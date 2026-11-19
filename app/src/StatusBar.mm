// SPDX-License-Identifier: GPL-3.0-or-later
#import "StatusBar.h"
#import "Localization.h"

@implementation QStatusBar {
	NSTextField *_message;
	NSTextField *_length;
	NSButton *_position, *_eol, *_encoding, *_language;
	NSTextField *_mode;
	NSStackView *_right;
}

static NSButton *statusButton(id target, SEL action, NSString *tip) {
	NSButton *b = [NSButton buttonWithTitle:@"" target:target action:action];
	b.bordered = NO;
	b.font = [NSFont systemFontOfSize:11];
	b.toolTip = tip;
	b.contentTintColor = [NSColor secondaryLabelColor];
	[b setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
	return b;
}

static NSTextField *statusLabel(void) {
	NSTextField *l = [NSTextField labelWithString:@""];
	l.font = [NSFont systemFontOfSize:11];
	l.textColor = [NSColor secondaryLabelColor];
	l.lineBreakMode = NSLineBreakByTruncatingTail;
	return l;
}

- (instancetype)initWithFrame:(NSRect)frame {
	if ((self = [super initWithFrame:frame])) {
		_message = statusLabel();
		[_message setContentCompressionResistancePriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
		_length = statusLabel();
		_position = statusButton(self, @selector(positionAction:), T(@"Go to line (⌘L)", @"Ir para a linha (⌘L)"));
		_eol = statusButton(self, @selector(eolAction:), T(@"Line endings", @"Fim de linha"));
		_encoding = statusButton(self, @selector(encodingAction:), T(@"Encoding", @"Codificação"));
		_language = statusButton(self, @selector(languageAction:), T(@"Language", @"Linguagem"));
		_mode = statusLabel();
		_mode.stringValue = @"INS";
		_right = [NSStackView stackViewWithViews:@[ _length, _position, _eol, _encoding, _language, _mode ]];
		_right.spacing = 14;
		_right.translatesAutoresizingMaskIntoConstraints = NO;
		_message.translatesAutoresizingMaskIntoConstraints = NO;
		[self addSubview:_message];
		[self addSubview:_right];
		[NSLayoutConstraint activateConstraints:@[
			[_message.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:10],
			[_message.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
			[_right.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-10],
			[_right.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
			[_message.trailingAnchor constraintLessThanOrEqualToAnchor:_right.leadingAnchor constant:-10],
		]];
	}
	return self;
}

- (void)drawRect:(NSRect)dirtyRect {
	[[NSColor windowBackgroundColor] setFill];
	NSRectFill(self.bounds);
	[[NSColor separatorColor] setFill];
	NSRectFill(NSMakeRect(0, self.bounds.size.height - 1, self.bounds.size.width, 1));
}

- (void)setMessage:(NSString *)message {
	_message.stringValue = message ?: @"";
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(clearMessage) object:nil];
	if (message.length) [self performSelector:@selector(clearMessage) withObject:nil afterDelay:6];
}

- (void)clearMessage {
	_message.stringValue = @"";
}

- (void)setPosition:(NSString *)s {
	_position.title = s ?: @"";
}
- (void)setLength:(NSString *)s {
	_length.stringValue = s ?: @"";
}
- (void)setEncoding:(NSString *)s {
	_encoding.title = s ?: @"";
}
- (void)setLineEnding:(NSString *)s {
	_eol.title = s ?: @"";
}
- (void)setLanguage:(NSString *)s {
	_language.title = s ?: @"";
}
- (void)setOverwrite:(BOOL)overwrite {
	_mode.stringValue = overwrite ? @"OVR" : @"INS";
}

- (void)positionAction:(NSButton *)b {
	if (self.positionClicked) self.positionClicked(b);
}
- (void)eolAction:(NSButton *)b {
	if (self.lineEndingClicked) self.lineEndingClicked(b);
}
- (void)encodingAction:(NSButton *)b {
	if (self.encodingClicked) self.encodingClicked(b);
}
- (void)languageAction:(NSButton *)b {
	if (self.languageClicked) self.languageClicked(b);
}

@end
