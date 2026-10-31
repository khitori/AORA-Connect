# SPDX-License-Identifier: GPL-3.0-or-later
param([string]$LegacyHelper = 'C:/Users/thefa/AppData/Local/AORAConnect/app/aoravpn_update.exe', [switch]$FailStartup)
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$fixture=Join-Path $project ('build/migration-fixture-'+[guid]::NewGuid().ToString('N'))
$stage=Join-Path $fixture 'stage'
$legacy=Join-Path $fixture 'profile/Local/AORAConnect'
$installed=Join-Path $fixture 'installed'
New-Item -ItemType Directory -Force -Path "$stage/app","$stage/cores/windows","$legacy/app","$legacy/settings","$legacy/runtime/update-test","$legacy/cores","$legacy/uninstall" | Out-Null
$oldEnv=$env:AORA_MIGRATION_FIXTURE_ROOT
$env:AORA_MIGRATION_FIXTURE_ROOT=$fixture
$env:PATH='C:/Dev/flutter/bin;'+$env:PATH
$cargo=Join-Path $env:USERPROFILE '.cargo/bin/cargo.exe'
$rustc=Join-Path $env:USERPROFILE '.cargo/bin/rustc.exe'
$compiler='C:/Program Files (x86)/Inno Setup 6/ISCC.exe'
$version=((Get-Content "$project/pubspec.yaml" | Where-Object {$_ -match '^version:'}) -replace '^version:\s*','').Trim()
$releaseVersion=$version.Split('+')[0]
$buildVersion=$version.Replace('+','.')
$parts=$releaseVersion.Split('.')
$nextReleaseVersion="$($parts[0]).$($parts[1]).$([int]$parts[2]+1)"
$nextVersion=$nextReleaseVersion+'+'+([int]$version.Split('+')[1]+1)
$nextBuildVersion=$nextVersion.Replace('+','.')
try {
  & $LegacyHelper info | Set-Content "$fixture/legacy-version.json"
  if ((Get-Content "$fixture/legacy-version.json" -Raw | ConvertFrom-Json).version -ne '1.1.9+13') { throw 'Use the actual 1.1.9 updater for this regression.' }
  Copy-Item -LiteralPath $LegacyHelper -Destination "$legacy/runtime/update-test/aoravpn_update.exe"
  & $cargo build --locked --release --manifest-path "$project/native/windows/Cargo.toml" --features migration-fixture --bin aoravpn_migrate --bin aoravpn_update --target-dir "$project/build/migration-fixture-native" > "$fixture/native-build.log" 2>&1
  if ($LASTEXITCODE -ne 0) { throw "Fixture helper build failed; see $fixture/native-build.log" }
  Copy-Item -LiteralPath "$project/build/migration-fixture-native/release/aoravpn_migrate.exe" -Destination "$stage/app/aoravpn_migrate.exe"
  Copy-Item -LiteralPath "$project/build/migration-fixture-native/release/aoravpn_update.exe" -Destination "$stage/app/aoravpn_update.exe"
  $clientSource=@'
#![windows_subsystem="windows"]
use std::{fs,ffi::c_void,os::windows::ffi::OsStrExt};
#[link(name="kernel32")]
extern "system" { fn OpenEventW(access:u32,inherit:i32,name:*const u16)->*mut c_void; fn SetEvent(event:*mut c_void)->i32; fn CloseHandle(handle:*mut c_void)->i32; }
fn main(){
 let root=std::env::current_exe().unwrap().parent().unwrap().parent().unwrap().to_path_buf();
 if root.join("fail-startup").exists(){std::process::exit(42);}
 for name in ["app-state.json","language.json","updates.json"] { let bytes=fs::read(root.join("settings").join(name)).unwrap(); fs::write(root.join(format!("read-{name}")),bytes).unwrap(); }
 for arg in std::env::args(){if let Some(name)=arg.strip_prefix("--migration-ready="){let name:Vec<u16>=std::ffi::OsStr::new(name).encode_wide().chain(Some(0)).collect();unsafe{let handle=OpenEventW(2,0,name.as_ptr());assert!(!handle.is_null());SetEvent(handle);CloseHandle(handle);}}}
 fs::write(root.join("client-started.txt"),b"started").unwrap();
}
'@
  [IO.File]::WriteAllText("$fixture/client.rs",$clientSource)
  & $rustc --edition 2021 -O --crate-name migration_fixture_client "$fixture/client.rs" -o "$stage/app/aoravpn.exe"
  if($LASTEXITCODE -ne 0){throw 'Fixture client compilation failed'}
  Copy-Item -LiteralPath "$stage/app/aoravpn.exe" -Destination "$legacy/app/aoravpn.exe"
  [IO.File]::WriteAllText("$legacy/settings/app-state.json",'{"subscription":"fixture-token","routingPolicy":{"direction":"direct"}}')
  [IO.File]::WriteAllText("$legacy/settings/language.json",'{"language":"ru"}')
  [IO.File]::WriteAllText("$legacy/settings/updates.json",'{"automatic":false}')
  [IO.File]::WriteAllText("$legacy/installed-version.txt",'1.1.9.13')
  Copy-Item -LiteralPath "$project/LICENSE" -Destination "$stage/cores/windows/fixture.txt"
  if($FailStartup){New-Item -ItemType Directory -Force -Path $installed | Out-Null; [IO.File]::WriteAllText("$installed/fail-startup",'fail')}
  & $compiler /Q /DTestInstall=1 "/DMigrationFixtureRoot=$fixture" "/DStageDir=$stage" "/DAppVersion=$releaseVersion" "/DBuildVersion=$buildVersion" "/DOutputPath=$legacy/runtime/update-test" "$project/installer/aora.iss" > "$fixture/installer-build.log" 2>&1
  if($LASTEXITCODE -ne 0){throw "Fixture installer compilation failed; see $fixture/installer-build.log"}
  Push-Location $project
  try {
    & dart run tool/sign_release.dart sign (Join-Path $env:USERPROFILE '.aora-connect/release-private.json') "$legacy/runtime/update-test/AORAConnect-Setup.exe" $version "https://github.com/khitori/AORA-Connect/releases/download/v$releaseVersion/AORAConnect-Setup.exe" | Out-Null
    if($LASTEXITCODE -ne 0){throw 'Fixture signing failed'}
  } finally {Pop-Location}
  $start=[Diagnostics.ProcessStartInfo]::new("$legacy/runtime/update-test/aoravpn_update.exe",'install "'+"$legacy/runtime/update-test/AORAConnect-Setup.exe"+'" 0')
  $start.UseShellExecute=$false; $start.CreateNoWindow=$true
  $start.Environment['LOCALAPPDATA']=Join-Path $fixture 'profile/Local'
  $process=[Diagnostics.Process]::Start($start)
  try {
    if(!$process.WaitForExit(60000)){$process.Kill();throw 'Legacy updater timed out'}
    if($process.ExitCode -ne 0){throw "Legacy updater failed: $($process.ExitCode)"}
  } finally {$process.Dispose()}
  $deadline=[DateTime]::UtcNow.AddSeconds(40)
  if($FailStartup){
    while(!(Test-Path -LiteralPath "$legacy/client-started.txt") -and [DateTime]::UtcNow -lt $deadline){Start-Sleep -Milliseconds 100}
    if(!(Test-Path -LiteralPath "$legacy/client-started.txt")){throw 'Previous client did not restart after failed startup'}
    foreach($name in @('app-state.json','language.json','updates.json')){if(!(Test-Path -LiteralPath "$legacy/settings/$name")){throw "Rollback lost $name"}}
    if(!(Test-Path -LiteralPath "$legacy/cores")){throw 'Rollback removed old cores'}
    'PASS: actual 1.1.9 updater; failed new startup restored the previous client and preserved all legacy settings.'
  } else {
    while((!(Test-Path -LiteralPath "$installed/client-started.txt") -or (Test-Path -LiteralPath $legacy)) -and [DateTime]::UtcNow -lt $deadline){Start-Sleep -Milliseconds 100}
    if(!(Test-Path -LiteralPath "$installed/client-started.txt")){throw 'New client did not start from the target folder'}
    if(Test-Path -LiteralPath $legacy){throw 'Legacy installation or temporary launcher was left behind'}
    foreach($name in @('app-state.json','language.json','updates.json')){if([IO.File]::ReadAllText("$installed/settings/$name") -ne [IO.File]::ReadAllText("$installed/read-$name")){throw "New client did not read migrated $name"}}
    'PASS: actual 1.1.9 updater installed the signed migration package, restarted the new client, preserved all three settings files and removed the entire legacy folder.'
    $next=Join-Path $installed 'runtime/update-test'
    New-Item -ItemType Directory -Force -Path $next | Out-Null
    Copy-Item -LiteralPath "$stage/app/aoravpn_update.exe" -Destination "$next/aoravpn_update.exe"
    & $compiler /Q /DTestInstall=1 "/DMigrationFixtureRoot=$fixture" "/DStageDir=$stage" "/DAppVersion=$nextReleaseVersion" "/DBuildVersion=$nextBuildVersion" "/DOutputPath=$next" "$project/installer/aora.iss" > "$fixture/next-installer-build.log" 2>&1
    if($LASTEXITCODE -ne 0){throw 'Subsequent fixture build failed'}
    Push-Location $project
    try {
      & dart run tool/sign_release.dart sign (Join-Path $env:USERPROFILE '.aora-connect/release-private.json') "$next/AORAConnect-Setup.exe" $nextVersion "https://github.com/khitori/AORA-Connect/releases/download/v$nextReleaseVersion/AORAConnect-Setup.exe" | Out-Null
      if($LASTEXITCODE -ne 0){throw 'Subsequent fixture signing failed'}
    } finally {Pop-Location}
    $nextProcess=Start-Process -FilePath "$next/aoravpn_update.exe" -ArgumentList 'install',('"'+"$next/AORAConnect-Setup.exe"+'"'),'0' -WindowStyle Hidden -PassThru
    if(!$nextProcess.WaitForExit(60000)){$nextProcess.Kill();throw 'Subsequent updater timed out'}
    if($nextProcess.ExitCode -ne 0){throw 'Subsequent updater failed'}
    if(Test-Path -LiteralPath $legacy){throw 'Subsequent update recreated the legacy launcher'}
    if([IO.File]::ReadAllText("$installed/installed-version.txt") -ne $nextBuildVersion){throw 'Subsequent update did not advance version'}
    'PASS: subsequent signed update used the new installation directly and did not recreate any legacy files.'
  }
  "Isolated fixture: $fixture"
} finally {$env:AORA_MIGRATION_FIXTURE_ROOT=$oldEnv}
