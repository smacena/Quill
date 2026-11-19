// FTP: browse and edit files on SFTP / FTP / FTPS servers (NppFTP style).
// SFTP uses the system OpenSSH client (/usr/bin/sftp), FTP and FTPS use curl.
// Passwords are kept in the macOS Keychain. Files are downloaded to a local
// cache, opened in the editor and uploaded again every time they are saved.
// SPDX-License-Identifier: GPL-3.0-or-later
#include "PluginCommon.h"
#include "quill/TextTools.h"
#import <Security/Security.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

using namespace qp;

QUILL_PLUGIN_EXPORTS(L"FTP", L"FTP")

// ---- Profiles & keychain ------------------------------------------------------------------

static NSString *const kKeychainService = @"Quill FTP";

static NSString *profilesPath() {
	return configPath(@"FTP-profiles.json");
}

static NSMutableArray<NSMutableDictionary *> *loadProfiles() {
	NSData *d = [NSData dataWithContentsOfFile:profilesPath()];
	NSArray *arr = d ? [NSJSONSerialization JSONObjectWithData:d options:NSJSONReadingMutableContainers error:nil] : nil;
	NSMutableArray *out = [NSMutableArray array];
	for (id p in arr)
		if ([p isKindOfClass:[NSDictionary class]]) [out addObject:[p mutableCopy]];
	return out;
}

static void saveProfiles(NSArray *profiles) {
	NSData *d = [NSJSONSerialization dataWithJSONObject:profiles options:NSJSONWritingPrettyPrinted error:nil];
	[d writeToFile:profilesPath() atomically:YES];
}

static NSString *keychainPassword(NSString *account) {
	NSDictionary *q = @{
		(__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
		(__bridge id)kSecAttrService : kKeychainService,
		(__bridge id)kSecAttrAccount : account ?: @"",
		(__bridge id)kSecReturnData : @YES,
		(__bridge id)kSecMatchLimit : (__bridge id)kSecMatchLimitOne,
	};
	CFTypeRef result = NULL;
	if (SecItemCopyMatching((__bridge CFDictionaryRef)q, &result) != errSecSuccess || !result) return nil;
	NSData *data = (__bridge_transfer NSData *)result;
	return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

static void setKeychainPassword(NSString *account, NSString *password) {
	NSDictionary *q = @{
		(__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
		(__bridge id)kSecAttrService : kKeychainService,
		(__bridge id)kSecAttrAccount : account ?: @"",
	};
	SecItemDelete((__bridge CFDictionaryRef)q);
	if (!password.length) return;
	NSMutableDictionary *add = [q mutableCopy];
	add[(__bridge id)kSecValueData] = [password dataUsingEncoding:NSUTF8StringEncoding];
	SecItemAdd((__bridge CFDictionaryRef)add, NULL);
}

// ---- Remote operations ------------------------------------------------------------------------

struct OpResult {
	bool ok = false;
	std::string output;
	std::string error;
};

@interface QFTPSession : NSObject
@property (nonatomic, copy) NSDictionary *profile;
@property (nonatomic, copy) NSString *password;
- (OpResult)list:(NSString *)dir;
- (OpResult)download:(NSString *)remote to:(NSString *)local;
- (OpResult)upload:(NSString *)local to:(NSString *)remote;
- (OpResult)mkdir:(NSString *)remote;
- (OpResult)remove:(NSString *)remote isDirectory:(BOOL)dir;
- (OpResult)rename:(NSString *)from to:(NSString *)to;
@end

static OpResult runProcess(NSString *exe, NSArray *args, NSDictionary *extraEnv, NSString *stdinText, NSTimeInterval timeout) {
	OpResult r;
	NSTask *t = [[NSTask alloc] init];
	t.executableURL = [NSURL fileURLWithPath:exe];
	t.arguments = args;
	NSMutableDictionary *env = [[NSProcessInfo processInfo].environment mutableCopy];
	[env addEntriesFromDictionary:extraEnv ?: @{}];
	t.environment = env;
	NSPipe *outP = [NSPipe pipe], *errP = [NSPipe pipe], *inP = [NSPipe pipe];
	t.standardOutput = outP;
	t.standardError = errP;
	t.standardInput = inP;
	NSError *e = nil;
	if (![t launchAndReturnError:&e]) {
		r.error = QUtf8(e.localizedDescription);
		return r;
	}
	if (stdinText) [inP.fileHandleForWriting writeData:[stdinText dataUsingEncoding:NSUTF8StringEncoding]];
	[inP.fileHandleForWriting closeFile];
	__block NSData *outData = nil, *errData = nil;
	dispatch_group_t g = dispatch_group_create();
	dispatch_group_async(g, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
		outData = [outP.fileHandleForReading readDataToEndOfFile];
	});
	dispatch_group_async(g, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
		errData = [errP.fileHandleForReading readDataToEndOfFile];
	});
	if (dispatch_group_wait(g, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC))) != 0) {
		[t terminate];
		dispatch_group_wait(g, DISPATCH_TIME_FOREVER);
		r.error = "timeout";
	}
	[t waitUntilExit];
	r.output = std::string((const char *)outData.bytes, outData.length);
	if (r.error.empty()) r.error = std::string((const char *)errData.bytes, errData.length);
	r.ok = t.terminationStatus == 0;
	return r;
}

static NSString *sftpQuote(NSString *s) {
	s = [s stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
	s = [s stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
	return [NSString stringWithFormat:@"\"%@\"", s];
}

@implementation QFTPSession {
	NSString *_askpass;
	NSString *_netrc;
}

- (void)dealloc {
	if (_askpass) [[NSFileManager defaultManager] removeItemAtPath:_askpass error:nil];
	if (_netrc) [[NSFileManager defaultManager] removeItemAtPath:_netrc error:nil];
}

- (NSString *)protocol {
	return self.profile[@"protocol"] ?: @"sftp";
}

- (BOOL)isSFTP {
	return [self.protocol isEqualToString:@"sftp"];
}

- (NSString *)privateTempFile:(NSString *)name contents:(NSString *)contents mode:(short)mode {
	NSString *dir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"quill-ftp"];
	[[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions : @0700} error:nil];
	NSString *path = [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@", name, [NSUUID UUID].UUIDString]];
	[[NSFileManager defaultManager] createFileAtPath:path contents:[contents dataUsingEncoding:NSUTF8StringEncoding] attributes:@{NSFilePosixPermissions : @(mode)}];
	return path;
}

- (OpResult)sftp:(NSString *)commands {
	NSDictionary *p = self.profile;
	NSMutableArray *args = [NSMutableArray arrayWithObjects:@"-b", @"-", @"-o", @"StrictHostKeyChecking=accept-new", @"-o", @"ConnectTimeout=20",
							       @"-o", @"ServerAliveInterval=15", nil];
	if ([p[@"port"] integerValue] > 0) [args addObjectsFromArray:@[ @"-P", [p[@"port"] stringValue] ]];
	NSString *key = p[@"keyFile"];
	if (key.length) [args addObjectsFromArray:@[ @"-i", key.stringByExpandingTildeInPath ]];
	NSMutableDictionary *env = [NSMutableDictionary dictionary];
	if (self.password.length) {
		if (!_askpass) _askpass = [self privateTempFile:@"askpass" contents:@"#!/bin/sh\nprintf '%s\\n' \"$QUILL_FTP_SECRET\"\n" mode:0700];
		env[@"SSH_ASKPASS"] = _askpass;
		env[@"SSH_ASKPASS_REQUIRE"] = @"force";
		env[@"DISPLAY"] = @":0";
		env[@"QUILL_FTP_SECRET"] = self.password;
		[args addObjectsFromArray:@[ @"-o", @"NumberOfPasswordPrompts=1" ]];
	} else {
		[args addObjectsFromArray:@[ @"-o", @"BatchMode=yes" ]];
	}
	NSString *user = p[@"user"];
	NSString *dest = user.length ? [NSString stringWithFormat:@"%@@%@", user, p[@"host"]] : p[@"host"];
	[args addObject:dest];
	return runProcess(@"/usr/bin/sftp", args, env, commands, 120);
}

- (NSString *)urlFor:(NSString *)path {
	NSDictionary *p = self.profile;
	NSString *scheme = [self.protocol isEqualToString:@"ftps-implicit"] ? @"ftps" : @"ftp";
	NSInteger port = [p[@"port"] integerValue];
	NSString *host = port > 0 ? [NSString stringWithFormat:@"%@:%ld", p[@"host"], (long)port] : p[@"host"];
	NSString *encoded = [path stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]] ?: path;
	if (![encoded hasPrefix:@"/"]) encoded = [@"/" stringByAppendingString:encoded];
	// curl treats the path as relative to the login directory unless it starts with %2F.
	return [NSString stringWithFormat:@"%@://%@/%%2F%@", scheme, host, [encoded substringFromIndex:1]];
}

- (OpResult)curl:(NSArray *)extra url:(NSString *)url {
	NSDictionary *p = self.profile;
	if (!_netrc) {
		NSString *line = [NSString stringWithFormat:@"machine %@ login %@ password %@\n", p[@"host"], [p[@"user"] length] ? p[@"user"] : @"anonymous",
							    self.password.length ? self.password : @"anonymous@"];
		_netrc = [self privateTempFile:@"netrc" contents:line mode:0600];
	}
	NSMutableArray *args = [NSMutableArray arrayWithObjects:@"-sS", @"--netrc-file", _netrc, @"--connect-timeout", @"20", nil];
	if ([self.protocol isEqualToString:@"ftps"]) [args addObject:@"--ssl-reqd"];
	if ([p[@"insecureTLS"] boolValue]) [args addObject:@"-k"];
	[args addObjectsFromArray:extra];
	[args addObject:url];
	return runProcess(@"/usr/bin/curl", args, nil, nil, 300);
}

- (OpResult)list:(NSString *)dir {
	if (self.isSFTP) return [self sftp:[NSString stringWithFormat:@"cd %@\nls -la\n", sftpQuote(dir)]];
	NSString *u = [self urlFor:dir];
	if (![u hasSuffix:@"/"]) u = [u stringByAppendingString:@"/"];
	return [self curl:@[] url:u];
}

- (OpResult)download:(NSString *)remote to:(NSString *)local {
	[[NSFileManager defaultManager] createDirectoryAtPath:local.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
	if (self.isSFTP) return [self sftp:[NSString stringWithFormat:@"get %@ %@\n", sftpQuote(remote), sftpQuote(local)]];
	return [self curl:@[ @"-o", local ] url:[self urlFor:remote]];
}

- (OpResult)upload:(NSString *)local to:(NSString *)remote {
	if (self.isSFTP) return [self sftp:[NSString stringWithFormat:@"put %@ %@\n", sftpQuote(local), sftpQuote(remote)]];
	return [self curl:@[ @"-T", local, @"--ftp-create-dirs" ] url:[self urlFor:remote]];
}

- (OpResult)mkdir:(NSString *)remote {
	if (self.isSFTP) return [self sftp:[NSString stringWithFormat:@"mkdir %@\n", sftpQuote(remote)]];
	return [self curl:@[ @"-o", @"/dev/null", @"-Q", [@"MKD " stringByAppendingString:remote] ] url:[self urlFor:@"/"]];
}

- (OpResult)remove:(NSString *)remote isDirectory:(BOOL)dir {
	if (self.isSFTP) return [self sftp:[NSString stringWithFormat:@"%@ %@\n", dir ? @"rmdir" : @"rm", sftpQuote(remote)]];
	return [self curl:@[ @"-o", @"/dev/null", @"-Q", [(dir ? @"RMD " : @"DELE ") stringByAppendingString:remote] ] url:[self urlFor:@"/"]];
}

- (OpResult)rename:(NSString *)from to:(NSString *)to {
	if (self.isSFTP) return [self sftp:[NSString stringWithFormat:@"rename %@ %@\n", sftpQuote(from), sftpQuote(to)]];
	return [self curl:@[ @"-o", @"/dev/null", @"-Q", [@"RNFR " stringByAppendingString:from], @"-Q", [@"RNTO " stringByAppendingString:to] ]
		      url:[self urlFor:@"/"]];
}

@end

// ---- Panel ------------------------------------------------------------------------------------

@interface QRemoteNode : NSObject
@property (nonatomic, copy) NSString *path;
@property (nonatomic) BOOL isDirectory;
@property (nonatomic) unsigned long long size;
@property (nonatomic, copy) NSString *modified;
@property (nonatomic, strong) NSArray<QRemoteNode *> *children; // nil = not loaded
@property (nonatomic) BOOL loading;
@end
@implementation QRemoteNode
@end

@interface QFTPPanel : NSView <NSOutlineViewDataSource, NSOutlineViewDelegate, NSMenuDelegate>
- (void)reloadProfiles;
- (void)uploadCurrentFileAsk:(BOOL)ask;
- (void)fileSaved:(NSString *)path;
- (void)disconnect;
@end

@interface QProfilesWindow : NSWindowController <NSTableViewDataSource, NSTableViewDelegate>
@end

static QFTPPanel *gPanel;
static Panel gDock;
static QProfilesWindow *gProfilesWindow;
static int gShowIndex = 0;
// local cache path -> @{profile: name, remote: path}
static NSMutableDictionary<NSString *, NSDictionary *> *gMapping;

static NSString *cacheRoot() {
	NSString *dir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"Quill/FTP"];
	[[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
	return dir;
}

static void ensurePanel() {
	if (gPanel) return;
	gPanel = [[QFTPPanel alloc] initWithFrame:NSMakeRect(0, 0, 280, 500)];
	gDock.registerIn(gPanel, L"FTP", L"FTP.dylib", gShowIndex, DWS_DF_CONT_RIGHT);
}

static void cmdShow() {
	ensurePanel();
	if (gDock.visible()) {
		gDock.hide();
		gCommands.setChecked(gShowIndex, false);
	} else {
		gDock.show();
		gCommands.setChecked(gShowIndex, true);
	}
}

static void cmdProfiles() {
	if (!gProfilesWindow) gProfilesWindow = [[QProfilesWindow alloc] init];
	[gProfilesWindow showWindow:nil];
	[gProfilesWindow.window makeKeyAndOrderFront:nil];
}

static void cmdUpload() {
	ensurePanel();
	[gPanel uploadCurrentFileAsk:YES];
}

static void cmdDisconnect() {
	[gPanel disconnect];
}

static void pluginInit() {
	gMapping = [NSMutableDictionary dictionary];
}

static void pluginCommands(qp::Commands &c) {
	gShowIndex = c.add(L"Show FTP Panel", L"Mostrar painel FTP", cmdShow);
	c.add(L"Manage Profiles…", L"Gerenciar perfis…", cmdProfiles);
	c.add(L"Upload Current File", L"Enviar arquivo atual", cmdUpload, Commands::key('U', true, true, false));
	c.add(L"Disconnect", L"Desconectar", cmdDisconnect);
}

static void pluginNotify(SCNotification *n) {
	switch (n->nmhdr.code) {
	case NPPN_FILESAVED: {
		NSString *path = QStr(host().pathFromBufferID(n->nmhdr.idFrom));
		if (gMapping[path]) {
			ensurePanel();
			[gPanel fileSaved:path];
		}
		break;
	}
	case QUILLN_PANELCLOSED:
		if (gPanel && n->nmhdr.hwndFrom == (__bridge void *)gPanel) gCommands.setChecked(gShowIndex, false);
		break;
	default:
		break;
	}
}

static LRESULT pluginMessage(UINT, WPARAM, LPARAM) {
	return TRUE;
}

@implementation QFTPPanel {
	NSPopUpButton *_profiles;
	NSButton *_connect;
	NSTextField *_path;
	NSOutlineView *_outline;
	NSTextField *_status;
	NSProgressIndicator *_spinner;
	QFTPSession *_session;
	QRemoteNode *_root;
	NSOperationQueue *_queue;
	NSInteger _busy;
}

- (instancetype)initWithFrame:(NSRect)frame {
	if ((self = [super initWithFrame:frame])) {
		_queue = [[NSOperationQueue alloc] init];
		_queue.maxConcurrentOperationCount = 1;
		_profiles = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
		_profiles.controlSize = NSControlSizeSmall;
		_profiles.translatesAutoresizingMaskIntoConstraints = NO;
		_connect = [NSButton buttonWithTitle:QTR(@"Connect", @"Conectar") target:self action:@selector(toggleConnect:)];
		_connect.controlSize = NSControlSizeSmall;
		_connect.translatesAutoresizingMaskIntoConstraints = NO;
		NSButton *gear = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"gearshape" accessibilityDescription:nil] target:self action:@selector(manage:)];
		gear.bezelStyle = NSBezelStyleRecessed;
		gear.toolTip = QTR(@"Manage profiles…", @"Gerenciar perfis…");
		gear.translatesAutoresizingMaskIntoConstraints = NO;

		_path = [NSTextField textFieldWithString:@""];
		_path.placeholderString = QTR(@"Remote folder", @"Pasta remota");
		_path.font = monoFont(11);
		_path.target = self;
		_path.action = @selector(goPath:);
		_path.translatesAutoresizingMaskIntoConstraints = NO;
		NSButton *up = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"arrow.up" accessibilityDescription:nil] target:self action:@selector(goUp:)];
		NSButton *refresh = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"arrow.clockwise" accessibilityDescription:nil] target:self action:@selector(refresh:)];
		NSButton *upload = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"arrow.up.doc" accessibilityDescription:nil] target:self action:@selector(uploadFile:)];
		NSButton *mkdir = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"folder.badge.plus" accessibilityDescription:nil] target:self action:@selector(newFolder:)];
		up.toolTip = QTR(@"Parent folder", @"Pasta acima");
		refresh.toolTip = QTR(@"Refresh", @"Atualizar");
		upload.toolTip = QTR(@"Upload a local file to the selected folder…", @"Enviar um arquivo local para a pasta selecionada…");
		mkdir.toolTip = QTR(@"New folder…", @"Nova pasta…");
		for (NSButton *b in @[ up, refresh, upload, mkdir ]) {
			b.bezelStyle = NSBezelStyleRecessed;
			b.translatesAutoresizingMaskIntoConstraints = NO;
		}
		NSStackView *tools = [NSStackView stackViewWithViews:@[ up, refresh, upload, mkdir ]];
		tools.spacing = 2;
		tools.translatesAutoresizingMaskIntoConstraints = NO;

		NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
		scroll.hasVerticalScroller = YES;
		scroll.autohidesScrollers = YES;
		scroll.translatesAutoresizingMaskIntoConstraints = NO;
		_outline = [[NSOutlineView alloc] initWithFrame:NSZeroRect];
		NSTableColumn *name = [[NSTableColumn alloc] initWithIdentifier:@"name"];
		name.title = QTR(@"Name", @"Nome");
		name.width = 170;
		NSTableColumn *size = [[NSTableColumn alloc] initWithIdentifier:@"size"];
		size.title = QTR(@"Size", @"Tamanho");
		size.width = 70;
		[_outline addTableColumn:name];
		[_outline addTableColumn:size];
		_outline.outlineTableColumn = name;
		_outline.dataSource = self;
		_outline.delegate = self;
		_outline.rowSizeStyle = NSTableViewRowSizeStyleSmall;
		_outline.target = self;
		_outline.doubleAction = @selector(openItem:);
		NSMenu *menu = [[NSMenu alloc] init];
		menu.delegate = self;
		_outline.menu = menu;
		scroll.documentView = _outline;

		_status = [NSTextField labelWithString:QTR(@"Not connected.", @"Desconectado.")];
		_status.font = [NSFont systemFontOfSize:11];
		_status.textColor = [NSColor secondaryLabelColor];
		_status.lineBreakMode = NSLineBreakByTruncatingTail;
		_status.translatesAutoresizingMaskIntoConstraints = NO;
		_spinner = [[NSProgressIndicator alloc] init];
		_spinner.style = NSProgressIndicatorStyleSpinning;
		_spinner.controlSize = NSControlSizeSmall;
		_spinner.displayedWhenStopped = NO;
		_spinner.translatesAutoresizingMaskIntoConstraints = NO;

		for (NSView *v in @[ _profiles, _connect, gear, _path, tools, scroll, _status, _spinner ]) [self addSubview:v];
		[NSLayoutConstraint activateConstraints:@[
			[_profiles.topAnchor constraintEqualToAnchor:self.topAnchor constant:6],
			[_profiles.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:6],
			[_connect.leadingAnchor constraintEqualToAnchor:_profiles.trailingAnchor constant:4],
			[_connect.centerYAnchor constraintEqualToAnchor:_profiles.centerYAnchor],
			[gear.leadingAnchor constraintEqualToAnchor:_connect.trailingAnchor constant:2],
			[gear.centerYAnchor constraintEqualToAnchor:_profiles.centerYAnchor],
			[gear.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-6],
			[_path.topAnchor constraintEqualToAnchor:_profiles.bottomAnchor constant:6],
			[_path.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:6],
			[tools.leadingAnchor constraintEqualToAnchor:_path.trailingAnchor constant:4],
			[tools.centerYAnchor constraintEqualToAnchor:_path.centerYAnchor],
			[tools.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-6],
			[scroll.topAnchor constraintEqualToAnchor:_path.bottomAnchor constant:6],
			[scroll.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
			[scroll.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
			[scroll.bottomAnchor constraintEqualToAnchor:_status.topAnchor constant:-4],
			[_spinner.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:6],
			[_spinner.centerYAnchor constraintEqualToAnchor:_status.centerYAnchor],
			[_status.leadingAnchor constraintEqualToAnchor:_spinner.trailingAnchor constant:4],
			[_status.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-6],
			[_status.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-6],
		]];
		[_profiles setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
		[_path setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
		[self reloadProfiles];
	}
	return self;
}

- (void)reloadProfiles {
	NSString *selected = _profiles.titleOfSelectedItem;
	[_profiles removeAllItems];
	NSArray *profiles = loadProfiles();
	if (profiles.count == 0) {
		[_profiles addItemWithTitle:QTR(@"No profiles — click ⚙︎", @"Sem perfis — clique em ⚙︎")];
		_profiles.enabled = NO;
		_connect.enabled = NO;
		return;
	}
	_profiles.enabled = YES;
	_connect.enabled = YES;
	for (NSDictionary *p in profiles) [_profiles addItemWithTitle:p[@"name"] ?: @"?"];
	if (selected && [_profiles itemWithTitle:selected]) [_profiles selectItemWithTitle:selected];
}

- (NSDictionary *)profileNamed:(NSString *)name {
	for (NSDictionary *p in loadProfiles())
		if ([p[@"name"] isEqualToString:name]) return p;
	return nil;
}

- (void)setBusy:(BOOL)busy text:(NSString *)text {
	_busy += busy ? 1 : -1;
	if (_busy < 0) _busy = 0;
	if (_busy) [_spinner startAnimation:nil];
	else [_spinner stopAnimation:nil];
	if (text) _status.stringValue = text;
}

// Runs work on the serial queue and calls done on the main thread.
- (void)run:(NSString *)message work:(OpResult (^)(QFTPSession *s))work done:(void (^)(OpResult r))done {
	QFTPSession *s = _session;
	if (!s) return;
	[self setBusy:YES text:message];
	[_queue addOperationWithBlock:^{
		OpResult r = work(s);
		dispatch_async(dispatch_get_main_queue(), ^{
			[self setBusy:NO text:nil];
			if (!r.ok) {
				NSString *err = [QStr(r.error) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
				self->_status.stringValue = [QTR(@"Error: ", @"Erro: ") stringByAppendingString:err.length ? err : @"?"];
				self->_status.toolTip = err;
			}
			done(r);
		});
	}];
}

- (void)toggleConnect:(id)sender {
	if (_session) {
		[self disconnect];
		return;
	}
	NSDictionary *p = [self profileNamed:_profiles.titleOfSelectedItem];
	if (!p) return;
	QFTPSession *s = [[QFTPSession alloc] init];
	s.profile = p;
	s.password = keychainPassword(p[@"name"]);
	if (!s.password.length && [p[@"askPassword"] boolValue]) {
		NSAlert *a = [[NSAlert alloc] init];
		a.messageText = [NSString stringWithFormat:QTR(@"Password for %@", @"Senha para %@"), p[@"name"]];
		NSSecureTextField *f = [[NSSecureTextField alloc] initWithFrame:NSMakeRect(0, 0, 240, 24)];
		a.accessoryView = f;
		[a addButtonWithTitle:QTR(@"Connect", @"Conectar")];
		[a addButtonWithTitle:QTR(@"Cancel", @"Cancelar")];
		a.window.initialFirstResponder = f;
		if ([a runModal] != NSAlertFirstButtonReturn) return;
		s.password = f.stringValue;
	}
	_session = s;
	NSString *start = [p[@"initialDir"] length] ? p[@"initialDir"] : ([p[@"protocol"] isEqualToString:@"sftp"] ? @"." : @"/");
	_root = [[QRemoteNode alloc] init];
	_root.path = start;
	_root.isDirectory = YES;
	_connect.title = QTR(@"Disconnect", @"Desconectar");
	[self loadNode:_root then:^(BOOL ok) {
		if (!ok) {
			[self disconnect];
			self->_status.stringValue = QTR(@"Connection failed. Check the profile, password or SSH key.", @"Falha na conexão. Verifique o perfil, a senha ou a chave SSH.");
			return;
		}
		self->_path.stringValue = self->_root.path;
		self->_status.stringValue = [NSString stringWithFormat:QTR(@"Connected to %@", @"Conectado a %@"), p[@"host"]];
	}];
}

- (void)disconnect {
	_session = nil;
	_root = nil;
	[_outline reloadData];
	_connect.title = QTR(@"Connect", @"Conectar");
	_status.stringValue = QTR(@"Not connected.", @"Desconectado.");
}

- (void)loadNode:(QRemoteNode *)node then:(void (^)(BOOL ok))then {
	if (node.loading) return;
	node.loading = YES;
	NSString *dir = node.path;
	[self run:[NSString stringWithFormat:QTR(@"Listing %@…", @"Listando %@…"), dir]
	     work:^OpResult(QFTPSession *s) {
		     return [s list:dir];
	     }
	     done:^(OpResult r) {
		     node.loading = NO;
		     if (r.ok) {
			     NSMutableArray *kids = [NSMutableArray array];
			     for (const auto &e : quill::parseDirectoryListing(r.output)) {
				     QRemoteNode *c = [[QRemoteNode alloc] init];
				     c.path = QStr(quill::joinRemotePath(QUtf8(dir), e.name));
				     c.isDirectory = e.isDirectory || (e.isLink && e.size < 100);
				     c.size = e.size;
				     c.modified = QStr(e.modified);
				     [kids addObject:c];
			     }
			     node.children = kids;
			     if (node == self->_root) [self->_outline reloadData];
			     else [self->_outline reloadItem:node reloadChildren:YES];
			     if (!self->_busy) self->_status.stringValue = [NSString stringWithFormat:QTR(@"%lu item(s) in %@", @"%lu item(ns) em %@"), (unsigned long)kids.count, dir];
		     }
		     if (then) then(r.ok);
	     }];
}

- (NSInteger)outlineView:(NSOutlineView *)ov numberOfChildrenOfItem:(id)item {
	QRemoteNode *n = item ?: _root;
	if (!n) return 0;
	if (!n.children) {
		if (item) [self loadNode:n then:nil];
		return 0;
	}
	return (NSInteger)n.children.count;
}

- (id)outlineView:(NSOutlineView *)ov child:(NSInteger)index ofItem:(id)item {
	QRemoteNode *n = item ?: _root;
	return n.children[(NSUInteger)index];
}

- (BOOL)outlineView:(NSOutlineView *)ov isItemExpandable:(id)item {
	return ((QRemoteNode *)item).isDirectory;
}

- (NSView *)outlineView:(NSOutlineView *)ov viewForTableColumn:(NSTableColumn *)col item:(id)item {
	QRemoteNode *n = item;
	NSTableCellView *cell = [ov makeViewWithIdentifier:col.identifier owner:self];
	if (!cell) {
		cell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 160, 18)];
		cell.identifier = col.identifier;
		NSTextField *tf = [NSTextField labelWithString:@""];
		tf.font = [NSFont systemFontOfSize:12];
		tf.lineBreakMode = NSLineBreakByTruncatingMiddle;
		if ([col.identifier isEqualToString:@"name"]) {
			NSImageView *iv = [[NSImageView alloc] initWithFrame:NSMakeRect(0, 1, 16, 16)];
			[cell addSubview:iv];
			cell.imageView = iv;
			tf.frame = NSMakeRect(20, 0, 140, 18);
		} else {
			tf.frame = NSMakeRect(0, 0, 70, 18);
			tf.alignment = NSTextAlignmentRight;
			tf.textColor = [NSColor secondaryLabelColor];
			tf.font = [NSFont systemFontOfSize:11];
		}
		tf.autoresizingMask = NSViewWidthSizable;
		[cell addSubview:tf];
		cell.textField = tf;
	}
	if ([col.identifier isEqualToString:@"name"]) {
		cell.textField.stringValue = n.path.lastPathComponent ?: @"";
		cell.imageView.image = n.isDirectory ? [NSImage imageWithSystemSymbolName:@"folder.fill" accessibilityDescription:nil]
						     : [[NSWorkspace sharedWorkspace] iconForContentType:[UTType typeWithFilenameExtension:n.path.pathExtension] ?: UTTypeData];
		cell.textField.toolTip = [NSString stringWithFormat:@"%@\n%@", n.path, n.modified ?: @""];
	} else {
		cell.textField.stringValue = n.isDirectory ? @"" : [NSByteCountFormatter stringFromByteCount:(long long)n.size countStyle:NSByteCountFormatterCountStyleFile];
	}
	return cell;
}

- (QRemoteNode *)clickedOrSelected {
	NSInteger row = _outline.clickedRow >= 0 ? _outline.clickedRow : _outline.selectedRow;
	return row >= 0 ? [_outline itemAtRow:row] : nil;
}

- (NSString *)targetDirectory {
	QRemoteNode *n = [self clickedOrSelected];
	if (!n) return _root.path;
	return n.isDirectory ? n.path : QStr(quill::parentRemotePath(QUtf8(n.path)));
}

- (QRemoteNode *)nodeForPath:(NSString *)path under:(QRemoteNode *)node {
	if ([node.path isEqualToString:path]) return node;
	for (QRemoteNode *c in node.children) {
		QRemoteNode *r = [self nodeForPath:path under:c];
		if (r) return r;
	}
	return nil;
}

- (void)reloadDirectory:(NSString *)dir {
	QRemoteNode *n = _root ? [self nodeForPath:dir under:_root] : nil;
	if (!n) n = _root;
	n.children = nil;
	[self loadNode:n then:nil];
}

- (void)openItem:(id)sender {
	QRemoteNode *n = [self clickedOrSelected];
	if (!n) return;
	if (n.isDirectory) {
		if ([_outline isItemExpanded:n]) [_outline collapseItem:n];
		else [_outline expandItem:n];
		return;
	}
	NSString *profile = _session.profile[@"name"];
	NSString *rel = [n.path hasPrefix:@"/"] ? [n.path substringFromIndex:1] : n.path;
	NSString *local = [[cacheRoot() stringByAppendingPathComponent:profile] stringByAppendingPathComponent:rel];
	NSString *remote = n.path;
	[self run:[NSString stringWithFormat:QTR(@"Downloading %@…", @"Baixando %@…"), n.path.lastPathComponent]
	     work:^OpResult(QFTPSession *s) {
		     return [s download:remote to:local];
	     }
	     done:^(OpResult r) {
		     if (!r.ok) return;
		     gMapping[local] = @{@"profile" : profile, @"remote" : remote};
		     // If the file is already open, reload it.
		     std::wstring wl = QWide(local);
		     host().npp(NPPM_RELOADFILE, 0, (LPARAM)wl.c_str());
		     host().openFile(wl);
		     self->_status.stringValue = [NSString stringWithFormat:QTR(@"Opened %@ (saving uploads it)", @"%@ aberto (salvar envia ao servidor)"), remote.lastPathComponent];
	     }];
}

- (void)fileSaved:(NSString *)local {
	NSDictionary *m = gMapping[local];
	if (!m) return;
	if (!_session || ![_session.profile[@"name"] isEqualToString:m[@"profile"]]) {
		status(QTR(@"FTP: connect to the profile again to upload this file.", @"FTP: conecte-se ao perfil novamente para enviar este arquivo."));
		return;
	}
	NSString *remote = m[@"remote"];
	[self run:[NSString stringWithFormat:QTR(@"Uploading %@…", @"Enviando %@…"), remote.lastPathComponent]
	     work:^OpResult(QFTPSession *s) {
		     return [s upload:local to:remote];
	     }
	     done:^(OpResult r) {
		     if (r.ok) {
			     self->_status.stringValue = [NSString stringWithFormat:QTR(@"Uploaded %@", @"%@ enviado"), remote];
			     status([NSString stringWithFormat:QTR(@"FTP: uploaded %@", @"FTP: %@ enviado"), remote]);
		     } else {
			     status([NSString stringWithFormat:QTR(@"FTP: upload of %@ FAILED", @"FTP: FALHA ao enviar %@"), remote]);
		     }
	     }];
}

- (void)uploadLocal:(NSString *)local toDirectory:(NSString *)dir {
	NSString *remote = QStr(quill::joinRemotePath(QUtf8(dir), QUtf8(local.lastPathComponent)));
	[self run:[NSString stringWithFormat:QTR(@"Uploading %@…", @"Enviando %@…"), local.lastPathComponent]
	     work:^OpResult(QFTPSession *s) {
		     return [s upload:local to:remote];
	     }
	     done:^(OpResult r) {
		     if (r.ok) {
			     gMapping[local] = @{@"profile" : self->_session.profile[@"name"] ?: @"", @"remote" : remote};
			     [self reloadDirectory:dir];
		     }
	     }];
}

- (void)uploadCurrentFileAsk:(BOOL)ask {
	NSString *local = QStr(host().currentPath());
	if (![[NSFileManager defaultManager] fileExistsAtPath:local]) {
		alert(QTR(@"Save the file first", @"Salve o arquivo primeiro"), @"");
		return;
	}
	if (!_session) {
		ensurePanel();
		gDock.show();
		alert(QTR(@"Not connected", @"Desconectado"), QTR(@"Connect to a server in the FTP panel first.", @"Conecte-se a um servidor no painel FTP primeiro."));
		return;
	}
	if (gMapping[local]) {
		[self fileSaved:local];
		return;
	}
	[self uploadLocal:local toDirectory:[self targetDirectory]];
}

- (void)uploadFile:(id)sender {
	if (!_session) return;
	NSOpenPanel *p = [NSOpenPanel openPanel];
	p.allowsMultipleSelection = YES;
	if ([p runModal] != NSModalResponseOK) return;
	NSString *dir = [self targetDirectory];
	for (NSURL *u in p.URLs) [self uploadLocal:u.path toDirectory:dir];
}

- (NSString *)askName:(NSString *)title initial:(NSString *)initial {
	NSAlert *a = [[NSAlert alloc] init];
	a.messageText = title;
	NSTextField *f = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 260, 24)];
	f.stringValue = initial ?: @"";
	a.accessoryView = f;
	[a addButtonWithTitle:@"OK"];
	[a addButtonWithTitle:QTR(@"Cancel", @"Cancelar")];
	a.window.initialFirstResponder = f;
	if ([a runModal] != NSAlertFirstButtonReturn) return nil;
	return f.stringValue.length && ![f.stringValue containsString:@"/"] ? f.stringValue : nil;
}

- (void)newFolder:(id)sender {
	if (!_session) return;
	NSString *dir = [self targetDirectory];
	NSString *name = [self askName:QTR(@"New folder name", @"Nome da nova pasta") initial:@""];
	if (!name) return;
	NSString *remote = QStr(quill::joinRemotePath(QUtf8(dir), QUtf8(name)));
	[self run:QTR(@"Creating folder…", @"Criando pasta…")
	     work:^OpResult(QFTPSession *s) {
		     return [s mkdir:remote];
	     }
	     done:^(OpResult r) {
		     if (r.ok) [self reloadDirectory:dir];
	     }];
}

- (void)deleteItem:(id)sender {
	QRemoteNode *n = [self clickedOrSelected];
	if (!n || !_session) return;
	NSAlert *a = [[NSAlert alloc] init];
	a.messageText = [NSString stringWithFormat:QTR(@"Delete \"%@\" on the server?", @"Apagar \"%@\" no servidor?"), n.path.lastPathComponent];
	a.informativeText = n.isDirectory ? QTR(@"Only empty folders can be deleted.", @"Só pastas vazias podem ser apagadas.") : @"";
	[a addButtonWithTitle:QTR(@"Delete", @"Apagar")];
	[a addButtonWithTitle:QTR(@"Cancel", @"Cancelar")];
	if ([a runModal] != NSAlertFirstButtonReturn) return;
	NSString *path = n.path;
	BOOL isDir = n.isDirectory;
	NSString *parent = QStr(quill::parentRemotePath(QUtf8(path)));
	[self run:QTR(@"Deleting…", @"Apagando…")
	     work:^OpResult(QFTPSession *s) {
		     return [s remove:path isDirectory:isDir];
	     }
	     done:^(OpResult r) {
		     if (r.ok) [self reloadDirectory:parent];
	     }];
}

- (void)renameItem:(id)sender {
	QRemoteNode *n = [self clickedOrSelected];
	if (!n || !_session) return;
	NSString *name = [self askName:QTR(@"Rename", @"Renomear") initial:n.path.lastPathComponent];
	if (!name) return;
	NSString *parent = QStr(quill::parentRemotePath(QUtf8(n.path)));
	NSString *from = n.path;
	NSString *to = QStr(quill::joinRemotePath(QUtf8(parent), QUtf8(name)));
	[self run:QTR(@"Renaming…", @"Renomeando…")
	     work:^OpResult(QFTPSession *s) {
		     return [s rename:from to:to];
	     }
	     done:^(OpResult r) {
		     if (r.ok) [self reloadDirectory:parent];
	     }];
}

- (void)copyRemotePath:(id)sender {
	QRemoteNode *n = [self clickedOrSelected];
	if (!n) return;
	[[NSPasteboard generalPasteboard] clearContents];
	[[NSPasteboard generalPasteboard] setString:n.path forType:NSPasteboardTypeString];
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
	[menu removeAllItems];
	if (!_session) return;
	QRemoteNode *n = [self clickedOrSelected];
	auto add = ^(NSString *t, SEL s) {
		NSMenuItem *mi = [menu addItemWithTitle:t action:s keyEquivalent:@""];
		mi.target = self;
	};
	if (n && !n.isDirectory) add(QTR(@"Open", @"Abrir"), @selector(openItem:));
	add(QTR(@"Upload File Here…", @"Enviar arquivo para cá…"), @selector(uploadFile:));
	add(QTR(@"New Folder…", @"Nova pasta…"), @selector(newFolder:));
	if (n) {
		add(QTR(@"Rename…", @"Renomear…"), @selector(renameItem:));
		add(QTR(@"Delete…", @"Apagar…"), @selector(deleteItem:));
		add(QTR(@"Copy Remote Path", @"Copiar caminho remoto"), @selector(copyRemotePath:));
	}
	add(QTR(@"Refresh", @"Atualizar"), @selector(refresh:));
}

- (void)goPath:(NSTextField *)sender {
	if (!_session || !sender.stringValue.length) return;
	_root = [[QRemoteNode alloc] init];
	_root.path = sender.stringValue;
	_root.isDirectory = YES;
	[self loadNode:_root then:nil];
}

- (void)goUp:(id)sender {
	if (!_session || !_root) return;
	NSString *parent = QStr(quill::parentRemotePath(QUtf8(_root.path)));
	if ([_root.path isEqualToString:@"."]) parent = @"..";
	_path.stringValue = parent;
	[self goPath:_path];
}

- (void)refresh:(id)sender {
	if (!_session || !_root) return;
	_root.children = nil;
	[self loadNode:_root then:nil];
}

- (void)manage:(id)sender {
	cmdProfiles();
}

@end

// ---- Profile manager ------------------------------------------------------------------------------

@implementation QProfilesWindow {
	NSMutableArray<NSMutableDictionary *> *_profiles;
	NSTableView *_table;
	NSTextField *_name, *_host, *_port, *_user, *_dir, *_key;
	NSSecureTextField *_password;
	NSPopUpButton *_protocol;
	NSButton *_askPassword, *_insecure;
	NSTextField *_testResult;
	NSInteger _editing;
}

- (instancetype)init {
	NSWindow *w = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 680, 420)
						  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
						    backing:NSBackingStoreBuffered
						      defer:YES];
	w.title = QTR(@"FTP Profiles", @"Perfis FTP");
	w.releasedWhenClosed = NO;
	if ((self = [super initWithWindow:w])) {
		_profiles = loadProfiles();
		_editing = -1;
		[self build];
		[w center];
		if (_profiles.count) [self select:0];
	}
	return self;
}

- (NSTextField *)field:(NSString *)placeholder {
	NSTextField *f = [NSTextField textFieldWithString:@""];
	f.placeholderString = placeholder;
	[f.widthAnchor constraintEqualToConstant:300].active = YES;
	return f;
}

static NSTextField *rlabel(NSString *s) {
	NSTextField *l = [NSTextField labelWithString:s];
	l.alignment = NSTextAlignmentRight;
	return l;
}

- (void)build {
	NSView *c = self.window.contentView;
	NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(16, 56, 200, 348)];
	scroll.hasVerticalScroller = YES;
	scroll.borderType = NSBezelBorder;
	_table = [[NSTableView alloc] initWithFrame:scroll.bounds];
	NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:@"name"];
	col.title = QTR(@"Profiles", @"Perfis");
	col.width = 190;
	[_table addTableColumn:col];
	_table.dataSource = self;
	_table.delegate = self;
	scroll.documentView = _table;
	[c addSubview:scroll];
	NSButton *add = [NSButton buttonWithTitle:@"+" target:self action:@selector(addProfile:)];
	NSButton *remove = [NSButton buttonWithTitle:@"−" target:self action:@selector(removeProfile:)];
	add.frame = NSMakeRect(16, 16, 40, 30);
	remove.frame = NSMakeRect(58, 16, 40, 30);
	[c addSubview:add];
	[c addSubview:remove];

	_name = [self field:QTR(@"My server", @"Meu servidor")];
	_protocol = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
	[_protocol addItemsWithTitles:@[ @"SFTP (SSH)", @"FTP", QTR(@"FTPS (explicit TLS)", @"FTPS (TLS explícito)"), QTR(@"FTPS (implicit TLS)", @"FTPS (TLS implícito)") ]];
	_host = [self field:@"example.com"];
	_port = [self field:QTR(@"default", @"padrão")];
	_user = [self field:QTR(@"user name", @"usuário")];
	_password = [[NSSecureTextField alloc] initWithFrame:NSZeroRect];
	_password.placeholderString = QTR(@"stored in the Keychain (optional for SSH keys)", @"guardada no Keychain (opcional com chave SSH)");
	[_password.widthAnchor constraintEqualToConstant:300].active = YES;
	_askPassword = [NSButton checkboxWithTitle:QTR(@"Ask for the password when connecting", @"Pedir a senha ao conectar") target:nil action:nil];
	_key = [self field:@"~/.ssh/id_ed25519"];
	NSButton *chooseKey = [NSButton buttonWithTitle:QTR(@"Choose…", @"Escolher…") target:self action:@selector(chooseKey:)];
	NSStackView *keyRow = [NSStackView stackViewWithViews:@[ _key, chooseKey ]];
	_dir = [self field:QTR(@"/var/www (empty = home)", @"/var/www (vazio = pasta inicial)")];
	_insecure = [NSButton checkboxWithTitle:QTR(@"Accept invalid TLS certificates (FTPS)", @"Aceitar certificados TLS inválidos (FTPS)") target:nil action:nil];
	NSView *empty = [NSGridCell emptyContentView];
	NSGridView *grid = [NSGridView gridViewWithViews:@[
		@[ rlabel(QTR(@"Name:", @"Nome:")), _name ],
		@[ rlabel(QTR(@"Protocol:", @"Protocolo:")), _protocol ],
		@[ rlabel(QTR(@"Host:", @"Servidor:")), _host ],
		@[ rlabel(QTR(@"Port:", @"Porta:")), _port ],
		@[ rlabel(QTR(@"User:", @"Usuário:")), _user ],
		@[ rlabel(QTR(@"Password:", @"Senha:")), _password ],
		@[ empty, _askPassword ],
		@[ rlabel(QTR(@"SSH key:", @"Chave SSH:")), keyRow ],
		@[ rlabel(QTR(@"Start folder:", @"Pasta inicial:")), _dir ],
		@[ empty, _insecure ],
	]];
	grid.rowSpacing = 8;
	grid.columnSpacing = 8;
	grid.frame = NSMakeRect(232, 60, 430, 340);
	[c addSubview:grid];

	NSButton *save = [NSButton buttonWithTitle:QTR(@"Save", @"Salvar") target:self action:@selector(saveProfile:)];
	save.keyEquivalent = @"\r";
	NSButton *test = [NSButton buttonWithTitle:QTR(@"Test Connection", @"Testar conexão") target:self action:@selector(testProfile:)];
	save.frame = NSMakeRect(560, 16, 104, 30);
	test.frame = NSMakeRect(420, 16, 136, 30);
	[c addSubview:save];
	[c addSubview:test];
	_testResult = [NSTextField labelWithString:@""];
	_testResult.frame = NSMakeRect(110, 22, 300, 18);
	_testResult.textColor = [NSColor secondaryLabelColor];
	_testResult.lineBreakMode = NSLineBreakByTruncatingTail;
	[c addSubview:_testResult];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv {
	return (NSInteger)_profiles.count;
}

- (NSView *)tableView:(NSTableView *)tv viewForTableColumn:(NSTableColumn *)col row:(NSInteger)row {
	NSTextField *tf = [NSTextField labelWithString:_profiles[(NSUInteger)row][@"name"] ?: @""];
	return tf;
}

- (void)tableViewSelectionDidChange:(NSNotification *)n {
	if (_table.selectedRow >= 0) [self select:_table.selectedRow];
}

static NSArray *protocols() {
	return @[ @"sftp", @"ftp", @"ftps", @"ftps-implicit" ];
}

- (void)select:(NSInteger)row {
	_editing = row;
	NSDictionary *p = _profiles[(NSUInteger)row];
	_name.stringValue = p[@"name"] ?: @"";
	NSUInteger proto = [protocols() indexOfObject:p[@"protocol"] ?: @"sftp"];
	[_protocol selectItemAtIndex:proto == NSNotFound ? 0 : (NSInteger)proto];
	_host.stringValue = p[@"host"] ?: @"";
	_port.stringValue = [p[@"port"] integerValue] > 0 ? [p[@"port"] stringValue] : @"";
	_user.stringValue = p[@"user"] ?: @"";
	_password.stringValue = keychainPassword(p[@"name"]) ?: @"";
	_askPassword.state = [p[@"askPassword"] boolValue];
	_key.stringValue = p[@"keyFile"] ?: @"";
	_dir.stringValue = p[@"initialDir"] ?: @"";
	_insecure.state = [p[@"insecureTLS"] boolValue];
	if (_table.selectedRow != row) [_table selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)row] byExtendingSelection:NO];
}

- (NSMutableDictionary *)formProfile {
	NSMutableDictionary *p = [NSMutableDictionary dictionary];
	p[@"name"] = _name.stringValue.length ? _name.stringValue : _host.stringValue;
	p[@"protocol"] = protocols()[(NSUInteger)MAX(0, _protocol.indexOfSelectedItem)];
	p[@"host"] = [_host.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	p[@"port"] = @(_port.integerValue);
	p[@"user"] = _user.stringValue;
	p[@"askPassword"] = @(_askPassword.state == NSControlStateValueOn);
	p[@"keyFile"] = _key.stringValue;
	p[@"initialDir"] = _dir.stringValue;
	p[@"insecureTLS"] = @(_insecure.state == NSControlStateValueOn);
	return p;
}

- (void)addProfile:(id)sender {
	NSMutableDictionary *p = [@{@"name" : QTR(@"New profile", @"Novo perfil"), @"protocol" : @"sftp"} mutableCopy];
	[_profiles addObject:p];
	[_table reloadData];
	[self select:(NSInteger)_profiles.count - 1];
	[self.window makeFirstResponder:_name];
}

- (void)removeProfile:(id)sender {
	if (_editing < 0 || _editing >= (NSInteger)_profiles.count) return;
	setKeychainPassword(_profiles[(NSUInteger)_editing][@"name"], nil);
	[_profiles removeObjectAtIndex:(NSUInteger)_editing];
	saveProfiles(_profiles);
	_editing = -1;
	[_table reloadData];
	if (_profiles.count) [self select:0];
	[gPanel reloadProfiles];
}

- (void)saveProfile:(id)sender {
	NSMutableDictionary *p = [self formProfile];
	if (![p[@"host"] length]) {
		NSBeep();
		return;
	}
	if (_editing >= 0 && _editing < (NSInteger)_profiles.count) {
		NSString *oldName = _profiles[(NSUInteger)_editing][@"name"];
		if (![oldName isEqualToString:p[@"name"]]) setKeychainPassword(oldName, nil);
		_profiles[(NSUInteger)_editing] = p;
	} else {
		[_profiles addObject:p];
		_editing = (NSInteger)_profiles.count - 1;
	}
	setKeychainPassword(p[@"name"], _password.stringValue);
	saveProfiles(_profiles);
	[_table reloadData];
	[gPanel reloadProfiles];
	_testResult.stringValue = QTR(@"Saved.", @"Salvo.");
}

- (void)testProfile:(id)sender {
	QFTPSession *s = [[QFTPSession alloc] init];
	NSMutableDictionary *p = [self formProfile];
	s.profile = p;
	s.password = _password.stringValue;
	NSString *dir = [p[@"initialDir"] length] ? p[@"initialDir"] : ([p[@"protocol"] isEqualToString:@"sftp"] ? @"." : @"/");
	_testResult.stringValue = QTR(@"Connecting…", @"Conectando…");
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
		OpResult r = [s list:dir];
		dispatch_async(dispatch_get_main_queue(), ^{
			if (r.ok) {
				size_t n = quill::parseDirectoryListing(r.output).size();
				self->_testResult.stringValue = [NSString stringWithFormat:QTR(@"Success: %zu item(s) in %@", @"Sucesso: %zu item(ns) em %@"), n, dir];
				self->_testResult.textColor = [NSColor systemGreenColor];
			} else {
				NSString *err = [QStr(r.error) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
				self->_testResult.stringValue = [QTR(@"Failed: ", @"Falhou: ") stringByAppendingString:err];
				self->_testResult.toolTip = err;
				self->_testResult.textColor = [NSColor systemRedColor];
			}
		});
	});
}

- (void)chooseKey:(id)sender {
	NSOpenPanel *p = [NSOpenPanel openPanel];
	p.showsHiddenFiles = YES;
	p.directoryURL = [NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:@".ssh"]];
	if ([p runModal] == NSModalResponseOK) _key.stringValue = [p.URL.path stringByAbbreviatingWithTildeInPath];
}

@end
