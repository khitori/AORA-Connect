# Compare Windows default-route ICMP with the physical-source helper.
# This test owns its core process and closes it in finally.
param([Parameter(Mandatory=$true)][string]$ConfigPath)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskReportPath = Join-Path $taskRoot '.dart_tool/ping-route-check.json'
$taskReport = [ordered]@{}
$taskProcess = $null
try {
    if (Get-Process -Name sing-box,xray -ErrorAction SilentlyContinue) {
        throw 'A networking core is already running. Stop the app connection before this controlled test.'
    }
    $taskConfigPath = (Resolve-Path -LiteralPath $ConfigPath).Path
    $taskConfig = Get-Content -LiteralPath $taskConfigPath -Raw | ConvertFrom-Json
    $taskTarget = $taskConfig.outbounds[0].server
    if (!$taskTarget) { throw 'This diagnostic expects a sing-box runtime config.' }
    $taskBuild = Join-Path $taskRoot 'build/windows/x64/runner/Debug'
    $taskCore = Join-Path $taskRoot 'cores/windows/sing-box-1.14.2-windows-amd64/sing-box.exe'
    $taskProbe = Join-Path $taskBuild 'aoravpn_server_ping.exe'
    $taskReport.target = $taskTarget
    $taskReport.disconnectedMs = (& $taskProbe $taskTarget | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Disconnected server ping failed.' }
    $taskStart = [Diagnostics.ProcessStartInfo]::new()
    $taskStart.FileName = Join-Path $taskBuild 'aoravpn_core_host.exe'
    $taskStart.ArgumentList.Add($taskCore)
    $taskStart.ArgumentList.Add($taskConfigPath)
    $taskStart.WorkingDirectory = Split-Path -Parent $taskCore
    $taskStart.UseShellExecute = $false
    $taskStart.CreateNoWindow = $true
    $taskStart.RedirectStandardInput = $true
    $taskStart.RedirectStandardOutput = $true
    $taskStart.RedirectStandardError = $true
    $taskProcess = [Diagnostics.Process]::Start($taskStart)
    $taskStdout = $taskProcess.StandardOutput.ReadToEndAsync()
    $taskStderr = $taskProcess.StandardError.ReadToEndAsync()
    $taskDeadline = [DateTime]::UtcNow.AddSeconds(15)
    do {
        if ($taskProcess.HasExited) { throw 'Core exited before its tunnel became available.' }
        $taskTun = Get-NetIPAddress -IPAddress '172.29.0.1' -ErrorAction SilentlyContinue
        if ($taskTun) { break }
        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $taskDeadline)
    if (!$taskTun) { throw 'TUN adapter was not created.' }
    $taskReport.connectedWindowsPing = (& "$env:SystemRoot\System32\PING.EXE" -n 2 -w 2000 $taskTarget | Out-String).Trim()
    $taskReport.connectedPhysicalMs = (& $taskProbe $taskTarget | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Physical-source ping failed with TUN active.' }
    $taskReport.success = $true
} catch {
    $taskReport.success = $false
    $taskReport.error = $_.Exception.Message
} finally {
    if ($taskProcess -and !$taskProcess.HasExited) {
        $taskProcess.StandardInput.WriteLine('stop')
        $taskProcess.StandardInput.Flush()
        if (!$taskProcess.WaitForExit(12000)) { $taskProcess.Kill($true); $taskProcess.WaitForExit() }
    }
    if ($taskProcess) { $taskProcess.Dispose() }
    $taskReport.tunRemoved = !(Get-NetIPAddress -IPAddress '172.29.0.1' -ErrorAction SilentlyContinue)
    $taskReport | ConvertTo-Json | Set-Content -LiteralPath $taskReportPath -Encoding utf8
}
