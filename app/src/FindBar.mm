// SPDX-License-Identifier: GPL-3.0-or-later
#import "FindBar.h"
#import "Languages.h"
#import "Localization.h"

#import "ScintillaView.h"
#include "Scintilla.h"
#include <string>

@implementation QFindBar {
	NSSearchField *_findField;
	NSTextField *_replaceField;
	NSButton *_caseButton, *_wordButton, *_regexButton, *_selectionButton;
	NSButton *_prevButton, *_nextButton, *_markButton, *_closeButton;
	NSButton *_replaceButton, *_replaceAllButton;
	NSTextField *_countLabel;
	BOOL _replaceMode;
	sptr_t _anchor;
}

static NSButton *toggleButton(NSString *title, NSString *tip, id target, SEL action) {
	NSButton *b = [NSButton buttonWithTitle:title target:target action:action];
	[b setButtonType:NSButtonTypePushOnPushOff];
	b.bezelStyle = NSBezelStyleRecessed;
	b.showsBorderOnlyWhileMouseInside = YES;
	b.font = [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightSemibold];
	b.toolTip = tip;
	b.controlSize = NSControlSizeSmall;
	return b;
}

static NSButton *iconButton(NSString *symbol, NSString *tip, id target, SEL action) {
	NSButton *b = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:tip] target:target action:action];
	b.bezelStyle = NSBezelStyleRecessed;
	b.showsBorderOnlyWhileMouseInside = YES;
	b.toolTip = tip;
	return b;
}

- (instancetype)initWithFrame:(NSRect)frame {
	if ((self = [super initWithFrame:frame])) {
		_findField = [[NSSearchField alloc] initWithFrame:NSZeroRect];
		_findField.placeholderString = T(@"Find", @"Localizar");
		_findField.delegate = self;
		_findField.sendsSearchStringImmediately = NO;
		_findField.sendsWholeSearchString = YES;
		_findField.target = self;
		_findField.action = @selector(findFieldAction:);
		_findField.recentsAutosaveName = @"QuillFindRecents";
		((NSSearchFieldCell *)_findField.cell).maximumRecents = 20;

		_replaceField = [[NSTextField alloc] initWithFrame:NSZeroRect];
		_replaceField.placeholderString = T(@"Replace with", @"Substituir por");
		_replaceField.delegate = self;
		_replaceField.bezelStyle = NSTextFieldRoundedBezel;

		_caseButton = toggleButton(@"Aa", T(@"Match case", @"Diferenciar maiúsculas/minúsculas"), self, @selector(optionChanged:));
		_wordButton = toggleButton(@"W", T(@"Whole word", @"Palavra inteira"), self, @selector(optionChanged:));
		_regexButton = toggleButton(@".*", T(@"Regular expression", @"Expressão regular"), self, @selector(optionChanged:));
		_selectionButton = toggleButton(@"[ ]", T(@"Only in selection (Replace All)", @"Somente na seleção (Substituir tudo)"), self, @selector(optionChanged:));
		_prevButton = iconButton(@"chevron.up", T(@"Find previous (⇧⌘G)", @"Localizar anterior (⇧⌘G)"), self, @selector(prevAction:));
		_nextButton = iconButton(@"chevron.down", T(@"Find next (⌘G)", @"Localizar próximo (⌘G)"), self, @selector(nextAction:));
		_markButton = [NSButton buttonWithTitle:T(@"Mark All", @"Marcar tudo") target:self action:@selector(markAction:)];
		_markButton.bezelStyle = NSBezelStyleRecessed;
		_markButton.controlSize = NSControlSizeSmall;
		_markButton.showsBorderOnlyWhileMouseInside = YES;
		_closeButton = iconButton(@"xmark.circle.fill", T(@"Close (Esc)", @"Fechar (Esc)"), self, @selector(closeAction:));
		_closeButton.bordered = NO;
		_replaceButton = [NSButton buttonWithTitle:T(@"Replace", @"Substituir") target:self action:@selector(replaceAction:)];
		_replaceButton.controlSize = NSControlSizeSmall;
		_replaceAllButton = [NSButton buttonWithTitle:T(@"Replace All", @"Substituir tudo") target:self action:@selector(replaceAllAction:)];
		_replaceAllButton.controlSize = NSControlSizeSmall;
		_countLabel = [NSTextField labelWithString:@""];
		_countLabel.font = [NSFont systemFontOfSize:11];
		_countLabel.textColor = [NSColor secondaryLabelColor];
		_countLabel.alignment = NSTextAlignmentRight;

		for (NSView *v in @[ _findField, _replaceField, _caseButton, _wordButton, _regexButton, _selectionButton, _prevButton,
				     _nextButton, _markButton, _closeButton, _replaceButton, _replaceAllButton, _countLabel ])
			[self addSubview:v];
		NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
		_caseButton.state = [d boolForKey:@"findMatchCase"];
		_wordButton.state = [d boolForKey:@"findWholeWord"];
		_regexButton.state = [d boolForKey:@"findRegex"];
		[self updateReplaceVisibility];
	}
	return self;
}

- (BOOL)isFlipped {
	return YES;
}

- (CGFloat)preferredHeight {
	return _replaceMode ? 64 : 34;
}

- (void)drawRect:(NSRect)dirtyRect {
	[[NSColor windowBackgroundColor] setFill];
	NSRectFill(self.bounds);
	[[NSColor separatorColor] setFill];
	NSRectFill(NSMakeRect(0, self.bounds.size.height - 1, self.bounds.size.width, 1));
}

- (void)layout {
	[super layout];
	CGFloat w = self.bounds.size.width;
	CGFloat x = 8, y = 5, h = 24;
	CGFloat right = w - 8;
	_closeButton.frame = NSMakeRect(right - 20, y + 2, 20, 20);
	right -= 26;
	[_markButton sizeToFit];
	CGFloat mw = _markButton.frame.size.width + 8;
	_markButton.frame = NSMakeRect(right - mw, y + 1, mw, 22);
	right -= mw + 6;
	_nextButton.frame = NSMakeRect(right - 26, y, 26, h);
	right -= 28;
	_prevButton.frame = NSMakeRect(right - 26, y, 26, h);
	right -= 32;
	_countLabel.frame = NSMakeRect(right - 110, y + 4, 110, 16);
	right -= 116;
	CGFloat bx = right;
	for (NSButton *b in @[ _selectionButton, _regexButton, _wordButton, _caseButton ]) {
		b.frame = NSMakeRect(bx - 30, y + 1, 30, 22);
		bx -= 32;
	}
	_findField.frame = NSMakeRect(x, y, MAX(120, bx - x - 6), h);
	if (_replaceMode) {
		CGFloat y2 = y + 30;
		[_replaceAllButton sizeToFit];
		[_replaceButton sizeToFit];
		CGFloat raw = _replaceAllButton.frame.size.width + 10, rw = _replaceButton.frame.size.width + 10;
		_replaceAllButton.frame = NSMakeRect(_findField.frame.origin.x + _findField.frame.size.width + 6 + rw + 4, y2, raw, h);
		_replaceButton.frame = NSMakeRect(_findField.frame.origin.x + _findField.frame.size.width + 6, y2, rw, h);
		_replaceField.frame = NSMakeRect(x, y2 + 1, _findField.frame.size.width, 22);
	}
}

- (void)updateReplaceVisibility {
	_replaceField.hidden = !_replaceMode;
	_replaceButton.hidden = !_replaceMode;
	_replaceAllButton.hidden = !_replaceMode;
	_selectionButton.hidden = !_replaceMode;
	self.needsLayout = YES;
	self.needsDisplay = YES;
}

- (BOOL)replaceMode {
	return _replaceMode;
}

- (NSString *)searchString {
	return _findField.stringValue ?: @"";
}
- (void)setSearchString:(NSString *)s {
	_findField.stringValue = s ?: @"";
}
- (NSString *)replaceString {
	return _replaceField.stringValue ?: @"";
}
- (void)setReplaceString:(NSString *)s {
	_replaceField.stringValue = s ?: @"";
}
- (BOOL)matchCase {
	return _caseButton.state == NSControlStateValueOn;
}
- (void)setMatchCase:(BOOL)v {
	_caseButton.state = v;
}
- (BOOL)wholeWord {
	return _wordButton.state == NSControlStateValueOn;
}
- (void)setWholeWord:(BOOL)v {
	_wordButton.state = v;
}
- (BOOL)regex {
	return _regexButton.state == NSControlStateValueOn;
}
- (void)setRegex:(BOOL)v {
	_regexButton.state = v;
}
- (BOOL)inSelection {
	return _selectionButton.state == NSControlStateValueOn && _replaceMode;
}
- (void)setInSelection:(BOOL)v {
	_selectionButton.state = v;
}

- (int)searchFlags {
	int f = 0;
	if (self.matchCase) f |= SCFIND_MATCHCASE;
	if (self.wholeWord) f |= SCFIND_WHOLEWORD;
	if (self.regex) f |= SCFIND_REGEXP | SCFIND_CXX11REGEX;
	return f;
}

- (ScintillaView *)editor {
	return [self.delegate findBarEditor:self];
}

- (void)status:(NSString *)msg {
	[self.delegate findBar:self status:msg];
}

- (void)activateWithReplace:(BOOL)replace {
	_replaceMode = replace;
	[self updateReplaceVisibility];
	ScintillaView *v = [self editor];
	if (v) {
		_anchor = [v message:SCI_GETSELECTIONSTART];
		NSString *sel = v.selectedString;
		if (sel.length > 0 && [sel rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]].location == NSNotFound)
			_findField.stringValue = self.regex ? [NSRegularExpression escapedPatternForString:sel] : sel;
		self.inSelection = sel.length > 0 && [sel rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]].location != NSNotFound;
	}
	[self.window makeFirstResponder:_findField];
	[_findField selectText:nil];
	[self updateCount];
}

- (void)useSelectionForFind {
	ScintillaView *v = [self editor];
	NSString *sel = v.selectedString;
	if (sel.length) {
		_findField.stringValue = self.regex ? [NSRegularExpression escapedPatternForString:sel] : sel;
		[self status:[NSString stringWithFormat:T(@"Find: %@", @"Localizar: %@"), sel]];
	}
}

- (BOOL)searchInEditor:(ScintillaView *)v from:(sptr_t)from to:(sptr_t)to text:(const std::string &)s {
	[v message:SCI_SETSEARCHFLAGS wParam:(uptr_t)[self searchFlags]];
	[v message:SCI_SETTARGETRANGE wParam:(uptr_t)from lParam:to];
	sptr_t pos = [v message:SCI_SEARCHINTARGET wParam:s.size() lParam:(sptr_t)s.c_str()];
	return pos >= 0;
}

- (void)selectTarget:(ScintillaView *)v {
	sptr_t start = [v message:SCI_GETTARGETSTART];
	sptr_t end = [v message:SCI_GETTARGETEND];
	sptr_t line = [v message:SCI_LINEFROMPOSITION wParam:(uptr_t)start];
	[v message:SCI_ENSUREVISIBLEENFORCEPOLICY wParam:(uptr_t)line];
	[v message:SCI_SETSEL wParam:(uptr_t)start lParam:end];
	[v message:SCI_SCROLLRANGE wParam:(uptr_t)end lParam:start];
}

- (BOOL)findNext:(BOOL)backwards {
	ScintillaView *v = [self editor];
	NSString *needle = self.searchString;
	if (!v || needle.length == 0) return NO;
	std::string s(needle.UTF8String);
	sptr_t len = [v message:SCI_GETLENGTH];
	sptr_t selStart = [v message:SCI_GETSELECTIONSTART];
	sptr_t selEnd = [v message:SCI_GETSELECTIONEND];
	BOOL found;
	if (!backwards) {
		sptr_t from = selEnd;
		if (selStart == selEnd && self.regex) from = selEnd; // allow zero-width match at caret
		found = [self searchInEditor:v from:from to:len text:s];
		if (found && [v message:SCI_GETTARGETSTART] == selStart && [v message:SCI_GETTARGETEND] == selEnd && selStart == selEnd) {
			sptr_t next = [v message:SCI_POSITIONAFTER wParam:(uptr_t)selEnd];
			found = next > selEnd && [self searchInEditor:v from:next to:len text:s];
		}
		if (!found) {
			found = [self searchInEditor:v from:0 to:len text:s];
			if (found) [self status:T(@"Search wrapped to the beginning", @"A busca recomeçou do início")];
		}
	} else {
		found = [self searchInEditor:v from:selStart to:0 text:s];
		if (!found) {
			found = [self searchInEditor:v from:len to:0 text:s];
			if (found) [self status:T(@"Search wrapped to the end", @"A busca recomeçou do fim")];
		}
	}
	if (found) {
		[self selectTarget:v];
		_findField.textColor = [NSColor controlTextColor];
	} else {
		_findField.textColor = [NSColor systemRedColor];
		[self status:[NSString stringWithFormat:T(@"\"%@\" not found", @"\"%@\" não encontrado"), needle]];
		NSBeep();
	}
	return found;
}

- (BOOL)selectionMatches:(ScintillaView *)v {
	sptr_t selStart = [v message:SCI_GETSELECTIONSTART];
	sptr_t selEnd = [v message:SCI_GETSELECTIONEND];
	NSString *needle = self.searchString;
	if (needle.length == 0) return NO;
	std::string s(needle.UTF8String);
	if (![self searchInEditor:v from:selStart to:selEnd text:s]) return NO;
	return [v message:SCI_GETTARGETSTART] == selStart && [v message:SCI_GETTARGETEND] == selEnd;
}

- (void)replaceOne {
	ScintillaView *v = [self editor];
	if (!v || [v message:SCI_GETREADONLY]) return;
	if ([self selectionMatches:v]) {
		std::string r(self.replaceString.UTF8String);
		[v message:SCI_BEGINUNDOACTION];
		if (self.regex)
			[v message:SCI_REPLACETARGETRE wParam:r.size() lParam:(sptr_t)r.c_str()];
		else
			[v message:SCI_REPLACETARGET wParam:r.size() lParam:(sptr_t)r.c_str()];
		[v message:SCI_ENDUNDOACTION];
		sptr_t end = [v message:SCI_GETTARGETEND];
		[v message:SCI_SETSEL wParam:(uptr_t)end lParam:end];
	}
	[self findNext:NO];
	[self updateCount];
}

- (NSInteger)replaceAll {
	ScintillaView *v = [self editor];
	NSString *needle = self.searchString;
	if (!v || needle.length == 0 || [v message:SCI_GETREADONLY]) return 0;
	std::string s(needle.UTF8String);
	std::string r(self.replaceString.UTF8String);
	sptr_t start = 0, end = [v message:SCI_GETLENGTH];
	if (self.inSelection) {
		start = [v message:SCI_GETSELECTIONSTART];
		end = [v message:SCI_GETSELECTIONEND];
	}
	NSInteger count = 0;
	[v message:SCI_BEGINUNDOACTION];
	sptr_t pos = start;
	while (pos <= end && count < 1000000) {
		if (![self searchInEditor:v from:pos to:end text:s]) break;
		sptr_t tStart = [v message:SCI_GETTARGETSTART];
		sptr_t tEnd = [v message:SCI_GETTARGETEND];
		sptr_t replLen;
		if (self.regex)
			replLen = [v message:SCI_REPLACETARGETRE wParam:r.size() lParam:(sptr_t)r.c_str()];
		else
			replLen = [v message:SCI_REPLACETARGET wParam:r.size() lParam:(sptr_t)r.c_str()];
		count++;
		end += replLen - (tEnd - tStart);
		pos = tStart + replLen;
		if (tStart == tEnd) {
			sptr_t next = [v message:SCI_POSITIONAFTER wParam:(uptr_t)pos];
			if (next <= pos) break;
			pos = next;
		}
	}
	[v message:SCI_ENDUNDOACTION];
	[self status:[NSString stringWithFormat:T(@"%ld occurrence(s) replaced", @"%ld ocorrência(s) substituída(s)"), (long)count]];
	[self updateCount];
	return count;
}

- (NSInteger)countAndMark:(BOOL)mark {
	ScintillaView *v = [self editor];
	if (!v) return 0;
	sptr_t len = [v message:SCI_GETLENGTH];
	[v message:SCI_SETINDICATORCURRENT wParam:QIndicatorFindMark];
	[v message:SCI_INDICATORCLEARRANGE wParam:0 lParam:len];
	NSString *needle = self.searchString;
	if (needle.length == 0) return 0;
	std::string s(needle.UTF8String);
	sptr_t savedStart = [v message:SCI_GETTARGETSTART];
	sptr_t savedEnd = [v message:SCI_GETTARGETEND];
	NSInteger count = 0;
	sptr_t pos = 0;
	while (pos <= len && count < 100000) {
		if (![self searchInEditor:v from:pos to:len text:s]) break;
		sptr_t tStart = [v message:SCI_GETTARGETSTART];
		sptr_t tEnd = [v message:SCI_GETTARGETEND];
		count++;
		if (mark && tEnd > tStart) {
			[v message:SCI_SETINDICATORCURRENT wParam:QIndicatorFindMark];
			[v message:SCI_INDICATORFILLRANGE wParam:(uptr_t)tStart lParam:tEnd - tStart];
		}
		pos = tEnd > tStart ? tEnd : [v message:SCI_POSITIONAFTER wParam:(uptr_t)tEnd];
		if (pos <= tStart && tEnd == tStart) break;
	}
	[v message:SCI_SETTARGETRANGE wParam:(uptr_t)savedStart lParam:savedEnd];
	return count;
}

- (NSInteger)markAll {
	NSInteger n = [self countAndMark:YES];
	[self status:[NSString stringWithFormat:T(@"%ld match(es) marked", @"%ld ocorrência(s) marcada(s)"), (long)n]];
	_countLabel.stringValue = [NSString stringWithFormat:T(@"%ld matches", @"%ld resultados"), (long)n];
	return n;
}

- (void)clearMarks {
	ScintillaView *v = [self editor];
	if (!v) return;
	[v message:SCI_SETINDICATORCURRENT wParam:QIndicatorFindMark];
	[v message:SCI_INDICATORCLEARRANGE wParam:0 lParam:[v message:SCI_GETLENGTH]];
	_countLabel.stringValue = @"";
}

- (void)updateCount {
	if (self.searchString.length == 0) {
		[self clearMarks];
		return;
	}
	NSInteger n = [self countAndMark:YES];
	_countLabel.stringValue = n == 0 ? T(@"No results", @"Nenhum resultado")
					 : [NSString stringWithFormat:T(@"%ld matches", @"%ld resultados"), (long)n];
	_findField.textColor = n == 0 ? [NSColor systemRedColor] : [NSColor controlTextColor];
}

- (void)close {
	[self clearMarks];
	[self.delegate findBarDidClose:self];
}

// ---- Actions ---------------------------------------------------------------

- (void)saveOptions {
	NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
	[d setBool:self.matchCase forKey:@"findMatchCase"];
	[d setBool:self.wholeWord forKey:@"findWholeWord"];
	[d setBool:self.regex forKey:@"findRegex"];
}

- (void)optionChanged:(id)sender {
	[self saveOptions];
	[self updateCount];
}

- (void)findFieldAction:(id)sender {
	// Called on Enter by the search field.
}

- (void)prevAction:(id)sender {
	[self findNext:YES];
}

- (void)nextAction:(id)sender {
	[self findNext:NO];
}

- (void)markAction:(id)sender {
	[self markAll];
}

- (void)closeAction:(id)sender {
	[self close];
}

- (void)replaceAction:(id)sender {
	[self replaceOne];
}

- (void)replaceAllAction:(id)sender {
	[self replaceAll];
}

- (void)controlTextDidChange:(NSNotification *)note {
	if (note.object != _findField) return;
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(incrementalSearch) object:nil];
	[self performSelector:@selector(incrementalSearch) withObject:nil afterDelay:0.15];
}

- (void)incrementalSearch {
	ScintillaView *v = [self editor];
	if (!v) return;
	[self updateCount];
	if (self.searchString.length == 0) return;
	std::string s(self.searchString.UTF8String);
	sptr_t len = [v message:SCI_GETLENGTH];
	if ([self searchInEditor:v from:_anchor to:len text:s] || [self searchInEditor:v from:0 to:len text:s])
		[self selectTarget:v];
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)sel {
	if (sel == @selector(cancelOperation:)) {
		[self close];
		return YES;
	}
	if (sel == @selector(insertNewline:)) {
		BOOL shift = (NSApp.currentEvent.modifierFlags & NSEventModifierFlagShift) != 0;
		if (control == _replaceField) {
			[self replaceOne];
		} else {
			[self findNext:shift];
			_anchor = [[self editor] message:SCI_GETSELECTIONEND];
		}
		return YES;
	}
	if (sel == @selector(insertTab:) && control == _findField && _replaceMode) {
		[self.window makeFirstResponder:_replaceField];
		return YES;
	}
	return NO;
}

@end
