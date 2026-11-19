// Menu commands of the main window.
// SPDX-License-Identifier: GPL-3.0-or-later
#import "MainWindowController+Private.h"
#import "Languages.h"
#import "Localization.h"
#import "MainMenu.h"
#import "Preferences.h"

#import "ScintillaView.h"
#include "Notepad_plus_msgs.h"
#include "QuillExtensions.h"
#include "QuillPluginKit.h"
#include "quill/TextTools.h"
#include <functional>
#include <string>

@implementation QMainWindowController (Commands)

- (ScintillaView *)ed {
	return self.currentDocument.editor;
}

static std::string textRange(ScintillaView *v, sptr_t start, sptr_t end) {
	if (end <= start) return std::string();
	std::string s(static_cast<size_t>(end - start) + 1, '\0');
	Sci_TextRangeFull tr;
	tr.chrg.cpMin = start;
	tr.chrg.cpMax = end;
	tr.lpstrText = s.data();
	[v message:SCI_GETTEXTRANGEFULL wParam:0 lParam:(sptr_t)&tr];
	s.resize(static_cast<size_t>(end - start));
	return s;
}

static void replaceRange(ScintillaView *v, sptr_t start, sptr_t end, const std::string &text) {
	[v message:SCI_SETTARGETRANGE wParam:(uptr_t)start lParam:end];
	[v message:SCI_REPLACETARGET wParam:text.size() lParam:(sptr_t)text.c_str()];
}

// Applies f to the selected lines (or the whole document when nothing is selected).
- (void)transformLines:(std::function<std::string(const std::string &)>)f {
	ScintillaView *v = [self ed];
	if (!v || [v message:SCI_GETREADONLY]) return;
	sptr_t selStart = [v message:SCI_GETSELECTIONSTART];
	sptr_t selEnd = [v message:SCI_GETSELECTIONEND];
	sptr_t start = 0, end = [v message:SCI_GETLENGTH];
	BOOL partial = selEnd > selStart;
	if (partial) {
		sptr_t l1 = [v message:SCI_LINEFROMPOSITION wParam:(uptr_t)selStart];
		sptr_t l2 = [v message:SCI_LINEFROMPOSITION wParam:(uptr_t)selEnd];
		if ([v message:SCI_POSITIONFROMLINE wParam:(uptr_t)l2] == selEnd && l2 > l1) l2--;
		start = [v message:SCI_POSITIONFROMLINE wParam:(uptr_t)l1];
		end = [v message:SCI_GETLINEENDPOSITION wParam:(uptr_t)l2];
	}
	std::string in = textRange(v, start, end);
	std::string out = f(in);
	if (out == in) return;
	[v message:SCI_BEGINUNDOACTION];
	replaceRange(v, start, end, out);
	[v message:SCI_ENDUNDOACTION];
	if (partial) [v message:SCI_SETSEL wParam:(uptr_t)start lParam:start + (sptr_t)out.size()];
}

// ---- File -----------------------------------------------------------------------------

- (void)reopenClosedTab:(id)sender {
	while (self.closedPaths.count) {
		NSString *p = self.closedPaths.lastObject;
		[self.closedPaths removeLastObject];
		if ([[NSFileManager defaultManager] fileExistsAtPath:p]) {
			[self openPath:p];
			return;
		}
	}
	NSBeep();
}

- (void)openFolder:(id)sender {
	NSOpenPanel *p = [NSOpenPanel openPanel];
	p.canChooseDirectories = YES;
	p.canChooseFiles = NO;
	if ([p runModal] != NSModalResponseOK) return;
	[self openFolderInExplorer:p.URL.path];
}

- (void)openFolderInExplorer:(NSString *)path {
	std::wstring w = QWide(path);
	CommunicationInfo ci;
	ci.internalMsg = QUILL_EXPLORER_OPENFOLDER;
	ci.srcModuleName = L"Quill";
	ci.info = (void *)w.c_str();
	if (![[QPluginManager shared] sendToPlugin:@"Explorer.dylib" msg:NPPM_MSGTOPLUGIN wParam:0 lParam:(intptr_t)&ci])
		[self setStatusMessage:T(@"The Explorer plugin is not loaded.", @"O plugin Explorador não está carregado.")];
}

- (void)saveDocument:(id)sender {
	if (self.currentDocument) [self saveDocument:self.currentDocument forceDialog:NO];
}

- (void)saveDocumentAs:(id)sender {
	if (self.currentDocument) [self saveDocument:self.currentDocument forceDialog:YES];
}

- (void)saveCopyAs:(id)sender {
	QDocument *d = self.currentDocument;
	if (!d) return;
	NSSavePanel *panel = [NSSavePanel savePanel];
	panel.nameFieldStringValue = d.path ? d.path.lastPathComponent : d.displayName;
	if ([panel runModal] != NSModalResponseOK) return;
	NSError *err = nil;
	if (![d writeCopyToPath:panel.URL.path error:&err]) [self reportError:err];
	else [self setStatusMessage:[NSString stringWithFormat:T(@"Copy saved to %@", @"Cópia salva em %@"), panel.URL.path]];
}

- (void)saveAllDocuments:(id)sender {
	for (QDocument *d in [self.docs copy])
		if (d.isDirty && ![self saveDocument:d forceDialog:NO]) break;
}

- (void)renameDocument:(id)sender {
	QDocument *d = self.currentDocument;
	if (!d) return;
	NSAlert *a = [[NSAlert alloc] init];
	a.messageText = T(@"Rename", @"Renomear");
	a.informativeText = d.path ?: T(@"New name for the tab:", @"Novo nome para a aba:");
	NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 300, 24)];
	field.stringValue = d.displayName;
	a.accessoryView = field;
	[a addButtonWithTitle:T(@"Rename", @"Renomear")];
	[a addButtonWithTitle:T(@"Cancel", @"Cancelar")];
	a.window.initialFirstResponder = field;
	if ([a runModal] != NSAlertFirstButtonReturn) return;
	NSString *name = [field.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	if (!name.length || [name containsString:@"/"]) return;
	QPluginManager *pm = [QPluginManager shared];
	if (!d.path) {
		d.untitledName = name;
	} else {
		NSString *newPath = [d.path.stringByDeletingLastPathComponent stringByAppendingPathComponent:name];
		[pm notify:NPPN_FILEBEFORERENAME bufferID:d.bufferID];
		NSError *err = nil;
		if (![[NSFileManager defaultManager] moveItemAtPath:d.path toPath:newPath error:&err]) {
			[pm notify:NPPN_FILERENAMECANCEL bufferID:d.bufferID];
			[self reportError:err];
			return;
		}
		d.path = newPath;
		if (d.language.isPlainText) [d setLanguageAndRestyle:[[QLanguageManager shared] detectForPath:newPath firstLine:@""]];
		[pm notify:NPPN_FILERENAMED bufferID:d.bufferID];
	}
	[self refreshTabs];
	[self updateStatus];
}

- (void)reloadFromDisk:(id)sender {
	QDocument *d = self.currentDocument;
	if (!d.path) return;
	if (d.isDirty) {
		NSAlert *a = [[NSAlert alloc] init];
		a.messageText = T(@"Reload and discard unsaved changes?", @"Recarregar e descartar as alterações não salvas?");
		[a addButtonWithTitle:T(@"Reload", @"Recarregar")];
		[a addButtonWithTitle:T(@"Cancel", @"Cancelar")];
		if ([a runModal] != NSAlertFirstButtonReturn) return;
	}
	NSError *err = nil;
	if (![d reloadWithEncoding:d.encoding error:&err]) [self reportError:err];
	[self refreshTabs];
	[[QPluginManager shared] notify:NPPN_BUFFERACTIVATED bufferID:d.bufferID];
}

- (void)closeTab:(id)sender {
	if (self.currentDocument) [self closeDocument:self.currentDocument prompt:YES];
}

- (void)closeAllTabs:(id)sender {
	for (QDocument *d in [self.docs copy])
		if (![self closeDocument:d prompt:YES]) break;
}

- (void)closeOtherTabs:(id)sender {
	QDocument *cur = self.currentDocument;
	for (QDocument *d in [self.docs copy])
		if (d != cur && ![self closeDocument:d prompt:YES]) break;
}

- (void)revealInFinder:(id)sender {
	QDocument *d = self.currentDocument;
	if (d.path) [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[ [NSURL fileURLWithPath:d.path] ]];
}

- (void)openInTerminal:(id)sender {
	QDocument *d = self.currentDocument;
	NSString *dir = d.path ? d.path.stringByDeletingLastPathComponent : NSHomeDirectory();
	NSURL *terminal = [[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier:@"com.apple.Terminal"];
	if (!terminal) return;
	NSWorkspaceOpenConfiguration *cfg = [NSWorkspaceOpenConfiguration configuration];
	[[NSWorkspace sharedWorkspace] openURLs:@[ [NSURL fileURLWithPath:dir] ] withApplicationAtURL:terminal configuration:cfg completionHandler:nil];
}

- (void)copyFullPath:(id)sender {
	QDocument *d = self.currentDocument;
	[[NSPasteboard generalPasteboard] clearContents];
	[[NSPasteboard generalPasteboard] setString:d.path ?: d.displayName forType:NSPasteboardTypeString];
}

- (void)copyFileName:(id)sender {
	QDocument *d = self.currentDocument;
	[[NSPasteboard generalPasteboard] clearContents];
	[[NSPasteboard generalPasteboard] setString:d.displayName forType:NSPasteboardTypeString];
}

- (void)printDocument:(id)sender {
	QDocument *d = self.currentDocument;
	if (!d) return;
	NSPrintInfo *info = [[NSPrintInfo sharedPrintInfo] copy];
	info.horizontalPagination = NSPrintingPaginationModeFit;
	info.verticalPagination = NSPrintingPaginationModeAutomatic;
	info.verticallyCentered = NO;
	CGFloat width = info.paperSize.width - info.leftMargin - info.rightMargin;
	NSTextView *tv = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, width, 100)];
	NSFont *font = [NSFont fontWithName:[QPrefs shared].editorFont.fontName size:10] ?: [NSFont monospacedSystemFontOfSize:10 weight:NSFontWeightRegular];
	tv.font = font;
	tv.string = d.text;
	tv.textColor = [NSColor blackColor];
	tv.backgroundColor = [NSColor whiteColor];
	tv.textContainer.widthTracksTextView = YES;
	[tv sizeToFit];
	NSPrintOperation *op = [NSPrintOperation printOperationWithView:tv printInfo:info];
	op.jobTitle = d.displayName;
	[op runOperationModalForWindow:self.window delegate:nil didRunSelector:nil contextInfo:nil];
}

// ---- Edit -------------------------------------------------------------------------------------

- (void)duplicateLine:(id)sender {
	ScintillaView *v = [self ed];
	if ([v message:SCI_GETSELECTIONEMPTY]) [v message:SCI_LINEDUPLICATE];
	else [v message:SCI_SELECTIONDUPLICATE];
}

- (void)deleteLine:(id)sender {
	[[self ed] message:SCI_LINEDELETE];
}

- (void)moveLineUp:(id)sender {
	[[self ed] message:SCI_MOVESELECTEDLINESUP];
}

- (void)moveLineDown:(id)sender {
	[[self ed] message:SCI_MOVESELECTEDLINESDOWN];
}

- (void)joinLines:(id)sender {
	ScintillaView *v = [self ed];
	sptr_t selStart = [v message:SCI_GETSELECTIONSTART];
	sptr_t selEnd = [v message:SCI_GETSELECTIONEND];
	if (selStart == selEnd) {
		sptr_t line = [v message:SCI_LINEFROMPOSITION wParam:(uptr_t)selStart];
		selEnd = [v message:SCI_GETLINEENDPOSITION wParam:(uptr_t)line + 1];
		selStart = [v message:SCI_POSITIONFROMLINE wParam:(uptr_t)line];
	}
	[v message:SCI_SETTARGETRANGE wParam:(uptr_t)selStart lParam:selEnd];
	[v message:SCI_LINESJOIN];
}

- (void)sortLinesAscending:(id)sender {
	[self transformLines:[](const std::string &s) { return quill::sortLines(s, quill::SortMode::Ascending); }];
}
- (void)sortLinesDescending:(id)sender {
	[self transformLines:[](const std::string &s) { return quill::sortLines(s, quill::SortMode::Descending); }];
}
- (void)sortLinesCaseInsensitive:(id)sender {
	[self transformLines:[](const std::string &s) { return quill::sortLines(s, quill::SortMode::AscendingCaseInsensitive); }];
}
- (void)sortLinesNumeric:(id)sender {
	[self transformLines:[](const std::string &s) { return quill::sortLines(s, quill::SortMode::Numeric); }];
}
- (void)removeDuplicateLines:(id)sender {
	[self transformLines:[](const std::string &s) { return quill::removeDuplicateLines(s); }];
}
- (void)removeEmptyLines:(id)sender {
	[self transformLines:[](const std::string &s) { return quill::removeEmptyLines(s); }];
}
- (void)trimTrailingWhitespace:(id)sender {
	ScintillaView *v = [self ed];
	if (!v || [v message:SCI_GETREADONLY]) return;
	// Line by line so markers and folding stay in place.
	sptr_t lines = [v message:SCI_GETLINECOUNT];
	[v message:SCI_BEGINUNDOACTION];
	for (sptr_t l = 0; l < lines; l++) {
		sptr_t start = [v message:SCI_POSITIONFROMLINE wParam:(uptr_t)l];
		sptr_t end = [v message:SCI_GETLINEENDPOSITION wParam:(uptr_t)l];
		sptr_t p = end;
		while (p > start) {
			int c = (int)[v message:SCI_GETCHARAT wParam:(uptr_t)p - 1];
			if (c != ' ' && c != '\t') break;
			p--;
		}
		if (p < end) [v message:SCI_DELETERANGE wParam:(uptr_t)p lParam:end - p];
	}
	[v message:SCI_ENDUNDOACTION];
}

- (void)toggleComment:(id)sender {
	QDocument *d = self.currentDocument;
	ScintillaView *v = d.editor;
	if (!v || [v message:SCI_GETREADONLY]) return;
	NSString *token = d.language.commentLine;
	if (!token.length) {
		[self blockComment:sender];
		return;
	}
	std::string tok(token.UTF8String);
	sptr_t selStart = [v message:SCI_GETSELECTIONSTART];
	sptr_t selEnd = [v message:SCI_GETSELECTIONEND];
	sptr_t l1 = [v message:SCI_LINEFROMPOSITION wParam:(uptr_t)selStart];
	sptr_t l2 = [v message:SCI_LINEFROMPOSITION wParam:(uptr_t)selEnd];
	if (l2 > l1 && [v message:SCI_POSITIONFROMLINE wParam:(uptr_t)l2] == selEnd) l2--;
	BOOL allCommented = YES;
	sptr_t minIndent = -1;
	for (sptr_t l = l1; l <= l2; l++) {
		sptr_t ip = [v message:SCI_GETLINEINDENTPOSITION wParam:(uptr_t)l];
		sptr_t end = [v message:SCI_GETLINEENDPOSITION wParam:(uptr_t)l];
		if (ip == end) continue; // blank
		sptr_t indentCol = [v message:SCI_GETLINEINDENTATION wParam:(uptr_t)l];
		if (minIndent < 0 || indentCol < minIndent) minIndent = indentCol;
		if (textRange(v, ip, MIN(end, ip + (sptr_t)tok.size())) != tok) allCommented = NO;
	}
	[v message:SCI_BEGINUNDOACTION];
	for (sptr_t l = l2; l >= l1; l--) {
		sptr_t ip = [v message:SCI_GETLINEINDENTPOSITION wParam:(uptr_t)l];
		sptr_t end = [v message:SCI_GETLINEENDPOSITION wParam:(uptr_t)l];
		if (ip == end) continue;
		if (allCommented) {
			sptr_t removeLen = (sptr_t)tok.size();
			if (ip + removeLen < end && [v message:SCI_GETCHARAT wParam:(uptr_t)(ip + removeLen)] == ' ') removeLen++;
			[v message:SCI_DELETERANGE wParam:(uptr_t)ip lParam:removeLen];
		} else {
			sptr_t at = [v message:SCI_FINDCOLUMN wParam:(uptr_t)l lParam:MAX((sptr_t)0, minIndent)];
			std::string ins = tok + " ";
			[v message:SCI_INSERTTEXT wParam:(uptr_t)at lParam:(sptr_t)ins.c_str()];
		}
	}
	[v message:SCI_ENDUNDOACTION];
}

- (void)blockComment:(id)sender {
	QDocument *d = self.currentDocument;
	ScintillaView *v = d.editor;
	NSString *open = d.language.commentStart, *close = d.language.commentEnd;
	if (!open.length || !close.length) {
		if (d.language.commentLine.length && sender != nil) [self toggleComment:nil];
		else NSBeep();
		return;
	}
	sptr_t s = [v message:SCI_GETSELECTIONSTART];
	sptr_t e = [v message:SCI_GETSELECTIONEND];
	std::string o(open.UTF8String), c(close.UTF8String);
	std::string sel = textRange(v, s, e);
	[v message:SCI_BEGINUNDOACTION];
	if (sel.size() >= o.size() + c.size() && sel.compare(0, o.size(), o) == 0 && sel.compare(sel.size() - c.size(), c.size(), c) == 0) {
		std::string inner = sel.substr(o.size(), sel.size() - o.size() - c.size());
		replaceRange(v, s, e, inner);
		[v message:SCI_SETSEL wParam:(uptr_t)s lParam:s + (sptr_t)inner.size()];
	} else {
		std::string wrapped = o + sel + c;
		replaceRange(v, s, e, wrapped);
		[v message:SCI_SETSEL wParam:(uptr_t)s lParam:s + (sptr_t)wrapped.size()];
	}
	[v message:SCI_ENDUNDOACTION];
}

- (void)transformSelection:(NSString * (^)(NSString *))f {
	ScintillaView *v = [self ed];
	if (!v || [v message:SCI_GETREADONLY]) return;
	sptr_t s = [v message:SCI_GETSELECTIONSTART];
	sptr_t e = [v message:SCI_GETSELECTIONEND];
	if (s == e) {
		s = [v message:SCI_WORDSTARTPOSITION wParam:(uptr_t)s lParam:1];
		e = [v message:SCI_WORDENDPOSITION wParam:(uptr_t)e lParam:1];
	}
	std::string text = textRange(v, s, e);
	NSString *in = [NSString stringWithUTF8String:text.c_str()];
	if (!in) return;
	std::string out(f(in).UTF8String);
	[v message:SCI_BEGINUNDOACTION];
	replaceRange(v, s, e, out);
	[v message:SCI_ENDUNDOACTION];
	[v message:SCI_SETSEL wParam:(uptr_t)s lParam:s + (sptr_t)out.size()];
}

- (void)makeUppercase:(id)sender {
	[self transformSelection:^NSString *(NSString *s) {
		return s.uppercaseString;
	}];
}
- (void)makeLowercase:(id)sender {
	[self transformSelection:^NSString *(NSString *s) {
		return s.lowercaseString;
	}];
}
- (void)makeTitleCase:(id)sender {
	[self transformSelection:^NSString *(NSString *s) {
		return s.capitalizedString;
	}];
}
- (void)invertCase:(id)sender {
	[self transformSelection:^NSString *(NSString *s) {
		NSMutableString *out = [NSMutableString stringWithCapacity:s.length];
		[s enumerateSubstringsInRange:NSMakeRange(0, s.length)
				      options:NSStringEnumerationByComposedCharacterSequences
				   usingBlock:^(NSString *ch, NSRange r, NSRange er, BOOL *stop) {
					   [out appendString:[ch isEqualToString:ch.uppercaseString] ? ch.lowercaseString : ch.uppercaseString];
				   }];
		return out;
	}];
}

- (void)indentLines:(id)sender {
	[[self ed] message:SCI_TAB];
}

- (void)unindentLines:(id)sender {
	[[self ed] message:SCI_BACKTAB];
}

- (void)tabsToSpaces:(id)sender {
	ScintillaView *v = [self ed];
	int width = (int)[v message:SCI_GETTABWIDTH];
	[self transformLines:[width](const std::string &s) {
		std::string out;
		int col = 0;
		for (char c : s) {
			if (c == '\t') {
				int n = width - (col % width);
				out.append(static_cast<size_t>(n), ' ');
				col += n;
			} else {
				out.push_back(c);
				col = (c == '\n' || c == '\r') ? 0 : col + ((static_cast<unsigned char>(c) & 0xC0) == 0x80 ? 0 : 1);
			}
		}
		return out;
	}];
}

- (void)spacesToTabs:(id)sender {
	ScintillaView *v = [self ed];
	int width = (int)[v message:SCI_GETTABWIDTH];
	[self transformLines:[width](const std::string &s) {
		std::string out;
		size_t i = 0;
		while (i < s.size()) {
			// leading whitespace of the line
			int spaces = 0;
			size_t j = i;
			while (j < s.size() && (s[j] == ' ' || s[j] == '\t')) {
				spaces += s[j] == '\t' ? width - (spaces % width) : 1;
				j++;
			}
			out.append(static_cast<size_t>(spaces / width), '\t');
			out.append(static_cast<size_t>(spaces % width), ' ');
			while (j < s.size() && s[j] != '\n' && s[j] != '\r') out.push_back(s[j++]);
			while (j < s.size() && (s[j] == '\n' || s[j] == '\r')) out.push_back(s[j++]);
			i = j;
		}
		return out;
	}];
}

- (void)selectNextOccurrence:(id)sender {
	ScintillaView *v = [self ed];
	[v message:SCI_TARGETWHOLEDOCUMENT];
	[v message:SCI_SETSEARCHFLAGS wParam:SCFIND_MATCHCASE];
	if ([v message:SCI_GETSELECTIONEMPTY]) {
		sptr_t pos = [v message:SCI_GETCURRENTPOS];
		sptr_t s = [v message:SCI_WORDSTARTPOSITION wParam:(uptr_t)pos lParam:1];
		sptr_t e = [v message:SCI_WORDENDPOSITION wParam:(uptr_t)pos lParam:1];
		if (e > s) [v message:SCI_SETSEL wParam:(uptr_t)s lParam:e];
		return;
	}
	[v message:SCI_MULTIPLESELECTADDNEXT];
	[v message:SCI_SCROLLCARET];
}

- (void)selectAllOccurrences:(id)sender {
	ScintillaView *v = [self ed];
	[v message:SCI_TARGETWHOLEDOCUMENT];
	[v message:SCI_SETSEARCHFLAGS wParam:SCFIND_MATCHCASE];
	if ([v message:SCI_GETSELECTIONEMPTY]) [self selectNextOccurrence:nil];
	[v message:SCI_MULTIPLESELECTADDEACH];
	[self setStatusMessage:[NSString stringWithFormat:T(@"%ld cursors", @"%ld cursores"), (long)[v message:SCI_GETSELECTIONS]]];
}

- (void)splitSelectionIntoLines:(id)sender {
	ScintillaView *v = [self ed];
	sptr_t s = [v message:SCI_GETSELECTIONSTART];
	sptr_t e = [v message:SCI_GETSELECTIONEND];
	sptr_t l1 = [v message:SCI_LINEFROMPOSITION wParam:(uptr_t)s];
	sptr_t l2 = [v message:SCI_LINEFROMPOSITION wParam:(uptr_t)e];
	if (l2 <= l1) return;
	BOOL first = YES;
	for (sptr_t l = l1; l <= l2; l++) {
		sptr_t end = [v message:SCI_GETLINEENDPOSITION wParam:(uptr_t)l];
		if (l == l2) end = e;
		if (first) {
			[v message:SCI_SETSELECTION wParam:(uptr_t)end lParam:end];
			first = NO;
		} else {
			[v message:SCI_ADDSELECTION wParam:(uptr_t)end lParam:end];
		}
	}
}

- (void)completeWord:(id)sender {
	QDocument *d = self.currentDocument;
	if (d) [self showWordCompletion:d force:YES];
}

- (void)insertDateTime:(id)sender {
	NSDateFormatter *f = [[NSDateFormatter alloc] init];
	f.dateStyle = NSDateFormatterShortStyle;
	f.timeStyle = NSDateFormatterShortStyle;
	std::string s([f stringFromDate:[NSDate date]].UTF8String);
	[[self ed] message:SCI_REPLACESEL wParam:0 lParam:(sptr_t)s.c_str()];
}

- (void)toggleReadOnly:(id)sender {
	QDocument *d = self.currentDocument;
	d.readOnly = !d.readOnly;
	[self refreshTabs];
	[[QPluginManager shared] notify:NPPN_READONLYCHANGED from:(void *)(uintptr_t)d.bufferID idFrom:d.readOnly ? DOCSTATUS_READONLY : 0];
}

// ---- Search -------------------------------------------------------------------------------------

- (void)showFind:(id)sender {
	[self showFindBarReplace:NO];
}

- (void)showReplace:(id)sender {
	[self showFindBarReplace:YES];
}

- (void)findNext:(id)sender {
	if (self.findBar.searchString.length == 0) {
		[self showFindBarReplace:NO];
		return;
	}
	[self.findBar findNext:NO];
}

- (void)findPrevious:(id)sender {
	if (self.findBar.searchString.length == 0) {
		[self showFindBarReplace:NO];
		return;
	}
	[self.findBar findNext:YES];
}

- (void)useSelectionForFind:(id)sender {
	[self.findBar useSelectionForFind];
}

- (void)findInFiles:(id)sender {
	QDocument *d = self.currentDocument;
	NSString *sel = d.editor.selectedString;
	if ([sel rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]].location != NSNotFound) sel = nil;
	[self.findInFiles showWithSearch:sel directory:d.path.stringByDeletingLastPathComponent];
}

- (void)markAllOccurrences:(id)sender {
	if (self.findBar.searchString.length == 0) {
		[self.findBar useSelectionForFind];
	}
	[self.findBar markAll];
}

- (void)clearMarks:(id)sender {
	[self.findBar clearMarks];
}

- (void)gotoLine:(id)sender {
	QDocument *d = self.currentDocument;
	if (!d) return;
	ScintillaView *v = d.editor;
	sptr_t lines = [v message:SCI_GETLINECOUNT];
	NSAlert *a = [[NSAlert alloc] init];
	a.messageText = T(@"Go to Line", @"Ir para a linha");
	a.informativeText = [NSString stringWithFormat:T(@"Line number (1 – %ld), optionally \"line:column\":", @"Número da linha (1 – %ld), opcionalmente \"linha:coluna\":"), (long)lines];
	NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
	sptr_t cur = [v message:SCI_LINEFROMPOSITION wParam:(uptr_t)[v message:SCI_GETCURRENTPOS]];
	field.stringValue = [NSString stringWithFormat:@"%ld", (long)cur + 1];
	a.accessoryView = field;
	[a addButtonWithTitle:T(@"Go", @"Ir")];
	[a addButtonWithTitle:T(@"Cancel", @"Cancelar")];
	a.window.initialFirstResponder = field;
	if ([a runModal] != NSAlertFirstButtonReturn) return;
	NSArray *parts = [field.stringValue componentsSeparatedByString:@":"];
	NSInteger line = [parts[0] integerValue];
	NSInteger col = parts.count > 1 ? [parts[1] integerValue] : 1;
	if (line < 1) return;
	[self gotoLine:MIN(line, (NSInteger)lines) column:col inDocument:d];
}

- (void)gotoMatchingBrace:(id)sender {
	ScintillaView *v = [self ed];
	sptr_t pos = [v message:SCI_GETCURRENTPOS];
	sptr_t match = [v message:SCI_BRACEMATCH wParam:(uptr_t)pos lParam:0];
	if (match < 0 && pos > 0) match = [v message:SCI_BRACEMATCH wParam:(uptr_t)pos - 1 lParam:0];
	if (match >= 0) [v message:SCI_GOTOPOS wParam:(uptr_t)match];
	else NSBeep();
}

- (void)toggleBookmark:(id)sender {
	ScintillaView *v = [self ed];
	sptr_t line = [v message:SCI_LINEFROMPOSITION wParam:(uptr_t)[v message:SCI_GETCURRENTPOS]];
	int mask = (int)[v message:SCI_MARKERGET wParam:(uptr_t)line];
	if (mask & (1 << QMarkerBookmark)) [v message:SCI_MARKERDELETE wParam:(uptr_t)line lParam:QMarkerBookmark];
	else [v message:SCI_MARKERADD wParam:(uptr_t)line lParam:QMarkerBookmark];
}

- (void)nextBookmark:(id)sender {
	ScintillaView *v = [self ed];
	sptr_t line = [v message:SCI_LINEFROMPOSITION wParam:(uptr_t)[v message:SCI_GETCURRENTPOS]];
	sptr_t next = [v message:SCI_MARKERNEXT wParam:(uptr_t)line + 1 lParam:1 << QMarkerBookmark];
	if (next < 0) next = [v message:SCI_MARKERNEXT wParam:0 lParam:1 << QMarkerBookmark];
	if (next >= 0) {
		[v message:SCI_ENSUREVISIBLEENFORCEPOLICY wParam:(uptr_t)next];
		[v message:SCI_GOTOLINE wParam:(uptr_t)next];
	} else {
		NSBeep();
	}
}

- (void)previousBookmark:(id)sender {
	ScintillaView *v = [self ed];
	sptr_t line = [v message:SCI_LINEFROMPOSITION wParam:(uptr_t)[v message:SCI_GETCURRENTPOS]];
	sptr_t prev = line > 0 ? [v message:SCI_MARKERPREVIOUS wParam:(uptr_t)line - 1 lParam:1 << QMarkerBookmark] : -1;
	if (prev < 0) prev = [v message:SCI_MARKERPREVIOUS wParam:(uptr_t)[v message:SCI_GETLINECOUNT] lParam:1 << QMarkerBookmark];
	if (prev >= 0) {
		[v message:SCI_ENSUREVISIBLEENFORCEPOLICY wParam:(uptr_t)prev];
		[v message:SCI_GOTOLINE wParam:(uptr_t)prev];
	} else {
		NSBeep();
	}
}

- (void)clearBookmarks:(id)sender {
	[[self ed] message:SCI_MARKERDELETEALL wParam:QMarkerBookmark];
}

// ---- View --------------------------------------------------------------------------------------------

- (void)toggleToolbarVisible:(id)sender {
	QPrefs *p = [QPrefs shared];
	p.showToolbar = !p.showToolbar;
	self.window.toolbar.visible = p.showToolbar;
}

- (void)toggleStatusBar:(id)sender {
	QPrefs *p = [QPrefs shared];
	p.showStatusBar = !p.showStatusBar;
	self.window.contentView.needsLayout = YES;
	[self.window.contentView layoutSubtreeIfNeeded];
}

- (void)toggleWordWrap:(id)sender {
	QPrefs *p = [QPrefs shared];
	p.wordWrap = !p.wordWrap;
}
- (void)toggleWhitespace:(id)sender {
	QPrefs *p = [QPrefs shared];
	p.showWhitespace = !p.showWhitespace;
}
- (void)toggleEOL:(id)sender {
	QPrefs *p = [QPrefs shared];
	p.showEOL = !p.showEOL;
}
- (void)toggleIndentGuides:(id)sender {
	QPrefs *p = [QPrefs shared];
	p.showIndentGuides = !p.showIndentGuides;
}
- (void)toggleLineNumbers:(id)sender {
	QPrefs *p = [QPrefs shared];
	p.showLineNumbers = !p.showLineNumbers;
}
- (void)toggleFoldMargin:(id)sender {
	QPrefs *p = [QPrefs shared];
	p.showFoldMargin = !p.showFoldMargin;
}
- (void)toggleHighlightCurrentLine:(id)sender {
	QPrefs *p = [QPrefs shared];
	p.highlightCurrentLine = !p.highlightCurrentLine;
}

- (void)zoomIn:(id)sender {
	for (QDocument *d in self.docs) [d.editor message:SCI_ZOOMIN];
}
- (void)zoomOut:(id)sender {
	for (QDocument *d in self.docs) [d.editor message:SCI_ZOOMOUT];
}
- (void)zoomReset:(id)sender {
	for (QDocument *d in self.docs) [d.editor message:SCI_SETZOOM wParam:0];
}

- (void)foldAll:(id)sender {
	[[self ed] message:SCI_FOLDALL wParam:SC_FOLDACTION_CONTRACT];
}
- (void)unfoldAll:(id)sender {
	[[self ed] message:SCI_FOLDALL wParam:SC_FOLDACTION_EXPAND];
}
- (void)toggleCurrentFold:(id)sender {
	ScintillaView *v = [self ed];
	sptr_t line = [v message:SCI_LINEFROMPOSITION wParam:(uptr_t)[v message:SCI_GETCURRENTPOS]];
	int level = (int)[v message:SCI_GETFOLDLEVEL wParam:(uptr_t)line];
	if (!(level & SC_FOLDLEVELHEADERFLAG)) line = [v message:SCI_GETFOLDPARENT wParam:(uptr_t)line];
	if (line >= 0) [v message:SCI_TOGGLEFOLD wParam:(uptr_t)line];
}

- (void)setThemeMode:(NSMenuItem *)sender {
	[QPrefs shared].theme = (QThemeMode)sender.tag;
}

// ---- Encoding / language ------------------------------------------------------------------------------

- (void)setDocumentEncoding:(NSMenuItem *)sender {
	QDocument *d = self.currentDocument;
	if (!d || d.encoding == (QEncoding)sender.tag) return;
	d.encoding = (QEncoding)sender.tag;
	d.forcedDirty = YES;
	[self refreshTabs];
	[self updateStatus];
	[self setStatusMessage:[NSString stringWithFormat:T(@"The file will be saved as %@.", @"O arquivo será salvo como %@."), QEncodingName(d.encoding)]];
}

- (void)reopenWithEncoding:(NSMenuItem *)sender {
	QDocument *d = self.currentDocument;
	if (!d.path) {
		NSBeep();
		return;
	}
	if (d.isDirty) {
		NSAlert *a = [[NSAlert alloc] init];
		a.messageText = T(@"Reopen and discard unsaved changes?", @"Reabrir e descartar as alterações não salvas?");
		[a addButtonWithTitle:T(@"Reopen", @"Reabrir")];
		[a addButtonWithTitle:T(@"Cancel", @"Cancelar")];
		if ([a runModal] != NSAlertFirstButtonReturn) return;
	}
	NSError *err = nil;
	if (![d reloadWithEncoding:(QEncoding)sender.tag error:&err]) [self reportError:err];
	[self refreshTabs];
	[self updateStatus];
}

- (void)setDocumentLineEnding:(NSMenuItem *)sender {
	QDocument *d = self.currentDocument;
	if (!d || [d.editor message:SCI_GETREADONLY]) return;
	[d convertLineEndingsTo:(QLineEnding)sender.tag];
	[self updateStatus];
}

- (void)setDocumentLanguage:(NSMenuItem *)sender {
	QDocument *d = self.currentDocument;
	QLanguage *l = [[QLanguageManager shared] languageNamed:sender.representedObject];
	if (!d || !l) return;
	[d setLanguageAndRestyle:l];
	[self updateStatus];
	[[QPluginManager shared] notify:NPPN_LANGCHANGED bufferID:d.bufferID];
}

// ---- Tabs -----------------------------------------------------------------------------------------------

- (void)selectNextTab:(id)sender {
	if (self.docs.count < 2) return;
	[self activateDocument:self.docs[(NSUInteger)((self.currentIndex + 1) % (NSInteger)self.docs.count)]];
}

- (void)selectPreviousTab:(id)sender {
	if (self.docs.count < 2) return;
	NSInteger n = (NSInteger)self.docs.count;
	[self activateDocument:self.docs[(NSUInteger)((self.currentIndex - 1 + n) % n)]];
}

- (void)selectTabNumber:(NSMenuItem *)sender {
	NSInteger i = sender.tag == 9 ? (NSInteger)self.docs.count - 1 : sender.tag - 1;
	if (i >= 0 && i < (NSInteger)self.docs.count) [self activateDocument:self.docs[(NSUInteger)i]];
}

// ---- Validation ---------------------------------------------------------------------------------------------

- (BOOL)validateMenuItem:(NSMenuItem *)item {
	SEL a = item.action;
	QPrefs *p = [QPrefs shared];
	QDocument *d = self.currentDocument;
	if (a == @selector(toggleWordWrap:)) item.state = p.wordWrap;
	else if (a == @selector(toggleWhitespace:)) item.state = p.showWhitespace;
	else if (a == @selector(toggleEOL:)) item.state = p.showEOL;
	else if (a == @selector(toggleIndentGuides:)) item.state = p.showIndentGuides;
	else if (a == @selector(toggleLineNumbers:)) item.state = p.showLineNumbers;
	else if (a == @selector(toggleFoldMargin:)) item.state = p.showFoldMargin;
	else if (a == @selector(toggleHighlightCurrentLine:)) item.state = p.highlightCurrentLine;
	else if (a == @selector(toggleStatusBar:)) item.state = p.showStatusBar;
	else if (a == @selector(toggleToolbarVisible:)) item.state = self.window.toolbar.visible;
	else if (a == @selector(setThemeMode:)) item.state = item.tag == p.theme;
	else if (a == @selector(setDocumentEncoding:)) item.state = d && item.tag == d.encoding;
	else if (a == @selector(reopenWithEncoding:)) {
		item.state = d && item.tag == d.encoding;
		return d.path != nil;
	} else if (a == @selector(setDocumentLineEnding:)) item.state = d && item.tag == d.lineEnding;
	else if (a == @selector(setDocumentLanguage:)) item.state = d && [d.language.name isEqualToString:item.representedObject];
	else if (a == @selector(toggleReadOnly:)) item.state = d.readOnly;
	else if (a == @selector(selectDocumentFromMenu:)) item.state = d && (NSUInteger)item.tag == d.bufferID;
	if (a == @selector(revealInFinder:) || a == @selector(reloadFromDisk:)) return d.path != nil;
	if (a == @selector(reopenClosedTab:)) return self.closedPaths.count > 0;
	if (a == @selector(saveDocument:)) return d != nil;
	return YES;
}

- (BOOL)validateToolbarItem:(NSToolbarItem *)item {
	return YES;
}

@end
