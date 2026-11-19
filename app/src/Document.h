// An open document: file metadata plus its own Scintilla editor view.
// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#import <Cocoa/Cocoa.h>
#include <string>

#import "ScintillaView.h"
@class QLanguage;
@class QDocument;

// Editor view used for documents: adds a customizable context menu.
@interface QEditorView : ScintillaView
// Builds the context menu for an editor (set once by the main window controller).
+ (void)setContextMenuBuilder:(NSMenu * (^)(QEditorView *view, NSEvent *event))builder;
@property (nonatomic, weak) QDocument *document;
@end

@protocol QDocumentNotificationTarget <NSObject>
- (void)document:(QDocument *)doc notification:(SCNotification *)notification;
@end

// Values match quill::TextEncoding / quill::LineEnding.
typedef NS_ENUM(NSInteger, QEncoding) {
	QEncodingUTF8 = 0,
	QEncodingUTF8BOM,
	QEncodingUTF16LE,
	QEncodingUTF16BE,
	QEncodingWindows1252,
	QEncodingLatin1,
	QEncodingMacRoman,
};
typedef NS_ENUM(NSInteger, QLineEnding) {
	QLineEndingLF = 0,
	QLineEndingCRLF,
	QLineEndingCR,
};

NSString *QEncodingName(QEncoding e);
NSString *QLineEndingName(QLineEnding e);

@interface QDocument : NSObject <ScintillaNotificationProtocol>

- (instancetype)initUntitled:(NSString *)name;

@property (nonatomic, readonly) NSUInteger bufferID;     // unique, stable id (Notepad++ buffer ID)
@property (nonatomic, copy) NSString *path;              // nil when untitled
@property (nonatomic, copy) NSString *untitledName;      // "new 1"
@property (nonatomic, readonly) QEditorView *editor;
@property (nonatomic, weak) id<QDocumentNotificationTarget> notificationTarget;
@property (nonatomic) QEncoding encoding;
@property (nonatomic) QLineEnding lineEnding;
@property (nonatomic, strong) QLanguage *language;
@property (nonatomic) BOOL readOnly;
@property (nonatomic, strong) NSDate *fileModificationDate;
@property (nonatomic) BOOL fileMissing;                  // file was deleted / moved on disk
@property (nonatomic, readonly) BOOL isDirty;
@property (nonatomic, readonly) BOOL isUntitled;
@property (nonatomic, readonly) NSString *displayName;
@property (nonatomic) BOOL pinned;
// Marks the document as modified without changing its text (e.g. encoding change).
@property (nonatomic) BOOL forcedDirty;
@property (nonatomic, copy) NSString *backupPath;        // unsaved-changes backup file

// Loads a file (detects encoding, line endings and language).
- (BOOL)loadFromPath:(NSString *)path error:(NSError **)error;
// Reloads using a specific encoding (Encoding > Reopen with...).
- (BOOL)reloadWithEncoding:(QEncoding)encoding error:(NSError **)error;
// Writes the editor text using the document encoding / line endings.
- (BOOL)saveToPath:(NSString *)path error:(NSError **)error;
// Writes a copy without changing the document's path / dirty state.
- (BOOL)writeCopyToPath:(NSString *)path error:(NSError **)error;

// Text helpers
- (NSString *)text;
- (void)setText:(NSString *)text;
- (std::string)utf8Text;
- (void)setUTF8Text:(const std::string &)text;

- (void)markSaved;
- (void)convertLineEndingsTo:(QLineEnding)eol;
- (void)setLanguageAndRestyle:(QLanguage *)language;
- (void)restyle;
// True when the file on disk changed after it was loaded / saved.
- (BOOL)changedOnDisk;
@end
