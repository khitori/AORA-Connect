; SPDX-License-Identifier: GPL-3.0-or-later
[Setup]
AppName=AORA installer overlay probe
AppVersion=1.0
DefaultDirName={tmp}\AORA-overlay-probe
PrivilegesRequired=lowest
Uninstallable=no
CreateUninstallRegKey=no
OutputDir=..\build\installer-probe
OutputBaseFilename=overlay-probe
DisableDirPage=yes
DisableProgramGroupPage=yes
[Files]
Source: "..\LICENSE"; DestDir: "{app}"
