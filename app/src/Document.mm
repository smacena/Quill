// SPDX-License-Identifier: GPL-3.0-or-later
#import "Document.h"
#import "Languages.h"
#import "Localization.h"
#import "Preferences.h"

#import "ScintillaView.h"
#include "Scintilla.h"
#include "quill/Encoding.h"

NSString *QEncodingName(QEncoding e) {
	return @(quill::encodingName(static_cast<quill::TextEncoding>(e)));
}

NSString *QLineEndingName(QLineEnding e) {
	switch (e) {
	case QLineEndingLF: return T(@"Unix (LF)", @"Unix (LF)");
	case QLineEndingCRLF: return T(@"Windows (CR LF)", @"Windows (CR LF)");
	case QLineEndingCR: return T(@"Classic Mac (CR)", @"Mac clássico (CR)");
	}
	return @"LF";
}

static NSUInteger gNextBufferID = 1;

static NSMenu * (^gContextMenuBuilder)(QEditorView *, NSEvent *);

@implementation QEditorView
+ (void)setContextMenuBuilder:(NSMenu * (^)(QEditorView *, NSEvent *))builder {
	gContextMenuBuilder = [builder copy];
}
- (NSMenu *)menuForEvent:(NSEvent *)event {
	if (gContextMenuBuilder) return gContextMenuBuilder(self, event);
	return [super menuForEvent:event];
}
@end

@implementation QDocument {
	QEditorView *_editor;
	NSUInteger _bufferID;
}

- (instancetype)init {
	if ((self = [super init])) {
		_bufferID = gNextBufferID++;
		_editor = [[QEditorView alloc] initWithFrame:NSMakeRect(0, 0, 800, 600)];
		_editor.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
		_editor.document = self;
		_editor.delegate = self;
		[QEditorStyler configureEditor:_editor];
		QPrefs *p = [QPrefs shared];
		_encoding = (QEncoding)p.defaultEncoding;
		_lineEnding = (QLineEnding)p.defaultLineEnding;
		[self applyEOLMode];
		_language = [QLanguageManager shared].plainText;
		[QEditorStyler applyLanguage:_language toEditor:_editor];
	}
	return self;
}

- (instancetype)initUntitled:(NSString *)name {
	if ((self = [self init])) {
		_untitledName = [name copy];
	}
	return self;
}

- (NSUInteger)bufferID {
	return _bufferID;
}

- (QEditorView *)editor {
	return _editor;
}

- (void)notification:(SCNotification *)notification {
	[self.notificationTarget document:self notification:notification];
}

- (void)dealloc {
	_editor.delegate = nil;
}

- (BOOL)isUntitled {
	return _path == nil;
}

- (BOOL)isDirty {
	return _forcedDirty || [_editor message:SCI_GETMODIFY] != 0;
}

- (NSString *)displayName {
	return _path ? _path.lastPathComponent : (_untitledName ?: @"new");
}

- (void)applyEOLMode {
	int mode = SC_EOL_LF;
	if (_lineEnding == QLineEndingCRLF) mode = SC_EOL_CRLF;
	else if (_lineEnding == QLineEndingCR) mode = SC_EOL_CR;
	[_editor message:SCI_SETEOLMODE wParam:(uptr_t)mode];
}

- (NSString *)text {
	std::string s = [self utf8Text];
	return [[NSString alloc] initWithBytes:s.data() length:s.size() encoding:NSUTF8StringEncoding] ?: @"";
}

- (void)setText:(NSString *)text {
	[self setUTF8Text:std::string(text.UTF8String ?: "")];
}

- (std::string)utf8Text {
	sptr_t len = [_editor message:SCI_GETLENGTH];
	const char *ptr = reinterpret_cast<const char *>([_editor message:SCI_GETCHARACTERPOINTER]);
	return ptr ? std::string(ptr, static_cast<size_t>(len)) : std::string();
}

- (void)setUTF8Text:(const std::string &)text {
	[_editor message:SCI_SETTEXT wParam:0 lParam:(sptr_t)text.c_str()];
}

- (void)markSaved {
	_forcedDirty = NO;
	[_editor message:SCI_SETSAVEPOINT];
}

static NSError *QError(NSString *message) {
	return [NSError errorWithDomain:@"Quill" code:1 userInfo:@{NSLocalizedDescriptionKey : message}];
}

- (BOOL)loadBytes:(NSData *)data encoding:(QEncoding)encoding detect:(BOOL)detect {
	std::string bytes(static_cast<const char *>(data.bytes), data.length);
	quill::TextEncoding enc = detect ? quill::detectEncoding(bytes) : static_cast<quill::TextEncoding>(encoding);
	std::string utf8 = quill::decodeToUtf8(bytes, enc);
	_encoding = static_cast<QEncoding>(enc);
	_lineEnding = static_cast<QLineEnding>(quill::detectLineEnding(utf8));
	[_editor message:SCI_SETREADONLY wParam:0];
	[_editor message:SCI_CLEARALL];
	[_editor message:SCI_SETUNDOCOLLECTION wParam:0];
	[_editor message:SCI_SETCHANGEHISTORY wParam:SC_CHANGE_HISTORY_DISABLED];
	[_editor message:SCI_ALLOCATE wParam:(uptr_t)utf8.size() + 1];
	[_editor message:SCI_ADDTEXT wParam:(uptr_t)utf8.size() lParam:(sptr_t)utf8.data()];
	[_editor message:SCI_SETUNDOCOLLECTION wParam:1];
	[_editor message:SCI_EMPTYUNDOBUFFER];
	[_editor message:SCI_SETSAVEPOINT];
	_forcedDirty = NO;
	[_editor message:SCI_SETCHANGEHISTORY wParam:SC_CHANGE_HISTORY_ENABLED | SC_CHANGE_HISTORY_MARKERS];
	[_editor message:SCI_GOTOPOS wParam:0];
	[self applyEOLMode];
	return YES;
}

- (BOOL)loadFromPath:(NSString *)path error:(NSError **)error {
	NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:error];
	if (!data) return NO;
	if (data.length > (NSUInteger)1024 * 1024 * 1024) {
		if (error) *error = QError(T(@"The file is too large to open (more than 1 GB).", @"O arquivo é grande demais para abrir (mais de 1 GB)."));
		return NO;
	}
	self.path = path;
	[self loadBytes:data encoding:QEncodingUTF8 detect:YES];
	NSString *firstLine = @"";
	NSUInteger len = MIN(data.length, (NSUInteger)256);
	NSString *head = [[NSString alloc] initWithBytes:data.bytes length:len encoding:NSUTF8StringEncoding];
	if (head) firstLine = [head componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]].firstObject ?: @"";
	_language = [[QLanguageManager shared] detectForPath:path firstLine:firstLine];
	[self restyle];
	NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
	self.fileModificationDate = attrs.fileModificationDate;
	self.readOnly = ![[NSFileManager defaultManager] isWritableFileAtPath:path];
	self.fileMissing = NO;
	return YES;
}

- (BOOL)reloadWithEncoding:(QEncoding)encoding error:(NSError **)error {
	if (!_path) return NO;
	NSData *data = [NSData dataWithContentsOfFile:_path options:0 error:error];
	if (!data) return NO;
	[self loadBytes:data encoding:encoding detect:NO];
	[self restyle];
	NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:_path error:nil];
	self.fileModificationDate = attrs.fileModificationDate;
	return YES;
}

- (NSData *)encodedData:(NSError **)error {
	std::string utf8 = [self utf8Text];
	QPrefs *p = [QPrefs shared];
	if (p.ensureFinalNewline && !utf8.empty() && utf8.back() != '\n' && utf8.back() != '\r')
		utf8 += _lineEnding == QLineEndingCRLF ? "\r\n" : (_lineEnding == QLineEndingCR ? "\r" : "\n");
	size_t bad = 0;
	std::string bytes = quill::encodeFromUtf8(utf8, static_cast<quill::TextEncoding>(_encoding), &bad);
	if (bad > 0) {
		NSAlert *alert = [[NSAlert alloc] init];
		alert.messageText = T(@"Some characters cannot be saved in this encoding", @"Alguns caracteres não podem ser salvos nesta codificação");
		alert.informativeText = [NSString stringWithFormat:T(@"%lu character(s) will be replaced by '?' when saving as %@. Save as UTF-8 instead?",
								      @"%lu caractere(s) serão substituídos por '?' ao salvar como %@. Salvar como UTF-8?"),
						 (unsigned long)bad, QEncodingName(_encoding)];
		[alert addButtonWithTitle:T(@"Save as UTF-8", @"Salvar como UTF-8")];
		[alert addButtonWithTitle:T(@"Save Anyway", @"Salvar assim mesmo")];
		[alert addButtonWithTitle:T(@"Cancel", @"Cancelar")];
		NSModalResponse r = [alert runModal];
		if (r == NSAlertFirstButtonReturn) {
			_encoding = QEncodingUTF8;
			bytes = utf8;
		} else if (r != NSAlertSecondButtonReturn) {
			if (error) *error = QError(T(@"Save cancelled.", @"Gravação cancelada."));
			return nil;
		}
	}
	return [NSData dataWithBytes:bytes.data() length:bytes.size()];
}

- (BOOL)writeData:(NSData *)data toPath:(NSString *)path error:(NSError **)error {
	NSFileManager *fm = [NSFileManager defaultManager];
	NSDictionary *oldAttrs = [fm attributesOfItemAtPath:path error:nil];
	if (![data writeToFile:path options:NSDataWritingAtomic error:error]) return NO;
	if (oldAttrs[NSFilePosixPermissions])
		[fm setAttributes:@{NSFilePosixPermissions : oldAttrs[NSFilePosixPermissions]} ofItemAtPath:path error:nil];
	return YES;
}

- (BOOL)saveToPath:(NSString *)path error:(NSError **)error {
	NSData *data = [self encodedData:error];
	if (!data) return NO;
	if (![self writeData:data toPath:path error:error]) return NO;
	BOOL pathChanged = ![path isEqualToString:_path];
	self.path = path;
	[self markSaved];
	NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
	self.fileModificationDate = attrs.fileModificationDate;
	self.fileMissing = NO;
	self.readOnly = NO;
	if (pathChanged && _language.isPlainText) {
		_language = [[QLanguageManager shared] detectForPath:path firstLine:@""];
		[self restyle];
	}
	return YES;
}

- (BOOL)writeCopyToPath:(NSString *)path error:(NSError **)error {
	NSData *data = [self encodedData:error];
	if (!data) return NO;
	return [self writeData:data toPath:path error:error];
}

- (void)convertLineEndingsTo:(QLineEnding)eol {
	_lineEnding = eol;
	[self applyEOLMode];
	int mode = eol == QLineEndingCRLF ? SC_EOL_CRLF : (eol == QLineEndingCR ? SC_EOL_CR : SC_EOL_LF);
	[_editor message:SCI_CONVERTEOLS wParam:(uptr_t)mode];
}

- (void)setLanguageAndRestyle:(QLanguage *)language {
	_language = language ?: [QLanguageManager shared].plainText;
	[self restyle];
}

- (void)restyle {
	[QEditorStyler applyPreferencesToEditor:_editor];
	[QEditorStyler applyLanguage:_language toEditor:_editor];
	[_editor message:SCI_SETREADONLY wParam:_readOnly];
}

- (void)setReadOnly:(BOOL)readOnly {
	_readOnly = readOnly;
	[_editor message:SCI_SETREADONLY wParam:readOnly];
}

- (BOOL)changedOnDisk {
	if (!_path) return NO;
	NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:_path error:nil];
	if (!attrs) return NO;
	NSDate *d = attrs.fileModificationDate;
	return _fileModificationDate && d && [d timeIntervalSinceDate:_fileModificationDate] > 0.5;
}

@end
