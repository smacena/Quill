// Automated end-to-end check run in CI: `Quill --selftest <outdir>`.
// Opens sample files, exercises editor features and plugins, writes
// screenshots and a results.txt file, then quits with exit code 0 / 1.
// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#import <Cocoa/Cocoa.h>

@interface QSelfTest : NSObject
- (instancetype)initWithOutputDirectory:(NSString *)dir;
- (void)run;
// Only opens a file and takes a screenshot (used to check the Portuguese UI).
@property (nonatomic) BOOL quick;
@end
