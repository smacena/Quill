// Markdown Viewer: live HTML preview of Markdown documents.
// SPDX-License-Identifier: GPL-3.0-or-later
#include "PluginCommon.h"
#include "quill/TextTools.h"
#import <WebKit/WebKit.h>

using namespace qp;

QUILL_PLUGIN_EXPORTS(L"Markdown Viewer", L"Visualizador Markdown")

@interface QMarkdownPanel : NSView <WKNavigationDelegate>
@property (nonatomic, strong) WKWebView *web;
@property (nonatomic, strong) NSTextField *placeholder;
- (void)render;
- (void)syncScroll;
@end

static QMarkdownPanel *gPanel;
static Panel gDock;
static int gToggleIndex = 0, gSyncIndex = 0, gAutoIndex = 0;

static NSUserDefaults *defaults() {
	return [NSUserDefaults standardUserDefaults];
}

static bool syncScrollOn() {
	return [defaults() objectForKey:@"Markdown.syncScroll"] ? [defaults() boolForKey:@"Markdown.syncScroll"] : true;
}

static bool autoOpenOn() {
	return [defaults() boolForKey:@"Markdown.autoOpen"];
}

static bool isMarkdownBuffer() {
	std::wstring lang = languageName();
	if (lang == L"markdown") return true;
	NSString *ext = QStr(host().currentPath()).pathExtension.lowercaseString;
	return [@[ @"md", @"markdown", @"mdown", @"mkd", @"mkdn", @"mdx" ] containsObject:ext];
}

static NSString *css() {
	return @"<style>"
	       ":root{color-scheme:light dark;--fg:#1f2328;--bg:#fff;--muted:#59636e;--border:#d1d9e0;--code:#f6f8fa;--link:#0969da}"
	       "@media (prefers-color-scheme:dark){:root{--fg:#e6edf3;--bg:#1e1e1e;--muted:#9198a1;--border:#3d444d;--code:#2a2d31;--link:#4493f8}}"
	       "body{font:15px/1.6 -apple-system,BlinkMacSystemFont,'Helvetica Neue',sans-serif;color:var(--fg);background:var(--bg);"
	       "max-width:860px;margin:0 auto;padding:20px 28px 60px;word-wrap:break-word}"
	       "h1,h2{border-bottom:1px solid var(--border);padding-bottom:.3em}h1,h2,h3,h4{line-height:1.25;margin:1.4em 0 .6em}"
	       "a{color:var(--link);text-decoration:none}a:hover{text-decoration:underline}"
	       "code,pre{font:13px/1.45 ui-monospace,SFMono-Regular,Menlo,monospace;background:var(--code);border-radius:6px}"
	       "code{padding:.15em .35em}pre{padding:14px 16px;overflow:auto}pre code{padding:0;background:none}"
	       "blockquote{margin:0;padding:0 1em;color:var(--muted);border-left:.25em solid var(--border)}"
	       "table{border-collapse:collapse;display:block;overflow:auto}th,td{border:1px solid var(--border);padding:6px 13px}"
	       "tr:nth-child(2n){background:var(--code)}img{max-width:100%}hr{border:0;border-top:1px solid var(--border);margin:24px 0}"
	       "ul.contains-task-list,li.task-list-item{list-style:none}input[type=checkbox]{margin-right:.4em}"
	       "</style>";
}

static NSString *fullHTML(NSString *body, NSString *title) {
	return [NSString stringWithFormat:@"<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>%@</title>%@</head><body>%@</body></html>",
					  title ?: @"", css(), body];
}

static void ensurePanel() {
	if (gPanel) return;
	gPanel = [[QMarkdownPanel alloc] initWithFrame:NSMakeRect(0, 0, 400, 600)];
	gDock.registerIn(gPanel, host().tr(L"Markdown Preview", L"Pré-visualização Markdown"), L"MarkdownViewer.dylib", gToggleIndex, DWS_DF_CONT_RIGHT);
}

static void cmdToggle() {
	ensurePanel();
	if (gDock.visible()) {
		gDock.hide();
		gCommands.setChecked(gToggleIndex, false);
	} else {
		gDock.show();
		gCommands.setChecked(gToggleIndex, true);
		[gPanel render];
	}
}

static void cmdExport() {
	std::string md = host().currentText();
	NSString *path = QStr(host().currentPath());
	NSString *html = fullHTML(QStr(quill::markdownToHtml(md)), path.lastPathComponent);
	NSSavePanel *p = [NSSavePanel savePanel];
	p.nameFieldStringValue = [path.lastPathComponent.stringByDeletingPathExtension stringByAppendingPathExtension:@"html"];
	if ([[NSFileManager defaultManager] fileExistsAtPath:path]) p.directoryURL = [NSURL fileURLWithPath:path.stringByDeletingLastPathComponent];
	if ([p runModal] != NSModalResponseOK) return;
	NSError *err = nil;
	if (![html writeToURL:p.URL atomically:YES encoding:NSUTF8StringEncoding error:&err]) [[NSAlert alertWithError:err] runModal];
	else status(QTR(@"HTML exported", @"HTML exportado"));
}

static void cmdCopyHTML() {
	std::string md = host().hasSelection() ? host().selectedText() : host().currentText();
	NSString *html = QStr(quill::markdownToHtml(md));
	NSPasteboard *pb = [NSPasteboard generalPasteboard];
	[pb clearContents];
	[pb setString:html forType:NSPasteboardTypeString];
	[pb setString:fullHTML(html, nil) forType:NSPasteboardTypeHTML];
	status(QTR(@"HTML copied to the clipboard", @"HTML copiado para a área de transferência"));
}

static void cmdSync() {
	BOOL v = !syncScrollOn();
	[defaults() setBool:v forKey:@"Markdown.syncScroll"];
	gCommands.setChecked(gSyncIndex, v);
}

static void cmdAuto() {
	BOOL v = !autoOpenOn();
	[defaults() setBool:v forKey:@"Markdown.autoOpen"];
	gCommands.setChecked(gAutoIndex, v);
}

static void scheduleRender() {
	if (!gPanel || !gDock.visible()) return;
	[NSObject cancelPreviousPerformRequestsWithTarget:gPanel selector:@selector(render) object:nil];
	[gPanel performSelector:@selector(render) withObject:nil afterDelay:0.35];
}

static void pluginInit() {}

static void pluginCommands(qp::Commands &c) {
	gToggleIndex = c.add(L"Toggle Preview", L"Alternar pré-visualização", cmdToggle, Commands::key('M', true, false, true));
	c.add(L"Export HTML…", L"Exportar HTML…", cmdExport);
	c.add(L"Copy HTML", L"Copiar HTML", cmdCopyHTML);
	c.separator();
	gSyncIndex = c.add(L"Synchronize Scrolling", L"Sincronizar rolagem", cmdSync, nullptr, syncScrollOn());
	gAutoIndex = c.add(L"Open Preview for Markdown Files", L"Abrir pré-visualização para arquivos Markdown", cmdAuto, nullptr, autoOpenOn());
}

static void pluginNotify(SCNotification *n) {
	switch (n->nmhdr.code) {
	case NPPN_BUFFERACTIVATED:
	case NPPN_LANGCHANGED:
		if (autoOpenOn() && isMarkdownBuffer()) {
			ensurePanel();
			if (!gDock.visible()) {
				gDock.show();
				gCommands.setChecked(gToggleIndex, true);
			}
		}
		scheduleRender();
		break;
	case SCN_MODIFIED:
		if (n->modificationType & (SC_MOD_INSERTTEXT | SC_MOD_DELETETEXT)) scheduleRender();
		break;
	case SCN_UPDATEUI:
		if ((n->updated & SC_UPDATE_V_SCROLL) && gPanel && gDock.visible() && syncScrollOn()) [gPanel syncScroll];
		break;
	case QUILLN_PANELCLOSED:
		if (gPanel && n->nmhdr.hwndFrom == (__bridge void *)gPanel) gCommands.setChecked(gToggleIndex, false);
		break;
	default:
		break;
	}
}

static LRESULT pluginMessage(UINT, WPARAM, LPARAM) {
	return TRUE;
}

@implementation QMarkdownPanel {
	NSString *_tempFile;
	NSString *_baseDir;
	BOOL _loaded;
}

- (instancetype)initWithFrame:(NSRect)frame {
	if ((self = [super initWithFrame:frame])) {
		WKWebViewConfiguration *cfg = [[WKWebViewConfiguration alloc] init];
		_web = [[WKWebView alloc] initWithFrame:self.bounds configuration:cfg];
		_web.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
		_web.navigationDelegate = self;
		[self addSubview:_web];
		_placeholder = [NSTextField wrappingLabelWithString:QTR(@"The current document is not Markdown.", @"O documento atual não é Markdown.")];
		_placeholder.textColor = [NSColor secondaryLabelColor];
		_placeholder.alignment = NSTextAlignmentCenter;
		_placeholder.frame = NSMakeRect(20, frame.size.height / 2, frame.size.width - 40, 40);
		_placeholder.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin | NSViewMaxYMargin;
		_placeholder.hidden = YES;
		[self addSubview:_placeholder];
		_tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"quill-md-preview-%d.html", getpid()]];
	}
	return self;
}

- (void)render {
	BOOL md = isMarkdownBuffer();
	_placeholder.hidden = md;
	_web.hidden = !md;
	if (!md) return;
	std::string text = host().currentText();
	NSString *path = QStr(host().currentPath());
	NSString *body = QStr(quill::markdownToHtml(text));
	NSString *baseDir = [[NSFileManager defaultManager] fileExistsAtPath:path] ? path.stringByDeletingLastPathComponent : NSHomeDirectory();
	NSString *base = [NSString stringWithFormat:@"<base href=\"%@/\">", [NSURL fileURLWithPath:baseDir].absoluteString];
	NSString *html = fullHTML(body, path.lastPathComponent);
	html = [html stringByReplacingOccurrencesOfString:@"<head>" withString:[@"<head>" stringByAppendingString:base]];
	if (_loaded && [_baseDir isEqualToString:baseDir]) {
		// Replace the body in place to keep the scroll position.
		NSData *json = [NSJSONSerialization dataWithJSONObject:@[ body ] options:0 error:nil];
		NSString *arr = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
		NSString *js = [NSString stringWithFormat:@"document.body.innerHTML = %@[0];", arr];
		[_web evaluateJavaScript:js completionHandler:nil];
		return;
	}
	[html writeToFile:_tempFile atomically:YES encoding:NSUTF8StringEncoding error:nil];
	[_web loadFileURL:[NSURL fileURLWithPath:_tempFile] allowingReadAccessToURL:[NSURL fileURLWithPath:@"/"]];
	_loaded = YES;
	_baseDir = baseDir;
}

- (void)syncScroll {
	intptr_t first = host().sci(SCI_GETFIRSTVISIBLELINE);
	intptr_t lines = MAX((intptr_t)1, host().sci(SCI_GETLINECOUNT) - host().sci(SCI_LINESONSCREEN));
	double f = MIN(1.0, MAX(0.0, (double)first / (double)lines));
	NSString *js = [NSString stringWithFormat:@"window.scrollTo(0, (document.documentElement.scrollHeight - window.innerHeight) * %f);", f];
	[_web evaluateJavaScript:js completionHandler:nil];
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)action decisionHandler:(void (^)(WKNavigationActionPolicy))handler {
	NSURL *url = action.request.URL;
	if (action.navigationType == WKNavigationTypeLinkActivated) {
		if (url.isFileURL && [[NSFileManager defaultManager] fileExistsAtPath:url.path]) {
			NSString *ext = url.pathExtension.lowercaseString;
			if ([@[ @"md", @"markdown", @"txt" ] containsObject:ext]) host().openFile(QWide(url.path));
			else [[NSWorkspace sharedWorkspace] openURL:url];
		} else if (url) {
			[[NSWorkspace sharedWorkspace] openURL:url];
		}
		handler(WKNavigationActionPolicyCancel);
		return;
	}
	handler(WKNavigationActionPolicyAllow);
}

@end
