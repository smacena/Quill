// Hex Editor: view and edit the bytes of the current document.
// SPDX-License-Identifier: GPL-3.0-or-later
#include "PluginCommon.h"
#include "quill/TextTools.h"

using namespace qp;

QUILL_PLUGIN_EXPORTS(L"Hex Editor", L"Editor hexadecimal")

static const NSInteger kPerRow = 16;

@interface QHexController : NSWindowController <NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate, NSTextFieldDelegate>
- (void)showBuffer:(UINT_PTR)bufferID;
- (void)reloadIfShowing:(UINT_PTR)bufferID;
@property (nonatomic) UINT_PTR bufferID;
@end

static QHexController *gHex;

static void cmdView() {
	if (!gHex) gHex = [[QHexController alloc] init];
	[gHex showBuffer:host().currentBufferID()];
	[gHex showWindow:nil];
}

static void pluginInit() {}

static void pluginCommands(qp::Commands &c) {
	c.add(L"View in Hex", L"Ver em hexadecimal", cmdView, Commands::key('H', true, true, true));
}

static void pluginNotify(SCNotification *n) {
	if (!gHex || !gHex.window.isVisible) return;
	if (n->nmhdr.code == SCN_MODIFIED && (n->modificationType & (SC_MOD_INSERTTEXT | SC_MOD_DELETETEXT)))
		[gHex reloadIfShowing:host().currentBufferID()];
	else if (n->nmhdr.code == NPPN_FILECLOSED && n->nmhdr.idFrom == gHex.bufferID)
		[gHex close];
}

static LRESULT pluginMessage(UINT, WPARAM, LPARAM) {
	return TRUE;
}

@implementation QHexController {
	NSTableView *_table;
	NSData *_data;
	NSTextField *_info;
	NSTextField *_gotoField;
	NSTextField *_findField;
	NSInteger _selOffset;
	BOOL _editing;
}

- (instancetype)init {
	NSWindow *w = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 780, 560)
						  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable |
							    NSWindowStyleMaskMiniaturizable
						    backing:NSBackingStoreBuffered
						      defer:NO];
	w.releasedWhenClosed = NO;
	w.minSize = NSMakeSize(700, 300);
	if ((self = [super initWithWindow:w])) {
		w.delegate = self;
		[w setFrameAutosaveName:@"QuillHexWindow"];
		[self build];
		_selOffset = -1;
	}
	return self;
}

- (void)build {
	NSView *c = self.window.contentView;
	NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
	scroll.hasVerticalScroller = YES;
	scroll.hasHorizontalScroller = YES;
	scroll.translatesAutoresizingMaskIntoConstraints = NO;
	_table = [[NSTableView alloc] initWithFrame:NSZeroRect];
	NSFont *mono = monoFont(12);
	NSTableColumn *off = [[NSTableColumn alloc] initWithIdentifier:@"offset"];
	off.title = QTR(@"Offset", @"Posição");
	off.width = 80;
	[_table addTableColumn:off];
	for (NSInteger i = 0; i < kPerRow; i++) {
		NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:[NSString stringWithFormat:@"%ld", (long)i]];
		col.title = [NSString stringWithFormat:@"%02lX", (long)i];
		col.width = 24;
		col.minWidth = 22;
		col.headerCell.alignment = NSTextAlignmentCenter;
		[_table addTableColumn:col];
	}
	NSTableColumn *ascii = [[NSTableColumn alloc] initWithIdentifier:@"ascii"];
	ascii.title = @"ASCII";
	ascii.width = 150;
	[_table addTableColumn:ascii];
	_table.dataSource = self;
	_table.delegate = self;
	_table.rowHeight = 18;
	_table.usesAlternatingRowBackgroundColors = YES;
	_table.allowsColumnReordering = NO;
	_table.intercellSpacing = NSMakeSize(4, 1);
	_table.style = NSTableViewStylePlain;
	scroll.documentView = _table;
	(void)mono;

	_info = [NSTextField labelWithString:@""];
	_info.font = monoFont(11);
	_info.textColor = [NSColor secondaryLabelColor];
	_info.selectable = YES;
	_info.translatesAutoresizingMaskIntoConstraints = NO;
	_gotoField = [NSTextField textFieldWithString:@""];
	_gotoField.placeholderString = QTR(@"Go to offset (0x1F or 31)", @"Ir para posição (0x1F ou 31)");
	_gotoField.target = self;
	_gotoField.action = @selector(gotoOffset:);
	_gotoField.translatesAutoresizingMaskIntoConstraints = NO;
	_findField = [NSTextField textFieldWithString:@""];
	_findField.placeholderString = QTR(@"Find bytes (48 65 6C) or \"text\"", @"Localizar bytes (48 65 6C) ou \"texto\"");
	_findField.target = self;
	_findField.action = @selector(findBytes:);
	_findField.translatesAutoresizingMaskIntoConstraints = NO;
	NSButton *refresh = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"arrow.clockwise" accessibilityDescription:nil] target:self action:@selector(refresh:)];
	refresh.toolTip = QTR(@"Reload from the document", @"Recarregar do documento");
	refresh.translatesAutoresizingMaskIntoConstraints = NO;

	[c addSubview:scroll];
	[c addSubview:_info];
	[c addSubview:_gotoField];
	[c addSubview:_findField];
	[c addSubview:refresh];
	[NSLayoutConstraint activateConstraints:@[
		[_gotoField.topAnchor constraintEqualToAnchor:c.topAnchor constant:8],
		[_gotoField.leadingAnchor constraintEqualToAnchor:c.leadingAnchor constant:10],
		[_gotoField.widthAnchor constraintEqualToConstant:200],
		[_findField.centerYAnchor constraintEqualToAnchor:_gotoField.centerYAnchor],
		[_findField.leadingAnchor constraintEqualToAnchor:_gotoField.trailingAnchor constant:8],
		[_findField.trailingAnchor constraintEqualToAnchor:refresh.leadingAnchor constant:-8],
		[refresh.centerYAnchor constraintEqualToAnchor:_gotoField.centerYAnchor],
		[refresh.trailingAnchor constraintEqualToAnchor:c.trailingAnchor constant:-10],
		[scroll.topAnchor constraintEqualToAnchor:_gotoField.bottomAnchor constant:8],
		[scroll.leadingAnchor constraintEqualToAnchor:c.leadingAnchor],
		[scroll.trailingAnchor constraintEqualToAnchor:c.trailingAnchor],
		[scroll.bottomAnchor constraintEqualToAnchor:_info.topAnchor constant:-6],
		[_info.leadingAnchor constraintEqualToAnchor:c.leadingAnchor constant:10],
		[_info.trailingAnchor constraintEqualToAnchor:c.trailingAnchor constant:-10],
		[_info.bottomAnchor constraintEqualToAnchor:c.bottomAnchor constant:-6],
	]];
}

- (void)loadData {
	std::string bytes = host().bufferText(self.bufferID);
	_data = [NSData dataWithBytes:bytes.data() length:bytes.size()];
	NSString *path = QStr(host().pathFromBufferID(self.bufferID));
	self.window.title = [NSString stringWithFormat:QTR(@"Hex: %@ — %lu bytes (UTF-8 buffer)", @"Hex: %@ — %lu bytes (buffer UTF-8)"),
						       path.lastPathComponent ?: @"", (unsigned long)_data.length];
	[_table reloadData];
	[self updateInfo];
}

- (void)showBuffer:(UINT_PTR)bufferID {
	self.bufferID = bufferID;
	[self loadData];
}

- (void)reloadIfShowing:(UINT_PTR)bufferID {
	if (bufferID != self.bufferID || _editing) return;
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(loadData) object:nil];
	[self performSelector:@selector(loadData) withObject:nil afterDelay:0.3];
}

- (void)refresh:(id)sender {
	[self loadData];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv {
	return (NSInteger)((_data.length + kPerRow - 1) / kPerRow);
}

- (NSView *)tableView:(NSTableView *)tv viewForTableColumn:(NSTableColumn *)col row:(NSInteger)row {
	NSString *ident = col.identifier;
	NSTextField *tf = [tv makeViewWithIdentifier:ident owner:self];
	if (!tf) {
		tf = [NSTextField labelWithString:@""];
		tf.identifier = ident;
		tf.font = monoFont(12);
		tf.delegate = self;
	}
	const unsigned char *bytes = (const unsigned char *)_data.bytes;
	NSUInteger base = (NSUInteger)(row * kPerRow);
	if ([ident isEqualToString:@"offset"]) {
		tf.stringValue = [NSString stringWithFormat:@"%08lX", (unsigned long)base];
		tf.textColor = [NSColor secondaryLabelColor];
		tf.editable = NO;
	} else if ([ident isEqualToString:@"ascii"]) {
		NSMutableString *s = [NSMutableString string];
		for (NSUInteger i = base; i < MIN(base + kPerRow, _data.length); i++) {
			unsigned char b = bytes[i];
			[s appendFormat:@"%c", (b >= 0x20 && b < 0x7F) ? b : '.'];
		}
		tf.stringValue = s;
		tf.textColor = [NSColor labelColor];
		tf.editable = NO;
	} else {
		NSUInteger i = base + (NSUInteger)ident.integerValue;
		if (i < _data.length) {
			tf.stringValue = [NSString stringWithFormat:@"%02X", bytes[i]];
			tf.editable = YES;
			tf.tag = (NSInteger)i;
			tf.textColor = bytes[i] == 0 ? [NSColor tertiaryLabelColor] : [NSColor labelColor];
		} else {
			tf.stringValue = @"";
			tf.editable = NO;
		}
		tf.alignment = NSTextAlignmentCenter;
	}
	return tf;
}

- (void)controlTextDidBeginEditing:(NSNotification *)n {
	_editing = YES;
}

- (void)controlTextDidEndEditing:(NSNotification *)n {
	_editing = NO;
	NSTextField *tf = n.object;
	if (tf == _gotoField || tf == _findField) return;
	NSInteger offset = tf.tag;
	std::string parsed;
	if (!quill::parseHexBytes(QUtf8(tf.stringValue), parsed) || parsed.size() != 1) {
		NSBeep();
		[_table reloadData];
		return;
	}
	if (offset < 0 || (NSUInteger)offset >= _data.length) return;
	if (((const char *)_data.bytes)[offset] == parsed[0]) return;
	if (host().currentBufferID() != self.bufferID) {
		std::wstring path = host().pathFromBufferID(self.bufferID);
		host().npp(NPPM_SWITCHTOFILE, 0, (LPARAM)path.c_str());
	}
	if (host().currentBufferID() != self.bufferID) return;
	host().sci(SCI_BEGINUNDOACTION);
	host().sci(SCI_SETTARGETRANGE, static_cast<WPARAM>(offset), offset + 1);
	host().sci(SCI_REPLACETARGET, 1, (LPARAM)parsed.data());
	host().sci(SCI_ENDUNDOACTION);
	_selOffset = offset;
	[self loadData];
}

- (void)tableViewSelectionDidChange:(NSNotification *)n {
	NSInteger row = _table.selectedRow;
	if (row >= 0) _selOffset = row * kPerRow;
	[self updateInfo];
}

- (void)updateInfo {
	if (_selOffset < 0 || (NSUInteger)_selOffset >= _data.length) {
		_info.stringValue = [NSString stringWithFormat:QTR(@"%lu bytes. Double-click a byte to edit it.", @"%lu bytes. Clique duas vezes num byte para editá-lo."), (unsigned long)_data.length];
		return;
	}
	const unsigned char *b = (const unsigned char *)_data.bytes + _selOffset;
	NSUInteger avail = _data.length - (NSUInteger)_selOffset;
	uint16_t u16 = avail >= 2 ? (uint16_t)(b[0] | b[1] << 8) : 0;
	uint32_t u32 = avail >= 4 ? (uint32_t)(b[0] | b[1] << 8 | b[2] << 16 | (uint32_t)b[3] << 24) : 0;
	_info.stringValue = [NSString stringWithFormat:@"@ 0x%lX (%ld)   u8 %u   i8 %d   u16le %u   u32le %u",
						       (long)_selOffset, (long)_selOffset, b[0], (signed char)b[0], u16, u32];
}

- (void)selectOffset:(NSInteger)offset length:(NSInteger)length {
	if (offset < 0 || (NSUInteger)offset >= _data.length) {
		NSBeep();
		return;
	}
	NSInteger row = offset / kPerRow;
	[_table selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)row] byExtendingSelection:NO];
	[_table scrollRowToVisible:row];
	_selOffset = offset;
	[self updateInfo];
	// Also select the bytes in the editor.
	if (host().currentBufferID() == self.bufferID) {
		host().sci(SCI_SETSEL, static_cast<WPARAM>(offset), offset + MAX((NSInteger)1, length));
		host().sci(SCI_SCROLLCARET);
	}
}

- (void)gotoOffset:(NSTextField *)sender {
	NSString *s = [sender.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	unsigned long long v = 0;
	if ([s.lowercaseString hasPrefix:@"0x"]) [[NSScanner scannerWithString:s] scanHexLongLong:&v];
	else v = (unsigned long long)MAX(0LL, s.longLongValue);
	[self selectOffset:(NSInteger)v length:1];
}

- (void)findBytes:(NSTextField *)sender {
	NSString *s = sender.stringValue;
	std::string needle;
	if (s.length >= 2 && [s hasPrefix:@"\""] && [s hasSuffix:@"\""]) needle = QUtf8([s substringWithRange:NSMakeRange(1, s.length - 2)]);
	else if (!quill::parseHexBytes(QUtf8(s), needle)) needle = QUtf8(s);
	if (needle.empty()) return;
	NSData *n = [NSData dataWithBytes:needle.data() length:needle.size()];
	NSUInteger from = _selOffset >= 0 ? (NSUInteger)_selOffset + 1 : 0;
	if (from >= _data.length) from = 0;
	NSRange r = [_data rangeOfData:n options:0 range:NSMakeRange(from, _data.length - from)];
	if (r.location == NSNotFound && from > 0) r = [_data rangeOfData:n options:0 range:NSMakeRange(0, _data.length)];
	if (r.location == NSNotFound) {
		NSBeep();
		return;
	}
	[self selectOffset:(NSInteger)r.location length:(NSInteger)r.length];
}

@end
