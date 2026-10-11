; SPDX-License-Identifier: GPL-3.0-or-later
#ifndef StageDir
  #error StageDir is required
#endif
#ifndef AppVersion
  #error AppVersion is required
#endif
#ifndef OutputPath
  #define OutputPath "..\build\installer"
#endif

[Setup]
AppId={{C9DE0FA9-DB41-4D08-B236-D7747D54C844}
AppName=AORA Connect
AppVersion={#AppVersion}
AppPublisher=AORA Connect
AppPublisherURL=https://github.com/khitori/AORA-Connect
DefaultDirName={localappdata}\AORAConnect
DisableDirPage=yes
DisableProgramGroupPage=yes
UsePreviousAppDir=no
PrivilegesRequired=lowest
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
AppMutex=Local\AORAConnectApp,Local\AORAConnectPortableLaunch
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
Name: "{userprograms}\AORA Connect"; Filename: "{app}\app\aoravpn.exe"; WorkingDir: "{app}\app"
Name: "{userdesktop}\AORA Connect"; Filename: "{app}\app\aoravpn.exe"; WorkingDir: "{app}\app"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\AORAConnect"; ValueType: string; ValueName: "Version"; ValueData: "{#AppVersion}"; Flags: uninsdeletekey

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

function PrepareToInstall(var NeedsRestart: Boolean): String;
var Existing: AnsiString; OldVersion, NewVersion: Int64;
begin
  Result := '';
#ifndef TestInstall
  if CompareText(RemoveBackslash(ExpandConstant('{app}')), RemoveBackslash(ExpandConstant('{localappdata}\AORAConnect'))) <> 0 then
    Result := 'AORA Connect uses its existing local application folder. A custom installation folder is not supported.';
#endif
  if LoadStringFromFile(ExpandConstant('{app}\installed-version.txt'), Existing) then
    if StrToVersion(Trim(Existing), OldVersion) and StrToVersion('{#AppVersion}', NewVersion) then
      if ComparePackedVersion(OldVersion, NewVersion) > 0 then
        Result := 'A newer version is already installed. Downgrading would risk compatibility with your saved settings.';
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
    SaveStringToFile(ExpandConstant('{app}\installed-version.txt'), '{#AppVersion}', False);
end;

function InitializeUninstall(): Boolean;
var Form: TSetupForm; Description: TNewStaticText; Check: TNewCheckBox; Remove, Cancel: TNewButton;
begin
  DeleteUserData := False;
  Result := True;
  if UninstallSilent then Exit;
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

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if (CurUninstallStep = usPostUninstall) and DeleteUserData then begin
    { Delete only the named app-owned data folders, never the user's profile. }
    if CompareText(RemoveBackslash(ExpandConstant('{app}')), RemoveBackslash(ExpandConstant('{localappdata}\AORAConnect'))) = 0 then begin
      DelTree(ExpandConstant('{app}\settings'), True, True, True);
      DelTree(ExpandConstant('{app}\runtime'), True, True, True);
    end;
  end;
end;
