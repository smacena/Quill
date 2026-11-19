// Quill plugin SDK - convenience helpers for plugins written in Objective-C++.
//
// Include this from exactly the plugin sources that need it. It is header-only.
// Before using QuillHost, call QuillHost::shared().setData(nppData) in setInfo().
//
// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include <string>
#include <vector>

#include "PluginInterface.h"
#include "Docking.h"
#include "QuillExtensions.h"

namespace quill {

// ---- UTF-8 <-> UTF-32 (wchar_t on macOS) -----------------------------------

inline std::wstring widen(const std::string &s) {
	std::wstring out;
	out.reserve(s.size());
	size_t i = 0;
	const size_t n = s.size();
	while (i < n) {
		unsigned char c = static_cast<unsigned char>(s[i]);
		uint32_t cp = 0;
		int extra = 0;
		if (c < 0x80) { cp = c; extra = 0; }
		else if ((c & 0xE0) == 0xC0) { cp = c & 0x1F; extra = 1; }
		else if ((c & 0xF0) == 0xE0) { cp = c & 0x0F; extra = 2; }
		else if ((c & 0xF8) == 0xF0) { cp = c & 0x07; extra = 3; }
		else { out.push_back(0xFFFD); i++; continue; }
		bool ok = true;
		for (int k = 1; k <= extra; k++) {
			if (i + k >= n) { ok = false; break; }
			unsigned char cc = static_cast<unsigned char>(s[i + k]);
			if ((cc & 0xC0) != 0x80) { ok = false; break; }
			cp = (cp << 6) | (cc & 0x3F);
		}
		if (!ok) { out.push_back(0xFFFD); i++; continue; }
		out.push_back(static_cast<wchar_t>(cp));
		i += extra + 1;
	}
	return out;
}

inline std::string narrow(const std::wstring &w) {
	std::string out;
	out.reserve(w.size());
	for (wchar_t wc : w) {
		uint32_t cp = static_cast<uint32_t>(wc);
		if (cp < 0x80) out.push_back(static_cast<char>(cp));
		else if (cp < 0x800) {
			out.push_back(static_cast<char>(0xC0 | (cp >> 6)));
			out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
		} else if (cp < 0x10000) {
			out.push_back(static_cast<char>(0xE0 | (cp >> 12)));
			out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
			out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
		} else {
			out.push_back(static_cast<char>(0xF0 | (cp >> 18)));
			out.push_back(static_cast<char>(0x80 | ((cp >> 12) & 0x3F)));
			out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
			out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
		}
	}
	return out;
}

inline void copyName(wchar_t *dest, size_t destLen, const std::wstring &src) {
	size_t n = src.size() < destLen - 1 ? src.size() : destLen - 1;
	for (size_t i = 0; i < n; i++) dest[i] = src[i];
	dest[n] = 0;
}

// ---- Host access -------------------------------------------------------------

class QuillHost {
public:
	static QuillHost &shared() {
		static QuillHost host;
		return host;
	}

	void setData(const NppData &d) { data_ = d; }
	const NppData &data() const { return data_; }
	HWND npp() const { return data_._nppHandle; }

	HWND currentScintilla() const {
		int which = 0;
		SendMessage(data_._nppHandle, NPPM_GETCURRENTSCINTILLA, 0, (LPARAM)&which);
		return which == 0 ? data_._scintillaMainHandle : data_._scintillaSecondHandle;
	}

	LRESULT npp(UINT msg, WPARAM w = 0, LPARAM l = 0) const { return SendMessage(data_._nppHandle, msg, w, l); }
	LRESULT sci(UINT msg, WPARAM w = 0, LPARAM l = 0) const { return SendMessage(currentScintilla(), msg, w, l); }

	bool isPortuguese() const { return npp(QUILLM_GETUILANGUAGE) == QUILL_LANG_PT; }

	// Pick the English or Portuguese text according to the UI language.
	const wchar_t *tr(const wchar_t *en, const wchar_t *pt) const { return isPortuguese() ? pt : en; }

	std::string currentText() const {
		intptr_t len = sci(SCI_GETLENGTH);
		std::string s(static_cast<size_t>(len) + 1, '\0');
		sci(SCI_GETTEXT, static_cast<WPARAM>(len + 1), (LPARAM)s.data());
		s.resize(static_cast<size_t>(len));
		return s;
	}

	std::string selectedText() const {
		intptr_t len = sci(SCI_GETSELTEXT, 0, 0);
		std::string s(static_cast<size_t>(len) + 1, '\0');
		sci(SCI_GETSELTEXT, 0, (LPARAM)s.data());
		s.resize(strlen(s.c_str()));
		return s;
	}

	bool hasSelection() const { return sci(SCI_GETSELECTIONEMPTY) == 0; }

	// Replaces the whole document as one undo step.
	void setCurrentText(const std::string &text) const {
		sci(SCI_BEGINUNDOACTION);
		sci(SCI_SETTEXT, 0, (LPARAM)text.c_str());
		sci(SCI_ENDUNDOACTION);
	}

	void replaceSelection(const std::string &text) const {
		sci(SCI_BEGINUNDOACTION);
		sci(SCI_REPLACESEL, 0, (LPARAM)text.c_str());
		sci(SCI_ENDUNDOACTION);
	}

	std::wstring currentPath() const {
		wchar_t buf[MAX_PATH * 4] = {0};
		npp(NPPM_GETFULLCURRENTPATH, _countof(buf), (LPARAM)buf);
		return buf;
	}

	std::wstring currentDirectory() const {
		wchar_t buf[MAX_PATH * 4] = {0};
		npp(NPPM_GETCURRENTDIRECTORY, _countof(buf), (LPARAM)buf);
		return buf;
	}

	std::wstring pluginConfigDir() const {
		wchar_t buf[MAX_PATH * 4] = {0};
		npp(NPPM_GETPLUGINSCONFIGDIR, _countof(buf), (LPARAM)buf);
		return buf;
	}

	UINT_PTR currentBufferID() const { return static_cast<UINT_PTR>(npp(NPPM_GETCURRENTBUFFERID)); }

	std::wstring pathFromBufferID(UINT_PTR id) const {
		intptr_t len = npp(NPPM_GETFULLPATHFROMBUFFERID, id, 0);
		if (len <= 0) return std::wstring();
		std::wstring s(static_cast<size_t>(len) + 1, 0);
		npp(NPPM_GETFULLPATHFROMBUFFERID, id, (LPARAM)s.data());
		s.resize(static_cast<size_t>(len));
		return s;
	}

	std::string bufferText(UINT_PTR id) const {
		intptr_t len = npp(QUILLM_GETBUFFERTEXT, id, 0);
		if (len < 0) return std::string();
		std::string s(static_cast<size_t>(len) + 1, '\0');
		npp(QUILLM_GETBUFFERTEXT, id, (LPARAM)s.data());
		s.resize(static_cast<size_t>(len));
		return s;
	}

	int currentLangType() const {
		int lang = 0;
		npp(NPPM_GETCURRENTLANGTYPE, 0, (LPARAM)&lang);
		return lang;
	}

	bool openFile(const std::wstring &path) const { return npp(NPPM_DOOPEN, 0, (LPARAM)path.c_str()) != 0; }

	void status(const std::wstring &msg) const { npp(QUILLM_SETSTATUSMESSAGE, 0, (LPARAM)msg.c_str()); }

	void message(const std::wstring &text, const std::wstring &title, UINT type = MB_OK | MB_ICONINFORMATION) const {
		MessageBox(data_._nppHandle, text.c_str(), title.c_str(), type);
	}

private:
	NppData data_;
};

inline QuillHost &host() { return QuillHost::shared(); }

} // namespace quill

#ifdef __OBJC__
#import <Cocoa/Cocoa.h>

inline NSString *QStr(const std::wstring &w) {
	return [NSString stringWithUTF8String:quill::narrow(w).c_str()] ?: @"";
}
inline NSString *QStr(const std::string &s) {
	return [NSString stringWithUTF8String:s.c_str()] ?: @"";
}
inline std::wstring QWide(NSString *s) {
	return quill::widen(s ? std::string(s.UTF8String) : std::string());
}
inline std::string QUtf8(NSString *s) {
	return s ? std::string(s.UTF8String) : std::string();
}
// Localized literal: QTR(@"English", @"Português")
inline NSString *QTR(NSString *en, NSString *pt) {
	return quill::host().isPortuguese() ? pt : en;
}
#endif
