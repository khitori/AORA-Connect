# SPDX-License-Identifier: GPL-3.0-or-later
$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$compiler = 'C:/Program Files (x86)/Inno Setup 6/ISCC.exe'
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('aora-installer-test-' + [guid]::NewGuid().ToString('N'))
$stage = Join-Path $fixture 'stage'
$installation = Join-Path $fixture 'installed'
New-Item -ItemType Directory -Path (Join-Path $stage 'app'),(Join-Path $stage 'cores/windows'),(Join-Path $installation 'settings') -Force | Out-Null
# Inert fixture files; no app or VPN core is executed.
Copy-Item -LiteralPath (Join-Path $project 'LICENSE') -Destination (Join-Path $stage 'app/fixture.txt')
Copy-Item -LiteralPath (Join-Path $project 'LICENSE') -Destination (Join-Path $stage 'cores/windows/fixture.txt')
$saved = Join-Path $installation 'settings/app-state.json'
[IO.File]::WriteAllText($saved, '{"fixture":"preserve"}')
function Run-FixtureInstaller([string]$path) {
  $process = Start-Process -FilePath $path -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART',('/DIR="' + $installation + '"') -WindowStyle Hidden -PassThru -Wait
  return $process.ExitCode
}
Push-Location $project
try {
  foreach ($version in @('1.0.0.1','1.0.0.2')) {
    $output = Join-Path $fixture $version
    & $compiler /Q /DTestInstall=1 "/DStageDir=$stage" "/DAppVersion=$version" "/DOutputPath=$output" 'installer/aora.iss'
    if ($LASTEXITCODE -ne 0) { throw 'Fixture installer did not compile.' }
    if ((Run-FixtureInstaller (Join-Path $output 'AORAConnect-Setup.exe')) -ne 0) { throw "Fixture installation failed: $version" }
    if (!(Test-Path -LiteralPath (Join-Path $installation 'cores/windows/fixture.txt'))) { throw 'Installer did not preserve the Windows core subdirectory.' }
    if ([IO.File]::ReadAllText($saved) -ne '{"fixture":"preserve"}') { throw 'Saved settings were changed.' }
    if ([IO.File]::ReadAllText((Join-Path $installation 'installed-version.txt')) -ne $version) { throw 'Installation version was not updated.' }
  }
  if ((Run-FixtureInstaller (Join-Path $fixture '1.0.0.1/AORAConnect-Setup.exe')) -eq 0) { throw 'Downgrade was accepted.' }
  $uninstall = Join-Path $installation 'uninstall/unins000.exe'
  $removed = Start-Process -FilePath $uninstall -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART' -WindowStyle Hidden -PassThru -Wait
  if ($removed.ExitCode -ne 0) { throw 'Fixture uninstall failed.' }
  if (!(Test-Path -LiteralPath $saved) -or [IO.File]::ReadAllText($saved) -ne '{"fixture":"preserve"}') { throw 'Uninstall removed saved settings.' }
  if (Test-Path -LiteralPath (Join-Path $installation 'app')) { throw 'Uninstall left application files.' }
  if (Test-Path -LiteralPath (Join-Path $installation 'cores')) { throw 'Uninstall left core files.' }
  Write-Output 'Installer checks passed: fresh install, upgrade, downgrade rejection and uninstall with data retention.'
  Write-Output "Isolated fixture: $fixture"
} finally { Pop-Location }
