; SPDX-License-Identifier: GPL-3.0-or-later
#ifndef StageDir
  #error StageDir is required
#endif
#ifndef AppVersion
  #error AppVersion is required
#endif
#ifndef BuildVersion
  #define BuildVersion AppVersion
#endif
#ifndef OutputPath
  #define OutputPath "..\build\installer"
#endif

[Setup]
AppId={{C9DE0FA9-DB41-4D08-B236-D7747D54C844}
AppName=AORA Connect
AppVersion={#AppVersion}
VersionInfoVersion={#BuildVersion}
AppPublisher=AORA Connect
AppPublisherURL=https://github.com/khitori/AORA-Connect
#ifdef MigrationFixtureRoot
DefaultDirName={#MigrationFixtureRoot}\installed
#else
DefaultDirName={autopf64}\AORAConnect
#endif
DisableDirPage=yes
DisableProgramGroupPage=yes
UsePreviousAppDir=no
#ifdef TestInstall
PrivilegesRequired=lowest
#else
PrivilegesRequired=admin
#endif
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
UninstallFilesDir={app}\uninstall
UninstallDisplayIcon={app}\app\aoravpn.exe
SetupIconFile=..\windows\runner\resources\app_icon.ico
LicenseFile=..\LICENSE
OutputDir={#OutputPath}
OutputBaseFilename=AORAConnect-Setup
Compression=lzma2
SolidCompression=yes
CloseApplications=no
RestartApplications=no
#ifndef TestInstall
AppMutex=Local\AORAConnectApp,Local\AORAConnectPortableLaunch
#endif
WizardStyle=modern
#ifdef TestInstall
CreateUninstallRegKey=no
#endif

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; Flags: unchecked

[Files]
Source: "{#StageDir}\app\*"; DestDir: "{app}\app"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#StageDir}\cores\*"; DestDir: "{app}\cores"; Flags: ignoreversion recursesubdirs createallsubdirs

#ifndef TestInstall
[Icons]
Name: "{commonprograms}\AORA Connect"; Filename: "{app}\app\aoravpn.exe"; WorkingDir: "{app}\app"
Name: "{commondesktop}\AORA Connect"; Filename: "{app}\app\aoravpn.exe"; WorkingDir: "{app}\app"; Tasks: desktopicon; Check: not LegacyDesktopShortcutExists
Name: "{userdesktop}\AORA Connect"; Filename: "{app}\app\aoravpn.exe"; WorkingDir: "{app}\app"; Check: LegacyDesktopShortcutExists

[Registry]
Root: HKLM; Subkey: "Software\AORAConnect"; ValueType: string; ValueName: "Version"; ValueData: "{#AppVersion}"; Flags: uninsdeletekey

[Run]
Filename: "{app}\app\aoravpn.exe"; Description: "Open AORA Connect"; Flags: postinstall nowait skipifsilent shellexec
#endif

[UninstallDelete]
Type: filesandordirs; Name: "{app}\app"
Type: filesandordirs; Name: "{app}\cores"
Type: files; Name: "{app}\installed-version.txt"

[Code]
var
  DeleteUserData: Boolean;
  LegacyRoot: String;
  MigratedSettings: Boolean;
  LegacyHandoff: Boolean;

#ifndef TestInstall
function ServiceCommand(const Command: String; const Required: Boolean): String;
var Helper: String; Code: Integer;
begin
  Result := '';
  Helper := ExpandConstant('{app}\app\aoravpn_service.exe');
  if not FileExists(Helper) then begin
    if Required or RegKeyExists(HKLM, 'SYSTEM\CurrentControlSet\Services\AORAConnectService') then
      Result := 'The AORA Connect service executable is missing. Repair the installation before continuing.';
    Exit;
  end;
  if not Exec(Helper, Command, ExpandConstant('{app}\app'), SW_HIDE, ewWaitUntilTerminated, Code) then
    Result := 'Could not launch the AORA Connect service manager.'
  else if Code <> 0 then
    Result := 'Could not ' + Command + ' the AORA Connect service (exit ' + IntToStr(Code) + '). Installation was stopped to protect existing files.';
  Log('Service ' + Command + ': ' + Result);
end;
#endif

function LegacyDesktopShortcutExists(): Boolean;
begin
  Result := (LegacyRoot <> '') and DirExists(LegacyRoot + '\app') and FileExists(ExpandConstant('{userdesktop}\AORA Connect.lnk'));
end;

function SafeDirectory(const Path: String): Boolean;
var Find: TFindRec;
begin
  Result := not DirExists(Path);
  if not DirExists(Path) then Exit;
  if not FindFirst(Path, Find) then Exit;
  try
    Result := (Find.Attributes and FILE_ATTRIBUTE_REPARSE_POINT) = 0;
  finally FindClose(Find); end;
end;

function CopyLegacySettings(): Boolean;
var Names: TArrayOfString; I: Integer; Source, Target: String;
begin
  Result := False;
  if not DirExists(LegacyRoot) then Exit;
  if not SafeDirectory(LegacyRoot) or not SafeDirectory(LegacyRoot + '\settings') then
    RaiseException('Legacy application storage contains a directory link. Migration was cancelled.');
  Names := ['app-state.json', 'language.json', 'updates.json'];
  ForceDirectories(ExpandConstant('{app}\settings'));
  Result := True;
  for I := 0 to GetArrayLength(Names) - 1 do begin
    Source := LegacyRoot + '\settings\' + Names[I];
    Target := ExpandConstant('{app}\settings\') + Names[I];
    if FileExists(Source) then begin
      if not FileExists(Target) and not CopyFile(Source, Target, True) then
        RaiseException('Could not migrate ' + Names[I] + '. The original settings were kept.');
      if GetSHA256OfFile(Source) <> GetSHA256OfFile(Target) then Result := False;
    end;
  end;
end;

function RemoveLegacyTree(const Path: String): Boolean;
var Find: TFindRec; Child: String;
begin
  Result := True;
  if not DirExists(Path) then Exit;
  if not SafeDirectory(Path) then begin Result := False; Exit; end;
  if FindFirst(Path + '\*', Find) then begin
    try
      repeat
        if (Find.Name <> '.') and (Find.Name <> '..') then begin
          Child := Path + '\' + Find.Name;
          if (Find.Attributes and FILE_ATTRIBUTE_REPARSE_POINT) <> 0 then Result := False
          else if (Find.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0 then begin
            if not RemoveLegacyTree(Child) then Result := False;
          end else if not DeleteFile(Child) then Result := False;
        end;
      until not FindNext(Find);
    finally FindClose(Find); end;
  end;
  if Result then Result := RemoveDir(Path);
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var Existing: AnsiString; OldVersion, NewVersion: Int64;
begin
  Result := '';
#ifndef TestInstall
  if CompareText(RemoveBackslash(ExpandConstant('{app}')), RemoveBackslash(ExpandConstant('{autopf64}\AORAConnect'))) <> 0 then begin
    Result := 'AORA Connect must be installed in Program Files. A custom installation folder is not supported.';
    Exit;
  end;
  LegacyRoot := ExpandConstant('{localappdata}\AORAConnect');
  LegacyHandoff := WizardSilent and DirExists(LegacyRoot + '\app');
#else
#ifdef MigrationFixtureRoot
  LegacyRoot := '{#MigrationFixtureRoot}\profile\Local\AORAConnect';
  LegacyHandoff := WizardSilent and DirExists(LegacyRoot + '\app');
#else
  LegacyRoot := ExpandConstant('{param:LEGACYROOT|}');
#endif
#endif
  if LoadStringFromFile(ExpandConstant('{app}\installed-version.txt'), Existing) then
    if StrToVersion(Trim(Existing), OldVersion) and StrToVersion('{#BuildVersion}', NewVersion) then
      if ComparePackedVersion(OldVersion, NewVersion) > 0 then
        Result := 'A newer version is already installed. Downgrading would risk compatibility with your saved settings.';
  if (LegacyRoot <> '') and LoadStringFromFile(LegacyRoot + '\installed-version.txt', Existing) then
    if StrToVersion(Trim(Existing), OldVersion) and StrToVersion('{#BuildVersion}', NewVersion) then
      if ComparePackedVersion(OldVersion, NewVersion) > 0 then
        Result := 'The previous installation is newer. Migration would downgrade your saved settings.';
  if (Result = '') and (LegacyRoot <> '') then
    MigratedSettings := CopyLegacySettings();
#ifndef TestInstall
  if Result = '' then Result := ServiceCommand('stop', False);
#endif
end;

procedure CurStepChanged(CurStep: TSetupStep);
var Code: Integer; Location: String;
begin
  if CurStep = ssPostInstall then begin
    SaveStringToFile(ExpandConstant('{app}\installed-version.txt'), '{#BuildVersion}', False);
#ifndef TestInstall
    if not ForceDirectories(ExpandConstant('{app}\runtime')) then RaiseException('Could not create runtime storage.');
    if not ForceDirectories(ExpandConstant('{app}\settings')) then RaiseException('Could not create settings storage.');
    if not Exec(ExpandConstant('{sys}\icacls.exe'), '"' + ExpandConstant('{app}\settings') + '" /inheritance:r /grant:r "*S-1-5-18:(OI)(CI)F" "*S-1-5-32-544:(OI)(CI)F"', '', SW_HIDE, ewWaitUntilTerminated, Code) or (Code <> 0) then RaiseException('Could not protect settings storage.');
    if not Exec(ExpandConstant('{sys}\icacls.exe'), '"' + ExpandConstant('{app}\runtime') + '" /inheritance:r /grant:r "*S-1-5-18:(OI)(CI)F" "*S-1-5-32-544:(OI)(CI)F"', '', SW_HIDE, ewWaitUntilTerminated, Code) or (Code <> 0) then RaiseException('Could not protect runtime storage.');
    Location := ServiceCommand('install', True);
    if Location <> '' then RaiseException(Location);
#endif
    if LegacyHandoff then begin
      if not SafeDirectory(LegacyRoot) or not SafeDirectory(LegacyRoot + '\app') then
        RaiseException('Legacy launcher storage contains a directory link.');
      if not FileExists(LegacyRoot + '\app\aoravpn.migration-backup.exe') and
         not CopyFile(LegacyRoot + '\app\aoravpn.exe', LegacyRoot + '\app\aoravpn.migration-backup.exe', True) then
        RaiseException('Could not preserve the previous client for migration rollback.');
      if not CopyFile(ExpandConstant('{app}\app\aoravpn_migrate.exe'), LegacyRoot + '\app\aoravpn.exe', False) then
        RaiseException('Could not prepare the legacy updater handoff. Settings were retained.');
    end else if MigratedSettings then begin
      if not SafeDirectory(LegacyRoot) then RaiseException('Legacy storage changed during migration.');
      if not RemoveLegacyTree(LegacyRoot + '\app') then Log('Some legacy application files are still in use.');
      if not RemoveLegacyTree(LegacyRoot + '\cores') then Log('Some legacy core files are still in use.');
      if not RemoveLegacyTree(LegacyRoot + '\runtime') then Log('Some legacy runtime files are still in use.');
      if not RemoveLegacyTree(LegacyRoot + '\uninstall') then Log('Some legacy uninstall files are still in use.');
      DeleteFile(LegacyRoot + '\settings\app-state.json');
      DeleteFile(LegacyRoot + '\settings\language.json');
      DeleteFile(LegacyRoot + '\settings\updates.json');
      RemoveDir(LegacyRoot + '\settings');
      DeleteFile(LegacyRoot + '\installed-version.txt');
#ifndef TestInstall
      DeleteFile(ExpandConstant('{userprograms}\AORA Connect.lnk'));
      if RegQueryStringValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{C9DE0FA9-DB41-4D08-B236-D7747D54C844}_is1', 'InstallLocation', Location) and (CompareText(RemoveBackslash(Location), RemoveBackslash(LegacyRoot)) = 0) then
        RegDeleteKeyIncludingSubkeys(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{C9DE0FA9-DB41-4D08-B236-D7747D54C844}_is1');
      RegDeleteKeyIncludingSubkeys(HKCU, 'Software\AORAConnect');
#endif
      RemoveDir(LegacyRoot);
    end;
  end;
end;

function InitializeUninstall(): Boolean;
var Form: TSetupForm; Description: TNewStaticText; Check: TNewCheckBox; Remove, Cancel: TNewButton; ServiceError: String;
begin
  DeleteUserData := False;
  Result := True;
  if not UninstallSilent then begin
  Form := CreateCustomForm(ScaleX(380), ScaleY(150), False, False);
  try
    Form.Caption := 'Uninstall AORA Connect';
    Description := TNewStaticText.Create(Form); Description.Parent := Form;
    Description.SetBounds(ScaleX(16), ScaleY(16), ScaleX(348), ScaleY(40));
    Description.Caption := 'Remove AORA Connect and its networking cores? Your saved data is kept unless selected below.';
    Description.AutoSize := False; Description.WordWrap := True;
    Check := TNewCheckBox.Create(Form); Check.Parent := Form;
    Check.SetBounds(ScaleX(16), ScaleY(64), ScaleX(348), ScaleY(24));
    Check.Caption := 'Delete settings, subscriptions and routing rules';
    Remove := TNewButton.Create(Form); Remove.Parent := Form;
    Remove.SetBounds(ScaleX(190), ScaleY(108), ScaleX(80), ScaleY(26));
    Remove.Caption := 'Uninstall'; Remove.ModalResult := mrOk;
    Cancel := TNewButton.Create(Form); Cancel.Parent := Form;
    Cancel.SetBounds(ScaleX(282), ScaleY(108), ScaleX(80), ScaleY(26));
    Cancel.Caption := 'Cancel'; Cancel.ModalResult := mrCancel; Cancel.Cancel := True;
    Result := Form.ShowModal = mrOk;
    DeleteUserData := Result and Check.Checked;
  finally Form.Free; end;
  end;
#ifndef TestInstall
  if Result then begin
    ServiceError := ServiceCommand('startup-remove', False);
    if ServiceError = '' then ServiceError := ServiceCommand('remove', False);
    if ServiceError <> '' then begin
      Result := False;
      Log(ServiceError);
      if not UninstallSilent then MsgBox(ServiceError, mbError, MB_OK);
    end;
  end;
#endif
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if (CurUninstallStep = usPostUninstall) and DeleteUserData then begin
    if CompareText(RemoveBackslash(ExpandConstant('{app}')), RemoveBackslash(ExpandConstant('{autopf64}\AORAConnect'))) = 0 then begin
      DelTree(ExpandConstant('{app}\settings'), True, True, True);
      DelTree(ExpandConstant('{app}\runtime'), True, True, True);
    end;
  end;
end;
