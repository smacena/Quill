// Helpers shared by the bundled plugins (header-only, Objective-C++).
// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#import <Cocoa/Cocoa.h>
#include <string>
#include <vector>

#include "QuillPluginKit.h"
#import "ScintillaView.h"

namespace qp {

using quill::host;

// Menu commands -------------------------------------------------------------

struct Commands {
	std::vector<FuncItem> items;
	std::vector<ShortcutKey *> keys;

	int add(const wchar_t *en, const wchar_t *pt, PFUNCPLUGINCMD fn, ShortcutKey *key = nullptr, bool checked = false) {
		FuncItem f;
		quill::copyName(f._itemName, menuItemSize, host().isPortuguese() ? pt : en);
		f._pFunc = fn;
		f._init2Check = checked;
		f._pShKey = key;
		items.push_back(f);
		return static_cast<int>(items.size()) - 1;
	}

	void separator() {
		FuncItem f;
		items.push_back(f);
	}

	// Ctrl = Command on macOS, Alt = Option.
	static ShortcutKey *key(UCHAR vk, bool cmd, bool option, bool shift) {
		ShortcutKey *k = new ShortcutKey;
		k->_isCtrl = cmd;
		k->_isAlt = option;
		k->_isShift = shift;
		k->_key = vk;
		return k;
	}

	int cmdID(int index) const { return items[static_cast<size_t>(index)]._cmdID; }
	void setChecked(int index, bool checked) const {
		host().npp(NPPM_SETMENUITEMCHECK, static_cast<WPARAM>(cmdID(index)), checked ? TRUE : FALSE);
	}
};

// Docked panels ---------------------------------------------------------------

struct Panel {
	NSView *view = nil;
	std::wstring title;
	std::wstring module;
	tTbData data;
	bool registered = false;

	void registerIn(NSView *v, const std::wstring &panelTitle, const std::wstring &moduleName, int dlgIndex, UINT position) {
		view = v;
		title = panelTitle;
		module = moduleName;
		data = tTbData();
		data.hClient = (__bridge HWND)v;
		data.pszName = title.c_str();
		data.dlgID = dlgIndex;
		data.uMask = position;
		data.pszModuleName = module.c_str();
		host().npp(NPPM_DMMREGASDCKDLG, 0, (LPARAM)&data);
		registered = true;
	}

	bool visible() const { return view && host().npp(QUILLM_ISPANELVISIBLE, 0, (LPARAM)(__bridge void *)view) != 0; }
	void show() const {
		if (view) host().npp(NPPM_DMMSHOW, 0, (LPARAM)(__bridge void *)view);
	}
	void hide() const {
		if (view) host().npp(NPPM_DMMHIDE, 0, (LPARAM)(__bridge void *)view);
	}
};

// Editor helpers ----------------------------------------------------------------

inline ScintillaView *currentView() {
	return (__bridge ScintillaView *)(void *)host().npp(QUILLM_GETSCINTILLAVIEW, (WPARAM)host().data()._scintillaMainHandle, 0);
}

inline std::string textRange(intptr_t start, intptr_t end) {
	if (end <= start) return std::string();
	std::string s(static_cast<size_t>(end - start) + 1, '\0');
	Sci_TextRangeFull tr;
	tr.chrg.cpMin = start;
	tr.chrg.cpMax = end;
	tr.lpstrText = s.data();
	host().sci(SCI_GETTEXTRANGEFULL, 0, (LPARAM)&tr);
	s.resize(static_cast<size_t>(end - start));
	return s;
}

// Selection if any, otherwise the whole document. start/end receive the range.
inline std::string selectionOrAll(intptr_t &start, intptr_t &end) {
	start = host().sci(SCI_GETSELECTIONSTART);
	end = host().sci(SCI_GETSELECTIONEND);
	if (end <= start) {
		start = 0;
		end = host().sci(SCI_GETLENGTH);
	}
	return textRange(start, end);
}

inline void replaceRange(intptr_t start, intptr_t end, const std::string &text) {
	host().sci(SCI_BEGINUNDOACTION);
	host().sci(SCI_SETTARGETRANGE, static_cast<WPARAM>(start), end);
	host().sci(SCI_REPLACETARGET, text.size(), (LPARAM)text.c_str());
	host().sci(SCI_ENDUNDOACTION);
}

inline std::wstring languageName() {
	int lang = host().currentLangType();
	intptr_t len = host().npp(NPPM_GETLANGUAGENAME, static_cast<WPARAM>(lang), 0);
	std::wstring s(static_cast<size_t>(len) + 1, 0);
	host().npp(NPPM_GETLANGUAGENAME, static_cast<WPARAM>(lang), (LPARAM)s.data());
	s.resize(wcslen(s.c_str()));
	return s;
}

inline NSString *configPath(NSString *fileName) {
	return [QStr(host().pluginConfigDir()) stringByAppendingPathComponent:fileName];
}

inline void status(NSString *msg) {
	host().status(QWide(msg));
}

inline void alert(NSString *title, NSString *text, NSAlertStyle style = NSAlertStyleInformational) {
	NSAlert *a = [[NSAlert alloc] init];
	a.messageText = title ?: @"";
	a.informativeText = text ?: @"";
	a.alertStyle = style;
	[a runModal];
}

inline NSFont *monoFont(CGFloat size = 12) {
	return [NSFont monospacedSystemFontOfSize:size weight:NSFontWeightRegular];
}

inline NSWindow *mainWindow() {
	return (__bridge NSWindow *)(void *)host().npp(QUILLM_GETMAINWINDOW);
}

} // namespace qp

// Declares the six exported functions with the usual names. The plugin must
// define: pluginInit(), pluginCommands(qp::Commands&), pluginNotify(SCNotification*),
// and the PLUGIN_NAME / PLUGIN_NAME_PT strings.
#define QUILL_PLUGIN_EXPORTS(NAME_EN, NAME_PT)                                         \
	static qp::Commands gCommands;                                                  \
	static bool gCommandsBuilt = false;                                             \
	static void pluginInit();                                                        \
	static void pluginCommands(qp::Commands &c);                                     \
	static void pluginNotify(SCNotification *n);                                     \
	static LRESULT pluginMessage(UINT msg, WPARAM w, LPARAM l);                      \
	extern "C" __declspec(dllexport) void setInfo(NppData data) {                    \
		quill::host().setData(data);                                             \
		pluginInit();                                                            \
	}                                                                                \
	extern "C" __declspec(dllexport) const wchar_t *getName() {                      \
		return quill::host().isPortuguese() ? NAME_PT : NAME_EN;                 \
	}                                                                                \
	extern "C" __declspec(dllexport) FuncItem *getFuncsArray(int *count) {           \
		if (!gCommandsBuilt) {                                                   \
			pluginCommands(gCommands);                                       \
			gCommandsBuilt = true;                                           \
		}                                                                        \
		*count = static_cast<int>(gCommands.items.size());                       \
		return gCommands.items.data();                                           \
	}                                                                                \
	extern "C" __declspec(dllexport) void beNotified(SCNotification *n) {            \
		pluginNotify(n);                                                         \
	}                                                                                \
	extern "C" __declspec(dllexport) LRESULT messageProc(UINT msg, WPARAM w, LPARAM l) { \
		return pluginMessage(msg, w, l);                                          \
	}                                                                                \
	extern "C" __declspec(dllexport) BOOL isUnicode() {                              \
		return TRUE;                                                             \
	}
