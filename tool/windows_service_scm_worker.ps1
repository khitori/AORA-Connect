# SPDX-License-Identifier: GPL-3.0-or-later
param(
  [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{32}$')][string]$FixtureId,
  [Parameter(Mandatory)][string]$FirstHelper,
  [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{64}$')][string]$FirstHash,
  [Parameter(Mandatory)][string]$SecondHelper,
  [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{64}$')][string]$SecondHash,
  [Parameter(Mandatory)][string]$Assets,
  [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{64}$')][string]$AssetsHash,
  [Parameter(Mandatory)][ValidatePattern('^AORAConnectServiceReport-[0-9a-f]{32}$')][string]$ReportPipe
)
$ErrorActionPreference = 'Stop'
$root = Join-Path ([Environment]::GetFolderPath('ProgramFiles')) ('AORAConnect-ServiceTest-' + $FixtureId)
$serviceName = 'AORAConnectServiceTest-' + $FixtureId
$serviceKey = 'HKLM:\SYSTEM\CurrentControlSet\Services\' + $serviceName
$helper = Join-Path $root 'app/aoravpn_service.exe'
$imagePath = '"' + $helper + '" run'
$createdRoot = $false
$changedConfig = $false
$checks = [Collections.Generic.List[string]]::new()
$result = [ordered]@{ Passed = $false; FixtureId = $FixtureId; Checks = @(); Error = $null; CleanupError = $null; RootRemoved = $false; ServiceRemoved = $false }

function Get-BytesHash([byte[]]$bytes) {
  $sha = [Security.Cryptography.SHA256]::Create()
  try { return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLowerInvariant() }
  finally { $sha.Dispose() }
}

function Invoke-Helper([string]$command, [bool]$success = $true, [string]$body = '') {
  $startup = [Diagnostics.ProcessStartInfo]::new($helper, $command)
  $startup.UseShellExecute = $false
  $startup.CreateNoWindow = $true
  $startup.RedirectStandardOutput = $true
  $startup.RedirectStandardError = $true
  $startup.RedirectStandardInput = $body -ne ''
  $startup.WorkingDirectory = Split-Path $helper -Parent
  $process = [Diagnostics.Process]::Start($startup)
  try {
    if ($body -ne '') { $process.StandardInput.Write($body); $process.StandardInput.Close() }
    $output = $process.StandardOutput.ReadToEndAsync()
    $diagnostics = $process.StandardError.ReadToEndAsync()
    if (!$process.WaitForExit(35000)) { $process.Kill(); $process.WaitForExit(); throw "Service helper timed out: $command" }
    $text = $output.GetAwaiter().GetResult()
    $errorText = $diagnostics.GetAwaiter().GetResult()
    if (($process.ExitCode -eq 0) -ne $success) { throw "Unexpected exit $($process.ExitCode) for $command : $errorText" }
    return $text
  } finally { $process.Dispose() }
}

function Assert-NoLinks([string]$path) {
  $absolute = [IO.Path]::GetFullPath($path)
  if ($absolute -ne $root -and !$absolute.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Fixture path escaped its protected root.' }
  $item = Get-Item -LiteralPath $absolute -Force
  if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Fixture cleanup refuses file/directory links.' }
  if ($item.PSIsContainer) { foreach ($child in Get-ChildItem -LiteralPath $absolute -Force) { Assert-NoLinks $child.FullName } }
}

function Protect-Fixture {
  $icacls = Join-Path $env:SystemRoot 'System32/icacls.exe'
  & $icacls $root '/inheritance:r' '/grant:r' '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-32-545:(OI)(CI)RX' '/Q' | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Could not restrict the fixture directory.' }
  & $icacls $root '/setowner' '*S-1-5-32-544' '/T' '/Q' | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Could not protect fixture ownership.' }
  foreach ($path in @($root, (Split-Path $helper -Parent), $helper)) {
    $acl = Get-Acl -LiteralPath $path
    if ($acl.GetOwner([Security.Principal.SecurityIdentifier]).Value -ne 'S-1-5-32-544') { throw 'Fixture ownership is not Administrators.' }
    foreach ($rule in $acl.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier])) {
      if ($rule.AccessControlType -eq 'Allow' -and $rule.IdentityReference.Value -notin @('S-1-5-18','S-1-5-32-544')) {
        $writes = [Security.AccessControl.FileSystemRights]::Write -bor [Security.AccessControl.FileSystemRights]::Delete -bor [Security.AccessControl.FileSystemRights]::ChangePermissions -bor [Security.AccessControl.FileSystemRights]::TakeOwnership
        if (($rule.FileSystemRights -band $writes) -ne 0) { throw 'Unprivileged access can modify the privileged fixture.' }
      }
    }
  }
}

function Assert-Health([string]$version) {
  $health = (Invoke-Helper 'probe') | ConvertFrom-Json
  if ($health.version -ne $version -or $health.protocol -ne 1 -or $health.phase -ne 'core-control' -or $health.vpn_control -ne $true -or $health.pid -le 0) { throw 'Unexpected service health.' }
  $configuration = Get-ItemProperty -LiteralPath $serviceKey
  if ($configuration.ImagePath.Replace('/','\') -cne $imagePath.Replace('/','\') -or $configuration.ObjectName -ne 'LocalSystem' -or $configuration.Start -ne 3 -or $configuration.Type -ne 16) { throw ('Unexpected SCM registration: ' + (($configuration | Select-Object ImagePath,ObjectName,Start,Type) | ConvertTo-Json -Compress)) }
  return $health
}

function Control([hashtable]$request, [bool]$success = $true) {
  $request.protocol = 1
  $reply = (Invoke-Helper 'request' $true ($request | ConvertTo-Json -Depth 20 -Compress)) | ConvertFrom-Json
  if ($reply.ok -ne $success) { throw "Unexpected control result: $($reply.error)" }
  return $reply
}

function Wait-Control([long]$ticket) {
  $deadline = [DateTime]::UtcNow.AddSeconds(45)
  do {
    $reply = Control @{ command='status'; cursor=0 }
    if ($reply.snapshot.completed -ge $ticket) {
      if ($reply.snapshot.error) { throw ('Core operation failed: ' + $reply.snapshot.error + ' Logs: ' + ($reply.logs | ConvertTo-Json -Compress)) }
      return $reply.snapshot
    }
    Start-Sleep -Milliseconds 100
  } while ([DateTime]::UtcNow -lt $deadline)
  throw 'Core operation timed out.'
}

function Test-SettingsStorage {
  function Settings([string]$command,[string]$document,[object]$value=$null,[string]$revision='', [bool]$success=$true) {
    $request=@{protocol=1;command=$command;document=$document}
    if ($command -eq 'settings.write') { $request.value=$value; $request.revision=$revision }
    $reply=(Invoke-Helper 'request' $true ($request|ConvertTo-Json -Depth 20 -Compress))|ConvertFrom-Json
    if ($reply.ok -ne $success) { throw ('Unexpected settings result ('+$command+'/'+$document+'): '+$reply.error+' '+$reply.diagnostic) }
    return $reply
  }
  $appFile=Join-Path $root 'settings/app-state.json'
  [IO.File]::WriteAllText($appFile,'{"version":1,"subscriptions":[{"url":"https://fixture.example/sub","extra":"preserve"}],"future":{"keep":true}}')
  $initialHash=Get-BytesHash ([IO.File]::ReadAllBytes($appFile))
  $first=Settings 'settings.read' 'app'
  if ($first.revision -ne $initialHash -or !$first.value.future.keep) { throw 'Settings read changed or lost legacy metadata.' }
  $saved=Settings 'settings.write' 'app' @{version=1;subscriptions=@(@{url='https://fixture.example/sub';selectedServerKey='dummy'});statisticsEnabled=$true} $first.revision
  $latest=Settings 'settings.read' 'app'
  if (!$latest.value.future.keep -or $latest.value.subscriptions[0].extra -ne 'preserve' -or !$latest.value.statisticsEnabled) { throw 'Typed save lost existing metadata.' }
  $conflict=Settings 'settings.write' 'app' @{version=1} $first.revision $false
  if ($conflict.error -ne 'settings_conflict' -or (Get-BytesHash ([IO.File]::ReadAllBytes($appFile))) -ne $saved.revision) { throw 'A stale save overwrote newer settings.' }
  $many=@(1..64|ForEach-Object {@{url=('https://fixture.example/sub/'+$_);selectedServerKey=('k'*1024)}})
  $large=Settings 'settings.write' 'app' @{version=1;subscriptions=$many;core='singBox';mode='tun'} $saved.revision
  $read=Settings 'settings.read' 'app'
  if ($read.value.subscriptions.Count -ne 64 -or ([IO.File]::ReadAllBytes($appFile)).Length -le 32768 -or $read.revision -ne $large.revision) { throw 'Large settings did not round-trip.' }
  $language=Settings 'settings.read' 'language'
  if ($language.revision -ne 'missing' -or $null -ne $language.value) { throw 'Missing language did not use the missing revision.' }
  $language=Settings 'settings.write' 'language' @{language='ru'} 'missing'
  $languagePath=Join-Path $root 'settings/language.json'
  $held=[IO.File]::Open($languagePath,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
  try {
    $failed=Settings 'settings.write' 'language' @{language='de'} $language.revision $false
    if ($failed.error -ne 'settings_storage_unavailable') { throw 'A locked file was replaced.' }
  } finally { $held.Dispose() }
  $unchanged=Settings 'settings.read' 'language'
  if ($unchanged.value.language -ne 'ru' -or $unchanged.revision -ne $language.revision) { throw 'A failed save changed language data.' }
  if (@(Get-ChildItem -LiteralPath (Join-Path $root 'settings') -Filter '.settings-*.tmp').Count) { throw 'Failed atomic save left temporary files.' }
  $language=Settings 'settings.write' 'language' @{language=$null} $language.revision
  $invalid=Settings 'settings.write' 'language' @{language='not-a-language'} $language.revision $false
  if ($invalid.error -ne 'invalid_settings') { throw 'Invalid language settings were accepted.' }
  $invalid=Settings 'settings.read' '../service-access.json' $null '' $false
  if ($invalid.error -ne 'invalid_settings') { throw 'An arbitrary settings path was accepted.' }
  $updatesFile=Join-Path $root 'settings/updates.json'
  $linkSource=Join-Path $root 'settings/hard-link-source.json'
  [IO.File]::WriteAllText($linkSource,'{"automaticChecks":false,"sources":[]}')
  New-Item -ItemType HardLink -Path $updatesFile -Target $linkSource | Out-Null
  try {
    $invalid=Settings 'settings.read' 'updates' $null '' $false
    if ($invalid.error -ne 'invalid_stored_settings') { throw 'Hard-linked settings were read.' }
  } finally { Remove-Item -LiteralPath $updatesFile -Force }
  $updates=Settings 'settings.write' 'updates' @{automaticChecks=$false;sources=@('https://mirror.example/updates')} 'missing'
  if ((Settings 'settings.read' 'updates').value.sources[0] -ne 'https://mirror.example/updates') { throw 'Update preferences were not saved.' }
  $bytes=[IO.File]::ReadAllBytes($appFile)
  try {
    [IO.File]::WriteAllText($appFile,'{broken')
    $invalid=Settings 'settings.read' 'app' $null '' $false
    $write=Settings 'settings.write' 'app' @{version=1} $large.revision $false
    if ($invalid.error -ne 'invalid_stored_settings' -or $write.error -ne 'invalid_stored_settings' -or [IO.File]::ReadAllText($appFile) -ne '{broken') { throw 'Corrupt settings were replaced.' }
  } finally { [IO.File]::WriteAllBytes($appFile,$bytes) }
  $checks.Add('Typed settings: atomic saves, large documents, stale revisions, metadata preservation, locked files, hard-link/path rejection and corrupt-file protection')
}

function Test-ProxyTraffic([int]$proxyPort=17890) {
  $backend = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
  $proxy = [Net.Sockets.TcpClient]::new()
  $accepted = $null
  try {
    $backend.Start()
    $port = $backend.LocalEndpoint.Port
    $pending = $backend.AcceptTcpClientAsync()
    $proxy.Connect('127.0.0.1',$proxyPort)
    $proxyStream = $proxy.GetStream()
    $proxyStream.ReadTimeout = 5000
    $request = [Text.Encoding]::ASCII.GetBytes("GET http://127.0.0.1:$port/test HTTP/1.1`r`nHost: 127.0.0.1:$port`r`nConnection: close`r`n`r`n")
    $proxyStream.Write($request,0,$request.Length)
    if (!$pending.Wait(5000)) { throw 'Proxy did not reach the local test server.' }
    $accepted = $pending.GetAwaiter().GetResult()
    $serverStream = $accepted.GetStream()
    $serverStream.ReadTimeout = 5000
    $buffer = New-Object byte[] 4096
    $count = $serverStream.Read($buffer,0,$buffer.Length)
    if ($count -le 0) { throw 'Proxy sent no HTTP request.' }
    $body = 'aora-proxy-' + $FixtureId
    $response = [Text.Encoding]::ASCII.GetBytes("HTTP/1.1 200 OK`r`nContent-Length: $($body.Length)`r`nConnection: close`r`n`r`n$body")
    $serverStream.Write($response,0,$response.Length)
    $accepted.Dispose(); $accepted = $null
    $reader = [IO.StreamReader]::new($proxyStream)
    try { $text = $reader.ReadToEnd() } finally { $reader.Dispose() }
    if (!$text.Contains($body)) { throw 'Proxy response did not match the local test server.' }
  } finally { if ($null -ne $accepted) { $accepted.Dispose() }; $proxy.Dispose(); $backend.Stop() }
}

function Test-TypedConnections([string]$version) {
  foreach ($core in @('singBox','xray')) {
    $plan=@{core=$core;mode='proxy';dns='cloudflare';leakProtection=$true;routing=@{enabled=$true;direction='direct';rules=@(@{match='ip';target='127.0.0.1';enabled=$true})}}
    if ($core -eq 'singBox') {
      $plan.outbound=@{type='hysteria2';tag='proxy';server='127.0.0.1';server_port=443;password='dummy';tls=@{enabled=$true;server_name='example.com';insecure=$false}}
    } else {
      $plan.outbound=@{protocol='vless';tag='proxy';settings=@{address='127.0.0.1';port=443;id='bf000d23-0752-40b4-affe-68f7707a9661';encryption='none'};streamSettings=@{method='grpc';security='tls';tlsSettings=@{serverName='example.com';allowInsecure=$false;pinnedPeerCertSha256=('ab'*32)};grpcSettings=@{serviceName='vpn';multiMode=$false}}}
    }
    $before=@(Get-ChildItem -LiteralPath (Join-Path $root 'runtime') -Directory -Filter 'service-*').Count
    $validated=Control @{command='connection.validate';plan=$plan}
    Wait-Control $validated.snapshot.issued|Out-Null
    if (@(Get-ChildItem -LiteralPath (Join-Path $root 'runtime') -Directory -Filter 'service-*').Count -ne $before) {throw 'Typed validation left a runtime file.'}
    Control @{command='connection.start';core=$core;config='profile-a/config.json';plan=$plan} $false|Out-Null
    $badPlan=$plan.Clone(); $badPlan.outbound=$plan.outbound.Clone(); $badPlan.outbound.path='C:/secret'
    $rejected=Control @{command='connection.validate';plan=$badPlan}
    $deadline=[DateTime]::UtcNow.AddSeconds(5)
    do {$failed=Control @{command='connection.status'}; if ($failed.snapshot.completed -ge $rejected.snapshot.issued) {break}; Start-Sleep -Milliseconds 50} while ([DateTime]::UtcNow -lt $deadline)
    if (!$failed.snapshot.error -or $failed.snapshot.state -ne 'stopped') {throw 'Unsafe typed plan was accepted.'}
    $started=Control @{command='connection.start';plan=$plan}
    $active=Wait-Control $started.snapshot.issued
    $files=@(Get-ChildItem -LiteralPath (Join-Path $root 'runtime') -Directory|Where-Object {$_.Name -match '^service-[0-9a-f]{32}$'})
    if ($files.Count -ne 1) {throw 'Typed connection did not retain exactly one private configuration.'}
    foreach ($path in @($files[0].FullName,(Join-Path $files[0].FullName 'config.json'))) {
      $acl=Get-Acl -LiteralPath $path
      if ($acl.GetOwner([Security.Principal.SecurityIdentifier]).Value -ne 'S-1-5-18') {throw 'Runtime configuration is not owned by SYSTEM.'}
      foreach ($rule in $acl.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier])) {
        if ($rule.AccessControlType -eq 'Allow' -and $rule.IdentityReference.Value -notin @('S-1-5-18','S-1-5-32-544')) {throw 'Private runtime configuration grants ordinary access.'}
      }
    }
    Test-ProxyTraffic
    Control @{command='connection.confirm';session=$active.session}|Out-Null
    Control @{command='connection.stop';session='stale-session'} $false|Out-Null
    $stopped=Control @{command='connection.stop';session=$active.session}
    Wait-Control $stopped.snapshot.issued|Out-Null
    if (Test-Path -LiteralPath $files[0].FullName) {throw 'Typed stop retained its private runtime file.'}
    $started=Control @{command='connection.start';plan=$plan}
    $active=Wait-Control $started.snapshot.issued
    Control @{command='connection.confirm';session=$active.session}|Out-Null
    $serviceProcess=[Diagnostics.Process]::GetProcessById((Assert-Health $version).pid)
    try {$serviceProcess.Kill();if (!$serviceProcess.WaitForExit(5000)) {throw 'Typed fixture service failed to terminate.'}} finally {$serviceProcess.Dispose()}
    Invoke-Helper 'start'|Out-Null
    if (@(Get-ChildItem -LiteralPath (Join-Path $root 'runtime') -Directory|Where-Object {$_.Name -match '^service-[0-9a-f]{32}$'}).Count) {throw 'Service restart retained crash-orphaned private configurations.'}
    $checks.Add("$core typed connection: no client files, real local proxy traffic, private SYSTEM-only configuration, stale-session rejection, stop cleanup and crash recovery")
  }
}

function Checks([hashtable]$request,[bool]$success=$true) {
  $request.protocol=1
  $reply=(Invoke-Helper 'request' $true ($request|ConvertTo-Json -Depth 20 -Compress))|ConvertFrom-Json
  if ($reply.ok -ne $success) {throw ('Unexpected server-check response: '+$reply.error)}
  return $reply
}
function Wait-Checks([string]$id,[string]$phase) {
  $deadline=[DateTime]::UtcNow.AddSeconds(50)
  do {
    $reply=Checks @{command='checks.status';id=$id}
    if ($reply.phase -eq $phase) {return $reply}
    if ($phase -eq 'ready' -and $reply.phase -eq 'closed') {throw ('Server checks stopped during preparation: '+$reply.error+' '+($reply.nodes|ConvertTo-Json -Compress))}
    Start-Sleep -Milliseconds 100
  } while ([DateTime]::UtcNow -lt $deadline)
  throw 'Server checks failed to reach the expected phase.'
}
function Test-ServerChecks([string]$version) {
  $mainPlan=@{core='singBox';mode='proxy';dns='cloudflare';leakProtection=$true;routing=@{enabled=$true;direction='direct';rules=@(@{match='ip';target='127.0.0.1';enabled=$true})};outbound=@{type='hysteria2';tag='proxy';server='127.0.0.1';server_port=443;password='dummy';tls=@{enabled=$true;server_name='example.com';insecure=$false}}}
  $main=Control @{command='connection.start';plan=$mainPlan};$mainState=Wait-Control $main.snapshot.issued
  Control @{command='connection.confirm';session=$mainState.session}|Out-Null
  $nodes=@(0..69|ForEach-Object {if ($_%2 -eq 0) {@{index=$_;core='singBox';outbound=@{type='direct';tag='proxy'}}}else{@{index=$_;core='xray';outbound=@{protocol='freedom';tag='proxy'}}}})
  $nodes+=@{index=70;core='singBox';outbound=@{type='shadowsocks';tag='proxy';server='127.0.0.1';server_port=8388;method='2022-blake3-aes-128-gcm';password='bad-key'}}
  $nodes+=@{index=71;core='xray';outbound=@{protocol='freedom';tag='proxy';exec='C:/secret'}}
  $id=[guid]::NewGuid().ToString('N')
  $request=@{command='checks.open';id=$id;nodes=$nodes}
  Checks $request|Out-Null
  $ready=Wait-Checks $id 'ready'
  if ($ready.nodes.Count -ne 72 -or @($ready.nodes|Where-Object {$_.port -gt 0}).Count -ne 70 -or @($ready.nodes|Where-Object {$_.error}).Count -ne 2) {throw ('Mixed check batch did not isolate bad profiles: '+($ready.nodes|ConvertTo-Json -Compress))}
  if (@(Get-ChildItem -LiteralPath (Join-Path $root 'runtime') -Directory|Where-Object {$_.Name -match '^service-[0-9a-f]{32}$'}).Count -ne 3) {throw 'Scan did not share exactly two cores beside the main connection.'}
  Test-ProxyTraffic ($ready.nodes|Where-Object {$_.index -eq 0}).port
  Checks @{command='checks.status';id=$id}|Out-Null
  Test-ProxyTraffic ($ready.nodes|Where-Object {$_.index -eq 1}).port
  Checks $request|Out-Null
  $other=[guid]::NewGuid().ToString('N')
  Checks @{command='checks.open';id=$other;nodes=$nodes} $false|Out-Null
  Checks @{command='checks.close';id=$other}|Out-Null
  if ((Checks @{command='checks.status';id=$id}).phase -ne 'ready') {throw 'Stale close changed an active check batch.'}
  if ((Control @{command='connection.status'}).snapshot.session -ne $mainState.session) {throw 'Server checks replaced the main VPN session.'}
  Test-ProxyTraffic
  Checks @{command='checks.close';id=$id}|Out-Null
  Wait-Checks $id 'closed'|Out-Null
  if (@(Get-ChildItem -LiteralPath (Join-Path $root 'runtime') -Directory|Where-Object {$_.Name -match '^service-[0-9a-f]{32}$'}).Count -ne 1) {throw 'Scan cleanup retained files or deleted the main connection.'}
  Test-ProxyTraffic
  $checks.Add('72-node mixed-core scan: two shared cores, invalid-profile isolation, proxy traffic, idempotent open, stale-close rejection and independent active VPN session')
  $id=[guid]::NewGuid().ToString('N')
  Checks @{command='checks.open';id=$id;nodes=$nodes}|Out-Null
  Checks @{command='checks.close';id=$id}|Out-Null
  Wait-Checks $id 'closed'|Out-Null
  if ((Control @{command='connection.status'}).snapshot.state -ne 'running') {throw 'Cancelling preparation stopped the main connection.'}
  $id=[guid]::NewGuid().ToString('N')
  Checks @{command='checks.open';id=$id;nodes=$nodes[0..1]}|Out-Null
  Wait-Checks $id 'ready'|Out-Null
  Start-Sleep -Seconds 4
  if ((Checks @{command='checks.status';id=$id}).phase -ne 'closed') {throw 'Abandoned server checks did not expire.'}
  if ((Control @{command='connection.status'}).snapshot.state -ne 'running') {throw 'Check lease expiry stopped the main connection.'}
  $checks.Add('Cancellation during preparation and expired client heartbeat clean check cores without stopping the active VPN')
  $id=[guid]::NewGuid().ToString('N')
  Checks @{command='checks.open';id=$id;nodes=$nodes[0..1]}|Out-Null
  $ready=Wait-Checks $id 'ready'
  $ports=@(17890)+@($ready.nodes|ForEach-Object {[int]$_.port})
  $serviceProcess=[Diagnostics.Process]::GetProcessById((Assert-Health $version).pid)
  try {$serviceProcess.Kill();if (!$serviceProcess.WaitForExit(5000)) {throw 'Check fixture service failed to terminate.'}} finally {$serviceProcess.Dispose()}
  Invoke-Helper 'start'|Out-Null
  $listeners=[Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners().Port
  if (@($ports|Where-Object {$_ -in $listeners}).Count) {throw 'A core listener survived the service crash.'}
  if (@(Get-ChildItem -LiteralPath (Join-Path $root 'runtime') -Directory|Where-Object {$_.Name -match '^service-[0-9a-f]{32}$'}).Count) {throw 'Crash recovery retained check configurations.'}
  $checks.Add('Service crash removes main/check core process trees and restart removes private orphaned configurations')
}

function Test-RuntimeRejection {
  Invoke-Helper 'stop'|Out-Null
  $directory=Join-Path $root ('runtime/service-'+('f'*32))
  $file=Join-Path $directory 'config.json'
  $extra=Join-Path $directory 'extra.txt'
  $source=Join-Path $root 'runtime/preserved-runtime-sample.json'
  $hash=Get-BytesHash ([IO.File]::ReadAllBytes($source))
  New-Item -ItemType Directory -Path $directory|Out-Null
  New-Item -ItemType HardLink -Path $file -Target $source|Out-Null
  try {
    Invoke-Helper 'start' $false|Out-Null
    if ((Get-BytesHash ([IO.File]::ReadAllBytes($source))) -ne $hash -or !(Test-Path -LiteralPath $file)) {throw 'Hard-link recovery modified the linked file.'}
  } finally {Remove-Item -LiteralPath $file -Force}
  [IO.File]::WriteAllText($file,'{}')
  [IO.File]::WriteAllText($extra,'preserve')
  try {
    Invoke-Helper 'start' $false|Out-Null
    if (!(Test-Path -LiteralPath $file) -or [IO.File]::ReadAllText($extra) -ne 'preserve') {throw 'Unknown runtime contents were deleted.'}
  } finally {Remove-Item -LiteralPath $file,$extra -Force;[IO.Directory]::Delete($directory)}
  Invoke-Helper 'start'|Out-Null
  $checks.Add('Runtime recovery rejects hard links and unexpected contents without following links or deleting unrelated files')
}

function Test-CoreControl([string]$version) {
  if ([Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners().Port -contains 17890) { throw 'Port 17890 is already in use; the test will not interrupt its owner.' }
  foreach ($core in @('singBox','xray')) {
    $profile = 'profile-scm-' + $FixtureId + '-' + $core
    $directory = Join-Path $root ('runtime/' + $profile)
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    if ($core -eq 'singBox') {
      $config = @{ log=@{level='info'}; inbounds=@(@{type='mixed';listen='127.0.0.1';listen_port=17890}); outbounds=@(@{type='direct';tag='direct'}); route=@{final='direct'} }
    } else {
      $config = @{ log=@{loglevel='info'}; inbounds=@(@{protocol='http';listen='127.0.0.1';port=17890}); outbounds=@(@{protocol='freedom';tag='direct'}); routing=@{domainStrategy='AsIs'} }
    }
    $file = Join-Path $directory 'config.json'
    [IO.File]::WriteAllText($file, ($config | ConvertTo-Json -Depth 10 -Compress), [Text.UTF8Encoding]::new($false))
    $reference = $profile + '/config.json'
    Control @{command='start';core=$core;config='../outside/config.json'} $false | Out-Null
    $badConfig = $config.Clone()
    $badConfig.outbounds = @(@{type='unsupported-test-outbound';protocol='unsupported-test-outbound'})
    [IO.File]::WriteAllText($file, ($badConfig | ConvertTo-Json -Depth 10 -Compress), [Text.UTF8Encoding]::new($false))
    $invalid = Control @{command='validate';core=$core;config=$reference}
    $deadline = [DateTime]::UtcNow.AddSeconds(10)
    do {
      $rejected = Control @{command='status'}
      if ($rejected.snapshot.completed -ge $invalid.snapshot.issued) { break }
      Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)
    if ($rejected.snapshot.completed -lt $invalid.snapshot.issued -or !$rejected.snapshot.error -or $rejected.snapshot.state -ne 'stopped') { throw 'Invalid configuration was not rejected cleanly.' }
    [IO.File]::WriteAllText($file, ($config | ConvertTo-Json -Depth 10 -Compress), [Text.UTF8Encoding]::new($false))
    $validation = Control @{command='validate';core=$core;config=$reference}
    Wait-Control $validation.snapshot.issued | Out-Null
    $started = Control @{command='start';core=$core;config=$reference}
    $snapshot = Wait-Control $started.snapshot.issued
    if (!$snapshot.ready -or $snapshot.state -ne 'starting') { throw 'Service reported connected before verification.' }
    $session = $snapshot.session
    Control @{command='start';core=$core;config=$reference} $false | Out-Null
    Control @{command='stop';session='stale-session'} $false | Out-Null
    Test-ProxyTraffic
    Remove-Item -LiteralPath $file
    $confirmed = Control @{command='confirm';session=$session}
    if ($confirmed.snapshot.state -ne 'running') { throw 'Verification acknowledgement did not commit the connection.' }
    if ((Control @{command='status'}).snapshot.session -ne $session) { throw 'Connection did not survive the control client exiting.' }
    $stopped = Control @{command='stop';session=$session}
    if ((Wait-Control $stopped.snapshot.issued).state -ne 'stopped') { throw 'Core failed to stop.' }
    if ([Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners().Port -contains 17890) { throw 'Core process survived stop.' }
    $checks.Add("$core real-core validation, HTTP proxy traffic, verification gating, stale-session rejection and graceful stop")
    [IO.File]::WriteAllText($file, ($config | ConvertTo-Json -Depth 10 -Compress), [Text.UTF8Encoding]::new($false))
    $cancelled = Control @{command='start';core=$core;config=$reference}
    $cancelStop = Control @{command='stop';session=$cancelled.snapshot.session}
    Wait-Control $cancelStop.snapshot.issued | Out-Null
    if ([Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners().Port -contains 17890) { throw 'Cancelled start left a running core.' }
    $checks.Add("$core startup cancellation without an orphan core")
    $crashStart = Control @{command='start';core=$core;config=$reference}
    $active = Wait-Control $crashStart.snapshot.issued
    Control @{command='confirm';session=$active.session} | Out-Null
    $serviceProcess = [Diagnostics.Process]::GetProcessById((Assert-Health $version).pid)
    try {
      $null = $serviceProcess.Handle
      $serviceProcess.Kill()
      if (!$serviceProcess.WaitForExit(5000)) { throw 'Fixture service failed to terminate.' }
    } finally { $serviceProcess.Dispose() }
    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    while (([Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners().Port -contains 17890) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 50 }
    if ([Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners().Port -contains 17890) { throw 'Core survived its service process crashing.' }
    $deadline = [DateTime]::UtcNow.AddSeconds(3)
    do {
      $offline = (Invoke-Helper 'request' $true '{"protocol":1,"command":"status"}') | ConvertFrom-Json
      if ($offline.service_stopped -eq $true) { break }
      Start-Sleep -Milliseconds 50
    } while ([DateTime]::UtcNow -lt $deadline)
    if ($offline.ok -ne $false -or $offline.service_stopped -ne $true) { throw 'Crashed service did not report an authoritative stopped state.' }
    Invoke-Helper 'start' | Out-Null
    if ((Control @{command='status'}).snapshot.state -ne 'stopped') { throw 'Restarted service reported the old connection as active.' }
    $checks.Add("$core complete process tree removed after service crash")
  }
  $lease = Control @{command='start';core='xray';config=$reference}
  Wait-Control $lease.snapshot.issued | Out-Null
  $deadline = [DateTime]::UtcNow.AddSeconds(15)
  do {
    $pending = Control @{command='status'}
    if ($pending.snapshot.state -eq 'stopped') { break }
    Start-Sleep -Milliseconds 200
  } while ([DateTime]::UtcNow -lt $deadline)
  if ($pending.snapshot.state -ne 'stopped' -or !$pending.snapshot.error.Contains('acknowledgement timed out')) { throw 'Unverified connection was not stopped when its acknowledgement lease expired.' }
  $checks.Add('Missing verification acknowledgement expires and stops the unverified connection')
}

try {
  if (![Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Administrator approval is required for the real SCM test.' }
  if ([IO.Path]::GetFullPath($root) -cne $root -or (Test-Path -LiteralPath $root) -or (Test-Path -LiteralPath $serviceKey)) { throw 'The unique test service or directory already exists; it was left untouched.' }
  $firstBytes = [IO.File]::ReadAllBytes($FirstHelper)
  $secondBytes = [IO.File]::ReadAllBytes($SecondHelper)
  if ((Get-BytesHash $firstBytes) -ne $FirstHash -or (Get-BytesHash $secondBytes) -ne $SecondHash -or $FirstHash -eq $SecondHash) { throw 'Fixture binary integrity check failed.' }
  New-Item -ItemType Directory -Path $root | Out-Null
  $createdRoot = $true
  New-Item -ItemType Directory -Path (Split-Path $helper -Parent) | Out-Null
  [IO.File]::WriteAllBytes($helper, $firstBytes)
  $assetBytes = [IO.File]::ReadAllBytes($Assets)
  if ((Get-BytesHash $assetBytes) -ne $AssetsHash) { throw 'Asset manifest integrity check failed.' }
  foreach ($asset in ([Text.Encoding]::UTF8.GetString($assetBytes).TrimStart([char]0xFEFF) | ConvertFrom-Json)) {
    if ($asset.Relative -notmatch '^(app/(aoravpn_core_host|aoravpn_core_console)\.exe|cores/windows/(sing-box-1\.14\.2-windows-amd64|xray-v26\.9\.30-windows-64)/[A-Za-z0-9_.-]+)$') { throw 'Unexpected asset destination.' }
    $bytes = [IO.File]::ReadAllBytes($asset.Source)
    if ((Get-BytesHash $bytes) -ne $asset.Hash) { throw 'Core asset integrity check failed.' }
    $destination = Join-Path $root $asset.Relative
    New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
    [IO.File]::WriteAllBytes($destination, $bytes)
  }
  New-Item -ItemType Directory -Path (Join-Path $root 'runtime') | Out-Null
  Protect-Fixture
  $runtimePath=Join-Path $root 'runtime'
  $runtimeAcl=Get-Acl -LiteralPath $runtimePath
  $runtimeAcl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new('S-1-5-32-545'),[Security.AccessControl.FileSystemRights]::Write,[Security.AccessControl.AccessControlType]::Allow))
  Set-Acl -LiteralPath $runtimePath -AclObject $runtimeAcl
  $runtimeSample=Join-Path $runtimePath 'preserved-runtime-sample.json'
  [IO.File]::WriteAllText($runtimeSample,'{"fixture":"preserve-existing-runtime"}')
  $runtimeHash=Get-BytesHash ([IO.File]::ReadAllBytes($runtimeSample))
  $settingsPath = Join-Path $root 'settings'
  New-Item -ItemType Directory -Path $settingsPath | Out-Null
  & (Join-Path $env:SystemRoot 'System32/icacls.exe') $settingsPath '/setowner' '*S-1-5-32-544' '/Q' | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Could not set the test settings owner.' }
  $looseAcl = Get-Acl -LiteralPath $settingsPath
  $looseAcl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new('S-1-5-32-545'), [Security.AccessControl.FileSystemRights]::Write, [Security.AccessControl.AccessControlType]::Allow))
  Set-Acl -LiteralPath $settingsPath -AclObject $looseAcl
  $preferenceSample = Join-Path $settingsPath 'preference-sample.json'
  [IO.File]::WriteAllText($preferenceSample, '{"fixture":"preserve-existing-preferences"}')
  $preferenceHash = Get-BytesHash ([IO.File]::ReadAllBytes($preferenceSample))
  $firstInfo = (Invoke-Helper 'fixture-info') | ConvertFrom-Json
  if ($firstInfo.root -cne $root -or $firstInfo.service -cne $serviceName) { throw 'Compiled fixture identity does not match the protected test scope.' }
  $checks.Add('Protected fixture ownership, permissions and binary integrity')
  Invoke-Helper 'install' | Out-Null
  $initial = Assert-Health $firstInfo.version
  if ((Get-BytesHash ([IO.File]::ReadAllBytes($runtimeSample))) -ne $runtimeHash) {throw 'Runtime enrollment changed existing file contents.'}
  foreach ($rule in (Get-Acl -LiteralPath $runtimePath).GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier])) {
    if ($rule.AccessControlType -eq 'Allow' -and $rule.IdentityReference.Value -notin @('S-1-5-18','S-1-5-32-544')) {throw 'Runtime enrollment retained an ordinary access grant.'}
  }
  $checks.Add('Existing administrator-owned runtime permissions tightened without changing file contents')
  if ((Get-BytesHash ([IO.File]::ReadAllBytes($preferenceSample))) -ne $preferenceHash) { throw 'Enrollment changed an existing preference file.' }
  foreach ($rule in (Get-Acl -LiteralPath $settingsPath).GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier])) {
    if ($rule.AccessControlType -eq 'Allow' -and $rule.IdentityReference.Value -notin @('S-1-5-18','S-1-5-32-544')) { throw 'First enrollment retained an ordinary settings write grant.' }
  }
  $checks.Add('First enrollment removes stale ordinary settings permissions without changing preferences')
  $checks.Add('Real SCM registration and LocalSystem startup')
  $policyPath = Join-Path $root 'settings/service-access.json'
  $policyBytes = [IO.File]::ReadAllBytes($policyPath)
  $policyHash = Get-BytesHash $policyBytes
  $policy = [Text.Encoding]::UTF8.GetString($policyBytes) | ConvertFrom-Json
  if ($policy.version -ne 1 -or $policy.user_sid -ne [Security.Principal.WindowsIdentity]::GetCurrent().User.Value) { throw 'Enrollment did not bind the signed-in test user.' }
  Invoke-Helper 'install' | Out-Null
  if ((Get-BytesHash ([IO.File]::ReadAllBytes($policyPath))) -ne $policyHash) { throw 'Repair rewrote the authorization owner.' }
  $policyAcl = Get-Acl -LiteralPath $policyPath
  try {
    $unsafeAcl = Get-Acl -LiteralPath $policyPath
    $unsafeAcl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new('S-1-5-32-545'), [Security.AccessControl.FileSystemRights]::Write, [Security.AccessControl.AccessControlType]::Allow))
    Set-Acl -LiteralPath $policyPath -AclObject $unsafeAcl
    Invoke-Helper 'install' $false | Out-Null
    if ((Get-BytesHash ([IO.File]::ReadAllBytes($policyPath))) -ne $policyHash) { throw 'Unsafe enrollment policy was silently replaced.' }
  } finally { Set-Acl -LiteralPath $policyPath -AclObject $policyAcl }
  Invoke-Helper 'stop' | Out-Null
  try {
    [IO.File]::WriteAllText($policyPath, '{"version":999,"user_sid":"S-1-1-0"}')
    Invoke-Helper 'start' $false | Out-Null
    Invoke-Helper 'probe' $false | Out-Null
  } finally { [IO.File]::WriteAllBytes($policyPath, $policyBytes) }
  Invoke-Helper 'start' | Out-Null
  Assert-Health $firstInfo.version | Out-Null
  $checks.Add('Authorization owner retained on repair; writable and malformed policies rejected without permissive fallback')
  Test-SettingsStorage
  Test-TypedConnections $firstInfo.version
  Test-RuntimeRejection
  Test-ServerChecks $firstInfo.version
  Test-CoreControl $firstInfo.version
  $initial = Assert-Health $firstInfo.version
  Invoke-Helper 'install' | Out-Null
  if ((Assert-Health $firstInfo.version).pid -ne $initial.pid) { throw 'Repair unexpectedly duplicated/restarted the service.' }
  $checks.Add('Idempotent repair without a duplicate process')
  $serviceProcess = [Diagnostics.Process]::GetProcessById($initial.pid)
  $null = $serviceProcess.Handle
  $stalledClient = [IO.Pipes.NamedPipeClientStream]::new('.', ('AORAConnectService-ScmTest-' + $FixtureId), [IO.Pipes.PipeDirection]::InOut, [IO.Pipes.PipeOptions]::None, [Security.Principal.TokenImpersonationLevel]::Identification)
  try {
    $stalledClient.Connect(2000)
    $stalledClient.WriteByte(1)
    $stalledClient.Flush()
    $stoppedAt = [DateTime]::UtcNow
    Invoke-Helper 'stop' | Out-Null
    if (!$serviceProcess.WaitForExit(0) -or ([DateTime]::UtcNow - $stoppedAt).TotalSeconds -gt 5) { throw 'Service stop did not finish its process promptly with a stalled client.' }
  } finally { $serviceProcess.Dispose(); $stalledClient.Dispose() }
  Invoke-Helper 'stop' | Out-Null
  Invoke-Helper 'probe' $false | Out-Null
  $checks.Add('Stalled-client cancellation, process exit, repeated stop and endpoint removal')
  Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
public static class AoraScmFixtureConfig {
  [DllImport("advapi32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern IntPtr OpenSCManager(string machine, string database, uint access);
  [DllImport("advapi32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern IntPtr OpenService(IntPtr manager, string name, uint access);
  [DllImport("advapi32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern bool ChangeServiceConfig(IntPtr service, uint type, uint start, uint error, string binary, string group, IntPtr tag, string dependencies, string account, string password, string display);
  [DllImport("advapi32.dll")] static extern bool CloseServiceHandle(IntPtr handle);
  public static void Set(string name, string binary, string account, uint type) {
    if (!name.StartsWith("AORAConnectServiceTest-", StringComparison.Ordinal) || name.Length != 55) throw new ArgumentException("Invalid fixture name");
    if (String.IsNullOrEmpty(binary)) binary = null;
    if (String.IsNullOrEmpty(account)) account = null;
    IntPtr manager = OpenSCManager(null, null, 1);
    if (manager == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
    try {
      IntPtr service = OpenService(manager, name, 2);
      if (service == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
      try { if (!ChangeServiceConfig(service,type,uint.MaxValue,uint.MaxValue,binary,null,IntPtr.Zero,null,account,null,null)) throw new Win32Exception(Marshal.GetLastWin32Error()); }
      finally { CloseServiceHandle(service); }
    } finally { CloseServiceHandle(manager); }
  }
}
'@
  foreach ($case in @('path','account','type')) {
    $changedConfig = $true
    switch ($case) {
      'path' { [AoraScmFixtureConfig]::Set($serviceName, ('"' + (Join-Path $env:SystemRoot 'System32/notepad.exe') + '"'), $null, [uint32]::MaxValue) }
      'account' { [AoraScmFixtureConfig]::Set($serviceName, $null, 'NT AUTHORITY\LocalService', [uint32]::MaxValue) }
      'type' { [AoraScmFixtureConfig]::Set($serviceName, $null, $null, 32) }
    }
    $before = (Get-ItemProperty -LiteralPath $serviceKey) | Select-Object ImagePath,ObjectName,Type | ConvertTo-Json -Compress
    foreach ($command in @('install','stop','remove')) { Invoke-Helper $command $false | Out-Null }
    $after = (Get-ItemProperty -LiteralPath $serviceKey) | Select-Object ImagePath,ObjectName,Type | ConvertTo-Json -Compress
    if ($before -cne $after) { throw 'Service manager changed an unexpected registration.' }
    [AoraScmFixtureConfig]::Set($serviceName, $imagePath, 'LocalSystem', 16)
    $changedConfig = $false
  }
  $checks.Add('Unexpected executable, account and service type rejected without modification')
  [IO.File]::WriteAllBytes($helper, $secondBytes)
  Protect-Fixture
  $secondInfo = (Invoke-Helper 'fixture-info') | ConvertFrom-Json
  if ($secondInfo.version -eq $firstInfo.version -or $secondInfo.service -cne $serviceName -or $secondInfo.root -cne $root) { throw 'Upgrade fixture does not have a distinct version in the same installation.' }
  Invoke-Helper 'install' | Out-Null
  Assert-Health $secondInfo.version | Out-Null
  $checks.Add('Stopped service binary replaced and upgraded version started')
  Invoke-Helper 'remove' | Out-Null
  $deadline = [DateTime]::UtcNow.AddSeconds(10)
  while ((Test-Path -LiteralPath $serviceKey) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 100 }
  if (Test-Path -LiteralPath $serviceKey) { throw 'Service registration survived removal.' }
  Invoke-Helper 'remove' | Out-Null
  Invoke-Helper 'probe' $false | Out-Null
  $checks.Add('Uninstall, repeated removal and endpoint cleanup')
  $result.Passed = $true
} catch {
  $result.Error = $_.Exception.Message
} finally {
  if ($createdRoot) {
    try {
      if (Test-Path -LiteralPath $serviceKey) {
        if ($changedConfig) { [AoraScmFixtureConfig]::Set($serviceName, $imagePath, 'LocalSystem', 16) }
        Invoke-Helper 'remove' | Out-Null
      }
      $deadline = [DateTime]::UtcNow.AddSeconds(10)
      while ((Test-Path -LiteralPath $serviceKey) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 100 }
      if (Test-Path -LiteralPath $serviceKey) { throw 'Cleanup retained the protected fixture because the service still exists.' }
      Assert-NoLinks $root
      Remove-Item -LiteralPath $root -Recurse -Force
    } catch { $result.CleanupError = $_.Exception.Message; $result.Passed = $false }
  }
  $result.RootRemoved = !(Test-Path -LiteralPath $root)
  $result.ServiceRemoved = !(Test-Path -LiteralPath $serviceKey)
  $result.Checks = @($checks.ToArray())
  $client = [IO.Pipes.NamedPipeClientStream]::new('.', $ReportPipe, [IO.Pipes.PipeDirection]::Out, [IO.Pipes.PipeOptions]::None, [Security.Principal.TokenImpersonationLevel]::Identification)
  try {
    $client.Connect(10000)
    $writer = [IO.StreamWriter]::new($client, [Text.UTF8Encoding]::new($false), 4096, $true)
    try { $writer.WriteLine(($result | ConvertTo-Json -Depth 5 -Compress)); $writer.Flush() }
    finally { $writer.Dispose() }
  } finally { $client.Dispose() }
}
if (!$result.Passed) { exit 1 }
