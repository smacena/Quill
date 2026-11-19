// Language definitions (from languages.json) and editor styling.
// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#import <Cocoa/Cocoa.h>

@class ScintillaView;

// Marker / indicator numbers used by the app. Plugins get their own through
// NPPM_ALLOCATEMARKER / NPPM_ALLOCATEINDICATOR.
enum {
	QMarkerBookmark = 20,
	QIndicatorFindMark = 18,    // "Mark all" results
	QIndicatorSmartHighlight = 19, // other occurrences of the selected word
	QIndicatorFirstPlugin = 20,
	QIndicatorLastPlugin = 34,
	QMarkerFirstPlugin = 1,
	QMarkerLastPlugin = 15,
};

@interface QLanguage : NSObject
@property (nonatomic, copy) NSString *name;        // internal name ("cpp")
@property (nonatomic, copy) NSString *displayName; // menu name ("C++")
@property (nonatomic, copy) NSString *lexer;       // Lexilla lexer name
@property (nonatomic) int langType;                // Notepad++ LangType value
@property (nonatomic, copy) NSArray<NSString *> *extensions;
@property (nonatomic, copy) NSArray<NSString *> *fileNames;
@property (nonatomic, copy) NSString *commentLine;
@property (nonatomic, copy) NSString *commentStart;
@property (nonatomic, copy) NSString *commentEnd;
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *keywords; // set index -> words
@property (nonatomic, copy) NSArray<NSArray *> *styles; // [styleID, token]
@property (nonatomic, copy) NSSet<NSNumber *> *boldStyles;
@property (nonatomic, copy) NSSet<NSNumber *> *italicStyles;
@property (nonatomic, readonly) BOOL isPlainText;
@end

@interface QLanguageManager : NSObject
+ (instancetype)shared;
@property (nonatomic, readonly) NSArray<QLanguage *> *languages; // sorted by display name
@property (nonatomic, readonly) QLanguage *plainText;
- (QLanguage *)languageNamed:(NSString *)name;
- (QLanguage *)languageForLangType:(int)langType;
// Chooses a language for a file from its name, extension and first line (shebang / <?xml).
- (QLanguage *)detectForPath:(NSString *)path firstLine:(NSString *)firstLine;
@end

@interface QEditorStyler : NSObject
+ (BOOL)isDark;
// One time setup of a new editor view (margins, markers, behaviour).
+ (void)configureEditor:(ScintillaView *)view;
// Font, colors, lexer and keywords. lang may be nil for plain text.
+ (void)applyLanguage:(QLanguage *)lang toEditor:(ScintillaView *)view;
// Options from QPrefs (wrap, whitespace, tabs, margins...).
+ (void)applyPreferencesToEditor:(ScintillaView *)view;
// Updates the line number margin width for the current line count.
+ (void)updateLineNumberMargin:(ScintillaView *)view;
+ (NSColor *)editorBackgroundColor;
+ (NSColor *)editorForegroundColor;
@end
