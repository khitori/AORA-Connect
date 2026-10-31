# SPDX-License-Identifier: GPL-3.0-or-later
param(
  [Parameter(Mandatory)][string]$SourceDirectory,
  [ValidateSet('Debug','Profile','Release')][string]$Configuration = 'Debug',
  [switch]$CheckOnly
)
$ErrorActionPreference = 'Stop'
if ($Configuration -eq 'Release') { return }
foreach ($module in @('Microsoft.PowerShell.Utility','Microsoft.PowerShell.Management')) {
  Import-Module (Join-Path $PSHOME "Modules/$module/$module.psd1") -ErrorAction Stop
}
$root = Join-Path ([Environment]::GetFolderPath('ProgramFiles')) 'AORAConnect'
$app = Join-Path $root 'app'
$source = [IO.Path]::GetFullPath($SourceDirectory)
$assets = @('aoravpn_service.exe','aoravpn_core_host.exe','aoravpn_core_console.exe') | ForEach-Object {
  $path = Join-Path $source $_
  @{ Name=$_; Source=$path; Hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() }
}
if (!(Test-Path -LiteralPath (Join-Path $app 'aoravpn.exe') -PathType Leaf)) {
  throw 'Install AORA Connect in Program Files first. Development uses its service, cores and settings.'
}
$serviceKey = 'HKLM:\SYSTEM\CurrentControlSet\Services\AORAConnectService'
$changed = !(Test-Path -LiteralPath $serviceKey)
foreach ($asset in $assets) {
  $destination = Join-Path $app $asset.Name
  if (!(Test-Path -LiteralPath $destination) -or (Get-FileHash -LiteralPath $destination).Hash.ToLowerInvariant() -ne $asset.Hash) { $changed = $true }
}
if (!$changed) {
  Write-Output 'The shared Windows service helpers are current.'
  return
}
if ($CheckOnly) { throw 'The installed service needs preparation. Run a normal Windows debug build.' }
$workerPath = Join-Path $PSScriptRoot 'windows_service_prepare_worker.ps1'
$workerHash = (Get-FileHash -LiteralPath $workerPath).Hash.ToLowerInvariant()
$manifest = ConvertTo-Json -InputObject @($assets) -Compress
$pipeName = 'AORAConnectPrepare-' + [guid]::NewGuid().ToString('N')
$pipe = [IO.Pipes.NamedPipeServerStream]::new($pipeName, [IO.Pipes.PipeDirection]::In, 1, [IO.Pipes.PipeTransmissionMode]::Byte, [IO.Pipes.PipeOptions]::Asynchronous)
$process = $null
function Quote-Value([string]$value) { return "'" + $value.Replace("'", "''") + "'" }
try {
  $bootstrap = @'
$ErrorActionPreference = 'Stop'
$bytes = [IO.File]::ReadAllBytes(__WORKER__)
$sha = [Security.Cryptography.SHA256]::Create()
try { $hash = ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLowerInvariant() } finally { $sha.Dispose() }
if ($hash -ne __HASH__) { throw 'Service preparation script changed before administrator approval.' }
& ([ScriptBlock]::Create([Text.Encoding]::UTF8.GetString($bytes))) -Manifest __MANIFEST__ -ReportPipe __PIPE__
'@
  foreach ($entry in @{
    '__WORKER__'=$workerPath; '__HASH__'=$workerHash; '__MANIFEST__'=$manifest; '__PIPE__'=$pipeName
  }.GetEnumerator()) { $bootstrap = $bootstrap.Replace($entry.Key, (Quote-Value $entry.Value)) }
  $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($bootstrap))
  $connected = $pipe.BeginWaitForConnection($null,$null)
  $windows = [Environment]::GetFolderPath('Windows')
  Write-Output 'Preparing the shared installed service. Windows may request administrator approval. Close AORA Connect first.'
  $process = Start-Process -FilePath (Join-Path $windows 'System32/WindowsPowerShell/v1.0/powershell.exe') -ArgumentList '-NoProfile','-NonInteractive','-EncodedCommand',$encoded -Verb RunAs -WindowStyle Hidden -WorkingDirectory (Join-Path $windows 'System32') -PassThru
  $deadline = [DateTime]::UtcNow.AddMinutes(3)
  while (!$connected.AsyncWaitHandle.WaitOne(250)) {
    if ($process.HasExited) { throw 'Administrator service preparation exited without a report.' }
    if ([DateTime]::UtcNow -gt $deadline) { throw 'Timed out waiting for service preparation.' }
  }
  $pipe.EndWaitForConnection($connected)
  $reader = [IO.StreamReader]::new($pipe, [Text.UTF8Encoding]::new($false), $false, 4096, $true)
  try {
    $reading = $reader.ReadLineAsync()
    if (!$reading.Wait(15000)) { throw 'Timed out reading the service preparation result.' }
    $line = $reading.GetAwaiter().GetResult()
    if (!$line -or $line.Length -gt 32768) { throw 'Invalid service preparation report.' }
  } finally { $reader.Dispose() }
  $result = $line | ConvertFrom-Json
  if (!$process.WaitForExit(15000)) { throw 'Service preparation did not finish after reporting.' }
  if (!$result.Passed -or $process.ExitCode -ne 0) { throw "Service preparation failed: $($result.Error)" }
  Write-Output 'The shared AORA Connect service is ready. Existing settings were preserved.'
} finally {
  if ($null -ne $process) { $process.Dispose() }
  $pipe.Dispose()
}
