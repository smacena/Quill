// Tools menu: MD5, SHA-1, SHA-256 and SHA-512 digests of text or files.
// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#import <Cocoa/Cocoa.h>

typedef NS_ENUM(NSInteger, QHashAlgorithm) {
	QHashMD5 = 0,
	QHashSHA1,
	QHashSHA256,
	QHashSHA512,
};

@interface QHashTools : NSObject
+ (instancetype)shared;
// Lower-case hexadecimal digest of data.
+ (NSString *)digestOfData:(NSData *)data algorithm:(QHashAlgorithm)algorithm;
+ (NSString *)nameOfAlgorithm:(QHashAlgorithm)algorithm;
// Menu actions (target is QHashTools.shared).
- (void)fromText:(NSMenuItem *)sender;
- (void)fromFiles:(NSMenuItem *)sender;
- (void)intoClipboard:(NSMenuItem *)sender;
@end
