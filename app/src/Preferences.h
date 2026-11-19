// User preferences (stored in NSUserDefaults).
// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#import <Cocoa/Cocoa.h>

extern NSString *const QPrefsChangedNotification;

typedef NS_ENUM(NSInteger, QThemeMode) {
	QThemeModeAuto = 0,
	QThemeModeLight = 1,
	QThemeModeDark = 2,
};

@interface QPrefs : NSObject
+ (instancetype)shared;

@property (nonatomic, copy) NSString *fontName;
@property (nonatomic) CGFloat fontSize;
@property (nonatomic) NSInteger tabWidth;
@property (nonatomic) BOOL useSpaces;
@property (nonatomic) BOOL wordWrap;
@property (nonatomic) BOOL showLineNumbers;
@property (nonatomic) BOOL showWhitespace;
@property (nonatomic) BOOL showEOL;
@property (nonatomic) BOOL showIndentGuides;
@property (nonatomic) BOOL highlightCurrentLine;
@property (nonatomic) BOOL autoIndent;
@property (nonatomic) BOOL autoCloseBrackets;
@property (nonatomic) BOOL autoCompleteWords;
@property (nonatomic) BOOL highlightMatchingWords;
@property (nonatomic) BOOL showFoldMargin;
@property (nonatomic) BOOL showToolbar;
@property (nonatomic) BOOL showStatusBar;
@property (nonatomic) BOOL restoreSession;
@property (nonatomic) BOOL backupUnsaved;       // keep unsaved changes across restarts
@property (nonatomic) BOOL trimOnSave;
@property (nonatomic) BOOL ensureFinalNewline;
@property (nonatomic) NSInteger edgeColumn;      // 0 = no vertical edge
@property (nonatomic) QThemeMode theme;
@property (nonatomic) NSInteger defaultEncoding; // quill::TextEncoding
@property (nonatomic) NSInteger defaultLineEnding; // quill::LineEnding

- (NSFont *)editorFont;
- (void)notifyChanged;
@end
