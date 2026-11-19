// SPDX-License-Identifier: GPL-3.0-or-later
#import "Preferences.h"

NSString *const QPrefsChangedNotification = @"QPrefsChangedNotification";

@implementation QPrefs

+ (instancetype)shared {
	static QPrefs *prefs;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		prefs = [[QPrefs alloc] init];
	});
	return prefs;
}

- (instancetype)init {
	if ((self = [super init])) {
		[[NSUserDefaults standardUserDefaults] registerDefaults:@{
			@"fontName" : @"Menlo",
			@"fontSize" : @13,
			@"tabWidth" : @4,
			@"useSpaces" : @NO,
			@"wordWrap" : @NO,
			@"showLineNumbers" : @YES,
			@"showWhitespace" : @NO,
			@"showEOL" : @NO,
			@"showIndentGuides" : @YES,
			@"highlightCurrentLine" : @YES,
			@"autoIndent" : @YES,
			@"autoCloseBrackets" : @NO,
			@"autoCompleteWords" : @YES,
			@"highlightMatchingWords" : @YES,
			@"showFoldMargin" : @YES,
			@"showToolbar" : @YES,
			@"showStatusBar" : @YES,
			@"restoreSession" : @YES,
			@"backupUnsaved" : @YES,
			@"trimOnSave" : @NO,
			@"ensureFinalNewline" : @NO,
			@"edgeColumn" : @0,
			@"theme" : @0,
			@"defaultEncoding" : @0,
			@"defaultLineEnding" : @0,
		}];
	}
	return self;
}

#define D [NSUserDefaults standardUserDefaults]

#define BOOL_PROP(getter, setter, key)                       \
	-(BOOL)getter { return [D boolForKey:key]; }         \
	-(void)setter:(BOOL)v { [D setBool:v forKey:key]; [self notifyChanged]; }

#define INT_PROP(getter, setter, key)                        \
	-(NSInteger)getter { return [D integerForKey:key]; } \
	-(void)setter:(NSInteger)v { [D setInteger:v forKey:key]; [self notifyChanged]; }

BOOL_PROP(useSpaces, setUseSpaces, @"useSpaces")
BOOL_PROP(wordWrap, setWordWrap, @"wordWrap")
BOOL_PROP(showLineNumbers, setShowLineNumbers, @"showLineNumbers")
BOOL_PROP(showWhitespace, setShowWhitespace, @"showWhitespace")
BOOL_PROP(showEOL, setShowEOL, @"showEOL")
BOOL_PROP(showIndentGuides, setShowIndentGuides, @"showIndentGuides")
BOOL_PROP(highlightCurrentLine, setHighlightCurrentLine, @"highlightCurrentLine")
BOOL_PROP(autoIndent, setAutoIndent, @"autoIndent")
BOOL_PROP(autoCloseBrackets, setAutoCloseBrackets, @"autoCloseBrackets")
BOOL_PROP(autoCompleteWords, setAutoCompleteWords, @"autoCompleteWords")
BOOL_PROP(highlightMatchingWords, setHighlightMatchingWords, @"highlightMatchingWords")
BOOL_PROP(showFoldMargin, setShowFoldMargin, @"showFoldMargin")
BOOL_PROP(showToolbar, setShowToolbar, @"showToolbar")
BOOL_PROP(showStatusBar, setShowStatusBar, @"showStatusBar")
BOOL_PROP(restoreSession, setRestoreSession, @"restoreSession")
BOOL_PROP(backupUnsaved, setBackupUnsaved, @"backupUnsaved")
BOOL_PROP(trimOnSave, setTrimOnSave, @"trimOnSave")
BOOL_PROP(ensureFinalNewline, setEnsureFinalNewline, @"ensureFinalNewline")
INT_PROP(tabWidth, setTabWidth, @"tabWidth")
INT_PROP(edgeColumn, setEdgeColumn, @"edgeColumn")
INT_PROP(defaultEncoding, setDefaultEncoding, @"defaultEncoding")
INT_PROP(defaultLineEnding, setDefaultLineEnding, @"defaultLineEnding")

- (QThemeMode)theme {
	return (QThemeMode)[D integerForKey:@"theme"];
}
- (void)setTheme:(QThemeMode)theme {
	[D setInteger:theme forKey:@"theme"];
	[self notifyChanged];
}

- (NSString *)fontName {
	return [D stringForKey:@"fontName"];
}
- (void)setFontName:(NSString *)fontName {
	[D setObject:fontName forKey:@"fontName"];
	[self notifyChanged];
}

- (CGFloat)fontSize {
	CGFloat s = [D doubleForKey:@"fontSize"];
	return s < 6 ? 13 : s;
}
- (void)setFontSize:(CGFloat)fontSize {
	[D setDouble:fontSize forKey:@"fontSize"];
	[self notifyChanged];
}

- (NSFont *)editorFont {
	NSFont *f = [NSFont fontWithName:self.fontName size:self.fontSize];
	return f ?: [NSFont monospacedSystemFontOfSize:self.fontSize weight:NSFontWeightRegular];
}

- (void)notifyChanged {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(postChanged) object:nil];
	[self performSelector:@selector(postChanged) withObject:nil afterDelay:0];
}

- (void)postChanged {
	[[NSNotificationCenter defaultCenter] postNotificationName:QPrefsChangedNotification object:self];
}

@end
