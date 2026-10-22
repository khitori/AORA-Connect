# SPDX-License-Identifier: GPL-3.0-or-later
param([string]$FlutterBin = '', [string]$ReleaseNotes = '')
$project = Split-Path $PSScriptRoot -Parent
if ($FlutterBin) { $env:PATH = $FlutterBin + ';' + $env:PATH }
New-Item -ItemType Directory -Path (Join-Path $project 'build/installer') -Force | Out-Null
$log = Join-Path $project 'build/installer/build.log'
$result = Join-Path $project 'build/installer/build-result.txt'
[IO.File]::WriteAllText($result, 'running')
try {
  $env:AORA_BUILD_NOTES = $ReleaseNotes
  $errors = Join-Path $project 'build/installer/build-errors.log'
  $shell = (Get-Process -Id $PID).Path
  $child = Start-Process -FilePath $shell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',('"' + "$PSScriptRoot/build_installer.ps1" + '"') -NoNewWindow -PassThru -RedirectStandardOutput $log -RedirectStandardError $errors
  $null = $child.Handle
  $child.WaitForExit()
  $child.Refresh()
  if ($child.ExitCode -ne 0) { throw 'Installer build failed; inspect build.log and build-errors.log.' }
  [IO.File]::WriteAllText($result, 'success')
} catch {
  $_ | Out-String | Add-Content -LiteralPath $log
  [IO.File]::WriteAllText($result, 'failed')
  exit 1
}
