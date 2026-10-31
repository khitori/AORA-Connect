# SPDX-License-Identifier: GPL-3.0-or-later
$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$cargo = Join-Path $env:USERPROFILE '.cargo/bin/cargo.exe'
$id = [guid]::NewGuid().ToString('N')
$fixture = Join-Path $project ('build/service-fixture-' + $id)
$target = Join-Path $fixture 'native'
New-Item -ItemType Directory -Path $fixture | Out-Null
$previousId = $env:AORA_SERVICE_FIXTURE_ID
$server = $null
$duplicate = $null

function Start-FixtureProcess([string]$executable, [string]$argument) {
  $startup = [Diagnostics.ProcessStartInfo]::new($executable, $argument)
  $startup.UseShellExecute = $false
  $startup.CreateNoWindow = $true
  $startup.RedirectStandardInput = $true
  $startup.RedirectStandardOutput = $true
  $startup.RedirectStandardError = $true
  $startup.WorkingDirectory = $fixture
  return [Diagnostics.Process]::Start($startup)
}

function Invoke-FixtureCommand([string]$executable, [string]$argument) {
  $process = Start-FixtureProcess $executable $argument
  try {
    if (!$process.WaitForExit(10000)) { $process.Kill(); throw "Service command timed out: $argument" }
    return @{ Code = $process.ExitCode; Output = $process.StandardOutput.ReadToEnd(); Error = $process.StandardError.ReadToEnd() }
  } finally { $process.Dispose() }
}

try {
  & $cargo test --locked --manifest-path (Join-Path $project 'native/windows/Cargo.toml') --target-dir (Join-Path $project 'build/service-native') --lib service -- --test-threads=1
  if ($LASTEXITCODE -ne 0) { throw 'Service unit and pipe tests failed.' }
  $env:AORA_SERVICE_FIXTURE_ID = $id
  & $cargo build --locked --manifest-path (Join-Path $project 'native/windows/Cargo.toml') --target-dir $target --features service-fixture --bin aoravpn_service
  if ($LASTEXITCODE -ne 0) { throw 'Isolated service fixture build failed.' }
  $executable = Join-Path $target 'debug/aoravpn_service.exe'
  $server = Start-FixtureProcess $executable 'fixture'
  $deadline = [DateTime]::UtcNow.AddSeconds(10)
  do {
    $reply = Invoke-FixtureCommand $executable 'probe'
    if ($reply.Code -eq 0) { break }
    if ($server.HasExited) { throw ('Service fixture exited: ' + $server.StandardError.ReadToEnd()) }
    Start-Sleep -Milliseconds 100
  } while ([DateTime]::UtcNow -lt $deadline)
  if ($reply.Code -ne 0) { throw ('Service did not become ready: ' + $reply.Error) }
  $health = $reply.Output | ConvertFrom-Json
  $version = ((Get-Content (Join-Path $project 'pubspec.yaml') | Where-Object { $_ -match '^version:' }) -replace '^version:\s*', '').Trim()
  if ($health.protocol -ne 1 -or $health.phase -ne 'foundation' -or $health.vpn_control -ne $false -or $health.version -ne $version -or $health.pid -ne $server.Id) {
    throw 'Service health did not match the running fixture.'
  }
  foreach ($command in @('install','start','remove','stop','run','request')) {
    if ((Invoke-FixtureCommand $executable $command).Code -eq 0) { throw "Fixture exposed production service command: $command" }
  }
  $duplicate = Start-FixtureProcess $executable 'fixture'
  if (!$duplicate.WaitForExit(10000)) { $duplicate.Kill(); throw 'Duplicate endpoint did not fail promptly.' }
  if ($duplicate.ExitCode -eq 0) { throw 'Duplicate endpoint was accepted.' }
  if ((Invoke-FixtureCommand $executable 'probe').Code -ne 0) { throw 'Duplicate fixture interrupted the original endpoint.' }
  $server.StandardInput.WriteLine('stop')
  $server.StandardInput.Flush()
  if (!$server.WaitForExit(5000)) { $server.Kill(); throw 'Service fixture failed to stop cleanly.' }
  if ($server.ExitCode -ne 0) { throw ('Service fixture stopped with an error: ' + $server.StandardError.ReadToEnd()) }
  if ((Invoke-FixtureCommand $executable 'probe').Code -eq 0) { throw 'Service endpoint survived shutdown.' }
  Write-Output 'PASS: isolated service health, version/server identity, duplicate rejection, production-command isolation and clean shutdown.'
  Write-Output "Isolated fixture: $fixture"
} finally {
  foreach ($process in @($server,$duplicate)) {
    if ($null -ne $process) {
      if (!$process.HasExited) { $process.Kill(); $process.WaitForExit() }
      $process.Dispose()
    }
  }
  $env:AORA_SERVICE_FIXTURE_ID = $previousId
}
