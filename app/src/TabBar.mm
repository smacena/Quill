// SPDX-License-Identifier: GPL-3.0-or-later
#import "TabBar.h"
#import "Localization.h"

@implementation QTabItem
@end

static const CGFloat kTabMinWidth = 110;
static const CGFloat kTabMaxWidth = 220;
static const CGFloat kTabHeight = 30;
static const CGFloat kCloseSize = 16;

@interface QTabStrip : NSView
@property (nonatomic, weak) QTabBar *owner;
@property (nonatomic, copy) NSArray<QTabItem *> *items;
@property (nonatomic) NSInteger selected;
@property (nonatomic) NSInteger hoverIndex;
@property (nonatomic) BOOL hoverClose;
@property (nonatomic) NSInteger pressedIndex;
@property (nonatomic) NSInteger dragIndex;
@property (nonatomic) CGFloat dragOffset;
@property (nonatomic) NSPoint mouseDownPoint;
- (CGFloat)tabWidth;
- (NSRect)rectForIndex:(NSInteger)i;
@end

@interface QTabBar ()
- (void)stripSelect:(NSInteger)i;
- (void)stripClose:(NSInteger)i;
- (void)stripMove:(NSInteger)from to:(NSInteger)to;
- (NSMenu *)stripMenu:(NSInteger)i;
- (void)stripNewTab;
@end

@implementation QTabStrip

- (BOOL)isFlipped {
	return YES;
}

- (CGFloat)tabWidth {
	NSInteger n = (NSInteger)self.items.count;
	if (n == 0) return kTabMaxWidth;
	CGFloat avail = self.enclosingScrollView ? self.enclosingScrollView.contentSize.width : self.bounds.size.width;
	CGFloat w = floor(avail / n);
	return MAX(kTabMinWidth, MIN(kTabMaxWidth, w));
}

- (NSRect)rectForIndex:(NSInteger)i {
	CGFloat w = [self tabWidth];
	NSRect r = NSMakeRect(i * w, 0, w, kTabHeight);
	if (i == self.dragIndex && self.dragIndex >= 0) r.origin.x += self.dragOffset;
	return r;
}

- (NSRect)closeRectForTab:(NSRect)tab {
	return NSMakeRect(NSMaxX(tab) - kCloseSize - 8, (kTabHeight - kCloseSize) / 2, kCloseSize, kCloseSize);
}

- (NSInteger)indexAtPoint:(NSPoint)p {
	if (p.y < 0 || p.y > kTabHeight) return -1;
	CGFloat w = [self tabWidth];
	NSInteger i = (NSInteger)floor(p.x / w);
	return (i >= 0 && i < (NSInteger)self.items.count) ? i : -1;
}

- (void)updateTrackingAreas {
	[super updateTrackingAreas];
	for (NSTrackingArea *a in self.trackingAreas) [self removeTrackingArea:a];
	[self addTrackingArea:[[NSTrackingArea alloc] initWithRect:self.bounds
							   options:NSTrackingMouseMoved | NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect
							     owner:self
							  userInfo:nil]];
}

- (void)mouseMoved:(NSEvent *)event {
	NSPoint p = [self convertPoint:event.locationInWindow fromView:nil];
	NSInteger i = [self indexAtPoint:p];
	BOOL overClose = i >= 0 && NSPointInRect(p, [self closeRectForTab:[self rectForIndex:i]]);
	if (i != self.hoverIndex || overClose != self.hoverClose) {
		self.hoverIndex = i;
		self.hoverClose = overClose;
		self.needsDisplay = YES;
	}
}

- (void)mouseExited:(NSEvent *)event {
	self.hoverIndex = -1;
	self.hoverClose = NO;
	self.needsDisplay = YES;
}

- (void)mouseDown:(NSEvent *)event {
	NSPoint p = [self convertPoint:event.locationInWindow fromView:nil];
	NSInteger i = [self indexAtPoint:p];
	self.mouseDownPoint = p;
	self.pressedIndex = i;
	self.dragIndex = -1;
	if (i < 0) {
		if (event.clickCount == 2) [self.owner stripNewTab];
		return;
	}
	if (NSPointInRect(p, [self closeRectForTab:[self rectForIndex:i]])) return;
	[self.owner stripSelect:i];
}

- (void)mouseDragged:(NSEvent *)event {
	if (self.pressedIndex < 0) return;
	NSPoint p = [self convertPoint:event.locationInWindow fromView:nil];
	CGFloat dx = p.x - self.mouseDownPoint.x;
	if (self.dragIndex < 0 && fabs(dx) < 6) return;
	self.dragIndex = self.pressedIndex;
	self.dragOffset = dx;
	CGFloat w = [self tabWidth];
	NSInteger target = (NSInteger)floor(([self rectForIndex:self.dragIndex].origin.x + w / 2) / w);
	target = MAX(0, MIN((NSInteger)self.items.count - 1, target));
	if (target != self.dragIndex) {
		NSInteger from = self.dragIndex;
		self.mouseDownPoint = NSMakePoint(self.mouseDownPoint.x + (target - from) * w, self.mouseDownPoint.y);
		self.dragOffset = p.x - self.mouseDownPoint.x;
		self.pressedIndex = target;
		self.dragIndex = target;
		[self.owner stripMove:from to:target];
	}
	self.needsDisplay = YES;
}

- (void)mouseUp:(NSEvent *)event {
	NSPoint p = [self convertPoint:event.locationInWindow fromView:nil];
	NSInteger i = [self indexAtPoint:p];
	if (self.dragIndex < 0 && i >= 0 && i == self.pressedIndex &&
	    NSPointInRect(p, [self closeRectForTab:[self rectForIndex:i]]))
		[self.owner stripClose:i];
	self.dragIndex = -1;
	self.pressedIndex = -1;
	self.dragOffset = 0;
	self.needsDisplay = YES;
}

- (void)otherMouseUp:(NSEvent *)event {
	if (event.buttonNumber != 2) return;
	NSInteger i = [self indexAtPoint:[self convertPoint:event.locationInWindow fromView:nil]];
	if (i >= 0) [self.owner stripClose:i];
}

- (NSMenu *)menuForEvent:(NSEvent *)event {
	NSInteger i = [self indexAtPoint:[self convertPoint:event.locationInWindow fromView:nil]];
	if (i < 0) return nil;
	return [self.owner stripMenu:i];
}

- (NSString *)view:(NSView *)view stringForToolTip:(NSToolTipTag)tag point:(NSPoint)point userData:(void *)data {
	NSInteger i = [self indexAtPoint:point];
	return i >= 0 ? self.items[(NSUInteger)i].toolTip : nil;
}

- (void)rebuildToolTips {
	[self removeAllToolTips];
	[self addToolTipRect:self.bounds owner:self userData:nil];
}

- (void)drawRect:(NSRect)dirty {
	BOOL dark = [[self.effectiveAppearance bestMatchFromAppearancesWithNames:@[ NSAppearanceNameAqua, NSAppearanceNameDarkAqua ]]
		isEqualToString:NSAppearanceNameDarkAqua];
	NSColor *barBack = dark ? [NSColor colorWithWhite:0.15 alpha:1] : [NSColor colorWithWhite:0.925 alpha:1];
	NSColor *selBack = dark ? [NSColor colorWithWhite:0.118 alpha:1] : [NSColor whiteColor];
	NSColor *hoverBack = dark ? [NSColor colorWithWhite:0.19 alpha:1] : [NSColor colorWithWhite:0.96 alpha:1];
	[barBack setFill];
	NSRectFill(self.bounds);

	NSInteger n = (NSInteger)self.items.count;
	// Draw the dragged tab last so it stays on top.
	NSMutableArray<NSNumber *> *order = [NSMutableArray array];
	for (NSInteger i = 0; i < n; i++)
		if (i != self.dragIndex) [order addObject:@(i)];
	if (self.dragIndex >= 0 && self.dragIndex < n) [order addObject:@(self.dragIndex)];

	for (NSNumber *num in order) {
		NSInteger i = num.integerValue;
		QTabItem *item = self.items[(NSUInteger)i];
		NSRect r = [self rectForIndex:i];
		BOOL sel = i == self.selected;
		BOOL hover = i == self.hoverIndex;
		if (sel) {
			[selBack setFill];
			NSRectFill(r);
			[[NSColor controlAccentColor] setFill];
			NSRectFill(NSMakeRect(r.origin.x, 0, r.size.width, 2));
		} else if (hover) {
			[hoverBack setFill];
			NSRectFill(r);
		}
		[[NSColor separatorColor] setFill];
		NSRectFill(NSMakeRect(NSMaxX(r) - 1, 6, 1, kTabHeight - 12));

		NSRect closeRect = [self closeRectForTab:r];
		NSColor *textColor = sel ? [NSColor labelColor] : [NSColor secondaryLabelColor];
		if (item.missing) textColor = [NSColor systemRedColor];
		NSMutableParagraphStyle *para = [[NSMutableParagraphStyle alloc] init];
		para.lineBreakMode = NSLineBreakByTruncatingMiddle;
		NSDictionary *attrs = @{
			NSFontAttributeName : [NSFont systemFontOfSize:12 weight:sel ? NSFontWeightMedium : NSFontWeightRegular],
			NSForegroundColorAttributeName : textColor,
			NSParagraphStyleAttributeName : para,
		};
		CGFloat left = r.origin.x + 12;
		if (item.readOnly) {
			NSImage *lock = [NSImage imageWithSystemSymbolName:@"lock.fill" accessibilityDescription:nil];
			[lock drawInRect:NSMakeRect(left, 9, 10, 12)];
			left += 14;
		}
		NSRect textRect = NSMakeRect(left, 7, closeRect.origin.x - left - 4, 18);
		[item.title drawInRect:textRect withAttributes:attrs];

		BOOL showClose = hover || sel;
		if (item.dirty && !(hover && self.hoverClose)) {
			[[NSColor labelColor] setFill];
			NSRect dot = NSInsetRect(closeRect, 4.5, 4.5);
			[[NSBezierPath bezierPathWithOvalInRect:dot] fill];
		} else if (showClose) {
			if (hover && self.hoverClose) {
				[[NSColor colorWithWhite:dark ? 1 : 0 alpha:0.12] setFill];
				[[NSBezierPath bezierPathWithRoundedRect:closeRect xRadius:4 yRadius:4] fill];
			}
			NSBezierPath *x = [NSBezierPath bezierPath];
			NSRect cr = NSInsetRect(closeRect, 5, 5);
			[x moveToPoint:NSMakePoint(NSMinX(cr), NSMinY(cr))];
			[x lineToPoint:NSMakePoint(NSMaxX(cr), NSMaxY(cr))];
			[x moveToPoint:NSMakePoint(NSMaxX(cr), NSMinY(cr))];
			[x lineToPoint:NSMakePoint(NSMinX(cr), NSMaxY(cr))];
			x.lineWidth = 1.3;
			[[NSColor secondaryLabelColor] setStroke];
			[x stroke];
		}
	}
	[[NSColor separatorColor] setFill];
	NSRectFill(NSMakeRect(0, kTabHeight - 1, self.bounds.size.width, 1));
	if (self.selected >= 0 && self.selected < n) {
		NSRect r = [self rectForIndex:self.selected];
		[selBack setFill];
		NSRectFill(NSMakeRect(r.origin.x, kTabHeight - 1, r.size.width - 1, 1));
	}
}

@end

@implementation QTabBar {
	NSScrollView *_scroll;
	QTabStrip *_strip;
	NSButton *_addButton;
	NSArray<QTabItem *> *_items;
}

- (instancetype)initWithFrame:(NSRect)frame {
	if ((self = [super initWithFrame:frame])) {
		_scroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
		_scroll.hasHorizontalScroller = NO;
		_scroll.hasVerticalScroller = NO;
		_scroll.horizontalScrollElasticity = NSScrollElasticityNone;
		_scroll.verticalScrollElasticity = NSScrollElasticityNone;
		_scroll.drawsBackground = NO;
		_strip = [[QTabStrip alloc] initWithFrame:NSMakeRect(0, 0, 100, kTabHeight)];
		_strip.owner = self;
		_strip.hoverIndex = -1;
		_strip.pressedIndex = -1;
		_strip.dragIndex = -1;
		_scroll.documentView = _strip;
		[self addSubview:_scroll];

		_addButton = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"plus" accessibilityDescription:T(@"New Tab", @"Nova aba")]
						target:self
						action:@selector(addTab:)];
		_addButton.bordered = NO;
		_addButton.toolTip = T(@"New Tab", @"Nova aba");
		[self addSubview:_addButton];
	}
	return self;
}

- (BOOL)isFlipped {
	return YES;
}

- (void)drawRect:(NSRect)dirtyRect {
	BOOL dark = [[self.effectiveAppearance bestMatchFromAppearancesWithNames:@[ NSAppearanceNameAqua, NSAppearanceNameDarkAqua ]]
		isEqualToString:NSAppearanceNameDarkAqua];
	[(dark ? [NSColor colorWithWhite:0.15 alpha:1] : [NSColor colorWithWhite:0.925 alpha:1]) setFill];
	NSRectFill(self.bounds);
	[[NSColor separatorColor] setFill];
	NSRectFill(NSMakeRect(0, kTabHeight - 1, self.bounds.size.width, 1));
}

- (void)layout {
	[super layout];
	NSRect b = self.bounds;
	CGFloat addW = 30;
	_scroll.frame = NSMakeRect(0, 0, b.size.width - addW, kTabHeight);
	_addButton.frame = NSMakeRect(b.size.width - addW, 3, addW - 4, kTabHeight - 7);
	[self relayoutStrip];
}

- (void)relayoutStrip {
	CGFloat w = [_strip tabWidth] * (CGFloat)_items.count;
	CGFloat visible = _scroll.contentSize.width;
	[_strip setFrameSize:NSMakeSize(MAX(w, visible), kTabHeight)];
	[_strip rebuildToolTips];
	_strip.needsDisplay = YES;
}

- (NSSize)intrinsicContentSize {
	return NSMakeSize(NSViewNoIntrinsicMetric, kTabHeight);
}

- (NSInteger)selectedIndex {
	return _strip.selected;
}

- (void)setItems:(NSArray<QTabItem *> *)items selectedIndex:(NSInteger)selected {
	_items = [items copy];
	_strip.items = _items;
	_strip.selected = selected;
	if (_strip.hoverIndex >= (NSInteger)items.count) _strip.hoverIndex = -1;
	[self relayoutStrip];
}

- (void)scrollSelectedIntoView {
	if (_strip.selected < 0) return;
	[_strip scrollRectToVisible:[_strip rectForIndex:_strip.selected]];
}

- (void)addTab:(id)sender {
	[self.delegate tabBarNewTab:self];
}

- (void)scrollWheel:(NSEvent *)event {
	// Vertical wheel scrolls the tabs horizontally.
	NSClipView *clip = _scroll.contentView;
	NSPoint origin = clip.bounds.origin;
	CGFloat delta = event.scrollingDeltaX != 0 ? -event.scrollingDeltaX : -event.scrollingDeltaY;
	if (!event.hasPreciseScrollingDeltas) delta *= 10;
	CGFloat maxX = MAX(0, _strip.frame.size.width - clip.bounds.size.width);
	origin.x = MAX(0, MIN(maxX, origin.x + delta));
	[clip scrollToPoint:origin];
	[_scroll reflectScrolledClipView:clip];
}

- (void)stripSelect:(NSInteger)i {
	[self.delegate tabBar:self didSelectIndex:i];
}

- (void)stripClose:(NSInteger)i {
	[self.delegate tabBar:self closeIndex:i];
}

- (void)stripMove:(NSInteger)from to:(NSInteger)to {
	[self.delegate tabBar:self moveIndex:from toIndex:to];
}

- (NSMenu *)stripMenu:(NSInteger)i {
	return [self.delegate tabBar:self menuForIndex:i];
}

- (void)stripNewTab {
	[self.delegate tabBarNewTab:self];
}

@end
