// Status bar at the bottom of the main window.
// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#import <Cocoa/Cocoa.h>

@interface QStatusBar : NSView
@property (nonatomic, copy) void (^encodingClicked)(NSView *anchor);
@property (nonatomic, copy) void (^lineEndingClicked)(NSView *anchor);
@property (nonatomic, copy) void (^languageClicked)(NSView *anchor);
@property (nonatomic, copy) void (^positionClicked)(NSView *anchor);

- (void)setMessage:(NSString *)message;          // transient (clears after a few seconds)
- (void)setPosition:(NSString *)position;        // "Ln 1, Col 1"
- (void)setLength:(NSString *)length;            // "length: 10  lines: 2"
- (void)setEncoding:(NSString *)encoding;
- (void)setLineEnding:(NSString *)eol;
- (void)setLanguage:(NSString *)language;
- (void)setOverwrite:(BOOL)overwrite;
@end
