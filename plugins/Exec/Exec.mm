// Exec: run shell commands and scripts with output in a console panel (NppExec style).
// SPDX-License-Identifier: GPL-3.0-or-later
#include "PluginCommon.h"
#include "quill/TextTools.h"

using namespace qp;

QUILL_PLUGIN_EXPORTS(L"Exec", L"Executar")

@interface QConsolePanel : NSView <NSTextViewDelegate, NSTextFieldDelegate>
@property (nonatomic, strong) NSTextView *output;
@property (nonatomic, strong) NSTextField *input;
@property (nonatomic, strong) NSButton *stopButton;
- (void)appendText:(NSString *)text color:(NSColor *)color;
- (void)clear;
@end

static QConsolePanel *gConsole;
static Panel gDock;
static NSTask *gTask;
static NSFileHandle *gStdin;
static NSDate *gStart;
static NSString *gLastCommand;
static int gConsoleIndex = 0, gSaveIndex = 0, gCdIndex = 0;

static NSUserDefaults *defaults() {
	return [NSUserDefaults standardUserDefaults];
}

static bool saveBeforeRun() {
	return [defaults() objectForKey:@"Exec.saveBeforeRun"] ? [defaults() boolForKey:@"Exec.saveBeforeRun"] : true;
}

static bool cdToFileDir() {
	return [defaults() objectForKey:@"Exec.cdToFileDir"] ? [defaults() boolForKey:@"Exec.cdToFileDir"] : true;
}

static void ensureConsole() {
	if (gConsole) return;
	gConsole = [[QConsolePanel alloc] initWithFrame:NSMakeRect(0, 0, 600, 200)];
	gDock.registerIn(gConsole, host().tr(L"Console", L"Console"), L"Exec.dylib", gConsoleIndex, DWS_DF_CONT_BOTTOM);
}

static void showConsole() {
	ensureConsole();
	gDock.show();
	gCommands.setChecked(gConsoleIndex, true);
}

static std::map<std::string, std::string> variables() {
	std::string path = quill::narrow(host().currentPath());
	auto vars = quill::fileVariables(path);
	vars["CURRENT_WORD"] = quill::narrow([&] {
		wchar_t buf[1024] = {0};
		host().npp(NPPM_GETCURRENTWORD, 1024, (LPARAM)buf);
		return std::wstring(buf);
	}());
	vars["CURRENT_LINE"] = std::to_string(host().npp(NPPM_GETCURRENTLINE) + 1);
	vars["CURRENT_COLUMN"] = std::to_string(host().npp(NPPM_GETCURRENTCOLUMN) + 1);
	vars["CURRENT_SELECTION"] = host().selectedText();
	vars["NPP_DIRECTORY"] = QUtf8([NSBundle mainBundle].bundlePath);
	vars["QUILL_DIRECTORY"] = vars["NPP_DIRECTORY"];
	vars["HOME"] = QUtf8(NSHomeDirectory());
	return vars;
}

static NSString *ansiStrip(NSString *s) {
	static NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"\\x1B\\[[0-9;?]*[ -/]*[@-~]" options:0 error:nil];
	return [re stringByReplacingMatchesInString:s options:0 range:NSMakeRange(0, s.length) withTemplate:@""];
}

static void stopCommand() {
	if (gTask.isRunning) {
		[gTask interrupt];
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			if (gTask.isRunning) [gTask terminate];
		});
	}
}

static void runCommand(NSString *command) {
	if (!command.length) return;
	showConsole();
	if (gTask.isRunning) {
		NSAlert *a = [[NSAlert alloc] init];
		a.messageText = QTR(@"A command is still running.", @"Um comando ainda está em execução.");
		[a addButtonWithTitle:QTR(@"Stop It and Run", @"Parar e executar")];
		[a addButtonWithTitle:QTR(@"Cancel", @"Cancelar")];
		if ([a runModal] != NSAlertFirstButtonReturn) return;
		[gTask terminate];
		[gTask waitUntilExit];
	}
	gLastCommand = command;
	if (saveBeforeRun() && host().npp(NPPM_GETFULLPATHFROMBUFFERID, host().currentBufferID(), 0) > 0) {
		NSString *path = QStr(host().currentPath());
		if ([[NSFileManager defaultManager] fileExistsAtPath:path]) host().npp(NPPM_SAVECURRENTFILE);
	}
	auto vars = variables();
	std::string expanded = quill::expandVariables(QUtf8(command), vars);
	NSString *cmd = QStr(expanded);

	NSTask *task = [[NSTask alloc] init];
	NSString *shell = [NSProcessInfo processInfo].environment[@"SHELL"] ?: @"/bin/zsh";
	if (![shell hasSuffix:@"zsh"] && ![shell hasSuffix:@"bash"]) shell = @"/bin/zsh";
	task.executableURL = [NSURL fileURLWithPath:shell];
	task.arguments = @[ @"-l", @"-c", cmd ];
	NSString *dir = QStr(vars["CURRENT_DIRECTORY"]);
	BOOL isDir = NO;
	if (!cdToFileDir() || !dir.length || ![[NSFileManager defaultManager] fileExistsAtPath:dir isDirectory:&isDir] || !isDir) dir = NSHomeDirectory();
	task.currentDirectoryURL = [NSURL fileURLWithPath:dir];
	NSMutableDictionary *env = [[NSProcessInfo processInfo].environment mutableCopy];
	env[@"PYTHONUNBUFFERED"] = @"1";
	env[@"NO_COLOR"] = @"1";
	env[@"TERM"] = @"dumb";
	env[@"CLICOLOR"] = @"0";
	for (auto &kv : vars) env[[@"QUILL_" stringByAppendingString:QStr(kv.first)]] = QStr(kv.second);
	task.environment = env;
	NSPipe *outPipe = [NSPipe pipe], *errPipe = [NSPipe pipe], *inPipe = [NSPipe pipe];
	task.standardOutput = outPipe;
	task.standardError = errPipe;
	task.standardInput = inPipe;
	gStdin = inPipe.fileHandleForWriting;

	[gConsole appendText:[NSString stringWithFormat:@"\n$ %@\n", cmd] color:[NSColor systemBlueColor]];
	auto reader = ^(NSFileHandle *h, BOOL isErr) {
		NSData *data = h.availableData;
		if (data.length == 0) {
			h.readabilityHandler = nil;
			return;
		}
		NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]
				      ?: [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
		dispatch_async(dispatch_get_main_queue(), ^{
			[gConsole appendText:ansiStrip(s) color:isErr ? [NSColor systemRedColor] : nil];
		});
	};
	outPipe.fileHandleForReading.readabilityHandler = ^(NSFileHandle *h) {
		reader(h, NO);
	};
	errPipe.fileHandleForReading.readabilityHandler = ^(NSFileHandle *h) {
		reader(h, YES);
	};
	task.terminationHandler = ^(NSTask *t) {
		int code = t.terminationStatus;
		NSTimeInterval elapsed = -[gStart timeIntervalSinceNow];
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			NSString *msg = [NSString stringWithFormat:QTR(@"<< finished with exit code %d (%.2f s)\n", @"<< terminou com código %d (%.2f s)\n"), code, elapsed];
			[gConsole appendText:msg color:code == 0 ? [NSColor secondaryLabelColor] : [NSColor systemOrangeColor]];
			gConsole.stopButton.enabled = NO;
			status([NSString stringWithFormat:QTR(@"Command finished (exit code %d)", @"Comando terminou (código %d)"), code]);
		});
	};
	NSError *err = nil;
	gStart = [NSDate date];
	if (![task launchAndReturnError:&err]) {
		[gConsole appendText:[NSString stringWithFormat:@"%@\n", err.localizedDescription] color:[NSColor systemRedColor]];
		return;
	}
	gTask = task;
	gConsole.stopButton.enabled = YES;
	NSMutableArray *history = [[defaults() stringArrayForKey:@"Exec.history"] mutableCopy] ?: [NSMutableArray array];
	[history removeObject:command];
	[history insertObject:command atIndex:0];
	while (history.count > 30) [history removeLastObject];
	[defaults() setObject:history forKey:@"Exec.history"];
}

static NSString *askCommand(NSString *initial) {
	NSAlert *a = [[NSAlert alloc] init];
	a.messageText = QTR(@"Execute Command", @"Executar comando");
	a.informativeText = QTR(@"Shell command. Variables: $(FULL_CURRENT_PATH) $(CURRENT_DIRECTORY) $(FILE_NAME) $(NAME_PART) $(EXT_PART) $(CURRENT_WORD) $(CURRENT_LINE) $(CURRENT_SELECTION) $(SYS.NAME)",
				@"Comando do shell. Variáveis: $(FULL_CURRENT_PATH) $(CURRENT_DIRECTORY) $(FILE_NAME) $(NAME_PART) $(EXT_PART) $(CURRENT_WORD) $(CURRENT_LINE) $(CURRENT_SELECTION) $(SYS.NOME)");
	NSComboBox *box = [[NSComboBox alloc] initWithFrame:NSMakeRect(0, 0, 520, 26)];
	box.font = monoFont(12);
	box.completes = YES;
	NSArray *history = [defaults() stringArrayForKey:@"Exec.history"] ?: @[];
	[box addItemsWithObjectValues:history];
	box.stringValue = initial ?: (history.firstObject ?: @"");
	a.accessoryView = box;
	[a addButtonWithTitle:QTR(@"Run", @"Executar")];
	[a addButtonWithTitle:QTR(@"Cancel", @"Cancelar")];
	a.window.initialFirstResponder = box;
	if ([a runModal] != NSAlertFirstButtonReturn) return nil;
	return box.stringValue;
}

static void cmdExecute() {
	NSString *c = askCommand(nil);
	if (c) runCommand(c);
}

static void cmdRunFile() {
	std::wstring path = host().currentPath();
	NSString *p = QStr(path);
	if (![[NSFileManager defaultManager] fileExistsAtPath:p]) {
		alert(QTR(@"Save the file first", @"Salve o arquivo primeiro"), QTR(@"Run Current File needs a file saved on disk.", @"Executar arquivo atual precisa de um arquivo salvo no disco."));
		return;
	}
	NSString *ext = p.pathExtension.lowercaseString;
	NSDictionary *custom = [defaults() dictionaryForKey:@"Exec.runners"];
	NSString *cmd = custom[ext];
	if (!cmd.length) cmd = QStr(quill::defaultRunCommand(QUtf8(ext)));
	if (!cmd.length) {
		// Executable scripts with a shebang run directly.
		std::string text = host().currentText();
		if (text.rfind("#!", 0) == 0) cmd = @"chmod +x \"$(FULL_CURRENT_PATH)\" && \"$(FULL_CURRENT_PATH)\"";
	}
	if (!cmd.length) {
		cmd = askCommand(@"\"$(FULL_CURRENT_PATH)\"");
		if (!cmd) return;
		NSMutableDictionary *d = [custom mutableCopy] ?: [NSMutableDictionary dictionary];
		d[ext] = cmd;
		[defaults() setObject:d forKey:@"Exec.runners"];
	}
	runCommand(cmd);
}

static void cmdRunPrevious() {
	NSString *last = gLastCommand ?: [[defaults() stringArrayForKey:@"Exec.history"] firstObject];
	if (last) runCommand(last);
	else cmdExecute();
}

static void cmdStop() {
	stopCommand();
}

static void cmdConsole() {
	ensureConsole();
	if (gDock.visible()) {
		gDock.hide();
		gCommands.setChecked(gConsoleIndex, false);
	} else {
		showConsole();
	}
}

static void cmdClear() {
	ensureConsole();
	[gConsole clear];
}

// Saved commands: name -> command, editable in a simple list window.
static void cmdSavedCommands() {
	NSMutableDictionary *saved = [[defaults() dictionaryForKey:@"Exec.saved"] mutableCopy] ?: [NSMutableDictionary dictionary];
	NSAlert *a = [[NSAlert alloc] init];
	a.messageText = QTR(@"Saved Commands", @"Comandos salvos");
	a.informativeText = QTR(@"Pick a command to run, or type a new name and command to save it.", @"Escolha um comando para executar, ou digite um nome e um comando novos para salvar.");
	NSView *acc = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 520, 90)];
	NSPopUpButton *pop = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 62, 520, 26) pullsDown:NO];
	[pop addItemWithTitle:QTR(@"— new —", @"— novo —")];
	for (NSString *k in [saved.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]) [pop addItemWithTitle:k];
	NSTextField *name = [NSTextField textFieldWithString:@""];
	name.placeholderString = QTR(@"Name", @"Nome");
	name.frame = NSMakeRect(0, 32, 520, 24);
	NSTextField *command = [NSTextField textFieldWithString:@""];
	command.placeholderString = QTR(@"Command", @"Comando");
	command.font = monoFont(12);
	command.frame = NSMakeRect(0, 2, 520, 24);
	[acc addSubview:pop];
	[acc addSubview:name];
	[acc addSubview:command];
	a.accessoryView = acc;
	[a addButtonWithTitle:QTR(@"Run", @"Executar")];
	[a addButtonWithTitle:QTR(@"Save", @"Salvar")];
	[a addButtonWithTitle:QTR(@"Delete", @"Apagar")];
	[a addButtonWithTitle:QTR(@"Cancel", @"Cancelar")];
	// Keep the fields in sync with the popup selection.
	__block id observer = [[NSNotificationCenter defaultCenter] addObserverForName:NSMenuDidSendActionNotification
										 object:pop.menu
										  queue:nil
									     usingBlock:^(NSNotification *n) {
										     NSString *k = pop.titleOfSelectedItem;
										     name.stringValue = pop.indexOfSelectedItem > 0 ? k : @"";
										     command.stringValue = pop.indexOfSelectedItem > 0 ? (saved[k] ?: @"") : @"";
									     }];
	NSModalResponse r = [a runModal];
	[[NSNotificationCenter defaultCenter] removeObserver:observer];
	NSString *key = name.stringValue.length ? name.stringValue : (pop.indexOfSelectedItem > 0 ? pop.titleOfSelectedItem : nil);
	if (r == NSAlertFirstButtonReturn) {
		NSString *c = command.stringValue.length ? command.stringValue : (key ? saved[key] : nil);
		if (c.length) runCommand(c);
	} else if (r == NSAlertSecondButtonReturn) {
		if (key.length && command.stringValue.length) {
			saved[key] = command.stringValue;
			[defaults() setObject:saved forKey:@"Exec.saved"];
		}
	} else if (r == NSAlertThirdButtonReturn) {
		if (key) {
			[saved removeObjectForKey:key];
			[defaults() setObject:saved forKey:@"Exec.saved"];
		}
	}
}

static void cmdSaveToggle() {
	BOOL v = !saveBeforeRun();
	[defaults() setBool:v forKey:@"Exec.saveBeforeRun"];
	gCommands.setChecked(gSaveIndex, v);
}

static void cmdCdToggle() {
	BOOL v = !cdToFileDir();
	[defaults() setBool:v forKey:@"Exec.cdToFileDir"];
	gCommands.setChecked(gCdIndex, v);
}

static void pluginInit() {}

static void pluginCommands(qp::Commands &c) {
	c.add(L"Execute Command…", L"Executar comando…", cmdExecute, Commands::key(0x75 /* F6 */, false, false, false));
	c.add(L"Run Current File", L"Executar arquivo atual", cmdRunFile, Commands::key('R', true, false, false));
	c.add(L"Run Previous Command", L"Executar comando anterior", cmdRunPrevious, Commands::key(0x75, true, false, false));
	c.add(L"Stop", L"Parar", cmdStop, Commands::key(0xBE /* . */, true, false, false));
	c.separator();
	gConsoleIndex = c.add(L"Show Console", L"Mostrar console", cmdConsole, Commands::key(0xC0 /* ` */, true, false, true));
	c.add(L"Clear Console", L"Limpar console", cmdClear);
	c.add(L"Saved Commands…", L"Comandos salvos…", cmdSavedCommands);
	c.separator();
	gSaveIndex = c.add(L"Save File Before Running", L"Salvar arquivo antes de executar", cmdSaveToggle, nullptr, saveBeforeRun());
	gCdIndex = c.add(L"Run in the File's Folder", L"Executar na pasta do arquivo", cmdCdToggle, nullptr, cdToFileDir());
}

static void pluginNotify(SCNotification *n) {
	if (n->nmhdr.code == QUILLN_PANELCLOSED && gConsole && n->nmhdr.hwndFrom == (__bridge void *)gConsole)
		gCommands.setChecked(gConsoleIndex, false);
	if (n->nmhdr.code == NPPN_SHUTDOWN && gTask.isRunning) [gTask terminate];
}

static LRESULT pluginMessage(UINT, WPARAM, LPARAM) {
	return TRUE;
}

// ---- Console panel --------------------------------------------------------------------

@implementation QConsolePanel

- (instancetype)initWithFrame:(NSRect)frame {
	if ((self = [super initWithFrame:frame])) {
		NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
		scroll.hasVerticalScroller = YES;
		scroll.translatesAutoresizingMaskIntoConstraints = NO;
		_output = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 600, 200)];
		_output.editable = NO;
		_output.selectable = YES;
		_output.richText = NO;
		_output.font = monoFont(12);
		_output.textContainerInset = NSMakeSize(6, 4);
		_output.autoresizingMask = NSViewWidthSizable;
		_output.delegate = self;
		_output.automaticLinkDetectionEnabled = NO;
		_output.linkTextAttributes = @{NSUnderlineStyleAttributeName : @(NSUnderlineStyleSingle), NSCursorAttributeName : [NSCursor pointingHandCursor]};
		scroll.documentView = _output;

		_input = [NSTextField textFieldWithString:@""];
		_input.placeholderString = QTR(@"Send input to the running program (Enter)", @"Enviar entrada ao programa em execução (Enter)");
		_input.font = monoFont(12);
		_input.delegate = self;
		_input.target = self;
		_input.action = @selector(sendInput:);
		_input.translatesAutoresizingMaskIntoConstraints = NO;
		_stopButton = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"stop.fill" accessibilityDescription:nil] target:self action:@selector(stop:)];
		_stopButton.toolTip = QTR(@"Stop (⌘.)", @"Parar (⌘.)");
		_stopButton.enabled = NO;
		_stopButton.translatesAutoresizingMaskIntoConstraints = NO;
		NSButton *clear = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"trash" accessibilityDescription:nil] target:self action:@selector(clearAction:)];
		clear.toolTip = QTR(@"Clear", @"Limpar");
		clear.translatesAutoresizingMaskIntoConstraints = NO;
		NSButton *run = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"play.fill" accessibilityDescription:nil] target:self action:@selector(runAction:)];
		run.toolTip = QTR(@"Execute command… (F6)", @"Executar comando… (F6)");
		run.translatesAutoresizingMaskIntoConstraints = NO;
		for (NSButton *b in @[ _stopButton, clear, run ]) b.bezelStyle = NSBezelStyleRecessed;

		[self addSubview:scroll];
		[self addSubview:_input];
		[self addSubview:run];
		[self addSubview:_stopButton];
		[self addSubview:clear];
		[NSLayoutConstraint activateConstraints:@[
			[scroll.topAnchor constraintEqualToAnchor:self.topAnchor],
			[scroll.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
			[scroll.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
			[scroll.bottomAnchor constraintEqualToAnchor:_input.topAnchor constant:-4],
			[_input.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:6],
			[_input.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-4],
			[run.leadingAnchor constraintEqualToAnchor:_input.trailingAnchor constant:6],
			[run.centerYAnchor constraintEqualToAnchor:_input.centerYAnchor],
			[_stopButton.leadingAnchor constraintEqualToAnchor:run.trailingAnchor constant:2],
			[_stopButton.centerYAnchor constraintEqualToAnchor:_input.centerYAnchor],
			[clear.leadingAnchor constraintEqualToAnchor:_stopButton.trailingAnchor constant:2],
			[clear.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-6],
			[clear.centerYAnchor constraintEqualToAnchor:_input.centerYAnchor],
		]];
	}
	return self;
}

- (void)appendText:(NSString *)text color:(NSColor *)color {
	if (!text.length) return;
	NSDictionary *attrs = @{NSFontAttributeName : monoFont(12), NSForegroundColorAttributeName : color ?: [NSColor textColor]};
	NSMutableAttributedString *s = [[NSMutableAttributedString alloc] initWithString:text attributes:attrs];
	// file:line[:col] references become clickable.
	static NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"((?:/|\\./|~/)?[\\w\\-./ ]+\\.[A-Za-z0-9]+):(\\d+)(?::(\\d+))?"
											options:0
											  error:nil];
	NSString *cwd = QStr(host().currentDirectory());
	[re enumerateMatchesInString:text
			     options:0
			       range:NSMakeRange(0, text.length)
			  usingBlock:^(NSTextCheckingResult *m, NSMatchingFlags f, BOOL *stop) {
				  NSString *path = [[text substringWithRange:[m rangeAtIndex:1]] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
				  if (![path hasPrefix:@"/"]) path = [cwd stringByAppendingPathComponent:path.stringByExpandingTildeInPath];
				  if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return;
				  NSURLComponents *u = [[NSURLComponents alloc] init];
				  u.scheme = @"quill-open";
				  u.path = path;
				  NSString *line = [text substringWithRange:[m rangeAtIndex:2]];
				  NSRange colRange = [m rangeAtIndex:3];
				  NSString *col = colRange.location != NSNotFound ? [text substringWithRange:colRange] : @"1";
				  u.queryItems = @[ [NSURLQueryItem queryItemWithName:@"line" value:line], [NSURLQueryItem queryItemWithName:@"col" value:col] ];
				  if (u.URL) [s addAttribute:NSLinkAttributeName value:u.URL range:m.range];
			  }];
	NSTextStorage *ts = _output.textStorage;
	BOOL atBottom = NSMaxY(_output.visibleRect) >= NSMaxY(_output.bounds) - 20;
	[ts appendAttributedString:s];
	// Keep the console bounded.
	if (ts.length > 2000000) [ts deleteCharactersInRange:NSMakeRange(0, ts.length - 1500000)];
	if (atBottom) [_output scrollRangeToVisible:NSMakeRange(ts.length, 0)];
}

- (BOOL)textView:(NSTextView *)textView clickedOnLink:(id)link atIndex:(NSUInteger)charIndex {
	NSURL *url = [link isKindOfClass:[NSURL class]] ? link : [NSURL URLWithString:[link description]];
	if (![url.scheme isEqualToString:@"quill-open"]) return NO;
	NSURLComponents *c = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
	NSInteger line = 1, col = 1;
	for (NSURLQueryItem *q in c.queryItems) {
		if ([q.name isEqualToString:@"line"]) line = q.value.integerValue;
		if ([q.name isEqualToString:@"col"]) col = q.value.integerValue;
	}
	if (host().openFile(QWide(c.path))) {
		intptr_t pos = host().sci(SCI_FINDCOLUMN, static_cast<WPARAM>(MAX(0, line - 1)), MAX(0, col - 1));
		host().sci(SCI_GOTOPOS, static_cast<WPARAM>(pos));
		host().sci(SCI_SCROLLCARET);
	}
	return YES;
}

- (void)clear {
	[_output.textStorage setAttributedString:[[NSAttributedString alloc] initWithString:@""]];
}

- (void)sendInput:(NSTextField *)sender {
	NSString *text = sender.stringValue;
	if (!gTask.isRunning || !gStdin) {
		if (text.length) runCommand(text);
		sender.stringValue = @"";
		return;
	}
	[self appendText:[text stringByAppendingString:@"\n"] color:[NSColor systemTealColor]];
	@try {
		[gStdin writeData:[[text stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding]];
	} @catch (NSException *e) {
	}
	sender.stringValue = @"";
}

- (void)stop:(id)sender {
	stopCommand();
}

- (void)clearAction:(id)sender {
	[self clear];
}

- (void)runAction:(id)sender {
	cmdExecute();
}

@end
