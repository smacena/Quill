// Builds the application menu bar (localized).
// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#import <Cocoa/Cocoa.h>

@interface QMainMenu : NSObject
+ (instancetype)shared;
- (NSMenu *)build;
@property (nonatomic, readonly) NSMenu *recentMenu;
@property (nonatomic, readonly) NSMenu *languageMenu;
@property (nonatomic, readonly) NSMenu *encodingMenu;
@property (nonatomic, readonly) NSMenu *reopenEncodingMenu;
@property (nonatomic, readonly) NSMenu *lineEndingMenu;
@property (nonatomic, readonly) NSMenu *pluginsMenu;
@property (nonatomic, readonly) NSMenu *panelsMenu;
@property (nonatomic, readonly) NSMenu *windowMenu;
@end
