// Internal state shared by the MainWindowController implementation files.
// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#import "MainWindowController.h"
#import "FindBar.h"
#import "FindInFiles.h"
#import "PanelArea.h"
#import "PluginManager.h"
#import "StatusBar.h"
#import "TabBar.h"

#include "Scintilla.h"

@interface QPanelRecord : NSObject
@property (nonatomic, strong) NSView *view;
@property (nonatomic, weak) QPanelArea *area;
@property (nonatomic, copy) NSString *title;
@property (nonatomic) int dlgID;
@property (nonatomic, copy) NSString *moduleName;
@property (nonatomic) BOOL fromPlugin;
@end

@interface QMainWindowController () <QTabBarDelegate, QFindBarDelegate, QDocumentNotificationTarget, QPluginHost,
				     NSWindowDelegate, NSToolbarDelegate, NSSplitViewDelegate, NSMenuItemValidation,
				     NSToolbarItemValidation>
@property (nonatomic, strong) NSMutableArray<QDocument *> *docs;
@property (nonatomic) NSInteger currentIndex;
@property (nonatomic, strong) QTabBar *tabBar;
@property (nonatomic, strong) QFindBar *findBar;
@property (nonatomic) BOOL findBarVisible;
@property (nonatomic, strong) NSView *editorArea;
@property (nonatomic, strong) NSView *editorHost;
@property (nonatomic, strong) QStatusBar *statusBar;
@property (nonatomic, strong) NSView *mainArea;
@property (nonatomic, strong) NSSplitView *hSplit;
@property (nonatomic, strong) NSSplitView *vSplit;
@property (nonatomic, strong) QPanelArea *leftArea;
@property (nonatomic, strong) QPanelArea *rightArea;
@property (nonatomic, strong) QPanelArea *bottomArea;
@property (nonatomic, strong) QFindInFilesController *findInFiles;
@property (nonatomic, strong) NSMutableArray<NSString *> *closedPaths;
@property (nonatomic, strong) NSMutableArray<QPanelRecord *> *panels;
@property (nonatomic, strong) NSMutableArray<NSValue *> *contextMenuHandlers;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *pluginToolbarButtons;
@property (nonatomic) NSInteger untitledCounter;
@property (nonatomic) BOOL restoringSession;
@property (nonatomic) BOOL lastDark;

- (void)refreshTabs;
- (void)updateStatus;
- (void)updateTitle;
- (void)reportError:(NSError *)error;
- (BOOL)saveDocument:(QDocument *)doc forceDialog:(BOOL)saveAs;
- (void)restyleAllDocuments;
- (QPanelRecord *)panelRecordFor:(NSView *)view;
- (void)showFindBarReplace:(BOOL)replace;
- (void)hideFindBar;
- (void)addRecentPath:(NSString *)path;
- (void)gotoLine:(NSInteger)line column:(NSInteger)column inDocument:(QDocument *)doc;
- (NSInteger)indexOfDocument:(QDocument *)doc;
- (void)applyTheme;
- (void)showWordCompletion:(QDocument *)doc force:(BOOL)force;
- (void)selectDocumentFromMenu:(NSMenuItem *)sender;
- (void)openFolderInExplorer:(NSString *)path;
- (void)addPluginToolbarButtonForCommand:(int)cmdID symbol:(NSString *)symbol;
- (void)rebuildPanelsMenu;
@end
