// Explorer: folder tree panel with file operations.
// SPDX-License-Identifier: GPL-3.0-or-later
#include "PluginCommon.h"

using namespace qp;

QUILL_PLUGIN_EXPORTS(L"Explorer", L"Explorador")

@interface QFSNode : NSObject
@property (nonatomic, copy) NSString *path;
@property (nonatomic) BOOL isDirectory;
@property (nonatomic, strong) NSArray<QFSNode *> *children; // nil = not loaded
@end
@implementation QFSNode
@end

@interface QExplorerPanel : NSView <NSOutlineViewDataSource, NSOutlineViewDelegate, NSMenuDelegate, NSSearchFieldDelegate>
@property (nonatomic, strong) NSOutlineView *outline;
@property (nonatomic, strong) NSPopUpButton *rootPopup;
@property (nonatomic, strong) NSSearchField *filter;
@property (nonatomic, strong) QFSNode *root;
- (void)openFolder:(NSString *)path;
- (void)reloadPreservingState;
- (void)revealPath:(NSString *)path;
@end

static QExplorerPanel *gPanel;
static Panel gDock;
static int gShowIndex = 0, gHiddenIndex = 0;

static NSUserDefaults *defaults() {
	return [NSUserDefaults standardUserDefaults];
}

static BOOL showHidden() {
	return [defaults() boolForKey:@"Explorer.showHidden"];
}

static void ensurePanel() {
	if (gPanel) return;
	gPanel = [[QExplorerPanel alloc] initWithFrame:NSMakeRect(0, 0, 260, 500)];
	gDock.registerIn(gPanel, host().tr(L"Explorer", L"Explorador"), L"Explorer.dylib", gShowIndex, DWS_DF_CONT_LEFT);
	NSString *last = [defaults() stringForKey:@"Explorer.root"];
	BOOL isDir = NO;
	if (last && [[NSFileManager defaultManager] fileExistsAtPath:last isDirectory:&isDir] && isDir) [gPanel openFolder:last];
}

static void showPanel() {
	ensurePanel();
	gDock.show();
	gCommands.setChecked(gShowIndex, true);
}

static void cmdShow() {
	ensurePanel();
	if (gDock.visible()) {
		gDock.hide();
		gCommands.setChecked(gShowIndex, false);
	} else {
		if (!gPanel.root) {
			NSString *dir = QStr(host().currentDirectory());
			[gPanel openFolder:dir.length ? dir : NSHomeDirectory()];
		}
		showPanel();
	}
}

static void cmdOpenFolder() {
	NSOpenPanel *p = [NSOpenPanel openPanel];
	p.canChooseDirectories = YES;
	p.canChooseFiles = NO;
	if ([p runModal] != NSModalResponseOK) return;
	ensurePanel();
	[gPanel openFolder:p.URL.path];
	showPanel();
}

static void cmdReveal() {
	NSString *path = QStr(host().currentPath());
	if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
		NSBeep();
		return;
	}
	ensurePanel();
	if (!gPanel.root || ![path hasPrefix:[gPanel.root.path stringByAppendingString:@"/"]]) [gPanel openFolder:path.stringByDeletingLastPathComponent];
	showPanel();
	[gPanel revealPath:path];
}

static void cmdRefresh() {
	if (gPanel) [gPanel reloadPreservingState];
}

static void cmdHidden() {
	BOOL v = !showHidden();
	[defaults() setBool:v forKey:@"Explorer.showHidden"];
	gCommands.setChecked(gHiddenIndex, v);
	cmdRefresh();
}

static void pluginInit() {}

static void pluginCommands(qp::Commands &c) {
	gShowIndex = c.add(L"Show Explorer", L"Mostrar Explorador", cmdShow, Commands::key('E', true, false, true));
	c.add(L"Open Folder…", L"Abrir pasta…", cmdOpenFolder);
	c.add(L"Go to Current File", L"Ir para o arquivo atual", cmdReveal, Commands::key('J', true, false, true));
	c.add(L"Refresh", L"Atualizar", cmdRefresh);
	c.separator();
	gHiddenIndex = c.add(L"Show Hidden Files", L"Mostrar arquivos ocultos", cmdHidden, nullptr, showHidden());
}

static void pluginNotify(SCNotification *n) {
	switch (n->nmhdr.code) {
	case NPPN_READY:
		if ([defaults() boolForKey:@"Explorer.visible"]) {
			ensurePanel();
			if (gPanel.root) showPanel();
		}
		[[NSNotificationCenter defaultCenter] addObserverForName:NSApplicationDidBecomeActiveNotification
								  object:nil
								   queue:nil
							      usingBlock:^(NSNotification *note) {
								      if (gPanel && gDock.visible()) [gPanel reloadPreservingState];
							      }];
		break;
	case NPPN_FILESAVED:
	case NPPN_FILERENAMED:
		if (gPanel && gDock.visible()) [gPanel reloadPreservingState];
		break;
	case NPPN_BEFORESHUTDOWN:
		[defaults() setBool:(gPanel && gDock.visible()) forKey:@"Explorer.visible"];
		break;
	case QUILLN_PANELCLOSED:
		if (gPanel && n->nmhdr.hwndFrom == (__bridge void *)gPanel) gCommands.setChecked(gShowIndex, false);
		break;
	default:
		break;
	}
}

static LRESULT pluginMessage(UINT msg, WPARAM w, LPARAM l) {
	if (msg == NPPM_MSGTOPLUGIN && l) {
		CommunicationInfo *ci = (CommunicationInfo *)l;
		if (ci->internalMsg == QUILL_EXPLORER_OPENFOLDER && ci->info) {
			ensurePanel();
			[gPanel openFolder:QStr(std::wstring((const wchar_t *)ci->info))];
			showPanel();
			return TRUE;
		}
	}
	return TRUE;
}

// ---- Panel ----------------------------------------------------------------------------

@implementation QExplorerPanel

- (instancetype)initWithFrame:(NSRect)frame {
	if ((self = [super initWithFrame:frame])) {
		_rootPopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
		_rootPopup.controlSize = NSControlSizeSmall;
		_rootPopup.font = [NSFont systemFontOfSize:11];
		_rootPopup.target = self;
		_rootPopup.action = @selector(rootChosen:);
		_rootPopup.translatesAutoresizingMaskIntoConstraints = NO;
		NSButton *open = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"folder.badge.plus" accessibilityDescription:nil]
						    target:self
						    action:@selector(openAction:)];
		open.toolTip = QTR(@"Open folder…", @"Abrir pasta…");
		NSButton *up = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"arrow.up" accessibilityDescription:nil] target:self action:@selector(upAction:)];
		up.toolTip = QTR(@"Parent folder", @"Pasta acima");
		NSButton *reveal = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"scope" accessibilityDescription:nil] target:self action:@selector(revealAction:)];
		reveal.toolTip = QTR(@"Go to current file", @"Ir para o arquivo atual");
		NSButton *refresh = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"arrow.clockwise" accessibilityDescription:nil] target:self action:@selector(refreshAction:)];
		refresh.toolTip = QTR(@"Refresh", @"Atualizar");
		for (NSButton *b in @[ open, up, reveal, refresh ]) {
			b.bezelStyle = NSBezelStyleRecessed;
			b.translatesAutoresizingMaskIntoConstraints = NO;
		}
		NSStackView *buttons = [NSStackView stackViewWithViews:@[ open, up, reveal, refresh ]];
		buttons.spacing = 2;
		buttons.translatesAutoresizingMaskIntoConstraints = NO;

		NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
		scroll.hasVerticalScroller = YES;
		scroll.autohidesScrollers = YES;
		scroll.translatesAutoresizingMaskIntoConstraints = NO;
		_outline = [[NSOutlineView alloc] initWithFrame:NSZeroRect];
		NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:@"name"];
		col.resizingMask = NSTableColumnAutoresizingMask;
		[_outline addTableColumn:col];
		_outline.outlineTableColumn = col;
		_outline.headerView = nil;
		_outline.dataSource = self;
		_outline.delegate = self;
		_outline.style = NSTableViewStyleSourceList;
		_outline.rowSizeStyle = NSTableViewRowSizeStyleSmall;
		_outline.target = self;
		_outline.doubleAction = @selector(openSelected:);
		_outline.allowsMultipleSelection = YES;
		_outline.autosaveExpandedItems = NO;
		[_outline registerForDraggedTypes:@[ NSPasteboardTypeFileURL ]];
		[_outline setDraggingSourceOperationMask:NSDragOperationCopy | NSDragOperationMove forLocal:NO];
		NSMenu *menu = [[NSMenu alloc] init];
		menu.delegate = self;
		_outline.menu = menu;
		scroll.documentView = _outline;

		_filter = [[NSSearchField alloc] initWithFrame:NSZeroRect];
		_filter.placeholderString = QTR(@"Filter (e.g. *.c)", @"Filtrar (ex.: *.c)");
		_filter.controlSize = NSControlSizeSmall;
		_filter.delegate = self;
		_filter.translatesAutoresizingMaskIntoConstraints = NO;

		[self addSubview:_rootPopup];
		[self addSubview:buttons];
		[self addSubview:scroll];
		[self addSubview:_filter];
		[NSLayoutConstraint activateConstraints:@[
			[_rootPopup.topAnchor constraintEqualToAnchor:self.topAnchor constant:4],
			[_rootPopup.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:4],
			[_rootPopup.trailingAnchor constraintEqualToAnchor:buttons.leadingAnchor constant:-4],
			[buttons.centerYAnchor constraintEqualToAnchor:_rootPopup.centerYAnchor],
			[buttons.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-4],
			[scroll.topAnchor constraintEqualToAnchor:_rootPopup.bottomAnchor constant:4],
			[scroll.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
			[scroll.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
			[scroll.bottomAnchor constraintEqualToAnchor:_filter.topAnchor constant:-4],
			[_filter.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:4],
			[_filter.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-4],
			[_filter.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-4],
		]];
		[_rootPopup setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
	}
	return self;
}

- (BOOL)isFlipped {
	return YES;
}

- (void)rebuildRootPopup {
	[_rootPopup removeAllItems];
	NSArray *recent = [defaults() stringArrayForKey:@"Explorer.recentRoots"] ?: @[];
	for (NSString *p in recent) {
		[_rootPopup addItemWithTitle:p.lastPathComponent.length ? p.lastPathComponent : p];
		_rootPopup.lastItem.representedObject = p;
		_rootPopup.lastItem.toolTip = p;
		NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:p];
		icon.size = NSMakeSize(14, 14);
		_rootPopup.lastItem.image = icon;
	}
	[_rootPopup selectItemAtIndex:0];
}

- (void)openFolder:(NSString *)path {
	if (!path.length) return;
	path = path.stringByStandardizingPath;
	QFSNode *root = [[QFSNode alloc] init];
	root.path = path;
	root.isDirectory = YES;
	self.root = root;
	NSMutableArray *recent = [[defaults() stringArrayForKey:@"Explorer.recentRoots"] mutableCopy] ?: [NSMutableArray array];
	[recent removeObject:path];
	[recent insertObject:path atIndex:0];
	while (recent.count > 10) [recent removeLastObject];
	[defaults() setObject:recent forKey:@"Explorer.recentRoots"];
	[defaults() setObject:path forKey:@"Explorer.root"];
	[self rebuildRootPopup];
	[_outline reloadData];
}

- (NSArray<QFSNode *> *)childrenOf:(QFSNode *)node {
	if (node.children) return node.children;
	NSFileManager *fm = [NSFileManager defaultManager];
	NSDirectoryEnumerationOptions opts = showHidden() ? 0 : NSDirectoryEnumerationSkipsHiddenFiles;
	NSArray<NSURL *> *urls = [fm contentsOfDirectoryAtURL:[NSURL fileURLWithPath:node.path]
				   includingPropertiesForKeys:@[ NSURLIsDirectoryKey, NSURLIsPackageKey ]
						      options:opts
							error:nil];
	NSString *pattern = _filter.stringValue;
	NSMutableArray *dirs = [NSMutableArray array], *files = [NSMutableArray array];
	for (NSURL *u in urls) {
		NSNumber *isDir = nil, *isPkg = nil;
		[u getResourceValue:&isDir forKey:NSURLIsDirectoryKey error:nil];
		[u getResourceValue:&isPkg forKey:NSURLIsPackageKey error:nil];
		QFSNode *c = [[QFSNode alloc] init];
		c.path = u.path;
		c.isDirectory = isDir.boolValue && !isPkg.boolValue;
		if (!c.isDirectory && pattern.length) {
			NSString *glob = [pattern containsString:@"*"] || [pattern containsString:@"?"] ? pattern : [NSString stringWithFormat:@"*%@*", pattern];
			NSPredicate *pred = [NSPredicate predicateWithFormat:@"SELF LIKE[cd] %@", glob];
			if (![pred evaluateWithObject:u.lastPathComponent]) continue;
		}
		[(c.isDirectory ? dirs : files) addObject:c];
	}
	NSComparator byName = ^NSComparisonResult(QFSNode *a, QFSNode *b) {
		return [a.path.lastPathComponent localizedStandardCompare:b.path.lastPathComponent];
	};
	[dirs sortUsingComparator:byName];
	[files sortUsingComparator:byName];
	node.children = [dirs arrayByAddingObjectsFromArray:files];
	return node.children;
}

- (void)collectExpanded:(QFSNode *)node into:(NSMutableSet *)set {
	if (!node.children) return;
	for (QFSNode *c in node.children) {
		if (c.isDirectory && [_outline isItemExpanded:c]) {
			[set addObject:c.path];
			[self collectExpanded:c into:set];
		}
	}
}

- (void)expandPaths:(NSSet *)paths under:(QFSNode *)node {
	for (QFSNode *c in [self childrenOf:node]) {
		if (c.isDirectory && [paths containsObject:c.path]) {
			[_outline expandItem:c];
			[self expandPaths:paths under:c];
		}
	}
}

- (void)reloadPreservingState {
	if (!self.root) return;
	NSMutableSet *expanded = [NSMutableSet set];
	[self collectExpanded:self.root into:expanded];
	NSMutableSet *selected = [NSMutableSet set];
	[_outline.selectedRowIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
		QFSNode *n = [self->_outline itemAtRow:(NSInteger)idx];
		if (n.path) [selected addObject:n.path];
	}];
	self.root.children = nil;
	[_outline reloadData];
	[self expandPaths:expanded under:self.root];
	NSMutableIndexSet *rows = [NSMutableIndexSet indexSet];
	for (NSInteger r = 0; r < _outline.numberOfRows; r++)
		if ([selected containsObject:((QFSNode *)[_outline itemAtRow:r]).path]) [rows addIndex:(NSUInteger)r];
	[_outline selectRowIndexes:rows byExtendingSelection:NO];
}

- (void)revealPath:(NSString *)path {
	if (!self.root || ![path hasPrefix:self.root.path]) return;
	NSString *rel = [path substringFromIndex:self.root.path.length];
	NSArray *parts = [rel componentsSeparatedByString:@"/"];
	QFSNode *node = self.root;
	QFSNode *found = nil;
	for (NSString *part in parts) {
		if (!part.length) continue;
		found = nil;
		for (QFSNode *c in [self childrenOf:node])
			if ([c.path.lastPathComponent isEqualToString:part]) found = c;
		if (!found) break;
		if (found.isDirectory) [_outline expandItem:found];
		node = found;
	}
	if (found) {
		NSInteger row = [_outline rowForItem:found];
		if (row >= 0) {
			[_outline selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)row] byExtendingSelection:NO];
			[_outline scrollRowToVisible:row];
		}
	}
}

// ---- Outline data ------------------------------------------------------------------

- (NSInteger)outlineView:(NSOutlineView *)ov numberOfChildrenOfItem:(id)item {
	QFSNode *n = item ?: self.root;
	if (!n) return 0;
	return (NSInteger)[self childrenOf:n].count;
}

- (id)outlineView:(NSOutlineView *)ov child:(NSInteger)index ofItem:(id)item {
	QFSNode *n = item ?: self.root;
	return [self childrenOf:n][(NSUInteger)index];
}

- (BOOL)outlineView:(NSOutlineView *)ov isItemExpandable:(id)item {
	return ((QFSNode *)item).isDirectory;
}

- (NSView *)outlineView:(NSOutlineView *)ov viewForTableColumn:(NSTableColumn *)col item:(id)item {
	QFSNode *n = item;
	NSTableCellView *cell = [ov makeViewWithIdentifier:@"fs" owner:self];
	if (!cell) {
		cell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 200, 18)];
		cell.identifier = @"fs";
		NSImageView *iv = [[NSImageView alloc] initWithFrame:NSMakeRect(0, 1, 16, 16)];
		NSTextField *tf = [NSTextField labelWithString:@""];
		tf.frame = NSMakeRect(20, 0, 180, 18);
		tf.autoresizingMask = NSViewWidthSizable;
		tf.lineBreakMode = NSLineBreakByTruncatingMiddle;
		tf.font = [NSFont systemFontOfSize:12];
		[cell addSubview:iv];
		[cell addSubview:tf];
		cell.imageView = iv;
		cell.textField = tf;
	}
	cell.textField.stringValue = n.path.lastPathComponent ?: @"";
	cell.textField.toolTip = n.path;
	NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:n.path];
	icon.size = NSMakeSize(16, 16);
	cell.imageView.image = icon;
	return cell;
}

- (id<NSPasteboardWriting>)outlineView:(NSOutlineView *)ov pasteboardWriterForItem:(id)item {
	return [NSURL fileURLWithPath:((QFSNode *)item).path];
}

- (NSDragOperation)outlineView:(NSOutlineView *)ov validateDrop:(id<NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(NSInteger)index {
	QFSNode *target = item ?: self.root;
	if (!target.isDirectory) return NSDragOperationNone;
	[ov setDropItem:item dropChildIndex:NSOutlineViewDropOnItemIndex];
	return (info.draggingSourceOperationMask & NSDragOperationMove) && info.draggingSource == ov ? NSDragOperationMove : NSDragOperationCopy;
}

- (BOOL)outlineView:(NSOutlineView *)ov acceptDrop:(id<NSDraggingInfo>)info item:(id)item childIndex:(NSInteger)index {
	QFSNode *target = item ?: self.root;
	NSArray<NSURL *> *urls = [info.draggingPasteboard readObjectsForClasses:@[ [NSURL class] ] options:@{NSPasteboardURLReadingFileURLsOnlyKey : @YES}];
	BOOL move = info.draggingSource == ov;
	for (NSURL *u in urls) {
		NSString *dest = [target.path stringByAppendingPathComponent:u.lastPathComponent];
		if ([dest isEqualToString:u.path]) continue;
		NSError *err = nil;
		BOOL ok = move ? [[NSFileManager defaultManager] moveItemAtPath:u.path toPath:dest error:&err]
			       : [[NSFileManager defaultManager] copyItemAtPath:u.path toPath:dest error:&err];
		if (!ok) [[NSAlert alertWithError:err] runModal];
	}
	[self reloadPreservingState];
	return YES;
}

// ---- Actions --------------------------------------------------------------------------------

- (NSArray<QFSNode *> *)targets {
	NSInteger clicked = _outline.clickedRow;
	NSIndexSet *sel = _outline.selectedRowIndexes;
	if (clicked >= 0 && ![sel containsIndex:(NSUInteger)clicked]) sel = [NSIndexSet indexSetWithIndex:(NSUInteger)clicked];
	NSMutableArray *nodes = [NSMutableArray array];
	[sel enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
		QFSNode *n = [self->_outline itemAtRow:(NSInteger)idx];
		if (n) [nodes addObject:n];
	}];
	return nodes;
}

- (NSString *)targetFolder {
	QFSNode *n = [self targets].firstObject;
	if (!n) return self.root.path;
	return n.isDirectory ? n.path : n.path.stringByDeletingLastPathComponent;
}

- (void)openSelected:(id)sender {
	for (QFSNode *n in [self targets]) {
		if (n.isDirectory) {
			if ([_outline isItemExpanded:n]) [_outline collapseItem:n];
			else [_outline expandItem:n];
		} else {
			host().openFile(QWide(n.path));
		}
	}
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
	[menu removeAllItems];
	NSArray *t = [self targets];
	auto add = ^(NSString *title, SEL sel) {
		NSMenuItem *mi = [menu addItemWithTitle:title action:sel keyEquivalent:@""];
		mi.target = self;
	};
	if (t.count) {
		add(QTR(@"Open", @"Abrir"), @selector(openSelected:));
		add(QTR(@"Open with Default App", @"Abrir com o app padrão"), @selector(openExternal:));
		add(QTR(@"Reveal in Finder", @"Mostrar no Finder"), @selector(revealInFinder:));
		[menu addItem:[NSMenuItem separatorItem]];
	}
	add(QTR(@"New File…", @"Novo arquivo…"), @selector(newFile:));
	add(QTR(@"New Folder…", @"Nova pasta…"), @selector(newFolder:));
	if (t.count == 1) add(QTR(@"Rename…", @"Renomear…"), @selector(renameItem:));
	if (t.count) add(QTR(@"Move to Trash", @"Mover para o Lixo"), @selector(trashItems:));
	[menu addItem:[NSMenuItem separatorItem]];
	if (t.count) add(QTR(@"Copy Path", @"Copiar caminho"), @selector(copyPath:));
	add(QTR(@"Find in Folder…", @"Localizar na pasta…"), @selector(findInFolder:));
	add(QTR(@"Open in Terminal", @"Abrir no Terminal"), @selector(openTerminal:));
	NSMenuItem *rootItem = [menu addItemWithTitle:QTR(@"Set as Root Folder", @"Definir como pasta raiz") action:@selector(setAsRoot:) keyEquivalent:@""];
	rootItem.target = self;
}

- (void)openExternal:(id)sender {
	for (QFSNode *n in [self targets]) [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:n.path]];
}

- (void)revealInFinder:(id)sender {
	NSMutableArray *urls = [NSMutableArray array];
	for (QFSNode *n in [self targets]) [urls addObject:[NSURL fileURLWithPath:n.path]];
	[[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:urls];
}

- (NSString *)askName:(NSString *)title initial:(NSString *)initial {
	NSAlert *a = [[NSAlert alloc] init];
	a.messageText = title;
	NSTextField *f = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 280, 24)];
	f.stringValue = initial ?: @"";
	a.accessoryView = f;
	[a addButtonWithTitle:@"OK"];
	[a addButtonWithTitle:QTR(@"Cancel", @"Cancelar")];
	a.window.initialFirstResponder = f;
	if ([a runModal] != NSAlertFirstButtonReturn) return nil;
	NSString *name = [f.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	return name.length && ![name containsString:@"/"] ? name : nil;
}

- (void)newFile:(id)sender {
	NSString *name = [self askName:QTR(@"New file name", @"Nome do novo arquivo") initial:@"untitled.txt"];
	if (!name) return;
	NSString *path = [[self targetFolder] stringByAppendingPathComponent:name];
	if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
		NSBeep();
		return;
	}
	[[NSData data] writeToFile:path atomically:YES];
	[self reloadPreservingState];
	[self revealPath:path];
	host().openFile(QWide(path));
}

- (void)newFolder:(id)sender {
	NSString *name = [self askName:QTR(@"New folder name", @"Nome da nova pasta") initial:QTR(@"New Folder", @"Nova pasta")];
	if (!name) return;
	NSString *path = [[self targetFolder] stringByAppendingPathComponent:name];
	NSError *err = nil;
	if (![[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:&err]) {
		[[NSAlert alertWithError:err] runModal];
		return;
	}
	[self reloadPreservingState];
	[self revealPath:path];
}

- (void)renameItem:(id)sender {
	QFSNode *n = [self targets].firstObject;
	if (!n) return;
	NSString *name = [self askName:QTR(@"Rename", @"Renomear") initial:n.path.lastPathComponent];
	if (!name) return;
	NSString *dest = [n.path.stringByDeletingLastPathComponent stringByAppendingPathComponent:name];
	NSError *err = nil;
	if (![[NSFileManager defaultManager] moveItemAtPath:n.path toPath:dest error:&err]) {
		[[NSAlert alertWithError:err] runModal];
		return;
	}
	[self reloadPreservingState];
	[self revealPath:dest];
}

- (void)trashItems:(id)sender {
	NSArray<QFSNode *> *t = [self targets];
	if (!t.count) return;
	NSAlert *a = [[NSAlert alloc] init];
	a.messageText = t.count == 1 ? [NSString stringWithFormat:QTR(@"Move \"%@\" to the Trash?", @"Mover \"%@\" para o Lixo?"), t[0].path.lastPathComponent]
				     : [NSString stringWithFormat:QTR(@"Move %lu items to the Trash?", @"Mover %lu itens para o Lixo?"), (unsigned long)t.count];
	[a addButtonWithTitle:QTR(@"Move to Trash", @"Mover para o Lixo")];
	[a addButtonWithTitle:QTR(@"Cancel", @"Cancelar")];
	if ([a runModal] != NSAlertFirstButtonReturn) return;
	NSMutableArray *urls = [NSMutableArray array];
	for (QFSNode *n in t) [urls addObject:[NSURL fileURLWithPath:n.path]];
	[[NSWorkspace sharedWorkspace] recycleURLs:urls
				 completionHandler:^(NSDictionary *newURLs, NSError *error) {
					 dispatch_async(dispatch_get_main_queue(), ^{
						 [self reloadPreservingState];
					 });
				 }];
}

- (void)copyPath:(id)sender {
	NSMutableArray *paths = [NSMutableArray array];
	for (QFSNode *n in [self targets]) [paths addObject:n.path];
	[[NSPasteboard generalPasteboard] clearContents];
	[[NSPasteboard generalPasteboard] setString:[paths componentsJoinedByString:@"\n"] forType:NSPasteboardTypeString];
}

- (void)findInFolder:(id)sender {
	std::wstring dir = QWide([self targetFolder]);
	host().npp(NPPM_LAUNCHFINDINFILESDLG, (WPARAM)dir.c_str(), 0);
}

- (void)openTerminal:(id)sender {
	NSURL *terminal = [[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier:@"com.apple.Terminal"];
	if (!terminal) return;
	[[NSWorkspace sharedWorkspace] openURLs:@[ [NSURL fileURLWithPath:[self targetFolder]] ]
			   withApplicationAtURL:terminal
				  configuration:[NSWorkspaceOpenConfiguration configuration]
			      completionHandler:nil];
}

- (void)setAsRoot:(id)sender {
	[self openFolder:[self targetFolder]];
}

- (void)rootChosen:(NSPopUpButton *)sender {
	NSString *p = sender.selectedItem.representedObject;
	if (p) [self openFolder:p];
}

- (void)openAction:(id)sender {
	cmdOpenFolder();
}

- (void)upAction:(id)sender {
	if (self.root && ![self.root.path isEqualToString:@"/"]) [self openFolder:self.root.path.stringByDeletingLastPathComponent];
}

- (void)revealAction:(id)sender {
	cmdReveal();
}

- (void)refreshAction:(id)sender {
	[self reloadPreservingState];
}

- (void)controlTextDidChange:(NSNotification *)note {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reloadPreservingState) object:nil];
	[self performSelector:@selector(reloadPreservingState) withObject:nil afterDelay:0.3];
}

@end
