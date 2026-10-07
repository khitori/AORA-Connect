# SPDX-License-Identifier: GPL-3.0-or-later
$ErrorActionPreference = 'Stop'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $powershellPath = (Get-Process -Id $PID).Path
    Start-Process -FilePath $powershellPath -Verb RunAs -ArgumentList @(
        '-NoProfile', '-NoExit', '-ExecutionPolicy', 'Bypass', '-File',
        ('"{0}"' -f $PSCommandPath)
    )
    exit
}
Set-Location -LiteralPath (Split-Path -Parent $PSScriptRoot)
flutter run -d windows
