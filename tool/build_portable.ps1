# SPDX-License-Identifier: GPL-3.0-or-later
param([switch]$SkipFlutterBuild)
$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$cargo = Get-Command cargo -ErrorAction SilentlyContinue
if (!$cargo) {
  $cargoFile = Join-Path $env:USERPROFILE '.cargo/bin/cargo.exe'
  if (!(Test-Path -LiteralPath $cargoFile)) { throw 'Rust/Cargo is required. Install the Rust MSVC toolchain first.' }
  $cargoPath = $cargoFile
} else { $cargoPath = $cargo.Source }
if (!$SkipFlutterBuild) {
  Push-Location $project
  try { & flutter build windows --release; if ($LASTEXITCODE -ne 0) { throw 'Flutter build failed' } }
  finally { Pop-Location }
}
$release = Join-Path $project 'build/windows/x64/runner/Release'
$output = Join-Path $project 'build/portable'
# Each build has its own staging directory; no recursive cleanup of existing builds.
$stage = Join-Path $output ('stage-' + [guid]::NewGuid().ToString('N'))
$app = Join-Path $stage 'app'
$cores = Join-Path $stage 'cores'
New-Item -ItemType Directory -Force -Path $app,$cores | Out-Null
if (!(Test-Path -LiteralPath (Join-Path $release 'aoravpn.exe'))) { throw 'Release application missing' }
Get-ChildItem -LiteralPath $release | Copy-Item -Destination $app -Recurse -Force
# Rebuild native helpers even when reusing the Flutter release bundle, so a
# source-only migration cannot accidentally package old C++ helper binaries.
$rustProject = Join-Path $project 'native/windows'
$helperBuild = Join-Path $project 'build/windows/x64/rust'
Push-Location $rustProject
try {
  & $cargoPath build --locked --release --target x86_64-pc-windows-msvc --target-dir $helperBuild --bins
  if ($LASTEXITCODE -ne 0) { throw 'Rust helper build failed' }
  $metadataJson = & $cargoPath metadata --locked --format-version 1 --filter-platform x86_64-pc-windows-msvc
  if ($LASTEXITCODE -ne 0) { throw 'Rust dependency metadata failed' }
  $metadata = $metadataJson | ConvertFrom-Json
  foreach ($dependency in $metadata.packages | Where-Object { $_.source }) {
    $noticeDirectory = Join-Path $app ("licenses/rust/" + $dependency.name + '-' + $dependency.version)
    New-Item -ItemType Directory -Force -Path $noticeDirectory | Out-Null
    Get-ChildItem -LiteralPath (Split-Path $dependency.manifest_path -Parent) -File -Filter '*license*' |
      Copy-Item -Destination $noticeDirectory
  }
} finally { Pop-Location }
Copy-Item -LiteralPath (Join-Path $rustProject 'Cargo.lock') -Destination (Join-Path $app 'licenses/rust/Cargo.lock')
Copy-Item -LiteralPath (Join-Path $rustProject 'LICENSE-FlutterWindowsRunner.txt') -Destination (Join-Path $app 'licenses/LICENSE-FlutterWindowsRunner.txt')
foreach ($helper in @('aoravpn_core_host','aoravpn_core_console','aoravpn_server_ping','aoravpn_kill_switch','aoravpn_update')) {
  Copy-Item -LiteralPath (Join-Path $helperBuild "x86_64-pc-windows-msvc/release/$helper.exe") -Destination $app -Force
}
foreach ($folder in @('sing-box-1.14.2-windows-amd64','xray-v26.9.30-windows-64')) {
  $source = Join-Path $project "cores/$folder"
  if (!(Test-Path -LiteralPath $source)) { throw "Missing core: $folder" }
  Copy-Item -LiteralPath $source -Destination $cores -Recurse
}
Copy-Item -LiteralPath (Join-Path $project 'LICENSE') -Destination (Join-Path $app 'LICENSE-AORAConnect')
$cache = Get-Content -LiteralPath (Join-Path $project 'build/windows/x64/CMakeCache.txt')
$vs = ($cache | Where-Object { $_ -like 'CMAKE_GENERATOR_INSTANCE:INTERNAL=*' }) -replace '^.*?=', ''
# App-local C++ runtime avoids requiring a separate redistributable installer.
$crt = Get-ChildItem -LiteralPath (Join-Path $vs 'VC/Redist/MSVC') -Recurse -Directory |
  Where-Object { $_.Name -like 'Microsoft.VC*.CRT' -and $_.FullName -match '[\\/]x64[\\/]' } |
  Sort-Object FullName -Descending | Select-Object -First 1
if (!$crt) { throw 'Visual C++ x64 redistributable DLLs not found' }
Get-ChildItem -LiteralPath $crt.FullName -Filter '*.dll' | Copy-Item -Destination $app
$archive = Join-Path $output 'payload.zip'
# Some crate archives preserve pre-1980 license timestamps; ZIP cannot store
# those dates. Normalize only generated staging files, never the source files.
$zipMinimum = [DateTime]::new(1980, 1, 1)
$zipMaximum = [DateTime]::new(2107, 12, 31)
Get-ChildItem -LiteralPath $stage -Recurse -File | ForEach-Object {
  if ($_.LastWriteTime -lt $zipMinimum) { $_.LastWriteTime = $zipMinimum }
  elseif ($_.LastWriteTime -gt $zipMaximum) { $_.LastWriteTime = $zipMaximum }
}
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $archive -Force
Set-Content -LiteralPath (Join-Path $output 'stage-path.txt') -Value $stage
$packageId = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
$nativeBuild = Join-Path $output 'rust-launcher'
$oldPayload = $env:AORA_PAYLOAD_ZIP
$oldPackageId = $env:AORA_PACKAGE_ID
$oldResourceCompiler = $env:AORA_RESOURCE_COMPILER
$resourceCompiler = Get-Command rc.exe -ErrorAction SilentlyContinue
if ($resourceCompiler) {
  $env:AORA_RESOURCE_COMPILER = $resourceCompiler.Source
} else {
  $kits = @(
    'HKLM:\SOFTWARE\Microsoft\Windows Kits\Installed Roots',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows Kits\Installed Roots'
  ) | ForEach-Object {
    (Get-ItemProperty -LiteralPath $_ -ErrorAction SilentlyContinue).KitsRoot10
  } | Where-Object { $_ -and (Test-Path -LiteralPath (Join-Path $_ 'bin')) } |
    Select-Object -First 1
  if (!$kits) { throw 'Windows SDK installation missing' }
  $resourceCompilerPath = Get-ChildItem -LiteralPath (Join-Path $kits 'bin') -Directory |
    Sort-Object Name -Descending |
    ForEach-Object { Join-Path $_.FullName 'x64/rc.exe' } |
    Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
  if (!$resourceCompilerPath) { throw 'Windows SDK resource compiler missing' }
  $env:AORA_RESOURCE_COMPILER = $resourceCompilerPath
}
$env:AORA_PAYLOAD_ZIP = $archive
$env:AORA_PACKAGE_ID = $packageId
Push-Location $rustProject
try {
  & $cargoPath build --locked --release --target x86_64-pc-windows-msvc --target-dir $nativeBuild --features portable --bin AORAConnect
  if ($LASTEXITCODE -ne 0) { throw 'Rust launcher build failed' }
} finally {
  Pop-Location
  $env:AORA_PAYLOAD_ZIP = $oldPayload
  $env:AORA_PACKAGE_ID = $oldPackageId
  $env:AORA_RESOURCE_COMPILER = $oldResourceCompiler
}
$executable = Join-Path $output 'AORAConnect-windows-x64.exe'
Copy-Item -LiteralPath (Join-Path $nativeBuild 'x86_64-pc-windows-msvc/release/AORAConnect.exe') -Destination $executable -Force
Get-FileHash -LiteralPath $executable -Algorithm SHA256
Write-Output "Portable package: $executable"
