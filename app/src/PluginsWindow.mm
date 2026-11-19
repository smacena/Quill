// SPDX-License-Identifier: GPL-3.0-or-later
#import "PluginsWindow.h"
#import "Localization.h"
#import "PluginManager.h"
#include <sys/xattr.h>

@implementation QPluginsWindowController {
	NSTableView *_table;
	NSTextField *_note;
}

- (instancetype)init {
	NSWindow *w = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 720, 380)
						  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable
						    backing:NSBackingStoreBuffered
						      defer:YES];
	w.title = T(@"Plugins", @"Plugins");
	w.minSize = NSMakeSize(520, 260);
	if ((self = [super initWithWindow:w])) {
		[self build];
		[w center];
	}
	return self;
}

- (void)build {
	NSView *c = self.window.contentView;
	NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(16, 56, 688, 290)];
	scroll.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
	scroll.hasVerticalScroller = YES;
	scroll.borderType = NSBezelBorder;
	_table = [[NSTableView alloc] initWithFrame:scroll.bounds];
	NSArray *cols = @[
		@[ @"enabled", T(@"On", @"Ativo"), @40 ], @[ @"name", T(@"Name", @"Nome"), @150 ], @[ @"file", T(@"File", @"Arquivo"), @150 ],
		@[ @"where", T(@"Location", @"Local"), @80 ], @[ @"status", T(@"Status", @"Situação"), @250 ]
	];
	for (NSArray *def in cols) {
		NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:def[0]];
		col.title = def[1];
		col.width = [def[2] doubleValue];
		[_table addTableColumn:col];
	}
	_table.dataSource = self;
	_table.delegate = self;
	_table.usesAlternatingRowBackgroundColors = YES;
	scroll.documentView = _table;
	[c addSubview:scroll];

	_note = [NSTextField labelWithString:T(@"Changes take effect after restarting Quill. Plugins are .dylib files in the plugins folder.",
					       @"As mudanças valem depois de reiniciar o Quill. Plugins são arquivos .dylib na pasta de plugins.")];
	_note.textColor = [NSColor secondaryLabelColor];
	_note.font = [NSFont systemFontOfSize:11];
	_note.frame = NSMakeRect(16, 352, 688, 18);
	_note.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
	[c addSubview:_note];

	NSButton *install = [NSButton buttonWithTitle:T(@"Install Plugin…", @"Instalar plugin…") target:self action:@selector(install:)];
	NSButton *folder = [NSButton buttonWithTitle:T(@"Open Plugins Folder", @"Abrir pasta de plugins") target:self action:@selector(openFolder:)];
	NSButton *remove = [NSButton buttonWithTitle:T(@"Remove", @"Remover") target:self action:@selector(removePlugin:)];
	install.frame = NSMakeRect(16, 14, 150, 30);
	folder.frame = NSMakeRect(172, 14, 190, 30);
	remove.frame = NSMakeRect(368, 14, 110, 30);
	for (NSButton *b in @[ install, folder, remove ]) [c addSubview:b];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv {
	return (NSInteger)[QPluginManager shared].plugins.count;
}

- (NSView *)tableView:(NSTableView *)tv viewForTableColumn:(NSTableColumn *)col row:(NSInteger)row {
	QPluginInfo *p = [QPluginManager shared].plugins[(NSUInteger)row];
	NSString *ident = col.identifier;
	if ([ident isEqualToString:@"enabled"]) {
		NSButton *b = [NSButton checkboxWithTitle:@"" target:self action:@selector(toggle:)];
		b.tag = row;
		b.state = ![[QPluginManager disabledPluginFiles] containsObject:p.fileName];
		return b;
	}
	NSString *text = @"";
	if ([ident isEqualToString:@"name"]) text = p.name;
	else if ([ident isEqualToString:@"file"]) text = p.fileName;
	else if ([ident isEqualToString:@"where"]) text = p.builtIn ? T(@"Built-in", @"Embutido") : T(@"User", @"Usuário");
	else if ([ident isEqualToString:@"status"]) {
		if (p.loadError) text = p.loadError;
		else if (!p.enabled) text = T(@"Disabled", @"Desativado");
		else text = T(@"Loaded", @"Carregado");
	}
	NSTextField *tf = [NSTextField labelWithString:text ?: @""];
	tf.lineBreakMode = NSLineBreakByTruncatingTail;
	tf.toolTip = [ident isEqualToString:@"status"] ? text : p.path;
	if ([ident isEqualToString:@"status"] && p.loadError) tf.textColor = [NSColor systemRedColor];
	return tf;
}

- (void)toggle:(NSButton *)sender {
	QPluginInfo *p = [QPluginManager shared].plugins[(NSUInteger)sender.tag];
	[QPluginManager setPluginFile:p.fileName disabled:sender.state != NSControlStateValueOn];
}

- (void)install:(id)sender {
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	panel.allowedFileTypes = @[ @"dylib" ];
	panel.allowsMultipleSelection = YES;
	if ([panel runModal] != NSModalResponseOK) return;
	NSString *dir = [QPluginManager userPluginDirectory];
	for (NSURL *url in panel.URLs) {
		NSString *dest = [dir stringByAppendingPathComponent:url.lastPathComponent];
		[[NSFileManager defaultManager] removeItemAtPath:dest error:nil];
		NSError *err = nil;
		if (![[NSFileManager defaultManager] copyItemAtPath:url.path toPath:dest error:&err]) {
			[[NSAlert alertWithError:err] runModal];
			continue;
		}
		// Files downloaded from the internet are quarantined; clear it so dlopen works.
		removexattr(dest.fileSystemRepresentation, "com.apple.quarantine", 0);
	}
	NSAlert *a = [[NSAlert alloc] init];
	a.messageText = T(@"Plugin installed", @"Plugin instalado");
	a.informativeText = T(@"Restart Quill to load it.", @"Reinicie o Quill para carregá-lo.");
	[a runModal];
}

- (void)openFolder:(id)sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:[QPluginManager userPluginDirectory]]];
}

- (void)removePlugin:(id)sender {
	NSInteger row = _table.selectedRow;
	if (row < 0) return;
	QPluginInfo *p = [QPluginManager shared].plugins[(NSUInteger)row];
	if (p.builtIn) {
		NSAlert *a = [[NSAlert alloc] init];
		a.messageText = T(@"Built-in plugins cannot be removed. You can disable them instead.", @"Plugins embutidos não podem ser removidos. Você pode desativá-los.");
		[a runModal];
		return;
	}
	[[NSWorkspace sharedWorkspace] recycleURLs:@[ [NSURL fileURLWithPath:p.path] ] completionHandler:nil];
	[QPluginManager setPluginFile:p.fileName disabled:YES];
	[_table reloadData];
}

@end
