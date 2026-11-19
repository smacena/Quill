// The single main window: tabs, editor, panels, status bar.
// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#import <Cocoa/Cocoa.h>
#import "Document.h"

@class QLanguage;

typedef NS_ENUM(NSInteger, QPanelPosition) {
	QPanelLeft = 0,
	QPanelRight = 1,
	QPanelTop = 2,
	QPanelBottom = 3,
};

@interface QMainWindowController : NSWindowController
+ (instancetype)shared;

@property (nonatomic, readonly) QDocument *currentDocument;
@property (nonatomic, readonly) NSArray<QDocument *> *documents;

- (void)finishLaunchingWithFiles:(NSArray<NSString *> *)files;
- (QDocument *)openPath:(NSString *)path;
- (QDocument *)openPath:(NSString *)path line:(NSInteger)line column:(NSInteger)column;
- (QDocument *)newDocumentWithText:(NSString *)text language:(QLanguage *)language;
- (QDocument *)documentForBufferID:(NSUInteger)bufferID;
- (QDocument *)documentForPath:(NSString *)path;
- (void)activateDocument:(QDocument *)doc;
- (BOOL)closeDocument:(QDocument *)doc prompt:(BOOL)prompt;

// Quit support: asks to save dirty documents (unless they are backed up).
- (BOOL)prepareForQuit;
- (void)saveSession;

- (void)setStatusMessage:(NSString *)message;
- (void)rebuildPluginMenu;
- (void)refreshRecentMenu;

// Panels
- (void)registerPanel:(NSView *)view title:(NSString *)title position:(QPanelPosition)position;
- (void)showPanel:(NSView *)view;
- (void)hidePanel:(NSView *)view;
- (BOOL)isPanelVisible:(NSView *)view;
- (void)setPanelTitle:(NSString *)title forView:(NSView *)view;

// Captures the window contents to a PNG (used by the self test).
- (BOOL)writeSnapshotToPath:(NSString *)path;
@end
