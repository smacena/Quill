// SPDX-License-Identifier: GPL-3.0-or-later
#import "Languages.h"
#import "Preferences.h"

#import "ScintillaView.h"
#include <string>
#include "ILexer.h"
#include "Scintilla.h"
#include "SciLexer.h"

extern "C" Scintilla::ILexer5 *CreateLexer(const char *name);

// ---------------------------------------------------------------------------

@implementation QLanguage
- (BOOL)isPlainText {
	return [self.lexer isEqualToString:@"null"] || self.lexer.length == 0;
}
@end

@implementation QLanguageManager {
	NSArray<QLanguage *> *_languages;
	NSMutableDictionary<NSString *, QLanguage *> *_byName;
	NSMutableDictionary<NSString *, QLanguage *> *_byExtension;
	NSMutableDictionary<NSString *, QLanguage *> *_byFileName;
	QLanguage *_plain;
}

+ (instancetype)shared {
	static QLanguageManager *m;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		m = [[QLanguageManager alloc] init];
	});
	return m;
}

- (instancetype)init {
	if ((self = [super init])) {
		_byName = [NSMutableDictionary dictionary];
		_byExtension = [NSMutableDictionary dictionary];
		_byFileName = [NSMutableDictionary dictionary];
		NSMutableArray *list = [NSMutableArray array];
		NSString *path = [[NSBundle mainBundle] pathForResource:@"languages" ofType:@"json"];
		NSData *data = path ? [NSData dataWithContentsOfFile:path] : nil;
		NSArray *json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
		for (NSDictionary *d in json) {
			QLanguage *l = [[QLanguage alloc] init];
			l.name = d[@"name"];
			l.displayName = d[@"display"];
			l.lexer = d[@"lexer"];
			l.langType = [d[@"langType"] intValue];
			l.extensions = d[@"ext"] ?: @[];
			l.fileNames = d[@"filenames"] ?: @[];
			l.commentLine = d[@"commentLine"];
			l.commentStart = d[@"commentStart"];
			l.commentEnd = d[@"commentEnd"];
			l.keywords = d[@"keywords"] ?: @{};
			l.styles = d[@"styles"] ?: @[];
			l.boldStyles = [NSSet setWithArray:d[@"bold"] ?: @[]];
			l.italicStyles = [NSSet setWithArray:d[@"italic"] ?: @[]];
			[list addObject:l];
			_byName[l.name] = l;
			for (NSString *ext in l.extensions) {
				NSString *key = ext.lowercaseString;
				if (!_byExtension[key]) _byExtension[key] = l;
			}
			for (NSString *fn in l.fileNames)
				_byFileName[fn] = l;
		}
		_plain = _byName[@"normal"];
		if (!_plain) {
			_plain = [[QLanguage alloc] init];
			_plain.name = @"normal";
			_plain.displayName = @"Normal text";
			_plain.lexer = @"null";
			_plain.langType = 0;
			[list addObject:_plain];
			_byName[@"normal"] = _plain;
		}
		_plain.displayName = @"Normal text";
		// Preferred owners for ambiguous extensions.
		NSDictionary *prefer = @{
			@"h" : @"cpp", @"m" : @"objc", @"mm" : @"objc", @"txt" : @"normal", @"js" : @"javascript.js",
			@"ts" : @"typescript", @"json" : @"json", @"inc" : @"php", @"sql" : @"sql", @"xml" : @"xml",
			@"html" : @"html", @"htm" : @"html", @"md" : @"markdown", @"log" : @"normal", @"conf" : @"props",
			@"cfg" : @"ini", @"pl" : @"perl", @"v" : @"verilog", @"r" : @"r", @"bas" : @"vb",
		};
		[prefer enumerateKeysAndObjectsUsingBlock:^(NSString *ext, NSString *name, BOOL *stop) {
			if (self->_byName[name]) self->_byExtension[ext] = self->_byName[name];
		}];
		_languages = [list sortedArrayUsingComparator:^NSComparisonResult(QLanguage *a, QLanguage *b) {
			if (a == self->_plain) return NSOrderedAscending;
			if (b == self->_plain) return NSOrderedDescending;
			return [a.displayName localizedCaseInsensitiveCompare:b.displayName];
		}];
	}
	return self;
}

- (NSArray<QLanguage *> *)languages {
	return _languages;
}

- (QLanguage *)plainText {
	return _plain;
}

- (QLanguage *)languageNamed:(NSString *)name {
	return name ? _byName[name] : nil;
}

- (QLanguage *)languageForLangType:(int)langType {
	if (langType == 19) langType = 58; // L_JS_EMBEDDED -> JavaScript
	for (QLanguage *l in _languages)
		if (l.langType == langType && langType != 15) return l;
	return nil;
}

- (QLanguage *)detectForPath:(NSString *)path firstLine:(NSString *)firstLine {
	NSString *fileName = path.lastPathComponent;
	if (fileName.length) {
		QLanguage *byFile = _byFileName[fileName];
		if (byFile) return byFile;
		NSString *ext = fileName.pathExtension.lowercaseString;
		if (ext.length == 0 && [fileName hasPrefix:@"."])
			ext = [fileName substringFromIndex:1].lowercaseString;
		if ([fileName.lowercaseString isEqualToString:@"dockerfile"] || [fileName.lowercaseString hasPrefix:@"dockerfile."])
			return _byName[@"dockerfile"] ?: _plain;
		if (ext.length) {
			QLanguage *l = _byExtension[ext];
			if (l) return l;
		}
	}
	NSString *line = [firstLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	if ([line hasPrefix:@"#!"]) {
		NSDictionary *shebangs = @{
			@"python" : @"python", @"bash" : @"bash", @"/sh" : @"bash", @"zsh" : @"bash", @"env sh" : @"bash",
			@"node" : @"javascript.js", @"ruby" : @"ruby", @"perl" : @"perl", @"php" : @"php", @"lua" : @"lua",
			@"tclsh" : @"tcl", @"Rscript" : @"r", @"pwsh" : @"powershell", @"swift" : @"swift", @"julia" : @"julia",
		};
		for (NSString *key in shebangs)
			if ([line rangeOfString:key].location != NSNotFound) return _byName[shebangs[key]] ?: _plain;
	}
	if ([line hasPrefix:@"<?xml"]) return _byName[@"xml"];
	if ([line.lowercaseString hasPrefix:@"<!doctype html"] || [line.lowercaseString hasPrefix:@"<html"]) return _byName[@"html"];
	if ([line hasPrefix:@"<?php"]) return _byName[@"php"];
	return _plain;
}

@end

// ---------------------------------------------------------------------------

namespace {

int rgb(uint32_t hex) {
	return static_cast<int>(((hex >> 16) & 0xFF) | (hex & 0xFF00) | ((hex & 0xFF) << 16));
}

int rgba(uint32_t hex, uint8_t alpha) {
	return rgb(hex) | (static_cast<int>(alpha) << 24);
}

struct Palette {
	uint32_t background, foreground, caret, selection, selectionInactive, currentLine;
	uint8_t currentLineAlpha;
	uint32_t marginBack, marginFore, foldBack, foldMarker, indentGuide, whitespace, edge;
	uint32_t braceBack, braceFore, braceBad, findMark, smartHighlight, bookmark;
	NSDictionary<NSString *, NSNumber *> *tokens;
	uint32_t addedBack, deletedBack;
};

Palette lightPalette() {
	Palette p;
	p.background = 0xFFFFFF;
	p.foreground = 0x1F1F24;
	p.caret = 0x000000;
	p.selection = 0xADD6FF;
	p.selectionInactive = 0xE5EBF1;
	p.currentLine = 0x000000;
	p.currentLineAlpha = 0x0C;
	p.marginBack = 0xF7F7F7;
	p.marginFore = 0x8C8C8C;
	p.foldBack = 0xF7F7F7;
	p.foldMarker = 0x9A9A9A;
	p.indentGuide = 0xD8D8D8;
	p.whitespace = 0xB8B8B8;
	p.edge = 0xE0E0E0;
	p.braceBack = 0xC8E1FF;
	p.braceFore = 0x000000;
	p.braceBad = 0xD32F2F;
	p.findMark = 0xF9A825;
	p.smartHighlight = 0x2E7D32;
	p.bookmark = 0x1E88E5;
	p.addedBack = 0xE6FFEC;
	p.deletedBack = 0xFFEBE9;
	p.tokens = @{
		@"default" : @0x1F1F24, @"comment" : @0x6A8759, @"commentDoc" : @0x5E7D5E, @"keyword" : @0x0033B3,
		@"keyword2" : @0x8E24AA, @"type" : @0x267F99, @"string" : @0xA31515, @"number" : @0x098658,
		@"operator" : @0x383A42, @"preprocessor" : @0xAF00DB, @"function" : @0x795E26, @"variable" : @0x001080,
		@"tag" : @0x800000, @"attribute" : @0xC2185B, @"entity" : @0x0033B3, @"regex" : @0x811F3F,
		@"label" : @0xAF00DB, @"error" : @0xCD3131, @"added" : @0x22863A, @"deleted" : @0xB31D28,
		@"changed" : @0xE36209,
	};
	return p;
}

Palette darkPalette() {
	Palette p;
	p.background = 0x1E1E1E;
	p.foreground = 0xD4D4D4;
	p.caret = 0xAEAFAD;
	p.selection = 0x264F78;
	p.selectionInactive = 0x3A3D41;
	p.currentLine = 0xFFFFFF;
	p.currentLineAlpha = 0x0D;
	p.marginBack = 0x1E1E1E;
	p.marginFore = 0x858585;
	p.foldBack = 0x1E1E1E;
	p.foldMarker = 0x8A8A8A;
	p.indentGuide = 0x404040;
	p.whitespace = 0x5A5A5A;
	p.edge = 0x333333;
	p.braceBack = 0x3B514D;
	p.braceFore = 0xFFFFFF;
	p.braceBad = 0xF44747;
	p.findMark = 0xC9A227;
	p.smartHighlight = 0x6A9955;
	p.bookmark = 0x4FA3F7;
	p.addedBack = 0x233D29;
	p.deletedBack = 0x4B2326;
	p.tokens = @{
		@"default" : @0xD4D4D4, @"comment" : @0x6A9955, @"commentDoc" : @0x6A9955, @"keyword" : @0x569CD6,
		@"keyword2" : @0xC586C0, @"type" : @0x4EC9B0, @"string" : @0xCE9178, @"number" : @0xB5CEA8,
		@"operator" : @0xD4D4D4, @"preprocessor" : @0xC586C0, @"function" : @0xDCDCAA, @"variable" : @0x9CDCFE,
		@"tag" : @0x569CD6, @"attribute" : @0x9CDCFE, @"entity" : @0x569CD6, @"regex" : @0xD16969,
		@"label" : @0xC586C0, @"error" : @0xF44747, @"added" : @0x81B88B, @"deleted" : @0xF14C4C,
		@"changed" : @0xE2C08D,
	};
	return p;
}

Palette currentPalette() {
	return [QEditorStyler isDark] ? darkPalette() : lightPalette();
}

NSColor *colorFromHex(uint32_t hex) {
	return [NSColor colorWithSRGBRed:((hex >> 16) & 0xFF) / 255.0 green:((hex >> 8) & 0xFF) / 255.0 blue:(hex & 0xFF) / 255.0 alpha:1];
}

} // namespace

@implementation QEditorStyler

+ (BOOL)isDark {
	NSAppearance *appearance = NSApp.effectiveAppearance;
	QThemeMode mode = [QPrefs shared].theme;
	if (mode == QThemeModeLight) return NO;
	if (mode == QThemeModeDark) return YES;
	NSAppearanceName best = [appearance bestMatchFromAppearancesWithNames:@[ NSAppearanceNameAqua, NSAppearanceNameDarkAqua ]];
	return [best isEqualToString:NSAppearanceNameDarkAqua];
}

+ (NSColor *)editorBackgroundColor {
	return colorFromHex(currentPalette().background);
}

+ (NSColor *)editorForegroundColor {
	return colorFromHex(currentPalette().foreground);
}

+ (void)configureEditor:(ScintillaView *)v {
	[v message:SCI_SETCODEPAGE wParam:SC_CP_UTF8];
	[v message:SCI_SETMULTIPLESELECTION wParam:1];
	[v message:SCI_SETADDITIONALSELECTIONTYPING wParam:1];
	[v message:SCI_SETMULTIPASTE wParam:SC_MULTIPASTE_EACH];
	[v message:SCI_SETVIRTUALSPACEOPTIONS wParam:SCVS_RECTANGULARSELECTION];
	[v message:SCI_SETSCROLLWIDTHTRACKING wParam:1];
	[v message:SCI_SETSCROLLWIDTH wParam:1];
	[v message:SCI_SETMOUSESELECTIONRECTANGULARSWITCH wParam:1];
	[v message:SCI_SETCARETWIDTH wParam:2];
	[v message:SCI_SETCARETLINEVISIBLEALWAYS wParam:1];
	[v message:SCI_SETCARETLINEFRAME wParam:0];
	[v message:SCI_SETENDATLASTLINE wParam:0];
	[v message:SCI_SETXCARETPOLICY wParam:CARET_SLOP | CARET_EVEN lParam:40];
	[v message:SCI_SETYCARETPOLICY wParam:CARET_SLOP | CARET_EVEN lParam:2];
	[v message:SCI_SETMARGINLEFT wParam:0 lParam:4];
	[v message:SCI_AUTOCSETIGNORECASE wParam:1];
	[v message:SCI_AUTOCSETMAXHEIGHT wParam:10];
	[v message:SCI_AUTOCSETORDER wParam:SC_ORDER_PERFORMSORT];
	[v message:SCI_SETLAYOUTCACHE wParam:SC_CACHE_PAGE];
	[v message:SCI_SETCHANGEHISTORY wParam:SC_CHANGE_HISTORY_ENABLED | SC_CHANGE_HISTORY_MARKERS];
	[v message:SCI_SETMODEVENTMASK wParam:SC_MODEVENTMASKALL];
	[v message:SCI_USEPOPUP wParam:SC_POPUP_TEXT];
	[v message:SCI_SETMOUSEDWELLTIME wParam:SC_TIME_FOREVER];

	// Margin 0: line numbers, 1: bookmarks + change history, 2: folding.
	[v message:SCI_SETMARGINS wParam:3];
	[v message:SCI_SETMARGINTYPEN wParam:0 lParam:SC_MARGIN_NUMBER];
	[v message:SCI_SETMARGINTYPEN wParam:1 lParam:SC_MARGIN_SYMBOL];
	int symbolMask = (1 << QMarkerBookmark) | (1 << SC_MARKNUM_HISTORY_REVERTED_TO_ORIGIN) |
			 (1 << SC_MARKNUM_HISTORY_SAVED) | (1 << SC_MARKNUM_HISTORY_MODIFIED) |
			 (1 << SC_MARKNUM_HISTORY_REVERTED_TO_MODIFIED);
	for (int m = QMarkerFirstPlugin; m <= QMarkerLastPlugin; m++) symbolMask |= (1 << m);
	[v message:SCI_SETMARGINMASKN wParam:1 lParam:symbolMask];
	[v message:SCI_SETMARGINWIDTHN wParam:1 lParam:14];
	[v message:SCI_SETMARGINSENSITIVEN wParam:1 lParam:1];
	[v message:SCI_SETMARGINTYPEN wParam:2 lParam:SC_MARGIN_SYMBOL];
	[v message:SCI_SETMARGINMASKN wParam:2 lParam:SC_MASK_FOLDERS];
	[v message:SCI_SETMARGINSENSITIVEN wParam:2 lParam:1];
	[v message:SCI_SETMARGINMASKN wParam:0 lParam:0];

	[v message:SCI_MARKERDEFINE wParam:QMarkerBookmark lParam:SC_MARK_BOOKMARK];
	[v message:SCI_SETAUTOMATICFOLD wParam:SC_AUTOMATICFOLD_SHOW | SC_AUTOMATICFOLD_CLICK | SC_AUTOMATICFOLD_CHANGE];
	[v message:SCI_SETFOLDFLAGS wParam:SC_FOLDFLAG_LINEAFTER_CONTRACTED];
	[v message:SCI_MARKERDEFINE wParam:SC_MARKNUM_FOLDEROPEN lParam:SC_MARK_BOXMINUS];
	[v message:SCI_MARKERDEFINE wParam:SC_MARKNUM_FOLDER lParam:SC_MARK_BOXPLUS];
	[v message:SCI_MARKERDEFINE wParam:SC_MARKNUM_FOLDERSUB lParam:SC_MARK_VLINE];
	[v message:SCI_MARKERDEFINE wParam:SC_MARKNUM_FOLDERTAIL lParam:SC_MARK_LCORNER];
	[v message:SCI_MARKERDEFINE wParam:SC_MARKNUM_FOLDEREND lParam:SC_MARK_BOXPLUSCONNECTED];
	[v message:SCI_MARKERDEFINE wParam:SC_MARKNUM_FOLDEROPENMID lParam:SC_MARK_BOXMINUSCONNECTED];
	[v message:SCI_MARKERDEFINE wParam:SC_MARKNUM_FOLDERMIDTAIL lParam:SC_MARK_TCORNER];

	[v message:SCI_INDICSETSTYLE wParam:QIndicatorFindMark lParam:INDIC_ROUNDBOX];
	[v message:SCI_INDICSETALPHA wParam:QIndicatorFindMark lParam:90];
	[v message:SCI_INDICSETOUTLINEALPHA wParam:QIndicatorFindMark lParam:200];
	[v message:SCI_INDICSETUNDER wParam:QIndicatorFindMark lParam:1];
	[v message:SCI_INDICSETSTYLE wParam:QIndicatorSmartHighlight lParam:INDIC_ROUNDBOX];
	[v message:SCI_INDICSETALPHA wParam:QIndicatorSmartHighlight lParam:50];
	[v message:SCI_INDICSETOUTLINEALPHA wParam:QIndicatorSmartHighlight lParam:120];
	[v message:SCI_INDICSETUNDER wParam:QIndicatorSmartHighlight lParam:1];

	[self applyPreferencesToEditor:v];
}

+ (void)applyPreferencesToEditor:(ScintillaView *)v {
	QPrefs *p = [QPrefs shared];
	[v message:SCI_SETWRAPMODE wParam:p.wordWrap ? SC_WRAP_WORD : SC_WRAP_NONE];
	[v message:SCI_SETWRAPVISUALFLAGS wParam:SC_WRAPVISUALFLAG_END];
	[v message:SCI_SETWRAPINDENTMODE wParam:SC_WRAPINDENT_SAME];
	[v message:SCI_SETVIEWWS wParam:p.showWhitespace ? SCWS_VISIBLEALWAYS : SCWS_INVISIBLE];
	[v message:SCI_SETVIEWEOL wParam:p.showEOL];
	[v message:SCI_SETINDENTATIONGUIDES wParam:p.showIndentGuides ? SC_IV_LOOKBOTH : SC_IV_NONE];
	[v message:SCI_SETTABWIDTH wParam:(uptr_t)MAX(1, p.tabWidth)];
	[v message:SCI_SETINDENT wParam:0];
	[v message:SCI_SETUSETABS wParam:!p.useSpaces];
	[v message:SCI_SETTABINDENTS wParam:1];
	[v message:SCI_SETBACKSPACEUNINDENTS wParam:1];
	if (p.edgeColumn > 0) {
		[v message:SCI_SETEDGEMODE wParam:EDGE_LINE];
		[v message:SCI_SETEDGECOLUMN wParam:(uptr_t)p.edgeColumn];
	} else {
		[v message:SCI_SETEDGEMODE wParam:EDGE_NONE];
	}
	[v message:SCI_SETMARGINWIDTHN wParam:2 lParam:p.showFoldMargin ? 14 : 0];
	[self updateLineNumberMargin:v];
}

+ (void)updateLineNumberMargin:(ScintillaView *)v {
	if (![QPrefs shared].showLineNumbers) {
		[v message:SCI_SETMARGINWIDTHN wParam:0 lParam:0];
		return;
	}
	long lines = [v message:SCI_GETLINECOUNT];
	int digits = 3;
	while (lines >= 1000) {
		digits++;
		lines /= 10;
	}
	std::string sample = "_" + std::string(static_cast<size_t>(digits), '9');
	long width = [v message:SCI_TEXTWIDTH wParam:STYLE_LINENUMBER lParam:(sptr_t)sample.c_str()];
	long current = [v message:SCI_GETMARGINWIDTHN wParam:0];
	if (width + 4 != current) [v message:SCI_SETMARGINWIDTHN wParam:0 lParam:width + 4];
}

+ (void)applyLanguage:(QLanguage *)lang toEditor:(ScintillaView *)v {
	Palette pal = currentPalette();
	QPrefs *prefs = [QPrefs shared];
	NSFont *font = prefs.editorFont;

	// Lexer
	Scintilla::ILexer5 *lexer = nullptr;
	if (lang && !lang.isPlainText) lexer = CreateLexer(lang.lexer.UTF8String);
	[v message:SCI_SETILEXER wParam:0 lParam:(sptr_t)lexer];

	// Base style
	[v message:SCI_STYLERESETDEFAULT];
	[v message:SCI_STYLESETFONT wParam:STYLE_DEFAULT lParam:(sptr_t)font.familyName.UTF8String];
	[v message:SCI_STYLESETSIZEFRACTIONAL wParam:STYLE_DEFAULT lParam:(sptr_t)(font.pointSize * SC_FONT_SIZE_MULTIPLIER)];
	[v message:SCI_STYLESETFORE wParam:STYLE_DEFAULT lParam:rgb(pal.foreground)];
	[v message:SCI_STYLESETBACK wParam:STYLE_DEFAULT lParam:rgb(pal.background)];
	[v message:SCI_STYLECLEARALL];

	NSDictionary *tokens = pal.tokens;
	for (NSArray *style in lang.styles) {
		if (style.count < 2) continue;
		int sid = [style[0] intValue];
		NSString *token = style[1];
		NSNumber *color = tokens[token] ?: tokens[@"default"];
		[v message:SCI_STYLESETFORE wParam:(uptr_t)sid lParam:rgb(color.unsignedIntValue)];
		if ([token isEqualToString:@"added"])
			[v message:SCI_STYLESETBACK wParam:(uptr_t)sid lParam:rgb(pal.addedBack)];
		if ([token isEqualToString:@"deleted"])
			[v message:SCI_STYLESETBACK wParam:(uptr_t)sid lParam:rgb(pal.deletedBack)];
		if ([lang.boldStyles containsObject:@(sid)])
			[v message:SCI_STYLESETBOLD wParam:(uptr_t)sid lParam:1];
		if ([lang.italicStyles containsObject:@(sid)])
			[v message:SCI_STYLESETITALIC wParam:(uptr_t)sid lParam:1];
	}

	// Keywords
	for (NSString *key in lang.keywords) {
		NSString *words = lang.keywords[key];
		[v message:SCI_SETKEYWORDS wParam:(uptr_t)key.intValue lParam:(sptr_t)words.UTF8String];
	}

	// Lexer properties
	NSDictionary *props = @{
		@"fold" : @"1", @"fold.compact" : @"0", @"fold.comment" : @"1", @"fold.preprocessor" : @"1",
		@"fold.html" : @"1", @"fold.cpp.comment.explicit" : @"0", @"lexer.cpp.track.preprocessor" : @"0",
		@"fold.at.else" : @"1", @"fold.quotes.python" : @"1", @"lexer.json.allow.comments" : @"1",
		@"lexer.json.escape.sequence" : @"1", @"lexer.xml.allow.scripts" : @"1",
	};
	for (NSString *k in props)
		[v message:SCI_SETPROPERTY wParam:(uptr_t)k.UTF8String lParam:(sptr_t)[props[k] UTF8String]];
	NSSet *backquoted = [NSSet setWithArray:@[ @"javascript.js", @"typescript", @"go", @"kotlin" ]];
	if ([backquoted containsObject:lang.name])
		[v message:SCI_SETPROPERTY wParam:(uptr_t) "lexer.cpp.backquoted.strings" lParam:(sptr_t) "1"];
	if ([lang.name isEqualToString:@"json5"])
		[v message:SCI_SETPROPERTY wParam:(uptr_t) "lexer.json.allow.comments" lParam:(sptr_t) "1"];

	// Special styles
	[v message:SCI_STYLESETFORE wParam:STYLE_LINENUMBER lParam:rgb(pal.marginFore)];
	[v message:SCI_STYLESETBACK wParam:STYLE_LINENUMBER lParam:rgb(pal.marginBack)];
	[v message:SCI_STYLESETSIZEFRACTIONAL wParam:STYLE_LINENUMBER lParam:(sptr_t)(MAX(9.0, font.pointSize - 1) * SC_FONT_SIZE_MULTIPLIER)];
	[v message:SCI_STYLESETFORE wParam:STYLE_INDENTGUIDE lParam:rgb(pal.indentGuide)];
	[v message:SCI_STYLESETBACK wParam:STYLE_INDENTGUIDE lParam:rgb(pal.background)];
	[v message:SCI_STYLESETFORE wParam:STYLE_BRACELIGHT lParam:rgb(pal.braceFore)];
	[v message:SCI_STYLESETBACK wParam:STYLE_BRACELIGHT lParam:rgb(pal.braceBack)];
	[v message:SCI_STYLESETBOLD wParam:STYLE_BRACELIGHT lParam:1];
	[v message:SCI_STYLESETFORE wParam:STYLE_BRACEBAD lParam:rgb(pal.braceBad)];
	[v message:SCI_STYLESETFORE wParam:STYLE_CONTROLCHAR lParam:rgb(pal.whitespace)];
	[v message:SCI_STYLESETBACK wParam:STYLE_FOLDDISPLAYTEXT lParam:rgb(pal.marginBack)];

	// Elements
	[v message:SCI_SETELEMENTCOLOUR wParam:SC_ELEMENT_CARET lParam:rgba(pal.caret, 0xFF)];
	[v message:SCI_SETELEMENTCOLOUR wParam:SC_ELEMENT_SELECTION_BACK lParam:rgba(pal.selection, 0xFF)];
	[v message:SCI_SETELEMENTCOLOUR wParam:SC_ELEMENT_SELECTION_ADDITIONAL_BACK lParam:rgba(pal.selection, 0xC0)];
	[v message:SCI_SETELEMENTCOLOUR wParam:SC_ELEMENT_SELECTION_SECONDARY_BACK lParam:rgba(pal.selectionInactive, 0xFF)];
	[v message:SCI_SETELEMENTCOLOUR wParam:SC_ELEMENT_SELECTION_INACTIVE_BACK lParam:rgba(pal.selectionInactive, 0xFF)];
	if (prefs.highlightCurrentLine)
		[v message:SCI_SETELEMENTCOLOUR wParam:SC_ELEMENT_CARET_LINE_BACK lParam:rgba(pal.currentLine, pal.currentLineAlpha)];
	else
		[v message:SCI_RESETELEMENTCOLOUR wParam:SC_ELEMENT_CARET_LINE_BACK];
	[v message:SCI_SETELEMENTCOLOUR wParam:SC_ELEMENT_WHITE_SPACE lParam:rgba(pal.whitespace, 0xFF)];
	[v message:SCI_SETSELECTIONLAYER wParam:SC_LAYER_UNDER_TEXT];
	[v message:SCI_SETCARETLINELAYER wParam:SC_LAYER_UNDER_TEXT];
	[v message:SCI_SETEDGECOLOUR wParam:(uptr_t)rgb(pal.edge)];
	[v message:SCI_SETWHITESPACESIZE wParam:2];

	// Margins
	[v message:SCI_SETMARGINBACKN wParam:1 lParam:rgb(pal.marginBack)];
	[v message:SCI_SETMARGINBACKN wParam:2 lParam:rgb(pal.foldBack)];
	[v message:SCI_SETFOLDMARGINCOLOUR wParam:1 lParam:rgb(pal.foldBack)];
	[v message:SCI_SETFOLDMARGINHICOLOUR wParam:1 lParam:rgb(pal.foldBack)];
	for (int m = SC_MARKNUM_FOLDEREND; m <= SC_MARKNUM_FOLDEROPEN; m++) {
		[v message:SCI_MARKERSETFORE wParam:(uptr_t)m lParam:rgb(pal.foldBack)];
		[v message:SCI_MARKERSETBACK wParam:(uptr_t)m lParam:rgb(pal.foldMarker)];
		[v message:SCI_MARKERSETBACKSELECTED wParam:(uptr_t)m lParam:rgb(pal.foldMarker)];
	}
	[v message:SCI_MARKERSETFORE wParam:QMarkerBookmark lParam:rgb(pal.bookmark)];
	[v message:SCI_MARKERSETBACK wParam:QMarkerBookmark lParam:rgb(pal.bookmark)];

	[v message:SCI_INDICSETFORE wParam:QIndicatorFindMark lParam:rgb(pal.findMark)];
	[v message:SCI_INDICSETFORE wParam:QIndicatorSmartHighlight lParam:rgb(pal.smartHighlight)];

	[v message:SCI_COLOURISE wParam:0 lParam:-1];
	[self updateLineNumberMargin:v];
	[v setNeedsDisplay:YES];
}

@end
