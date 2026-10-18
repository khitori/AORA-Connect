# SPDX-License-Identifier: GPL-3.0-or-later
param(
  [string]$SigningProperties,
  [string]$UpdateSigningKey = (Join-Path $env:USERPROFILE '.aora-connect/release-private.json'),
  [string]$ReleaseNotes = $env:AORA_BUILD_NOTES
)
$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
if (!$SigningProperties) { $SigningProperties = Join-Path $project '.release-keys/android/signing.properties' }
if (!(Test-Path -LiteralPath $SigningProperties)) { throw 'Android signing files are missing. Restore the signing folder; see docs/updates.md.' }
if (!(Test-Path -LiteralPath $UpdateSigningKey)) { throw 'Update metadata signing key is missing; see docs/updates.md.' }
$oldSigning = $env:AORA_ANDROID_SIGNING_PROPERTIES
$oldNotes = $env:AORA_RELEASE_NOTES
Push-Location $project
try {
  $env:AORA_ANDROID_SIGNING_PROPERTIES = (Resolve-Path -LiteralPath $SigningProperties).Path
  $env:AORA_RELEASE_NOTES = $ReleaseNotes
  $version = ((Get-Content pubspec.yaml | Where-Object { $_ -match '^version:' }) -replace '^version:\s*', '').Trim()
  if ($version -notmatch '^\d+\.\d+\.\d+\+([1-9]\d*)$' -or [long]$Matches[1] -gt 2100000000) { throw 'Use major.minor.patch+build in pubspec.yaml with a positive Android build number.' }
  $releaseVersion = $version.Split('+')[0]
  & flutter build apk --release --target-platform android-arm64
  if ($LASTEXITCODE -ne 0) { throw 'Android release compilation failed.' }
  $output = Join-Path $project 'build/android-release'
  New-Item -ItemType Directory -Path $output -Force | Out-Null
  $apk = Join-Path $output 'AORAConnect.apk'
  Copy-Item -LiteralPath (Join-Path $project 'build/app/outputs/flutter-apk/app-release.apk') -Destination $apk -Force
  $sdkLine = Get-Content android/local.properties | Where-Object { $_ -match '^sdk.dir=' } | Select-Object -First 1
  $sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { ($sdkLine -replace '^sdk.dir=', '') -replace '\\', '\' }
  $tools = Get-ChildItem -LiteralPath (Join-Path $sdk 'build-tools') -Directory | Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } | Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
  $java = if ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME 'bin/java.exe' } else { 'C:/Program Files/Android/Android Studio/jbr/bin/java.exe' }
  & $java -jar (Join-Path $tools.FullName 'lib/apksigner.jar') verify --verbose --print-certs $apk
  if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed.' }
  $badging = & (Join-Path $tools.FullName 'aapt2.exe') dump badging $apk
  if ($LASTEXITCODE -ne 0) { throw 'Could not read the built APK manifest.' }
  $package = $badging | Where-Object { $_ -match '^package:' } | Select-Object -First 1
  if ($package -notmatch "name='aora.aoranet.aoravpn' versionCode='(\d+)' versionName='([^']+)'" -or "$($Matches[2])+$($Matches[1])" -ne $version) { throw 'Built APK application/version does not match pubspec.yaml.' }
  $url = 'https://github.com/khitori/AORA-Connect/releases/download/v' + $releaseVersion + '/AORAConnect.apk'
  & dart run tool/sign_release.dart sign-android $UpdateSigningKey $apk $version $url
  if ($LASTEXITCODE -ne 0) { throw 'Android update metadata signing failed.' }
  Get-FileHash -LiteralPath $apk -Algorithm SHA256
  Write-Output "Built $apk. Publish AORAConnect.apk and aora-update-android.json to GitHub release v$releaseVersion."
} finally {
  $env:AORA_ANDROID_SIGNING_PROPERTIES = $oldSigning
  $env:AORA_RELEASE_NOTES = $oldNotes
  Pop-Location
}
