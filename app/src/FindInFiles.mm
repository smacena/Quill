// SPDX-License-Identifier: GPL-3.0-or-later
#import "FindInFiles.h"
#import "Localization.h"

#include <atomic>
#include <fnmatch.h>
#include <string>
#include "quill/Encoding.h"

@implementation QSearchHit
@end

@interface QSearchFileNode : NSObject
@property (nonatomic, copy) NSString *path;
@property (nonatomic, strong) NSMutableArray<QSearchHit *> *hits;
@end
@implementation QSearchFileNode
@end

@implementation QFindInFilesController {
	NSTextField *_findField, *_replaceField, *_dirField, *_filterField, *_progressLabel;
	NSButton *_caseCheck, *_wordCheck, *_regexCheck, *_subCheck, *_hiddenCheck;
	NSButton *_findButton, *_replaceButton, *_stopButton;
	NSView *_resultsView;
	NSOutlineView *_outline;
	NSTextField *_summaryLabel;
	NSMutableArray<QSearchFileNode *> *_results;
	std::atomic<bool> _cancel;
	BOOL _running;
}

- (instancetype)init {
	NSPanel *panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 560, 300)
						    styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskUtilityWindow
						      backing:NSBackingStoreBuffered
							defer:YES];
	panel.title = T(@"Find in Files", @"Localizar em arquivos");
	panel.hidesOnDeactivate = NO;
	panel.floatingPanel = NO;
	if ((self = [super initWithWindow:panel])) {
		_results = [NSMutableArray array];
		[self buildDialog];
		[self buildResults];
	}
	return self;
}

static NSTextField *label(NSString *s) {
	NSTextField *l = [NSTextField labelWithString:s];
	l.alignment = NSTextAlignmentRight;
	return l;
}

static NSButton *check(NSString *s) {
	return [NSButton checkboxWithTitle:s target:nil action:nil];
}

- (void)buildDialog {
	NSView *c = self.window.contentView;
	NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
	_findField = [NSTextField textFieldWithString:@""];
	_replaceField = [NSTextField textFieldWithString:@""];
	_dirField = [NSTextField textFieldWithString:[d stringForKey:@"fifDirectory"] ?: NSHomeDirectory()];
	_filterField = [NSTextField textFieldWithString:[d stringForKey:@"fifFilters"] ?: @"*.*"];
	_filterField.placeholderString = @"*.c *.h *.txt";
	_findField.placeholderString = T(@"Text to find", @"Texto a localizar");
	_replaceField.placeholderString = T(@"Replacement (only for Replace in Files)", @"Substituição (só para Substituir em arquivos)");
	NSButton *browse = [NSButton buttonWithTitle:T(@"Choose…", @"Escolher…") target:self action:@selector(browse:)];
	_caseCheck = check(T(@"Match case", @"Diferenciar maiúsculas"));
	_wordCheck = check(T(@"Whole word", @"Palavra inteira"));
	_regexCheck = check(T(@"Regular expression", @"Expressão regular"));
	_subCheck = check(T(@"In subfolders", @"Em subpastas"));
	_hiddenCheck = check(T(@"In hidden folders", @"Em pastas ocultas"));
	_caseCheck.state = [d boolForKey:@"fifCase"];
	_wordCheck.state = [d boolForKey:@"fifWord"];
	_regexCheck.state = [d boolForKey:@"fifRegex"];
	_subCheck.state = [d objectForKey:@"fifSub"] ? [d boolForKey:@"fifSub"] : YES;
	_hiddenCheck.state = [d boolForKey:@"fifHidden"];
	_findButton = [NSButton buttonWithTitle:T(@"Find All", @"Localizar todos") target:self action:@selector(findAll:)];
	_findButton.keyEquivalent = @"\r";
	_replaceButton = [NSButton buttonWithTitle:T(@"Replace in Files", @"Substituir em arquivos") target:self action:@selector(replaceAll:)];
	_stopButton = [NSButton buttonWithTitle:T(@"Stop", @"Parar") target:self action:@selector(stop:)];
	_stopButton.enabled = NO;
	_progressLabel = [NSTextField labelWithString:@""];
	_progressLabel.textColor = [NSColor secondaryLabelColor];
	_progressLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;

	NSGridView *grid = [NSGridView gridViewWithViews:@[
		@[ label(T(@"Find:", @"Localizar:")), _findField, [NSGridCell emptyContentView] ],
		@[ label(T(@"Replace:", @"Substituir:")), _replaceField, [NSGridCell emptyContentView] ],
		@[ label(T(@"Folder:", @"Pasta:")), _dirField, browse ],
		@[ label(T(@"Filters:", @"Filtros:")), _filterField, [NSGridCell emptyContentView] ],
	]];
	grid.rowSpacing = 8;
	grid.columnSpacing = 8;
	[grid columnAtIndex:1].width = 340;
	NSStackView *checks1 = [NSStackView stackViewWithViews:@[ _caseCheck, _wordCheck, _regexCheck ]];
	NSStackView *checks2 = [NSStackView stackViewWithViews:@[ _subCheck, _hiddenCheck ]];
	NSStackView *buttons = [NSStackView stackViewWithViews:@[ _progressLabel, _stopButton, _replaceButton, _findButton ]];
	[_progressLabel setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
	[_progressLabel setContentCompressionResistancePriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
	NSStackView *stack = [NSStackView stackViewWithViews:@[ grid, checks1, checks2, buttons ]];
	stack.orientation = NSUserInterfaceLayoutOrientationVertical;
	stack.alignment = NSLayoutAttributeLeading;
	stack.spacing = 12;
	stack.edgeInsets = NSEdgeInsetsMake(16, 16, 16, 16);
	stack.translatesAutoresizingMaskIntoConstraints = NO;
	[c addSubview:stack];
	[NSLayoutConstraint activateConstraints:@[
		[stack.leadingAnchor constraintEqualToAnchor:c.leadingAnchor],
		[stack.trailingAnchor constraintEqualToAnchor:c.trailingAnchor],
		[stack.topAnchor constraintEqualToAnchor:c.topAnchor],
		[stack.bottomAnchor constraintEqualToAnchor:c.bottomAnchor],
		[buttons.widthAnchor constraintEqualToAnchor:grid.widthAnchor],
	]];
	[checks1 setContentHuggingPriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationVertical];
}

- (void)buildResults {
	_resultsView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 600, 200)];
	_summaryLabel = [NSTextField labelWithString:T(@"No search yet.", @"Nenhuma busca ainda.")];
	_summaryLabel.font = [NSFont systemFontOfSize:11];
	_summaryLabel.textColor = [NSColor secondaryLabelColor];
	_summaryLabel.frame = NSMakeRect(8, 178, 584, 18);
	_summaryLabel.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
	NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 600, 176)];
	scroll.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
	scroll.hasVerticalScroller = YES;
	scroll.hasHorizontalScroller = YES;
	_outline = [[NSOutlineView alloc] initWithFrame:scroll.bounds];
	NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:@"text"];
	col.resizingMask = NSTableColumnAutoresizingMask;
	col.width = 2000;
	[_outline addTableColumn:col];
	_outline.outlineTableColumn = col;
	_outline.headerView = nil;
	_outline.dataSource = self;
	_outline.delegate = self;
	_outline.rowSizeStyle = NSTableViewRowSizeStyleSmall;
	_outline.style = NSTableViewStylePlain;
	_outline.target = self;
	_outline.doubleAction = @selector(openSelected:);
	_outline.action = @selector(clickSelected:);
	scroll.documentView = _outline;
	[_resultsView addSubview:scroll];
	[_resultsView addSubview:_summaryLabel];
}

- (NSView *)resultsView {
	return _resultsView;
}

- (void)showWithSearch:(NSString *)search directory:(NSString *)directory {
	if (search.length) _findField.stringValue = search;
	if (directory.length) _dirField.stringValue = directory;
	if (!self.window.isVisible) [self.window center];
	[self showWindow:nil];
	[self.window makeFirstResponder:_findField];
}

- (void)browse:(id)sender {
	NSOpenPanel *p = [NSOpenPanel openPanel];
	p.canChooseDirectories = YES;
	p.canChooseFiles = NO;
	p.directoryURL = [NSURL fileURLWithPath:_dirField.stringValue];
	if ([p runModal] == NSModalResponseOK) _dirField.stringValue = p.URL.path;
}

- (void)saveOptions {
	NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
	[d setObject:_dirField.stringValue forKey:@"fifDirectory"];
	[d setObject:_filterField.stringValue forKey:@"fifFilters"];
	[d setBool:_caseCheck.state forKey:@"fifCase"];
	[d setBool:_wordCheck.state forKey:@"fifWord"];
	[d setBool:_regexCheck.state forKey:@"fifRegex"];
	[d setBool:_subCheck.state forKey:@"fifSub"];
	[d setBool:_hiddenCheck.state forKey:@"fifHidden"];
}

- (NSRegularExpression *)buildRegex:(NSError **)error {
	NSString *pattern = _findField.stringValue;
	if (_regexCheck.state != NSControlStateValueOn) pattern = [NSRegularExpression escapedPatternForString:pattern];
	if (_wordCheck.state == NSControlStateValueOn) pattern = [NSString stringWithFormat:@"\\b(?:%@)\\b", pattern];
	NSRegularExpressionOptions opts = NSRegularExpressionAnchorsMatchLines;
	if (_caseCheck.state != NSControlStateValueOn) opts |= NSRegularExpressionCaseInsensitive;
	return [NSRegularExpression regularExpressionWithPattern:pattern options:opts error:error];
}

- (NSArray<NSString *> *)filters {
	NSMutableArray *f = [NSMutableArray array];
	for (NSString *part in [_filterField.stringValue componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" ;,"]])
		if (part.length) [f addObject:part];
	return f;
}

static BOOL matchesFilters(NSString *name, NSArray<NSString *> *filters) {
	if (filters.count == 0) return YES;
	for (NSString *f in filters) {
		if ([f isEqualToString:@"*.*"] || [f isEqualToString:@"*"]) return YES;
		if (fnmatch(f.UTF8String, name.UTF8String, FNM_CASEFOLD) == 0) return YES;
	}
	return NO;
}

// Collects candidate files on a background queue.
- (NSArray<NSString *> *)filesInDirectory:(NSString *)dir filters:(NSArray *)filters sub:(BOOL)sub hidden:(BOOL)hidden {
	NSMutableArray *files = [NSMutableArray array];
	NSFileManager *fm = [NSFileManager defaultManager];
	NSURL *root = [NSURL fileURLWithPath:dir];
	NSDirectoryEnumerationOptions opts = 0;
	if (!sub) opts |= NSDirectoryEnumerationSkipsSubdirectoryDescendants;
	if (!hidden) opts |= NSDirectoryEnumerationSkipsHiddenFiles;
	NSDirectoryEnumerator *en = [fm enumeratorAtURL:root
			     includingPropertiesForKeys:@[ NSURLIsRegularFileKey, NSURLFileSizeKey ]
						options:opts
					   errorHandler:^BOOL(NSURL *url, NSError *error) {
						   return YES;
					   }];
	for (NSURL *url in en) {
		if (_cancel) break;
		NSNumber *isFile = nil, *size = nil;
		[url getResourceValue:&isFile forKey:NSURLIsRegularFileKey error:nil];
		if (!isFile.boolValue) continue;
		[url getResourceValue:&size forKey:NSURLFileSizeKey error:nil];
		if (size.unsignedLongLongValue > 50ull * 1024 * 1024) continue;
		if (!matchesFilters(url.lastPathComponent, filters)) continue;
		[files addObject:url.path];
	}
	return files;
}

static NSString *readText(NSString *path, quill::TextEncoding *encOut) {
	NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil];
	if (!data) return nil;
	NSUInteger probe = MIN(data.length, (NSUInteger)8000);
	std::string bytes(static_cast<const char *>(data.bytes), data.length);
	quill::TextEncoding enc = quill::detectEncoding(bytes);
	if (enc != quill::TextEncoding::UTF16LE && enc != quill::TextEncoding::UTF16BE && memchr(data.bytes, 0, probe)) return nil; // binary
	std::string utf8 = quill::decodeToUtf8(bytes, enc);
	if (encOut) *encOut = enc;
	return [[NSString alloc] initWithBytes:utf8.data() length:utf8.size() encoding:NSUTF8StringEncoding];
}

- (void)setRunning:(BOOL)running {
	_running = running;
	_findButton.enabled = !running;
	_replaceButton.enabled = !running;
	_stopButton.enabled = running;
}

- (void)findAll:(id)sender {
	[self runReplace:NO];
}

- (void)replaceAll:(id)sender {
	NSAlert *a = [[NSAlert alloc] init];
	a.messageText = T(@"Replace in all matching files?", @"Substituir em todos os arquivos encontrados?");
	a.informativeText = T(@"Files will be modified on disk. Files open with unsaved changes are skipped. This cannot be undone.",
			      @"Os arquivos serão alterados no disco. Arquivos abertos com alterações não salvas são ignorados. Não é possível desfazer.");
	[a addButtonWithTitle:T(@"Replace", @"Substituir")];
	[a addButtonWithTitle:T(@"Cancel", @"Cancelar")];
	if ([a runModal] != NSAlertFirstButtonReturn) return;
	[self runReplace:YES];
}

- (void)stop:(id)sender {
	_cancel = true;
}

- (void)runReplace:(BOOL)replace {
	if (_running || _findField.stringValue.length == 0) return;
	NSError *err = nil;
	NSRegularExpression *re = [self buildRegex:&err];
	if (!re) {
		NSAlert *a = [NSAlert alertWithError:err];
		[a runModal];
		return;
	}
	[self saveOptions];
	NSString *dir = _dirField.stringValue.stringByExpandingTildeInPath;
	BOOL isDir = NO;
	if (![[NSFileManager defaultManager] fileExistsAtPath:dir isDirectory:&isDir] || !isDir) {
		NSBeep();
		_progressLabel.stringValue = T(@"Folder not found.", @"Pasta não encontrada.");
		return;
	}
	NSArray *filters = [self filters];
	BOOL sub = _subCheck.state == NSControlStateValueOn;
	BOOL hidden = _hiddenCheck.state == NSControlStateValueOn;
	NSString *replacement = _replaceField.stringValue;
	if (_regexCheck.state != NSControlStateValueOn) replacement = [NSRegularExpression escapedTemplateForString:replacement];
	NSSet<NSString *> *dirty = (replace && self.dirtyPaths) ? self.dirtyPaths() : [NSSet set];
	NSString *needle = _findField.stringValue;

	_cancel = false;
	[self setRunning:YES];
	[_results removeAllObjects];
	[_outline reloadData];
	if (self.showResults) self.showResults();
	_summaryLabel.stringValue = T(@"Searching…", @"Buscando…");

	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
		NSArray<NSString *> *files = [self filesInDirectory:dir filters:filters sub:sub hidden:hidden];
		NSMutableArray<QSearchFileNode *> *found = [NSMutableArray array];
		NSMutableArray<NSString *> *modified = [NSMutableArray array];
		NSUInteger totalHits = 0, scanned = 0;
		NSUInteger skippedDirty = 0;
		for (NSString *path in files) {
			if (self->_cancel || totalHits > 50000) break;
			scanned++;
			if (scanned % 50 == 0) {
				NSString *p = path;
				NSUInteger n = scanned, total = files.count;
				dispatch_async(dispatch_get_main_queue(), ^{
					self->_progressLabel.stringValue = [NSString stringWithFormat:@"%lu / %lu  %@", (unsigned long)n, (unsigned long)total, p.lastPathComponent];
				});
			}
			quill::TextEncoding enc = quill::TextEncoding::UTF8;
			NSString *text = readText(path, &enc);
			if (!text) continue;
			if ([re firstMatchInString:text options:0 range:NSMakeRange(0, text.length)] == nil) continue;
			QSearchFileNode *node = [[QSearchFileNode alloc] init];
			node.path = path;
			node.hits = [NSMutableArray array];
			__block NSInteger lineNo = 0;
			[text enumerateSubstringsInRange:NSMakeRange(0, text.length)
						 options:NSStringEnumerationByLines
					      usingBlock:^(NSString *line, NSRange lineRange, NSRange enclosing, BOOL *stop) {
						      lineNo++;
						      NSArray<NSTextCheckingResult *> *ms = [re matchesInString:line options:0 range:NSMakeRange(0, line.length)];
						      if (ms.count == 0) return;
						      QSearchHit *hit = [[QSearchHit alloc] init];
						      hit.path = path;
						      hit.line = lineNo;
						      hit.column = (NSInteger)ms.firstObject.range.location;
						      hit.matchLength = (NSInteger)ms.firstObject.range.length;
						      NSString *display = line.length > 400 ? [line substringToIndex:400] : line;
						      hit.text = display;
						      NSMutableArray *ranges = [NSMutableArray array];
						      for (NSTextCheckingResult *m in ms)
							      if (NSMaxRange(m.range) <= display.length) [ranges addObject:[NSValue valueWithRange:m.range]];
						      hit.ranges = ranges;
						      [node.hits addObject:hit];
					      }];
			totalHits += node.hits.count;
			[found addObject:node];
			if (replace) {
				if ([dirty containsObject:path]) {
					skippedDirty++;
					continue;
				}
				NSString *newText = [re stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:replacement];
				std::string utf8(newText.UTF8String);
				std::string bytes = quill::encodeFromUtf8(utf8, enc);
				NSData *out = [NSData dataWithBytes:bytes.data() length:bytes.size()];
				if ([out writeToFile:path options:NSDataWritingAtomic error:nil]) [modified addObject:path];
			}
		}
		dispatch_async(dispatch_get_main_queue(), ^{
			[self->_results setArray:found];
			[self->_outline reloadData];
			if (found.count <= 30) [self->_outline expandItem:nil expandChildren:YES];
			NSString *summary;
			if (replace) {
				summary = [NSString stringWithFormat:T(@"Replaced %lu match(es) in %lu file(s) for \"%@\"", @"%lu ocorrência(s) substituída(s) em %lu arquivo(s) para \"%@\""),
								     (unsigned long)totalHits, (unsigned long)modified.count, needle];
				if (skippedDirty)
					summary = [summary stringByAppendingFormat:T(@" — %lu file(s) with unsaved changes skipped", @" — %lu arquivo(s) com alterações não salvas ignorado(s)"), (unsigned long)skippedDirty];
				if (self.filesModified) self.filesModified(modified);
			} else {
				summary = [NSString stringWithFormat:T(@"%lu match(es) in %lu file(s) for \"%@\" (%lu files searched)",
								       @"%lu ocorrência(s) em %lu arquivo(s) para \"%@\" (%lu arquivos pesquisados)"),
								     (unsigned long)totalHits, (unsigned long)found.count, needle, (unsigned long)scanned];
			}
			if (self->_cancel) summary = [summary stringByAppendingString:T(@" (stopped)", @" (interrompida)")];
			self->_summaryLabel.stringValue = summary;
			self->_progressLabel.stringValue = summary;
			[self setRunning:NO];
		});
	});
}

// ---- Outline ------------------------------------------------------------------

- (NSInteger)outlineView:(NSOutlineView *)ov numberOfChildrenOfItem:(id)item {
	if (!item) return (NSInteger)_results.count;
	if ([item isKindOfClass:[QSearchFileNode class]]) return (NSInteger)((QSearchFileNode *)item).hits.count;
	return 0;
}

- (id)outlineView:(NSOutlineView *)ov child:(NSInteger)index ofItem:(id)item {
	if (!item) return _results[(NSUInteger)index];
	return ((QSearchFileNode *)item).hits[(NSUInteger)index];
}

- (BOOL)outlineView:(NSOutlineView *)ov isItemExpandable:(id)item {
	return [item isKindOfClass:[QSearchFileNode class]];
}

- (NSView *)outlineView:(NSOutlineView *)ov viewForTableColumn:(NSTableColumn *)col item:(id)item {
	NSTableCellView *cell = [ov makeViewWithIdentifier:@"cell" owner:self];
	if (!cell) {
		cell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 400, 18)];
		cell.identifier = @"cell";
		NSTextField *tf = [NSTextField labelWithString:@""];
		tf.frame = cell.bounds;
		tf.autoresizingMask = NSViewWidthSizable;
		tf.lineBreakMode = NSLineBreakByTruncatingTail;
		[cell addSubview:tf];
		cell.textField = tf;
	}
	NSFont *mono = [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular];
	if ([item isKindOfClass:[QSearchFileNode class]]) {
		QSearchFileNode *n = item;
		NSMutableAttributedString *s = [[NSMutableAttributedString alloc]
			initWithString:n.path
			    attributes:@{NSFontAttributeName : [NSFont systemFontOfSize:12 weight:NSFontWeightSemibold], NSForegroundColorAttributeName : [NSColor labelColor]}];
		[s appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"  (%lu)", (unsigned long)n.hits.count]
									  attributes:@{NSFontAttributeName : [NSFont systemFontOfSize:11], NSForegroundColorAttributeName : [NSColor secondaryLabelColor]}]];
		cell.textField.attributedStringValue = s;
		cell.textField.toolTip = n.path;
	} else {
		QSearchHit *h = item;
		NSMutableAttributedString *s = [[NSMutableAttributedString alloc]
			initWithString:[NSString stringWithFormat:@"%6ld: ", (long)h.line]
			    attributes:@{NSFontAttributeName : mono, NSForegroundColorAttributeName : [NSColor secondaryLabelColor]}];
		NSMutableAttributedString *line = [[NSMutableAttributedString alloc]
			initWithString:h.text
			    attributes:@{NSFontAttributeName : mono, NSForegroundColorAttributeName : [NSColor labelColor]}];
		for (NSValue *v in h.ranges) {
			[line addAttribute:NSBackgroundColorAttributeName value:[[NSColor systemYellowColor] colorWithAlphaComponent:0.45] range:v.rangeValue];
			[line addAttribute:NSFontAttributeName value:[NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightBold] range:v.rangeValue];
		}
		[s appendAttributedString:line];
		cell.textField.attributedStringValue = s;
		cell.textField.toolTip = nil;
	}
	return cell;
}

- (void)clickSelected:(id)sender {
	id item = [_outline itemAtRow:_outline.clickedRow];
	if ([item isKindOfClass:[QSearchHit class]] && NSApp.currentEvent.clickCount == 1) {
		// single click previews the hit
		if (self.openHit) self.openHit(item);
	}
}

- (void)openSelected:(id)sender {
	id item = [_outline itemAtRow:_outline.clickedRow];
	if ([item isKindOfClass:[QSearchFileNode class]]) {
		if ([_outline isItemExpanded:item]) [_outline collapseItem:item];
		else [_outline expandItem:item];
		return;
	}
	if ([item isKindOfClass:[QSearchHit class]] && self.openHit) self.openHit(item);
}

@end
