# SPDX-License-Identifier: GPL-3.0-or-later
param([ValidateSet('Debug','Release')][string]$Configuration = 'Release')
$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$build = Join-Path $project 'build/windows/x64'
$cache = Get-Content -LiteralPath (Join-Path $build 'CMakeCache.txt')
$cmake = ($cache | Where-Object { $_ -like 'CMAKE_COMMAND:INTERNAL=*' }) -replace '^.*?=', ''
& $cmake -S (Join-Path $project 'windows') -B $build -DAORA_BUILD_RUNNER_SMOKE=ON
if ($LASTEXITCODE -ne 0) { throw 'Smoke target configuration failed' }
& $cmake --build $build --config $Configuration --target aora_runner_smoke
if ($LASTEXITCODE -ne 0) { throw 'Rust runner smoke build failed' }
$testRoot = Join-Path $project ('build/runner-smoke-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
$bundle = Join-Path $build "runner/$Configuration"
Copy-Item -LiteralPath (Join-Path $build "runner-tests/$Configuration/aora_runner_smoke.exe") -Destination $testRoot
Get-ChildItem -LiteralPath $bundle -File -Filter '*.dll' | Copy-Item -Destination $testRoot
Copy-Item -LiteralPath (Join-Path $bundle 'data') -Destination $testRoot -Recurse
$startup = [Diagnostics.ProcessStartInfo]::new((Join-Path $testRoot 'aora_runner_smoke.exe'), '--runner-smoke-test')
$startup.UseShellExecute = $false
$startup.CreateNoWindow = $true
$startup.RedirectStandardOutput = $true
$startup.RedirectStandardError = $true
$startup.Environment['LOCALAPPDATA'] = Join-Path $testRoot 'local'
$startup.Environment['APPDATA'] = Join-Path $testRoot 'roaming'
$startup.WorkingDirectory = $testRoot
$process = [Diagnostics.Process]::Start($startup)
try {
  if (!$process.WaitForExit(30000)) { $process.Kill(); throw 'Rust runner did not finish its hidden smoke test' }
  $output = $process.StandardOutput.ReadToEnd()
  $diagnostics = $process.StandardError.ReadToEnd()
  if ($process.ExitCode -ne 0 -or $output -notmatch 'AORA_RUNNER_SMOKE_OK') {
    throw "Rust runner smoke failed (exit $($process.ExitCode)): $output $diagnostics"
  }
  Write-Output $output.Trim()
  Write-Output "Isolated smoke folder: $testRoot"
} finally { $process.Dispose() }
