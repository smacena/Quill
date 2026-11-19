// SPDX-License-Identifier: GPL-3.0-or-later
#import "AppDelegate.h"
#import "Localization.h"
#import "MainMenu.h"
#import "MainWindowController.h"
#import "PluginManager.h"
#import "PluginsWindow.h"
#import "Preferences.h"
#import "PreferencesWindow.h"
#import "SelfTest.h"

@implementation QAppDelegate {
	NSMutableArray<NSString *> *_pendingFiles;
	BOOL _launched;
	QPreferencesWindowController *_prefsWindow;
	QPluginsWindowController *_pluginsWindow;
	QSelfTest *_selfTest;
	BOOL _skipQuitPrompt;
}

- (void)applicationWillFinishLaunching:(NSNotification *)note {
	_pendingFiles = [NSMutableArray array];
	NSApp.mainMenu = [[QMainMenu shared] build];
}

- (void)applicationDidFinishLaunching:(NSNotification *)note {
	NSArray<NSString *> *args = [NSProcessInfo processInfo].arguments;
	NSUInteger st = [args indexOfObject:@"--selftest"];
	// Files passed on the command line (not -psn / defaults arguments).
	for (NSUInteger i = 1; i < args.count; i++) {
		NSString *a = args[i];
		if ([a hasPrefix:@"-"]) {
			if (i + 1 < args.count && ![a hasPrefix:@"-psn"] && ![a isEqualToString:@"--selftest"]) i++; // skip "-Key value"
			if ([a isEqualToString:@"--selftest"]) i++;
			continue;
		}
		if ([[NSFileManager defaultManager] fileExistsAtPath:a]) [_pendingFiles addObject:a.stringByStandardizingPath];
	}
	QMainWindowController *c = [QMainWindowController shared];
	if (st != NSNotFound) {
		NSString *outDir = st + 1 < args.count ? args[st + 1] : NSTemporaryDirectory();
		[c finishLaunchingWithFiles:@[]];
		_launched = YES;
		_selfTest = [[QSelfTest alloc] initWithOutputDirectory:outDir];
		[_selfTest run];
		return;
	}
	[c finishLaunchingWithFiles:_pendingFiles];
	[_pendingFiles removeAllObjects];
	_launched = YES;
}

- (void)application:(NSApplication *)sender openURLs:(NSArray<NSURL *> *)urls {
	for (NSURL *url in urls) {
		if (!url.isFileURL) continue;
		if (_launched) [self openPathOrFolder:url.path];
		else [_pendingFiles addObject:url.path];
	}
}

- (void)openPathOrFolder:(NSString *)path {
	BOOL isDir = NO;
	[[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir];
	QMainWindowController *c = [QMainWindowController shared];
	if (isDir) [c performSelector:NSSelectorFromString(@"openFolderInExplorer:") withObject:path];
	else [c openPath:path];
	[c showWindow:nil];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
	if (_selfTest || _skipQuitPrompt) return NSTerminateNow;
	return [[QMainWindowController shared] prepareForQuit] ? NSTerminateNow : NSTerminateCancel;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
	return NO;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
	[[QMainWindowController shared] showWindow:nil];
	return YES;
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
	return YES;
}

// ---- Actions that work whatever window is key ---------------------------------------------

- (void)newDocument:(id)sender {
	QMainWindowController *c = [QMainWindowController shared];
	[c showWindow:nil];
	[c newDocumentWithText:nil language:nil];
}

- (void)openDocument:(id)sender {
	NSOpenPanel *p = [NSOpenPanel openPanel];
	p.allowsMultipleSelection = YES;
	p.canChooseDirectories = YES;
	p.showsHiddenFiles = [[NSUserDefaults standardUserDefaults] boolForKey:@"openShowsHidden"];
	p.message = T(@"Choose files to open (a folder opens in the Explorer panel)", @"Escolha os arquivos (uma pasta abre no painel Explorador)");
	NSString *dir = [QMainWindowController shared].currentDocument.path.stringByDeletingLastPathComponent;
	if (dir) p.directoryURL = [NSURL fileURLWithPath:dir];
	if ([p runModal] != NSModalResponseOK) return;
	for (NSURL *url in p.URLs) [self openPathOrFolder:url.path];
}

- (void)showPreferences:(id)sender {
	if (!_prefsWindow) _prefsWindow = [[QPreferencesWindowController alloc] init];
	[_prefsWindow showWindow:nil];
	[_prefsWindow.window makeKeyAndOrderFront:nil];
}

- (void)setInterfaceLanguage:(NSMenuItem *)sender {
	QUILanguage lang = (QUILanguage)sender.tag;
	QSetLanguage(lang);
	if (lang == QCurrentLanguage()) return;
	NSAlert *a = [[NSAlert alloc] init];
	a.messageText = lang == QUILanguagePortuguese ? @"Reiniciar o Quill para usar Português?" : @"Restart Quill to use English?";
	a.informativeText = lang == QUILanguagePortuguese ? @"Seus arquivos abertos serão restaurados." : @"Your open files will be restored.";
	[a addButtonWithTitle:lang == QUILanguagePortuguese ? @"Reiniciar agora" : @"Restart Now"];
	[a addButtonWithTitle:lang == QUILanguagePortuguese ? @"Depois" : @"Later"];
	if ([a runModal] == NSAlertFirstButtonReturn) [self relaunch];
}

- (void)relaunch {
	if (![[QMainWindowController shared] prepareForQuit]) return;
	NSString *path = [NSBundle mainBundle].bundlePath;
	NSTask *task = [[NSTask alloc] init];
	task.launchPath = @"/bin/sh";
	task.arguments = @[ @"-c", [NSString stringWithFormat:@"sleep 1; /usr/bin/open -n \"%@\"", path] ];
	[task launch];
	_skipQuitPrompt = YES;
	[NSApp terminate:nil];
}

- (void)openPluginsFolder:(id)sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:[QPluginManager userPluginDirectory]]];
}

- (void)managePlugins:(id)sender {
	if (!_pluginsWindow) _pluginsWindow = [[QPluginsWindowController alloc] init];
	[_pluginsWindow showWindow:nil];
	[_pluginsWindow.window makeKeyAndOrderFront:nil];
}

- (void)openBundledDoc:(NSString *)name {
	NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:@"md"];
	if (path) [[QMainWindowController shared] openPath:path];
}

- (void)showHelp:(id)sender {
	[self openBundledDoc:QCurrentLanguage() == QUILanguagePortuguese ? @"README.pt-BR" : @"README"];
}

- (void)showPluginGuide:(id)sender {
	[self openBundledDoc:@"PLUGINS"];
}

- (BOOL)validateMenuItem:(NSMenuItem *)item {
	if (item.action == @selector(setInterfaceLanguage:)) {
		NSString *stored = [[NSUserDefaults standardUserDefaults] stringForKey:@"UILanguage"];
		QUILanguage effective = stored ? ([stored isEqualToString:@"pt"] ? QUILanguagePortuguese : QUILanguageEnglish) : QCurrentLanguage();
		item.state = item.tag == effective ? NSControlStateValueOn : NSControlStateValueOff;
	}
	return YES;
}

@end
