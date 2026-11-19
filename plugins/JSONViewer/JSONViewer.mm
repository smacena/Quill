// JSON Viewer: format / minify / validate JSON and browse it as a tree.
// SPDX-License-Identifier: GPL-3.0-or-later
#include "PluginCommon.h"
#include "quill/Json.h"
#include <functional>

using namespace qp;

QUILL_PLUGIN_EXPORTS(L"JSON Viewer", L"Visualizador JSON")

// ---- Tree model -----------------------------------------------------------------

@interface QJNode : NSObject
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) NSString *path;
@property (nonatomic) std::shared_ptr<quill::JsonValue> value;
@property (nonatomic, strong) NSArray<QJNode *> *children;
@end

@implementation QJNode
- (NSArray<QJNode *> *)children {
	if (_children) return _children;
	NSMutableArray *kids = [NSMutableArray array];
	auto v = self.value;
	if (v && v->type == quill::JsonValue::Type::Object) {
		for (auto &m : v->members) {
			QJNode *n = [[QJNode alloc] init];
			n.key = QStr(m.first);
			n.value = m.second;
			BOOL simple = [n.key rangeOfCharacterFromSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]].location == NSNotFound;
			n.path = simple ? [NSString stringWithFormat:@"%@.%@", self.path, n.key] : [NSString stringWithFormat:@"%@[\"%@\"]", self.path, n.key];
			[kids addObject:n];
		}
	} else if (v && v->type == quill::JsonValue::Type::Array) {
		for (size_t i = 0; i < v->items.size(); i++) {
			QJNode *n = [[QJNode alloc] init];
			n.key = [NSString stringWithFormat:@"[%zu]", i];
			n.value = v->items[i];
			n.path = [NSString stringWithFormat:@"%@[%zu]", self.path, i];
			[kids addObject:n];
		}
	}
	_children = kids;
	return _children;
}
@end

@interface QJSONPanel : NSView <NSOutlineViewDataSource, NSOutlineViewDelegate, NSSearchFieldDelegate>
@property (nonatomic, strong) NSOutlineView *outline;
@property (nonatomic, strong) NSTextField *pathLabel;
@property (nonatomic, strong) NSSearchField *search;
@property (nonatomic, strong) QJNode *root;
@property (nonatomic) UINT_PTR bufferID;
- (void)reload;
@end

// ---- Commands -----------------------------------------------------------------------

static QJSONPanel *gPanel;
static Panel gDock;
static int gTreeIndex = 0, gIndent2Index = 0;

static int indentSize() {
	return [[NSUserDefaults standardUserDefaults] boolForKey:@"JSONViewer.indent2"] ? 2 : 4;
}

static std::shared_ptr<quill::JsonValue> parseCurrent(intptr_t &start, intptr_t &end, bool report) {
	std::string text = selectionOrAll(start, end);
	quill::JsonError err;
	auto v = quill::parseJson(text, err);
	if (!v && report) {
		// Move the caret to the error.
		host().sci(SCI_GOTOPOS, static_cast<WPARAM>(start + static_cast<intptr_t>(err.offset)));
		alert(QTR(@"Invalid JSON", @"JSON inválido"),
		      [NSString stringWithFormat:QTR(@"%@\nLine %zu, column %zu.", @"%@\nLinha %zu, coluna %zu."), QStr(err.message), err.line, err.column],
		      NSAlertStyleWarning);
	}
	return v;
}

static void formatJSON(bool sortKeys) {
	intptr_t start, end;
	auto v = parseCurrent(start, end, true);
	if (!v) return;
	quill::JsonFormatOptions o;
	o.indent = indentSize();
	o.sortKeys = sortKeys;
	int eolMode = (int)host().sci(SCI_GETEOLMODE);
	o.eol = eolMode == SC_EOL_CRLF ? "\r\n" : (eolMode == SC_EOL_CR ? "\r" : "\n");
	replaceRange(start, end, quill::formatJson(*v, o));
	if (gPanel && gDock.visible()) [gPanel reload];
	status(QTR(@"JSON formatted", @"JSON formatado"));
}

static void cmdFormat() {
	formatJSON(false);
}

static void cmdSortFormat() {
	formatJSON(true);
}

static void cmdMinify() {
	intptr_t start, end;
	auto v = parseCurrent(start, end, true);
	if (!v) return;
	replaceRange(start, end, quill::minifyJson(*v));
	status(QTR(@"JSON minified", @"JSON compactado"));
}

static void cmdValidate() {
	intptr_t start, end;
	auto v = parseCurrent(start, end, true);
	if (v) alert(QTR(@"Valid JSON", @"JSON válido"), QTR(@"No syntax errors found.", @"Nenhum erro de sintaxe encontrado."));
}

static void cmdEscape() {
	intptr_t start = host().sci(SCI_GETSELECTIONSTART), end = host().sci(SCI_GETSELECTIONEND);
	if (end <= start) return;
	std::string s = textRange(start, end);
	replaceRange(start, end, "\"" + quill::escapeJsonString(s) + "\"");
}

static void cmdUnescape() {
	intptr_t start = host().sci(SCI_GETSELECTIONSTART), end = host().sci(SCI_GETSELECTIONEND);
	if (end <= start) return;
	std::string s = textRange(start, end);
	if (s.size() < 2 || s.front() != '"') s = "\"" + s + "\"";
	quill::JsonError err;
	auto v = quill::parseJson(s, err);
	if (!v || v->type != quill::JsonValue::Type::String) {
		NSBeep();
		return;
	}
	replaceRange(start, end, v->text);
}

static void ensurePanel() {
	if (gPanel) return;
	gPanel = [[QJSONPanel alloc] initWithFrame:NSMakeRect(0, 0, 300, 500)];
	gDock.registerIn(gPanel, host().tr(L"JSON", L"JSON"), L"JSONViewer.dylib", gTreeIndex, DWS_DF_CONT_RIGHT);
}

static void cmdTree() {
	ensurePanel();
	if (gDock.visible()) {
		gDock.hide();
		gCommands.setChecked(gTreeIndex, false);
	} else {
		[gPanel reload];
		gDock.show();
		gCommands.setChecked(gTreeIndex, true);
	}
}

static void cmdIndent2() {
	BOOL v = ![[NSUserDefaults standardUserDefaults] boolForKey:@"JSONViewer.indent2"];
	[[NSUserDefaults standardUserDefaults] setBool:v forKey:@"JSONViewer.indent2"];
	gCommands.setChecked(gIndent2Index, v);
}

static void pluginInit() {}

static void pluginCommands(qp::Commands &c) {
	gTreeIndex = c.add(L"Show JSON Tree", L"Mostrar árvore JSON", cmdTree, Commands::key('J', true, true, false));
	c.separator();
	c.add(L"Format JSON", L"Formatar JSON", cmdFormat, Commands::key('M', true, true, true));
	c.add(L"Minify JSON", L"Compactar JSON", cmdMinify);
	c.add(L"Sort Keys and Format", L"Ordenar chaves e formatar", cmdSortFormat);
	c.add(L"Validate JSON", L"Validar JSON", cmdValidate);
	c.separator();
	c.add(L"Escape Selection as JSON String", L"Escapar seleção como string JSON", cmdEscape);
	c.add(L"Unescape JSON String", L"Desescapar string JSON", cmdUnescape);
	c.separator();
	gIndent2Index = c.add(L"Indent with 2 Spaces", L"Indentar com 2 espaços", cmdIndent2, nullptr,
			      [[NSUserDefaults standardUserDefaults] boolForKey:@"JSONViewer.indent2"]);
}

static void pluginNotify(SCNotification *n) {
	switch (n->nmhdr.code) {
	case NPPN_BUFFERACTIVATED:
	case NPPN_FILESAVED:
		if (gPanel && gDock.visible()) [gPanel reload];
		break;
	case QUILLN_PANELCLOSED:
		if (gPanel && n->nmhdr.hwndFrom == (__bridge void *)gPanel) gCommands.setChecked(gTreeIndex, false);
		break;
	default:
		break;
	}
}

static LRESULT pluginMessage(UINT, WPARAM, LPARAM) {
	return TRUE;
}

// ---- Panel ---------------------------------------------------------------------------

@implementation QJSONPanel {
	NSTextField *_message;
}

- (instancetype)initWithFrame:(NSRect)frame {
	if ((self = [super initWithFrame:frame])) {
		NSButton *refresh = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"arrow.clockwise" accessibilityDescription:nil]
						       target:self
						       action:@selector(refresh:)];
		refresh.bezelStyle = NSBezelStyleRecessed;
		refresh.toolTip = QTR(@"Refresh from the current document", @"Atualizar a partir do documento atual");
		NSButton *expand = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"plus.square" accessibilityDescription:nil]
						      target:self
						      action:@selector(expandAll:)];
		expand.bezelStyle = NSBezelStyleRecessed;
		expand.toolTip = QTR(@"Expand all", @"Expandir tudo");
		NSButton *collapse = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"minus.square" accessibilityDescription:nil]
							target:self
							action:@selector(collapseAll:)];
		collapse.bezelStyle = NSBezelStyleRecessed;
		collapse.toolTip = QTR(@"Collapse all", @"Recolher tudo");
		_search = [[NSSearchField alloc] initWithFrame:NSZeroRect];
		_search.placeholderString = QTR(@"Find key or value", @"Localizar chave ou valor");
		_search.delegate = self;
		_search.target = self;
		_search.action = @selector(searchAction:);
		_search.controlSize = NSControlSizeSmall;
		NSStackView *bar = [NSStackView stackViewWithViews:@[ refresh, expand, collapse, _search ]];
		bar.spacing = 4;
		bar.edgeInsets = NSEdgeInsetsMake(4, 6, 4, 6);
		bar.translatesAutoresizingMaskIntoConstraints = NO;

		NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
		scroll.hasVerticalScroller = YES;
		scroll.hasHorizontalScroller = YES;
		scroll.autohidesScrollers = YES;
		scroll.translatesAutoresizingMaskIntoConstraints = NO;
		_outline = [[NSOutlineView alloc] initWithFrame:NSZeroRect];
		NSArray *cols = @[ @[ @"key", QTR(@"Key", @"Chave"), @120 ], @[ @"value", QTR(@"Value", @"Valor"), @160 ], @[ @"type", QTR(@"Type", @"Tipo"), @60 ] ];
		for (NSArray *def in cols) {
			NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:def[0]];
			col.title = def[1];
			col.width = [def[2] doubleValue];
			col.resizingMask = NSTableColumnUserResizingMask | NSTableColumnAutoresizingMask;
			[_outline addTableColumn:col];
		}
		_outline.outlineTableColumn = _outline.tableColumns[0];
		_outline.dataSource = self;
		_outline.delegate = self;
		_outline.rowSizeStyle = NSTableViewRowSizeStyleSmall;
		_outline.usesAlternatingRowBackgroundColors = YES;
		_outline.columnAutoresizingStyle = NSTableViewLastColumnOnlyAutoresizingStyle;
		_outline.target = self;
		_outline.doubleAction = @selector(goToNode:);
		scroll.documentView = _outline;

		_pathLabel = [NSTextField labelWithString:@"$"];
		_pathLabel.font = monoFont(11);
		_pathLabel.textColor = [NSColor secondaryLabelColor];
		_pathLabel.selectable = YES;
		_pathLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
		_pathLabel.translatesAutoresizingMaskIntoConstraints = NO;
		_message = [NSTextField wrappingLabelWithString:@""];
		_message.textColor = [NSColor secondaryLabelColor];
		_message.translatesAutoresizingMaskIntoConstraints = NO;
		_message.hidden = YES;

		[self addSubview:bar];
		[self addSubview:scroll];
		[self addSubview:_pathLabel];
		[self addSubview:_message];
		[NSLayoutConstraint activateConstraints:@[
			[bar.topAnchor constraintEqualToAnchor:self.topAnchor],
			[bar.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
			[bar.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
			[scroll.topAnchor constraintEqualToAnchor:bar.bottomAnchor],
			[scroll.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
			[scroll.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
			[scroll.bottomAnchor constraintEqualToAnchor:_pathLabel.topAnchor constant:-4],
			[_pathLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:6],
			[_pathLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-6],
			[_pathLabel.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-4],
			[_message.topAnchor constraintEqualToAnchor:bar.bottomAnchor constant:10],
			[_message.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:10],
			[_message.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-10],
		]];
	}
	return self;
}

- (void)reload {
	std::string text = host().currentText();
	self.bufferID = host().currentBufferID();
	quill::JsonError err;
	auto v = text.size() > 50 * 1024 * 1024 ? nullptr : quill::parseJson(text, err);
	if (!v) {
		self.root = nil;
		_message.stringValue = text.empty() ? QTR(@"The document is empty.", @"O documento está vazio.")
						    : [NSString stringWithFormat:QTR(@"Not valid JSON: %@ (line %zu, column %zu)", @"JSON inválido: %@ (linha %zu, coluna %zu)"),
										 QStr(err.message), err.line, err.column];
		_message.hidden = NO;
	} else {
		QJNode *root = [[QJNode alloc] init];
		root.key = @"$";
		root.path = @"$";
		root.value = v;
		self.root = root;
		_message.hidden = YES;
	}
	[_outline reloadData];
	if (self.root) [_outline expandItem:self.root];
}

- (void)refresh:(id)sender {
	[self reload];
}

- (void)expandAll:(id)sender {
	[_outline expandItem:nil expandChildren:YES];
}

- (void)collapseAll:(id)sender {
	[_outline collapseItem:nil collapseChildren:YES];
	if (self.root) [_outline expandItem:self.root];
}

- (NSInteger)outlineView:(NSOutlineView *)ov numberOfChildrenOfItem:(id)item {
	if (!item) return self.root ? 1 : 0;
	return (NSInteger)((QJNode *)item).children.count;
}

- (id)outlineView:(NSOutlineView *)ov child:(NSInteger)index ofItem:(id)item {
	if (!item) return self.root;
	return ((QJNode *)item).children[(NSUInteger)index];
}

- (BOOL)outlineView:(NSOutlineView *)ov isItemExpandable:(id)item {
	auto v = ((QJNode *)item).value;
	return v && (v->type == quill::JsonValue::Type::Object || v->type == quill::JsonValue::Type::Array) &&
	       (!v->members.empty() || !v->items.empty());
}

- (NSView *)outlineView:(NSOutlineView *)ov viewForTableColumn:(NSTableColumn *)col item:(id)item {
	QJNode *n = item;
	NSString *ident = col.identifier;
	NSTextField *tf = [ov makeViewWithIdentifier:ident owner:self];
	if (!tf) {
		tf = [NSTextField labelWithString:@""];
		tf.identifier = ident;
		tf.lineBreakMode = NSLineBreakByTruncatingTail;
		tf.font = [ident isEqualToString:@"type"] ? [NSFont systemFontOfSize:11] : monoFont(11);
	}
	auto v = n.value;
	if ([ident isEqualToString:@"key"]) {
		tf.stringValue = n.key ?: @"";
		tf.textColor = [NSColor labelColor];
	} else if ([ident isEqualToString:@"value"]) {
		tf.stringValue = v ? QStr(quill::jsonPreview(*v, 200)) : @"";
		NSColor *c = [NSColor labelColor];
		if (v) {
			switch (v->type) {
			case quill::JsonValue::Type::String: c = [NSColor systemRedColor]; break;
			case quill::JsonValue::Type::Number: c = [NSColor systemGreenColor]; break;
			case quill::JsonValue::Type::Bool: c = [NSColor systemBlueColor]; break;
			case quill::JsonValue::Type::Null: c = [NSColor systemGrayColor]; break;
			default: c = [NSColor secondaryLabelColor]; break;
			}
		}
		tf.textColor = c;
		tf.toolTip = tf.stringValue;
	} else {
		tf.stringValue = v ? QStr(quill::jsonTypeName(v->type)) : @"";
		tf.textColor = [NSColor tertiaryLabelColor];
	}
	return tf;
}

- (void)outlineViewSelectionDidChange:(NSNotification *)note {
	QJNode *n = [_outline itemAtRow:_outline.selectedRow];
	_pathLabel.stringValue = n.path ?: @"$";
}

- (void)goToNode:(id)sender {
	QJNode *n = [_outline itemAtRow:_outline.clickedRow];
	if (!n || !n.value) return;
	if (host().currentBufferID() != self.bufferID) return;
	intptr_t pos = static_cast<intptr_t>(n.value->offset);
	host().sci(SCI_GOTOPOS, static_cast<WPARAM>(pos));
	host().sci(SCI_SCROLLCARET);
	[mainWindow() makeFirstResponder:currentView().content];
}

- (BOOL)node:(QJNode *)n matches:(NSString *)needle {
	if ([n.key rangeOfString:needle options:NSCaseInsensitiveSearch].location != NSNotFound) return YES;
	auto v = n.value;
	if (v && (v->type == quill::JsonValue::Type::String || v->type == quill::JsonValue::Type::Number))
		return [QStr(v->text) rangeOfString:needle options:NSCaseInsensitiveSearch].location != NSNotFound;
	return NO;
}

- (QJNode *)findFrom:(QJNode *)n needle:(NSString *)needle after:(QJNode *)after found:(BOOL *)passed {
	if (*passed && n != after && [self node:n matches:needle]) return n;
	if (n == after) *passed = YES;
	for (QJNode *c in n.children) {
		QJNode *r = [self findFrom:c needle:needle after:after found:passed];
		if (r) return r;
	}
	return nil;
}

- (void)searchAction:(NSSearchField *)sender {
	NSString *needle = sender.stringValue;
	if (!needle.length || !self.root) return;
	QJNode *current = [_outline itemAtRow:_outline.selectedRow];
	BOOL passed = current == nil;
	QJNode *hit = [self findFrom:self.root needle:needle after:current found:&passed];
	if (!hit) {
		passed = YES;
		hit = [self findFrom:self.root needle:needle after:nil found:&passed];
	}
	if (!hit) {
		NSBeep();
		return;
	}
	// Expand ancestors: walk from the root.
	NSMutableArray *chain = [NSMutableArray array];
	std::function<BOOL(QJNode *)> walk = [&](QJNode *n) -> BOOL {
		if (n == hit) return YES;
		for (QJNode *c in n.children)
			if (walk(c)) {
				[chain insertObject:n atIndex:0];
				return YES;
			}
		return NO;
	};
	walk(self.root);
	for (QJNode *n in chain) [_outline expandItem:n];
	NSInteger row = [_outline rowForItem:hit];
	if (row >= 0) {
		[_outline selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)row] byExtendingSelection:NO];
		[_outline scrollRowToVisible:row];
	}
}

@end
