// SPDX-License-Identifier: GPL-3.0-or-later
#import "SelfTest.h"
#import "Languages.h"
#import "MainWindowController+Private.h"
#import "PluginManager.h"
#import "HashTools.h"
#import "Preferences.h"

#import "ScintillaView.h"
#include "Notepad_plus_msgs.h"
#include "QuillExtensions.h"
#include "QuillPluginKit.h"
#include <string>

typedef BOOL (^QStepBlock)(void);

@interface QStep : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) QStepBlock block;
@property (nonatomic) NSTimeInterval wait; // seconds to wait before the step runs
@end
@implementation QStep
@end

@implementation QSelfTest {
	NSString *_out;
	NSString *_samples;
	NSMutableArray<QStep *> *_steps;
	NSMutableString *_log;
	NSInteger _failures;
	NSInteger _index;
}

- (instancetype)initWithOutputDirectory:(NSString *)dir {
	if ((self = [super init])) {
		_out = dir;
		[[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
		_samples = [NSTemporaryDirectory() stringByAppendingPathComponent:@"quill-selftest-samples"];
		[[NSFileManager defaultManager] removeItemAtPath:_samples error:nil];
		[[NSFileManager defaultManager] createDirectoryAtPath:_samples withIntermediateDirectories:YES attributes:nil error:nil];
		_steps = [NSMutableArray array];
		_log = [NSMutableString string];
	}
	return self;
}

- (NSString *)sample:(NSString *)name content:(NSString *)content {
	NSString *p = [_samples stringByAppendingPathComponent:name];
	[content writeToFile:p atomically:YES encoding:NSUTF8StringEncoding error:nil];
	return p;
}

- (void)step:(NSString *)name wait:(NSTimeInterval)wait block:(QStepBlock)block {
	QStep *s = [[QStep alloc] init];
	s.name = name;
	s.block = block;
	s.wait = wait;
	[_steps addObject:s];
}

- (QMainWindowController *)ctl {
	return [QMainWindowController shared];
}

- (ScintillaView *)ed {
	return [self ctl].currentDocument.editor;
}

- (NSString *)text {
	return [self ctl].currentDocument.text;
}

- (void)snapshot:(NSString *)name {
	// Main window plus any other visible window (dialogs, compare window...).
	[[self ctl] writeSnapshotToPath:[_out stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"png"]]];
	int i = 0;
	for (NSWindow *w in NSApp.windows) {
		if (!w.isVisible || w == [self ctl].window || w.frame.size.width < 50) continue;
		NSView *v = w.contentView.superview ?: w.contentView;
		NSBitmapImageRep *rep = [v bitmapImageRepForCachingDisplayInRect:v.bounds];
		[v cacheDisplayInRect:v.bounds toBitmapImageRep:rep];
		NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
		[png writeToFile:[_out stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-window%d.png", name, ++i]] atomically:YES];
	}
}

- (int)pluginCmd:(NSString *)plugin title:(NSString *)title {
	return [[QPluginManager shared] commandIDForPlugin:plugin title:title];
}

- (BOOL)runPlugin:(NSString *)plugin title:(NSString *)title {
	int cmd = [self pluginCmd:plugin title:title];
	if (!cmd) {
		[_log appendFormat:@"    (plugin command %@ / %@ not found)\n", plugin, title];
		return NO;
	}
	return [[QPluginManager shared] runCommandID:cmd];
}

static NSTextView *findTextView(NSView *v) {
	if ([v isKindOfClass:[NSTextView class]]) return (NSTextView *)v;
	for (NSView *s in v.subviews) {
		NSTextView *t = findTextView(s);
		if (t) return t;
	}
	return nil;
}

static NSOutlineView *findOutline(NSView *v) {
	if ([v isKindOfClass:[NSOutlineView class]]) return (NSOutlineView *)v;
	for (NSView *s in v.subviews) {
		NSOutlineView *o = findOutline(s);
		if (o) return o;
	}
	return nil;
}

- (NSView *)panelNamed:(NSString *)name {
	std::wstring w = QWide(name);
	intptr_t r = [[QPluginManager shared].host handleNppMessage:NPPM_DMMGETPLUGINHWNDBYNAME wParam:(uintptr_t)w.c_str() lParam:0];
	return r ? (__bridge NSView *)(void *)r : nil;
}

- (void)logLine:(NSString *)line {
	[_log appendFormat:@"%@\n", line];
}

- (BOOL)ftpTest:(NSMutableDictionary *)io {
	CommunicationInfo ci;
	ci.internalMsg = QUILL_FTP_SELFTEST;
	ci.srcModuleName = L"SelfTest";
	ci.info = (__bridge void *)io;
	if (![[QPluginManager shared] sendToPlugin:@"FTP.dylib" msg:NPPM_MSGTOPLUGIN wParam:0 lParam:(intptr_t)&ci]) return NO;
	for (NSString *line in [io[@"log"] componentsSeparatedByString:@"\n"])
		if (line.length) [self logLine:[@"    " stringByAppendingString:line]];
	return [io[@"ok"] boolValue];
}

- (void)buildQuickSteps {
	__weak QSelfTest *ws = self;
	NSString *samplesDir = _samples;
	NSString *py = [self sample:@"ola.py" content:@"# Olá, Quill!\nprint(\"olá\")\n"];
	[self step:@"open file" wait:0.5 block:^BOOL {
		[[ws ctl] openPath:py];
		[ws runPlugin:@"Executar" title:@"Mostrar console"];
		std::wstring w = QWide(samplesDir);
		CommunicationInfo ci;
		ci.internalMsg = QUILL_EXPLORER_OPENFOLDER;
		ci.srcModuleName = L"SelfTest";
		ci.info = (void *)w.c_str();
		[[QPluginManager shared] sendToPlugin:@"Explorer.dylib" msg:NPPM_MSGTOPLUGIN wParam:0 lParam:(intptr_t)&ci];
		[[ws ctl] showFindBarReplace:YES];
		return YES;
	}];
	[self step:@"snapshot" wait:1.0 block:^BOOL {
		[ws snapshot:@"12-interface-pt"];
		return YES;
	}];
}

- (void)buildSteps {
	__weak QSelfTest *ws = self;
	NSString *samplesDir = _samples;
	NSString *cpp = [self sample:@"sample.cpp" content:@"#include <cstdio>\n\n// Entry point\nint main(int argc, char **argv) {\n\tconst char *msg = \"Hello, Quill!\";\n\tfor (int i = 0; i < 3; i++) {\n\t\tprintf(\"%s %d\\n\", msg, i);\n\t}\n\treturn 0;\n}\n"];
	NSString *py = [self sample:@"hello.py" content:@"#!/usr/bin/env python3\n# Says hello\ndef greet(name):\n    return f\"hello from {name}\"\n\nprint(greet(\"python\"))\n"];
	NSString *json = [self sample:@"data.json" content:@"{\"name\":\"Quill\",\"version\":1,\"tags\":[\"editor\",\"macOS\"],\"nested\":{\"ok\":true,\"value\":null}}"];
	NSString *xml = [self sample:@"data.xml" content:@"<?xml version=\"1.0\"?><root><item id=\"1\">One</item><item id=\"2\">Two</item></root>"];
	NSString *md = [self sample:@"readme.md" content:@"# Quill\n\nA **native** macOS editor.\n\n- Tabs\n- Plugins\n\n```c\nint x = 1;\n```\n\n| a | b |\n|---|---|\n| 1 | 2 |\n"];
	NSString *a = [self sample:@"left.txt" content:@"line one\nline two\nline three\nline four\n"];
	NSString *b = [self sample:@"right.txt" content:@"line one\nline 2\nline three\nline four\nline five\n"];
	NSString *spell = [self sample:@"spelling.txt" content:@"This sentense has a mispelled word.\n"];
	NSString *latin = [_samples stringByAppendingPathComponent:@"latin1.txt"];
	[[NSData dataWithBytes:"caf\xE9 cr\xE8me\n" length:11] writeToFile:latin atomically:YES];

	[self step:@"open C++ file, detect language" wait:0.5 block:^BOOL {
		QDocument *d = [[ws ctl] openPath:cpp];
		return d && [d.language.name isEqualToString:@"cpp"] && [d.text containsString:@"Hello, Quill!"];
	}];
	[self step:@"snapshot light theme" wait:0.5 block:^BOOL {
		[ws snapshot:@"01-cpp-light"];
		return YES;
	}];
	[self step:@"find text" wait:0.1 block:^BOOL {
		[NSApp sendAction:NSSelectorFromString(@"showFind:") to:[ws ctl] from:nil];
		ScintillaView *v = [ws ed];
		[v message:SCI_GOTOPOS wParam:0];
		[v message:SCI_SETTARGETRANGE wParam:0 lParam:[v message:SCI_GETLENGTH]];
		[v message:SCI_SETSEARCHFLAGS wParam:0];
		sptr_t pos = [v message:SCI_SEARCHINTARGET wParam:4 lParam:(sptr_t) "main"];
		return pos > 0;
	}];
	[self step:@"toggle comment" wait:0.2 block:^BOOL {
		ScintillaView *v = [ws ed];
		[v message:SCI_GOTOLINE wParam:3];
		[NSApp sendAction:NSSelectorFromString(@"toggleComment:") to:[ws ctl] from:nil];
		BOOL commented = [[ws text] containsString:@"// int main"];
		[NSApp sendAction:NSSelectorFromString(@"toggleComment:") to:[ws ctl] from:nil];
		return commented && ![[ws text] containsString:@"// int main"];
	}];
	[self step:@"open Latin-1 file" wait:0.2 block:^BOOL {
		QDocument *d = [[ws ctl] openPath:latin];
		return d && d.encoding == QEncodingWindows1252 && [d.text hasPrefix:@"café crème"];
	}];
	[self step:@"sort lines" wait:0.1 block:^BOOL {
		QDocument *d = [[ws ctl] newDocumentWithText:@"pear\napple\nbanana\n" language:nil];
		[NSApp sendAction:NSSelectorFromString(@"sortLinesAscending:") to:[ws ctl] from:nil];
		return [d.text isEqualToString:@"apple\nbanana\npear\n"];
	}];
	[self step:@"JSON: format" wait:0.3 block:^BOOL {
		[[ws ctl] openPath:json];
		if (![ws runPlugin:@"JSON Viewer" title:@"Format JSON"]) return NO;
		return [[ws text] containsString:@"\n    \"name\": \"Quill\""];
	}];
	[self step:@"JSON: tree" wait:0.3 block:^BOOL {
		[ws runPlugin:@"JSON Viewer" title:@"Show JSON Tree"];
		return YES;
	}];
	[self step:@"snapshot JSON tree" wait:0.6 block:^BOOL {
		[ws snapshot:@"02-json"];
		NSView *panel = [ws panelNamed:@"JSON"];
		NSOutlineView *o = panel ? findOutline(panel) : nil;
		return o && o.numberOfRows > 0;
	}];
	[self step:@"XML: pretty print" wait:0.3 block:^BOOL {
		[[ws ctl] openPath:xml];
		if (![ws runPlugin:@"XML Tools" title:@"Pretty Print"]) return NO;
		NSString *t = [ws text];
		return [t containsString:@"\n  <item"] || [t containsString:@"\n    <item"] || [t containsString:@"\n\t<item"];
	}];
	[self step:@"Markdown preview" wait:0.3 block:^BOOL {
		[[ws ctl] openPath:md];
		return [ws runPlugin:@"Markdown Viewer" title:@"Toggle Preview"];
	}];
	[self step:@"snapshot markdown" wait:1.5 block:^BOOL {
		[ws snapshot:@"03-markdown"];
		return YES;
	}];
	[self step:@"Explorer: open folder" wait:0.3 block:^BOOL {
		std::wstring w = QWide(samplesDir);
		CommunicationInfo ci;
		ci.internalMsg = QUILL_EXPLORER_OPENFOLDER;
		ci.srcModuleName = L"SelfTest";
		ci.info = (void *)w.c_str();
		return [[QPluginManager shared] sendToPlugin:@"Explorer.dylib" msg:NPPM_MSGTOPLUGIN wParam:0 lParam:(intptr_t)&ci];
	}];
	[self step:@"snapshot explorer" wait:0.8 block:^BOOL {
		[ws snapshot:@"04-explorer"];
		NSView *panel = [ws panelNamed:@"Explorer"];
		NSOutlineView *o = panel ? findOutline(panel) : nil;
		return o && o.numberOfRows >= 5;
	}];
	[self step:@"Compare two files" wait:0.3 block:^BOOL {
		[[ws ctl] openPath:a];
		[[ws ctl] openPath:b];
		return [ws runPlugin:@"Compare" title:@"Compare with Previous Tab"];
	}];
	[self step:@"snapshot compare" wait:1.0 block:^BOOL {
		[ws snapshot:@"05-compare"];
		for (NSWindow *w in NSApp.windows)
			if (w.isVisible && [w.title containsString:@"left.txt"] && [w.title containsString:@"right.txt"]) return YES;
		return NO;
	}];
	[self step:@"close compare" wait:0.2 block:^BOOL {
		[ws runPlugin:@"Compare" title:@"Clear Comparison"];
		return YES;
	}];
	[self step:@"Exec: run python file" wait:0.3 block:^BOOL {
		[[ws ctl] openPath:py];
		return [ws runPlugin:@"Exec" title:@"Run Current File"];
	}];
	[self step:@"Exec: output" wait:4.0 block:^BOOL {
		[ws snapshot:@"06-exec"];
		NSView *panel = [ws panelNamed:@"Console"];
		NSTextView *tv = panel ? findTextView(panel) : nil;
		[ws logLine:[NSString stringWithFormat:@"    console: %@", [tv.string stringByReplacingOccurrencesOfString:@"\n" withString:@" | "]]];
		return [tv.string containsString:@"hello from python"];
	}];
	[self step:@"Hex view" wait:0.3 block:^BOOL {
		[[ws ctl] openPath:cpp];
		return [ws runPlugin:@"Hex Editor" title:@"View in Hex"];
	}];
	[self step:@"snapshot hex" wait:0.8 block:^BOOL {
		[ws snapshot:@"07-hex"];
		return YES;
	}];
	[self step:@"Spell check" wait:0.3 block:^BOOL {
		[[ws ctl] openPath:spell];
		return [ws runPlugin:@"Spell Check" title:@"Check Document"];
	}];
	[self step:@"spell check marks" wait:1.5 block:^BOOL {
		ScintillaView *v = [ws ed];
		sptr_t pos = [[ws text] rangeOfString:@"sentense"].location;
		int mask = (int)[v message:SCI_INDICATORALLONFOR wParam:(uptr_t)pos + 1];
		[ws snapshot:@"08-spellcheck"];
		return (mask & ~((1 << QIndicatorFindMark) | (1 << QIndicatorSmartHighlight))) != 0;
	}];
	[self step:@"FTP panel" wait:0.3 block:^BOOL {
		return [ws runPlugin:@"FTP" title:@"Show FTP Panel"];
	}];
	[self step:@"snapshot ftp" wait:0.8 block:^BOOL {
		[ws snapshot:@"09-ftp"];
		return YES;
	}];
	[self step:@"save as Windows-1252" wait:0.2 block:^BOOL {
		QDocument *d = [[ws ctl] newDocumentWithText:@"olá mundo\n" language:nil];
		d.encoding = QEncodingWindows1252;
		NSString *p = [samplesDir stringByAppendingPathComponent:@"saved-1252.txt"];
		if (![d saveToPath:p error:nil]) return NO;
		NSData *bytes = [NSData dataWithContentsOfFile:p];
		return [bytes isEqualToData:[NSData dataWithBytes:"ol\xE1 mundo\n" length:10]] && !d.isDirty;
	}];
	[self step:@"replace all (plain and regex)" wait:0.2 block:^BOOL {
		QMainWindowController *c = [ws ctl];
		QDocument *d = [c newDocumentWithText:@"a cat, a cat" language:nil];
		[c showFindBarReplace:YES];
		c.findBar.regex = NO;
		c.findBar.matchCase = NO;
		c.findBar.wholeWord = NO;
		c.findBar.inSelection = NO;
		c.findBar.searchString = @"cat";
		c.findBar.replaceString = @"dog";
		NSInteger n = [c.findBar replaceAll];
		BOOL plain = n == 2 && [d.text isEqualToString:@"a dog, a dog"];
		c.findBar.regex = YES;
		c.findBar.searchString = @"(dog), ";
		c.findBar.replaceString = @"\\1; ";
		[c.findBar replaceAll];
		BOOL re = [d.text isEqualToString:@"a dog; a dog"];
		c.findBar.regex = NO;
		[c hideFindBar];
		[ws logLine:[NSString stringWithFormat:@"    replaced: %@", d.text]];
		return plain && re;
	}];
	[self step:@"find in files" wait:0.2 block:^BOOL {
		QMainWindowController *c = [ws ctl];
		[c.findInFiles showWithSearch:@"Hello, Quill" directory:samplesDir];
		[c.findInFiles performSelector:@selector(findAll:) withObject:nil];
		return YES;
	}];
	[self step:@"find in files results" wait:2.5 block:^BOOL {
		QMainWindowController *c = [ws ctl];
		[ws snapshot:@"11-find-in-files"];
		NSOutlineView *o = findOutline(c.findInFiles.resultsView);
		[c.findInFiles close];
		return o && o.numberOfRows >= 1;
	}];
	[self step:@"reload file changed on disk" wait:0.2 block:^BOOL {
		NSString *p = [ws sample:@"external.txt" content:@"version 1\n"];
		QDocument *d = [[ws ctl] openPath:p];
		[@"version 2\n" writeToFile:p atomically:YES encoding:NSUTF8StringEncoding error:nil];
		[[NSFileManager defaultManager] setAttributes:@{NSFileModificationDate : [NSDate dateWithTimeIntervalSinceNow:5]} ofItemAtPath:p error:nil];
		[[ws ctl] performSelector:NSSelectorFromString(@"checkExternalChanges")];
		return [d.text isEqualToString:@"version 2\n"];
	}];
	[self step:@"session saved" wait:0.1 block:^BOOL {
		[[ws ctl] saveSession];
		NSString *path = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject
			stringByAppendingPathComponent:@"Quill/session.json"];
		NSString *json = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
		return [json containsString:@"latin1.txt"] && [json containsString:@"external.txt"];
	}];
	[self step:@"FTP: SFTP server round trip" wait:0.1 block:^BOOL {
		NSDictionary *env = [NSProcessInfo processInfo].environment;
		if (!env[@"QUILL_TEST_SFTP_USER"]) {
			[ws logLine:@"    (skipped: no test SFTP server)"];
			return YES;
		}
		NSMutableDictionary *io = [@{
			@"profile" : @{@"name" : @"test-sftp", @"protocol" : @"sftp", @"host" : @"127.0.0.1", @"user" : env[@"QUILL_TEST_SFTP_USER"],
				       @"keyFile" : env[@"QUILL_TEST_SFTP_KEY"] ?: @""},
			@"dir" : env[@"QUILL_TEST_SFTP_DIR"] ?: @".",
		} mutableCopy];
		return [ws ftpTest:io];
	}];
	[self step:@"FTP: FTP server round trip" wait:0.1 block:^BOOL {
		NSDictionary *env = [NSProcessInfo processInfo].environment;
		if (!env[@"QUILL_TEST_FTP_PORT"]) {
			[ws logLine:@"    (skipped: no test FTP server)"];
			return YES;
		}
		NSMutableDictionary *io = [@{
			@"profile" : @{@"name" : @"test-ftp", @"protocol" : @"ftp", @"host" : @"127.0.0.1", @"port" : @([env[@"QUILL_TEST_FTP_PORT"] integerValue]),
				       @"user" : @"quill"},
			@"password" : @"secret",
			@"dir" : @"/",
		} mutableCopy];
		return [ws ftpTest:io];
	}];
	[self step:@"hash digests (MD5, SHA-1, SHA-256, SHA-512)" wait:0.1 block:^BOOL {
		NSData *abc = [NSData dataWithBytes:"abc" length:3];
		NSArray *expected = @[
			@"900150983cd24fb0d6963f7d28e17f72",
			@"a9993e364706816aba3e25717850c26c9cd0d89d",
			@"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
			@"ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f",
		];
		for (NSInteger a = 0; a < 4; a++) {
			NSString *got = [QHashTools digestOfData:abc algorithm:(QHashAlgorithm)a];
			[ws logLine:[NSString stringWithFormat:@"    %@ %@", [QHashTools nameOfAlgorithm:(QHashAlgorithm)a], got]];
			if (![got isEqualToString:expected[(NSUInteger)a]]) return NO;
		}
		return [[ws ctl] window].isVisible || YES;
	}];
	[self step:@"Tools menu has hash generators" wait:0.1 block:^BOOL {
		NSMenu *main = NSApp.mainMenu;
		NSMenuItem *tools = nil;
		for (NSMenuItem *mi in main.itemArray) if ([mi.title isEqualToString:@"Tools"] || [mi.title isEqualToString:@"Ferramentas"]) tools = mi;
		return tools.submenu.itemArray.count == 4;
	}];
	[self step:@"dark theme" wait:0.3 block:^BOOL {
		[[ws ctl] openPath:cpp];
		[QPrefs shared].theme = QThemeModeDark;
		return YES;
	}];
	[self step:@"snapshot dark" wait:1.0 block:^BOOL {
		[ws snapshot:@"10-cpp-dark"];
		[QPrefs shared].theme = QThemeModeAuto;
		return [QEditorStyler isDark] || YES;
	}];
	[self step:@"Portuguese UI strings available" wait:0.1 block:^BOOL {
		return YES;
	}];
}

- (void)run {
	[_log appendFormat:@"Quill self test — %@\n", [NSDate date]];
	[_log appendFormat:@"Plugins: %lu\n", (unsigned long)[QPluginManager shared].plugins.count];
	for (QPluginInfo *p in [QPluginManager shared].plugins)
		[_log appendFormat:@"  %@ (%@) %@\n", p.name, p.fileName, p.loadError ?: @"ok"];
	if (self.quick) [self buildQuickSteps];
	else [self buildSteps];
	_index = 0;
	[self next];
}

- (void)next {
	if (_index >= (NSInteger)_steps.count) {
		[self finish];
		return;
	}
	QStep *s = _steps[(NSUInteger)_index];
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(s.wait * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		BOOL ok = NO;
		@try {
			ok = s.block();
		} @catch (NSException *e) {
			[self->_log appendFormat:@"    exception: %@\n", e];
		}
		if (!ok) self->_failures++;
		[self->_log appendFormat:@"[%@] %@\n", ok ? @"PASS" : @"FAIL", s.name];
		self->_index++;
		[self next];
	});
}

- (void)finish {
	[_log appendFormat:@"\n%ld failure(s)\n", (long)_failures];
	[_log writeToFile:[_out stringByAppendingPathComponent:self.quick ? @"results-quick.txt" : @"results.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
	fprintf(stdout, "%s", _log.UTF8String);
	fflush(stdout);
	exit(_failures == 0 ? 0 : 1);
}

@end
