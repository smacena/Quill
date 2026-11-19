// SPDX-License-Identifier: GPL-3.0-or-later
#import "PanelArea.h"
#import "Localization.h"

@interface QPanelEntry : NSObject
@property (nonatomic, strong) NSView *view;
@property (nonatomic, copy) NSString *title;
@property (nonatomic) BOOL open;
@end
@implementation QPanelEntry
@end

@implementation QPanelArea {
	NSMutableArray<QPanelEntry *> *_entries;
	QPanelEntry *_current;
	NSView *_header;
	NSTextField *_titleLabel;
	NSSegmentedControl *_switcher;
	NSButton *_closeButton;
	NSView *_content;
}

- (instancetype)initWithFrame:(NSRect)frame {
	if ((self = [super initWithFrame:frame])) {
		_entries = [NSMutableArray array];
		_header = [[NSView alloc] initWithFrame:NSZeroRect];
		_titleLabel = [NSTextField labelWithString:@""];
		_titleLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
		_titleLabel.textColor = [NSColor secondaryLabelColor];
		_titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
		_switcher = [NSSegmentedControl segmentedControlWithLabels:@[] trackingMode:NSSegmentSwitchTrackingSelectOne target:self action:@selector(switchPanel:)];
		_switcher.controlSize = NSControlSizeSmall;
		_switcher.font = [NSFont systemFontOfSize:11];
		_switcher.segmentStyle = NSSegmentStyleRounded;
		_closeButton = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"xmark" accessibilityDescription:T(@"Close Panel", @"Fechar painel")]
						  target:self
						  action:@selector(closeCurrent:)];
		_closeButton.bordered = NO;
		_closeButton.toolTip = T(@"Close Panel", @"Fechar painel");
		[_header addSubview:_titleLabel];
		[_header addSubview:_switcher];
		[_header addSubview:_closeButton];
		_content = [[NSView alloc] initWithFrame:NSZeroRect];
		[self addSubview:_header];
		[self addSubview:_content];
	}
	return self;
}

- (BOOL)isFlipped {
	return YES;
}

- (void)drawRect:(NSRect)dirtyRect {
	[[NSColor windowBackgroundColor] setFill];
	NSRectFill(self.bounds);
	[[NSColor separatorColor] setFill];
	NSRectFill(NSMakeRect(0, 25, self.bounds.size.width, 1));
}

- (void)layout {
	[super layout];
	NSRect b = self.bounds;
	_header.frame = NSMakeRect(0, 0, b.size.width, 25);
	_closeButton.frame = NSMakeRect(b.size.width - 24, 4, 18, 17);
	_titleLabel.frame = NSMakeRect(8, 5, b.size.width - 40, 16);
	[_switcher sizeToFit];
	NSRect sf = _switcher.frame;
	sf.origin = NSMakePoint(6, 2);
	sf.size.width = MIN(sf.size.width, b.size.width - 40);
	_switcher.frame = sf;
	_content.frame = NSMakeRect(0, 26, b.size.width, MAX(0, b.size.height - 26));
	_current.view.frame = _content.bounds;
}

- (QPanelEntry *)entryFor:(NSView *)view {
	for (QPanelEntry *e in _entries)
		if (e.view == view) return e;
	return nil;
}

- (void)addPanel:(NSView *)view title:(NSString *)title {
	if ([self entryFor:view]) return;
	QPanelEntry *e = [[QPanelEntry alloc] init];
	e.view = view;
	e.title = title ?: @"";
	[_entries addObject:e];
}

- (void)removePanel:(NSView *)view {
	QPanelEntry *e = [self entryFor:view];
	if (!e) return;
	[self hidePanel:view];
	[_entries removeObject:e];
}

- (BOOL)containsPanel:(NSView *)view {
	return [self entryFor:view] != nil;
}

- (void)setTitle:(NSString *)title forPanel:(NSView *)view {
	QPanelEntry *e = [self entryFor:view];
	if (!e) return;
	e.title = title ?: @"";
	[self refresh];
}

- (NSArray<QPanelEntry *> *)openEntries {
	NSMutableArray *open = [NSMutableArray array];
	for (QPanelEntry *e in _entries)
		if (e.open) [open addObject:e];
	return open;
}

- (NSArray<NSView *> *)openPanels {
	NSMutableArray *views = [NSMutableArray array];
	for (QPanelEntry *e in [self openEntries]) [views addObject:e.view];
	return views;
}

- (BOOL)hasOpenPanels {
	return [self openEntries].count > 0;
}

- (BOOL)isPanelOpen:(NSView *)view {
	return [self entryFor:view].open;
}

- (void)showPanel:(NSView *)view {
	QPanelEntry *e = [self entryFor:view];
	if (!e) return;
	BOOL wasEmpty = !self.hasOpenPanels;
	e.open = YES;
	[self select:e];
	if (wasEmpty && self.visibilityChanged) self.visibilityChanged(self);
}

- (void)hidePanel:(NSView *)view {
	QPanelEntry *e = [self entryFor:view];
	if (!e || !e.open) return;
	e.open = NO;
	if (_current == e) {
		[e.view removeFromSuperview];
		_current = nil;
		QPanelEntry *next = [self openEntries].lastObject;
		if (next) [self select:next];
	}
	[self refresh];
	if (!self.hasOpenPanels && self.visibilityChanged) self.visibilityChanged(self);
}

- (void)select:(QPanelEntry *)e {
	if (_current != e) {
		[_current.view removeFromSuperview];
		_current = e;
		e.view.frame = _content.bounds;
		e.view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
		[_content addSubview:e.view];
	}
	[self refresh];
}

- (void)refresh {
	NSArray<QPanelEntry *> *open = [self openEntries];
	if (open.count > 1) {
		_switcher.segmentCount = (NSInteger)open.count;
		for (NSUInteger i = 0; i < open.count; i++) {
			[_switcher setLabel:open[i].title forSegment:(NSInteger)i];
			[_switcher setWidth:0 forSegment:(NSInteger)i];
			if (open[i] == _current) _switcher.selectedSegment = (NSInteger)i;
		}
		_switcher.hidden = NO;
		_titleLabel.hidden = YES;
	} else {
		_switcher.hidden = YES;
		_titleLabel.hidden = NO;
		_titleLabel.stringValue = _current.title.uppercaseString ?: @"";
	}
	self.needsLayout = YES;
}

- (void)switchPanel:(NSSegmentedControl *)sender {
	NSArray<QPanelEntry *> *open = [self openEntries];
	NSInteger i = sender.selectedSegment;
	if (i >= 0 && i < (NSInteger)open.count) [self select:open[(NSUInteger)i]];
}

- (void)closeCurrent:(id)sender {
	NSView *v = _current.view;
	if (!v) return;
	[self hidePanel:v];
	if (self.panelClosed) self.panelClosed(v);
}

@end
