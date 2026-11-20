// Quill plugin SDK - macOS specific extensions to the Notepad++ plugin API.
//
// Everything in Notepad_plus_msgs.h keeps its Notepad++ meaning. The messages
// below exist only in Quill and give plugins access to native macOS objects.
//
// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include "QuillWin32.h"

#define QUILL_SDK_VERSION 1

#define QUILLMSG (WM_USER + 5000)

// int QUILLM_GETUILANGUAGE(0, 0)
// Returns the user interface language: 0 = English, 1 = Portuguese (Brazil).
#define QUILLM_GETUILANGUAGE (QUILLMSG + 1)
#define QUILL_LANG_EN 0
#define QUILL_LANG_PT 1

// intptr_t QUILLM_GETBUFFERTEXT(UINT_PTR bufferID, char* utf8Buffer)
// Copies the UTF-8 text of any open buffer (not only the current one).
// Call with utf8Buffer == NULL to get the length in bytes (without the
// terminating NUL); then allocate length + 1 bytes and call again.
// Returns -1 if the buffer does not exist.
#define QUILLM_GETBUFFERTEXT (QUILLMSG + 2)

// BOOL QUILLM_APPLYEDITORSTYLE(HWND scintilla, int langType)
// Applies the user's font, theme (light/dark) and the syntax highlighting of
// langType (see enum LangType, -1 = keep plain text) to a Scintilla view that
// the plugin owns (e.g. created with NPPM_CREATESCINTILLAHANDLE).
#define QUILLM_APPLYEDITORSTYLE (QUILLMSG + 3)

// NSWindow* QUILLM_GETMAINWINDOW(0, 0)
#define QUILLM_GETMAINWINDOW (QUILLMSG + 4)

// UINT_PTR QUILLM_NEWDOCUMENT(int langType, const char* utf8Text)
// Opens a new untitled tab containing utf8Text. Returns the new buffer ID.
#define QUILLM_NEWDOCUMENT (QUILLMSG + 5)

// ScintillaView* QUILLM_GETSCINTILLAVIEW(HWND scintilla, 0)
// Converts a Scintilla handle (including NppData._scintillaMainHandle, which
// always refers to the current editor) to the ScintillaView object.
#define QUILLM_GETSCINTILLAVIEW (QUILLMSG + 6)

// BOOL QUILLM_SETSTATUSMESSAGE(0, const wchar_t* text)
// Shows a transient message in the status bar (NULL clears it).
#define QUILLM_SETSTATUSMESSAGE (QUILLMSG + 7)

// BOOL QUILLM_ISPANELVISIBLE(0, HWND hClient)
#define QUILLM_ISPANELVISIBLE (QUILLMSG + 8)

// intptr_t QUILLM_GETBUFFERENCODINGNAME(UINT_PTR bufferID, wchar_t* name)
// name must hold at least 64 characters. Returns its length.
#define QUILLM_GETBUFFERENCODINGNAME (QUILLMSG + 9)

// BOOL QUILLM_ADDTOOLBARBUTTON(int cmdID, const wchar_t* sfSymbolName)
// Adds a toolbar button that runs the plugin command with the given cmdID
// (FuncItem._cmdID after getFuncsArray). The icon is an SF Symbol name such
// as L"doc.on.doc". Call it when you receive NPPN_TBMODIFICATION.
#define QUILLM_ADDTOOLBARBUTTON (QUILLMSG + 10)

// ---- Notifications sent to beNotified() in addition to NPPN_* -------------

#define QUILLN_FIRST 5000
// The user closed a docked panel with its close button.
// nmhdr.hwndFrom = the panel's hClient, nmhdr.idFrom = tTbData.dlgID
#define QUILLN_PANELCLOSED (QUILLN_FIRST + 1)
// The editor theme changed (light <-> dark). nmhdr.idFrom = 1 when dark.
#define QUILLN_THEMECHANGED (QUILLN_FIRST + 2)

// BOOL QUILLM_ADDCONTEXTMENUHANDLER(0, QuillContextMenuHandler handler)
// Registers a function that can add items to the editor context menu right
// before it is shown. nsMenu is an NSMenu*, clickPosition the document
// position under the mouse (or the caret position).
typedef void (*QuillContextMenuHandler)(void *nsMenu, intptr_t clickPosition);
#define QUILLM_ADDCONTEXTMENUHANDLER (QUILLMSG + 11)

// Messages understood by the bundled Explorer plugin through NPPM_MSGTOPLUGIN
// (CommunicationInfo.internalMsg). info = const wchar_t* folder path.
#define QUILL_EXPLORER_OPENFOLDER 1
// Bundled FTP plugin: internal end-to-end test (used by the app self test).
#define QUILL_FTP_SELFTEST 100
