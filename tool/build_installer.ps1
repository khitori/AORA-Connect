# SPDX-License-Identifier: GPL-3.0-or-later
param(
  [switch]$SkipBuild,
  [string]$SigningKey = (Join-Path $env:USERPROFILE '.aora-connect/release-private.json'),
  [string]$ReleaseNotes = $env:AORA_BUILD_NOTES
)
$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$compiler = Get-Command ISCC.exe -ErrorAction SilentlyContinue
$compilerPath = if ($compiler) { $compiler.Source } else { 'C:/Program Files (x86)/Inno Setup 6/ISCC.exe' }
if (!(Test-Path -LiteralPath $compilerPath)) { throw 'Install Inno Setup 6 or place ISCC.exe on PATH.' }
if (!(Test-Path -LiteralPath $SigningKey)) { throw 'Release signing key is missing; see docs/updates.md.' }
Push-Location $project
try {
  if (!$SkipBuild) {
    & "$PSScriptRoot/update_app_icon.ps1"
    & "$PSScriptRoot/test_app_icon.ps1"
    & "$PSScriptRoot/build_portable.ps1" -BundleOnly
    if ($LASTEXITCODE -ne 0) { throw 'Windows bundle build failed' }
  }
  $stage = (Get-Content -LiteralPath 'build/installer/stage-path.txt' -Raw).Trim()
  if (!(Test-Path -LiteralPath (Join-Path $stage 'app/aoravpn_update.exe'))) { throw 'Build staging is missing the update helper; rebuild first.' }
  if (!(Test-Path -LiteralPath (Join-Path $stage 'app/aoravpn_migrate.exe'))) { throw 'Build staging is missing the migration helper; rebuild first.' }
  $version = ((Get-Content pubspec.yaml | Where-Object { $_ -match '^version:' }) -replace '^version:\s*', '').Trim()
  if ($version -notmatch '^\d+\.\d+\.\d+\+\d+$') { throw 'Set version to major.minor.patch+build in pubspec.yaml.' }
  $installerVersion = $version -replace '\+', '.'
  $releaseVersion = $version.Split('+')[0]
  $output = Join-Path $project 'build/installer'
  & $compilerPath "/DStageDir=$stage" "/DAppVersion=$releaseVersion" "/DBuildVersion=$installerVersion" "/DOutputPath=$output" 'installer/aora.iss'
  if ($LASTEXITCODE -ne 0) { throw 'Installer compilation failed.' }
  $oldNotes = $env:AORA_RELEASE_NOTES
  $env:AORA_RELEASE_NOTES = $ReleaseNotes
  try {
    $url = 'https://github.com/khitori/AORA-Connect/releases/download/v' + $releaseVersion + '/AORAConnect-Setup.exe'
    & dart run tool/sign_release.dart sign $SigningKey (Join-Path $output 'AORAConnect-Setup.exe') $version $url
    if ($LASTEXITCODE -ne 0) { throw 'Installer signing failed.' }
  } finally { $env:AORA_RELEASE_NOTES = $oldNotes }
  $verification = Start-Process -FilePath (Join-Path $stage 'app/aoravpn_update.exe') -ArgumentList 'verify-package',('"' + (Join-Path $output 'AORAConnect-Setup.exe') + '"') -NoNewWindow -Wait -PassThru -RedirectStandardOutput (Join-Path $output 'verification.json') -RedirectStandardError (Join-Path $output 'verification-errors.txt')
  if ($verification.ExitCode -ne 0) { throw 'Signed installer verification failed; inspect verification-errors.txt.' }
  Get-FileHash -LiteralPath (Join-Path $output 'AORAConnect-Setup.exe') -Algorithm SHA256
  Write-Output "Publish AORAConnect-Setup.exe and aora-update.json to GitHub release v$releaseVersion."
} finally { Pop-Location }
