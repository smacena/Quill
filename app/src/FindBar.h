// Inline find / replace bar shown above the editor.
// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#import <Cocoa/Cocoa.h>

@class ScintillaView;
@class QFindBar;

@protocol QFindBarDelegate <NSObject>
- (ScintillaView *)findBarEditor:(QFindBar *)bar;
- (void)findBarDidClose:(QFindBar *)bar;
- (void)findBar:(QFindBar *)bar status:(NSString *)message;
@end

@interface QFindBar : NSView <NSSearchFieldDelegate, NSTextFieldDelegate>
@property (nonatomic, weak) id<QFindBarDelegate> delegate;
@property (nonatomic, readonly) BOOL replaceMode;
@property (nonatomic, copy) NSString *searchString;
@property (nonatomic, copy) NSString *replaceString;
@property (nonatomic) BOOL matchCase;
@property (nonatomic) BOOL wholeWord;
@property (nonatomic) BOOL regex;
@property (nonatomic) BOOL inSelection;

- (CGFloat)preferredHeight;
- (void)activateWithReplace:(BOOL)replace;
- (BOOL)findNext:(BOOL)backwards;
- (void)replaceOne;
- (NSInteger)replaceAll;
- (NSInteger)markAll;
- (void)clearMarks;
- (void)useSelectionForFind;
- (void)close;
// Scintilla search flags for the current options.
- (int)searchFlags;
@end
