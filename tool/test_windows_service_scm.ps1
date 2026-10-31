# SPDX-License-Identifier: GPL-3.0-or-later
param([switch]$PrepareOnly, [string]$PreparedFixture = '')
$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$cargo = Join-Path $env:USERPROFILE '.cargo/bin/cargo.exe'
$workerPath = Join-Path $PSScriptRoot 'windows_service_scm_worker.ps1'

function Read-Process([string]$executable, [string]$argument) {
  $startup = [Diagnostics.ProcessStartInfo]::new($executable, $argument)
  $startup.UseShellExecute = $false
  $startup.CreateNoWindow = $true
  $startup.RedirectStandardOutput = $true
  $startup.RedirectStandardError = $true
  $process = [Diagnostics.Process]::Start($startup)
  try {
    if (!$process.WaitForExit(10000)) { $process.Kill(); throw 'Fixture identity check timed out.' }
    $output = $process.StandardOutput.ReadToEnd()
    if ($process.ExitCode -ne 0) { throw $process.StandardError.ReadToEnd() }
    return $output | ConvertFrom-Json
  } finally { $process.Dispose() }
}

function Quote-PowerShell([string]$value) { return "'" + $value.Replace("'", "''") + "'" }

if (!$PreparedFixture) {
  $id = [guid]::NewGuid().ToString('N')
  $fixture = Join-Path $project ('build/service-scm-fixture-' + $id)
  New-Item -ItemType Directory -Path $fixture | Out-Null
  $version = ((Get-Content (Join-Path $project 'pubspec.yaml') | Where-Object { $_ -match '^version:' }) -replace '^version:\s*', '').Trim()
  if ($version -notmatch '^(\d+)\.(\d+)\.(\d+)\+(\d+)$') { throw 'Unexpected application version.' }
  $nextVersion = '{0}.{1}.{2}+{3}' -f $Matches[1],$Matches[2],([int]$Matches[3] + 1),([int]$Matches[4] + 1)
  $previousId = $env:AORA_SERVICE_FIXTURE_ID
  $previousVersion = $env:AORA_SERVICE_FIXTURE_VERSION
  $target = Join-Path $project 'build/service-scm-native'
  try {
    $env:AORA_SERVICE_FIXTURE_ID = $id
    foreach ($entry in @(@{ Name='first'; Version=$version }, @{ Name='second'; Version=$nextVersion })) {
      $env:AORA_SERVICE_FIXTURE_VERSION = $entry.Version
      & $cargo build --locked --manifest-path (Join-Path $project 'native/windows/Cargo.toml') --target-dir $target --features service-scm-fixture --bin aoravpn_service --bin aoravpn_core_host --bin aoravpn_core_console
      if ($LASTEXITCODE -ne 0) { throw 'SCM fixture build failed.' }
      $destination = Join-Path $fixture $entry.Name
      New-Item -ItemType Directory -Path $destination | Out-Null
      Copy-Item -LiteralPath (Join-Path $target 'debug/aoravpn_service.exe') -Destination $destination
    }
  } finally {
    $env:AORA_SERVICE_FIXTURE_ID = $previousId
    $env:AORA_SERVICE_FIXTURE_VERSION = $previousVersion
  }
  $first = Join-Path $fixture 'first/aoravpn_service.exe'
  $second = Join-Path $fixture 'second/aoravpn_service.exe'
  $assets = [Collections.Generic.List[object]]::new()
  foreach ($name in @('aoravpn_core_host.exe','aoravpn_core_console.exe')) {
    $source = Join-Path $target ('debug/' + $name)
    $assets.Add(@{ Relative='app/' + $name; Source=$source; Hash=(Get-FileHash -LiteralPath $source).Hash.ToLowerInvariant() })
  }
  foreach ($folder in @('sing-box-1.14.2-windows-amd64','xray-v26.9.30-windows-64')) {
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $project ('cores/windows/' + $folder)) -File | Where-Object { $_.Extension -in @('.exe','.dll','.dat') }) {
      $assets.Add(@{ Relative='cores/windows/' + $folder + '/' + $file.Name; Source=$file.FullName; Hash=(Get-FileHash -LiteralPath $file.FullName).Hash.ToLowerInvariant() })
    }
  }
  $assetFile = Join-Path $fixture 'assets.json'
  $assets.ToArray() | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $assetFile -Encoding UTF8
  [ordered]@{
    Id=$id; First=$first; FirstHash=(Get-FileHash -LiteralPath $first).Hash.ToLowerInvariant();
    Second=$second; SecondHash=(Get-FileHash -LiteralPath $second).Hash.ToLowerInvariant();
    Assets=$assetFile; AssetsHash=(Get-FileHash -LiteralPath $assetFile).Hash.ToLowerInvariant()
  } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $fixture 'fixture.json') -Encoding UTF8
} else {
  $fixture = [IO.Path]::GetFullPath($PreparedFixture)
}
$buildRoot = [IO.Path]::GetFullPath((Join-Path $project 'build'))
if (!$fixture.StartsWith($buildRoot + '\', [StringComparison]::OrdinalIgnoreCase) -or (Split-Path $fixture -Leaf) -notmatch '^service-scm-fixture-[0-9a-f]{32}$') { throw 'Prepared fixture must be in the project build directory.' }
$manifest = Get-Content -LiteralPath (Join-Path $fixture 'fixture.json') -Raw | ConvertFrom-Json
if ($manifest.Id -notmatch '^[0-9a-f]{32}$' -or (Split-Path $fixture -Leaf) -cne ('service-scm-fixture-' + $manifest.Id)) { throw 'Fixture ID does not match its directory.' }
$expectedRoot = Join-Path ([Environment]::GetFolderPath('ProgramFiles')) ('AORAConnect-ServiceTest-' + $manifest.Id)
$expectedService = 'AORAConnectServiceTest-' + $manifest.Id
foreach ($entry in @(@{ Path=$manifest.First; Hash=$manifest.FirstHash }, @{ Path=$manifest.Second; Hash=$manifest.SecondHash })) {
  if ((Get-FileHash -LiteralPath $entry.Path).Hash.ToLowerInvariant() -ne $entry.Hash) { throw 'Prepared fixture changed; rebuild it.' }
  $identity = Read-Process $entry.Path 'fixture-info'
  if ($identity.root -cne $expectedRoot -or $identity.service -cne $expectedService) { throw 'Prepared helper does not match the isolated SCM fixture.' }
}
if ($PrepareOnly) { Write-Output "Prepared SCM fixture: $fixture"; exit 0 }
$pipeName = 'AORAConnectServiceReport-' + $manifest.Id
$pipe = [IO.Pipes.NamedPipeServerStream]::new($pipeName, [IO.Pipes.PipeDirection]::In, 1, [IO.Pipes.PipeTransmissionMode]::Byte, [IO.Pipes.PipeOptions]::Asynchronous)
$process = $null
try {
  $workerHash = (Get-FileHash -LiteralPath $workerPath).Hash.ToLowerInvariant()
  $bootstrap = @'
$ErrorActionPreference = 'Stop'
$bytes = [IO.File]::ReadAllBytes(__WORKER__)
$sha = [Security.Cryptography.SHA256]::Create()
try { $hash = ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLowerInvariant() } finally { $sha.Dispose() }
if ($hash -ne __WORKER_HASH__) { throw 'SCM test script changed before administrator approval.' }
& ([ScriptBlock]::Create([Text.Encoding]::UTF8.GetString($bytes))) -FixtureId __ID__ -FirstHelper __FIRST__ -FirstHash __FIRST_HASH__ -SecondHelper __SECOND__ -SecondHash __SECOND_HASH__ -Assets __ASSETS__ -AssetsHash __ASSETS_HASH__ -ReportPipe __PIPE__
'@
  foreach ($replacement in @{
    '__WORKER__'=$workerPath; '__WORKER_HASH__'=$workerHash; '__ID__'=$manifest.Id;
    '__FIRST__'=$manifest.First; '__FIRST_HASH__'=$manifest.FirstHash;
    '__SECOND__'=$manifest.Second; '__SECOND_HASH__'=$manifest.SecondHash; '__PIPE__'=$pipeName;
    '__ASSETS__'=$manifest.Assets; '__ASSETS_HASH__'=$manifest.AssetsHash
  }.GetEnumerator()) { $bootstrap = $bootstrap.Replace($replacement.Key, (Quote-PowerShell $replacement.Value)) }
  $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($bootstrap))
  $connected = $pipe.BeginWaitForConnection($null,$null)
  $windows = [Environment]::GetFolderPath('Windows')
  Write-Output 'Requesting Windows administrator approval for the isolated service test.'
  $process = Start-Process -FilePath (Join-Path $windows 'System32/WindowsPowerShell/v1.0/powershell.exe') -ArgumentList '-NoProfile','-NonInteractive','-EncodedCommand',$encoded -Verb RunAs -WindowStyle Hidden -WorkingDirectory (Join-Path $windows 'System32') -PassThru
  $deadline = [DateTime]::UtcNow.AddMinutes(3)
  while (!$connected.AsyncWaitHandle.WaitOne(500)) {
    if ($process.HasExited) { throw 'The administrator worker exited without a report.' }
    if ([DateTime]::UtcNow -gt $deadline) { throw 'Timed out waiting for the administrator test report.' }
  }
  $pipe.EndWaitForConnection($connected)
  $reader = [IO.StreamReader]::new($pipe, [Text.UTF8Encoding]::new($false), $false, 4096, $true)
  try {
    $reading = $reader.ReadLineAsync()
    if (!$reading.Wait(15000)) { throw 'Timed out reading the test report.' }
    $line = $reading.GetAwaiter().GetResult()
    if (!$line -or $line.Length -gt 32768) { throw 'Invalid administrator test report.' }
  } finally { $reader.Dispose() }
  $report = $line | ConvertFrom-Json
  $report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $fixture 'report.json') -Encoding UTF8
  if (!$process.WaitForExit(15000)) { throw 'Administrator worker did not exit after reporting.' }
  if ($report.FixtureId -cne $manifest.Id -or !$report.Passed -or !$report.RootRemoved -or !$report.ServiceRemoved -or $process.ExitCode -ne 0) { throw "SCM test failed: $($report.Error) Cleanup: $($report.CleanupError). Report: $fixture/report.json" }
  if ((Test-Path -LiteralPath $expectedRoot) -or (Test-Path -LiteralPath ('HKLM:\SYSTEM\CurrentControlSet\Services\' + $expectedService))) { throw 'SCM fixture survived cleanup.' }
  foreach ($check in $report.Checks) { Write-Output "PASS: $check" }
  Write-Output "SCM report: $fixture/report.json"
} finally {
  if ($null -ne $process) { $process.Dispose() }
  $pipe.Dispose()
}
