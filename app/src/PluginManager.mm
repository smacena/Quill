// SPDX-License-Identifier: GPL-3.0-or-later
#import "PluginManager.h"
#import "Languages.h"
#import "Localization.h"

#import "ScintillaView.h"
#include <dlfcn.h>
#include <algorithm>
#include <map>
#include <string>
#include <vector>

#include "PluginInterface.h"
#include "QuillExtensions.h"
#include "QuillPluginKit.h"

static char gNppTag, gSciMainTag, gSciSecondTag;

@implementation QPluginInfo
@end

namespace {
struct LoadedPlugin {
	void *handle = nullptr;
	NSString *name = nil;
	NSString *file = nil;
	PFUNCSETINFO setInfo = nullptr;
	PFUNCGETNAME getName = nullptr;
	PFUNCGETFUNCSARRAY getFuncsArray = nullptr;
	PBENOTIFIED beNotified = nullptr;
	PMESSAGEPROC messageProc = nullptr;
	FuncItem *items = nullptr;
	int count = 0;
};
struct CommandRef {
	size_t plugin;
	int item;
};
} // namespace

@implementation QPluginManager {
	std::vector<LoadedPlugin> _loaded;
	std::map<int, CommandRef> _commands;
	NSMutableArray<QPluginInfo *> *_infos;
	NSHashTable<ScintillaView *> *_views;
	NSMutableArray<NSMenuItem *> *_menuItems;
	int _nextCmdID;
	int _nextDynamicCmdID;
	int _nextMarker;
	int _nextIndicator;
	BOOL _notifying;
}

+ (instancetype)shared {
	static QPluginManager *m;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		m = [[QPluginManager alloc] init];
	});
	return m;
}

+ (void *)nppHandle {
	return &gNppTag;
}
+ (void *)mainScintillaHandle {
	return &gSciMainTag;
}
+ (void *)secondScintillaHandle {
	return &gSciSecondTag;
}

- (instancetype)init {
	if ((self = [super init])) {
		_infos = [NSMutableArray array];
		_views = [NSHashTable weakObjectsHashTable];
		_menuItems = [NSMutableArray array];
		_nextCmdID = 22000;        // ID_PLUGINS_CMD in Notepad++
		_nextDynamicCmdID = 23000; // ID_PLUGINS_CMD_DYNAMIC
		_nextMarker = QMarkerFirstPlugin;
		_nextIndicator = QIndicatorFirstPlugin;
	}
	return self;
}

- (NSArray<QPluginInfo *> *)plugins {
	return _infos;
}

+ (NSString *)userPluginDirectory {
	NSString *base = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject
		stringByAppendingPathComponent:@"Quill/plugins"];
	[[NSFileManager defaultManager] createDirectoryAtPath:base withIntermediateDirectories:YES attributes:nil error:nil];
	return base;
}

+ (NSString *)pluginConfigDirectory {
	NSString *dir = [[self userPluginDirectory] stringByAppendingPathComponent:@"Config"];
	[[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
	return dir;
}

+ (NSArray<NSString *> *)disabledPluginFiles {
	return [[NSUserDefaults standardUserDefaults] stringArrayForKey:@"disabledPlugins"] ?: @[];
}

+ (void)setPluginFile:(NSString *)fileName disabled:(BOOL)disabled {
	NSMutableSet *set = [NSMutableSet setWithArray:[self disabledPluginFiles]];
	if (disabled) [set addObject:fileName];
	else [set removeObject:fileName];
	[[NSUserDefaults standardUserDefaults] setObject:set.allObjects forKey:@"disabledPlugins"];
}

- (NSArray<NSString *> *)candidateFiles:(NSString *)dir {
	NSMutableArray *files = [NSMutableArray array];
	NSFileManager *fm = [NSFileManager defaultManager];
	for (NSString *entry in [[fm contentsOfDirectoryAtPath:dir error:nil] sortedArrayUsingSelector:@selector(compare:)]) {
		NSString *full = [dir stringByAppendingPathComponent:entry];
		BOOL isDir = NO;
		[fm fileExistsAtPath:full isDirectory:&isDir];
		if (!isDir && [entry.pathExtension isEqualToString:@"dylib"]) {
			[files addObject:full];
		} else if (isDir && ![entry isEqualToString:@"Config"]) {
			// Notepad++ layout: plugins/<Name>/<Name>.dylib
			NSString *inner = [full stringByAppendingPathComponent:[entry stringByAppendingPathExtension:@"dylib"]];
			if ([fm fileExistsAtPath:inner]) [files addObject:inner];
		}
	}
	return files;
}

- (void)loadPlugins {
	NSArray *disabled = [QPluginManager disabledPluginFiles];
	NSMutableArray<NSString *> *paths = [NSMutableArray array];
	NSMutableSet<NSString *> *seenNames = [NSMutableSet set];
	NSString *builtInDir = [NSBundle mainBundle].builtInPlugInsPath;
	NSArray *builtIn = builtInDir ? [self candidateFiles:builtInDir] : @[];
	[paths addObjectsFromArray:builtIn];
	[paths addObjectsFromArray:[self candidateFiles:[QPluginManager userPluginDirectory]]];

	NppData data;
	data._nppHandle = &gNppTag;
	data._scintillaMainHandle = &gSciMainTag;
	data._scintillaSecondHandle = &gSciSecondTag;

	for (NSString *path in paths) {
		QPluginInfo *info = [[QPluginInfo alloc] init];
		info.path = path;
		info.fileName = path.lastPathComponent;
		info.builtIn = [builtIn containsObject:path];
		info.name = path.lastPathComponent.stringByDeletingPathExtension;
		info.enabled = ![disabled containsObject:info.fileName];
		[_infos addObject:info];
		if (!info.enabled) continue;
		if ([seenNames containsObject:info.fileName]) {
			info.loadError = T(@"A plugin with the same file name is already loaded.", @"Já existe um plugin carregado com o mesmo nome de arquivo.");
			info.enabled = NO;
			continue;
		}
		void *h = dlopen(path.fileSystemRepresentation, RTLD_NOW | RTLD_LOCAL);
		if (!h) {
			const char *err = dlerror();
			info.loadError = err ? @(err) : @"dlopen failed";
			NSLog(@"Quill: cannot load plugin %@: %@", path, info.loadError);
			continue;
		}
		LoadedPlugin p;
		p.handle = h;
		p.file = info.fileName;
		p.setInfo = (PFUNCSETINFO)dlsym(h, "setInfo");
		p.getName = (PFUNCGETNAME)dlsym(h, "getName");
		p.getFuncsArray = (PFUNCGETFUNCSARRAY)dlsym(h, "getFuncsArray");
		p.beNotified = (PBENOTIFIED)dlsym(h, "beNotified");
		p.messageProc = (PMESSAGEPROC)dlsym(h, "messageProc");
		if (!p.setInfo || !p.getName || !p.getFuncsArray || !p.beNotified || !p.messageProc) {
			info.loadError = T(@"Not a Quill / Notepad++ plugin (missing exported functions).", @"Não é um plugin Quill / Notepad++ (funções exportadas ausentes).");
			dlclose(h);
			continue;
		}
		@try {
			p.setInfo(data);
			const wchar_t *wname = p.getName();
			p.name = wname ? QStr(std::wstring(wname)) : info.name;
			p.items = p.getFuncsArray(&p.count);
		} @catch (NSException *e) {
			info.loadError = e.reason;
			continue;
		}
		info.name = p.name;
		[seenNames addObject:info.fileName];
		size_t index = _loaded.size();
		for (int i = 0; i < p.count; i++) {
			p.items[i]._cmdID = _nextCmdID++;
			_commands[p.items[i]._cmdID] = CommandRef{index, i};
		}
		_loaded.push_back(p);
	}
}

static NSString *keyEquivalentForVK(unsigned char vk) {
	if ((vk >= '0' && vk <= '9') || (vk >= 'A' && vk <= 'Z')) return [[NSString stringWithFormat:@"%c", vk] lowercaseString];
	if (vk >= 0x70 && vk <= 0x7B) {
		unichar f = (unichar)(NSF1FunctionKey + (vk - 0x70));
		return [NSString stringWithCharacters:&f length:1];
	}
	switch (vk) {
	case 0xBA: return @";";
	case 0xBB: return @"=";
	case 0xBC: return @",";
	case 0xBD: return @"-";
	case 0xBE: return @".";
	case 0xBF: return @"/";
	case 0xC0: return @"`";
	case 0xDB: return @"[";
	case 0xDC: return @"\\";
	case 0xDD: return @"]";
	case 0xDE: return @"'";
	case 0x0D: return @"\r";
	case 0x20: return @" ";
	case 0x2E: {
		unichar c = NSDeleteFunctionKey;
		return [NSString stringWithCharacters:&c length:1];
	}
	}
	return @"";
}

- (void)populateMenu:(NSMenu *)menu {
	for (NSMenuItem *item in _menuItems) [menu removeItem:item];
	[_menuItems removeAllObjects];
	NSInteger insertAt = 0;
	std::vector<size_t> order(_loaded.size());
	for (size_t i = 0; i < order.size(); i++) order[i] = i;
	std::sort(order.begin(), order.end(), [&](size_t a, size_t b) {
		return [_loaded[a].name localizedCaseInsensitiveCompare:_loaded[b].name] == NSOrderedAscending;
	});
	for (size_t idx : order) {
		LoadedPlugin &p = _loaded[idx];
		NSMenuItem *top = [[NSMenuItem alloc] initWithTitle:p.name action:nil keyEquivalent:@""];
		NSMenu *sub = [[NSMenu alloc] initWithTitle:p.name];
		for (int i = 0; i < p.count; i++) {
			FuncItem &fi = p.items[i];
			std::wstring title(fi._itemName);
			if (!fi._pFunc || title.empty()) {
				[sub addItem:[NSMenuItem separatorItem]];
				continue;
			}
			NSMenuItem *mi = [[NSMenuItem alloc] initWithTitle:QStr(title) action:@selector(pluginMenuAction:) keyEquivalent:@""];
			mi.target = self;
			mi.tag = fi._cmdID;
			mi.state = fi._init2Check ? NSControlStateValueOn : NSControlStateValueOff;
			if (fi._pShKey && fi._pShKey->_key) {
				NSString *key = keyEquivalentForVK(fi._pShKey->_key);
				if (key.length) {
					NSEventModifierFlags mods = 0;
					if (fi._pShKey->_isCtrl) mods |= NSEventModifierFlagCommand;
					if (fi._pShKey->_isAlt) mods |= NSEventModifierFlagOption;
					if (fi._pShKey->_isShift) mods |= NSEventModifierFlagShift;
					mi.keyEquivalent = key;
					mi.keyEquivalentModifierMask = mods;
				}
			}
			[sub addItem:mi];
		}
		top.submenu = sub;
		[menu insertItem:top atIndex:insertAt++];
		[_menuItems addObject:top];
	}
	if (_loaded.empty()) {
		NSMenuItem *none = [[NSMenuItem alloc] initWithTitle:T(@"No plugins loaded", @"Nenhum plugin carregado") action:nil keyEquivalent:@""];
		none.enabled = NO;
		[menu insertItem:none atIndex:0];
		[_menuItems addObject:none];
	}
}

- (NSMenuItem *)menuItemForCommand:(int)cmdID {
	for (NSMenuItem *top in _menuItems)
		for (NSMenuItem *mi in top.submenu.itemArray)
			if (mi.tag == cmdID && mi.action == @selector(pluginMenuAction:)) return mi;
	return nil;
}

- (void)pluginMenuAction:(NSMenuItem *)sender {
	[self runCommandID:(int)sender.tag];
}

- (BOOL)isPluginCommandID:(int)cmdID {
	return _commands.count(cmdID) > 0;
}

- (BOOL)runCommandID:(int)cmdID {
	auto it = _commands.find(cmdID);
	if (it == _commands.end()) return NO;
	LoadedPlugin &p = _loaded[it->second.plugin];
	FuncItem &fi = p.items[it->second.item];
	if (fi._pFunc) fi._pFunc();
	return YES;
}

- (void)setCommand:(int)cmdID checked:(BOOL)checked {
	auto it = _commands.find(cmdID);
	if (it != _commands.end()) {
		LoadedPlugin &p = _loaded[it->second.plugin];
		p.items[it->second.item]._init2Check = checked;
	}
	[self menuItemForCommand:cmdID].state = checked ? NSControlStateValueOn : NSControlStateValueOff;
}

- (NSString *)titleForCommandID:(int)cmdID {
	auto it = _commands.find(cmdID);
	if (it == _commands.end()) return nil;
	LoadedPlugin &p = _loaded[it->second.plugin];
	return QStr(std::wstring(p.items[it->second.item]._itemName));
}

- (int)commandIDForPlugin:(NSString *)pluginName title:(NSString *)title {
	for (auto &p : _loaded) {
		if ([p.name caseInsensitiveCompare:pluginName] != NSOrderedSame) continue;
		for (int i = 0; i < p.count; i++) {
			NSString *t = QStr(std::wstring(p.items[i]._itemName));
			if ([t caseInsensitiveCompare:title] == NSOrderedSame || [t hasPrefix:title]) return p.items[i]._cmdID;
		}
	}
	return 0;
}

// ---- Notifications ---------------------------------------------------------------

- (void)notify:(unsigned int)code from:(void *)hwndFrom idFrom:(uintptr_t)idFrom {
	SCNotification n;
	memset(&n, 0, sizeof(n));
	n.nmhdr.hwndFrom = hwndFrom;
	n.nmhdr.idFrom = idFrom;
	n.nmhdr.code = code;
	for (auto &p : _loaded) {
		@try {
			p.beNotified(&n);
		} @catch (NSException *e) {
			NSLog(@"Quill: plugin %@ raised %@", p.name, e);
		}
	}
}

- (void)notify:(unsigned int)code bufferID:(uintptr_t)bufferID {
	[self notify:code from:&gNppTag idFrom:bufferID];
}

- (void)forwardScintillaNotification:(const SCNotification *)notification {
	if (_loaded.empty()) return;
	SCNotification n = *notification;
	n.nmhdr.hwndFrom = &gSciMainTag;
	for (auto &p : _loaded) p.beNotified(&n);
}

- (intptr_t)broadcastMessage:(unsigned int)msg wParam:(uintptr_t)w lParam:(intptr_t)l {
	intptr_t r = 0;
	for (auto &p : _loaded) r = p.messageProc(msg, w, l);
	return r;
}

- (BOOL)sendToPlugin:(NSString *)moduleName msg:(unsigned int)msg wParam:(uintptr_t)w lParam:(intptr_t)l {
	for (auto &p : _loaded) {
		if ([p.file caseInsensitiveCompare:moduleName] == NSOrderedSame ||
		    [p.file.stringByDeletingPathExtension caseInsensitiveCompare:moduleName.stringByDeletingPathExtension] == NSOrderedSame) {
			p.messageProc(msg, w, l);
			return YES;
		}
	}
	return NO;
}

// ---- Scintilla views ------------------------------------------------------------------

- (ScintillaView *)createScintillaView {
	ScintillaView *v = [[ScintillaView alloc] initWithFrame:NSMakeRect(0, 0, 400, 300)];
	v.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
	[QEditorStyler configureEditor:v];
	[QEditorStyler applyLanguage:[QLanguageManager shared].plainText toEditor:v];
	[_views addObject:v];
	// Plugins own the view; keep it alive until NPPM_DESTROYSCINTILLAHANDLE (deprecated) / app exit.
	static NSMutableArray *keep;
	if (!keep) keep = [NSMutableArray array];
	[keep addObject:v];
	return v;
}

- (void)registerScintillaView:(ScintillaView *)view {
	if (view) [_views addObject:view];
}

- (ScintillaView *)viewForHandle:(void *)handle {
	if (!handle) return nil;
	if (handle == &gSciMainTag || handle == &gSciSecondTag) return [self.host currentEditor];
	for (ScintillaView *v in _views)
		if ((__bridge void *)v == handle) return v;
	return nil;
}

// ---- Allocations -------------------------------------------------------------------------

- (int)allocateCommandIDs:(int)count {
	if (count <= 0) return 0;
	int start = _nextDynamicCmdID;
	_nextDynamicCmdID += count;
	return start;
}

- (int)allocateMarkers:(int)count {
	if (count <= 0 || _nextMarker + count - 1 > QMarkerLastPlugin) return 0;
	int start = _nextMarker;
	_nextMarker += count;
	return start;
}

- (int)allocateIndicators:(int)count {
	if (count <= 0 || _nextIndicator + count - 1 > QIndicatorLastPlugin) return 0;
	int start = _nextIndicator;
	_nextIndicator += count;
	return start;
}

@end

// ---- C entry points used by plugins ------------------------------------------------------

extern "C" __attribute__((visibility("default"), used)) LRESULT QuillSendMessage(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam) {
	QPluginManager *pm = [QPluginManager shared];
	if (hWnd == &gNppTag) return [pm.host handleNppMessage:msg wParam:wParam lParam:lParam];
	ScintillaView *v = [pm viewForHandle:hWnd];
	if (!v) return 0;
	return [v message:msg wParam:wParam lParam:lParam];
}

extern "C" __attribute__((visibility("default"), used)) int QuillMessageBox(HWND, const wchar_t *text, const wchar_t *caption, UINT type) {
	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = caption ? QStr(std::wstring(caption)) : @"Quill";
	alert.informativeText = text ? QStr(std::wstring(text)) : @"";
	UINT icon = type & 0xF0;
	alert.alertStyle = icon == MB_ICONERROR ? NSAlertStyleCritical : (icon == MB_ICONWARNING ? NSAlertStyleWarning : NSAlertStyleInformational);
	UINT buttons = type & 0x0F;
	switch (buttons) {
	case MB_OKCANCEL:
		[alert addButtonWithTitle:@"OK"];
		[alert addButtonWithTitle:T(@"Cancel", @"Cancelar")];
		return [alert runModal] == NSAlertFirstButtonReturn ? IDOK : IDCANCEL;
	case MB_YESNO:
		[alert addButtonWithTitle:T(@"Yes", @"Sim")];
		[alert addButtonWithTitle:T(@"No", @"Não")];
		return [alert runModal] == NSAlertFirstButtonReturn ? IDYES : IDNO;
	case MB_YESNOCANCEL: {
		[alert addButtonWithTitle:T(@"Yes", @"Sim")];
		[alert addButtonWithTitle:T(@"No", @"Não")];
		[alert addButtonWithTitle:T(@"Cancel", @"Cancelar")];
		NSModalResponse r = [alert runModal];
		return r == NSAlertFirstButtonReturn ? IDYES : (r == NSAlertSecondButtonReturn ? IDNO : IDCANCEL);
	}
	default:
		[alert addButtonWithTitle:@"OK"];
		[alert runModal];
		return IDOK;
	}
}
