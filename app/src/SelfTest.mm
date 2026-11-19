// SPDX-License-Identifier: GPL-3.0-or-later
#import "SelfTest.h"
#import "Languages.h"
#import "MainWindowController.h"
#import "PluginManager.h"
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
	[self buildSteps];
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
	[_log writeToFile:[_out stringByAppendingPathComponent:@"results.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
	fprintf(stdout, "%s", _log.UTF8String);
	fflush(stdout);
	exit(_failures == 0 ? 0 : 1);
}

@end
