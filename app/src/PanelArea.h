// A docking area (left, right or bottom) that hosts plugin panels.
// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#import <Cocoa/Cocoa.h>

@interface QPanelArea : NSView
@property (nonatomic, copy) void (^visibilityChanged)(QPanelArea *area);
@property (nonatomic, copy) void (^panelClosed)(NSView *panel);

- (void)addPanel:(NSView *)view title:(NSString *)title;
- (void)removePanel:(NSView *)view;
- (BOOL)containsPanel:(NSView *)view;
- (void)showPanel:(NSView *)view;
- (void)hidePanel:(NSView *)view;
- (BOOL)isPanelOpen:(NSView *)view;
- (void)setTitle:(NSString *)title forPanel:(NSView *)view;
@property (nonatomic, readonly) BOOL hasOpenPanels;
@property (nonatomic, readonly) NSArray<NSView *> *openPanels;
@end
