// Compare: side by side diff of two documents (tabs, saved version, clipboard or files).
// SPDX-License-Identifier: GPL-3.0-or-later
#include "PluginCommon.h"
#include "quill/Diff.h"
#include "quill/Encoding.h"

using namespace qp;

QUILL_PLUGIN_EXPORTS(L"Compare", L"Comparar")

enum LineKind { KEqual = 0, KAdded, KRemoved, KChanged, KPad };

enum {
	MarkAdded = 1,
	MarkRemoved = 2,
	MarkChanged = 3,
	MarkPad = 4,
	IndicCharDiff = 20,
};

struct Source {
	NSString *title;
	std::string text;
	UINT_PTR bufferID = 0; // 0 = not a buffer
	NSString *filePath;    // file read from disk (saved version / file)
	int langType = 0;
};

struct Side {
	std::string display;
	std::vector<int> lineNo;   // original line number (1-based), 0 for padding
	std::vector<LineKind> kinds;
	std::vector<std::pair<intptr_t, std::vector<quill::CharRange>>> charDiffs; // display line -> ranges
};

@class QCompareController;

@interface QComparePane : NSObject <ScintillaNotificationProtocol>
@property (nonatomic, weak) QCompareController *owner;
@property (nonatomic) int side;
@end

@interface QDiffOverview : NSView
@property (nonatomic) std::vector<LineKind> kinds;
@property (nonatomic, copy) void (^jump)(double fraction);
@property (nonatomic) double visibleStart;
@property (nonatomic) double visibleEnd;
@end

@interface QCompareController : NSWindowController <NSWindowDelegate>
- (void)compareLeft:(const Source &)left right:(const Source &)right;
- (void)paneScrolled:(int)side;
- (void)nextDiff:(BOOL)backwards;
- (void)refresh;
@end

static QCompareController *gCompare;
static int gIgnoreWsIndex = 0, gIgnoreCaseIndex = 0;

static bool optionIgnoreWs() {
	return [[NSUserDefaults standardUserDefaults] boolForKey:@"Compare.ignoreWhitespace"];
}
static bool optionIgnoreCase() {
	return [[NSUserDefaults standardUserDefaults] boolForKey:@"Compare.ignoreCase"];
}

static Source bufferSource(UINT_PTR id) {
	Source s;
	s.bufferID = id;
	s.text = host().bufferText(id);
	NSString *path = QStr(host().pathFromBufferID(id));
	s.title = path.lastPathComponent.length ? path.lastPathComponent : path;
	s.langType = (int)host().npp(NPPM_GETBUFFERLANGTYPE, id);
	return s;
}

static bool fileSource(NSString *path, Source &s) {
	NSData *data = [NSData dataWithContentsOfFile:path];
	if (!data) return false;
	std::string bytes(static_cast<const char *>(data.bytes), data.length);
	s.text = quill::decodeToUtf8(bytes, quill::detectEncoding(bytes));
	s.filePath = path;
	s.title = path.lastPathComponent;
	return true;
}

static void openCompare(const Source &left, const Source &right) {
	if (!gCompare) gCompare = [[QCompareController alloc] init];
	[gCompare compareLeft:left right:right];
	[gCompare showWindow:nil];
	[gCompare.window makeKeyAndOrderFront:nil];
}

static void compareWithNeighbour(int delta) {
	int index = (int)host().npp(NPPM_GETCURRENTDOCINDEX, 0, MAIN_VIEW);
	int count = (int)host().npp(NPPM_GETNBOPENFILES, 0, PRIMARY_VIEW);
	int other = index + delta;
	if (count < 2 || other < 0 || other >= count) {
		alert(QTR(@"Nothing to compare", @"Nada para comparar"),
		      delta < 0 ? QTR(@"There is no tab before the current one.", @"Não há aba antes da atual.")
				: QTR(@"There is no tab after the current one.", @"Não há aba depois da atual."));
		return;
	}
	UINT_PTR cur = host().currentBufferID();
	UINT_PTR oth = (UINT_PTR)host().npp(NPPM_GETBUFFERIDFROMPOS, static_cast<WPARAM>(other), MAIN_VIEW);
	Source a = bufferSource(delta < 0 ? oth : cur);
	Source b = bufferSource(delta < 0 ? cur : oth);
	openCompare(a, b);
}

static void cmdPrev() {
	compareWithNeighbour(-1);
}

static void cmdNext() {
	compareWithNeighbour(+1);
}

static void cmdSaved() {
	UINT_PTR cur = host().currentBufferID();
	NSString *path = QStr(host().pathFromBufferID(cur));
	Source saved;
	if (![[NSFileManager defaultManager] fileExistsAtPath:path] || !fileSource(path, saved)) {
		alert(QTR(@"No saved version", @"Sem versão salva"), QTR(@"This document has not been saved to disk yet.", @"Este documento ainda não foi salvo no disco."));
		return;
	}
	saved.title = [saved.title stringByAppendingString:QTR(@" (saved)", @" (salvo)")];
	saved.langType = (int)host().npp(NPPM_GETBUFFERLANGTYPE, cur);
	openCompare(saved, bufferSource(cur));
}

static void cmdClipboard() {
	NSString *clip = [[NSPasteboard generalPasteboard] stringForType:NSPasteboardTypeString];
	if (!clip.length) {
		alert(QTR(@"Clipboard is empty", @"A área de transferência está vazia"), @"");
		return;
	}
	Source c;
	c.text = QUtf8(clip);
	c.title = QTR(@"Clipboard", @"Área de transferência");
	UINT_PTR cur = host().currentBufferID();
	c.langType = (int)host().npp(NPPM_GETBUFFERLANGTYPE, cur);
	openCompare(c, bufferSource(cur));
}

static void cmdFiles() {
	NSOpenPanel *p = [NSOpenPanel openPanel];
	p.allowsMultipleSelection = YES;
	p.message = QTR(@"Choose two files to compare", @"Escolha dois arquivos para comparar");
	if ([p runModal] != NSModalResponseOK) return;
	NSArray<NSURL *> *urls = p.URLs;
	if (urls.count == 1) {
		NSOpenPanel *p2 = [NSOpenPanel openPanel];
		p2.message = QTR(@"Choose the second file", @"Escolha o segundo arquivo");
		if ([p2 runModal] != NSModalResponseOK) return;
		urls = @[ urls[0], p2.URL ];
	}
	Source a, b;
	if (!fileSource(urls[0].path, a) || !fileSource(urls[1].path, b)) return;
	openCompare(a, b);
}

static void cmdClear() {
	[gCompare close];
}

static void cmdNextDiff() {
	if (gCompare.window.isVisible) [gCompare nextDiff:NO];
}

static void cmdPrevDiff() {
	if (gCompare.window.isVisible) [gCompare nextDiff:YES];
}

static void cmdIgnoreWs() {
	BOOL v = !optionIgnoreWs();
	[[NSUserDefaults standardUserDefaults] setBool:v forKey:@"Compare.ignoreWhitespace"];
	gCommands.setChecked(gIgnoreWsIndex, v);
	if (gCompare.window.isVisible) [gCompare refresh];
}

static void cmdIgnoreCase() {
	BOOL v = !optionIgnoreCase();
	[[NSUserDefaults standardUserDefaults] setBool:v forKey:@"Compare.ignoreCase"];
	gCommands.setChecked(gIgnoreCaseIndex, v);
	if (gCompare.window.isVisible) [gCompare refresh];
}

static void pluginInit() {}

static void pluginCommands(qp::Commands &c) {
	c.add(L"Compare with Previous Tab", L"Comparar com a aba anterior", cmdPrev, Commands::key('C', true, true, false));
	c.add(L"Compare with Next Tab", L"Comparar com a próxima aba", cmdNext);
	c.add(L"Compare with Saved Version", L"Comparar com a versão salva", cmdSaved, Commands::key('S', true, true, true));
	c.add(L"Compare with Clipboard", L"Comparar com a área de transferência", cmdClipboard);
	c.add(L"Compare Two Files…", L"Comparar dois arquivos…", cmdFiles);
	c.add(L"Clear Comparison", L"Fechar comparação", cmdClear);
	c.separator();
	c.add(L"Next Difference", L"Próxima diferença", cmdNextDiff, Commands::key(0x28 /* VK_DOWN */, false, true, true));
	c.add(L"Previous Difference", L"Diferença anterior", cmdPrevDiff);
	c.separator();
	gIgnoreWsIndex = c.add(L"Ignore Whitespace", L"Ignorar espaços", cmdIgnoreWs, nullptr, optionIgnoreWs());
	gIgnoreCaseIndex = c.add(L"Ignore Case", L"Ignorar maiúsculas/minúsculas", cmdIgnoreCase, nullptr, optionIgnoreCase());
}

static void pluginNotify(SCNotification *n) {
	if (n->nmhdr.code == QUILLN_THEMECHANGED && gCompare.window.isVisible) [gCompare refresh];
}

static LRESULT pluginMessage(UINT, WPARAM, LPARAM) {
	return TRUE;
}

// ---- Diff to display ----------------------------------------------------------------

static void buildSides(const std::string &l, const std::string &r, Side &left, Side &right, quill::DiffStats &stats) {
	auto ll = quill::splitLines(l);
	auto rl = quill::splitLines(r);
	quill::DiffOptions opt;
	opt.ignoreWhitespace = optionIgnoreWs();
	opt.ignoreCase = optionIgnoreCase();
	auto blocks = quill::diffLines(ll, rl, opt);
	stats = quill::diffStats(blocks);
	auto add = [](Side &s, const std::string &line, int no, LineKind k) {
		s.display += line;
		s.display += "\n";
		s.lineNo.push_back(no);
		s.kinds.push_back(k);
	};
	for (const auto &b : blocks) {
		switch (b.kind) {
		case quill::DiffKind::Equal:
			for (size_t i = 0; i < b.leftCount; i++) {
				add(left, ll[b.leftStart + i], (int)(b.leftStart + i + 1), KEqual);
				add(right, rl[b.rightStart + i], (int)(b.rightStart + i + 1), KEqual);
			}
			break;
		case quill::DiffKind::Delete:
			for (size_t i = 0; i < b.leftCount; i++) {
				add(left, ll[b.leftStart + i], (int)(b.leftStart + i + 1), KRemoved);
				add(right, "", 0, KPad);
			}
			break;
		case quill::DiffKind::Insert:
			for (size_t i = 0; i < b.rightCount; i++) {
				add(left, "", 0, KPad);
				add(right, rl[b.rightStart + i], (int)(b.rightStart + i + 1), KAdded);
			}
			break;
		case quill::DiffKind::Change: {
			size_t n = std::max(b.leftCount, b.rightCount);
			for (size_t i = 0; i < n; i++) {
				intptr_t displayLine = (intptr_t)left.kinds.size();
				bool hasL = i < b.leftCount, hasR = i < b.rightCount;
				if (hasL) add(left, ll[b.leftStart + i], (int)(b.leftStart + i + 1), hasR ? KChanged : KRemoved);
				else add(left, "", 0, KPad);
				if (hasR) add(right, rl[b.rightStart + i], (int)(b.rightStart + i + 1), hasL ? KChanged : KAdded);
				else add(right, "", 0, KPad);
				if (hasL && hasR) {
					std::vector<quill::CharRange> lr, rr;
					quill::diffChars(ll[b.leftStart + i], rl[b.rightStart + i], lr, rr);
					left.charDiffs.emplace_back(displayLine, lr);
					right.charDiffs.emplace_back(displayLine, rr);
				}
			}
			break;
		}
		}
	}
}

static int bgr(uint32_t rgb) {
	return (int)(((rgb >> 16) & 0xFF) | (rgb & 0xFF00) | ((rgb & 0xFF) << 16));
}

// ---- UI ---------------------------------------------------------------------------------

@implementation QComparePane
- (void)notification:(SCNotification *)n {
	if (n->nmhdr.code == SCN_UPDATEUI && (n->updated & (SC_UPDATE_V_SCROLL | SC_UPDATE_H_SCROLL | SC_UPDATE_SELECTION)))
		[self.owner paneScrolled:self.side];
}
@end

@implementation QDiffOverview
- (BOOL)isFlipped {
	return YES;
}
- (void)drawRect:(NSRect)dirtyRect {
	[[NSColor controlBackgroundColor] setFill];
	NSRectFill(self.bounds);
	size_t n = _kinds.size();
	if (n == 0) return;
	CGFloat h = self.bounds.size.height;
	CGFloat w = self.bounds.size.width;
	for (size_t i = 0; i < n; i++) {
		LineKind k = _kinds[i];
		if (k == KEqual) continue;
		NSColor *c = k == KAdded ? [NSColor systemGreenColor] : (k == KRemoved ? [NSColor systemRedColor] : (k == KChanged ? [NSColor systemOrangeColor] : [NSColor systemGrayColor]));
		[c setFill];
		CGFloat y = floor(h * (CGFloat)i / (CGFloat)n);
		CGFloat y2 = MAX(y + 2, floor(h * (CGFloat)(i + 1) / (CGFloat)n));
		NSRectFill(NSMakeRect(2, y, w - 4, y2 - y));
	}
	[[NSColor colorWithWhite:0.5 alpha:0.25] setFill];
	NSRect vis = NSMakeRect(0, h * _visibleStart, w, MAX(4, h * (_visibleEnd - _visibleStart)));
	[[NSBezierPath bezierPathWithRoundedRect:vis xRadius:2 yRadius:2] fill];
}
- (void)mouseDown:(NSEvent *)e {
	NSPoint p = [self convertPoint:e.locationInWindow fromView:nil];
	if (self.jump) self.jump(p.y / MAX(1, self.bounds.size.height));
}
- (void)mouseDragged:(NSEvent *)e {
	[self mouseDown:e];
}
@end

@implementation QCompareController {
	ScintillaView *_views[2];
	QComparePane *_panes[2];
	NSTextField *_titles[2];
	NSTextField *_stats;
	QDiffOverview *_overview;
	Source _sources[2];
	Side _sides[2];
	std::vector<intptr_t> _diffStarts;
	BOOL _syncing;
}

- (instancetype)init {
	NSWindow *w = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1200, 760)
						  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable |
							    NSWindowStyleMaskMiniaturizable
						    backing:NSBackingStoreBuffered
						      defer:NO];
	w.releasedWhenClosed = NO;
	w.minSize = NSMakeSize(600, 300);
	if ((self = [super initWithWindow:w])) {
		w.delegate = self;
		[w setFrameAutosaveName:@"QuillCompareWindow"];
		[self build];
		if (!w.frameAutosaveName.length || NSIsEmptyRect(w.frame)) [w center];
	}
	return self;
}

- (NSButton *)toolButton:(NSString *)symbol tip:(NSString *)tip action:(SEL)action {
	NSButton *b = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:tip] target:self action:action];
	b.bezelStyle = NSBezelStyleTexturedRounded;
	b.toolTip = tip;
	return b;
}

- (void)build {
	NSView *c = self.window.contentView;
	NSButton *prev = [self toolButton:@"arrow.up" tip:QTR(@"Previous difference", @"Diferença anterior") action:@selector(prevAction:)];
	NSButton *next = [self toolButton:@"arrow.down" tip:QTR(@"Next difference", @"Próxima diferença") action:@selector(nextAction:)];
	NSButton *refresh = [self toolButton:@"arrow.clockwise" tip:QTR(@"Compare again", @"Comparar novamente") action:@selector(refreshAction:)];
	NSButton *swap = [self toolButton:@"arrow.left.arrow.right" tip:QTR(@"Swap sides", @"Trocar os lados") action:@selector(swapAction:)];
	NSButton *ws = [NSButton checkboxWithTitle:QTR(@"Ignore whitespace", @"Ignorar espaços") target:self action:@selector(optionAction:)];
	ws.identifier = @"Compare.ignoreWhitespace";
	ws.state = optionIgnoreWs();
	NSButton *cs = [NSButton checkboxWithTitle:QTR(@"Ignore case", @"Ignorar maiúsculas") target:self action:@selector(optionAction:)];
	cs.identifier = @"Compare.ignoreCase";
	cs.state = optionIgnoreCase();
	_stats = [NSTextField labelWithString:@""];
	_stats.textColor = [NSColor secondaryLabelColor];
	NSStackView *bar = [NSStackView stackViewWithViews:@[ prev, next, refresh, swap, ws, cs, _stats ]];
	bar.spacing = 8;
	bar.edgeInsets = NSEdgeInsetsMake(6, 10, 6, 10);
	bar.translatesAutoresizingMaskIntoConstraints = NO;
	[c addSubview:bar];

	NSSplitView *split = [[NSSplitView alloc] initWithFrame:NSZeroRect];
	split.vertical = YES;
	split.dividerStyle = NSSplitViewDividerStyleThin;
	split.translatesAutoresizingMaskIntoConstraints = NO;
	for (int i = 0; i < 2; i++) {
		NSView *pane = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 580, 600)];
		_titles[i] = [NSTextField labelWithString:@""];
		_titles[i].font = [NSFont systemFontOfSize:12 weight:NSFontWeightSemibold];
		_titles[i].lineBreakMode = NSLineBreakByTruncatingMiddle;
		_titles[i].translatesAutoresizingMaskIntoConstraints = NO;
		ScintillaView *v = (__bridge ScintillaView *)(void *)host().npp(NPPM_CREATESCINTILLAHANDLE, 0, 0);
		v.translatesAutoresizingMaskIntoConstraints = NO;
		_views[i] = v;
		_panes[i] = [[QComparePane alloc] init];
		_panes[i].owner = self;
		_panes[i].side = i;
		v.delegate = _panes[i];
		[pane addSubview:_titles[i]];
		[pane addSubview:v];
		[NSLayoutConstraint activateConstraints:@[
			[_titles[i].topAnchor constraintEqualToAnchor:pane.topAnchor constant:4],
			[_titles[i].leadingAnchor constraintEqualToAnchor:pane.leadingAnchor constant:8],
			[_titles[i].trailingAnchor constraintEqualToAnchor:pane.trailingAnchor constant:-8],
			[v.topAnchor constraintEqualToAnchor:_titles[i].bottomAnchor constant:4],
			[v.leadingAnchor constraintEqualToAnchor:pane.leadingAnchor],
			[v.trailingAnchor constraintEqualToAnchor:pane.trailingAnchor],
			[v.bottomAnchor constraintEqualToAnchor:pane.bottomAnchor],
		]];
		[split addSubview:pane];
	}
	_overview = [[QDiffOverview alloc] initWithFrame:NSZeroRect];
	_overview.translatesAutoresizingMaskIntoConstraints = NO;
	__weak QCompareController *weakSelf = self;
	_overview.jump = ^(double fraction) {
		[weakSelf jumpToFraction:fraction];
	};
	[c addSubview:split];
	[c addSubview:_overview];
	[NSLayoutConstraint activateConstraints:@[
		[bar.topAnchor constraintEqualToAnchor:c.topAnchor],
		[bar.leadingAnchor constraintEqualToAnchor:c.leadingAnchor],
		[bar.trailingAnchor constraintLessThanOrEqualToAnchor:c.trailingAnchor],
		[split.topAnchor constraintEqualToAnchor:bar.bottomAnchor],
		[split.leadingAnchor constraintEqualToAnchor:c.leadingAnchor],
		[split.bottomAnchor constraintEqualToAnchor:c.bottomAnchor],
		[split.trailingAnchor constraintEqualToAnchor:_overview.leadingAnchor],
		[_overview.topAnchor constraintEqualToAnchor:bar.bottomAnchor],
		[_overview.bottomAnchor constraintEqualToAnchor:c.bottomAnchor],
		[_overview.trailingAnchor constraintEqualToAnchor:c.trailingAnchor],
		[_overview.widthAnchor constraintEqualToConstant:14],
	]];
}

- (void)styleView:(ScintillaView *)v side:(int)side {
	host().npp(QUILLM_APPLYEDITORSTYLE, (WPARAM)(__bridge void *)v, _sources[side].langType);
	BOOL dark = host().npp(NPPM_ISDARKMODEENABLED) != 0;
	[v message:SCI_MARKERDEFINE wParam:MarkAdded lParam:SC_MARK_BACKGROUND];
	[v message:SCI_MARKERDEFINE wParam:MarkRemoved lParam:SC_MARK_BACKGROUND];
	[v message:SCI_MARKERDEFINE wParam:MarkChanged lParam:SC_MARK_BACKGROUND];
	[v message:SCI_MARKERDEFINE wParam:MarkPad lParam:SC_MARK_BACKGROUND];
	[v message:SCI_MARKERSETBACK wParam:MarkAdded lParam:bgr(dark ? 0x1F3B26 : 0xDDF7E3)];
	[v message:SCI_MARKERSETBACK wParam:MarkRemoved lParam:bgr(dark ? 0x4A2124 : 0xFDE2E1)];
	[v message:SCI_MARKERSETBACK wParam:MarkChanged lParam:bgr(dark ? 0x463B1C : 0xFFF4CC)];
	[v message:SCI_MARKERSETBACK wParam:MarkPad lParam:bgr(dark ? 0x2A2A2A : 0xF0F0F0)];
	[v message:SCI_INDICSETSTYLE wParam:IndicCharDiff lParam:INDIC_FULLBOX];
	[v message:SCI_INDICSETFORE wParam:IndicCharDiff lParam:bgr(dark ? 0xE5A50A : 0xF0A30A)];
	[v message:SCI_INDICSETALPHA wParam:IndicCharDiff lParam:dark ? 110 : 90];
	[v message:SCI_INDICSETUNDER wParam:IndicCharDiff lParam:1];
	// Margin 0: original line numbers (right aligned text margin).
	[v message:SCI_SETMARGINTYPEN wParam:0 lParam:SC_MARGIN_RTEXT];
	[v message:SCI_SETMARGINWIDTHN wParam:0 lParam:[v message:SCI_TEXTWIDTH wParam:STYLE_LINENUMBER lParam:(sptr_t) "_99999"]];
	[v message:SCI_SETMARGINWIDTHN wParam:1 lParam:0];
	[v message:SCI_SETMARGINWIDTHN wParam:2 lParam:0];
	[v message:SCI_SETWRAPMODE wParam:SC_WRAP_NONE];
	[v message:SCI_RESETELEMENTCOLOUR wParam:SC_ELEMENT_CARET_LINE_BACK];
	[v message:SCI_SETSELECTIONLAYER wParam:SC_LAYER_UNDER_TEXT];
}

- (void)loadSide:(int)side {
	ScintillaView *v = _views[side];
	Side &s = _sides[side];
	[v message:SCI_SETREADONLY wParam:0];
	[v message:SCI_SETCHANGEHISTORY wParam:SC_CHANGE_HISTORY_DISABLED];
	[v message:SCI_SETTEXT wParam:0 lParam:(sptr_t)s.display.c_str()];
	[v message:SCI_SETEMPTYSELECTION wParam:0];
	[v message:SCI_EMPTYUNDOBUFFER];
	[v message:SCI_MARKERDELETEALL wParam:(uptr_t)-1];
	[self styleView:v side:side];
	for (size_t i = 0; i < s.kinds.size(); i++) {
		int mark = 0;
		switch (s.kinds[i]) {
		case KAdded: mark = MarkAdded; break;
		case KRemoved: mark = MarkRemoved; break;
		case KChanged: mark = MarkChanged; break;
		case KPad: mark = MarkPad; break;
		default: break;
		}
		if (mark) [v message:SCI_MARKERADD wParam:i lParam:mark];
		if (s.lineNo[i] > 0) {
			std::string no = std::to_string(s.lineNo[i]);
			[v message:SCI_MARGINSETTEXT wParam:i lParam:(sptr_t)no.c_str()];
			[v message:SCI_MARGINSETSTYLE wParam:i lParam:STYLE_LINENUMBER];
		}
	}
	[v message:SCI_SETINDICATORCURRENT wParam:IndicCharDiff];
	for (auto &cd : s.charDiffs) {
		sptr_t lineStart = [v message:SCI_POSITIONFROMLINE wParam:(uptr_t)cd.first];
		for (auto &r : cd.second) [v message:SCI_INDICATORFILLRANGE wParam:(uptr_t)(lineStart + (sptr_t)r.start) lParam:(sptr_t)r.length];
	}
	[v message:SCI_SETREADONLY wParam:1];
	_titles[side].stringValue = _sources[side].title ?: @"";
	_titles[side].toolTip = _sources[side].filePath ?: _sources[side].title;
}

- (void)compareLeft:(const Source &)left right:(const Source &)right {
	_sources[0] = left;
	_sources[1] = right;
	[self recompute];
}

- (void)recompute {
	_sides[0] = Side();
	_sides[1] = Side();
	quill::DiffStats stats;
	buildSides(_sources[0].text, _sources[1].text, _sides[0], _sides[1], stats);
	_diffStarts.clear();
	for (size_t i = 0; i < _sides[0].kinds.size(); i++) {
		bool diff = _sides[0].kinds[i] != KEqual || _sides[1].kinds[i] != KEqual;
		bool prevDiff = i > 0 && (_sides[0].kinds[i - 1] != KEqual || _sides[1].kinds[i - 1] != KEqual);
		if (diff && !prevDiff) _diffStarts.push_back((intptr_t)i);
	}
	[self loadSide:0];
	[self loadSide:1];
	std::vector<LineKind> merged(_sides[0].kinds.size(), KEqual);
	for (size_t i = 0; i < merged.size(); i++) {
		LineKind a = _sides[0].kinds[i], b = _sides[1].kinds[i];
		merged[i] = a == KChanged || b == KChanged ? KChanged : (a == KRemoved ? KRemoved : (b == KAdded ? KAdded : KEqual));
	}
	_overview.kinds = merged;
	_overview.needsDisplay = YES;
	self.window.title = [NSString stringWithFormat:QTR(@"Compare: %@ ↔ %@", @"Comparar: %@ ↔ %@"), _sources[0].title ?: @"", _sources[1].title ?: @""];
	if (stats.blocks == 0) {
		_stats.stringValue = QTR(@"The files are identical.", @"Os arquivos são idênticos.");
	} else {
		_stats.stringValue = [NSString stringWithFormat:QTR(@"%zu difference(s): %zu added, %zu removed, %zu changed line(s)",
								     @"%zu diferença(s): %zu linha(s) adicionada(s), %zu removida(s), %zu alterada(s)"),
								stats.blocks, stats.added, stats.removed, stats.changed];
	}
	if (!_diffStarts.empty()) [self gotoDisplayLine:_diffStarts.front()];
	[self paneScrolled:0];
}

- (void)refresh {
	for (int i = 0; i < 2; i++) {
		Source &s = _sources[i];
		if (s.bufferID) {
			std::string t = host().bufferText(s.bufferID);
			if (host().npp(QUILLM_GETBUFFERTEXT, s.bufferID, 0) >= 0) s.text = t;
		} else if (s.filePath && [[NSFileManager defaultManager] fileExistsAtPath:s.filePath]) {
			NSString *title = s.title;
			fileSource(s.filePath, s);
			s.title = title;
		}
	}
	[self recompute];
}

- (void)gotoDisplayLine:(intptr_t)line {
	for (int i = 0; i < 2; i++) {
		ScintillaView *v = _views[i];
		[v message:SCI_GOTOLINE wParam:(uptr_t)line];
		sptr_t visible = [v message:SCI_LINESONSCREEN];
		[v message:SCI_SETFIRSTVISIBLELINE wParam:(uptr_t)MAX(0, line - visible / 3)];
	}
}

- (void)nextDiff:(BOOL)backwards {
	if (_diffStarts.empty()) {
		NSBeep();
		return;
	}
	sptr_t cur = [_views[0] message:SCI_LINEFROMPOSITION wParam:(uptr_t)[_views[0] message:SCI_GETCURRENTPOS]];
	intptr_t target = -1;
	if (!backwards) {
		for (intptr_t s : _diffStarts)
			if (s > cur) {
				target = s;
				break;
			}
		if (target < 0) target = _diffStarts.front();
	} else {
		for (auto it = _diffStarts.rbegin(); it != _diffStarts.rend(); ++it)
			if (*it < cur) {
				target = *it;
				break;
			}
		if (target < 0) target = _diffStarts.back();
	}
	[self gotoDisplayLine:target];
}

- (void)jumpToFraction:(double)f {
	sptr_t lines = [_views[0] message:SCI_GETLINECOUNT];
	sptr_t visible = [_views[0] message:SCI_LINESONSCREEN];
	sptr_t first = (sptr_t)(f * lines) - visible / 2;
	[_views[0] message:SCI_SETFIRSTVISIBLELINE wParam:(uptr_t)MAX(0, first)];
	[self paneScrolled:0];
}

- (void)paneScrolled:(int)side {
	if (_syncing) return;
	_syncing = YES;
	ScintillaView *from = _views[side], *to = _views[1 - side];
	sptr_t first = [from message:SCI_GETFIRSTVISIBLELINE];
	sptr_t xoff = [from message:SCI_GETXOFFSET];
	if ([to message:SCI_GETFIRSTVISIBLELINE] != first) [to message:SCI_SETFIRSTVISIBLELINE wParam:(uptr_t)first];
	if ([to message:SCI_GETXOFFSET] != xoff) [to message:SCI_SETXOFFSET wParam:(uptr_t)xoff];
	sptr_t line = [from message:SCI_LINEFROMPOSITION wParam:(uptr_t)[from message:SCI_GETCURRENTPOS]];
	sptr_t otherLine = [to message:SCI_LINEFROMPOSITION wParam:(uptr_t)[to message:SCI_GETCURRENTPOS]];
	if (line != otherLine) [to message:SCI_GOTOLINE wParam:(uptr_t)line];
	[to message:SCI_SETFIRSTVISIBLELINE wParam:(uptr_t)first];
	sptr_t lines = MAX((sptr_t)1, [from message:SCI_GETLINECOUNT]);
	sptr_t visible = [from message:SCI_LINESONSCREEN];
	_overview.visibleStart = (double)first / (double)lines;
	_overview.visibleEnd = MIN(1.0, (double)(first + visible) / (double)lines);
	_overview.needsDisplay = YES;
	_syncing = NO;
}

- (void)prevAction:(id)sender {
	[self nextDiff:YES];
}
- (void)nextAction:(id)sender {
	[self nextDiff:NO];
}
- (void)refreshAction:(id)sender {
	[self refresh];
}
- (void)swapAction:(id)sender {
	std::swap(_sources[0], _sources[1]);
	[self recompute];
}
- (void)optionAction:(NSButton *)sender {
	[[NSUserDefaults standardUserDefaults] setBool:sender.state == NSControlStateValueOn forKey:sender.identifier];
	gCommands.setChecked(gIgnoreWsIndex, optionIgnoreWs());
	gCommands.setChecked(gIgnoreCaseIndex, optionIgnoreCase());
	[self recompute];
}

- (void)windowWillClose:(NSNotification *)n {
	for (int i = 0; i < 2; i++) {
		[_views[i] message:SCI_SETREADONLY wParam:0];
		[_views[i] message:SCI_CLEARALL];
	}
}

@end
