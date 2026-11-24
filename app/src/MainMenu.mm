// SPDX-License-Identifier: GPL-3.0-or-later
#import "MainMenu.h"
#import "Document.h"
#import "Languages.h"
#import "Localization.h"
#import "HashTools.h"

static NSMenuItem *item(NSMenu *menu, NSString *title, SEL action, NSString *key, NSEventModifierFlags mods) {
	NSMenuItem *i = [menu addItemWithTitle:title action:action keyEquivalent:key ?: @""];
	if (key.length) i.keyEquivalentModifierMask = mods;
	return i;
}

static NSMenuItem *cmd(NSMenu *menu, NSString *title, SEL action, NSString *key) {
	return item(menu, title, action, key, NSEventModifierFlagCommand);
}

static NSMenu *submenu(NSMenu *parent, NSString *title) {
	NSMenuItem *i = [parent addItemWithTitle:title action:nil keyEquivalent:@""];
	NSMenu *m = [[NSMenu alloc] initWithTitle:title];
	i.submenu = m;
	return m;
}

static NSString *fkey(unichar c) {
	return [NSString stringWithCharacters:&c length:1];
}

@implementation QMainMenu

+ (instancetype)shared {
	static QMainMenu *m;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		m = [[QMainMenu alloc] init];
	});
	return m;
}

- (NSMenu *)build {
	const NSEventModifierFlags C = NSEventModifierFlagCommand;
	const NSEventModifierFlags S = NSEventModifierFlagShift;
	const NSEventModifierFlags O = NSEventModifierFlagOption;
	const NSEventModifierFlags K = NSEventModifierFlagControl;
	NSMenu *bar = [[NSMenu alloc] initWithTitle:@"Main"];

	// ---- App menu
	NSMenu *app = submenu(bar, @"Quill");
	cmd(app, T(@"About Quill", @"Sobre o Quill"), @selector(orderFrontStandardAboutPanel:), nil);
	[app addItem:[NSMenuItem separatorItem]];
	cmd(app, T(@"Settings…", @"Ajustes…"), @selector(showPreferences:), @",");
	NSMenu *uiLang = submenu(app, @"Language / Idioma");
	NSMenuItem *en = cmd(uiLang, @"English", @selector(setInterfaceLanguage:), nil);
	en.tag = QUILanguageEnglish;
	NSMenuItem *pt = cmd(uiLang, @"Português (Brasil)", @selector(setInterfaceLanguage:), nil);
	pt.tag = QUILanguagePortuguese;
	[app addItem:[NSMenuItem separatorItem]];
	NSMenu *services = submenu(app, T(@"Services", @"Serviços"));
	NSApp.servicesMenu = services;
	[app addItem:[NSMenuItem separatorItem]];
	cmd(app, T(@"Hide Quill", @"Ocultar Quill"), @selector(hide:), @"h");
	item(app, T(@"Hide Others", @"Ocultar outros"), @selector(hideOtherApplications:), @"h", C | O);
	cmd(app, T(@"Show All", @"Mostrar tudo"), @selector(unhideAllApplications:), nil);
	[app addItem:[NSMenuItem separatorItem]];
	cmd(app, T(@"Quit Quill", @"Encerrar Quill"), @selector(terminate:), @"q");

	// ---- File
	NSMenu *file = submenu(bar, T(@"File", @"Arquivo"));
	cmd(file, T(@"New", @"Novo"), @selector(newDocument:), @"n");
	cmd(file, T(@"Open…", @"Abrir…"), @selector(openDocument:), @"o");
	NSMenuItem *recentItem = [file addItemWithTitle:T(@"Open Recent", @"Abrir recente") action:nil keyEquivalent:@""];
	_recentMenu = [[NSMenu alloc] initWithTitle:@"Recent"];
	recentItem.submenu = _recentMenu;
	item(file, T(@"Reopen Closed Tab", @"Reabrir aba fechada"), @selector(reopenClosedTab:), @"t", C | S);
	cmd(file, T(@"Open Folder in Explorer…", @"Abrir pasta no Explorador…"), @selector(openFolder:), nil);
	[file addItem:[NSMenuItem separatorItem]];
	cmd(file, T(@"Save", @"Salvar"), @selector(saveDocument:), @"s");
	item(file, T(@"Save As…", @"Salvar como…"), @selector(saveDocumentAs:), @"s", C | S);
	cmd(file, T(@"Save a Copy As…", @"Salvar uma cópia como…"), @selector(saveCopyAs:), nil);
	item(file, T(@"Save All", @"Salvar tudo"), @selector(saveAllDocuments:), @"s", C | O);
	cmd(file, T(@"Rename…", @"Renomear…"), @selector(renameDocument:), nil);
	cmd(file, T(@"Reload from Disk", @"Recarregar do disco"), @selector(reloadFromDisk:), nil);
	[file addItem:[NSMenuItem separatorItem]];
	cmd(file, T(@"Close Tab", @"Fechar aba"), @selector(closeTab:), @"w");
	item(file, T(@"Close All Tabs", @"Fechar todas as abas"), @selector(closeAllTabs:), @"w", C | O);
	cmd(file, T(@"Close Other Tabs", @"Fechar outras abas"), @selector(closeOtherTabs:), nil);
	[file addItem:[NSMenuItem separatorItem]];
	item(file, T(@"Reveal in Finder", @"Mostrar no Finder"), @selector(revealInFinder:), @"r", C | S);
	cmd(file, T(@"Open in Terminal", @"Abrir no Terminal"), @selector(openInTerminal:), nil);
	item(file, T(@"Copy Full Path", @"Copiar caminho completo"), @selector(copyFullPath:), @"c", C | O | K);
	cmd(file, T(@"Copy File Name", @"Copiar nome do arquivo"), @selector(copyFileName:), nil);
	[file addItem:[NSMenuItem separatorItem]];
	cmd(file, T(@"Print…", @"Imprimir…"), @selector(printDocument:), @"p");

	// ---- Edit
	NSMenu *edit = submenu(bar, T(@"Edit", @"Editar"));
	cmd(edit, T(@"Undo", @"Desfazer"), @selector(undo:), @"z");
	item(edit, T(@"Redo", @"Refazer"), @selector(redo:), @"z", C | S);
	[edit addItem:[NSMenuItem separatorItem]];
	cmd(edit, T(@"Cut", @"Recortar"), @selector(cut:), @"x");
	cmd(edit, T(@"Copy", @"Copiar"), @selector(copy:), @"c");
	cmd(edit, T(@"Paste", @"Colar"), @selector(paste:), @"v");
	cmd(edit, T(@"Delete", @"Apagar"), @selector(clear:), nil);
	cmd(edit, T(@"Select All", @"Selecionar tudo"), @selector(selectAll:), @"a");
	[edit addItem:[NSMenuItem separatorItem]];
	NSMenu *lines = submenu(edit, T(@"Line Operations", @"Operações de linha"));
	cmd(lines, T(@"Duplicate Line", @"Duplicar linha"), @selector(duplicateLine:), @"d");
	item(lines, T(@"Delete Line", @"Apagar linha"), @selector(deleteLine:), @"k", C | S);
	item(lines, T(@"Move Line Up", @"Mover linha para cima"), @selector(moveLineUp:), fkey(NSUpArrowFunctionKey), C | O);
	item(lines, T(@"Move Line Down", @"Mover linha para baixo"), @selector(moveLineDown:), fkey(NSDownArrowFunctionKey), C | O);
	cmd(lines, T(@"Join Lines", @"Juntar linhas"), @selector(joinLines:), @"j");
	[lines addItem:[NSMenuItem separatorItem]];
	cmd(lines, T(@"Sort Lines Ascending", @"Ordenar linhas (crescente)"), @selector(sortLinesAscending:), nil);
	cmd(lines, T(@"Sort Lines Descending", @"Ordenar linhas (decrescente)"), @selector(sortLinesDescending:), nil);
	cmd(lines, T(@"Sort Lines (Ignore Case)", @"Ordenar linhas (ignorar maiúsculas)"), @selector(sortLinesCaseInsensitive:), nil);
	cmd(lines, T(@"Sort Lines as Numbers", @"Ordenar linhas como números"), @selector(sortLinesNumeric:), nil);
	cmd(lines, T(@"Remove Duplicate Lines", @"Remover linhas duplicadas"), @selector(removeDuplicateLines:), nil);
	cmd(lines, T(@"Remove Empty Lines", @"Remover linhas vazias"), @selector(removeEmptyLines:), nil);
	cmd(lines, T(@"Trim Trailing Whitespace", @"Remover espaços no fim das linhas"), @selector(trimTrailingWhitespace:), nil);
	NSMenu *comment = submenu(edit, T(@"Comment", @"Comentário"));
	cmd(comment, T(@"Toggle Line Comment", @"Alternar comentário de linha"), @selector(toggleComment:), @"/");
	item(comment, T(@"Block Comment", @"Comentário em bloco"), @selector(blockComment:), @"/", C | O);
	NSMenu *convCase = submenu(edit, T(@"Convert Case", @"Converter maiúsculas/minúsculas"));
	item(convCase, T(@"UPPERCASE", @"MAIÚSCULAS"), @selector(makeUppercase:), @"u", C | S);
	item(convCase, T(@"lowercase", @"minúsculas"), @selector(makeLowercase:), @"u", C | O);
	cmd(convCase, T(@"Title Case", @"Iniciais Maiúsculas"), @selector(makeTitleCase:), nil);
	cmd(convCase, T(@"iNVERT cASE", @"iNVERTER mAIÚSCULAS"), @selector(invertCase:), nil);
	NSMenu *indent = submenu(edit, T(@"Indentation", @"Indentação"));
	cmd(indent, T(@"Indent", @"Aumentar indentação"), @selector(indentLines:), @"]");
	cmd(indent, T(@"Unindent", @"Diminuir indentação"), @selector(unindentLines:), @"[");
	cmd(indent, T(@"Convert Tabs to Spaces", @"Converter tabulações em espaços"), @selector(tabsToSpaces:), nil);
	cmd(indent, T(@"Convert Leading Spaces to Tabs", @"Converter espaços iniciais em tabulações"), @selector(spacesToTabs:), nil);
	NSMenu *multi = submenu(edit, T(@"Multiple Cursors", @"Múltiplos cursores"));
	item(multi, T(@"Add Next Occurrence", @"Adicionar próxima ocorrência"), @selector(selectNextOccurrence:), @"d", C | O);
	item(multi, T(@"Select All Occurrences", @"Selecionar todas as ocorrências"), @selector(selectAllOccurrences:), @"l", C | S);
	cmd(multi, T(@"Split Selection into Lines", @"Dividir seleção em linhas"), @selector(splitSelectionIntoLines:), nil);
	[edit addItem:[NSMenuItem separatorItem]];
	item(edit, T(@"Complete Word", @"Completar palavra"), @selector(completeWord:), @"\x1b", O);
	cmd(edit, T(@"Insert Date and Time", @"Inserir data e hora"), @selector(insertDateTime:), nil);
	cmd(edit, T(@"Read-Only", @"Somente leitura"), @selector(toggleReadOnly:), nil);
	[edit addItem:[NSMenuItem separatorItem]];
	item(edit, T(@"Emoji & Symbols", @"Emoji e símbolos"), @selector(orderFrontCharacterPalette:), @" ", C | K);

	// ---- Search
	NSMenu *search = submenu(bar, T(@"Search", @"Pesquisar"));
	cmd(search, T(@"Find…", @"Localizar…"), @selector(showFind:), @"f");
	item(search, T(@"Replace…", @"Substituir…"), @selector(showReplace:), @"f", C | O);
	cmd(search, T(@"Find Next", @"Localizar próximo"), @selector(findNext:), @"g");
	item(search, T(@"Find Previous", @"Localizar anterior"), @selector(findPrevious:), @"g", C | S);
	cmd(search, T(@"Use Selection for Find", @"Usar seleção para localizar"), @selector(useSelectionForFind:), @"e");
	item(search, T(@"Find in Files…", @"Localizar em arquivos…"), @selector(findInFiles:), @"f", C | S);
	[search addItem:[NSMenuItem separatorItem]];
	cmd(search, T(@"Mark All Occurrences", @"Marcar todas as ocorrências"), @selector(markAllOccurrences:), nil);
	cmd(search, T(@"Clear Marks", @"Limpar marcações"), @selector(clearMarks:), nil);
	[search addItem:[NSMenuItem separatorItem]];
	cmd(search, T(@"Go to Line…", @"Ir para a linha…"), @selector(gotoLine:), @"l");
	item(search, T(@"Go to Matching Brace", @"Ir para o parêntese correspondente"), @selector(gotoMatchingBrace:), @"b", C | K);
	NSMenu *bookmarks = submenu(search, T(@"Bookmarks", @"Marcadores"));
	item(bookmarks, T(@"Toggle Bookmark", @"Alternar marcador"), @selector(toggleBookmark:), fkey(NSF2FunctionKey), C);
	item(bookmarks, T(@"Next Bookmark", @"Próximo marcador"), @selector(nextBookmark:), fkey(NSF2FunctionKey), 0);
	item(bookmarks, T(@"Previous Bookmark", @"Marcador anterior"), @selector(previousBookmark:), fkey(NSF2FunctionKey), S);
	cmd(bookmarks, T(@"Clear All Bookmarks", @"Limpar todos os marcadores"), @selector(clearBookmarks:), nil);

	// ---- View
	NSMenu *view = submenu(bar, T(@"View", @"Exibir"));
	item(view, T(@"Show Toolbar", @"Mostrar barra de ferramentas"), @selector(toggleToolbarVisible:), @"t", C | O);
	cmd(view, T(@"Show Status Bar", @"Mostrar barra de status"), @selector(toggleStatusBar:), nil);
	_panelsMenu = submenu(view, T(@"Panels", @"Painéis"));
	[view addItem:[NSMenuItem separatorItem]];
	item(view, T(@"Word Wrap", @"Quebra de linha automática"), @selector(toggleWordWrap:), @"z", C | O);
	cmd(view, T(@"Show Whitespace", @"Mostrar espaços em branco"), @selector(toggleWhitespace:), nil);
	cmd(view, T(@"Show End of Line", @"Mostrar fim de linha"), @selector(toggleEOL:), nil);
	cmd(view, T(@"Show Indent Guides", @"Mostrar guias de indentação"), @selector(toggleIndentGuides:), nil);
	cmd(view, T(@"Show Line Numbers", @"Mostrar números de linha"), @selector(toggleLineNumbers:), nil);
	cmd(view, T(@"Show Fold Margin", @"Mostrar margem de dobra"), @selector(toggleFoldMargin:), nil);
	cmd(view, T(@"Highlight Current Line", @"Destacar linha atual"), @selector(toggleHighlightCurrentLine:), nil);
	[view addItem:[NSMenuItem separatorItem]];
	cmd(view, T(@"Zoom In", @"Ampliar"), @selector(zoomIn:), @"+");
	NSMenuItem *zin2 = cmd(view, T(@"Zoom In", @"Ampliar"), @selector(zoomIn:), @"=");
	zin2.hidden = YES;
	zin2.allowsKeyEquivalentWhenHidden = YES;
	cmd(view, T(@"Zoom Out", @"Reduzir"), @selector(zoomOut:), @"-");
	cmd(view, T(@"Actual Size", @"Tamanho real"), @selector(zoomReset:), @"0");
	[view addItem:[NSMenuItem separatorItem]];
	item(view, T(@"Fold All", @"Recolher tudo"), @selector(foldAll:), @"0", C | O);
	item(view, T(@"Unfold All", @"Expandir tudo"), @selector(unfoldAll:), @"0", C | O | S);
	item(view, T(@"Toggle Current Fold", @"Alternar dobra atual"), @selector(toggleCurrentFold:), @"f", C | K);
	[view addItem:[NSMenuItem separatorItem]];
	NSMenu *theme = submenu(view, T(@"Theme", @"Tema"));
	cmd(theme, T(@"Automatic (System)", @"Automático (sistema)"), @selector(setThemeMode:), nil).tag = 0;
	cmd(theme, T(@"Light", @"Claro"), @selector(setThemeMode:), nil).tag = 1;
	cmd(theme, T(@"Dark", @"Escuro"), @selector(setThemeMode:), nil).tag = 2;
	[view addItem:[NSMenuItem separatorItem]];
	item(view, T(@"Enter Full Screen", @"Entrar em tela cheia"), @selector(toggleFullScreen:), @"f", C | K);

	// ---- Encoding
	NSMenu *encoding = submenu(bar, T(@"Encoding", @"Codificação"));
	_encodingMenu = encoding;
	NSArray *encs = @[ @(QEncodingUTF8), @(QEncodingUTF8BOM), @(QEncodingUTF16LE), @(QEncodingUTF16BE), @(QEncodingWindows1252), @(QEncodingLatin1), @(QEncodingMacRoman) ];
	for (NSNumber *e in encs) {
		NSMenuItem *mi = cmd(encoding, [NSString stringWithFormat:T(@"Convert to %@", @"Converter para %@"), QEncodingName((QEncoding)e.integerValue)], @selector(setDocumentEncoding:), nil);
		mi.tag = e.integerValue;
	}
	[encoding addItem:[NSMenuItem separatorItem]];
	_reopenEncodingMenu = submenu(encoding, T(@"Reopen with Encoding", @"Reabrir com codificação"));
	for (NSNumber *e in encs) {
		NSMenuItem *mi = cmd(_reopenEncodingMenu, QEncodingName((QEncoding)e.integerValue), @selector(reopenWithEncoding:), nil);
		mi.tag = e.integerValue;
	}
	_lineEndingMenu = submenu(encoding, T(@"Line Endings", @"Fim de linha"));
	for (NSNumber *e in @[ @(QLineEndingLF), @(QLineEndingCRLF), @(QLineEndingCR) ]) {
		NSMenuItem *mi = cmd(_lineEndingMenu, QLineEndingName((QLineEnding)e.integerValue), @selector(setDocumentLineEnding:), nil);
		mi.tag = e.integerValue;
	}

	// ---- Language
	_languageMenu = submenu(bar, T(@"Language", @"Linguagem"));
	NSMutableDictionary<NSString *, NSMenu *> *letters = [NSMutableDictionary dictionary];
	QLanguageManager *lm = [QLanguageManager shared];
	NSMenuItem *plain = cmd(_languageMenu, T(@"Normal Text", @"Texto normal"), @selector(setDocumentLanguage:), nil);
	plain.representedObject = lm.plainText.name;
	[_languageMenu addItem:[NSMenuItem separatorItem]];
	for (QLanguage *l in lm.languages) {
		if (l == lm.plainText || [l.name isEqualToString:@"nfo"]) continue;
		NSString *letter = [[l.displayName substringToIndex:1] uppercaseString];
		NSMenu *m = letters[letter];
		if (!m) {
			m = submenu(_languageMenu, letter);
			letters[letter] = m;
		}
		NSMenuItem *mi = cmd(m, l.displayName, @selector(setDocumentLanguage:), nil);
		mi.representedObject = l.name;
	}

	// ---- Tools
	NSMenu *tools = submenu(bar, T(@"Tools", @"Ferramentas"));
	for (NSNumber *alg in @[ @(QHashMD5), @(QHashSHA1), @(QHashSHA256), @(QHashSHA512) ]) {
		NSString *name = [QHashTools nameOfAlgorithm:(QHashAlgorithm)alg.integerValue];
		NSMenu *hashMenu = submenu(tools, name);
		NSMenuItem *t = [hashMenu addItemWithTitle:T(@"Generate from Text (selection or document)", @"Gerar a partir do texto (seleção ou documento)") action:@selector(fromText:) keyEquivalent:@""];
		NSMenuItem *f = [hashMenu addItemWithTitle:T(@"Generate from Files…", @"Gerar a partir de arquivos…") action:@selector(fromFiles:) keyEquivalent:@""];
		NSMenuItem *c = [hashMenu addItemWithTitle:T(@"Generate into Clipboard", @"Gerar para a área de transferência") action:@selector(intoClipboard:) keyEquivalent:@""];
		for (NSMenuItem *mi in @[ t, f, c ]) {
			mi.target = [QHashTools shared];
			mi.tag = alg.integerValue;
		}
	}

	// ---- Plugins
	_pluginsMenu = submenu(bar, T(@"Plugins", @"Plugins"));
	[_pluginsMenu addItem:[NSMenuItem separatorItem]];
	cmd(_pluginsMenu, T(@"Manage Plugins…", @"Gerenciar plugins…"), @selector(managePlugins:), nil);
	cmd(_pluginsMenu, T(@"Open Plugins Folder", @"Abrir pasta de plugins"), @selector(openPluginsFolder:), nil);

	// ---- Window
	NSMenu *window = submenu(bar, T(@"Window", @"Janela"));
	_windowMenu = window;
	cmd(window, T(@"Minimize", @"Minimizar"), @selector(performMiniaturize:), @"m");
	cmd(window, T(@"Zoom", @"Zoom"), @selector(performZoom:), nil);
	[window addItem:[NSMenuItem separatorItem]];
	item(window, T(@"Next Tab", @"Próxima aba"), @selector(selectNextTab:), @"}", C);
	item(window, T(@"Previous Tab", @"Aba anterior"), @selector(selectPreviousTab:), @"{", C);
	NSMenuItem *nextCtrlTab = item(window, T(@"Next Tab", @"Próxima aba"), @selector(selectNextTab:), @"\t", K);
	nextCtrlTab.hidden = YES;
	nextCtrlTab.allowsKeyEquivalentWhenHidden = YES;
	NSMenuItem *prevCtrlTab = item(window, T(@"Previous Tab", @"Aba anterior"), @selector(selectPreviousTab:), @"\t", K | S);
	prevCtrlTab.hidden = YES;
	prevCtrlTab.allowsKeyEquivalentWhenHidden = YES;
	for (int i = 1; i <= 9; i++) {
		NSMenuItem *mi = cmd(window, [NSString stringWithFormat:T(@"Tab %d", @"Aba %d"), i], @selector(selectTabNumber:), [NSString stringWithFormat:@"%d", i]);
		mi.tag = i;
		mi.hidden = YES;
		mi.allowsKeyEquivalentWhenHidden = YES;
	}
	[window addItem:[NSMenuItem separatorItem]];
	cmd(window, T(@"Bring All to Front", @"Trazer tudo para a frente"), @selector(arrangeInFront:), nil);
	NSApp.windowsMenu = window;

	// ---- Help
	NSMenu *help = submenu(bar, T(@"Help", @"Ajuda"));
	cmd(help, T(@"Quill Help", @"Ajuda do Quill"), @selector(showHelp:), @"?");
	cmd(help, T(@"Plugin Development Guide", @"Guia de desenvolvimento de plugins"), @selector(showPluginGuide:), nil);
	NSApp.helpMenu = help;

	return bar;
}

@end
