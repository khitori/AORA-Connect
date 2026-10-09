# SPDX-License-Identifier: GPL-3.0-or-later
param([switch]$SkipFlutterBuild)
$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
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
foreach ($folder in @('sing-box-1.14.2-windows-amd64','xray-v26.9.30-windows-64')) {
  $source = Join-Path $project "cores/$folder"
  if (!(Test-Path -LiteralPath $source)) { throw "Missing core: $folder" }
  Copy-Item -LiteralPath $source -Destination $cores -Recurse
}
Copy-Item -LiteralPath (Join-Path $project 'LICENSE') -Destination (Join-Path $app 'LICENSE-AORAConnect')
$cache = Get-Content -LiteralPath (Join-Path $project 'build/windows/x64/CMakeCache.txt')
$cmake = ($cache | Where-Object { $_ -like 'CMAKE_COMMAND:INTERNAL=*' }) -replace '^.*?=', ''
$vs = ($cache | Where-Object { $_ -like 'CMAKE_GENERATOR_INSTANCE:INTERNAL=*' }) -replace '^.*?=', ''
$generator = ($cache | Where-Object { $_ -like 'CMAKE_GENERATOR:INTERNAL=*' }) -replace '^.*?=', ''
# App-local C++ runtime avoids requiring a separate redistributable installer.
$crt = Get-ChildItem -LiteralPath (Join-Path $vs 'VC/Redist/MSVC') -Recurse -Directory |
  Where-Object { $_.Name -like 'Microsoft.VC*.CRT' -and $_.FullName -match '[\\/]x64[\\/]' } |
  Sort-Object FullName -Descending | Select-Object -First 1
if (!$crt) { throw 'Visual C++ x64 redistributable DLLs not found' }
Get-ChildItem -LiteralPath $crt.FullName -Filter '*.dll' | Copy-Item -Destination $app
$archive = Join-Path $output 'payload.zip'
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $archive -Force
$packageId = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
$nativeBuild = Join-Path $output 'launcher-build'
& $cmake -S (Join-Path $PSScriptRoot 'portable') -B $nativeBuild -G $generator -A x64 "-DPAYLOAD_ZIP=$archive" "-DPACKAGE_ID=$packageId"
if ($LASTEXITCODE -ne 0) { throw 'Launcher configuration failed' }
& $cmake --build $nativeBuild --config Release
if ($LASTEXITCODE -ne 0) { throw 'Launcher build failed' }
$executable = Join-Path $output 'AORAConnect-windows-x64.exe'
Copy-Item -LiteralPath (Join-Path $nativeBuild 'Release/AORAConnect.exe') -Destination $executable -Force
Get-FileHash -LiteralPath $executable -Algorithm SHA256
Write-Output "Portable package: $executable"
