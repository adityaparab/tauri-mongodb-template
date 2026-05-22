!include "nsDialogs.nsh"
!include "LogicLib.nsh"
!include "MUI2.nsh"

; ── Machine-specific license ──────────────────────────────────────────────────
; Before building this installer, replace PLACEHOLDER-UUID with the UUID of the
; target machine.  Obtain it by running on the target machine:
;
;     wmic csproduct get UUID
;
; Example:
;     !define LICENSED_MACHINE_UUID "4C4C4544-0046-4210-8031-CAC04F575931"
!define LICENSED_MACHINE_UUID "PLACEHOLDER-UUID"

Var MongoDbDataPath
Var MongoDbPathField
Var MongoDbBrowseBtn

; ── Page order ────────────────────────────────────────────────────────────────
; 1. LicenseCheckPage  — invisible; validates machine UUID before any UI appears
; 2. MongoDbPathPage   — lets the user choose a MongoDB data folder
; 3. PortCheckPage     — invisible; ensures port 27017 is free before installing
Page custom LicenseCheckPageShow
Page custom MongoDbPathPageShow MongoDbPathPageLeave
Page custom PortCheckPageShow

; ── Machine UUID validation ───────────────────────────────────────────────────
; This page is never displayed.  In NSIS, calling Abort from a Page custom
; "show" function silently skips the page and advances to the next one.
; We use this to run the UUID check before any wizard UI is rendered.
Function LicenseCheckPageShow
  ; Query machine UUID via PowerShell — produces a clean single-line UUID string.
  nsExec::ExecToStack 'powershell -NoProfile -NonInteractive -Command "(Get-WmiObject Win32_ComputerSystemProduct).UUID"'
  Pop $R0  ; exit code
  Pop $R1  ; UUID, e.g. "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX$\r$\n"

  ; Trim to 36 chars to remove any trailing whitespace / line endings.
  StrCpy $R1 $R1 36

  ; StrCmp is case-insensitive in NSIS — covers uppercase/lowercase variants.
  StrCmp $R1 "${LICENSED_MACHINE_UUID}" uuid_ok

  ; UUID did not match — inform the user and exit immediately.
  MessageBox MB_OK|MB_ICONSTOP \
    "This installer is not licensed for this machine.$\n$\nThis copy was built for a different machine. Please contact the distributor to obtain an installer for your machine."
  Quit

  uuid_ok:
  ; UUID matches — skip this invisible validation page and show the next page.
  Abort
FunctionEnd

Function MongoDbPathPageShow
  ${If} $MongoDbDataPath == ""
    StrCpy $MongoDbDataPath "$LOCALAPPDATA\inventory\mongodb-data"
  ${EndIf}

  !insertmacro MUI_HEADER_TEXT \
    "MongoDB Data Folder" \
    "Choose the location where the inventory database will be stored."

  nsDialogs::Create 1018
  Pop $0
  ${If} $0 == error
    Abort
  ${EndIf}

  ${NSD_CreateLabel} 0 0 100% 36u \
    "Setup will store the inventory database files in the following folder.$\r$\n$\r$\nTo store them in a different folder, click Browse and select another folder. Click Next to continue."
  Pop $0

  ${NSD_CreateText} 0 52u 280u 14u "$MongoDbDataPath"
  Pop $MongoDbPathField

  ${NSD_CreateButton} 285u 51u 50u 15u "Browse..."
  Pop $MongoDbBrowseBtn
  ${NSD_OnClick} $MongoDbBrowseBtn MongoDbPathBrowseClick

  nsDialogs::Show
FunctionEnd

Function MongoDbPathBrowseClick
  ${NSD_GetText} $MongoDbPathField $0
  nsDialogs::SelectFolderDialog "Select a folder for MongoDB data files" "$0"
  Pop $0
  ${If} $0 != error
    ${NSD_SetText} $MongoDbPathField $0
  ${EndIf}
FunctionEnd

Function MongoDbPathPageLeave
  ${NSD_GetText} $MongoDbPathField $MongoDbDataPath
  ${If} $MongoDbDataPath == ""
    MessageBox MB_ICONEXCLAMATION "Please select a folder for the MongoDB database files."
    Abort
  ${EndIf}
  CreateDirectory "$MongoDbDataPath"
FunctionEnd

; ── Port availability check ─────────────────────────────────────────────────
; Invisible page: checks whether port 27017 (MongoDB default) is already bound.
; If it is, the user is prompted to terminate the conflicting process.
; Declining the prompt terminates the installation.
Function PortCheckPageShow
  nsExec::ExecToStack 'powershell -NoProfile -NonInteractive -Command "try { $$c = Get-NetTCPConnection -LocalPort 27017 -EA SilentlyContinue | Select-Object -First 1; if ($$c) { Write-Host $$c.OwningProcess -NoNewline } else { Write-Host 0 -NoNewline } } catch { Write-Host 0 -NoNewline }"'
  Pop $R0   ; exit code
  Pop $R1   ; OwningProcess PID, or "0" if port is free

  ; Treat non-numeric or zero output as "port is free" and skip the page
  IntOp $R9 $R1 + 0
  ${If} $R9 <= 0
    Abort
  ${EndIf}

  ; Resolve the process name for the descriptive prompt
  nsExec::ExecToStack 'powershell -NoProfile -NonInteractive -Command "$$p = (Get-Process -Id $R1 -EA SilentlyContinue).Name; if ($$p) { Write-Host $$p -NoNewline } else { Write-Host Unknown -NoNewline }"'
  Pop $R0   ; exit code
  Pop $R2   ; process name

  ; Ask the user: terminate the blocking process, or cancel installation
  MessageBox MB_YESNO|MB_ICONEXCLAMATION \
    "Port 27017 is required by the bundled MongoDB database server, but is already in use.$\r$\n$\r$\nConflicting process: $R2 (PID $R1)$\r$\n$\r$\nClick Yes to terminate this process and continue installing.$\r$\nClick No to cancel the installation." \
    IDYES port27017_terminate

  ; User declined — inform and quit
  MessageBox MB_OK|MB_ICONINFORMATION \
    "Installation cancelled.$\r$\nPlease stop the process occupying port 27017 and run the installer again."
  Quit

port27017_terminate:
  nsExec::ExecToStack 'taskkill /F /PID $R1'
  Pop $R0   ; exit code (0 = success)
  Pop $R4   ; stdout (discard)
  ${If} $R0 != 0
    MessageBox MB_OK|MB_ICONSTOP \
      "Could not terminate $R2 (PID $R1).$\r$\nPlease stop it manually and run the installer again."
    Quit
  ${EndIf}

  ; Port is now free — skip page display and continue with installation
  Abort
FunctionEnd

!macro NSIS_HOOK_PREINSTALL
  ; MongoDB data path was collected in the wizard page above.
!macroend

!macro NSIS_HOOK_POSTINSTALL
  WriteINIStr "$INSTDIR\inventory.ini" "mongodb" "dbPath" "$MongoDbDataPath"
!macroend