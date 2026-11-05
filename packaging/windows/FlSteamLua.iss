#ifndef AppVersion
  #define AppVersion "0.1.5"
#endif
#ifndef BuildDir
  #define BuildDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\dist"
#endif

[Setup]
AppId={{BC0671F5-7DAE-4095-B54E-E4946C171678}
AppName=FlSteamLua
AppVersion={#AppVersion}
AppPublisher=FlSteamLua contributors
DefaultDirName={localappdata}\Programs\FlSteamLua
DefaultGroupName=FlSteamLua
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename=FlSteamLua-{#AppVersion}-windows-x64-setup
SetupIconFile=..\..\assets\branding\app.ico
UninstallDisplayIcon={app}\fl_steam_lua.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=no
RestartApplications=no
LicenseFile=..\..\LICENSE

[Languages]
Name: "chinesesimp"; MessagesFile: "ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; Flags: unchecked

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\FlSteamLua"; Filename: "{app}\fl_steam_lua.exe"
Name: "{autodesktop}\FlSteamLua"; Filename: "{app}\fl_steam_lua.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\fl_steam_lua.exe"; Description: "{cm:LaunchProgram,FlSteamLua}"; Flags: nowait postinstall skipifsilent

[Code]
procedure KillApplicationProcess(const ImageName: String);
var
  ResultCode: Integer;
begin
  Exec(
    ExpandConstant('{sys}\taskkill.exe'),
    '/F /T /IM ' + ImageName,
    '',
    SW_HIDE,
    ewWaitUntilTerminated,
    ResultCode
  );
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  NeedsRestart := False;
  KillApplicationProcess('fl_steam_lua.exe');
  KillApplicationProcess('steam_worker.exe');
  KillApplicationProcess('lan_transfer_engine.exe');
  Sleep(300);
  Result := '';
end;
