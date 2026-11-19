// SPDX-License-Identifier: GPL-3.0-or-later
#import "PreferencesWindow.h"
#import "Document.h"
#import "Localization.h"
#import "Preferences.h"

@interface QPreferencesWindowController () <NSWindowDelegate>
@end

@implementation QPreferencesWindowController {
	NSTextField *_fontLabel;
	NSMutableDictionary<NSString *, NSButton *> *_checks;
}

- (instancetype)init {
	NSWindow *w = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 560, 440)
						  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
						    backing:NSBackingStoreBuffered
						      defer:YES];
	w.title = T(@"Settings", @"Ajustes");
	if ((self = [super initWithWindow:w])) {
		_checks = [NSMutableDictionary dictionary];
		w.delegate = self;
		[self build];
		[w center];
	}
	return self;
}

- (NSButton *)check:(NSString *)title key:(NSString *)key {
	NSButton *b = [NSButton checkboxWithTitle:title target:self action:@selector(checkChanged:)];
	b.identifier = key;
	b.state = [[[QPrefs shared] valueForKey:key] boolValue] ? NSControlStateValueOn : NSControlStateValueOff;
	_checks[key] = b;
	return b;
}

- (void)checkChanged:(NSButton *)sender {
	[[QPrefs shared] setValue:@(sender.state == NSControlStateValueOn) forKey:sender.identifier];
}

static NSTextField *label(NSString *s) {
	NSTextField *l = [NSTextField labelWithString:s];
	l.alignment = NSTextAlignmentRight;
	return l;
}

- (NSView *)pageWithRows:(NSArray<NSArray<NSView *> *> *)rows {
	NSView *page = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 520, 360)];
	NSGridView *grid = [NSGridView gridViewWithViews:rows];
	grid.rowSpacing = 10;
	grid.columnSpacing = 10;
	grid.translatesAutoresizingMaskIntoConstraints = NO;
	[grid columnAtIndex:0].xPlacement = NSGridCellPlacementTrailing;
	[page addSubview:grid];
	[NSLayoutConstraint activateConstraints:@[
		[grid.topAnchor constraintEqualToAnchor:page.topAnchor constant:20],
		[grid.centerXAnchor constraintEqualToAnchor:page.centerXAnchor],
	]];
	return page;
}

- (void)build {
	QPrefs *p = [QPrefs shared];
	NSTabView *tabs = [[NSTabView alloc] initWithFrame:NSMakeRect(10, 10, 540, 420)];
	tabs.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
	NSView *empty = [NSGridCell emptyContentView];

	// ---- Editor
	_fontLabel = [NSTextField labelWithString:@""];
	[self updateFontLabel];
	NSButton *fontButton = [NSButton buttonWithTitle:T(@"Change…", @"Alterar…") target:self action:@selector(chooseFont:)];
	NSStackView *fontRow = [NSStackView stackViewWithViews:@[ _fontLabel, fontButton ]];
	NSPopUpButton *tabWidth = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
	for (NSNumber *n in @[ @2, @3, @4, @8 ]) [tabWidth addItemWithTitle:n.stringValue];
	[tabWidth selectItemWithTitle:@(p.tabWidth).stringValue];
	tabWidth.target = self;
	tabWidth.action = @selector(tabWidthChanged:);
	NSTextField *edge = [NSTextField textFieldWithString:p.edgeColumn > 0 ? @(p.edgeColumn).stringValue : @""];
	edge.placeholderString = T(@"off", @"desligado");
	edge.target = self;
	edge.action = @selector(edgeChanged:);
	[edge.widthAnchor constraintEqualToConstant:60].active = YES;
	NSView *editorPage = [self pageWithRows:@[
		@[ label(T(@"Font:", @"Fonte:")), fontRow ],
		@[ label(T(@"Tab width:", @"Largura da tabulação:")), tabWidth ],
		@[ empty, [self check:T(@"Insert spaces instead of tabs", @"Inserir espaços em vez de tabulações") key:@"useSpaces"] ],
		@[ empty, [self check:T(@"Automatic indentation", @"Indentação automática") key:@"autoIndent"] ],
		@[ empty, [self check:T(@"Auto-close brackets and quotes", @"Fechar parênteses e aspas automaticamente") key:@"autoCloseBrackets"] ],
		@[ empty, [self check:T(@"Word completion while typing", @"Completar palavras ao digitar") key:@"autoCompleteWords"] ],
		@[ empty, [self check:T(@"Highlight other occurrences of the selected word", @"Destacar outras ocorrências da palavra selecionada") key:@"highlightMatchingWords"] ],
		@[ label(T(@"Vertical edge at column:", @"Linha vertical na coluna:")), edge ],
	]];
	NSTabViewItem *t1 = [[NSTabViewItem alloc] initWithIdentifier:@"editor"];
	t1.label = T(@"Editor", @"Editor");
	t1.view = editorPage;
	[tabs addTabViewItem:t1];

	// ---- Display
	NSPopUpButton *theme = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
	[theme addItemsWithTitles:@[ T(@"Automatic (System)", @"Automático (sistema)"), T(@"Light", @"Claro"), T(@"Dark", @"Escuro") ]];
	[theme selectItemAtIndex:p.theme];
	theme.target = self;
	theme.action = @selector(themeChanged:);
	NSView *displayPage = [self pageWithRows:@[
		@[ label(T(@"Theme:", @"Tema:")), theme ],
		@[ empty, [self check:T(@"Show line numbers", @"Mostrar números de linha") key:@"showLineNumbers"] ],
		@[ empty, [self check:T(@"Show fold margin", @"Mostrar margem de dobra") key:@"showFoldMargin"] ],
		@[ empty, [self check:T(@"Show indent guides", @"Mostrar guias de indentação") key:@"showIndentGuides"] ],
		@[ empty, [self check:T(@"Highlight current line", @"Destacar linha atual") key:@"highlightCurrentLine"] ],
		@[ empty, [self check:T(@"Show whitespace", @"Mostrar espaços em branco") key:@"showWhitespace"] ],
		@[ empty, [self check:T(@"Show end of line", @"Mostrar fim de linha") key:@"showEOL"] ],
		@[ empty, [self check:T(@"Word wrap", @"Quebra de linha automática") key:@"wordWrap"] ],
		@[ empty, [self check:T(@"Show toolbar", @"Mostrar barra de ferramentas") key:@"showToolbar"] ],
		@[ empty, [self check:T(@"Show status bar", @"Mostrar barra de status") key:@"showStatusBar"] ],
	]];
	NSTabViewItem *t2 = [[NSTabViewItem alloc] initWithIdentifier:@"display"];
	t2.label = T(@"Display", @"Exibição");
	t2.view = displayPage;
	[tabs addTabViewItem:t2];

	// ---- Files
	NSPopUpButton *enc = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
	for (NSInteger e = QEncodingUTF8; e <= QEncodingMacRoman; e++) [enc addItemWithTitle:QEncodingName((QEncoding)e)];
	[enc selectItemAtIndex:p.defaultEncoding];
	enc.target = self;
	enc.action = @selector(encodingChanged:);
	NSPopUpButton *eol = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
	for (NSInteger e = QLineEndingLF; e <= QLineEndingCR; e++) [eol addItemWithTitle:QLineEndingName((QLineEnding)e)];
	[eol selectItemAtIndex:p.defaultLineEnding];
	eol.target = self;
	eol.action = @selector(eolChanged:);
	NSView *filesPage = [self pageWithRows:@[
		@[ label(T(@"New documents encoding:", @"Codificação de novos documentos:")), enc ],
		@[ label(T(@"New documents line ending:", @"Fim de linha de novos documentos:")), eol ],
		@[ empty, [self check:T(@"Reopen files from the last session", @"Reabrir os arquivos da última sessão") key:@"restoreSession"] ],
		@[ empty, [self check:T(@"Remember unsaved changes when quitting (no prompts)", @"Lembrar alterações não salvas ao sair (sem perguntas)") key:@"backupUnsaved"] ],
		@[ empty, [self check:T(@"Trim trailing whitespace on save", @"Remover espaços no fim das linhas ao salvar") key:@"trimOnSave"] ],
		@[ empty, [self check:T(@"Ensure a final newline on save", @"Garantir quebra de linha final ao salvar") key:@"ensureFinalNewline"] ],
	]];
	NSTabViewItem *t3 = [[NSTabViewItem alloc] initWithIdentifier:@"files"];
	t3.label = T(@"Files", @"Arquivos");
	t3.view = filesPage;
	[tabs addTabViewItem:t3];

	// ---- Language
	NSPopUpButton *ui = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
	[ui addItemsWithTitles:@[ @"English", @"Português (Brasil)" ]];
	NSString *stored = [[NSUserDefaults standardUserDefaults] stringForKey:@"UILanguage"];
	[ui selectItemAtIndex:stored ? ([stored isEqualToString:@"pt"] ? 1 : 0) : (QCurrentLanguage() == QUILanguagePortuguese ? 1 : 0)];
	ui.target = self;
	ui.action = @selector(uiLanguageChanged:);
	NSTextField *note = [NSTextField wrappingLabelWithString:T(@"The new language is used after restarting Quill.", @"O novo idioma é usado depois de reiniciar o Quill.")];
	note.textColor = [NSColor secondaryLabelColor];
	[note.widthAnchor constraintEqualToConstant:300].active = YES;
	NSView *langPage = [self pageWithRows:@[
		@[ label(@"Interface / Interface:"), ui ],
		@[ empty, note ],
	]];
	NSTabViewItem *t4 = [[NSTabViewItem alloc] initWithIdentifier:@"language"];
	t4.label = T(@"Language", @"Idioma");
	t4.view = langPage;
	[tabs addTabViewItem:t4];

	[self.window.contentView addSubview:tabs];
}

- (void)updateFontLabel {
	QPrefs *p = [QPrefs shared];
	NSFont *f = p.editorFont;
	_fontLabel.stringValue = [NSString stringWithFormat:@"%@ %.0f pt", f.displayName ?: f.fontName, f.pointSize];
}

- (void)chooseFont:(id)sender {
	NSFontManager *fm = [NSFontManager sharedFontManager];
	fm.target = self;
	fm.action = @selector(changeEditorFont:);
	[fm setSelectedFont:[QPrefs shared].editorFont isMultiple:NO];
	[fm orderFrontFontPanel:self];
}

- (void)changeEditorFont:(NSFontManager *)sender {
	NSFont *f = [sender convertFont:[QPrefs shared].editorFont];
	QPrefs *p = [QPrefs shared];
	p.fontName = f.fontName;
	p.fontSize = f.pointSize;
	[self updateFontLabel];
}

- (NSFontPanelModeMask)validModesForFontPanel:(NSFontPanel *)panel {
	return NSFontPanelModeMaskFace | NSFontPanelModeMaskSize | NSFontPanelModeMaskCollection;
}

- (void)tabWidthChanged:(NSPopUpButton *)s {
	[QPrefs shared].tabWidth = s.titleOfSelectedItem.integerValue;
}

- (void)edgeChanged:(NSTextField *)s {
	[QPrefs shared].edgeColumn = MAX(0, s.integerValue);
}

- (void)themeChanged:(NSPopUpButton *)s {
	[QPrefs shared].theme = (QThemeMode)s.indexOfSelectedItem;
}

- (void)encodingChanged:(NSPopUpButton *)s {
	[QPrefs shared].defaultEncoding = s.indexOfSelectedItem;
}

- (void)eolChanged:(NSPopUpButton *)s {
	[QPrefs shared].defaultLineEnding = s.indexOfSelectedItem;
}

- (void)uiLanguageChanged:(NSPopUpButton *)s {
	NSMenuItem *fake = [[NSMenuItem alloc] init];
	fake.tag = s.indexOfSelectedItem == 1 ? QUILanguagePortuguese : QUILanguageEnglish;
	[NSApp sendAction:NSSelectorFromString(@"setInterfaceLanguage:") to:nil from:fake];
}

- (void)windowDidBecomeKey:(NSNotification *)n {
	QPrefs *p = [QPrefs shared];
	for (NSString *key in _checks) _checks[key].state = [[p valueForKey:key] boolValue] ? NSControlStateValueOn : NSControlStateValueOff;
}

@end
