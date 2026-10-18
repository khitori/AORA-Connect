# SPDX-License-Identifier: GPL-3.0-or-later
param(
  [string]$SdkRoot = (Join-Path $env:LOCALAPPDATA 'Android/sdk'),
  [string]$JavaHome = 'C:/Program Files/Android/Android Studio/jbr'
)
$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$work = Join-Path $project 'build/android-core'
$version = '1.14.2'
$commit = 'af6e64c3b69e6132ebaee0e1a3d24e93903f6709'
$goVersion = 'go1.27.2'
$goHash = '1314008898bd40df77af4b014f777f08873dbdfbcd3d92308728ee03304fe04f'
$ndk = Join-Path $SdkRoot 'ndk/28.2.13676358'
if (!(Test-Path -LiteralPath "$ndk/source.properties")) { throw 'Install NDK 28.2.13676358 through Android SDK Manager first.' }
if (!(Test-Path -LiteralPath "$JavaHome/bin/javac.exe")) { throw 'Pass -JavaHome with a Java JDK directory.' }
New-Item -ItemType Directory -Path $work -Force | Out-Null
$toolchain = Join-Path $work $goVersion
$go = Join-Path $toolchain 'go/bin/go.exe'
if (!(Test-Path -LiteralPath $go)) {
  $archive = Join-Path $work "$goVersion.windows-amd64.zip"
  Invoke-WebRequest "https://go.dev/dl/$goVersion.windows-amd64.zip" -OutFile $archive
  if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $goHash) { throw 'Go archive hash mismatch.' }
  Expand-Archive -LiteralPath $archive -DestinationPath $toolchain -Force
}
$source = Join-Path $work 'sing-box'
if (!(Test-Path -LiteralPath "$source/go.mod")) {
  & git clone --depth 1 --branch "v$version" https://github.com/SagerNet/sing-box.git $source
  if ($LASTEXITCODE -ne 0) { throw 'Core source download failed.' }
}
$actualCommit = & git -C $source rev-parse HEAD
if ($actualCommit -ne $commit) { throw 'Unexpected core revision; expected the pinned v1.14.2 commit.' }
$xray = Join-Path $work 'xray'
if (!(Test-Path -LiteralPath "$xray/go.mod")) {
  & git clone --depth 1 --branch v26.9.30 https://github.com/XTLS/Xray-core.git $xray
  if ($LASTEXITCODE -ne 0) { throw 'Xray source download failed.' }
}
if ((& git -C $xray rev-parse HEAD) -ne 'b26a91de4f3294e26a0ad0a970b81a386a41f789') { throw 'Unexpected Xray revision.' }
$patch = Join-Path $project 'native/android/patches/xray-grpc-lifecycle.patch'
$patchCheckPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
& git -C $xray apply --reverse --check $patch 2>$null
$patchAlreadyApplied = $LASTEXITCODE -eq 0
$ErrorActionPreference = $patchCheckPreference
if (!$patchAlreadyApplied) {
  & git -C $xray apply --check $patch
  if ($LASTEXITCODE -ne 0) { throw 'Xray lifecycle patch does not match the pinned source.' }
  & git -C $xray apply $patch
  if ($LASTEXITCODE -ne 0) { throw 'Xray lifecycle patch failed.' }
}
Copy-Item -LiteralPath (Join-Path $project 'native/android/xray/grpc_lifecycle.go') -Destination "$xray/transport/internet/grpc/aora_lifecycle.go"
$environment = @{}
foreach ($name in 'PATH','GOBIN','GOPATH','GOCACHE','GOTOOLCHAIN','JAVA_HOME','ANDROID_HOME','ANDROID_NDK_HOME') {
  $environment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}
Push-Location (Join-Path $project 'native/android/core')
try {
  $env:PATH = "$toolchain/go/bin;$work/bin;$JavaHome/bin;" + $env:PATH
  $env:GOBIN = "$work/bin-go1.27"
  $env:GOPATH = "$work/gopath"
  $env:GOCACHE = "$work/cache"
  $env:GOTOOLCHAIN = 'local'
  $env:JAVA_HOME = $JavaHome
  $env:ANDROID_HOME = $SdkRoot
  $env:ANDROID_NDK_HOME = $ndk
  New-Item -ItemType Directory -Path $env:GOBIN -Force | Out-Null
  foreach ($tool in 'gomobile','gobind') {
    if (!(Test-Path -LiteralPath "$env:GOBIN/$tool.exe")) {
      & $go install "github.com/sagernet/gomobile/cmd/$tool@v0.1.12"
      if ($LASTEXITCODE -ne 0) { throw "Failed to build $tool." }
    }
  }
  # Match upstream's mobile build tags and its pinned gomobile fork.
  $tags = 'with_gvisor,with_quic,with_wireguard,with_utls,with_naive_outbound,with_clash_api,with_usbip,with_openvpn,with_openconnect,badlinkname,tfogo_checklinkname0,with_tailscale,ts_omit_logtail,ts_omit_ssh,ts_omit_drive,ts_omit_taildrop,ts_omit_webclient,ts_omit_doctor,ts_omit_capture,ts_omit_kube,ts_omit_aws,ts_omit_synology,ts_omit_bird'
  $flags = "-s -w -checklinkname=0 -X github.com/sagernet/sing-box/constant.Version=$version -X runtime.godebugDefault=multipathtcp=0,tlssha1=1"
  $env:PATH = "$env:GOBIN;" + $env:PATH
  & $go mod tidy
  if ($LASTEXITCODE -ne 0) { throw 'Android dependency resolution failed.' }
  & "$env:GOBIN/gomobile.exe" bind -target android/arm64 -androidapi 24 -javapkg io.nekohasekai -libname box -trimpath -buildvcs=false -ldflags $flags -tags $tags -o "$work/libbox.aar" github.com/sagernet/sing-box/experimental/libbox aora/androidcore
  if ($LASTEXITCODE -ne 0) { throw 'Android core build failed.' }
  $output = Join-Path $project "cores/android/sing-box-$version"
  $licenses = Join-Path $project 'cores/android/licenses'
  New-Item -ItemType Directory -Path $output,$licenses -Force | Out-Null
  Copy-Item -LiteralPath "$work/libbox.aar" -Destination "$output/libbox.aar"
  Copy-Item -LiteralPath "$source/LICENSE" -Destination "$licenses/sing-box.txt"
  Copy-Item -LiteralPath "$xray/LICENSE" -Destination "$licenses/xray.txt"
  Get-FileHash -LiteralPath "$output/libbox.aar" -Algorithm SHA256
} finally {
  Pop-Location
  foreach ($name in $environment.Keys) { [Environment]::SetEnvironmentVariable($name, $environment[$name], 'Process') }
}
