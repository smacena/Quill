// Notepad++ plugin messages (NPPM_*) and Quill extensions (QUILLM_*).
// SPDX-License-Identifier: GPL-3.0-or-later
#import "MainWindowController+Private.h"
#import "Languages.h"
#import "Localization.h"
#import "MainMenu.h"
#import "Preferences.h"

#import "ScintillaView.h"
#include "Docking.h"
#include "Notepad_plus_msgs.h"
#include "QuillExtensions.h"
#include "QuillPluginKit.h"
#include "menuCmdID.h"
#include <string>

@implementation QMainWindowController (Npp)

// Copies a string into a wchar_t buffer of `size` characters. Returns the length.
static intptr_t copyW(NSString *s, wchar_t *out, size_t size) {
	std::wstring w = QWide(s ?: @"");
	if (out && size > 0) {
		size_t n = MIN(w.size(), size - 1);
		for (size_t i = 0; i < n; i++) out[i] = w[i];
		out[n] = 0;
	}
	return (intptr_t)w.size();
}

static NSString *fromW(const wchar_t *w) {
	return w ? QStr(std::wstring(w)) : @"";
}

- (NSString *)currentWord {
	ScintillaView *v = self.currentDocument.editor;
	if (!v) return @"";
	if (![v message:SCI_GETSELECTIONEMPTY]) return v.selectedString ?: @"";
	sptr_t pos = [v message:SCI_GETCURRENTPOS];
	sptr_t s = [v message:SCI_WORDSTARTPOSITION wParam:(uptr_t)pos lParam:1];
	sptr_t e = [v message:SCI_WORDENDPOSITION wParam:(uptr_t)pos lParam:1];
	std::string w(static_cast<size_t>(MAX(0, e - s)) + 1, '\0');
	Sci_TextRangeFull tr;
	tr.chrg.cpMin = s;
	tr.chrg.cpMax = e;
	tr.lpstrText = w.data();
	[v message:SCI_GETTEXTRANGEFULL wParam:0 lParam:(sptr_t)&tr];
	return [NSString stringWithUTF8String:w.c_str()] ?: @"";
}

- (NSString *)currentLineString {
	ScintillaView *v = self.currentDocument.editor;
	sptr_t line = [v message:SCI_LINEFROMPOSITION wParam:(uptr_t)[v message:SCI_GETCURRENTPOS]];
	sptr_t len = [v message:SCI_GETLINE wParam:(uptr_t)line lParam:0];
	std::string s(static_cast<size_t>(len) + 1, '\0');
	[v message:SCI_GETLINE wParam:(uptr_t)line lParam:(sptr_t)s.data()];
	s.resize(static_cast<size_t>(len));
	while (!s.empty() && (s.back() == '\n' || s.back() == '\r')) s.pop_back();
	return [NSString stringWithUTF8String:s.c_str()] ?: @"";
}

- (NSString *)variable:(int)which {
	QDocument *d = self.currentDocument;
	NSString *path = d.path ?: d.displayName;
	switch (which) {
	case FULL_CURRENT_PATH: return path;
	case CURRENT_DIRECTORY: return d.path ? d.path.stringByDeletingLastPathComponent : @"";
	case FILE_NAME: return d.displayName;
	case NAME_PART: return d.displayName.stringByDeletingPathExtension;
	case EXT_PART: return d.displayName.pathExtension.length ? [@"." stringByAppendingString:d.displayName.pathExtension] : @"";
	case CURRENT_WORD: return [self currentWord];
	case NPP_DIRECTORY: return [NSBundle mainBundle].bundlePath;
	case NPP_FULL_FILE_PATH: return [NSBundle mainBundle].executablePath;
	case GETFILENAMEATCURSOR: return [self currentWord];
	case CURRENT_LINESTR: return [self currentLineString];
	default: return @"";
	}
}

- (int)menuCommand:(int)cmd {
	struct {
		int idm;
		SEL sel;
	} map[] = {
		{IDM_FILE_NEW, @selector(newDocument:)},
		{IDM_FILE_OPEN, @selector(openDocument:)},
		{IDM_FILE_CLOSE, @selector(closeTab:)},
		{IDM_FILE_CLOSEALL, @selector(closeAllTabs:)},
		{IDM_FILE_CLOSEALL_BUT_CURRENT, @selector(closeOtherTabs:)},
		{IDM_FILE_SAVE, @selector(saveDocument:)},
		{IDM_FILE_SAVEALL, @selector(saveAllDocuments:)},
		{IDM_FILE_SAVEAS, @selector(saveDocumentAs:)},
		{IDM_FILE_SAVECOPYAS, @selector(saveCopyAs:)},
		{IDM_FILE_PRINT, @selector(printDocument:)},
		{IDM_FILE_PRINTNOW, @selector(printDocument:)},
		{IDM_FILE_EXIT, @selector(terminate:)},
		{IDM_FILE_RELOAD, @selector(reloadFromDisk:)},
		{IDM_FILE_RENAME, @selector(renameDocument:)},
		{IDM_FILE_RESTORELASTCLOSEDFILE, @selector(reopenClosedTab:)},
		{IDM_EDIT_CUT, @selector(cut:)},
		{IDM_EDIT_COPY, @selector(copy:)},
		{IDM_EDIT_UNDO, @selector(undo:)},
		{IDM_EDIT_REDO, @selector(redo:)},
		{IDM_EDIT_PASTE, @selector(paste:)},
		{IDM_EDIT_DELETE, @selector(clear:)},
		{IDM_EDIT_SELECTALL, @selector(selectAll:)},
		{IDM_EDIT_DUP_LINE, @selector(duplicateLine:)},
		{IDM_EDIT_LINE_UP, @selector(moveLineUp:)},
		{IDM_EDIT_LINE_DOWN, @selector(moveLineDown:)},
		{IDM_EDIT_UPPERCASE, @selector(makeUppercase:)},
		{IDM_EDIT_LOWERCASE, @selector(makeLowercase:)},
		{IDM_EDIT_BLOCK_COMMENT, @selector(toggleComment:)},
		{IDM_EDIT_STREAM_COMMENT, @selector(blockComment:)},
		{IDM_EDIT_TRIMTRAILING, @selector(trimTrailingWhitespace:)},
		{IDM_EDIT_JOIN_LINES, @selector(joinLines:)},
		{IDM_EDIT_SORTLINES_LEXICOGRAPHIC_ASCENDING, @selector(sortLinesAscending:)},
		{IDM_EDIT_SORTLINES_LEXICOGRAPHIC_DESCENDING, @selector(sortLinesDescending:)},
		{IDM_EDIT_REMOVE_CONSECUTIVE_DUP_LINES, @selector(removeDuplicateLines:)},
		{IDM_EDIT_REMOVEEMPTYLINES, @selector(removeEmptyLines:)},
		{IDM_EDIT_TAB2SW, @selector(tabsToSpaces:)},
		{IDM_EDIT_SW2TAB_LEADING, @selector(spacesToTabs:)},
		{IDM_EDIT_TOGGLEREADONLY, @selector(toggleReadOnly:)},
		{IDM_EDIT_FULLPATHTOCLIP, @selector(copyFullPath:)},
		{IDM_EDIT_FILENAMETOCLIP, @selector(copyFileName:)},
		{IDM_SEARCH_FIND, @selector(showFind:)},
		{IDM_SEARCH_FINDNEXT, @selector(findNext:)},
		{IDM_SEARCH_FINDPREV, @selector(findPrevious:)},
		{IDM_SEARCH_REPLACE, @selector(showReplace:)},
		{IDM_SEARCH_GOTOLINE, @selector(gotoLine:)},
		{IDM_SEARCH_GOTOMATCHINGBRACE, @selector(gotoMatchingBrace:)},
		{IDM_SEARCH_TOGGLE_BOOKMARK, @selector(toggleBookmark:)},
		{IDM_SEARCH_NEXT_BOOKMARK, @selector(nextBookmark:)},
		{IDM_SEARCH_PREV_BOOKMARK, @selector(previousBookmark:)},
		{IDM_SEARCH_CLEAR_BOOKMARKS, @selector(clearBookmarks:)},
		{IDM_SEARCH_FINDINFILES, @selector(findInFiles:)},
		{IDM_VIEW_ALL_CHARACTERS, @selector(toggleWhitespace:)},
		{IDM_VIEW_WRAP, @selector(toggleWordWrap:)},
		{IDM_VIEW_ZOOMIN, @selector(zoomIn:)},
		{IDM_VIEW_ZOOMOUT, @selector(zoomOut:)},
		{IDM_VIEW_ZOOMRESTORE, @selector(zoomReset:)},
		{IDM_VIEW_FOLDALL, @selector(foldAll:)},
		{IDM_VIEW_UNFOLDALL, @selector(unfoldAll:)},
		{IDM_VIEW_INDENT_GUIDE, @selector(toggleIndentGuides:)},
		{IDM_VIEW_EOL, @selector(toggleEOL:)},
		{IDM_FORMAT_TODOS, @selector(setDocumentLineEnding:)},
		{IDM_FORMAT_TOUNIX, @selector(setDocumentLineEnding:)},
		{IDM_FORMAT_TOMAC, @selector(setDocumentLineEnding:)},
	};
	for (auto &m : map) {
		if (m.idm != cmd) continue;
		if (m.sel == @selector(setDocumentLineEnding:)) {
			NSMenuItem *fake = [[NSMenuItem alloc] init];
			fake.tag = cmd == IDM_FORMAT_TODOS ? QLineEndingCRLF : (cmd == IDM_FORMAT_TOMAC ? QLineEndingCR : QLineEndingLF);
			[self performSelector:m.sel withObject:fake];
			return TRUE;
		}
		if ([self respondsToSelector:m.sel]) {
			[self performSelector:m.sel withObject:nil];
			return TRUE;
		}
		// Editing actions handled by the Scintilla view, app actions by NSApp.
		[NSApp sendAction:m.sel to:nil from:nil];
		return TRUE;
	}
	if ([[QPluginManager shared] runCommandID:cmd]) return TRUE;
	return FALSE;
}

- (NSArray<QDocument *> *)documentsForView:(int)view {
	if (view == SECOND_VIEW) return @[];
	return self.docs;
}

- (intptr_t)handleNppMessage:(unsigned int)msg wParam:(uintptr_t)w lParam:(intptr_t)l {
	QPluginManager *pm = [QPluginManager shared];
	QDocument *cur = self.currentDocument;
	switch (msg) {
	// ---- Views & documents
	case NPPM_GETCURRENTSCINTILLA:
		if (l) *(int *)l = MAIN_VIEW;
		return TRUE;
	case NPPM_GETCURRENTVIEW:
		return MAIN_VIEW;
	case NPPM_GETCURRENTLANGTYPE:
		if (l) *(int *)l = cur.language.langType;
		return TRUE;
	case NPPM_SETCURRENTLANGTYPE: {
		QLanguage *lang = [[QLanguageManager shared] languageForLangType:(int)l];
		if (cur && lang) {
			[cur setLanguageAndRestyle:lang];
			[self updateStatus];
			[pm notify:NPPN_LANGCHANGED bufferID:cur.bufferID];
		}
		return TRUE;
	}
	case NPPM_GETNBOPENFILES:
		return (intptr_t)[self documentsForView:(int)l].count;
	case NPPM_GETOPENFILENAMES_DEPRECATED:
	case NPPM_GETOPENFILENAMESPRIMARY_DEPRECATED: {
		wchar_t **names = (wchar_t **)w;
		NSInteger i = 0;
		for (QDocument *d in self.docs) {
			if (i >= (NSInteger)l) break;
			if (names && names[i]) copyW(d.path ?: d.displayName, names[i], MAX_PATH);
			i++;
		}
		return i;
	}
	case NPPM_GETCURRENTDOCINDEX:
		return l == SUB_VIEW ? -1 : self.currentIndex;
	case NPPM_ACTIVATEDOC:
		if ((int)w == MAIN_VIEW && l >= 0 && l < (intptr_t)self.docs.count) [self activateDocument:self.docs[(NSUInteger)l]];
		return TRUE;
	case NPPM_SWITCHTOFILE: {
		QDocument *d = [self documentForPath:fromW((const wchar_t *)l)];
		if (d) [self activateDocument:d];
		return d != nil;
	}
	case NPPM_DOOPEN:
	case NPPM_RELOADFILE: {
		NSString *path = fromW((const wchar_t *)l);
		if (msg == NPPM_RELOADFILE) {
			QDocument *d = [self documentForPath:path];
			if (!d) return FALSE;
			[d reloadWithEncoding:d.encoding error:nil];
			[self refreshTabs];
			return TRUE;
		}
		BOOL isDir = NO;
		if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] && isDir) {
			[self openFolderInExplorer:path];
			return TRUE;
		}
		return [self openPath:path] != nil;
	}
	case NPPM_SAVECURRENTFILE:
		return cur ? [self saveDocument:cur forceDialog:NO] : FALSE;
	case NPPM_SAVECURRENTFILEAS: {
		if (!cur) return FALSE;
		NSString *path = fromW((const wchar_t *)l);
		NSError *err = nil;
		if (w) return [cur writeCopyToPath:path error:&err];
		BOOL ok = [cur saveToPath:path error:&err];
		[self refreshTabs];
		return ok;
	}
	case NPPM_SAVEALLFILES:
		for (QDocument *d in [self.docs copy])
			if (d.isDirty) [self saveDocument:d forceDialog:NO];
		return TRUE;
	case NPPM_SAVEFILE: {
		QDocument *d = [self documentForPath:fromW((const wchar_t *)l)];
		return d ? [self saveDocument:d forceDialog:NO] : FALSE;
	}
	case NPPM_MAKECURRENTBUFFERDIRTY:
		cur.forcedDirty = YES;
		[self refreshTabs];
		return TRUE;
	case NPPM_GETCURRENTBUFFERID:
		return (intptr_t)cur.bufferID;
	case NPPM_GETFULLPATHFROMBUFFERID: {
		QDocument *d = [self documentForBufferID:(NSUInteger)w];
		if (!d) return -1;
		NSString *p = d.path ?: d.displayName;
		return copyW(p, (wchar_t *)l, l ? (size_t)copyW(p, nullptr, 0) + 1 : 0);
	}
	case NPPM_GETPOSFROMBUFFERID: {
		QDocument *d = [self documentForBufferID:(NSUInteger)w];
		if (!d) return -1;
		return (intptr_t)[self indexOfDocument:d]; // view 0 -> high bits 0
	}
	case NPPM_GETBUFFERIDFROMPOS:
		if ((int)l != MAIN_VIEW || (NSInteger)w >= (NSInteger)self.docs.count) return 0;
		return (intptr_t)self.docs[(NSUInteger)w].bufferID;
	case NPPM_RELOADBUFFERID: {
		QDocument *d = [self documentForBufferID:(NSUInteger)w];
		if (!d || !d.path) return FALSE;
		[d reloadWithEncoding:d.encoding error:nil];
		[self refreshTabs];
		return TRUE;
	}
	case NPPM_GETBUFFERLANGTYPE: {
		QDocument *d = [self documentForBufferID:(NSUInteger)w];
		return d ? d.language.langType : -1;
	}
	case NPPM_SETBUFFERLANGTYPE: {
		QDocument *d = [self documentForBufferID:(NSUInteger)w];
		QLanguage *lang = [[QLanguageManager shared] languageForLangType:(int)l];
		if (!d || !lang) return FALSE;
		[d setLanguageAndRestyle:lang];
		[self updateStatus];
		[pm notify:NPPN_LANGCHANGED bufferID:d.bufferID];
		return TRUE;
	}
	case NPPM_GETBUFFERENCODING: {
		QDocument *d = [self documentForBufferID:(NSUInteger)w];
		if (!d) return -1;
		// Notepad++ UniMode: 0 ANSI, 1 UTF-8 BOM, 2 UTF-16BE BOM, 3 UTF-16LE BOM, 4 UTF-8
		switch (d.encoding) {
		case QEncodingUTF8: return 4;
		case QEncodingUTF8BOM: return 1;
		case QEncodingUTF16BE: return 2;
		case QEncodingUTF16LE: return 3;
		default: return 0;
		}
	}
	case NPPM_SETBUFFERENCODING: {
		QDocument *d = [self documentForBufferID:(NSUInteger)w];
		if (!d) return FALSE;
		QEncoding map[] = {QEncodingWindows1252, QEncodingUTF8BOM, QEncodingUTF16BE, QEncodingUTF16LE, QEncodingUTF8};
		if (l < 0 || l > 4) return FALSE;
		d.encoding = map[l];
		d.forcedDirty = YES;
		[self refreshTabs];
		[self updateStatus];
		return TRUE;
	}
	case NPPM_GETBUFFERFORMAT: {
		QDocument *d = [self documentForBufferID:(NSUInteger)w];
		if (!d) return -1;
		return d.lineEnding == QLineEndingCRLF ? 0 : (d.lineEnding == QLineEndingCR ? 1 : 2);
	}
	case NPPM_SETBUFFERFORMAT: {
		QDocument *d = [self documentForBufferID:(NSUInteger)w];
		if (!d) return FALSE;
		[d convertLineEndingsTo:l == 0 ? QLineEndingCRLF : (l == 1 ? QLineEndingCR : QLineEndingLF)];
		[self updateStatus];
		return TRUE;
	}

	// ---- Paths and variables
	case NPPM_GETFULLCURRENTPATH:
	case NPPM_GETCURRENTDIRECTORY:
	case NPPM_GETFILENAME:
	case NPPM_GETNAMEPART:
	case NPPM_GETEXTPART:
	case NPPM_GETCURRENTWORD:
	case NPPM_GETNPPDIRECTORY:
	case NPPM_GETNPPFULLFILEPATH:
	case NPPM_GETFILENAMEATCURSOR:
	case NPPM_GETCURRENTLINESTR: {
		int which = (int)(msg - RUNCOMMAND_USER);
		NSString *value = [self variable:which];
		std::wstring wv = QWide(value);
		if (l == 0) return (intptr_t)wv.size();
		if (w <= wv.size()) {
			copyW(value, (wchar_t *)l, w);
			return FALSE;
		}
		copyW(value, (wchar_t *)l, w);
		return TRUE;
	}
	case NPPM_GETCURRENTLINE: {
		ScintillaView *v = cur.editor;
		return [v message:SCI_LINEFROMPOSITION wParam:(uptr_t)[v message:SCI_GETCURRENTPOS]];
	}
	case NPPM_GETCURRENTCOLUMN: {
		ScintillaView *v = cur.editor;
		return [v message:SCI_GETCOLUMN wParam:(uptr_t)[v message:SCI_GETCURRENTPOS]];
	}
	case NPPM_GETPLUGINSCONFIGDIR:
		copyW([QPluginManager pluginConfigDirectory], (wchar_t *)l, w);
		return TRUE;
	case NPPM_GETPLUGINHOMEPATH:
		if (!l) return copyW([QPluginManager userPluginDirectory], nullptr, 0);
		return copyW([QPluginManager userPluginDirectory], (wchar_t *)l, w);
	case NPPM_GETNPPSETTINGSDIRPATH: {
		NSString *dir = [QPluginManager userPluginDirectory].stringByDeletingLastPathComponent;
		if (!l) return copyW(dir, nullptr, 0);
		return copyW(dir, (wchar_t *)l, w);
	}
	case NPPM_GETNPPVERSION: {
		// HIWORD = major, LOWORD = minor (Notepad++ 8.x compatible API level)
		BOOL padded = w != 0;
		return padded ? ((8 << 16) | 700) : ((8 << 16) | 7);
	}
	case NPPM_GETWINDOWSVERSION:
		return WV_WIN10;
	case NPPM_GETCURRENTNATIVELANGENCODING:
		return 65001; // UTF-8
	case NPPM_GETLANGUAGENAME:
	case NPPM_GETLANGUAGEDESC: {
		QLanguage *lang = [[QLanguageManager shared] languageForLangType:(int)w] ?: cur.language;
		NSString *s = msg == NPPM_GETLANGUAGENAME ? lang.name : lang.displayName;
		if (!l) return copyW(s, nullptr, 0);
		return copyW(s, (wchar_t *)l, (size_t)copyW(s, nullptr, 0) + 1);
	}
	case NPPM_GETAPPDATAPLUGINSALLOWED:
		return TRUE;
	case NPPM_ISDARKMODEENABLED:
		return [QEditorStyler isDark];
	case NPPM_GETEDITORDEFAULTFOREGROUNDCOLOR:
	case NPPM_GETEDITORDEFAULTBACKGROUNDCOLOR: {
		NSColor *c = msg == NPPM_GETEDITORDEFAULTFOREGROUNDCOLOR ? [QEditorStyler editorForegroundColor] : [QEditorStyler editorBackgroundColor];
		c = [c colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
		return RGB((int)(c.redComponent * 255), (int)(c.greenComponent * 255), (int)(c.blueComponent * 255));
	}
	case NPPM_GETCURRENTMACROSTATUS:
		return 0;
	case NPPM_ISAUTOINDENTON:
		return [QPrefs shared].autoIndent;
	case NPPM_GETLINENUMBERWIDTHMODE:
		return LINENUMWIDTH_DYNAMIC;
	case NPPM_SETLINENUMBERWIDTHMODE:
		return TRUE;
	case NPPM_ISTABBARHIDDEN:
	case NPPM_ISMENUHIDDEN:
		return FALSE;
	case NPPM_ISTOOLBARHIDDEN:
		return !self.window.toolbar.visible;
	case NPPM_ISSTATUSBARHIDDEN:
		return ![QPrefs shared].showStatusBar;
	case NPPM_HIDETOOLBAR:
		self.window.toolbar.visible = !l;
		return TRUE;
	case NPPM_HIDESTATUSBAR: {
		BOOL wasHidden = ![QPrefs shared].showStatusBar;
		[QPrefs shared].showStatusBar = !l;
		self.window.contentView.needsLayout = YES;
		return wasHidden;
	}
	case NPPM_SETSTATUSBAR:
		if (l) [self setStatusMessage:fromW((const wchar_t *)l)];
		return TRUE;
	case NPPM_GETMENUHANDLE:
		return (intptr_t)(__bridge void *)(w == NPPPLUGINMENU ? [QMainMenu shared].pluginsMenu : NSApp.mainMenu);

	// ---- Menus & commands
	case NPPM_MENUCOMMAND:
		return [self menuCommand:(int)l];
	case NPPM_SETMENUITEMCHECK:
		[pm setCommand:(int)w checked:l != 0];
		return TRUE;
	case NPPM_ALLOCATESUPPORTED_DEPRECATED:
		return TRUE;
	case NPPM_ALLOCATECMDID: {
		int start = [pm allocateCommandIDs:(int)w];
		if (l) *(int *)l = start;
		return start != 0;
	}
	case NPPM_ALLOCATEMARKER: {
		int start = [pm allocateMarkers:(int)w];
		if (l) *(int *)l = start;
		return start != 0;
	}
	case NPPM_ALLOCATEINDICATOR: {
		int start = [pm allocateIndicators:(int)w];
		if (l) *(int *)l = start;
		return start != 0;
	}
	case NPPM_GETBOOKMARKID:
		return QMarkerBookmark;
	case NPPM_ADDTOOLBARICON_DEPRECATED:
	case NPPM_ADDTOOLBARICON_FORDARKMODE:
		[self addPluginToolbarButtonForCommand:(int)w symbol:@"puzzlepiece.extension"];
		return TRUE;
	case NPPM_MSGTOPLUGIN: {
		NSString *module = fromW((const wchar_t *)w);
		return [pm sendToPlugin:module msg:NPPM_MSGTOPLUGIN wParam:w lParam:l];
	}
	case NPPM_DECODESCI:
	case NPPM_ENCODESCI:
		return SC_CP_UTF8;
	case NPPM_LAUNCHFINDINFILESDLG: {
		NSString *dir = fromW((const wchar_t *)w);
		NSString *filters = fromW((const wchar_t *)l);
		(void)filters;
		[self.findInFiles showWithSearch:nil directory:dir];
		return TRUE;
	}
	case NPPM_CREATESCINTILLAHANDLE:
		return (intptr_t)(__bridge void *)[pm createScintillaView];
	case NPPM_DESTROYSCINTILLAHANDLE_DEPRECATED:
		return TRUE;

	// ---- Sessions
	case NPPM_GETNBSESSIONFILES:
	case NPPM_GETSESSIONFILES:
	case NPPM_LOADSESSION:
	case NPPM_SAVESESSION:
	case NPPM_SAVECURRENTSESSION:
		return 0;

	// ---- Docking panels
	case NPPM_DMMREGASDCKDLG: {
		tTbData *data = (tTbData *)l;
		if (!data || !data->hClient) return FALSE;
		NSView *view = (__bridge NSView *)data->hClient;
		int pos = (data->uMask & DWS_DF_FLOATING) ? CONT_RIGHT : (int)((data->uMask >> 28) & 0x3);
		QPanelPosition p = pos == CONT_LEFT ? QPanelLeft : (pos == CONT_RIGHT ? QPanelRight : QPanelBottom);
		NSString *title = fromW(data->pszName);
		if ((data->uMask & DWS_ADDINFO) && data->pszAddInfo && data->pszAddInfo[0])
			title = [title stringByAppendingFormat:@" – %@", fromW(data->pszAddInfo)];
		[self registerPanel:view title:title position:p];
		QPanelRecord *r = [self panelRecordFor:view];
		r.fromPlugin = YES;
		r.dlgID = data->dlgID;
		r.moduleName = fromW(data->pszModuleName);
		return TRUE;
	}
	case NPPM_DMMSHOW:
		[self showPanel:(__bridge NSView *)(void *)l];
		return TRUE;
	case NPPM_DMMHIDE:
		[self hidePanel:(__bridge NSView *)(void *)l];
		return TRUE;
	case NPPM_DMMUPDATEDISPINFO:
		return TRUE;
	case NPPM_DMMVIEWOTHERTAB:
		for (QPanelRecord *r in self.panels)
			if ([r.title isEqualToString:fromW((const wchar_t *)l)]) [self showPanel:r.view];
		return TRUE;
	case NPPM_DMMGETPLUGINHWNDBYNAME: {
		NSString *name = fromW((const wchar_t *)w);
		for (QPanelRecord *r in self.panels)
			if ([r.title hasPrefix:name]) return (intptr_t)(__bridge void *)r.view;
		return 0;
	}
	case NPPM_MODELESSDIALOG:
		return (intptr_t)l;

	// ---- Quill extensions
	case QUILLM_GETUILANGUAGE:
		return QCurrentLanguage() == QUILanguagePortuguese ? QUILL_LANG_PT : QUILL_LANG_EN;
	case QUILLM_GETBUFFERTEXT: {
		QDocument *d = [self documentForBufferID:(NSUInteger)w];
		if (!d) return -1;
		std::string text = [d utf8Text];
		if (l) {
			memcpy((char *)l, text.data(), text.size());
			((char *)l)[text.size()] = 0;
		}
		return (intptr_t)text.size();
	}
	case QUILLM_APPLYEDITORSTYLE: {
		ScintillaView *v = [pm viewForHandle:(void *)w];
		if (!v) {
			// Accept any ScintillaView pointer created by the plugin itself.
			id obj = (__bridge id)(void *)w;
			if ([obj isKindOfClass:[ScintillaView class]]) v = obj;
		}
		if (!v) return FALSE;
		QLanguage *lang = (int)l < 0 ? [QLanguageManager shared].plainText : ([[QLanguageManager shared] languageForLangType:(int)l] ?: [QLanguageManager shared].plainText);
		[QEditorStyler applyPreferencesToEditor:v];
		[QEditorStyler applyLanguage:lang toEditor:v];
		return TRUE;
	}
	case QUILLM_GETMAINWINDOW:
		return (intptr_t)(__bridge void *)self.window;
	case QUILLM_NEWDOCUMENT: {
		NSString *text = l ? [NSString stringWithUTF8String:(const char *)l] : @"";
		QLanguage *lang = [[QLanguageManager shared] languageForLangType:(int)w];
		QDocument *d = [self newDocumentWithText:text language:lang];
		return (intptr_t)d.bufferID;
	}
	case QUILLM_GETSCINTILLAVIEW:
		return (intptr_t)(__bridge void *)[pm viewForHandle:(void *)w];
	case QUILLM_SETSTATUSMESSAGE:
		[self setStatusMessage:l ? fromW((const wchar_t *)l) : @""];
		return TRUE;
	case QUILLM_ISPANELVISIBLE:
		return [self isPanelVisible:(__bridge NSView *)(void *)l];
	case QUILLM_GETBUFFERENCODINGNAME: {
		QDocument *d = [self documentForBufferID:(NSUInteger)w];
		if (!d) return -1;
		return copyW(QEncodingName(d.encoding), (wchar_t *)l, 64);
	}
	case QUILLM_ADDTOOLBARBUTTON:
		[self addPluginToolbarButtonForCommand:(int)w symbol:l ? fromW((const wchar_t *)l) : nil];
		return TRUE;
	case QUILLM_ADDCONTEXTMENUHANDLER:
		if (l) [self.contextMenuHandlers addObject:[NSValue valueWithPointer:(const void *)l]];
		return TRUE;
	default:
		return 0;
	}
}

@end
