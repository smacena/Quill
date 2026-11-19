// SPDX-License-Identifier: GPL-3.0-or-later
#import "Localization.h"

static NSString *const kLanguageKey = @"UILanguage";
static QUILanguage gLanguage = (QUILanguage)-1;

QUILanguage QCurrentLanguage(void) {
	if ((NSInteger)gLanguage >= 0)
		return gLanguage;
	NSString *stored = [[NSUserDefaults standardUserDefaults] stringForKey:kLanguageKey];
	if ([stored isEqualToString:@"pt"]) {
		gLanguage = QUILanguagePortuguese;
	} else if ([stored isEqualToString:@"en"]) {
		gLanguage = QUILanguageEnglish;
	} else {
		NSString *preferred = [NSLocale preferredLanguages].firstObject ?: @"en";
		gLanguage = [preferred hasPrefix:@"pt"] ? QUILanguagePortuguese : QUILanguageEnglish;
	}
	return gLanguage;
}

void QSetLanguage(QUILanguage lang) {
	[[NSUserDefaults standardUserDefaults] setObject:(lang == QUILanguagePortuguese ? @"pt" : @"en") forKey:kLanguageKey];
	// The running UI keeps its language until restart, so gLanguage is not changed.
}

NSString *T(NSString *en, NSString *pt) {
	return QCurrentLanguage() == QUILanguagePortuguese ? pt : en;
}
