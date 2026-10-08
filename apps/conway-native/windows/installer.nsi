Unicode true
!include "MUI2.nsh"
!include "x64.nsh"
!include "WinVer.nsh"

!ifndef PAYLOAD
  !error "Pass -DPAYLOAD=<approved Windows executable>"
!endif
!ifndef OUTPUT
  !error "Pass -DOUTPUT=<installer output path>"
!endif
!ifndef NOTICES
  !error "Pass -DNOTICES=<third-party notices directory>"
!endif

!define APP_NAME "Conway's Game Of Life Lab"
!define APP_EXE "Conways-Game-of-Life-Lab-3.2-testing.exe"
!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\NithiConwayLifeLabNative"

Name "${APP_NAME}"
OutFile "${OUTPUT}"
InstallDir "$LOCALAPPDATA\Programs\Conway's Game Of Life Lab"
InstallDirRegKey HKCU "${UNINSTALL_KEY}" "InstallLocation"
RequestExecutionLevel user
SetCompressor /SOLID lzma
SetCompressorDictSize 32
VIProductVersion "3.0.0.0"
VIAddVersionKey "ProductName" "${APP_NAME}"
VIAddVersionKey "FileDescription" "Conway's Game Of Life Lab v3.0 Setup"
VIAddVersionKey "CompanyName" "Nithilan Vivek"
VIAddVersionKey "LegalCopyright" "Copyright 2026 Nithilan Vivek"
VIAddVersionKey "FileVersion" "3.0.0.0"
Icon "AppIcon.ico"
UninstallIcon "AppIcon.ico"

!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN "$INSTDIR\${APP_EXE}"
!define MUI_FINISHPAGE_RUN_NOTCHECKED
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Function .onInit
  ${IfNot} ${AtLeastWin10}
    MessageBox MB_OK|MB_ICONSTOP "This app requires Windows 10 or later."
    Abort
  ${EndIf}
  ${IfNot} ${RunningX64}
    MessageBox MB_OK|MB_ICONSTOP "This app requires 64-bit Windows 10 or later."
    Abort
  ${EndIf}
  SetShellVarContext current
FunctionEnd

Section "Conway's Game Of Life Lab"
  SetOutPath "$INSTDIR"
  File /oname=${APP_EXE} "${PAYLOAD}"
  File /oname=THIRD-PARTY-NOTICES.txt "${NOTICES}/THIRD-PARTY-NOTICES.txt"
  File /oname=DOTNET-LICENSE.txt "${NOTICES}/DOTNET-LICENSE.txt"
  File /oname=DOTNET-THIRD-PARTY-NOTICES.txt "${NOTICES}/DOTNET-THIRD-PARTY-NOTICES.txt"
  File /oname=WPF-THIRD-PARTY-NOTICES.txt "${NOTICES}/WPF-THIRD-PARTY-NOTICES.txt"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  CreateDirectory "$SMPROGRAMS\${APP_NAME}"
  CreateShortcut "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}"
  CreateShortcut "$SMPROGRAMS\${APP_NAME}\Uninstall.lnk" "$INSTDIR\Uninstall.exe"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayName" "${APP_NAME}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayVersion" "3.0"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "Publisher" "Nithilan Vivek"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "URLInfoAbout" "https://nithi.land/projects/conways-game-of-life/"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayIcon" "$INSTDIR\${APP_EXE}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "UninstallString" '$\"$INSTDIR\Uninstall.exe$\"'
  WriteRegStr HKCU "${UNINSTALL_KEY}" "QuietUninstallString" '$\"$INSTDIR\Uninstall.exe$\" /S'
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoRepair" 1
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "EstimatedSize" 65000
SectionEnd

Section "Uninstall"
  SetShellVarContext current
  ; Delete only files installed here; never recurse into folders or touch saved canvases.
  Delete "$INSTDIR\${APP_EXE}"
  Delete "$INSTDIR\THIRD-PARTY-NOTICES.txt"
  Delete "$INSTDIR\DOTNET-LICENSE.txt"
  Delete "$INSTDIR\DOTNET-THIRD-PARTY-NOTICES.txt"
  Delete "$INSTDIR\WPF-THIRD-PARTY-NOTICES.txt"
  Delete "$INSTDIR\Uninstall.exe"
  Delete "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk"
  Delete "$SMPROGRAMS\${APP_NAME}\Uninstall.lnk"
  RMDir "$SMPROGRAMS\${APP_NAME}"
  RMDir "$INSTDIR"
  DeleteRegKey HKCU "${UNINSTALL_KEY}"
SectionEnd
