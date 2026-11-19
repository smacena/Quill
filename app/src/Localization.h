// User interface language (English / Portuguese).
// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, QUILanguage) {
	QUILanguageEnglish = 0,
	QUILanguagePortuguese = 1,
};

#ifdef __cplusplus
extern "C" {
#endif

// Current UI language (from user defaults, default: system language).
QUILanguage QCurrentLanguage(void);
void QSetLanguage(QUILanguage lang);

// Returns the English or Portuguese string according to the UI language.
NSString *T(NSString *en, NSString *pt);

#ifdef __cplusplus
}
#endif
