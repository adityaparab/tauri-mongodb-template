!include "nsDialogs.nsh"
!include "LogicLib.nsh"
!include "MUI2.nsh"

Var MongoDbDataPath
Var MongoDbPathField
Var MongoDbBrowseBtn

; Wizard page for MongoDB data folder selection — appears in the installer flow
; just like the built-in "Choose Install Location" page.
Page custom MongoDbPathPageShow MongoDbPathPageLeave

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

!macro NSIS_HOOK_PREINSTALL
  ; MongoDB data path was collected in the wizard page above.
!macroend

!macro NSIS_HOOK_POSTINSTALL
  WriteINIStr "$INSTDIR\inventory.ini" "mongodb" "dbPath" "$MongoDbDataPath"
!macroend