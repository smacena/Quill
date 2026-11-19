// Quill plugin SDK - minimal Win32 type shim.
//
// Notepad++ plugins are written against <windows.h>. This header provides the
// handful of types and macros that the plugin interface needs so that plugin
// sources can be recompiled for macOS with as few changes as possible.
//
// Strings: like Notepad++, the plugin interface uses wchar_t strings. On macOS
// wchar_t is 32 bits (UTF-32). The host converts to/from UTF-32 for every
// message that exchanges wchar_t text. Scintilla text is always UTF-8.
//
// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include <stdint.h>
#include <stddef.h>
#include <wchar.h>
#include <string.h>

#ifndef QUILL_WIN32_SHIM
#define QUILL_WIN32_SHIM 1

typedef void *HWND;
typedef void *HINSTANCE;
typedef void *HMODULE;
typedef void *HMENU;
typedef void *HICON;
typedef void *HBITMAP;
typedef void *HANDLE;
typedef unsigned int UINT;
typedef unsigned long ULONG;
typedef unsigned long DWORD;
typedef unsigned short WORD;
typedef unsigned char UCHAR;
typedef unsigned char BYTE;
typedef int INT;
typedef long LONG;
typedef uintptr_t WPARAM;
typedef intptr_t LPARAM;
typedef intptr_t LRESULT;
typedef intptr_t INT_PTR;
typedef uintptr_t UINT_PTR;
#ifndef __OBJC__
typedef int BOOL;
#endif
typedef wchar_t WCHAR;
typedef wchar_t TCHAR;
typedef const wchar_t *LPCWSTR;
typedef wchar_t *LPWSTR;
typedef const wchar_t *LPCTSTR;
typedef wchar_t *LPTSTR;
typedef const char *LPCSTR;
typedef char *LPSTR;
typedef void *LPVOID;
typedef DWORD COLORREF;

typedef struct tagRECT {
	LONG left;
	LONG top;
	LONG right;
	LONG bottom;
} RECT;

#ifndef TRUE
#define TRUE 1
#endif
#ifndef FALSE
#define FALSE 0
#endif
#ifndef MAX_PATH
#define MAX_PATH 1024
#endif
#define WM_USER 0x0400
#define WM_COMMAND_SHIM 0x0111

#ifndef __cdecl
#define __cdecl
#endif
#ifndef __stdcall
#define __stdcall
#endif
#ifndef WINAPI
#define WINAPI
#endif
#ifndef CALLBACK
#define CALLBACK
#endif
#define __declspec(x) __attribute__((visibility("default")))

#ifndef TEXT
#define TEXT(s) L##s
#endif
#ifndef _T
#define _T(s) L##s
#endif
#ifndef _countof
#define _countof(a) (sizeof(a) / sizeof((a)[0]))
#endif

#define RGB(r, g, b) ((COLORREF)(((BYTE)(r) | ((WORD)((BYTE)(g)) << 8)) | (((DWORD)(BYTE)(b)) << 16)))
#define GetRValue(rgb) ((BYTE)(rgb))
#define GetGValue(rgb) ((BYTE)(((WORD)(rgb)) >> 8))
#define GetBValue(rgb) ((BYTE)((rgb) >> 16))

#define LOWORD(l) ((WORD)(((DWORD_PTR_SHIM)(l)) & 0xffff))
#define HIWORD(l) ((WORD)((((DWORD_PTR_SHIM)(l)) >> 16) & 0xffff))
typedef uintptr_t DWORD_PTR_SHIM;

#define MB_OK 0x0
#define MB_OKCANCEL 0x1
#define MB_YESNOCANCEL 0x3
#define MB_YESNO 0x4
#define MB_ICONERROR 0x10
#define MB_ICONQUESTION 0x20
#define MB_ICONWARNING 0x30
#define MB_ICONINFORMATION 0x40
#define IDOK 1
#define IDCANCEL 2
#define IDYES 6
#define IDNO 7

#ifdef __cplusplus
extern "C" {
#endif

// Implemented by the Quill host application. Plugins are linked with
// "-undefined dynamic_lookup" so these resolve against the running app.

// Sends a message to the host window (NppData._nppHandle), to a Scintilla
// handle (NppData._scintillaMainHandle / _scintillaSecondHandle or one
// created with NPPM_CREATESCINTILLAHANDLE).
LRESULT QuillSendMessage(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);

// Simple message box (NSAlert). Returns IDOK / IDCANCEL / IDYES / IDNO.
int QuillMessageBox(HWND hWnd, const wchar_t *text, const wchar_t *caption, UINT type);

#ifdef __cplusplus
}
#endif

#define SendMessage QuillSendMessage
#define SendMessageW QuillSendMessage
#define MessageBox QuillMessageBox
#define MessageBoxW QuillMessageBox

#endif // QUILL_WIN32_SHIM
