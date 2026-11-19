// Document tab strip shown above the editor.
// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#import <Cocoa/Cocoa.h>

@class QTabBar;

@interface QTabItem : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *toolTip;
@property (nonatomic) BOOL dirty;
@property (nonatomic) BOOL readOnly;
@property (nonatomic) BOOL missing;
@end

@protocol QTabBarDelegate <NSObject>
- (void)tabBar:(QTabBar *)bar didSelectIndex:(NSInteger)index;
- (void)tabBar:(QTabBar *)bar closeIndex:(NSInteger)index;
- (void)tabBar:(QTabBar *)bar moveIndex:(NSInteger)from toIndex:(NSInteger)to;
- (NSMenu *)tabBar:(QTabBar *)bar menuForIndex:(NSInteger)index;
- (void)tabBarNewTab:(QTabBar *)bar;
@end

@interface QTabBar : NSView
@property (nonatomic, weak) id<QTabBarDelegate> delegate;
@property (nonatomic, readonly) NSInteger selectedIndex;
- (void)setItems:(NSArray<QTabItem *> *)items selectedIndex:(NSInteger)selected;
- (void)scrollSelectedIntoView;
@end
