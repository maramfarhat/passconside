; PASS AI Windows installer (Inno Setup 6)
; Compile via desktop/scripts/build-pass-ai-setup.ps1

#ifndef MyAppVersion
  #define MyAppVersion "0.1.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\VSCode-win32-x64"
#endif

[Setup]
AppId={{A7B3C4D5-E6F7-4890-ABCD-EF1234567890}
AppName=PASS AI
AppVerName=PASS AI {#MyAppVersion}
AppVersion={#MyAppVersion}
AppPublisher=PASS Consulting Group
AppPublisherURL=https://github.com/maramfarhat/passconside
AppSupportURL=https://github.com/maramfarhat/passconside/issues
AppUpdatesURL=https://github.com/maramfarhat/passconside/releases
DefaultDirName={autopf64}\PASS AI
DefaultGroupName=PASS AI
DisableProgramGroupPage=no
OutputDir=..\out\releases
OutputBaseFilename=PASS-AI-Setup-{#MyAppVersion}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
UninstallDisplayName=PASS AI {#MyAppVersion}
UninstallDisplayIcon={app}\PASS AI.exe
CloseApplications=force

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\PASS AI"; Filename: "{app}\PASS AI.exe"
Name: "{autodesktop}\PASS AI"; Filename: "{app}\PASS AI.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\PASS AI.exe"; Description: "{cm:LaunchProgram,PASS AI}"; Flags: nowait postinstall skipifsilent
