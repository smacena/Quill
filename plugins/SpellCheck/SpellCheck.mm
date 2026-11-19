// Spell Check: underlines misspelled words using the macOS spell checker.
// SPDX-License-Identifier: GPL-3.0-or-later
#include "PluginCommon.h"
#include <set>

using namespace qp;

QUILL_PLUGIN_EXPORTS(L"Spell Check", L"Verificação ortográfica")

static int gIndicator = 0;
static int gAutoIndex = 0;
static NSInteger gDocTag = 0;
static std::set<UINT_PTR> gForced; // buffers checked on demand

static NSUserDefaults *defaults() {
	return [NSUserDefaults standardUserDefaults];
}

static bool autoCheck() {
	return [defaults() objectForKey:@"Spell.auto"] ? [defaults() boolForKey:@"Spell.auto"] : true;
}

static NSString *language() {
	return [defaults() stringForKey:@"Spell.language"]; // nil = automatic
}

static bool textLikeBuffer() {
	std::wstring lang = languageName();
	static const std::set<std::wstring> texty = {L"normal", L"markdown", L"tex", L"latex", L"txt2tags", L"nfo"};
	return texty.count(lang) > 0;
}

static bool shouldCheck() {
	return gForced.count(host().currentBufferID()) || (autoCheck() && textLikeBuffer());
}

static void setupIndicator() {
	if (!gIndicator) {
		int start = 0;
		if (host().npp(NPPM_ALLOCATEINDICATOR, 1, (LPARAM)&start) && start) gIndicator = start;
		else gIndicator = 30;
	}
	host().sci(SCI_INDICSETSTYLE, static_cast<WPARAM>(gIndicator), INDIC_SQUIGGLEPIXMAP);
	host().sci(SCI_INDICSETFORE, static_cast<WPARAM>(gIndicator), 0x2020E0); // red (BGR)
	host().sci(SCI_INDICSETUNDER, static_cast<WPARAM>(gIndicator), 1);
}

static void clearRange(intptr_t start, intptr_t end) {
	host().sci(SCI_SETINDICATORCURRENT, static_cast<WPARAM>(gIndicator));
	host().sci(SCI_INDICATORCLEARRANGE, static_cast<WPARAM>(start), end - start);
}

// Maps UTF-16 offsets of the NSString version of `bytes` back to byte offsets.
static std::vector<size_t> utf16ToBytes(const std::string &bytes) {
	std::vector<size_t> map;
	map.reserve(bytes.size() + 1);
	size_t i = 0;
	while (i < bytes.size()) {
		unsigned char c = static_cast<unsigned char>(bytes[i]);
		size_t len = c < 0x80 ? 1 : ((c & 0xE0) == 0xC0 ? 2 : ((c & 0xF0) == 0xE0 ? 3 : ((c & 0xF8) == 0xF0 ? 4 : 1)));
		if (i + len > bytes.size()) len = 1;
		map.push_back(i);
		if (len == 4) map.push_back(i); // surrogate pair
		i += len;
	}
	map.push_back(bytes.size());
	return map;
}

static void checkRange(intptr_t start, intptr_t end) {
	if (end <= start) return;
	setupIndicator();
	std::string text = textRange(start, end);
	NSString *s = [[NSString alloc] initWithBytes:text.data() length:text.size() encoding:NSUTF8StringEncoding];
	if (!s) return;
	std::vector<size_t> map = utf16ToBytes(text);
	if (map.size() != s.length + 1) return; // invalid UTF-8; skip
	NSSpellChecker *checker = [NSSpellChecker sharedSpellChecker];
	if (!gDocTag) gDocTag = [NSSpellChecker uniqueSpellDocumentTag];
	NSString *lang = language();
	if (lang) {
		checker.automaticallyIdentifiesLanguages = NO;
		[checker setLanguage:lang];
	} else {
		checker.automaticallyIdentifiesLanguages = YES;
	}
	NSArray<NSTextCheckingResult *> *results = [checker checkString:s
								 range:NSMakeRange(0, s.length)
								 types:NSTextCheckingTypeSpelling
							       options:nil
						inSpellDocumentWithTag:gDocTag
							   orthography:nil
							     wordCount:nil];
	clearRange(start, end);
	host().sci(SCI_SETINDICATORCURRENT, static_cast<WPARAM>(gIndicator));
	for (NSTextCheckingResult *r in results) {
		NSRange rr = r.range;
		if (NSMaxRange(rr) > s.length) continue;
		NSString *word = [s substringWithRange:rr];
		// Skip words with digits, URLs and identifiers like camelCase / snake_case.
		if ([word rangeOfCharacterFromSet:[NSCharacterSet decimalDigitCharacterSet]].location != NSNotFound) continue;
		if ([word containsString:@"_"]) continue;
		size_t b0 = map[rr.location], b1 = map[NSMaxRange(rr)];
		host().sci(SCI_INDICATORFILLRANGE, static_cast<WPARAM>(start + (intptr_t)b0), (intptr_t)(b1 - b0));
	}
}

static void checkVisible() {
	if (!shouldCheck()) return;
	intptr_t first = host().sci(SCI_DOCLINEFROMVISIBLE, static_cast<WPARAM>(host().sci(SCI_GETFIRSTVISIBLELINE)));
	intptr_t count = host().sci(SCI_LINESONSCREEN) + 2;
	intptr_t lastLine = MIN(host().sci(SCI_GETLINECOUNT) - 1, first + count);
	intptr_t start = host().sci(SCI_POSITIONFROMLINE, static_cast<WPARAM>(MAX((intptr_t)0, first - 5)));
	intptr_t end = host().sci(SCI_GETLINEENDPOSITION, static_cast<WPARAM>(MAX((intptr_t)0, lastLine + 5 < host().sci(SCI_GETLINECOUNT) ? lastLine + 5 : lastLine)));
	checkRange(start, end);
}

@interface QSpellHelper : NSObject
- (void)check;
- (void)replaceWord:(NSMenuItem *)sender;
- (void)learnWord:(NSMenuItem *)sender;
- (void)ignoreWord:(NSMenuItem *)sender;
@end

static QSpellHelper *gHelper;

static void scheduleCheck() {
	if (!gHelper) return;
	[NSObject cancelPreviousPerformRequestsWithTarget:gHelper selector:@selector(check) object:nil];
	[gHelper performSelector:@selector(check) withObject:nil afterDelay:0.4];
}

static void cmdAuto() {
	BOOL v = !autoCheck();
	[defaults() setBool:v forKey:@"Spell.auto"];
	gCommands.setChecked(gAutoIndex, v);
	if (!v && !gForced.count(host().currentBufferID())) {
		setupIndicator();
		clearRange(0, host().sci(SCI_GETLENGTH));
	} else {
		checkVisible();
	}
}

static void cmdCheckDocument() {
	gForced.insert(host().currentBufferID());
	intptr_t len = host().sci(SCI_GETLENGTH);
	// Check in chunks of whole lines to keep the work bounded.
	intptr_t lines = host().sci(SCI_GETLINECOUNT);
	for (intptr_t l = 0; l < lines; l += 400) {
		intptr_t s = host().sci(SCI_POSITIONFROMLINE, static_cast<WPARAM>(l));
		intptr_t e = host().sci(SCI_GETLINEENDPOSITION, static_cast<WPARAM>(MIN(lines - 1, l + 399)));
		checkRange(s, e);
	}
	(void)len;
	// Count marks.
	int count = 0;
	intptr_t pos = 0;
	while (pos < len) {
		intptr_t end = host().sci(SCI_INDICATOREND, static_cast<WPARAM>(gIndicator), pos);
		if (end <= pos) break;
		if (host().sci(SCI_INDICATORVALUEAT, static_cast<WPARAM>(gIndicator), pos)) count++;
		pos = end;
	}
	status([NSString stringWithFormat:QTR(@"%d possible misspelling(s)", @"%d possível(is) erro(s) de ortografia"), count]);
}

static void cmdClear() {
	gForced.erase(host().currentBufferID());
	setupIndicator();
	clearRange(0, host().sci(SCI_GETLENGTH));
}

static bool misspelledAt(intptr_t pos, intptr_t &s, intptr_t &e) {
	if (!gIndicator || !host().sci(SCI_INDICATORVALUEAT, static_cast<WPARAM>(gIndicator), pos)) return false;
	s = host().sci(SCI_INDICATORSTART, static_cast<WPARAM>(gIndicator), pos);
	e = host().sci(SCI_INDICATOREND, static_cast<WPARAM>(gIndicator), pos);
	return e > s;
}

static void cmdNext() {
	if (!gIndicator) return;
	intptr_t len = host().sci(SCI_GETLENGTH);
	intptr_t pos = host().sci(SCI_GETSELECTIONEND);
	for (int pass = 0; pass < 2; pass++) {
		while (pos < len) {
			if (host().sci(SCI_INDICATORVALUEAT, static_cast<WPARAM>(gIndicator), pos)) {
				intptr_t s, e;
				misspelledAt(pos, s, e);
				host().sci(SCI_SETSEL, static_cast<WPARAM>(s), e);
				host().sci(SCI_SCROLLCARET);
				return;
			}
			intptr_t next = host().sci(SCI_INDICATOREND, static_cast<WPARAM>(gIndicator), pos);
			if (next <= pos) break;
			pos = next;
		}
		pos = 0;
	}
	NSBeep();
}

static void addSuggestions(NSMenu *menu, intptr_t pos, BOOL atTop) {
	intptr_t s, e;
	if (!misspelledAt(pos, s, e)) return;
	NSString *word = QStr(textRange(s, e));
	NSSpellChecker *checker = [NSSpellChecker sharedSpellChecker];
	NSArray<NSString *> *guesses = [checker guessesForWordRange:NSMakeRange(0, word.length)
							   inString:word
							   language:language()
					     inSpellDocumentWithTag:gDocTag];
	NSInteger at = 0;
	if (guesses.count == 0) {
		NSMenuItem *none = [[NSMenuItem alloc] initWithTitle:QTR(@"No Guesses Found", @"Nenhuma sugestão") action:nil keyEquivalent:@""];
		none.enabled = NO;
		[menu insertItem:none atIndex:at++];
	}
	for (NSString *g in [guesses subarrayWithRange:NSMakeRange(0, MIN((NSUInteger)8, guesses.count))]) {
		NSMenuItem *mi = [[NSMenuItem alloc] initWithTitle:g action:@selector(replaceWord:) keyEquivalent:@""];
		mi.target = gHelper;
		mi.representedObject = @[ @(s), @(e), g ];
		mi.attributedTitle = [[NSAttributedString alloc] initWithString:g attributes:@{NSFontAttributeName : [NSFont menuFontOfSize:0]}];
		[menu insertItem:mi atIndex:at++];
	}
	NSMenuItem *learn = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:QTR(@"Learn \"%@\"", @"Aprender \"%@\""), word] action:@selector(learnWord:) keyEquivalent:@""];
	learn.target = gHelper;
	learn.representedObject = word;
	[menu insertItem:learn atIndex:at++];
	NSMenuItem *ignore = [[NSMenuItem alloc] initWithTitle:QTR(@"Ignore Spelling", @"Ignorar ortografia") action:@selector(ignoreWord:) keyEquivalent:@""];
	ignore.target = gHelper;
	ignore.representedObject = word;
	[menu insertItem:ignore atIndex:at++];
	[menu insertItem:[NSMenuItem separatorItem] atIndex:at++];
	(void)atTop;
}

static void contextMenuHandler(void *nsMenu, intptr_t position) {
	addSuggestions((__bridge NSMenu *)nsMenu, position, YES);
}

static void cmdSuggestions() {
	intptr_t pos = host().sci(SCI_GETCURRENTPOS);
	intptr_t s, e;
	if (!misspelledAt(pos, s, e) && !(pos > 0 && misspelledAt(pos - 1, s, e))) {
		NSBeep();
		return;
	}
	NSMenu *menu = [[NSMenu alloc] init];
	addSuggestions(menu, s, YES);
	ScintillaView *v = currentView();
	intptr_t x = host().sci(SCI_POINTXFROMPOSITION, 0, s);
	intptr_t y = host().sci(SCI_POINTYFROMPOSITION, 0, s) + host().sci(SCI_TEXTHEIGHT, 0);
	[menu popUpMenuPositioningItem:nil atLocation:NSMakePoint(x, y) inView:v.content];
}

static void cmdLanguage() {
	NSSpellChecker *checker = [NSSpellChecker sharedSpellChecker];
	NSAlert *a = [[NSAlert alloc] init];
	a.messageText = QTR(@"Spelling Language", @"Idioma da ortografia");
	NSPopUpButton *pop = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 260, 26) pullsDown:NO];
	[pop addItemWithTitle:QTR(@"Automatic by Language", @"Automático pelo idioma")];
	NSArray *langs = [checker.availableLanguages sortedArrayUsingSelector:@selector(compare:)];
	for (NSString *l in langs) {
		NSString *name = [[NSLocale currentLocale] localizedStringForLanguageCode:l] ?: l;
		[pop addItemWithTitle:[NSString stringWithFormat:@"%@ (%@)", name, l]];
		pop.lastItem.representedObject = l;
	}
	NSString *cur = language();
	if (cur) {
		for (NSMenuItem *mi in pop.itemArray)
			if ([mi.representedObject isEqual:cur]) [pop selectItem:mi];
	}
	a.accessoryView = pop;
	[a addButtonWithTitle:@"OK"];
	[a addButtonWithTitle:QTR(@"Cancel", @"Cancelar")];
	if ([a runModal] != NSAlertFirstButtonReturn) return;
	NSString *chosen = pop.selectedItem.representedObject;
	if (chosen) [defaults() setObject:chosen forKey:@"Spell.language"];
	else [defaults() removeObjectForKey:@"Spell.language"];
	checkVisible();
}

@implementation QSpellHelper
- (void)check {
	checkVisible();
}
- (void)replaceWord:(NSMenuItem *)sender {
	NSArray *info = sender.representedObject;
	intptr_t s = [info[0] longLongValue], e = [info[1] longLongValue];
	std::string w = QUtf8(info[2]);
	replaceRange(s, e, w);
	checkVisible();
}
- (void)learnWord:(NSMenuItem *)sender {
	[[NSSpellChecker sharedSpellChecker] learnWord:sender.representedObject];
	checkVisible();
}
- (void)ignoreWord:(NSMenuItem *)sender {
	[[NSSpellChecker sharedSpellChecker] ignoreWord:sender.representedObject inSpellDocumentWithTag:gDocTag];
	checkVisible();
}
@end

static void pluginInit() {
	gHelper = [[QSpellHelper alloc] init];
}

static void pluginCommands(qp::Commands &c) {
	gAutoIndex = c.add(L"Auto Check (Text and Markdown)", L"Verificar automaticamente (texto e Markdown)", cmdAuto, nullptr, autoCheck());
	c.add(L"Check Document", L"Verificar documento", cmdCheckDocument, Commands::key(0xBA /* ; */, true, false, true));
	c.add(L"Next Misspelling", L"Próximo erro", cmdNext, Commands::key(0xBA, true, false, false));
	c.add(L"Suggestions…", L"Sugestões…", cmdSuggestions, Commands::key(0xBA, true, true, false));
	c.add(L"Clear Marks", L"Limpar marcações", cmdClear);
	c.separator();
	c.add(L"Language…", L"Idioma…", cmdLanguage);
}

static void pluginNotify(SCNotification *n) {
	switch (n->nmhdr.code) {
	case NPPN_READY:
		host().npp(QUILLM_ADDCONTEXTMENUHANDLER, 0, (LPARAM)contextMenuHandler);
		break;
	case NPPN_BUFFERACTIVATED:
	case NPPN_LANGCHANGED:
		setupIndicator();
		scheduleCheck();
		break;
	case NPPN_FILECLOSED:
		gForced.erase(n->nmhdr.idFrom);
		break;
	case SCN_UPDATEUI:
		if (n->updated & (SC_UPDATE_V_SCROLL | SC_UPDATE_CONTENT)) scheduleCheck();
		break;
	default:
		break;
	}
}

static LRESULT pluginMessage(UINT, WPARAM, LPARAM) {
	return TRUE;
}
