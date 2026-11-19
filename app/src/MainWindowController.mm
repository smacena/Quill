// SPDX-License-Identifier: GPL-3.0-or-later
#import "MainWindowController+Private.h"
#import "Languages.h"
#import "Localization.h"
#import "MainMenu.h"
#import "Preferences.h"

#import "ScintillaView.h"
#include "Notepad_plus_msgs.h"
#include "QuillExtensions.h"
#include <string>

@implementation QPanelRecord
@end

// A flipped container that runs a block to lay out its subviews.
@interface QLayoutView : NSView
@property (nonatomic, copy) void (^layoutBlock)(NSView *view);
@end
@implementation QLayoutView
- (BOOL)isFlipped {
	return YES;
}
- (void)layout {
	[super layout];
	if (self.layoutBlock) self.layoutBlock(self);
}
- (void)resizeSubviewsWithOldSize:(NSSize)oldSize {
	[super resizeSubviewsWithOldSize:oldSize];
	if (self.layoutBlock) self.layoutBlock(self);
}
@end

static NSString *const kToolbarNew = @"new";
static NSString *const kToolbarOpen = @"open";
static NSString *const kToolbarSave = @"save";
static NSString *const kToolbarSaveAll = @"saveAll";
static NSString *const kToolbarFind = @"find";
static NSString *const kToolbarReplace = @"replace";
static NSString *const kToolbarUndo = @"undo";
static NSString *const kToolbarRedo = @"redo";
static NSString *const kToolbarWrap = @"wrap";
static NSString *const kToolbarWhitespace = @"whitespace";
static NSString *const kToolbarZoomIn = @"zoomIn";
static NSString *const kToolbarZoomOut = @"zoomOut";
static NSString *const kToolbarPluginPrefix = @"plugin.";

static NSString *appSupportDir(void) {
	NSString *dir = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject
		stringByAppendingPathComponent:@"Quill"];
	[[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
	return dir;
}

static NSString *backupDir(void) {
	NSString *dir = [appSupportDir() stringByAppendingPathComponent:@"backup"];
	[[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
	return dir;
}

@implementation QMainWindowController {
	NSTimer *_backupTimer;
	NSTimer *_wordListTimer;
}

+ (instancetype)shared {
	static QMainWindowController *c;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		c = [[QMainWindowController alloc] init];
	});
	return c;
}

- (instancetype)init {
	NSWindow *w = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1100, 720)
						  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable |
							    NSWindowStyleMaskResizable
						    backing:NSBackingStoreBuffered
						      defer:NO];
	if ((self = [super initWithWindow:w])) {
		_docs = [NSMutableArray array];
		_currentIndex = -1;
		_closedPaths = [NSMutableArray array];
		_panels = [NSMutableArray array];
		_contextMenuHandlers = [NSMutableArray array];
		_pluginToolbarButtons = [NSMutableArray array];
		[self buildWindow];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(prefsChanged:) name:QPrefsChangedNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidBecomeActive:) name:NSApplicationDidBecomeActiveNotification object:nil];
		[NSApp addObserver:self forKeyPath:@"effectiveAppearance" options:0 context:nil];
		[QPluginManager shared].host = self;
		__weak QMainWindowController *weakSelf = self;
		[QEditorView setContextMenuBuilder:^NSMenu *(QEditorView *view, NSEvent *event) {
			return [weakSelf contextMenuForEditor:view event:event];
		}];
	}
	return self;
}

// ---- Window construction -------------------------------------------------------------

- (void)buildWindow {
	NSWindow *w = self.window;
	w.title = @"Quill";
	w.delegate = self;
	w.minSize = NSMakeSize(480, 300);
	w.tabbingMode = NSWindowTabbingModeDisallowed;
	w.collectionBehavior |= NSWindowCollectionBehaviorFullScreenPrimary;
	[w center];
	[w setFrameAutosaveName:@"QuillMainWindow"];

	NSToolbar *tb = [[NSToolbar alloc] initWithIdentifier:@"QuillToolbar"];
	tb.delegate = self;
	tb.displayMode = NSToolbarDisplayModeIconOnly;
	tb.allowsUserCustomization = YES;
	tb.autosavesConfiguration = YES;
	w.toolbar = tb;
	w.toolbarStyle = NSWindowToolbarStyleUnified;
	tb.visible = [QPrefs shared].showToolbar;

	QLayoutView *content = [[QLayoutView alloc] initWithFrame:w.contentView.bounds];
	w.contentView = content;

	_statusBar = [[QStatusBar alloc] initWithFrame:NSZeroRect];
	__weak QMainWindowController *weakSelf = self;
	_statusBar.encodingClicked = ^(NSView *anchor) {
		[weakSelf popUpMenu:[QMainMenu shared].encodingMenu from:anchor];
	};
	_statusBar.lineEndingClicked = ^(NSView *anchor) {
		[weakSelf popUpMenu:[QMainMenu shared].lineEndingMenu from:anchor];
	};
	_statusBar.languageClicked = ^(NSView *anchor) {
		[weakSelf popUpMenu:[QMainMenu shared].languageMenu from:anchor];
	};
	_statusBar.positionClicked = ^(NSView *anchor) {
		[NSApp sendAction:@selector(gotoLine:) to:nil from:anchor];
	};

	_leftArea = [[QPanelArea alloc] initWithFrame:NSMakeRect(0, 0, 240, 400)];
	_rightArea = [[QPanelArea alloc] initWithFrame:NSMakeRect(0, 0, 300, 400)];
	_bottomArea = [[QPanelArea alloc] initWithFrame:NSMakeRect(0, 0, 600, 200)];
	for (QPanelArea *area in @[ _leftArea, _rightArea, _bottomArea ]) {
		area.hidden = YES;
		area.visibilityChanged = ^(QPanelArea *a) {
			[weakSelf areaVisibilityChanged:a];
		};
		area.panelClosed = ^(NSView *panel) {
			[weakSelf panelClosedByUser:panel];
		};
	}

	// Editor area: tab bar, find bar, editor.
	QLayoutView *editorArea = [[QLayoutView alloc] initWithFrame:NSMakeRect(0, 0, 600, 400)];
	_editorArea = editorArea;
	_tabBar = [[QTabBar alloc] initWithFrame:NSZeroRect];
	_tabBar.delegate = self;
	_findBar = [[QFindBar alloc] initWithFrame:NSZeroRect];
	_findBar.delegate = self;
	_findBar.hidden = YES;
	_editorHost = [[NSView alloc] initWithFrame:NSZeroRect];
	[editorArea addSubview:_tabBar];
	[editorArea addSubview:_findBar];
	[editorArea addSubview:_editorHost];
	editorArea.layoutBlock = ^(NSView *v) {
		QMainWindowController *s = weakSelf;
		if (!s) return;
		NSRect b = v.bounds;
		CGFloat y = 0;
		s.tabBar.frame = NSMakeRect(0, 0, b.size.width, 30);
		y = 30;
		if (s.findBarVisible) {
			CGFloat fh = [s.findBar preferredHeight];
			s.findBar.frame = NSMakeRect(0, y, b.size.width, fh);
			y += fh;
		}
		s.editorHost.frame = NSMakeRect(0, y, b.size.width, MAX(0, b.size.height - y));
		for (NSView *sub in s.editorHost.subviews) sub.frame = s.editorHost.bounds;
	};

	_vSplit = [[NSSplitView alloc] initWithFrame:NSMakeRect(0, 0, 600, 600)];
	_vSplit.vertical = NO;
	_vSplit.dividerStyle = NSSplitViewDividerStyleThin;
	_vSplit.delegate = self;
	[_vSplit addSubview:_editorArea];
	[_vSplit addSubview:_bottomArea];
	[_vSplit setHoldingPriority:NSLayoutPriorityDefaultLow - 10 forSubviewAtIndex:0];
	[_vSplit setHoldingPriority:NSLayoutPriorityDefaultLow + 10 forSubviewAtIndex:1];

	_hSplit = [[NSSplitView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 600)];
	_hSplit.vertical = YES;
	_hSplit.dividerStyle = NSSplitViewDividerStyleThin;
	_hSplit.delegate = self;
	[_hSplit addSubview:_leftArea];
	[_hSplit addSubview:_vSplit];
	[_hSplit addSubview:_rightArea];
	[_hSplit setHoldingPriority:NSLayoutPriorityDefaultLow + 10 forSubviewAtIndex:0];
	[_hSplit setHoldingPriority:NSLayoutPriorityDefaultLow - 10 forSubviewAtIndex:1];
	[_hSplit setHoldingPriority:NSLayoutPriorityDefaultLow + 10 forSubviewAtIndex:2];

	[content addSubview:_hSplit];
	[content addSubview:_statusBar];
	content.layoutBlock = ^(NSView *v) {
		QMainWindowController *s = weakSelf;
		if (!s) return;
		NSRect b = v.bounds;
		BOOL showStatus = [QPrefs shared].showStatusBar;
		CGFloat sh = showStatus ? 24 : 0;
		s.statusBar.hidden = !showStatus;
		s.hSplit.frame = NSMakeRect(0, 0, b.size.width, b.size.height - sh);
		s.statusBar.frame = NSMakeRect(0, b.size.height - sh, b.size.width, sh);
	};
	_lastDark = [QEditorStyler isDark];
	[self applyTheme];

	_findInFiles = [[QFindInFilesController alloc] init];
	[self registerPanel:_findInFiles.resultsView title:T(@"Search Results", @"Resultados da busca") position:QPanelBottom];
	_findInFiles.showResults = ^{
		QMainWindowController *s = weakSelf;
		[s showPanel:s.findInFiles.resultsView];
	};
	_findInFiles.openHit = ^(QSearchHit *hit) {
		QMainWindowController *s = weakSelf;
		QDocument *d = [s openPath:hit.path];
		if (d) [s selectHit:hit inDocument:d];
	};
	_findInFiles.filesModified = ^(NSArray<NSString *> *paths) {
		QMainWindowController *s = weakSelf;
		for (NSString *p in paths) {
			QDocument *d = [s documentForPath:p];
			if (d && !d.isDirty) [d loadFromPath:p error:nil];
		}
		[s refreshTabs];
	};
	_findInFiles.dirtyPaths = ^NSSet<NSString *> * {
		NSMutableSet *set = [NSMutableSet set];
		for (QDocument *d in weakSelf.docs)
			if (d.isDirty && d.path) [set addObject:d.path];
		return set;
	};
}

- (void)selectHit:(QSearchHit *)hit inDocument:(QDocument *)d {
	[self activateDocument:d];
	ScintillaView *v = d.editor;
	sptr_t lineStart = [v message:SCI_POSITIONFROMLINE wParam:(uptr_t)MAX(0, hit.line - 1)];
	sptr_t lineEnd = [v message:SCI_GETLINEENDPOSITION wParam:(uptr_t)MAX(0, hit.line - 1)];
	// Convert the UTF-16 column of the match to a byte position.
	sptr_t len = lineEnd - lineStart;
	std::string line(static_cast<size_t>(len) + 1, '\0');
	Sci_TextRangeFull tr;
	tr.chrg.cpMin = lineStart;
	tr.chrg.cpMax = lineEnd;
	tr.lpstrText = line.data();
	[v message:SCI_GETTEXTRANGEFULL wParam:0 lParam:(sptr_t)&tr];
	NSString *lineStr = [NSString stringWithUTF8String:line.c_str()] ?: @"";
	NSInteger col = MIN(hit.column, (NSInteger)lineStr.length);
	NSInteger end = MIN(hit.column + hit.matchLength, (NSInteger)lineStr.length);
	sptr_t startByte = lineStart + (sptr_t)strlen([[lineStr substringToIndex:(NSUInteger)col] UTF8String]);
	sptr_t endByte = lineStart + (sptr_t)strlen([[lineStr substringToIndex:(NSUInteger)end] UTF8String]);
	[v message:SCI_ENSUREVISIBLEENFORCEPOLICY wParam:(uptr_t)MAX(0, hit.line - 1)];
	[v message:SCI_SETSEL wParam:(uptr_t)startByte lParam:endByte];
	[v message:SCI_SCROLLCARET];
	[self.window makeFirstResponder:v.content];
}

- (void)popUpMenu:(NSMenu *)menu from:(NSView *)anchor {
	[self validateMenu:menu];
	[menu popUpMenuPositioningItem:nil atLocation:NSMakePoint(0, anchor.bounds.size.height + 4) inView:anchor];
}

- (void)validateMenu:(NSMenu *)menu {
	for (NSMenuItem *mi in menu.itemArray) {
		if (mi.submenu) [self validateMenu:mi.submenu];
		else if (mi.action) [self validateMenuItem:mi];
	}
}

- (void)applyTheme {
	QThemeMode mode = [QPrefs shared].theme;
	if (mode == QThemeModeLight) NSApp.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
	else if (mode == QThemeModeDark) NSApp.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
	else NSApp.appearance = nil;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if ([keyPath isEqualToString:@"effectiveAppearance"]) {
		BOOL dark = [QEditorStyler isDark];
		if (dark != _lastDark) {
			_lastDark = dark;
			[self restyleAllDocuments];
			[[QPluginManager shared] notify:NPPN_DARKMODECHANGED bufferID:0];
			[[QPluginManager shared] notify:QUILLN_THEMECHANGED from:[QPluginManager nppHandle] idFrom:dark ? 1 : 0];
		}
	}
}

- (void)prefsChanged:(NSNotification *)note {
	[self applyTheme];
	self.window.toolbar.visible = [QPrefs shared].showToolbar;
	_lastDark = [QEditorStyler isDark];
	[self restyleAllDocuments];
	self.window.contentView.needsLayout = YES;
	[[QPluginManager shared] notify:NPPN_WORDSTYLESUPDATED bufferID:self.currentDocument.bufferID];
}

- (void)restyleAllDocuments {
	for (QDocument *d in _docs) [d restyle];
	for (QPanelRecord *r in _panels) r.view.needsDisplay = YES;
	[_tabBar setNeedsDisplay:YES];
}

// ---- Launch / session ------------------------------------------------------------------

- (void)finishLaunchingWithFiles:(NSArray<NSString *> *)files {
	QPluginManager *pm = [QPluginManager shared];
	[pm loadPlugins];
	[self rebuildPluginMenu];
	[pm notify:NPPN_TBMODIFICATION bufferID:0];
	if ([QPrefs shared].restoreSession) [self restoreSession];
	for (NSString *f in files) [self openPath:f];
	if (_docs.count == 0) [self newDocumentWithText:nil language:nil];
	[self refreshRecentMenu];
	[self showWindow:nil];
	[self.window makeKeyAndOrderFront:nil];
	[pm notify:NPPN_READY bufferID:0];
	[pm notify:NPPN_BUFFERACTIVATED bufferID:self.currentDocument.bufferID];
	_backupTimer = [NSTimer scheduledTimerWithTimeInterval:30 target:self selector:@selector(backupTick:) userInfo:nil repeats:YES];
}

- (void)backupTick:(NSTimer *)t {
	if ([QPrefs shared].backupUnsaved) [self saveSession];
}

- (NSString *)sessionPath {
	return [appSupportDir() stringByAppendingPathComponent:@"session.json"];
}

- (void)saveSession {
	NSMutableArray *entries = [NSMutableArray array];
	NSMutableSet *usedBackups = [NSMutableSet set];
	BOOL backup = [QPrefs shared].backupUnsaved;
	for (QDocument *d in _docs) {
		NSMutableDictionary *e = [NSMutableDictionary dictionary];
		if (d.path) e[@"path"] = d.path;
		if (d.untitledName) e[@"untitled"] = d.untitledName;
		e[@"language"] = d.language.name ?: @"normal";
		e[@"encoding"] = @(d.encoding);
		e[@"eol"] = @(d.lineEnding);
		e[@"position"] = @([d.editor message:SCI_GETCURRENTPOS]);
		e[@"anchor"] = @([d.editor message:SCI_GETANCHOR]);
		e[@"firstLine"] = @([d.editor message:SCI_GETFIRSTVISIBLELINE]);
		BOOL needsBackup = backup && (d.isDirty || (d.isUntitled && [d.editor message:SCI_GETLENGTH] > 0));
		if (needsBackup) {
			if (!d.backupPath)
				d.backupPath = [backupDir() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%lu.txt", [[NSUUID UUID] UUIDString], (unsigned long)d.bufferID]];
			std::string text = [d utf8Text];
			[[NSData dataWithBytes:text.data() length:text.size()] writeToFile:d.backupPath atomically:YES];
			e[@"backup"] = d.backupPath;
			[usedBackups addObject:d.backupPath.lastPathComponent];
		} else if (d.isUntitled) {
			continue; // empty untitled documents are not kept
		}
		[entries addObject:e];
	}
	NSInteger current = 0;
	QDocument *cur = self.currentDocument;
	for (NSUInteger i = 0; i < entries.count; i++) {
		NSDictionary *e = entries[i];
		if ((cur.path && [e[@"path"] isEqualToString:cur.path]) || (!cur.path && [e[@"untitled"] isEqualToString:cur.untitledName]))
			current = (NSInteger)i;
	}
	NSDictionary *session = @{@"documents" : entries, @"current" : @(current), @"untitledCounter" : @(_untitledCounter)};
	NSData *json = [NSJSONSerialization dataWithJSONObject:session options:NSJSONWritingPrettyPrinted error:nil];
	[json writeToFile:[self sessionPath] atomically:YES];
	// Remove stale backups.
	for (NSString *f in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:backupDir() error:nil])
		if (![usedBackups containsObject:f])
			[[NSFileManager defaultManager] removeItemAtPath:[backupDir() stringByAppendingPathComponent:f] error:nil];
}

- (void)restoreSession {
	NSData *data = [NSData dataWithContentsOfFile:[self sessionPath]];
	if (!data) return;
	NSDictionary *session = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
	if (![session isKindOfClass:[NSDictionary class]]) return;
	_restoringSession = YES;
	_untitledCounter = [session[@"untitledCounter"] integerValue];
	QLanguageManager *lm = [QLanguageManager shared];
	for (NSDictionary *e in session[@"documents"]) {
		NSString *path = e[@"path"];
		NSString *backup = e[@"backup"];
		QDocument *d = nil;
		if (path && [[NSFileManager defaultManager] fileExistsAtPath:path]) {
			d = [self openPath:path];
		} else if (backup && [[NSFileManager defaultManager] fileExistsAtPath:backup]) {
			d = [self newDocumentWithText:nil language:nil];
			if (e[@"untitled"]) d.untitledName = e[@"untitled"];
			if (path) {
				d.path = path;
				d.fileMissing = YES;
			}
		}
		if (!d) continue;
		if (backup && [[NSFileManager defaultManager] fileExistsAtPath:backup]) {
			NSData *b = [NSData dataWithContentsOfFile:backup];
			std::string text(static_cast<const char *>(b.bytes), b.length);
			[d.editor message:SCI_SETTEXT wParam:0 lParam:(sptr_t)text.c_str()];
			[d.editor message:SCI_EMPTYUNDOBUFFER];
			d.backupPath = backup;
			if (d.isUntitled) {
				// keep it dirty so the user is reminded to save it
			}
		}
		QLanguage *lang = [lm languageNamed:e[@"language"]];
		if (lang && lang != d.language) [d setLanguageAndRestyle:lang];
		if (backup) {
			d.encoding = (QEncoding)[e[@"encoding"] integerValue];
			d.lineEnding = (QLineEnding)[e[@"eol"] integerValue];
		}
		sptr_t len = [d.editor message:SCI_GETLENGTH];
		sptr_t pos = MIN((sptr_t)[e[@"position"] longLongValue], len);
		sptr_t anchor = MIN((sptr_t)[e[@"anchor"] longLongValue], len);
		[d.editor message:SCI_SETSEL wParam:(uptr_t)anchor lParam:pos];
		[d.editor message:SCI_SETFIRSTVISIBLELINE wParam:(uptr_t)[e[@"firstLine"] longLongValue]];
	}
	NSInteger current = [session[@"current"] integerValue];
	if (current >= 0 && current < (NSInteger)_docs.count) [self activateDocument:_docs[(NSUInteger)current]];
	_restoringSession = NO;
	[self refreshTabs];
}

// ---- Documents -----------------------------------------------------------------------

- (NSArray<QDocument *> *)documents {
	return _docs;
}

- (QDocument *)currentDocument {
	return (_currentIndex >= 0 && _currentIndex < (NSInteger)_docs.count) ? _docs[(NSUInteger)_currentIndex] : nil;
}

- (NSInteger)indexOfDocument:(QDocument *)doc {
	NSUInteger i = [_docs indexOfObjectIdenticalTo:doc];
	return i == NSNotFound ? -1 : (NSInteger)i;
}

- (QDocument *)documentForBufferID:(NSUInteger)bufferID {
	for (QDocument *d in _docs)
		if (d.bufferID == bufferID) return d;
	return nil;
}

- (QDocument *)documentForPath:(NSString *)path {
	NSString *std = path.stringByStandardizingPath;
	for (QDocument *d in _docs)
		if (d.path && [d.path.stringByStandardizingPath isEqualToString:std]) return d;
	return nil;
}

- (void)addDocument:(QDocument *)doc {
	doc.notificationTarget = self;
	[[QPluginManager shared] registerScintillaView:doc.editor];
	NSInteger insertAt = _currentIndex >= 0 ? _currentIndex + 1 : (NSInteger)_docs.count;
	// A single empty untitled document is replaced by the next opened file.
	QDocument *cur = self.currentDocument;
	if (cur && _docs.count == 1 && cur.isUntitled && !cur.isDirty && [cur.editor message:SCI_GETLENGTH] == 0 && doc.path) {
		[_docs removeObjectAtIndex:0];
		[cur.editor removeFromSuperview];
		insertAt = 0;
		_currentIndex = -1;
	}
	[_docs insertObject:doc atIndex:(NSUInteger)MIN(insertAt, (NSInteger)_docs.count)];
}

- (QDocument *)newDocumentWithText:(NSString *)text language:(QLanguage *)language {
	_untitledCounter++;
	QDocument *d = [[QDocument alloc] initUntitled:[NSString stringWithFormat:T(@"new %ld", @"novo %ld"), (long)_untitledCounter]];
	if (text.length) {
		[d setText:text];
		[d.editor message:SCI_EMPTYUNDOBUFFER];
	}
	if (language) [d setLanguageAndRestyle:language];
	[self addDocument:d];
	[self activateDocument:d];
	[[QPluginManager shared] notify:NPPN_FILEOPENED bufferID:d.bufferID];
	return d;
}

- (QDocument *)openPath:(NSString *)path {
	return [self openPath:path line:0 column:0];
}

- (QDocument *)openPath:(NSString *)path line:(NSInteger)line column:(NSInteger)column {
	if (!path.length) return nil;
	path = path.stringByExpandingTildeInPath.stringByStandardizingPath;
	QDocument *existing = [self documentForPath:path];
	if (existing) {
		[self activateDocument:existing];
		if (line > 0) [self gotoLine:line column:column inDocument:existing];
		return existing;
	}
	BOOL isDir = NO;
	if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir]) {
		NSAlert *a = [[NSAlert alloc] init];
		a.messageText = [NSString stringWithFormat:T(@"\"%@\" does not exist. Create it?", @"\"%@\" não existe. Criar?"), path.lastPathComponent];
		a.informativeText = path;
		[a addButtonWithTitle:T(@"Create", @"Criar")];
		[a addButtonWithTitle:T(@"Cancel", @"Cancelar")];
		if (_restoringSession || [a runModal] != NSAlertFirstButtonReturn) return nil;
		if (![[NSData data] writeToFile:path atomically:YES]) {
			NSBeep();
			return nil;
		}
	} else if (isDir) {
		[self setStatusMessage:T(@"Folders open in the Explorer panel.", @"Pastas são abertas no painel Explorador.")];
		return nil;
	}
	QPluginManager *pm = [QPluginManager shared];
	[pm notify:NPPN_FILEBEFOREOPEN bufferID:0];
	QDocument *d = [[QDocument alloc] init];
	NSError *err = nil;
	if (![d loadFromPath:path error:&err]) {
		[pm notify:NPPN_FILELOADFAILED bufferID:0];
		if (!_restoringSession) [self reportError:err];
		return nil;
	}
	[self addDocument:d];
	[self activateDocument:d];
	if (line > 0) [self gotoLine:line column:column inDocument:d];
	[self addRecentPath:path];
	[pm notify:NPPN_FILEOPENED bufferID:d.bufferID];
	return d;
}

- (void)activateDocument:(QDocument *)doc {
	NSInteger idx = [self indexOfDocument:doc];
	if (idx < 0) return;
	QDocument *old = self.currentDocument;
	BOOL changed = old != doc;
	_currentIndex = idx;
	if (changed || doc.editor.superview != _editorHost) {
		[old.editor removeFromSuperview];
		doc.editor.frame = _editorHost.bounds;
		[_editorHost addSubview:doc.editor];
	}
	[self refreshTabs];
	[_tabBar scrollSelectedIntoView];
	[self updateStatus];
	[self updateTitle];
	if (self.window.isVisible) [self.window makeFirstResponder:doc.editor.content];
	if (changed && !_restoringSession) [[QPluginManager shared] notify:NPPN_BUFFERACTIVATED bufferID:doc.bufferID];
	if (_findBarVisible) [_findBar clearMarks];
}

- (BOOL)closeDocument:(QDocument *)doc prompt:(BOOL)prompt {
	NSInteger idx = [self indexOfDocument:doc];
	if (idx < 0) return YES;
	if (prompt && doc.isDirty) {
		[self activateDocument:doc];
		NSAlert *a = [[NSAlert alloc] init];
		a.messageText = [NSString stringWithFormat:T(@"Save changes to \"%@\"?", @"Salvar alterações em \"%@\"?"), doc.displayName];
		a.informativeText = T(@"Your changes will be lost if you don't save them.", @"Suas alterações serão perdidas se você não salvá-las.");
		[a addButtonWithTitle:T(@"Save", @"Salvar")];
		[a addButtonWithTitle:T(@"Cancel", @"Cancelar")];
		NSButton *dont = [a addButtonWithTitle:T(@"Don't Save", @"Não salvar")];
		dont.hasDestructiveAction = YES;
		NSModalResponse r = [a runModal];
		if (r == NSAlertFirstButtonReturn) {
			if (![self saveDocument:doc forceDialog:NO]) return NO;
		} else if (r == NSAlertSecondButtonReturn) {
			return NO;
		}
	}
	QPluginManager *pm = [QPluginManager shared];
	[pm notify:NPPN_FILEBEFORECLOSE bufferID:doc.bufferID];
	if (doc.path) {
		[_closedPaths removeObject:doc.path];
		[_closedPaths addObject:doc.path];
	}
	if (doc.backupPath) [[NSFileManager defaultManager] removeItemAtPath:doc.backupPath error:nil];
	[doc.editor removeFromSuperview];
	[_docs removeObjectAtIndex:(NSUInteger)idx];
	[pm notify:NPPN_FILECLOSED bufferID:doc.bufferID];
	if (_docs.count == 0) {
		_currentIndex = -1;
		[self newDocumentWithText:nil language:nil];
		return YES;
	}
	NSInteger next = MIN(idx, (NSInteger)_docs.count - 1);
	if (idx <= _currentIndex && _currentIndex > 0 && idx != _currentIndex) _currentIndex--;
	if (idx == _currentIndex || _currentIndex >= (NSInteger)_docs.count) {
		_currentIndex = -1;
		[self activateDocument:_docs[(NSUInteger)next]];
	} else {
		[self refreshTabs];
	}
	return YES;
}

- (BOOL)prepareForQuit {
	QPluginManager *pm = [QPluginManager shared];
	[pm notify:NPPN_BEFORESHUTDOWN bufferID:0];
	BOOL backup = [QPrefs shared].backupUnsaved && [QPrefs shared].restoreSession;
	if (!backup) {
		for (QDocument *d in [_docs copy]) {
			if (!d.isDirty) continue;
			[self activateDocument:d];
			NSAlert *a = [[NSAlert alloc] init];
			a.messageText = [NSString stringWithFormat:T(@"Save changes to \"%@\" before quitting?", @"Salvar alterações em \"%@\" antes de sair?"), d.displayName];
			[a addButtonWithTitle:T(@"Save", @"Salvar")];
			[a addButtonWithTitle:T(@"Cancel", @"Cancelar")];
			[a addButtonWithTitle:T(@"Don't Save", @"Não salvar")].hasDestructiveAction = YES;
			NSModalResponse r = [a runModal];
			if (r == NSAlertFirstButtonReturn) {
				if (![self saveDocument:d forceDialog:NO]) {
					[pm notify:NPPN_CANCELSHUTDOWN bufferID:0];
					return NO;
				}
			} else if (r == NSAlertSecondButtonReturn) {
				[pm notify:NPPN_CANCELSHUTDOWN bufferID:0];
				return NO;
			}
		}
	}
	[self saveSession];
	[pm notify:NPPN_SHUTDOWN bufferID:0];
	return YES;
}

- (void)gotoLine:(NSInteger)line column:(NSInteger)column inDocument:(QDocument *)doc {
	ScintillaView *v = doc.editor;
	sptr_t l = MAX(0, line - 1);
	[v message:SCI_ENSUREVISIBLEENFORCEPOLICY wParam:(uptr_t)l];
	sptr_t pos = [v message:SCI_FINDCOLUMN wParam:(uptr_t)l lParam:MAX(0, column - 1)];
	[v message:SCI_GOTOPOS wParam:(uptr_t)pos];
	[v message:SCI_VERTICALCENTRECARET];
}

// ---- Saving ------------------------------------------------------------------------------

- (BOOL)saveDocument:(QDocument *)doc forceDialog:(BOOL)saveAs {
	NSString *path = doc.path;
	if (!path || saveAs) {
		NSSavePanel *panel = [NSSavePanel savePanel];
		panel.nameFieldStringValue = doc.path ? doc.path.lastPathComponent : [doc.displayName stringByAppendingPathExtension:@"txt"];
		if (doc.path) panel.directoryURL = [NSURL fileURLWithPath:doc.path.stringByDeletingLastPathComponent];
		panel.showsHiddenFiles = YES;
		panel.canCreateDirectories = YES;
		panel.extensionHidden = NO;
		if ([panel runModal] != NSModalResponseOK) return NO;
		path = panel.URL.path;
	}
	QPluginManager *pm = [QPluginManager shared];
	[pm notify:NPPN_FILEBEFORESAVE bufferID:doc.bufferID];
	if ([QPrefs shared].trimOnSave) {
		ScintillaView *v = doc.editor;
		sptr_t pos = [v message:SCI_GETCURRENTPOS];
		[NSApp sendAction:@selector(trimTrailingWhitespace:) to:self from:nil];
		[v message:SCI_GOTOPOS wParam:(uptr_t)MIN(pos, [v message:SCI_GETLENGTH])];
	}
	NSError *err = nil;
	BOOL wasUntitled = doc.isUntitled;
	NSString *oldPath = doc.path;
	if (![doc saveToPath:path error:&err]) {
		if (err && ![err.localizedDescription isEqualToString:T(@"Save cancelled.", @"Gravação cancelada.")]) [self reportError:err];
		return NO;
	}
	if (doc.backupPath) {
		[[NSFileManager defaultManager] removeItemAtPath:doc.backupPath error:nil];
		doc.backupPath = nil;
	}
	[self addRecentPath:path];
	[self refreshTabs];
	[self updateTitle];
	[self updateStatus];
	[pm notify:NPPN_FILESAVED bufferID:doc.bufferID];
	if (!wasUntitled && oldPath && ![oldPath isEqualToString:path]) [pm notify:NPPN_FILERENAMED bufferID:doc.bufferID];
	[self setStatusMessage:[NSString stringWithFormat:T(@"Saved %@", @"Salvo %@"), path.lastPathComponent]];
	return YES;
}

- (void)reportError:(NSError *)error {
	if (!error) return;
	NSAlert *a = [NSAlert alertWithError:error];
	[a runModal];
}

// ---- Tabs ----------------------------------------------------------------------------------

- (void)refreshTabs {
	NSMutableArray *items = [NSMutableArray array];
	for (QDocument *d in _docs) {
		QTabItem *it = [[QTabItem alloc] init];
		it.title = d.displayName;
		it.toolTip = d.path ?: d.displayName;
		it.dirty = d.isDirty;
		it.readOnly = d.readOnly;
		it.missing = d.fileMissing;
		[items addObject:it];
	}
	[_tabBar setItems:items selectedIndex:_currentIndex];
	[self updateTitle];
	[self rebuildWindowMenuDocuments];
}

- (void)rebuildWindowMenuDocuments {
	NSMenu *menu = [QMainMenu shared].windowMenu;
	for (NSMenuItem *mi in [menu.itemArray copy])
		if (mi.action == @selector(selectDocumentFromMenu:)) [menu removeItem:mi];
	NSInteger idx = 0;
	for (QDocument *d in _docs) {
		NSMenuItem *mi = [[NSMenuItem alloc] initWithTitle:d.displayName action:@selector(selectDocumentFromMenu:) keyEquivalent:@""];
		mi.tag = (NSInteger)d.bufferID;
		mi.state = idx == _currentIndex ? NSControlStateValueOn : NSControlStateValueOff;
		mi.toolTip = d.path;
		[menu addItem:mi];
		idx++;
	}
}

- (void)selectDocumentFromMenu:(NSMenuItem *)sender {
	QDocument *d = [self documentForBufferID:(NSUInteger)sender.tag];
	if (d) [self activateDocument:d];
}

- (void)updateTitle {
	QDocument *d = self.currentDocument;
	if (!d) {
		self.window.title = @"Quill";
		return;
	}
	self.window.title = d.displayName;
	self.window.subtitle = d.path ? d.path.stringByDeletingLastPathComponent.stringByAbbreviatingWithTildeInPath : @"";
	self.window.representedURL = d.path ? [NSURL fileURLWithPath:d.path] : nil;
	self.window.documentEdited = d.isDirty;
}

- (void)tabBar:(QTabBar *)bar didSelectIndex:(NSInteger)index {
	if (index >= 0 && index < (NSInteger)_docs.count) [self activateDocument:_docs[(NSUInteger)index]];
}

- (void)tabBar:(QTabBar *)bar closeIndex:(NSInteger)index {
	if (index >= 0 && index < (NSInteger)_docs.count) [self closeDocument:_docs[(NSUInteger)index] prompt:YES];
}

- (void)tabBar:(QTabBar *)bar moveIndex:(NSInteger)from toIndex:(NSInteger)to {
	if (from == to || from < 0 || to < 0 || from >= (NSInteger)_docs.count || to >= (NSInteger)_docs.count) return;
	QDocument *cur = self.currentDocument;
	QDocument *d = _docs[(NSUInteger)from];
	[_docs removeObjectAtIndex:(NSUInteger)from];
	[_docs insertObject:d atIndex:(NSUInteger)to];
	_currentIndex = [self indexOfDocument:cur];
	[self refreshTabs];
	[[QPluginManager shared] notify:NPPN_DOCORDERCHANGED bufferID:d.bufferID];
}

- (void)tabBarNewTab:(QTabBar *)bar {
	[self newDocumentWithText:nil language:nil];
}

- (NSMenu *)tabBar:(QTabBar *)bar menuForIndex:(NSInteger)index {
	if (index < 0 || index >= (NSInteger)_docs.count) return nil;
	QDocument *d = _docs[(NSUInteger)index];
	NSMenu *m = [[NSMenu alloc] init];
	NSMenuItem *close = [m addItemWithTitle:T(@"Close", @"Fechar") action:@selector(tabMenuClose:) keyEquivalent:@""];
	NSMenuItem *others = [m addItemWithTitle:T(@"Close Others", @"Fechar outras") action:@selector(tabMenuCloseOthers:) keyEquivalent:@""];
	NSMenuItem *right = [m addItemWithTitle:T(@"Close Tabs to the Right", @"Fechar abas à direita") action:@selector(tabMenuCloseRight:) keyEquivalent:@""];
	NSMenuItem *left = [m addItemWithTitle:T(@"Close Tabs to the Left", @"Fechar abas à esquerda") action:@selector(tabMenuCloseLeft:) keyEquivalent:@""];
	NSMenuItem *unchanged = [m addItemWithTitle:T(@"Close Unchanged", @"Fechar não modificadas") action:@selector(tabMenuCloseUnchanged:) keyEquivalent:@""];
	[m addItem:[NSMenuItem separatorItem]];
	NSMenuItem *save = [m addItemWithTitle:T(@"Save", @"Salvar") action:@selector(tabMenuSave:) keyEquivalent:@""];
	NSMenuItem *rename = [m addItemWithTitle:T(@"Rename…", @"Renomear…") action:@selector(tabMenuRename:) keyEquivalent:@""];
	[m addItem:[NSMenuItem separatorItem]];
	NSMenuItem *copyPath = [m addItemWithTitle:T(@"Copy Full Path", @"Copiar caminho completo") action:@selector(tabMenuCopyPath:) keyEquivalent:@""];
	NSMenuItem *copyName = [m addItemWithTitle:T(@"Copy File Name", @"Copiar nome do arquivo") action:@selector(tabMenuCopyName:) keyEquivalent:@""];
	NSMenuItem *reveal = [m addItemWithTitle:T(@"Reveal in Finder", @"Mostrar no Finder") action:@selector(tabMenuReveal:) keyEquivalent:@""];
	NSMenuItem *readOnly = [m addItemWithTitle:T(@"Read-Only", @"Somente leitura") action:@selector(tabMenuReadOnly:) keyEquivalent:@""];
	readOnly.state = d.readOnly ? NSControlStateValueOn : NSControlStateValueOff;
	for (NSMenuItem *mi in @[ close, others, right, left, unchanged, save, rename, copyPath, copyName, reveal, readOnly ]) {
		mi.target = self;
		mi.representedObject = d;
	}
	copyPath.enabled = reveal.enabled = (d.path != nil);
	return m;
}

- (void)tabMenuClose:(NSMenuItem *)s {
	[self closeDocument:s.representedObject prompt:YES];
}
- (void)tabMenuCloseOthers:(NSMenuItem *)s {
	for (QDocument *d in [_docs copy])
		if (d != s.representedObject && ![self closeDocument:d prompt:YES]) break;
}
- (void)tabMenuCloseRight:(NSMenuItem *)s {
	NSInteger idx = [self indexOfDocument:s.representedObject];
	for (QDocument *d in [[_docs subarrayWithRange:NSMakeRange((NSUInteger)idx + 1, _docs.count - (NSUInteger)idx - 1)] copy])
		if (![self closeDocument:d prompt:YES]) break;
}
- (void)tabMenuCloseLeft:(NSMenuItem *)s {
	NSInteger idx = [self indexOfDocument:s.representedObject];
	for (QDocument *d in [[_docs subarrayWithRange:NSMakeRange(0, (NSUInteger)idx)] copy])
		if (![self closeDocument:d prompt:YES]) break;
}
- (void)tabMenuCloseUnchanged:(NSMenuItem *)s {
	for (QDocument *d in [_docs copy])
		if (!d.isDirty) [self closeDocument:d prompt:NO];
}
- (void)tabMenuSave:(NSMenuItem *)s {
	[self saveDocument:s.representedObject forceDialog:NO];
}
- (void)tabMenuRename:(NSMenuItem *)s {
	[self activateDocument:s.representedObject];
	[NSApp sendAction:@selector(renameDocument:) to:self from:nil];
}
- (void)tabMenuCopyPath:(NSMenuItem *)s {
	QDocument *d = s.representedObject;
	[[NSPasteboard generalPasteboard] clearContents];
	[[NSPasteboard generalPasteboard] setString:d.path ?: d.displayName forType:NSPasteboardTypeString];
}
- (void)tabMenuCopyName:(NSMenuItem *)s {
	QDocument *d = s.representedObject;
	[[NSPasteboard generalPasteboard] clearContents];
	[[NSPasteboard generalPasteboard] setString:d.displayName forType:NSPasteboardTypeString];
}
- (void)tabMenuReveal:(NSMenuItem *)s {
	QDocument *d = s.representedObject;
	if (d.path) [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[ [NSURL fileURLWithPath:d.path] ]];
}
- (void)tabMenuReadOnly:(NSMenuItem *)s {
	QDocument *d = s.representedObject;
	d.readOnly = !d.readOnly;
	[self refreshTabs];
	[[QPluginManager shared] notify:NPPN_READONLYCHANGED from:(void *)(uintptr_t)d.bufferID idFrom:d.readOnly ? DOCSTATUS_READONLY : 0];
}

// ---- Status --------------------------------------------------------------------------------

- (void)setStatusMessage:(NSString *)message {
	[_statusBar setMessage:message];
}

- (void)updateStatus {
	QDocument *d = self.currentDocument;
	if (!d) return;
	ScintillaView *v = d.editor;
	sptr_t pos = [v message:SCI_GETCURRENTPOS];
	sptr_t line = [v message:SCI_LINEFROMPOSITION wParam:(uptr_t)pos];
	sptr_t col = [v message:SCI_GETCOLUMN wParam:(uptr_t)pos];
	sptr_t selStart = [v message:SCI_GETSELECTIONSTART];
	sptr_t selEnd = [v message:SCI_GETSELECTIONEND];
	sptr_t nsel = [v message:SCI_GETSELECTIONS];
	NSString *posText = [NSString stringWithFormat:T(@"Ln %ld, Col %ld", @"Ln %ld, Col %ld"), (long)line + 1, (long)col + 1];
	if (nsel > 1) {
		posText = [posText stringByAppendingFormat:T(@"  (%ld cursors)", @"  (%ld cursores)"), (long)nsel];
	} else if (selEnd > selStart) {
		sptr_t chars = [v message:SCI_COUNTCHARACTERS wParam:(uptr_t)selStart lParam:selEnd];
		sptr_t lines = [v message:SCI_LINEFROMPOSITION wParam:(uptr_t)selEnd] - [v message:SCI_LINEFROMPOSITION wParam:(uptr_t)selStart] + 1;
		posText = [posText stringByAppendingFormat:T(@"  Sel %ld | %ld", @"  Sel %ld | %ld"), (long)chars, (long)lines];
	}
	[_statusBar setPosition:posText];
	[_statusBar setLength:[NSString stringWithFormat:T(@"length: %ld   lines: %ld", @"tamanho: %ld   linhas: %ld"), (long)[v message:SCI_GETLENGTH],
							 (long)[v message:SCI_GETLINECOUNT]]];
	[_statusBar setEncoding:QEncodingName(d.encoding)];
	NSString *eol = d.lineEnding == QLineEndingCRLF ? @"CRLF" : (d.lineEnding == QLineEndingCR ? @"CR" : @"LF");
	[_statusBar setLineEnding:eol];
	[_statusBar setLanguage:d.language.displayName ?: @""];
	[_statusBar setOverwrite:[v message:SCI_GETOVERTYPE] != 0];
}

// ---- Recent files -------------------------------------------------------------------------------

- (void)addRecentPath:(NSString *)path {
	if (!path) return;
	[[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:[NSURL fileURLWithPath:path]];
	NSMutableArray *recent = [[[NSUserDefaults standardUserDefaults] stringArrayForKey:@"recentFiles"] mutableCopy] ?: [NSMutableArray array];
	[recent removeObject:path];
	[recent insertObject:path atIndex:0];
	while (recent.count > 20) [recent removeLastObject];
	[[NSUserDefaults standardUserDefaults] setObject:recent forKey:@"recentFiles"];
	[self refreshRecentMenu];
}

- (void)refreshRecentMenu {
	NSMenu *m = [QMainMenu shared].recentMenu;
	[m removeAllItems];
	NSArray *recent = [[NSUserDefaults standardUserDefaults] stringArrayForKey:@"recentFiles"] ?: @[];
	for (NSString *p in recent) {
		NSMenuItem *mi = [m addItemWithTitle:p.lastPathComponent action:@selector(openRecent:) keyEquivalent:@""];
		mi.target = self;
		mi.representedObject = p;
		mi.toolTip = p;
		NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:p];
		icon.size = NSMakeSize(16, 16);
		mi.image = icon;
	}
	if (recent.count) {
		[m addItem:[NSMenuItem separatorItem]];
		NSMenuItem *clear = [m addItemWithTitle:T(@"Clear Menu", @"Limpar menu") action:@selector(clearRecent:) keyEquivalent:@""];
		clear.target = self;
	} else {
		[m addItemWithTitle:T(@"No Recent Files", @"Nenhum arquivo recente") action:nil keyEquivalent:@""].enabled = NO;
	}
}

- (void)openRecent:(NSMenuItem *)sender {
	[self openPath:sender.representedObject];
}

- (void)clearRecent:(id)sender {
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"recentFiles"];
	[[NSDocumentController sharedDocumentController] clearRecentDocuments:nil];
	[self refreshRecentMenu];
}

// ---- Plugins / menus ------------------------------------------------------------------------------

- (void)rebuildPluginMenu {
	[[QPluginManager shared] populateMenu:[QMainMenu shared].pluginsMenu];
	[self rebuildPanelsMenu];
}

- (void)pluginManagerDidChangeMenus {
	[self rebuildPluginMenu];
}

- (ScintillaView *)currentEditor {
	return self.currentDocument.editor;
}

- (NSMenu *)contextMenuForEditor:(QEditorView *)view event:(NSEvent *)event {
	NSMenu *m = [[NSMenu alloc] init];
	[m addItemWithTitle:T(@"Undo", @"Desfazer") action:@selector(undo:) keyEquivalent:@""];
	[m addItemWithTitle:T(@"Redo", @"Refazer") action:@selector(redo:) keyEquivalent:@""];
	[m addItem:[NSMenuItem separatorItem]];
	[m addItemWithTitle:T(@"Cut", @"Recortar") action:@selector(cut:) keyEquivalent:@""];
	[m addItemWithTitle:T(@"Copy", @"Copiar") action:@selector(copy:) keyEquivalent:@""];
	[m addItemWithTitle:T(@"Paste", @"Colar") action:@selector(paste:) keyEquivalent:@""];
	[m addItemWithTitle:T(@"Delete", @"Apagar") action:@selector(clear:) keyEquivalent:@""];
	[m addItem:[NSMenuItem separatorItem]];
	[m addItemWithTitle:T(@"Select All", @"Selecionar tudo") action:@selector(selectAll:) keyEquivalent:@""];
	[m addItem:[NSMenuItem separatorItem]];
	[m addItemWithTitle:T(@"Toggle Comment", @"Alternar comentário") action:@selector(toggleComment:) keyEquivalent:@""];
	NSMenuItem *upper = [m addItemWithTitle:T(@"UPPERCASE", @"MAIÚSCULAS") action:@selector(makeUppercase:) keyEquivalent:@""];
	NSMenuItem *lower = [m addItemWithTitle:T(@"lowercase", @"minúsculas") action:@selector(makeLowercase:) keyEquivalent:@""];
	(void)upper;
	(void)lower;
	if (_contextMenuHandlers.count) {
		NSPoint p = [view.content convertPoint:event.locationInWindow fromView:nil];
		sptr_t pos = [view message:SCI_POSITIONFROMPOINT wParam:(uptr_t)p.x lParam:(sptr_t)p.y];
		if (pos < 0) pos = [view message:SCI_GETCURRENTPOS];
		for (NSValue *v in _contextMenuHandlers) {
			QuillContextMenuHandler h = (QuillContextMenuHandler)v.pointerValue;
			if (h) h((__bridge void *)m, (intptr_t)pos);
		}
	}
	return m;
}

// ---- Panels ------------------------------------------------------------------------------------------

- (QPanelArea *)areaFor:(QPanelPosition)pos {
	switch (pos) {
	case QPanelLeft: return _leftArea;
	case QPanelRight: return _rightArea;
	default: return _bottomArea;
	}
}

- (QPanelRecord *)panelRecordFor:(NSView *)view {
	for (QPanelRecord *r in _panels)
		if (r.view == view) return r;
	return nil;
}

- (void)registerPanel:(NSView *)view title:(NSString *)title position:(QPanelPosition)position {
	if (!view || [self panelRecordFor:view]) return;
	QPanelRecord *r = [[QPanelRecord alloc] init];
	r.view = view;
	r.title = title;
	r.area = [self areaFor:position];
	r.dlgID = -1;
	[r.area addPanel:view title:title];
	[_panels addObject:r];
	[self rebuildPanelsMenu];
}

- (void)showPanel:(NSView *)view {
	QPanelRecord *r = [self panelRecordFor:view];
	if (!r) return;
	[r.area showPanel:view];
	[self rebuildPanelsMenu];
}

- (void)hidePanel:(NSView *)view {
	QPanelRecord *r = [self panelRecordFor:view];
	if (!r) return;
	[r.area hidePanel:view];
	[self rebuildPanelsMenu];
}

- (BOOL)isPanelVisible:(NSView *)view {
	QPanelRecord *r = [self panelRecordFor:view];
	return r && [r.area isPanelOpen:view] && !r.area.hidden;
}

- (void)setPanelTitle:(NSString *)title forView:(NSView *)view {
	QPanelRecord *r = [self panelRecordFor:view];
	if (!r) return;
	r.title = title;
	[r.area setTitle:title forPanel:view];
	[self rebuildPanelsMenu];
}

- (void)panelClosedByUser:(NSView *)panel {
	QPanelRecord *r = [self panelRecordFor:panel];
	[self rebuildPanelsMenu];
	if (r.fromPlugin) [[QPluginManager shared] notify:QUILLN_PANELCLOSED from:(__bridge void *)panel idFrom:(uintptr_t)r.dlgID];
}

- (void)rebuildPanelsMenu {
	NSMenu *m = [QMainMenu shared].panelsMenu;
	[m removeAllItems];
	for (QPanelRecord *r in _panels) {
		NSMenuItem *mi = [m addItemWithTitle:r.title ?: @"" action:@selector(togglePanelFromMenu:) keyEquivalent:@""];
		mi.target = self;
		mi.representedObject = r;
		mi.state = [self isPanelVisible:r.view] ? NSControlStateValueOn : NSControlStateValueOff;
	}
	if (_panels.count == 0) [m addItemWithTitle:T(@"No panels", @"Nenhum painel") action:nil keyEquivalent:@""].enabled = NO;
}

- (void)togglePanelFromMenu:(NSMenuItem *)sender {
	QPanelRecord *r = sender.representedObject;
	if ([self isPanelVisible:r.view]) {
		[self hidePanel:r.view];
		if (r.fromPlugin) [[QPluginManager shared] notify:QUILLN_PANELCLOSED from:(__bridge void *)r.view idFrom:(uintptr_t)r.dlgID];
	} else if (r.fromPlugin && r.dlgID >= 0) {
		// Let the plugin run its own toggle command so its state stays in sync.
		[self showPanel:r.view];
	} else {
		[self showPanel:r.view];
	}
}

- (void)areaVisibilityChanged:(QPanelArea *)area {
	BOOL show = area.hasOpenPanels;
	if (area.hidden == !show) return;
	area.hidden = !show;
	if (area == _bottomArea) {
		[_vSplit adjustSubviews];
		if (show) {
			CGFloat h = _vSplit.bounds.size.height;
			[_vSplit setPosition:MAX(120, h - 220) ofDividerAtIndex:0];
		}
	} else {
		[_hSplit adjustSubviews];
		if (show) {
			CGFloat w = _hSplit.bounds.size.width;
			if (area == _leftArea) [_hSplit setPosition:250 ofDividerAtIndex:0];
			else [_hSplit setPosition:w - 340 ofDividerAtIndex:1];
		}
	}
	[self.window.contentView setNeedsLayout:YES];
}

- (CGFloat)splitView:(NSSplitView *)sv constrainMinCoordinate:(CGFloat)proposed ofSubviewAt:(NSInteger)i {
	return proposed + 120;
}

- (CGFloat)splitView:(NSSplitView *)sv constrainMaxCoordinate:(CGFloat)proposed ofSubviewAt:(NSInteger)i {
	return proposed - 120;
}

- (BOOL)splitView:(NSSplitView *)sv canCollapseSubview:(NSView *)subview {
	return NO;
}

// ---- Find bar delegate ---------------------------------------------------------------------------------

- (ScintillaView *)findBarEditor:(QFindBar *)bar {
	return self.currentDocument.editor;
}

- (void)findBarDidClose:(QFindBar *)bar {
	[self hideFindBar];
}

- (void)findBar:(QFindBar *)bar status:(NSString *)message {
	[self setStatusMessage:message];
}

- (void)showFindBarReplace:(BOOL)replace {
	_findBarVisible = YES;
	_findBar.hidden = NO;
	[_findBar activateWithReplace:replace];
	_editorArea.needsLayout = YES;
	[_editorArea layoutSubtreeIfNeeded];
}

- (void)hideFindBar {
	_findBarVisible = NO;
	_findBar.hidden = YES;
	_editorArea.needsLayout = YES;
	QDocument *d = self.currentDocument;
	if (d) [self.window makeFirstResponder:d.editor.content];
}

// ---- Editor notifications ---------------------------------------------------------------------------------

- (void)document:(QDocument *)doc notification:(SCNotification *)n {
	BOOL isCurrent = doc == self.currentDocument;
	switch (n->nmhdr.code) {
	case SCN_SAVEPOINTREACHED:
	case SCN_SAVEPOINTLEFT:
		[self refreshTabs];
		break;
	case SCN_UPDATEUI:
		if (isCurrent) {
			[self updateStatus];
			if (n->updated & (SC_UPDATE_SELECTION | SC_UPDATE_CONTENT)) {
				[self highlightBraces:doc];
				[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(smartHighlight) object:nil];
				[self performSelector:@selector(smartHighlight) withObject:nil afterDelay:0.25];
			}
		}
		break;
	case SCN_MODIFIED:
		if (n->linesAdded != 0) [QEditorStyler updateLineNumberMargin:doc.editor];
		break;
	case SCN_CHARADDED:
		[self handleCharAdded:n->ch inDocument:doc];
		break;
	case SCN_MARGINCLICK:
		if (n->margin == 1) {
			sptr_t line = [doc.editor message:SCI_LINEFROMPOSITION wParam:(uptr_t)n->position];
			[self toggleBookmarkAtLine:line inDocument:doc];
		}
		break;
	case SCN_ZOOM:
		[QEditorStyler updateLineNumberMargin:doc.editor];
		break;
	default:
		break;
	}
	if (isCurrent) [[QPluginManager shared] forwardScintillaNotification:n];
}

- (void)toggleBookmarkAtLine:(sptr_t)line inDocument:(QDocument *)doc {
	ScintillaView *v = doc.editor;
	int mask = (int)[v message:SCI_MARKERGET wParam:(uptr_t)line];
	if (mask & (1 << QMarkerBookmark))
		[v message:SCI_MARKERDELETE wParam:(uptr_t)line lParam:QMarkerBookmark];
	else
		[v message:SCI_MARKERADD wParam:(uptr_t)line lParam:QMarkerBookmark];
}

- (void)highlightBraces:(QDocument *)doc {
	ScintillaView *v = doc.editor;
	sptr_t pos = [v message:SCI_GETCURRENTPOS];
	auto isBrace = [](int c) { return c == '(' || c == ')' || c == '[' || c == ']' || c == '{' || c == '}'; };
	sptr_t bracePos = -1;
	if (pos > 0 && isBrace((int)[v message:SCI_GETCHARAT wParam:(uptr_t)pos - 1])) bracePos = pos - 1;
	else if (isBrace((int)[v message:SCI_GETCHARAT wParam:(uptr_t)pos])) bracePos = pos;
	if (bracePos < 0) {
		[v message:SCI_BRACEHIGHLIGHT wParam:(uptr_t)INVALID_POSITION lParam:INVALID_POSITION];
		return;
	}
	sptr_t match = [v message:SCI_BRACEMATCH wParam:(uptr_t)bracePos lParam:0];
	if (match < 0) [v message:SCI_BRACEBADLIGHT wParam:(uptr_t)bracePos];
	else [v message:SCI_BRACEHIGHLIGHT wParam:(uptr_t)bracePos lParam:match];
}

- (void)smartHighlight {
	QDocument *doc = self.currentDocument;
	if (!doc) return;
	ScintillaView *v = doc.editor;
	sptr_t len = [v message:SCI_GETLENGTH];
	[v message:SCI_SETINDICATORCURRENT wParam:QIndicatorSmartHighlight];
	[v message:SCI_INDICATORCLEARRANGE wParam:0 lParam:len];
	if (![QPrefs shared].highlightMatchingWords || len > 4 * 1024 * 1024) return;
	sptr_t selStart = [v message:SCI_GETSELECTIONSTART];
	sptr_t selEnd = [v message:SCI_GETSELECTIONEND];
	if (selEnd <= selStart || selEnd - selStart > 200 || [v message:SCI_GETSELECTIONS] > 1) return;
	// Only whole words.
	sptr_t ws = [v message:SCI_WORDSTARTPOSITION wParam:(uptr_t)selStart lParam:1];
	sptr_t we = [v message:SCI_WORDENDPOSITION wParam:(uptr_t)selStart lParam:1];
	if (ws != selStart || we != selEnd) return;
	std::string word(static_cast<size_t>(selEnd - selStart) + 1, '\0');
	Sci_TextRangeFull tr;
	tr.chrg.cpMin = selStart;
	tr.chrg.cpMax = selEnd;
	tr.lpstrText = word.data();
	[v message:SCI_GETTEXTRANGEFULL wParam:0 lParam:(sptr_t)&tr];
	word.resize(static_cast<size_t>(selEnd - selStart));
	sptr_t savedStart = [v message:SCI_GETTARGETSTART];
	sptr_t savedEnd = [v message:SCI_GETTARGETEND];
	[v message:SCI_SETSEARCHFLAGS wParam:SCFIND_MATCHCASE | SCFIND_WHOLEWORD];
	sptr_t pos = 0;
	int count = 0;
	while (pos < len && count < 5000) {
		[v message:SCI_SETTARGETRANGE wParam:(uptr_t)pos lParam:len];
		sptr_t found = [v message:SCI_SEARCHINTARGET wParam:word.size() lParam:(sptr_t)word.c_str()];
		if (found < 0) break;
		sptr_t end = [v message:SCI_GETTARGETEND];
		if (found != selStart) {
			[v message:SCI_SETINDICATORCURRENT wParam:QIndicatorSmartHighlight];
			[v message:SCI_INDICATORFILLRANGE wParam:(uptr_t)found lParam:end - found];
		}
		pos = end > found ? end : found + 1;
		count++;
	}
	[v message:SCI_SETTARGETRANGE wParam:(uptr_t)savedStart lParam:savedEnd];
}

- (void)handleCharAdded:(int)ch inDocument:(QDocument *)doc {
	ScintillaView *v = doc.editor;
	QPrefs *prefs = [QPrefs shared];
	if ((ch == '\n' || ch == '\r') && prefs.autoIndent) {
		int eolMode = (int)[v message:SCI_GETEOLMODE];
		if (ch == '\r' && eolMode == SC_EOL_CRLF) return; // wait for the \n
		sptr_t pos = [v message:SCI_GETCURRENTPOS];
		sptr_t line = [v message:SCI_LINEFROMPOSITION wParam:(uptr_t)pos];
		if (line <= 0) return;
		sptr_t prevIndent = [v message:SCI_GETLINEINDENTATION wParam:(uptr_t)line - 1];
		// Extra indent after an opening brace or a Python colon.
		sptr_t prevEnd = [v message:SCI_GETLINEENDPOSITION wParam:(uptr_t)line - 1];
		sptr_t prevStart = [v message:SCI_POSITIONFROMLINE wParam:(uptr_t)line - 1];
		int last = 0;
		for (sptr_t p = prevEnd - 1; p >= prevStart; p--) {
			int c = (int)[v message:SCI_GETCHARAT wParam:(uptr_t)p];
			if (c != ' ' && c != '\t') {
				last = c;
				break;
			}
		}
		sptr_t indent = prevIndent;
		sptr_t width = [v message:SCI_GETINDENT] ?: [v message:SCI_GETTABWIDTH];
		if (last == '{' || last == '[' || last == '(' || (last == ':' && [doc.language.name isEqualToString:@"python"])) indent += width;
		if (indent > 0) {
			[v message:SCI_SETLINEINDENTATION wParam:(uptr_t)line lParam:indent];
			[v message:SCI_GOTOPOS wParam:(uptr_t)[v message:SCI_GETLINEINDENTPOSITION wParam:(uptr_t)line]];
		}
		// Closing brace right after the caret goes to its own line.
		int next = (int)[v message:SCI_GETCHARAT wParam:(uptr_t)[v message:SCI_GETCURRENTPOS]];
		if ((last == '{' && next == '}') || (last == '[' && next == ']') || (last == '(' && next == ')')) {
			sptr_t caret = [v message:SCI_GETCURRENTPOS];
			[v message:SCI_NEWLINE];
			sptr_t newLine = [v message:SCI_LINEFROMPOSITION wParam:(uptr_t)[v message:SCI_GETCURRENTPOS]];
			[v message:SCI_SETLINEINDENTATION wParam:(uptr_t)newLine lParam:prevIndent];
			[v message:SCI_GOTOPOS wParam:(uptr_t)caret];
		}
		return;
	}
	if (ch == '}' && prefs.autoIndent) {
		sptr_t pos = [v message:SCI_GETCURRENTPOS];
		sptr_t line = [v message:SCI_LINEFROMPOSITION wParam:(uptr_t)pos];
		sptr_t indentPos = [v message:SCI_GETLINEINDENTPOSITION wParam:(uptr_t)line];
		if (indentPos == pos - 1) {
			sptr_t match = [v message:SCI_BRACEMATCH wParam:(uptr_t)pos - 1 lParam:0];
			if (match >= 0) {
				sptr_t matchLine = [v message:SCI_LINEFROMPOSITION wParam:(uptr_t)match];
				[v message:SCI_SETLINEINDENTATION wParam:(uptr_t)line lParam:[v message:SCI_GETLINEINDENTATION wParam:(uptr_t)matchLine]];
			}
		}
	}
	if (prefs.autoCloseBrackets && [v message:SCI_GETSELECTIONS] == 1) {
		const char *closer = nullptr;
		switch (ch) {
		case '(': closer = ")"; break;
		case '[': closer = "]"; break;
		case '{': closer = "}"; break;
		case '"': closer = "\""; break;
		case '\'': closer = "'"; break;
		case '`': closer = "`"; break;
		default: break;
		}
		sptr_t pos = [v message:SCI_GETCURRENTPOS];
		int next = (int)[v message:SCI_GETCHARAT wParam:(uptr_t)pos];
		if ((ch == ')' || ch == ']' || ch == '}' || ch == '"' || ch == '\'' || ch == '`') && next == ch) {
			// Typed over an auto-inserted closer.
			[v message:SCI_DELETERANGE wParam:(uptr_t)pos lParam:1];
		} else if (closer) {
			BOOL nextIsWord = isalnum(next) || next == '_';
			int prev = pos >= 2 ? (int)[v message:SCI_GETCHARAT wParam:(uptr_t)pos - 2] : 0;
			BOOL quote = ch == '"' || ch == '\'' || ch == '`';
			if (!nextIsWord && !(quote && (isalnum(prev) || prev == '_'))) [v message:SCI_INSERTTEXT wParam:(uptr_t)pos lParam:(sptr_t)closer];
		}
	}
	if (prefs.autoCompleteWords && (isalnum(ch) || ch == '_') && ![v message:SCI_AUTOCACTIVE]) {
		sptr_t pos = [v message:SCI_GETCURRENTPOS];
		sptr_t start = [v message:SCI_WORDSTARTPOSITION wParam:(uptr_t)pos lParam:1];
		if (pos - start >= 3) [self showWordCompletion:doc force:NO];
	}
}

- (void)showWordCompletion:(QDocument *)doc force:(BOOL)force {
	ScintillaView *v = doc.editor;
	sptr_t pos = [v message:SCI_GETCURRENTPOS];
	sptr_t start = [v message:SCI_WORDSTARTPOSITION wParam:(uptr_t)pos lParam:1];
	if (pos - start < (force ? 1 : 3)) return;
	sptr_t len = [v message:SCI_GETLENGTH];
	if (len > 8 * 1024 * 1024) return;
	std::string prefix(static_cast<size_t>(pos - start) + 1, '\0');
	Sci_TextRangeFull tr;
	tr.chrg.cpMin = start;
	tr.chrg.cpMax = pos;
	tr.lpstrText = prefix.data();
	[v message:SCI_GETTEXTRANGEFULL wParam:0 lParam:(sptr_t)&tr];
	prefix.resize(static_cast<size_t>(pos - start));
	NSString *prefixStr = [NSString stringWithUTF8String:prefix.c_str()];
	if (!prefixStr) return;
	NSMutableSet<NSString *> *words = [NSMutableSet set];
	std::string text = [doc utf8Text];
	NSString *all = [[NSString alloc] initWithBytesNoCopy:(void *)text.data() length:text.size() encoding:NSUTF8StringEncoding freeWhenDone:NO];
	static NSRegularExpression *wordRe = [NSRegularExpression regularExpressionWithPattern:@"[\\p{L}\\p{N}_]{3,}" options:0 error:nil];
	NSString *lowerPrefix = prefixStr.lowercaseString;
	__block NSUInteger scanned = 0;
	[wordRe enumerateMatchesInString:all
				 options:0
				   range:NSMakeRange(0, all.length)
			      usingBlock:^(NSTextCheckingResult *r, NSMatchingFlags flags, BOOL *stop) {
				      NSString *w = [all substringWithRange:r.range];
				      if (w.length > prefixStr.length && [w.lowercaseString hasPrefix:lowerPrefix]) [words addObject:w];
				      if (++scanned > 400000) *stop = YES;
			      }];
	for (NSString *kw in doc.language.keywords.allValues)
		for (NSString *w in [kw componentsSeparatedByString:@" "])
			if (w.length > prefixStr.length && [w.lowercaseString hasPrefix:lowerPrefix]) [words addObject:w];
	if (words.count == 0) return;
	NSArray *sorted = [words.allObjects sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
	if (sorted.count > 200) sorted = [sorted subarrayWithRange:NSMakeRange(0, 200)];
	NSString *list = [sorted componentsJoinedByString:@"\n"];
	[v message:SCI_AUTOCSETSEPARATOR wParam:'\n'];
	[v message:SCI_AUTOCSHOW wParam:(uptr_t)(pos - start) lParam:(sptr_t)list.UTF8String];
}

// ---- External changes ------------------------------------------------------------------------------------

- (void)appDidBecomeActive:(NSNotification *)note {
	[self checkExternalChanges];
}

- (void)checkExternalChanges {
	for (QDocument *d in [_docs copy]) {
		if (!d.path) continue;
		BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:d.path];
		if (!exists) {
			if (!d.fileMissing) {
				d.fileMissing = YES;
				[self setStatusMessage:[NSString stringWithFormat:T(@"\"%@\" was deleted or moved on disk.", @"\"%@\" foi apagado ou movido no disco."), d.displayName]];
			}
			continue;
		}
		if (d.fileMissing) d.fileMissing = NO;
		if (![d changedOnDisk]) continue;
		if (!d.isDirty) {
			sptr_t pos = [d.editor message:SCI_GETCURRENTPOS];
			sptr_t first = [d.editor message:SCI_GETFIRSTVISIBLELINE];
			[d reloadWithEncoding:d.encoding error:nil];
			[d.editor message:SCI_GOTOPOS wParam:(uptr_t)MIN(pos, [d.editor message:SCI_GETLENGTH])];
			[d.editor message:SCI_SETFIRSTVISIBLELINE wParam:(uptr_t)first];
			[self setStatusMessage:[NSString stringWithFormat:T(@"\"%@\" was reloaded (changed on disk).", @"\"%@\" foi recarregado (alterado no disco)."), d.displayName]];
		} else {
			[self activateDocument:d];
			NSAlert *a = [[NSAlert alloc] init];
			a.messageText = [NSString stringWithFormat:T(@"\"%@\" was changed by another program.", @"\"%@\" foi alterado por outro programa."), d.displayName];
			a.informativeText = T(@"Reload it and lose your unsaved changes?", @"Recarregar e perder suas alterações não salvas?");
			[a addButtonWithTitle:T(@"Keep My Version", @"Manter minha versão")];
			[a addButtonWithTitle:T(@"Reload", @"Recarregar")];
			if ([a runModal] == NSAlertSecondButtonReturn) [d reloadWithEncoding:d.encoding error:nil];
			else d.fileModificationDate = [[NSFileManager defaultManager] attributesOfItemAtPath:d.path error:nil].fileModificationDate;
		}
		[[QPluginManager shared] notify:NPPN_BUFFERACTIVATED bufferID:self.currentDocument.bufferID];
	}
	[self refreshTabs];
}

// ---- Window delegate ---------------------------------------------------------------------------------------

- (BOOL)windowShouldClose:(NSWindow *)sender {
	[NSApp terminate:nil];
	return NO;
}

// ---- Toolbar -------------------------------------------------------------------------------------------------

- (NSArray<NSToolbarItemIdentifier> *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
	NSMutableArray *ids = [@[
		kToolbarNew, kToolbarOpen, kToolbarSave, kToolbarSaveAll, NSToolbarSpaceItemIdentifier, kToolbarUndo, kToolbarRedo,
		NSToolbarSpaceItemIdentifier, kToolbarFind, kToolbarReplace, NSToolbarSpaceItemIdentifier, kToolbarZoomOut, kToolbarZoomIn,
		kToolbarWrap, kToolbarWhitespace, NSToolbarFlexibleSpaceItemIdentifier
	] mutableCopy];
	for (NSDictionary *b in _pluginToolbarButtons) [ids addObject:b[@"id"]];
	return ids;
}

- (NSArray<NSToolbarItemIdentifier> *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
	NSMutableArray *ids = [@[
		kToolbarNew, kToolbarOpen, kToolbarSave, kToolbarSaveAll, kToolbarUndo, kToolbarRedo, kToolbarFind, kToolbarReplace,
		kToolbarZoomOut, kToolbarZoomIn, kToolbarWrap, kToolbarWhitespace, NSToolbarSpaceItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier
	] mutableCopy];
	for (NSDictionary *b in _pluginToolbarButtons) [ids addObject:b[@"id"]];
	return ids;
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSToolbarItemIdentifier)ident willBeInsertedIntoToolbar:(BOOL)flag {
	NSDictionary *defs = @{
		kToolbarNew : @[ @"doc.badge.plus", T(@"New", @"Novo"), NSStringFromSelector(@selector(newDocument:)) ],
		kToolbarOpen : @[ @"folder", T(@"Open", @"Abrir"), NSStringFromSelector(@selector(openDocument:)) ],
		kToolbarSave : @[ @"square.and.arrow.down", T(@"Save", @"Salvar"), NSStringFromSelector(@selector(saveDocument:)) ],
		kToolbarSaveAll : @[ @"square.and.arrow.down.on.square", T(@"Save All", @"Salvar tudo"), NSStringFromSelector(@selector(saveAllDocuments:)) ],
		kToolbarUndo : @[ @"arrow.uturn.backward", T(@"Undo", @"Desfazer"), NSStringFromSelector(@selector(undo:)) ],
		kToolbarRedo : @[ @"arrow.uturn.forward", T(@"Redo", @"Refazer"), NSStringFromSelector(@selector(redo:)) ],
		kToolbarFind : @[ @"magnifyingglass", T(@"Find", @"Localizar"), NSStringFromSelector(@selector(showFind:)) ],
		kToolbarReplace : @[ @"arrow.left.arrow.right", T(@"Replace", @"Substituir"), NSStringFromSelector(@selector(showReplace:)) ],
		kToolbarZoomIn : @[ @"plus.magnifyingglass", T(@"Zoom In", @"Ampliar"), NSStringFromSelector(@selector(zoomIn:)) ],
		kToolbarZoomOut : @[ @"minus.magnifyingglass", T(@"Zoom Out", @"Reduzir"), NSStringFromSelector(@selector(zoomOut:)) ],
		kToolbarWrap : @[ @"text.word.spacing", T(@"Word Wrap", @"Quebra de linha"), NSStringFromSelector(@selector(toggleWordWrap:)) ],
		kToolbarWhitespace : @[ @"paragraphsign", T(@"Show Whitespace", @"Mostrar espaços"), NSStringFromSelector(@selector(toggleWhitespace:)) ],
	};
	NSArray *def = defs[ident];
	NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:ident];
	if (def) {
		item.image = [NSImage imageWithSystemSymbolName:def[0] accessibilityDescription:def[1]];
		item.label = def[1];
		item.paletteLabel = def[1];
		item.toolTip = def[1];
		item.action = NSSelectorFromString(def[2]);
		item.target = nil;
		item.bordered = YES;
		return item;
	}
	for (NSDictionary *b in _pluginToolbarButtons) {
		if ([b[@"id"] isEqualToString:ident]) {
			item.image = [NSImage imageWithSystemSymbolName:b[@"symbol"] accessibilityDescription:b[@"title"]] ?:
				[NSImage imageWithSystemSymbolName:@"puzzlepiece.extension" accessibilityDescription:b[@"title"]];
			item.label = b[@"title"];
			item.paletteLabel = b[@"title"];
			item.toolTip = b[@"title"];
			item.tag = [b[@"cmd"] integerValue];
			item.target = self;
			item.action = @selector(pluginToolbarAction:);
			item.bordered = YES;
			return item;
		}
	}
	return nil;
}

- (void)pluginToolbarAction:(NSToolbarItem *)sender {
	[[QPluginManager shared] runCommandID:(int)sender.tag];
}

- (void)addPluginToolbarButtonForCommand:(int)cmdID symbol:(NSString *)symbol {
	NSString *ident = [NSString stringWithFormat:@"%@%d", kToolbarPluginPrefix, cmdID];
	for (NSDictionary *b in _pluginToolbarButtons)
		if ([b[@"id"] isEqualToString:ident]) return;
	NSString *title = [[QPluginManager shared] titleForCommandID:cmdID] ?: @"Plugin";
	[_pluginToolbarButtons addObject:@{@"id" : ident, @"symbol" : symbol ?: @"puzzlepiece.extension", @"title" : title, @"cmd" : @(cmdID)}];
	NSToolbar *tb = self.window.toolbar;
	BOOL present = NO;
	for (NSToolbarItem *it in tb.items)
		if ([it.itemIdentifier isEqualToString:ident]) present = YES;
	if (!present) [tb insertItemWithItemIdentifier:ident atIndex:(NSInteger)tb.items.count];
}

// ---- Snapshot (self test) ---------------------------------------------------------------------------------

- (BOOL)writeSnapshotToPath:(NSString *)path {
	NSView *view = self.window.contentView.superview ?: self.window.contentView;
	[view layoutSubtreeIfNeeded];
	[view displayIfNeeded];
	NSBitmapImageRep *rep = [view bitmapImageRepForCachingDisplayInRect:view.bounds];
	if (!rep) return NO;
	[view cacheDisplayInRect:view.bounds toBitmapImageRep:rep];
	NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
	return [png writeToFile:path atomically:YES];
}

@end
