#define AppName "Excellence Academy"
#define AppVersion "1.0.0"
#define AppPublisher "Excellence Academy"
#define AppExeName "excellence.exe"
#define AppIcon "..\windows\runner\resources\app_icon.ico"
#define BuildDir "..\build\windows\x64\runner\Release"
#define VcRedistExe "vc_redist.x64.exe"

[Setup]
AppId={{8C36F6CD-9E11-4AE0-BBCF-2E7B18C62B24}}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppVerName={#AppName} {#AppVersion}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
OutputDir={#SourcePath}\output
OutputBaseFilename=ExcellenceAcademy-Setup
Compression=lzma
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#AppExeName}
SetupIconFile={#AppIcon}
WizardStyle=modern
MinVersion=10.0
PrivilegesRequired=adminJL

[Tasks]
Name: "desktopicon"; Description: "Create a Desktop icon"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion
Source: "{#SourcePath}\{#VcRedistExe}"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{commondesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{tmp}\{#VcRedistExe}"; Parameters: "/install /passive /norestart"; StatusMsg: "Installing Microsoft Visual C++ Runtime..."; Flags: waituntilterminated runhidden
