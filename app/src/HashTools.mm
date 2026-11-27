// SPDX-License-Identifier: GPL-3.0-or-later
#import "HashTools.h"
#import "Localization.h"
#import "MainWindowController.h"

#import <CommonCrypto/CommonDigest.h>

@implementation QHashTools

+ (instancetype)shared {
	static QHashTools *t;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		t = [[QHashTools alloc] init];
	});
	return t;
}

+ (NSString *)nameOfAlgorithm:(QHashAlgorithm)algorithm {
	switch (algorithm) {
	case QHashMD5: return @"MD5";
	case QHashSHA1: return @"SHA-1";
	case QHashSHA256: return @"SHA-256";
	case QHashSHA512: return @"SHA-512";
	}
	return @"";
}

+ (NSString *)digestOfData:(NSData *)data algorithm:(QHashAlgorithm)algorithm {
	NSUInteger length = 0;
	unsigned char *out = NULL;
	NSMutableData *buf;
	switch (algorithm) {
	case QHashMD5:
		length = CC_MD5_DIGEST_LENGTH;
		buf = [NSMutableData dataWithLength:length];
		CC_MD5(data.bytes, (CC_LONG)data.length, (unsigned char *)buf.mutableBytes);
		break;
	case QHashSHA1:
		length = CC_SHA1_DIGEST_LENGTH;
		buf = [NSMutableData dataWithLength:length];
		CC_SHA1(data.bytes, (CC_LONG)data.length, (unsigned char *)buf.mutableBytes);
		break;
	case QHashSHA256:
		length = CC_SHA256_DIGEST_LENGTH;
		buf = [NSMutableData dataWithLength:length];
		CC_SHA256(data.bytes, (CC_LONG)data.length, (unsigned char *)buf.mutableBytes);
		break;
	case QHashSHA512:
		length = CC_SHA512_DIGEST_LENGTH;
		buf = [NSMutableData dataWithLength:length];
		CC_SHA512(data.bytes, (CC_LONG)data.length, (unsigned char *)buf.mutableBytes);
		break;
	default:
		return @"";
	}
	(void)out;
	NSMutableString *hex = [NSMutableString stringWithCapacity:length * 2];
	const unsigned char *b = (const unsigned char *)buf.bytes;
	for (NSUInteger i = 0; i < length; i++) [hex appendFormat:@"%02x", b[i]];
	return hex;
}

// Text to hash: the selection if there is one, otherwise the whole document.
- (NSString *)currentTextOrSelection {
	QDocument *d = [QMainWindowController shared].currentDocument;
	if (!d) return nil;
	NSString *sel = d.editor.selectedString;
	return sel.length ? sel : d.text;
}

- (QHashAlgorithm)algorithmFor:(NSMenuItem *)sender {
	return (QHashAlgorithm)sender.tag;
}

- (void)showResult:(NSString *)title body:(NSString *)body {
	NSAlert *a = [[NSAlert alloc] init];
	a.messageText = title;
	NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 520, 160)];
	scroll.hasVerticalScroller = YES;
	NSTextView *tv = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 520, 160)];
	tv.editable = NO;
	tv.selectable = YES;
	tv.font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular];
	tv.string = body;
	tv.textContainer.widthTracksTextView = YES;
	scroll.documentView = tv;
	a.accessoryView = scroll;
	[a addButtonWithTitle:T(@"OK", @"OK")];
	[a addButtonWithTitle:T(@"Copy", @"Copiar")];
	if ([a runModal] == NSAlertSecondButtonReturn) {
		[[NSPasteboard generalPasteboard] clearContents];
		[[NSPasteboard generalPasteboard] setString:body forType:NSPasteboardTypeString];
	}
}

- (void)fromText:(NSMenuItem *)sender {
	QHashAlgorithm alg = [self algorithmFor:sender];
	NSString *text = [self currentTextOrSelection];
	if (!text) return;
	NSString *digest = [QHashTools digestOfData:[text dataUsingEncoding:NSUTF8StringEncoding] algorithm:alg];
	[self showResult:[NSString stringWithFormat:T(@"%@ digest", @"Resumo %@"), [QHashTools nameOfAlgorithm:alg]] body:digest];
}

- (void)intoClipboard:(NSMenuItem *)sender {
	QHashAlgorithm alg = [self algorithmFor:sender];
	NSString *text = [self currentTextOrSelection];
	if (!text) return;
	NSString *digest = [QHashTools digestOfData:[text dataUsingEncoding:NSUTF8StringEncoding] algorithm:alg];
	[[NSPasteboard generalPasteboard] clearContents];
	[[NSPasteboard generalPasteboard] setString:digest forType:NSPasteboardTypeString];
	[[QMainWindowController shared] setStatusMessage:[NSString stringWithFormat:T(@"%@ copied to the clipboard", @"%@ copiado para a área de transferência"), [QHashTools nameOfAlgorithm:alg]]];
}

- (void)fromFiles:(NSMenuItem *)sender {
	QHashAlgorithm alg = [self algorithmFor:sender];
	NSOpenPanel *p = [NSOpenPanel openPanel];
	p.allowsMultipleSelection = YES;
	p.message = T(@"Choose files to generate the digest", @"Escolha os arquivos para gerar o resumo");
	if ([p runModal] != NSModalResponseOK) return;
	NSMutableString *out = [NSMutableString string];
	for (NSURL *u in p.URLs) {
		NSData *data = [NSData dataWithContentsOfURL:u options:NSDataReadingMappedIfSafe error:nil];
		if (!data) {
			[out appendFormat:@"ERROR  %@\n", u.lastPathComponent];
			continue;
		}
		[out appendFormat:@"%@  %@\n", [QHashTools digestOfData:data algorithm:alg], u.lastPathComponent];
	}
	[self showResult:[NSString stringWithFormat:T(@"%@ digest of files", @"Resumo %@ dos arquivos"), [QHashTools nameOfAlgorithm:alg]]
		    body:out];
}

@end
