; 0rhxPlayer Inno Setup Script
; Generates Windows x64 modern installer with multi-language support, desktop shortcut, and clean uninstall

#define MyAppName "0rhxPlayer"
#define MyAppVersion "1.1.0"
#define MyAppPublisher "RinCynar"
#define MyAppURL "https://0rhxplayer.rincynar.top"
#define MyAppExeName "0rhxPlayer.exe"

#ifndef AppId
  #define MyAppId "{{C47683C0-562D-4E15-9988-75176F73F50F}}"
#endif

#ifndef SourceDir
  #define SourceDir "..\dist\0rhxPlayer"
#endif

#ifndef OutputDir
  #define OutputDir "..\dist"
#endif

#ifndef OutputBaseFilename
  #define OutputBaseFilename "0rhxPlayer-v1.1.0-windows-x64-setup"
#endif

[Setup]
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} v{#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir={#OutputDir}
OutputBaseFilename={#OutputBaseFilename}
SetupIconFile=..\assets\icons\app.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
CloseApplications=yes
RestartApplications=no
VersionInfoVersion=1.1.0.0
VersionInfoCompany=RinCynar
VersionInfoDescription=0rhxPlayer Setup
VersionInfoProductName=0rhxPlayer
VersionInfoProductVersion=1.1.0.0
VersionInfoCopyright=Copyright (C) 2026 RinCynar

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"
Name: "japanese"; MessagesFile: "compiler:Languages\Japanese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
