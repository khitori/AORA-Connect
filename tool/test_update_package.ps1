# SPDX-License-Identifier: GPL-3.0-or-later
param([string]$Package = '')
$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
if (!$Package) { $Package = Join-Path $project 'build/installer/AORAConnect-Setup.exe' }
$stage = (Get-Content -LiteralPath (Join-Path $project 'build/portable/stage-path.txt') -Raw).Trim()
$helper = Join-Path $stage 'app/aoravpn_update.exe'
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('aora-update-package-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture | Out-Null
function Verify-Package([string]$file) {
  $process = Start-Process -FilePath $helper -ArgumentList 'verify-package',('"' + $file + '"') -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput (Join-Path $fixture 'verified.json') -RedirectStandardError (Join-Path $fixture 'error.txt')
  return $process.ExitCode
}
if ((Verify-Package $Package) -ne 0) { throw 'Generated release package did not verify.' }
$altered = Join-Path $fixture 'altered.exe'
Copy-Item -LiteralPath $Package -Destination $altered
$file = [IO.File]::Open($altered, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite)
try { $byte = $file.ReadByte(); $file.Position = 0; $file.WriteByte($byte -bxor 1) } finally { $file.Dispose() }
if ((Verify-Package $altered) -eq 0) { throw 'Modified installer was accepted.' }
$invalid = Join-Path $fixture 'invalid.exe'
[IO.File]::WriteAllText($invalid, 'Not a signed update')
if ((Verify-Package $invalid) -eq 0) { throw 'Unsigned file was accepted.' }
Write-Output 'Signed package checks passed: valid installer accepted, tampered and unsigned files rejected.'
