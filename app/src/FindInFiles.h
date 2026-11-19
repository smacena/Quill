// Find / Replace in Files dialog and its results panel.
// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#import <Cocoa/Cocoa.h>

@interface QSearchHit : NSObject
@property (nonatomic, copy) NSString *path;
@property (nonatomic) NSInteger line;       // 1-based
@property (nonatomic) NSInteger column;     // 0-based UTF-16 column of the first match
@property (nonatomic) NSInteger matchLength;
@property (nonatomic, copy) NSString *text; // the line (trimmed)
@property (nonatomic, copy) NSArray<NSValue *> *ranges; // match ranges inside text
@end

@interface QFindInFilesController : NSWindowController <NSOutlineViewDataSource, NSOutlineViewDelegate>
// The results panel content (put it in a docking area).
@property (nonatomic, readonly) NSView *resultsView;
// Called to open a hit in the editor.
@property (nonatomic, copy) void (^openHit)(QSearchHit *hit);
// Called before showing results, so the panel can be made visible.
@property (nonatomic, copy) void (^showResults)(void);
// Called after replacing, with the modified files (to reload open documents).
@property (nonatomic, copy) void (^filesModified)(NSArray<NSString *> *paths);
// Returns paths of open documents with unsaved changes (they are skipped by Replace).
@property (nonatomic, copy) NSSet<NSString *> * (^dirtyPaths)(void);

- (void)showWithSearch:(NSString *)search directory:(NSString *)directory;
@end
