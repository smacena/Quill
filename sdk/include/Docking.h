// Quill plugin SDK - dockable panel registration (Notepad++ compatible).
//
// Notepad++ plugins register dockable dialogs with NPPM_DMMREGASDCKDLG passing
// a tTbData. On macOS, hClient must be an NSView* bridged to HWND:
//
//     tTbData data = {};
//     data.hClient = (__bridge HWND)myPanelView;
//     data.pszName = L"My Panel";
//     data.dlgID = 0;
//     data.uMask = DWS_DF_CONT_RIGHT;
//     data.pszModuleName = L"MyPlugin.dylib";
//     SendMessage(nppData._nppHandle, NPPM_DMMREGASDCKDLG, 0, (LPARAM)&data);
//
// Show / hide with NPPM_DMMSHOW / NPPM_DMMHIDE (lParam = the same hClient).
//
// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include "QuillWin32.h"

#define CONT_LEFT 0
#define CONT_RIGHT 1
#define CONT_TOP 2
#define CONT_BOTTOM 3
#define DOCKCONT_MAX 4

#define DWS_ICONTAB 0x00000001
#define DWS_ICONBAR 0x00000002
#define DWS_ADDINFO 0x00000004
#define DWS_USEOWNDARKMODE 0x00000008
#define DWS_PARAMSALL (DWS_ICONTAB | DWS_ICONBAR | DWS_ADDINFO)

#define DWS_DF_CONT_LEFT (CONT_LEFT << 28)
#define DWS_DF_CONT_RIGHT (CONT_RIGHT << 28)
#define DWS_DF_CONT_TOP (CONT_TOP << 28)
#define DWS_DF_CONT_BOTTOM (CONT_BOTTOM << 28)
#define DWS_DF_FLOATING 0x80000000

struct tTbData {
	HWND hClient = nullptr;               // NSView* of the panel content
	const wchar_t *pszName = nullptr;     // title shown above the panel
	int dlgID = 0;                        // index of the FuncItem that toggles the panel
	UINT uMask = 0;                       // DWS_* flags, position in the top 4 bits
	HICON hIconTab = nullptr;             // unused on macOS
	const wchar_t *pszAddInfo = nullptr;  // extra text shown after the title
	RECT rcFloat = {};
	int iPrevCont = 0;
	const wchar_t *pszModuleName = nullptr;
};
