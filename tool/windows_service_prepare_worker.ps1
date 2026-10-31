# SPDX-License-Identifier: GPL-3.0-or-later
param(
  [Parameter(Mandatory)][string]$Manifest,
  [Parameter(Mandatory)][ValidatePattern('^AORAConnectPrepare-[0-9a-f]{32}$')][string]$ReportPipe
)
$ErrorActionPreference = 'Stop'
foreach ($module in @('Microsoft.PowerShell.Utility','Microsoft.PowerShell.Management','Microsoft.PowerShell.Security')) {
  Import-Module (Join-Path $PSHOME "Modules/$module/$module.psd1") -ErrorAction Stop
}
$root = Join-Path ([Environment]::GetFolderPath('ProgramFiles')) 'AORAConnect'
$app = Join-Path $root 'app'
$helper = Join-Path $app 'aoravpn_service.exe'
$serviceKey = 'HKLM:\SYSTEM\CurrentControlSet\Services\AORAConnectService'
$result = @{ Passed=$false; Error=$null }
$locks = [Collections.Generic.List[Threading.Mutex]]::new()
$original = @{}
$written = [Collections.Generic.List[string]]::new()
$hadService = $false
$wasRunning = $false
$registrationAttempted = $false

function Assert-Protected([string]$path) {
  $item = Get-Item -LiteralPath $path -Force
  if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Service preparation refuses links: $path" }
  $acl = Get-Acl -LiteralPath $path
  $trusted = @('S-1-5-18','S-1-5-32-544','S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464')
  if ($acl.GetOwner([Security.Principal.SecurityIdentifier]).Value -notin $trusted) { throw "The installed path has an untrusted owner: $path" }
  $writes = [long][Security.AccessControl.FileSystemRights]::Write -bor [long][Security.AccessControl.FileSystemRights]::Delete -bor [long][Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles -bor [long][Security.AccessControl.FileSystemRights]::ChangePermissions -bor [long][Security.AccessControl.FileSystemRights]::TakeOwnership -bor 0x50000000
  foreach ($rule in $acl.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier])) {
    if (($rule.PropagationFlags -band [Security.AccessControl.PropagationFlags]::InheritOnly) -ne 0) { continue }
    if ($rule.AccessControlType -eq 'Allow' -and $rule.IdentityReference.Value -notin $trusted -and ([long]$rule.FileSystemRights -band $writes) -ne 0) {
      throw "An unprivileged account can modify the installed path: $path"
    }
  }
}

function Invoke-Helper([string]$command, [string]$body = '') {
  $startup = [Diagnostics.ProcessStartInfo]::new($helper, $command)
  $startup.UseShellExecute = $false
  $startup.CreateNoWindow = $true
  $startup.RedirectStandardOutput = $true
  $startup.RedirectStandardError = $true
  $startup.RedirectStandardInput = $body -ne ''
  $process = [Diagnostics.Process]::Start($startup)
  try {
    $output = $process.StandardOutput.ReadToEndAsync()
    $errors = $process.StandardError.ReadToEndAsync()
    if ($body -ne '') { $process.StandardInput.Write($body); $process.StandardInput.Close() }
    if (!$process.WaitForExit(35000)) { $process.Kill(); $process.WaitForExit(); throw "Service preparation timed out: $command" }
    $text = $output.GetAwaiter().GetResult()
    if ($process.ExitCode -ne 0) { throw "Service command failed ($command): $($errors.GetAwaiter().GetResult())" }
    return $text
  } finally { $process.Dispose() }
}

try {
  foreach ($name in @('Local\AORAConnectApp','Local\AORAConnectPortableLaunch','Global\AORAConnectServicePreparation')) {
    $created = $false
    $mutex = [Threading.Mutex]::new($false, $name, [ref]$created)
    $locks.Add($mutex)
    if (!$created) { throw 'Close AORA Connect (including its tray icon) and any other installer/development preparation, then rebuild.' }
  }
  foreach ($path in @($root,$app,(Join-Path $app 'aoravpn.exe'),(Join-Path $root 'cores'),(Join-Path $root 'cores/windows'))) { Assert-Protected $path }
  foreach ($core in @('sing-box-1.14.2-windows-amd64/sing-box.exe','xray-v26.9.30-windows-64/xray.exe')) {
    $path = Join-Path $root ('cores/windows/' + $core)
    Assert-Protected (Split-Path $path -Parent)
    Assert-Protected $path
  }
  $assets = ConvertFrom-Json -InputObject $Manifest
  $names = @('aoravpn_service.exe','aoravpn_core_host.exe','aoravpn_core_console.exe')
  if ($assets.Count -ne $names.Count -or @($assets.Name | Select-Object -Unique).Count -ne $names.Count) { throw 'Invalid service preparation manifest.' }
  $pending = @{}
  foreach ($asset in $assets) {
    if ($asset.Name -cnotin $names -or $asset.Hash -cnotmatch '^[0-9a-f]{64}$') { throw 'Invalid service preparation asset.' }
    $bytes = [IO.File]::ReadAllBytes($asset.Source)
    if ($bytes.Length -eq 0 -or $bytes.Length -gt 33554432) { throw 'Service helper size limit exceeded.' }
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $hash = ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLowerInvariant() } finally { $sha.Dispose() }
    if ($hash -cne $asset.Hash) { throw 'Native helper changed before administrator approval. Rebuild.' }
    $pending[$asset.Name] = $bytes
    $destination = Join-Path $app $asset.Name
    if (Test-Path -LiteralPath $destination) {
      Assert-Protected $destination
      $original[$asset.Name] = [IO.File]::ReadAllBytes($destination)
    } else { $original[$asset.Name] = $null }
  }
  $hadService = Test-Path -LiteralPath $serviceKey
  if ($hadService) {
    if (!(Test-Path -LiteralPath $helper)) { throw 'The installed service helper is missing. Repair the installation first.' }
    $service = Get-Service -Name AORAConnectService
    $wasRunning = $service.Status -ne 'Stopped'
    if ($wasRunning) {
      $status = (Invoke-Helper 'request' '{"protocol":1,"command":"status","cursor":0}') | ConvertFrom-Json
      if (!$status.ok -or $status.snapshot.state -ne 'stopped' -or $status.snapshot.issued -ne $status.snapshot.completed) { throw 'Disconnect the VPN before updating the shared service.' }
    }
    Invoke-Helper 'stop' | Out-Null
  }
  try {
    foreach ($name in $names) {
      $written.Add($name)
      [IO.File]::WriteAllBytes((Join-Path $app $name), $pending[$name])
      Assert-Protected (Join-Path $app $name)
    }
    $identity = (Invoke-Helper 'installation-info') | ConvertFrom-Json
    if ($identity.root -cne $root -or $identity.service -cne 'AORAConnectService' -or $identity.protocol -ne 1 -or $identity.fixture -ne $false) { throw 'The built helper is not a production Windows service.' }
    $registrationAttempted = $true
    Invoke-Helper 'install' | Out-Null
    $result.Passed = $true
  } catch {
    $failure = $_.Exception.Message
    try {
      if ($registrationAttempted) { Invoke-Helper $(if ($hadService) { 'stop' } else { 'remove' }) | Out-Null }
      foreach ($name in $written) {
        $destination = Join-Path $app $name
        if ($null -eq $original[$name]) { Remove-Item -LiteralPath $destination -Force }
        else { [IO.File]::WriteAllBytes($destination, $original[$name]) }
      }
      if ($hadService -and $wasRunning) { Invoke-Helper 'start' | Out-Null }
    } catch { throw "$failure Rollback could not finish: $($_.Exception.Message). Repair the installation before continuing." }
    throw $failure
  }
} catch { $result.Error = $_.Exception.Message }
finally {
  foreach ($mutex in $locks) { $mutex.Dispose() }
  $pipe = [IO.Pipes.NamedPipeClientStream]::new('.', $ReportPipe, [IO.Pipes.PipeDirection]::Out)
  try {
    $pipe.Connect(10000)
    $writer = [IO.StreamWriter]::new($pipe, [Text.UTF8Encoding]::new($false), 4096, $true)
    try { $writer.WriteLine(($result | ConvertTo-Json -Compress)); $writer.Flush() } finally { $writer.Dispose() }
  } finally { $pipe.Dispose() }
}
if (!$result.Passed) { exit 1 }
