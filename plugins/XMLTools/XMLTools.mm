// XML Tools: pretty print, linearize, syntax check, XPath and entity escaping.
// SPDX-License-Identifier: GPL-3.0-or-later
#include "PluginCommon.h"

using namespace qp;

QUILL_PLUGIN_EXPORTS(L"XML Tools", L"Ferramentas XML")

static int gCheckOnSaveIndex = 0;
static int gIndentTabsIndex = 0;

@interface QXMLErrorCollector : NSObject <NSXMLParserDelegate>
@property (nonatomic, strong) NSError *error;
@property (nonatomic) NSInteger line;
@property (nonatomic) NSInteger column;
@end
@implementation QXMLErrorCollector
- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError {
	if (!self.error) {
		self.error = parseError;
		self.line = parser.lineNumber;
		self.column = parser.columnNumber;
	}
}
- (void)parser:(NSXMLParser *)parser validationErrorOccurred:(NSError *)validationError {
	[self parser:parser parseErrorOccurred:validationError];
}
@end

// Returns nil when the text is well formed, otherwise a description; moves the caret to the error.
static NSString *checkSyntax(const std::string &text, intptr_t base, bool moveCaret) {
	NSData *data = [NSData dataWithBytes:text.data() length:text.size()];
	NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
	QXMLErrorCollector *c = [[QXMLErrorCollector alloc] init];
	parser.delegate = c;
	parser.shouldResolveExternalEntities = NO;
	BOOL ok = [parser parse];
	if (ok && !c.error) return nil;
	NSError *err = c.error ?: parser.parserError;
	NSInteger line = MAX(1, c.line ?: parser.lineNumber);
	NSInteger col = MAX(1, c.column ?: parser.columnNumber);
	if (moveCaret) {
		intptr_t baseLine = host().sci(SCI_LINEFROMPOSITION, static_cast<WPARAM>(base));
		intptr_t pos = host().sci(SCI_FINDCOLUMN, static_cast<WPARAM>(baseLine + line - 1), col - 1);
		host().sci(SCI_GOTOPOS, static_cast<WPARAM>(pos));
		host().sci(SCI_SCROLLCARET);
	}
	NSString *desc = err.localizedDescription ?: @"";
	NSString *reason = err.userInfo[NSLocalizedFailureReasonErrorKey] ?: @"";
	return [NSString stringWithFormat:QTR(@"Line %ld, column %ld: %@ %@", @"Linha %ld, coluna %ld: %@ %@"), (long)line, (long)col, desc, reason];
}

static NSXMLDocument *parseDocument(const std::string &text, NSError **error) {
	NSString *s = QStr(text);
	return [[NSXMLDocument alloc] initWithXMLString:s options:NSXMLNodePreserveCDATA | NSXMLNodePreserveEmptyElements | NSXMLNodePreserveNamespaceOrder error:error];
}

static std::string eolString() {
	int eolMode = (int)host().sci(SCI_GETEOLMODE);
	return eolMode == SC_EOL_CRLF ? "\r\n" : (eolMode == SC_EOL_CR ? "\r" : "\n");
}

static NSString *reindent(NSString *pretty) {
	// NSXMLDocument indents with 4 spaces; adapt to the editor settings.
	BOOL tabs = [[NSUserDefaults standardUserDefaults] boolForKey:@"XMLTools.tabs"];
	int width = (int)host().sci(SCI_GETTABWIDTH);
	NSMutableArray *out = [NSMutableArray array];
	for (NSString *line in [pretty componentsSeparatedByString:@"\n"]) {
		NSUInteger spaces = 0;
		while (spaces < line.length && [line characterAtIndex:spaces] == ' ') spaces++;
		NSUInteger level = spaces / 4;
		NSString *indent = tabs ? [@"" stringByPaddingToLength:level withString:@"\t" startingAtIndex:0]
					: [@"" stringByPaddingToLength:level * (NSUInteger)MAX(2, MIN(width, 4)) withString:@" " startingAtIndex:0];
		[out addObject:[indent stringByAppendingString:[line substringFromIndex:level * 4]]];
	}
	return [out componentsJoinedByString:@"\n"];
}

static void cmdPrettyPrint() {
	intptr_t start, end;
	std::string text = selectionOrAll(start, end);
	if (NSString *err = checkSyntax(text, start, true)) {
		alert(QTR(@"XML is not well formed", @"XML mal formado"), err, NSAlertStyleWarning);
		return;
	}
	NSError *error = nil;
	NSXMLDocument *doc = parseDocument(text, &error);
	if (!doc) {
		alert(QTR(@"Cannot parse XML", @"Não foi possível ler o XML"), error.localizedDescription, NSAlertStyleWarning);
		return;
	}
	BOOL hasDecl = text.find("<?xml") != std::string::npos;
	NSString *pretty = hasDecl ? [doc XMLStringWithOptions:NSXMLNodePrettyPrint | NSXMLNodePreserveEmptyElements]
				   : [doc.rootElement XMLStringWithOptions:NSXMLNodePrettyPrint | NSXMLNodePreserveEmptyElements];
	if (!hasDecl) {
		// Keep top level comments / processing instructions that are siblings of the root.
		NSMutableString *all = [NSMutableString string];
		for (NSXMLNode *n in doc.children) {
			if (all.length) [all appendString:@"\n"];
			[all appendString:[n XMLStringWithOptions:NSXMLNodePrettyPrint | NSXMLNodePreserveEmptyElements]];
		}
		pretty = all;
	}
	pretty = reindent(pretty);
	std::string out(pretty.UTF8String);
	std::string eol = eolString();
	if (eol != "\n") {
		std::string conv;
		for (char ch : out) {
			if (ch == '\n') conv += eol;
			else conv.push_back(ch);
		}
		out = conv;
	}
	if (!text.empty() && (text.back() == '\n' || text.back() == '\r')) out += eol;
	replaceRange(start, end, out);
	status(QTR(@"XML formatted", @"XML formatado"));
}

static void cmdLinearize() {
	intptr_t start, end;
	std::string text = selectionOrAll(start, end);
	if (NSString *err = checkSyntax(text, start, true)) {
		alert(QTR(@"XML is not well formed", @"XML mal formado"), err, NSAlertStyleWarning);
		return;
	}
	NSError *error = nil;
	NSXMLDocument *doc = parseDocument(text, &error);
	if (!doc) return;
	// Remove whitespace-only text nodes.
	NSMutableArray *stack = [NSMutableArray arrayWithObject:doc];
	while (stack.count) {
		NSXMLNode *n = stack.lastObject;
		[stack removeLastObject];
		for (NSXMLNode *child in [n.children copy]) {
			if (child.kind == NSXMLTextKind &&
			    [child.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length == 0)
				[child detach];
			else if (child.childCount)
				[stack addObject:child];
		}
	}
	BOOL hasDecl = text.find("<?xml") != std::string::npos;
	NSString *flat = hasDecl ? [doc XMLStringWithOptions:NSXMLNodePreserveEmptyElements] : nil;
	if (!hasDecl) {
		NSMutableString *all = [NSMutableString string];
		for (NSXMLNode *n in doc.children) [all appendString:[n XMLStringWithOptions:NSXMLNodePreserveEmptyElements]];
		flat = all;
	}
	flat = [flat stringByReplacingOccurrencesOfString:@"\n" withString:@""];
	replaceRange(start, end, std::string(flat.UTF8String));
	status(QTR(@"XML linearized", @"XML linearizado"));
}

static void cmdCheck() {
	intptr_t start, end;
	std::string text = selectionOrAll(start, end);
	if (NSString *err = checkSyntax(text, start, true))
		alert(QTR(@"XML is not well formed", @"XML mal formado"), err, NSAlertStyleWarning);
	else
		alert(QTR(@"XML is well formed", @"XML bem formado"), QTR(@"No syntax errors found.", @"Nenhum erro de sintaxe encontrado."));
}

static void cmdXPath() {
	intptr_t start, end;
	std::string text = selectionOrAll(start, end);
	NSError *error = nil;
	NSXMLDocument *doc = parseDocument(text, &error);
	if (!doc) {
		alert(QTR(@"Cannot parse XML", @"Não foi possível ler o XML"), error.localizedDescription, NSAlertStyleWarning);
		return;
	}
	NSAlert *a = [[NSAlert alloc] init];
	a.messageText = QTR(@"Evaluate XPath", @"Avaliar XPath");
	a.informativeText = QTR(@"Expression, for example //item[@id='1']", @"Expressão, por exemplo //item[@id='1']");
	NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 380, 24)];
	field.stringValue = [[NSUserDefaults standardUserDefaults] stringForKey:@"XMLTools.lastXPath"] ?: @"//";
	field.font = monoFont(12);
	a.accessoryView = field;
	[a addButtonWithTitle:QTR(@"Evaluate", @"Avaliar")];
	[a addButtonWithTitle:QTR(@"Cancel", @"Cancelar")];
	a.window.initialFirstResponder = field;
	if ([a runModal] != NSAlertFirstButtonReturn) return;
	NSString *expr = field.stringValue;
	[[NSUserDefaults standardUserDefaults] setObject:expr forKey:@"XMLTools.lastXPath"];
	NSArray<NSXMLNode *> *nodes = [doc nodesForXPath:expr error:&error];
	if (!nodes) {
		alert(QTR(@"Invalid XPath", @"XPath inválido"), error.localizedDescription, NSAlertStyleWarning);
		return;
	}
	NSMutableString *result = [NSMutableString string];
	[result appendFormat:QTR(@"%lu result(s) for %@\n\n", @"%lu resultado(s) para %@\n\n"), (unsigned long)nodes.count, expr];
	NSUInteger i = 0;
	for (NSXMLNode *n in nodes) {
		NSString *s = n.kind == NSXMLElementKind ? [n XMLStringWithOptions:NSXMLNodePrettyPrint] : n.stringValue;
		[result appendFormat:@"[%lu] %@\n", (unsigned long)++i, s ?: @""];
	}
	NSAlert *r = [[NSAlert alloc] init];
	r.messageText = [NSString stringWithFormat:QTR(@"%lu node(s) found", @"%lu nó(s) encontrado(s)"), (unsigned long)nodes.count];
	NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 520, 280)];
	scroll.hasVerticalScroller = YES;
	NSTextView *tv = [[NSTextView alloc] initWithFrame:scroll.bounds];
	tv.editable = NO;
	tv.font = monoFont(11);
	tv.string = result;
	tv.autoresizingMask = NSViewWidthSizable;
	scroll.documentView = tv;
	r.accessoryView = scroll;
	[r addButtonWithTitle:@"OK"];
	[r addButtonWithTitle:QTR(@"Open in New Tab", @"Abrir em nova aba")];
	if ([r runModal] == NSAlertSecondButtonReturn) host().npp(QUILLM_NEWDOCUMENT, 9 /* L_XML */, (LPARAM)result.UTF8String);
}

static void transformSelection(NSString * (^f)(NSString *)) {
	intptr_t start = host().sci(SCI_GETSELECTIONSTART), end = host().sci(SCI_GETSELECTIONEND);
	if (end <= start) {
		NSBeep();
		return;
	}
	NSString *in = QStr(textRange(start, end));
	replaceRange(start, end, std::string(f(in).UTF8String));
}

static void cmdEscape() {
	transformSelection(^NSString *(NSString *s) {
		s = [s stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
		s = [s stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
		s = [s stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];
		s = [s stringByReplacingOccurrencesOfString:@"\"" withString:@"&quot;"];
		return [s stringByReplacingOccurrencesOfString:@"'" withString:@"&apos;"];
	});
}

static void cmdUnescape() {
	transformSelection(^NSString *(NSString *s) {
		s = [s stringByReplacingOccurrencesOfString:@"&lt;" withString:@"<"];
		s = [s stringByReplacingOccurrencesOfString:@"&gt;" withString:@">"];
		s = [s stringByReplacingOccurrencesOfString:@"&quot;" withString:@"\""];
		s = [s stringByReplacingOccurrencesOfString:@"&apos;" withString:@"'"];
		return [s stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
	});
}

static void cmdCommentSelection() {
	transformSelection(^NSString *(NSString *s) {
		if ([s hasPrefix:@"<!--"] && [s hasSuffix:@"-->"]) return [[s substringWithRange:NSMakeRange(4, s.length - 7)]
										   stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		return [NSString stringWithFormat:@"<!-- %@ -->", s];
	});
}

static void cmdCheckOnSave() {
	BOOL v = ![[NSUserDefaults standardUserDefaults] boolForKey:@"XMLTools.checkOnSave"];
	[[NSUserDefaults standardUserDefaults] setBool:v forKey:@"XMLTools.checkOnSave"];
	gCommands.setChecked(gCheckOnSaveIndex, v);
}

static void cmdIndentTabs() {
	BOOL v = ![[NSUserDefaults standardUserDefaults] boolForKey:@"XMLTools.tabs"];
	[[NSUserDefaults standardUserDefaults] setBool:v forKey:@"XMLTools.tabs"];
	gCommands.setChecked(gIndentTabsIndex, v);
}

static void pluginInit() {}

static void pluginCommands(qp::Commands &c) {
	c.add(L"Pretty Print", L"Formatar (Pretty Print)", cmdPrettyPrint, Commands::key('B', true, true, true));
	c.add(L"Linearize", L"Linearizar", cmdLinearize, Commands::key('L', true, true, true));
	c.add(L"Check XML Syntax", L"Verificar sintaxe XML", cmdCheck, Commands::key('K', true, true, true));
	c.add(L"Evaluate XPath…", L"Avaliar XPath…", cmdXPath);
	c.separator();
	c.add(L"Escape Selection (&lt; &gt; &amp;)", L"Escapar seleção (&lt; &gt; &amp;)", cmdEscape);
	c.add(L"Unescape Selection", L"Desescapar seleção", cmdUnescape);
	c.add(L"Comment / Uncomment Selection", L"Comentar / descomentar seleção", cmdCommentSelection);
	c.separator();
	gCheckOnSaveIndex = c.add(L"Check Syntax on Save", L"Verificar sintaxe ao salvar", cmdCheckOnSave, nullptr,
				  [[NSUserDefaults standardUserDefaults] boolForKey:@"XMLTools.checkOnSave"]);
	gIndentTabsIndex = c.add(L"Indent with Tabs", L"Indentar com tabulações", cmdIndentTabs, nullptr,
				 [[NSUserDefaults standardUserDefaults] boolForKey:@"XMLTools.tabs"]);
}

static void pluginNotify(SCNotification *n) {
	if (n->nmhdr.code == NPPN_FILESAVED && [[NSUserDefaults standardUserDefaults] boolForKey:@"XMLTools.checkOnSave"]) {
		std::wstring lang = languageName();
		if (lang != L"xml" && lang != L"html") return;
		std::string text = host().currentText();
		if (NSString *err = checkSyntax(text, 0, false)) status([QTR(@"XML error: ", @"Erro de XML: ") stringByAppendingString:err]);
	}
}

static LRESULT pluginMessage(UINT, WPARAM, LPARAM) {
	return TRUE;
}
