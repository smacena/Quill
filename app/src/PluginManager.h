// Loads Notepad++-style plugins (.dylib) and routes their messages.
// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#import <Cocoa/Cocoa.h>
#include "Scintilla.h"

@class ScintillaView;

// Implemented by the main window controller.
@protocol QPluginHost <NSObject>
- (intptr_t)handleNppMessage:(unsigned int)msg wParam:(uintptr_t)wParam lParam:(intptr_t)lParam;
- (ScintillaView *)currentEditor;
- (void)pluginManagerDidChangeMenus;
@end

@interface QPluginInfo : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy) NSString *fileName;
@property (nonatomic) BOOL builtIn;
@property (nonatomic) BOOL enabled;
@property (nonatomic, copy) NSString *loadError;
@end

@interface QPluginManager : NSObject
+ (instancetype)shared;
@property (nonatomic, weak) id<QPluginHost> host;
@property (nonatomic, readonly) NSArray<QPluginInfo *> *plugins;

// Handles used in NppData.
+ (void *)nppHandle;
+ (void *)mainScintillaHandle;
+ (void *)secondScintillaHandle;

- (void)loadPlugins;
// Adds one submenu per plugin to menu (after removing previous plugin items).
- (void)populateMenu:(NSMenu *)menu;
- (BOOL)runCommandID:(int)cmdID;
- (BOOL)isPluginCommandID:(int)cmdID;
- (void)setCommand:(int)cmdID checked:(BOOL)checked;
- (NSString *)titleForCommandID:(int)cmdID;
// Finds a command by plugin name and menu item title (0 when not found).
- (int)commandIDForPlugin:(NSString *)pluginName title:(NSString *)title;

// Notifications
- (void)notify:(unsigned int)code bufferID:(uintptr_t)bufferID;
- (void)notify:(unsigned int)code from:(void *)hwndFrom idFrom:(uintptr_t)idFrom;
- (void)forwardScintillaNotification:(const SCNotification *)notification;
- (intptr_t)broadcastMessage:(unsigned int)msg wParam:(uintptr_t)w lParam:(intptr_t)l;
// NPPM_MSGTOPLUGIN: sends to the plugin with the given module file name.
- (BOOL)sendToPlugin:(NSString *)moduleName msg:(unsigned int)msg wParam:(uintptr_t)w lParam:(intptr_t)l;

// Scintilla views created by plugins (NPPM_CREATESCINTILLAHANDLE).
- (ScintillaView *)createScintillaView;
- (void)registerScintillaView:(ScintillaView *)view;
- (ScintillaView *)viewForHandle:(void *)handle;

// Allocations
- (int)allocateCommandIDs:(int)count;
- (int)allocateMarkers:(int)count;
- (int)allocateIndicators:(int)count;

// Folders
+ (NSString *)userPluginDirectory;
+ (NSString *)pluginConfigDirectory;
+ (NSArray<NSString *> *)disabledPluginFiles;
+ (void)setPluginFile:(NSString *)fileName disabled:(BOOL)disabled;
@end
