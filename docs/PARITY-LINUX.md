# Quill para Linux — lista de paridade com o Notepad++

Referência: [`notepad-plus-plus/notepad-plus-plus`](https://github.com/notepad-plus-plus/notepad-plus-plus) no commit `d0bf05c` (clone raso, 24/11/2026).

Objetivo: uma versão Linux própria, com o mesmo nome (Quill) e o mesmo ícone, com **todos os recursos do Notepad++**. A versão Mac não é referência: esta lista não usa `docs/PARITY.md` nem o código do Mac. Do projeto Quill, o único item aproveitado é o ícone.

Como ler:

- `[ ]` a fazer · `[x]` pronto · `[~]` parcial
- `[W]` existe só no Windows. Precisa de decisão, e aparece na seção 21 para discussão
- `[A]` existe no Notepad++, mas no Linux exige um equivalente diferente
- `[?]` não confirmado no repositório. Veio do conhecimento geral sobre o produto e precisa ser checado no Notepad++ antes de implementar

Todos os itens estão `[ ]`. Nada foi tirado do código existente.

Seções 2, 4, 10, 10a, 11, 12, 13 e 15 são geradas a partir do código do Notepad++. As demais foram escritas à mão.

---

## 0. Identidade e distribuição

- [ ] Nome **Quill** e ícone do Quill (copiar o arquivo do ícone atual) em PNG nos tamanhos padrão e em SVG, se houver
- [ ] Arquivo `.desktop` com nome, ícone, categoria `TextEditor` e tipos MIME
- [ ] Associação dos tipos de texto e código (`text/plain`, `text/x-*`, `application/xml`, `application/json`, `text/markdown`) [A]
- [ ] Comando `quill` no `PATH`
- [ ] Release separado, com tag `linux-vX.Y.Z` e workflow próprio
- [ ] Pacote AppImage
- [ ] Pacote `.tar.gz`
- [ ] Pacote `.deb` [?]
- [ ] Dados do usuário em `~/.config/quill` e `~/.local/share/quill` (XDG) [A]
- [ ] Verificação de nova versão nas GitHub Releases (equivale a `IDM_UPDATE`) [A]
- [ ] Desinstalação sem deixar resíduos


## 1. Base técnica e dependências

- [ ] **Scintilla**, backend GTK ou Qt, na versão 569 do Notepad++ (`scintilla/gtk` e `scintilla/qt`) [A]
- [ ] **Lexilla**, na versão 555 do Notepad++ (128 lexers em `lexilla/lexers`)
- [ ] **uchardet**: detecção automática de codificação (`PowerEditor/src/uchardet`)
- [ ] **pugixml**: leitura e escrita dos XML de configuração (`PowerEditor/src/pugixml`)
- [ ] **Expressões regulares**: o Notepad++ usa Boost.Regex (`boostregex/`). Decidir entre Boost.Regex, PCRE2 ou `std::regex`, validando com `PowerEditor/installer/filesForTesting/regexGlobalTest.xml`
- [ ] **Hashes**: MD5, SHA-1, SHA-2, SHA-512, HMAC, CRC16 (`PowerEditor/src/MISC/md5`, `sha1`, `sha2`, `sha512`, `hmac`, `crc16`)
- [ ] **Threads** para busca em arquivos, FTP e Exec, sem travar a interface
- [ ] **Monitoramento de arquivos** com inotify (no Windows, `ReadDirectoryChanges`) [A]
- [ ] **Tema escuro** que segue o sistema (no Windows, `PowerEditor/src/DarkMode` e `NppDarkMode.cpp`) [A]
- [ ] **Escala de tela (DPI)**, tratada pelo toolkit [A]
- [ ] **Arquivos grandes** sem travar a interface (ver seção 7)
- [ ] **Localização** por XML (seção 15)


## 2. Menus (520 comandos)

Fonte: `PowerEditor/src/menuCmdID.h`. Cada item é um comando. O rótulo do menu fica em `PowerEditor/src/Notepad_plus.rc` e nos arquivos `nativeLang/`.

### 2.1 Arquivo (27)

- [ ] `IDM_FILE_CLOSE`
- [ ] `IDM_FILE_CLOSEALL`
- [ ] `IDM_FILE_CLOSEALL_BUT_CURRENT`
- [ ] `IDM_FILE_CLOSEALL_BUT_PINNED`
- [ ] `IDM_FILE_CLOSEALL_TOLEFT`
- [ ] `IDM_FILE_CLOSEALL_TORIGHT`
- [ ] `IDM_FILE_CLOSEALL_UNCHANGED`
- [ ] `IDM_FILE_CONTAININGFOLDERASWORKSPACE`
- [ ] `IDM_FILE_DELETE`
- [ ] `IDM_FILE_EXIT`
- [ ] `IDM_FILE_LOADSESSION`
- [ ] `IDM_FILE_NEW`
- [ ] `IDM_FILE_OPEN`
- [ ] `IDM_FILE_OPENFOLDERASWORKSPACE`
- [ ] `IDM_FILE_OPEN_CMD` [A]
- [ ] `IDM_FILE_OPEN_DEFAULT_VIEWER`
- [ ] `IDM_FILE_OPEN_FOLDER` [A]
- [ ] `IDM_FILE_OPEN_POWERSHELL` [W]
- [ ] `IDM_FILE_PRINT` [A]
- [ ] `IDM_FILE_RELOAD`
- [ ] `IDM_FILE_RENAME`
- [ ] `IDM_FILE_RESTORELASTCLOSEDFILE`
- [ ] `IDM_FILE_SAVE`
- [ ] `IDM_FILE_SAVEALL`
- [ ] `IDM_FILE_SAVEAS`
- [ ] `IDM_FILE_SAVECOPYAS`
- [ ] `IDM_FILE_SAVESESSION`

### 2.2 Editar (99)

- [ ] `IDM_EDIT_BEGINENDSELECT`
- [ ] `IDM_EDIT_BEGINENDSELECT_COLUMNMODE`
- [ ] `IDM_EDIT_BLANKLINEABOVECURRENT`
- [ ] `IDM_EDIT_BLANKLINEBELOWCURRENT`
- [ ] `IDM_EDIT_BLOCK_COMMENT`
- [ ] `IDM_EDIT_BLOCK_COMMENT_SET`
- [ ] `IDM_EDIT_BLOCK_UNCOMMENT`
- [ ] `IDM_EDIT_CHANGESEARCHENGINE`
- [ ] `IDM_EDIT_CHAR_PANEL`
- [ ] `IDM_EDIT_CLEARREADONLYFORALLDOCS`
- [ ] `IDM_EDIT_CLIPBOARDHISTORY_PANEL`
- [ ] `IDM_EDIT_COLUMNMODE`
- [ ] `IDM_EDIT_COLUMNMODETIP`
- [ ] `IDM_EDIT_COPY`
- [ ] `IDM_EDIT_COPY_ALL_NAMES`
- [ ] `IDM_EDIT_COPY_ALL_PATHS`
- [ ] `IDM_EDIT_COPY_BINARY`
- [ ] `IDM_EDIT_COPY_LINK`
- [ ] `IDM_EDIT_CURRENTDIRTOCLIP`
- [ ] `IDM_EDIT_CUT`
- [ ] `IDM_EDIT_CUT_BINARY`
- [ ] `IDM_EDIT_DELETE`
- [ ] `IDM_EDIT_DUP_LINE`
- [ ] `IDM_EDIT_EOL2WS`
- [ ] `IDM_EDIT_FILENAMETOCLIP`
- [ ] `IDM_EDIT_FULLPATHTOCLIP`
- [ ] `IDM_EDIT_INSERT_DATETIME_CUSTOMIZED`
- [ ] `IDM_EDIT_INSERT_DATETIME_LONG`
- [ ] `IDM_EDIT_INSERT_DATETIME_SHORT`
- [ ] `IDM_EDIT_INS_TAB`
- [ ] `IDM_EDIT_INVERTCASE`
- [ ] `IDM_EDIT_JOIN_LINES`
- [ ] `IDM_EDIT_LINE_DOWN`
- [ ] `IDM_EDIT_LINE_UP`
- [ ] `IDM_EDIT_LOWERCASE`
- [ ] `IDM_EDIT_LTR`
- [ ] `IDM_EDIT_MULTISELECTALL`
- [ ] `IDM_EDIT_MULTISELECTALLMATCHCASE`
- [ ] `IDM_EDIT_MULTISELECTALLMATCHCASEWHOLEWORD`
- [ ] `IDM_EDIT_MULTISELECTALLWHOLEWORD`
- [ ] `IDM_EDIT_MULTISELECTNEXT`
- [ ] `IDM_EDIT_MULTISELECTNEXTMATCHCASE`
- [ ] `IDM_EDIT_MULTISELECTNEXTMATCHCASEWHOLEWORD`
- [ ] `IDM_EDIT_MULTISELECTNEXTWHOLEWORD`
- [ ] `IDM_EDIT_MULTISELECTSSKIP`
- [ ] `IDM_EDIT_MULTISELECTUNDO`
- [ ] `IDM_EDIT_OPENSELECTEDFILEFOLDERINEXPLORER` [A]
- [ ] `IDM_EDIT_OPENSELECTEDFILETOEDIT`
- [ ] `IDM_EDIT_PASTE`
- [ ] `IDM_EDIT_PASTE_AS_HTML`
- [ ] `IDM_EDIT_PASTE_AS_RTF`
- [ ] `IDM_EDIT_PASTE_BINARY`
- [ ] `IDM_EDIT_PROPERCASE_BLEND`
- [ ] `IDM_EDIT_PROPERCASE_FORCE`
- [ ] `IDM_EDIT_RANDOMCASE`
- [ ] `IDM_EDIT_REDACT_SELECTION`
- [ ] `IDM_EDIT_REDO`
- [ ] `IDM_EDIT_REMOVEEMPTYLINES`
- [ ] `IDM_EDIT_REMOVEEMPTYLINESWITHBLANK`
- [ ] `IDM_EDIT_REMOVE_ANY_DUP_LINES`
- [ ] `IDM_EDIT_REMOVE_CONSECUTIVE_DUP_LINES`
- [ ] `IDM_EDIT_RMV_TAB`
- [ ] `IDM_EDIT_RTL`
- [ ] `IDM_EDIT_SEARCHONINTERNET`
- [ ] `IDM_EDIT_SELECTALL`
- [ ] `IDM_EDIT_SENTENCECASE_BLEND`
- [ ] `IDM_EDIT_SENTENCECASE_FORCE`
- [ ] `IDM_EDIT_SETREADONLYFORALLDOCS`
- [ ] `IDM_EDIT_SORTLINES_DECIMALCOMMA_ASCENDING`
- [ ] `IDM_EDIT_SORTLINES_DECIMALCOMMA_DESCENDING`
- [ ] `IDM_EDIT_SORTLINES_DECIMALDOT_ASCENDING`
- [ ] `IDM_EDIT_SORTLINES_DECIMALDOT_DESCENDING`
- [ ] `IDM_EDIT_SORTLINES_INTEGER_ASCENDING`
- [ ] `IDM_EDIT_SORTLINES_INTEGER_DESCENDING`
- [ ] `IDM_EDIT_SORTLINES_LENGTH_ASCENDING`
- [ ] `IDM_EDIT_SORTLINES_LENGTH_DESCENDING`
- [ ] `IDM_EDIT_SORTLINES_LEXICOGRAPHIC_ASCENDING`
- [ ] `IDM_EDIT_SORTLINES_LEXICOGRAPHIC_DESCENDING`
- [ ] `IDM_EDIT_SORTLINES_LEXICO_CASE_INSENS_ASCENDING`
- [ ] `IDM_EDIT_SORTLINES_LEXICO_CASE_INSENS_DESCENDING`
- [ ] `IDM_EDIT_SORTLINES_LOCALE_ASCENDING`
- [ ] `IDM_EDIT_SORTLINES_LOCALE_DESCENDING`
- [ ] `IDM_EDIT_SORTLINES_RANDOMLY`
- [ ] `IDM_EDIT_SORTLINES_REVERSE_ORDER`
- [ ] `IDM_EDIT_SPLIT_LINES`
- [ ] `IDM_EDIT_STREAM_COMMENT`
- [ ] `IDM_EDIT_STREAM_UNCOMMENT`
- [ ] `IDM_EDIT_SW2TAB_ALL`
- [ ] `IDM_EDIT_SW2TAB_LEADING`
- [ ] `IDM_EDIT_TAB2SW`
- [ ] `IDM_EDIT_TOGGLEREADONLY`
- [ ] `IDM_EDIT_TOGGLESYSTEMREADONLY`
- [ ] `IDM_EDIT_TRANSPOSE_LINE`
- [ ] `IDM_EDIT_TRIMALL`
- [ ] `IDM_EDIT_TRIMLINEHEAD`
- [ ] `IDM_EDIT_TRIMTRAILING`
- [ ] `IDM_EDIT_TRIM_BOTH`
- [ ] `IDM_EDIT_UNDO`
- [ ] `IDM_EDIT_UPPERCASE`

### 2.3 Pesquisar (65)

- [ ] `IDM_SEARCH_ALLSTYLESTOCLIP`
- [ ] `IDM_SEARCH_CHANGED_NEXT`
- [ ] `IDM_SEARCH_CHANGED_PREV`
- [ ] `IDM_SEARCH_CLEARALLMARKS`
- [ ] `IDM_SEARCH_CLEAR_BOOKMARKS`
- [ ] `IDM_SEARCH_CLEAR_CHANGE_HISTORY`
- [ ] `IDM_SEARCH_COPYMARKEDLINES`
- [ ] `IDM_SEARCH_CUTMARKEDLINES`
- [ ] `IDM_SEARCH_DELETEMARKEDLINES`
- [ ] `IDM_SEARCH_DELETEUNMARKEDLINES`
- [ ] `IDM_SEARCH_FIND`
- [ ] `IDM_SEARCH_FINDCHARINRANGE`
- [ ] `IDM_SEARCH_FINDINCREMENT`
- [ ] `IDM_SEARCH_FINDINFILES`
- [ ] `IDM_SEARCH_FINDNEXT`
- [ ] `IDM_SEARCH_FINDPREV`
- [ ] `IDM_SEARCH_GONEXTMARKER1`
- [ ] `IDM_SEARCH_GONEXTMARKER2`
- [ ] `IDM_SEARCH_GONEXTMARKER3`
- [ ] `IDM_SEARCH_GONEXTMARKER4`
- [ ] `IDM_SEARCH_GONEXTMARKER5`
- [ ] `IDM_SEARCH_GONEXTMARKER_DEF`
- [ ] `IDM_SEARCH_GOPREVMARKER1`
- [ ] `IDM_SEARCH_GOPREVMARKER2`
- [ ] `IDM_SEARCH_GOPREVMARKER3`
- [ ] `IDM_SEARCH_GOPREVMARKER4`
- [ ] `IDM_SEARCH_GOPREVMARKER5`
- [ ] `IDM_SEARCH_GOPREVMARKER_DEF`
- [ ] `IDM_SEARCH_GOTOLINE`
- [ ] `IDM_SEARCH_GOTOMATCHINGBRACE`
- [ ] `IDM_SEARCH_GOTONEXTFOUND`
- [ ] `IDM_SEARCH_GOTOPREVFOUND`
- [ ] `IDM_SEARCH_INVERSEMARKS`
- [ ] `IDM_SEARCH_MARK`
- [ ] `IDM_SEARCH_MARKALLEXT1`
- [ ] `IDM_SEARCH_MARKALLEXT2`
- [ ] `IDM_SEARCH_MARKALLEXT3`
- [ ] `IDM_SEARCH_MARKALLEXT4`
- [ ] `IDM_SEARCH_MARKALLEXT5`
- [ ] `IDM_SEARCH_MARKEDTOCLIP`
- [ ] `IDM_SEARCH_MARKONEEXT1`
- [ ] `IDM_SEARCH_MARKONEEXT2`
- [ ] `IDM_SEARCH_MARKONEEXT3`
- [ ] `IDM_SEARCH_MARKONEEXT4`
- [ ] `IDM_SEARCH_MARKONEEXT5`
- [ ] `IDM_SEARCH_NEXT_BOOKMARK`
- [ ] `IDM_SEARCH_PASTEMARKEDLINES`
- [ ] `IDM_SEARCH_PREV_BOOKMARK`
- [ ] `IDM_SEARCH_REPLACE`
- [ ] `IDM_SEARCH_SELECTMATCHINGBRACES`
- [ ] `IDM_SEARCH_SETANDFINDNEXT`
- [ ] `IDM_SEARCH_SETANDFINDPREV`
- [ ] `IDM_SEARCH_STYLE1TOCLIP`
- [ ] `IDM_SEARCH_STYLE2TOCLIP`
- [ ] `IDM_SEARCH_STYLE3TOCLIP`
- [ ] `IDM_SEARCH_STYLE4TOCLIP`
- [ ] `IDM_SEARCH_STYLE5TOCLIP`
- [ ] `IDM_SEARCH_TOGGLE_BOOKMARK`
- [ ] `IDM_SEARCH_UNMARKALLEXT1`
- [ ] `IDM_SEARCH_UNMARKALLEXT2`
- [ ] `IDM_SEARCH_UNMARKALLEXT3`
- [ ] `IDM_SEARCH_UNMARKALLEXT4`
- [ ] `IDM_SEARCH_UNMARKALLEXT5`
- [ ] `IDM_SEARCH_VOLATILE_FINDNEXT`
- [ ] `IDM_SEARCH_VOLATILE_FINDPREV`

### 2.4 Exibir (107)

- [ ] `IDM_VIEW_ALL_CHARACTERS`
- [ ] `IDM_VIEW_ALWAYSONTOP`
- [ ] `IDM_VIEW_CURLINE_HILITING`
- [ ] `IDM_VIEW_DISTRACTIONFREE`
- [ ] `IDM_VIEW_DOCCHANGEMARGIN`
- [ ] `IDM_VIEW_DOCLIST`
- [ ] `IDM_VIEW_DOC_MAP`
- [ ] `IDM_VIEW_DRAWTABBAR_CLOSEBOTTUN`
- [ ] `IDM_VIEW_DRAWTABBAR_DBCLK2CLOSE`
- [ ] `IDM_VIEW_DRAWTABBAR_INACTIVETAB`
- [ ] `IDM_VIEW_DRAWTABBAR_MULTILINE`
- [ ] `IDM_VIEW_DRAWTABBAR_TOPBAR`
- [ ] `IDM_VIEW_DRAWTABBAR_VERTICAL`
- [ ] `IDM_VIEW_EDGENONE`
- [ ] `IDM_VIEW_EOL`
- [ ] `IDM_VIEW_FILEBROWSER`
- [ ] `IDM_VIEW_FOLD`
- [ ] `IDM_VIEW_FOLDALL`
- [ ] `IDM_VIEW_FOLDERMARGIN`
- [ ] `IDM_VIEW_FOLDERMARGIN_ARROW`
- [ ] `IDM_VIEW_FOLDERMARGIN_BOX`
- [ ] `IDM_VIEW_FOLDERMARGIN_CIRCLE`
- [ ] `IDM_VIEW_FOLDERMARGIN_SIMPLE`
- [ ] `IDM_VIEW_FOLD_1`
- [ ] `IDM_VIEW_FOLD_2`
- [ ] `IDM_VIEW_FOLD_3`
- [ ] `IDM_VIEW_FOLD_4`
- [ ] `IDM_VIEW_FOLD_5`
- [ ] `IDM_VIEW_FOLD_6`
- [ ] `IDM_VIEW_FOLD_7`
- [ ] `IDM_VIEW_FOLD_8`
- [ ] `IDM_VIEW_FOLD_CURRENT`
- [ ] `IDM_VIEW_FULLSCREENTOGGLE`
- [ ] `IDM_VIEW_FUNC_LIST`
- [ ] `IDM_VIEW_HIDELINES`
- [ ] `IDM_VIEW_INDENT_GUIDE`
- [ ] `IDM_VIEW_IN_CHROME`
- [ ] `IDM_VIEW_IN_EDGE`
- [ ] `IDM_VIEW_IN_FIREFOX`
- [ ] `IDM_VIEW_IN_IE`
- [ ] `IDM_VIEW_LINENUMBER`
- [ ] `IDM_VIEW_LOCKTABBAR`
- [ ] `IDM_VIEW_LWALIGN`
- [ ] `IDM_VIEW_LWDEF`
- [ ] `IDM_VIEW_MONITORING`
- [ ] `IDM_VIEW_NPC`
- [ ] `IDM_VIEW_NPC_CCUNIEOL`
- [ ] `IDM_VIEW_POSTIT`
- [ ] `IDM_VIEW_PROJECT_PANEL_1`
- [ ] `IDM_VIEW_PROJECT_PANEL_2`
- [ ] `IDM_VIEW_PROJECT_PANEL_3`
- [ ] `IDM_VIEW_REDUCETABBAR`
- [ ] `IDM_VIEW_REFRESHTABAR`
- [ ] `IDM_VIEW_SUMMARY`
- [ ] `IDM_VIEW_SWITCHTO_DOCLIST`
- [ ] `IDM_VIEW_SWITCHTO_FILEBROWSER`
- [ ] `IDM_VIEW_SWITCHTO_FUNC_LIST`
- [ ] `IDM_VIEW_SWITCHTO_OTHER_VIEW`
- [ ] `IDM_VIEW_SWITCHTO_PROJECT_PANEL_1`
- [ ] `IDM_VIEW_SWITCHTO_PROJECT_PANEL_2`
- [ ] `IDM_VIEW_SWITCHTO_PROJECT_PANEL_3`
- [ ] `IDM_VIEW_SYMBOLMARGIN`
- [ ] `IDM_VIEW_SYNSCROLLH`
- [ ] `IDM_VIEW_SYNSCROLLV`
- [ ] `IDM_VIEW_TAB1`
- [ ] `IDM_VIEW_TAB2`
- [ ] `IDM_VIEW_TAB3`
- [ ] `IDM_VIEW_TAB4`
- [ ] `IDM_VIEW_TAB5`
- [ ] `IDM_VIEW_TAB6`
- [ ] `IDM_VIEW_TAB7`
- [ ] `IDM_VIEW_TAB8`
- [ ] `IDM_VIEW_TAB9`
- [ ] `IDM_VIEW_TAB_COLOUR_1`
- [ ] `IDM_VIEW_TAB_COLOUR_2`
- [ ] `IDM_VIEW_TAB_COLOUR_3`
- [ ] `IDM_VIEW_TAB_COLOUR_4`
- [ ] `IDM_VIEW_TAB_COLOUR_5`
- [ ] `IDM_VIEW_TAB_COLOUR_NONE`
- [ ] `IDM_VIEW_TAB_MOVEBACKWARD`
- [ ] `IDM_VIEW_TAB_MOVEFORWARD`
- [ ] `IDM_VIEW_TAB_NEXT`
- [ ] `IDM_VIEW_TAB_PREV`
- [ ] `IDM_VIEW_TAB_SPACE`
- [ ] `IDM_VIEW_TAB_START`
- [ ] `IDM_VIEW_TOOLBAR_ENLARGE`
- [ ] `IDM_VIEW_TOOLBAR_ENLARGE_SET2`
- [ ] `IDM_VIEW_TOOLBAR_HIDE`
- [ ] `IDM_VIEW_TOOLBAR_REDUCE`
- [ ] `IDM_VIEW_TOOLBAR_STANDARD`
- [ ] `IDM_VIEW_UNFOLD`
- [ ] `IDM_VIEW_UNFOLDALL`
- [ ] `IDM_VIEW_UNFOLD_1`
- [ ] `IDM_VIEW_UNFOLD_2`
- [ ] `IDM_VIEW_UNFOLD_3`
- [ ] `IDM_VIEW_UNFOLD_4`
- [ ] `IDM_VIEW_UNFOLD_5`
- [ ] `IDM_VIEW_UNFOLD_6`
- [ ] `IDM_VIEW_UNFOLD_7`
- [ ] `IDM_VIEW_UNFOLD_8`
- [ ] `IDM_VIEW_UNFOLD_CURRENT`
- [ ] `IDM_VIEW_WRAP`
- [ ] `IDM_VIEW_WRAP_SYMBOL`
- [ ] `IDM_VIEW_ZOOMIN`
- [ ] `IDM_VIEW_ZOOMOUT`
- [ ] `IDM_VIEW_ZOOMRESTORE`
- [ ] `IDM_VIEW_ZOOM_SYNC`

### 2.5 Formatar (codificação e fim de linha) (63)

- [ ] `IDM_FORMAT_ANSI` [W]
- [ ] `IDM_FORMAT_AS_UTF_8`
- [ ] `IDM_FORMAT_BIG5`
- [ ] `IDM_FORMAT_CONV2_ANSI` [W]
- [ ] `IDM_FORMAT_CONV2_AS_UTF_8`
- [ ] `IDM_FORMAT_CONV2_UTF_16BE`
- [ ] `IDM_FORMAT_CONV2_UTF_16LE`
- [ ] `IDM_FORMAT_CONV2_UTF_8`
- [ ] `IDM_FORMAT_DOS_437`
- [ ] `IDM_FORMAT_DOS_720`
- [ ] `IDM_FORMAT_DOS_737`
- [ ] `IDM_FORMAT_DOS_775`
- [ ] `IDM_FORMAT_DOS_850`
- [ ] `IDM_FORMAT_DOS_852`
- [ ] `IDM_FORMAT_DOS_855`
- [ ] `IDM_FORMAT_DOS_857`
- [ ] `IDM_FORMAT_DOS_858`
- [ ] `IDM_FORMAT_DOS_860`
- [ ] `IDM_FORMAT_DOS_861`
- [ ] `IDM_FORMAT_DOS_862`
- [ ] `IDM_FORMAT_DOS_863`
- [ ] `IDM_FORMAT_DOS_865`
- [ ] `IDM_FORMAT_DOS_866`
- [ ] `IDM_FORMAT_DOS_869`
- [ ] `IDM_FORMAT_ENCODE`
- [ ] `IDM_FORMAT_EUC_KR`
- [ ] `IDM_FORMAT_GB2312`
- [ ] `IDM_FORMAT_ISO_8859_1`
- [ ] `IDM_FORMAT_ISO_8859_10`
- [ ] `IDM_FORMAT_ISO_8859_11`
- [ ] `IDM_FORMAT_ISO_8859_13`
- [ ] `IDM_FORMAT_ISO_8859_14`
- [ ] `IDM_FORMAT_ISO_8859_15`
- [ ] `IDM_FORMAT_ISO_8859_16`
- [ ] `IDM_FORMAT_ISO_8859_2`
- [ ] `IDM_FORMAT_ISO_8859_3`
- [ ] `IDM_FORMAT_ISO_8859_4`
- [ ] `IDM_FORMAT_ISO_8859_5`
- [ ] `IDM_FORMAT_ISO_8859_6`
- [ ] `IDM_FORMAT_ISO_8859_7`
- [ ] `IDM_FORMAT_ISO_8859_8`
- [ ] `IDM_FORMAT_ISO_8859_9`
- [ ] `IDM_FORMAT_KOI8R_CYRILLIC`
- [ ] `IDM_FORMAT_KOI8U_CYRILLIC`
- [ ] `IDM_FORMAT_KOREAN_WIN`
- [ ] `IDM_FORMAT_MAC_CYRILLIC`
- [ ] `IDM_FORMAT_SHIFT_JIS`
- [ ] `IDM_FORMAT_TIS_620`
- [ ] `IDM_FORMAT_TODOS`
- [ ] `IDM_FORMAT_TOMAC`
- [ ] `IDM_FORMAT_TOUNIX`
- [ ] `IDM_FORMAT_UTF_16BE`
- [ ] `IDM_FORMAT_UTF_16LE`
- [ ] `IDM_FORMAT_UTF_8`
- [ ] `IDM_FORMAT_WIN_1250`
- [ ] `IDM_FORMAT_WIN_1251`
- [ ] `IDM_FORMAT_WIN_1252`
- [ ] `IDM_FORMAT_WIN_1253`
- [ ] `IDM_FORMAT_WIN_1254`
- [ ] `IDM_FORMAT_WIN_1255`
- [ ] `IDM_FORMAT_WIN_1256`
- [ ] `IDM_FORMAT_WIN_1257`
- [ ] `IDM_FORMAT_WIN_1258`

### 2.6 Linguagem (101)

- [ ] `IDM_LANG_ADA`
- [ ] `IDM_LANG_ASCII`
- [ ] `IDM_LANG_ASM`
- [ ] `IDM_LANG_ASN1`
- [ ] `IDM_LANG_ASP`
- [ ] `IDM_LANG_AU3`
- [ ] `IDM_LANG_AVS`
- [ ] `IDM_LANG_BAANC`
- [ ] `IDM_LANG_BASH`
- [ ] `IDM_LANG_BATCH`
- [ ] `IDM_LANG_BLITZBASIC`
- [ ] `IDM_LANG_C`
- [ ] `IDM_LANG_CAML`
- [ ] `IDM_LANG_CMAKE`
- [ ] `IDM_LANG_COBOL`
- [ ] `IDM_LANG_COFFEESCRIPT`
- [ ] `IDM_LANG_CPP`
- [ ] `IDM_LANG_CS`
- [ ] `IDM_LANG_CSOUND`
- [ ] `IDM_LANG_CSS`
- [ ] `IDM_LANG_D`
- [ ] `IDM_LANG_DIFF`
- [ ] `IDM_LANG_ERLANG`
- [ ] `IDM_LANG_ERRORLIST`
- [ ] `IDM_LANG_ESCRIPT`
- [ ] `IDM_LANG_ESCSEQ`
- [ ] `IDM_LANG_EXTERNAL`
- [ ] `IDM_LANG_EXTERNAL_LIMIT`
- [ ] `IDM_LANG_FLASH`
- [ ] `IDM_LANG_FORTH`
- [ ] `IDM_LANG_FORTRAN`
- [ ] `IDM_LANG_FORTRAN_77`
- [ ] `IDM_LANG_FREEBASIC`
- [ ] `IDM_LANG_GDSCRIPT`
- [ ] `IDM_LANG_GOLANG`
- [ ] `IDM_LANG_GUI4CLI`
- [ ] `IDM_LANG_HASKELL`
- [ ] `IDM_LANG_HOLLYWOOD`
- [ ] `IDM_LANG_HTML`
- [ ] `IDM_LANG_IHEX`
- [ ] `IDM_LANG_INI`
- [ ] `IDM_LANG_INNO`
- [ ] `IDM_LANG_JAVA`
- [ ] `IDM_LANG_JS`
- [ ] `IDM_LANG_JSON`
- [ ] `IDM_LANG_JSON5`
- [ ] `IDM_LANG_JSP`
- [ ] `IDM_LANG_KIX`
- [ ] `IDM_LANG_LATEX`
- [ ] `IDM_LANG_LISP`
- [ ] `IDM_LANG_LUA`
- [ ] `IDM_LANG_MAKEFILE`
- [ ] `IDM_LANG_MATLAB`
- [ ] `IDM_LANG_MMIXAL`
- [ ] `IDM_LANG_MSSQL`
- [ ] `IDM_LANG_NIM`
- [ ] `IDM_LANG_NNCRONTAB`
- [ ] `IDM_LANG_NSIS`
- [ ] `IDM_LANG_OBJC`
- [ ] `IDM_LANG_OPENUDLDIR`
- [ ] `IDM_LANG_OSCRIPT`
- [ ] `IDM_LANG_PASCAL`
- [ ] `IDM_LANG_PERL`
- [ ] `IDM_LANG_PHP`
- [ ] `IDM_LANG_POWERSHELL` [A]
- [ ] `IDM_LANG_PROPS`
- [ ] `IDM_LANG_PS`
- [ ] `IDM_LANG_PUREBASIC`
- [ ] `IDM_LANG_PYTHON`
- [ ] `IDM_LANG_R`
- [ ] `IDM_LANG_RAKU`
- [ ] `IDM_LANG_RC`
- [ ] `IDM_LANG_REBOL`
- [ ] `IDM_LANG_REGISTRY`
- [ ] `IDM_LANG_RUBY`
- [ ] `IDM_LANG_RUST`
- [ ] `IDM_LANG_SAS`
- [ ] `IDM_LANG_SCHEME`
- [ ] `IDM_LANG_SMALLTALK`
- [ ] `IDM_LANG_SPICE`
- [ ] `IDM_LANG_SQL`
- [ ] `IDM_LANG_SREC`
- [ ] `IDM_LANG_STTXT`
- [ ] `IDM_LANG_SWIFT`
- [ ] `IDM_LANG_TCL`
- [ ] `IDM_LANG_TEHEX`
- [ ] `IDM_LANG_TEX`
- [ ] `IDM_LANG_TEXT`
- [ ] `IDM_LANG_TOML`
- [ ] `IDM_LANG_TXT2TAGS`
- [ ] `IDM_LANG_TYPESCRIPT`
- [ ] `IDM_LANG_UDLCOLLECTION_PROJECT_SITE`
- [ ] `IDM_LANG_USER`
- [ ] `IDM_LANG_USER_DLG`
- [ ] `IDM_LANG_USER_LIMIT`
- [ ] `IDM_LANG_VB`
- [ ] `IDM_LANG_VERILOG`
- [ ] `IDM_LANG_VHDL`
- [ ] `IDM_LANG_VISUALPROLOG`
- [ ] `IDM_LANG_XML`
- [ ] `IDM_LANG_YAML`

### 2.7 Configurações (11)

- [ ] `IDM_SETTING_EDITCONTEXTMENU`
- [ ] `IDM_SETTING_IMPORTPLUGIN` [A]
- [ ] `IDM_SETTING_IMPORTSTYLETHEMES`
- [ ] `IDM_SETTING_OPENPLUGINSDIR` [A]
- [ ] `IDM_SETTING_PLUGINADM` [A]
- [ ] `IDM_SETTING_PREFERENCE`
- [ ] `IDM_SETTING_REMEMBER_LAST_SESSION`
- [ ] `IDM_SETTING_SHORTCUT_MAPPER`
- [ ] `IDM_SETTING_SHORTCUT_MAPPER_MACRO`
- [ ] `IDM_SETTING_SHORTCUT_MAPPER_RUN`
- [ ] `IDM_SETTING_TRAYICON` [A]

### 2.8 Ferramentas (12)

- [ ] `IDM_TOOL_MD5_GENERATE`
- [ ] `IDM_TOOL_MD5_GENERATEFROMFILE`
- [ ] `IDM_TOOL_MD5_GENERATEINTOCLIPBOARD`
- [ ] `IDM_TOOL_SHA1_GENERATE`
- [ ] `IDM_TOOL_SHA1_GENERATEFROMFILE`
- [ ] `IDM_TOOL_SHA1_GENERATEINTOCLIPBOARD`
- [ ] `IDM_TOOL_SHA256_GENERATE`
- [ ] `IDM_TOOL_SHA256_GENERATEFROMFILE`
- [ ] `IDM_TOOL_SHA256_GENERATEINTOCLIPBOARD`
- [ ] `IDM_TOOL_SHA512_GENERATE`
- [ ] `IDM_TOOL_SHA512_GENERATEFROMFILE`
- [ ] `IDM_TOOL_SHA512_GENERATEINTOCLIPBOARD`

### 2.9 Macro (5)

- [ ] `IDM_MACRO_PLAYBACKRECORDEDMACRO`
- [ ] `IDM_MACRO_RUNMULTIMACRODLG`
- [ ] `IDM_MACRO_SAVECURRENTMACRO`
- [ ] `IDM_MACRO_STARTRECORDINGMACRO`
- [ ] `IDM_MACRO_STOPRECORDINGMACRO`

### 2.10 Executar (1)

- [ ] `IDM_EXECUTE_VALIDATE_SHORTCUTSXML`

### 2.11 Janela (2)

- [ ] `IDM_WINDOW_COPY_NAME`
- [ ] `IDM_WINDOW_COPY_PATH`

### 2.12 Lista de documentos (4)

- [ ] `IDM_DOCLIST_COPYNAMES`
- [ ] `IDM_DOCLIST_COPYPATHS`
- [ ] `IDM_DOCLIST_FILESCLOSE`
- [ ] `IDM_DOCLIST_FILESCLOSEOTHERS`

### 2.13 Menu da bandeja (5)

- [ ] `IDM_SYSTRAYPOPUP_ACTIVATE` [A]
- [ ] `IDM_SYSTRAYPOPUP_CLOSE` [A]
- [ ] `IDM_SYSTRAYPOPUP_NEWDOC` [A]
- [ ] `IDM_SYSTRAYPOPUP_NEW_AND_PASTE` [A]
- [ ] `IDM_SYSTRAYPOPUP_OPENFILE` [A]

### 2.14 Ajuda, links e atualização (12)

- [ ] `IDM_CMDLINEARGUMENTS`
- [ ] `IDM_CONFUPDATERPROXY` [A]
- [ ] `IDM_DEBUGINFO`
- [ ] `IDM_FORUM`
- [ ] `IDM_HELP`
- [ ] `IDM_HOMESWEETHOME`
- [ ] `IDM_ONLINEDOCUMENT`
- [ ] `IDM_ONLINESUPPORT`
- [ ] `IDM_PLUGINSHOME`
- [ ] `IDM_PROJECTPAGE`
- [ ] `IDM_UPDATE_NPP` [W]
- [ ] `IDM_WIKIFAQ`

### 2.15 Outros (6)

- [ ] `IDM_CLEAN_RECENT_FILE_LIST`
- [ ] `IDM_EXPORT_FUNC_LIST_AND_QUIT`
- [ ] `IDM_FOCUS_ON_FOUND_RESULTS`
- [ ] `IDM_LANGSTYLE_CONFIG_DLG`
- [ ] `IDM_OPEN_ALL_RECENT_FILE`
- [ ] `IDM_PINTAB`


## 3. Janela principal

- [ ] Título com nome do arquivo, asterisco de alterado e indicação de somente leitura
- [ ] Barra de menus
- [ ] Barra de ferramentas com botões configuráveis (`toolbarButtonsConf.xml`)
- [ ] Barra de abas: arrastar para reordenar, botão fechar, ícones, duplo clique e opções de layout (`IDD_PREFERENCE_SUB_TABBAR`)
- [ ] Barra de status: posição do cursor, tamanho, linhas, fim de linha, codificação, linguagem, modo INS/SOBR
- [ ] Vistas divididas (duas vistas, horizontal e vertical), com `IDM_VIEW_*`
- [ ] Painéis acoplados à esquerda, à direita e embaixo, com abas, fixar e ocultar (`DockingWnd`)
- [ ] Margens do editor: números de linha, dobras, marcadores e símbolos
- [ ] Menu de contexto do editor (`contextMenu.xml`)
- [ ] Menu de contexto das abas (`tabContextMenu_example.xml`)
- [ ] Tela cheia
- [ ] Modo sem distrações (`IDM_VIEW_DISTRACTIONFREE` e equivalentes)
- [ ] Modo Post-it [?]
- [ ] Sempre no topo (`-alwaysOnTop`)
- [ ] Ícone na bandeja do sistema (`-systemtray`, `WinControls/TrayIcon`) [A]
- [ ] Ocultar a barra de abas (`-notabbar`)
- [ ] Modo multi-instância (`-multiInst`)


## 4. Diálogos e painéis (39 IDs em `resource.h`)

- [ ] Sobre — `IDD_ABOUTBOX`
- [ ] Caracteres ANSI (painel) — `IDD_ANSIASCII_PANEL`
- [ ] Caixa de botões — `IDD_BUTTON_DLG`
- [ ] Histórico da área de transferência — `IDD_CLIPBOARDHISTORY_PANEL`
- [ ] Seletor de cor — `IDD_COLOUR_POPUP`
- [ ] Editor de colunas — `IDD_COLUMNEDIT`
- [ ] Argumentos de linha de comando — `IDD_COMMANDLINEARGSBOX`
- [ ] Criar pasta — `IDD_CREATE_DIRECTORY`
- [ ] Informações de depuração — `IDD_DEBUGINFOBOX`
- [ ] Gerenciador de painéis acoplados — `IDD_DOCKING_MNG`
- [ ] Lista de documentos — `IDD_DOCLIST`
- [ ] Instantâneo do documento — `IDD_DOCUMENSNAPSHOT`
- [ ] Mapa do documento — `IDD_DOCUMENTMAP`
- [ ] Salvar todos — `IDD_DOSAVEALLBOX`
- [ ] Salvar ou não — `IDD_DOSAVEORNOTBOX`
- [ ] Navegador de arquivos — `IDD_FILEBROWSER`
- [ ] Localizar arquivo movido — `IDD_FILERELOCALIZER_DIALOG`
- [ ] Visualizar arquivo — `IDD_FILEVIEW_DIALOG`
- [ ] Localizar caracteres em intervalo — `IDD_FINDCHARACTERS`
- [ ] Localizar e substituir — `IDD_FIND_REPLACE_DLG`
- [ ] Lista de funções — `IDD_FUNCLIST_PANEL`
- [ ] Estilos globais — `IDD_GLOBAL_STYLER_DLG`
- [ ] Ir para linha — `IDD_GOLINE`
- [ ] Inserir texto — `IDD_INSERT_INPUT_TEXT`
- [ ] MD5 de arquivos — `IDD_MD5FROMFILES_DLG`
- [ ] MD5 de texto — `IDD_MD5FROMTEXT_DLG`
- [ ] Aviso de caminho de rede — `IDD_NETWORKPATHWARNINGBOX`
- [ ] Gerenciador de plugins — `IDD_PLUGINSADMIN_DLG`
- [ ] Preferências — `IDD_PREFERENCE_BOX`
- [ ] Painel de projetos — `IDD_PROJECTPANEL`
- [ ] Extensão do menu de contexto do sistema (ver seção 17) — `IDD_REGEXT`
- [ ] Executar — `IDD_RUN_DLG`
- [ ] Configurações — `IDD_SETTING_DLG`
- [ ] Mapeador de atalhos — `IDD_SHORTCUTMAPPER_DLG`
- [ ] Edição de atalho — `IDD_SHORTCUT_DLG`
- [ ] Configurador de estilo — `IDD_STYLER_DLG`
- [ ] Lista de tarefas — `IDD_TASKLIST_DLG`
- [ ] Linguagem definida pelo usuário — `IDD_USER_DEFINE_BOX`
- [ ] Caixa de valor — `IDD_VALUE_DLG`


## 5. Preferências (23 páginas, `preferenceDlg.cpp`)

Cada página tem a tela própria e as opções gravadas em `config.xml`.

- [ ] **Geral**: `IDD_PREFERENCE_SUB_GENERAL`
- [ ] **Edição**: `IDD_PREFERENCE_SUB_EDITING` e `IDD_PREFERENCE_SUB_EDITING2`
- [ ] **Realce**: `IDD_PREFERENCE_SUB_HIGHLIGHTING`
- [ ] **Indentação**: `IDD_PREFERENCE_SUB_INDENTATION`
- [ ] **Linguagem**: `IDD_PREFERENCE_SUB_LANGUAGE`, associação de extensões e padrão por linguagem
- [ ] **Diversos**: `IDD_PREFERENCE_SUB_MISC`
- [ ] **Multi-instância**: `IDD_PREFERENCE_SUB_MULTIINSTANCE`
- [ ] **Novo documento**: `IDD_PREFERENCE_SUB_NEWDOCUMENT` (codificação, fim de linha, linguagem)
- [ ] **Desempenho**: `IDD_PREFERENCE_SUB_PERFORMANCE`
- [ ] **Impressão**: `IDD_PREFERENCE_SUB_PRINT`
- [ ] **Histórico de arquivos recentes**: `IDD_PREFERENCE_SUB_RECENTFILESHISTORY`
- [ ] **Mecanismo de busca na web**: `IDD_PREFERENCE_SUB_SEARCHENGINE`
- [ ] **Pesquisa**: `IDD_PREFERENCE_SUB_SEARCHING`
- [ ] **Barra de abas**: `IDD_PREFERENCE_SUB_TABBAR`
- [ ] **Barra de ferramentas**: `IDD_PREFERENCE_SUB_TOOLBAR`
- [ ] **Autocompletar**: `IDD_PREFERENCE_SUB_AUTOCOMPLETION`. Ativar; por palavra, por função ou ambos; aceitar com Tab ou Enter; número mínimo de caracteres; ignorar números; fechar automaticamente colchetes, chaves, parênteses, aspas e tags
- [ ] **Backup**: `IDD_PREFERENCE_SUB_BACKUP` (ver seção 7)
- [ ] **Vinculação na nuvem**: `IDD_PREFERENCE_SUB_CLOUD_LINK` (pasta sincronizada para as configurações) [A]
- [ ] **Modo escuro**: `IDD_PREFERENCE_SUB_DARKMODE`
- [ ] **Diretório padrão**: `IDD_PREFERENCE_SUB_DEFAULTDIRECTORY` (abrir e salvar)
- [ ] **Delimitadores**: `IDD_PREFERENCE_SUB_DELIMITER` (seleção por palavra)
- [ ] **Margem, borda e régua**: `IDD_PREFERENCE_SUB_MARGING_BORDER_EDGE`


## 6. Painéis e navegação

- [ ] **Lista de funções**, com parser por linguagem (`PowerEditor/installer/functionList`, 48 arquivos) e ordenação
- [ ] **Mapa do documento** (`WinControls/DocumentMap`)
- [ ] **Lista de documentos** (`IDD_DOCLIST`)
- [ ] **Painel de projetos**, com três projetos (`IDD_PROJECTPANEL`, `PROJECT_PANEL_1..3`)
- [ ] **Navegador de arquivos** da pasta, como espaço de trabalho (`WinControls/FileBrowser`) [A]
- [ ] **Histórico da área de transferência** (`WinControls/ClipboardHistory`)
- [ ] **Painel de caracteres ANSI** (`WinControls/AnsiCharPanel`)
- [ ] **Localizar caracteres em intervalo** (`WinControls/FindCharsInRange`)
- [ ] **Lista de tarefas**, com marcadores como TODO e FIXME (`WinControls/TaskList`)
- [ ] **Resultados de Localizar em arquivos**, em painel com navegação
- [ ] **Monitorar arquivo** (equivale a `tail -f`, `-monitor`)


## 7. Arquivo, sessão e backup

- [ ] Restaurar a sessão ao iniciar (`session.xml`); desligar com `-nosession`
- [ ] Backup de arquivos modificados em pasta própria, com intervalo configurável (`IDD_BACKUPDIR_*`)
- [ ] Restaurar a sessão a partir da pasta de backup (`IDD_BACKUPDIR_RESTORESESSION_PATH_EDIT`)
- [ ] Lista de arquivos recentes, com tamanho configurável
- [ ] Reabrir aba fechada
- [ ] Recarregar o arquivo quando ele muda no disco, com aviso
- [ ] Somente leitura: `-ro`, `-fullReadOnly`, `-fullReadOnlySavingForbidden`
- [ ] Abrir pastas como espaço de trabalho (`-openFoldersAsWorkspace`)
- [ ] Mover pasta (`-moveFolder`)
- [ ] Aviso ao abrir caminho de rede (`IDD_NETWORKPATHWARNINGBOX`) [A]
- [ ] Arrastar e soltar arquivos na janela para abrir
- [ ] Arquivos grandes: carregamento com ajustes de desempenho (`IDD_PREFERENCE_SUB_PERFORMANCE`, `-loadingTime`, `-qSpeed`)
- [ ] Criar pasta ao salvar (`IDD_CREATE_DIRECTORY`)
- [ ] Caminho e nome do arquivo em `IDD_FILERELOCALIZER_DIALOG` (localizar arquivo movido)
- [ ] Aviso de salvar tudo e de salvar ou não (`IDD_DOSAVEALLBOX`, `IDD_DOSAVEORNOTBOX`)


## 8. Edição (comportamentos além do menu)

- [ ] Modo coluna com Alt e arrastar (e o Editor de colunas, `IDD_COLUMNEDIT`)
- [ ] Múltiplos cursores e seleções simultâneas
- [ ] Espaço virtual [?]
- [ ] Indentação automática; tabulações ou espaços por linguagem (`IDD_PREFERENCE_SUB_INDENTATION`)
- [ ] Destaque do delimitador correspondente e ir para o par
- [ ] Destaque das ocorrências da palavra selecionada (`IDD_PREFERENCE_SUB_HIGHLIGHTING`)
- [ ] Guias de indentação
- [ ] Dobra de código pela margem, com níveis (`FOLD_1..8`, `UNFOLD_1..8`)
- [ ] Números de linha
- [ ] Mostrar espaços, fim de linha e todos os caracteres
- [ ] Zoom com a roda do mouse [?]
- [ ] Quebra de linha com símbolo
- [ ] Régua e borda de largura (`IDD_PREFERENCE_SUB_MARGING_BORDER_EDGE`)
- [ ] Caracteres de palavra e delimitadores de seleção (`IDD_PREFERENCE_SUB_DELIMITER`, aviso `IDD_STATIC_WORDCHAR_WARNING`)
- [ ] Autocompletar: palavras, funções pela lista de APIs (`installer/APIs`, 34 arquivos), caminhos e dica de parâmetros
- [ ] Inserir data e hora em formatos curto, longo e personalizado (`IDD_DATETIMEFORMAT_*`)
- [ ] Remover e converter fim de linha
- [ ] Ir para linha (`IDD_GOLINE`) e ir para caractere


## 9. Pesquisar

- [ ] Localizar e substituir em uma janela só (`IDD_FIND_REPLACE_DLG`), com modos de localizar, substituir, em arquivos e marcar
- [ ] Localizar em arquivos: filtros, pastas, recursivo e painel de resultados
- [ ] Localizar tudo, com contagem de ocorrências
- [ ] Busca incremental ao digitar
- [ ] Busca estendida: `\n`, `\r`, `\t`, `\0`, `\x`, `\u` [?]
- [ ] Opção para `.` casar quebra de linha [?]
- [ ] Pesquisar a seleção na web (`IDM_SEARCH_SEARCHONINTERNET`) e escolher o mecanismo (`IDD_PREFERENCE_SUB_SEARCHENGINE`)
- [ ] Preencher o campo de busca com a seleção (`IDD_FILL_FIND_FIELD_GRP_STATIC`)
- [ ] Marcações coloridas em cinco estilos, com navegação entre elas
- [ ] Copiar, apagar e recortar linhas marcadas (`CUTMARKEDLINES` e equivalentes)


## 10. Linguagens, estilos e temas

- [ ] **Linguagens**: 96 em `langs.model.xml`. Lista completa na seção 10a
- [ ] **Lexers**: 128 arquivos em `lexilla/lexers`, usados pelas linguagens acima
- [ ] **Linguagem definida pelo usuário (UDL)**: editor completo (palavras-chave, delimitadores, comentários, operadores, números, dobra e estilos), importar e exportar XML (`userDefineLang.xml`, `IDD_USER_DEFINE_BOX`)
- [ ] **Configurador de estilos** por linguagem (`IDD_STYLER_DLG`) e **estilos globais** (`IDD_GLOBAL_STYLER_DLG`)
- [ ] **Temas de estilo**: 22 em `PowerEditor/installer/themes` (lista na seção 10b)
- [ ] **Modo escuro** com tema próprio (`DarkModeDefault.xml`)
- [ ] **Listas de funções**: 48 parsers em `installer/functionList`
- [ ] **APIs de autocompletar**: 34 arquivos em `installer/APIs`
- [ ] Associação de extensões a linguagens (`IDD_PREFERENCE_SUB_LANGUAGE`)
- [ ] Tags HTML e XML: destaque da tag correspondente e fechamento automático
- [ ] Idioma do menu Linguagem, com os itens `IDM_LANG_*` (seção 2.6)


## 10a. Linguagens (96, de `langs.model.xml`)

- [ ] `normal`
- [ ] `actionscript`
- [ ] `ada`
- [ ] `asm`
- [ ] `asn1`
- [ ] `asp`
- [ ] `autoit`
- [ ] `avs`
- [ ] `baanc`
- [ ] `bash`
- [ ] `batch`
- [ ] `blitzbasic`
- [ ] `c`
- [ ] `caml`
- [ ] `cmake`
- [ ] `cobol`
- [ ] `csound`
- [ ] `coffeescript`
- [ ] `cpp`
- [ ] `cs`
- [ ] `css`
- [ ] `d`
- [ ] `diff`
- [ ] `erlang`
- [ ] `errorlist`
- [ ] `escseq`
- [ ] `escript`
- [ ] `forth`
- [ ] `fortran`
- [ ] `fortran77`
- [ ] `freebasic`
- [ ] `go`
- [ ] `gui4cli`
- [ ] `haskell`
- [ ] `hollywood`
- [ ] `html`
- [ ] `ini`
- [ ] `inno`
- [ ] `ihex`
- [ ] `java`
- [ ] `javascript`
- [ ] `javascript.js`
- [ ] `json`
- [ ] `json5`
- [ ] `jsp`
- [ ] `kix`
- [ ] `lisp`
- [ ] `latex`
- [ ] `lua`
- [ ] `makefile`
- [ ] `matlab`
- [ ] `mssql`
- [ ] `mmixal`
- [ ] `nim`
- [ ] `nncrontab`
- [ ] `nfo`
- [ ] `nsis`
- [ ] `oscript`
- [ ] `objc`
- [ ] `pascal`
- [ ] `perl`
- [ ] `php`
- [ ] `postscript`
- [ ] `powershell`
- [ ] `props`
- [ ] `purebasic`
- [ ] `python`
- [ ] `gdscript`
- [ ] `r`
- [ ] `raku`
- [ ] `rebol`
- [ ] `registry`
- [ ] `rc`
- [ ] `ruby`
- [ ] `rust`
- [ ] `sas`
- [ ] `scheme`
- [ ] `smalltalk`
- [ ] `fcST`
- [ ] `spice`
- [ ] `sql`
- [ ] `srec`
- [ ] `swift`
- [ ] `tcl`
- [ ] `tehex`
- [ ] `tex`
- [ ] `toml`
- [ ] `vb`
- [ ] `txt2tags`
- [ ] `typescript`
- [ ] `verilog`
- [ ] `vhdl`
- [ ] `visualprolog`
- [ ] `xml`
- [ ] `yaml`
- [ ] `searchResult`


## 10b. Temas de estilo (22, de `installer/themes`)

- [ ] `Bespin`
- [ ] `Black board`
- [ ] `Choco`
- [ ] `DansLeRuSH-Dark`
- [ ] `DarkModeDefault`
- [ ] `Deep Black`
- [ ] `Hello Kitty`
- [ ] `HotFudgeSundae`
- [ ] `Mono Industrial`
- [ ] `Monokai`
- [ ] `MossyLawn`
- [ ] `Navajo`
- [ ] `Obsidian`
- [ ] `Plastic Code Wrap`
- [ ] `Ruby Blue`
- [ ] `Solarized-light`
- [ ] `Solarized`
- [ ] `Twilight`
- [ ] `Vibrant Ink`
- [ ] `Zenburn`
- [ ] `khaki`
- [ ] `vim Dark Blue`


## 11. Codificação e fim de linha

- [ ] Detecção automática de codificação (uchardet)
- [ ] Reabrir o arquivo com outra codificação, sem converter o conteúdo
- [ ] Converter o texto para outra codificação e salvar
- [ ] Codificação padrão de novo documento (`IDD_PREFERENCE_SUB_NEWDOCUMENT`)
- [ ] Fim de linha: Windows (CRLF), Unix (LF) e Mac (CR), com conversão
- [ ] Mostrar a codificação e o fim de linha na barra de status
- [ ] Lista completa de codificações: seção 11a


## 11a. Codificações (46, de `EncodingMapper.cpp`)

- [ ] `windows-1250` (CP 1250)
- [ ] `windows-1251` (CP 1251)
- [ ] `windows-1252` (CP 1252)
- [ ] `windows-1253` (CP 1253)
- [ ] `windows-1254` (CP 1254)
- [ ] `windows-1255` (CP 1255)
- [ ] `windows-1256` (CP 1256)
- [ ] `windows-1257` (CP 1257)
- [ ] `windows-1258` (CP 1258)
- [ ] `latin1` (CP 28591)
- [ ] `latin2` (CP 28592)
- [ ] `latin3` (CP 28593)
- [ ] `latin4` (CP 28594)
- [ ] `cyrillic` (CP 28595)
- [ ] `arabic` (CP 28596)
- [ ] `greek` (CP 28597)
- [ ] `hebrew` (CP 28598)
- [ ] `latin5` (CP 28599)
- [ ] `ISO_8859-13` (CP 28603)
- [ ] `iso-celtic` (CP 28604)
- [ ] `Latin-9` (CP 28605)
- [ ] `IBM437` (CP 437)
- [ ] `IBM720` (CP 720)
- [ ] `IBM737` (CP 737)
- [ ] `IBM775` (CP 775)
- [ ] `IBM850` (CP 850)
- [ ] `IBM852` (CP 852)
- [ ] `IBM855` (CP 855)
- [ ] `IBM857` (CP 857)
- [ ] `IBM858` (CP 858)
- [ ] `IBM860` (CP 860)
- [ ] `IBM861` (CP 861)
- [ ] `IBM862` (CP 862)
- [ ] `IBM863` (CP 863)
- [ ] `IBM865` (CP 865)
- [ ] `IBM866` (CP 866)
- [ ] `IBM869` (CP 869)
- [ ] `big5` (CP 950)
- [ ] `gb2312` (CP 936)
- [ ] `Shift_JIS` (CP 932)
- [ ] `windows-949` (CP 949)
- [ ] `euc-kr` (CP 51949)
- [ ] `tis-620` (CP 874)
- [ ] `x-mac-cyrillic` (CP 10007)
- [ ] `koi8_u` (CP 21866)
- [ ] `koi8_r` (CP 20866)


## 12. Plugins

- [ ] Carregar plugins compilados: `.dll` no Windows, `.so` no Linux [A]
- [ ] Pastas de plugins do usuário e do sistema (XDG) [A]
- [ ] Gerenciador de plugins: listar, ativar, desativar, instalar, atualizar e remover (`IDD_PLUGINSADMIN_DLG`, `WinControls/PluginsAdmin`)
- [ ] Lista de plugins do catálogo online (exige rede)
- [ ] Menu Plugins e os comandos de cada plugin
- [ ] Desativar todos os plugins na linha de comando (`-noPlugin`)
- [ ] Compatibilidade binária com DLLs do Windows [W]
- [ ] Plugin **NppExport** (referenciado em `PowerEditor/src`): port ou equivalente [A]
- [ ] Plugin **Converter** (referenciado em `PowerEditor/src`): port ou equivalente [A]
- [ ] Plugin **mimeTools** (referenciado em `PowerEditor/src`): port ou equivalente [A]
- [ ] Plugin **Hex Editor** (referenciado em `PowerEditor/src`): port ou equivalente [A]
- [ ] Plugin **DSpellCheck** (referenciado em `PowerEditor/src`): port ou equivalente [A]
- [ ] Plugin **Compare** (referenciado em `PowerEditor/src`): port ou equivalente [A]
- [ ] Plugin **XML Tools** (referenciado em `PowerEditor/src`): port ou equivalente [A]
- [ ] Plugin **NppExec** (referenciado em `PowerEditor/src`): port ou equivalente [A]
- [ ] Plugin **Explorer** (referenciado em `PowerEditor/src`): port ou equivalente [A]


## 12a. Mensagens da API de plugins (`NPPM_`, 123)

Fonte: `PowerEditor/src/MISC/PluginsManager/Notepad_plus_msgs.h`.

- [ ] `NPPM_ACTIVATEDOC`
- [ ] `NPPM_ADDSCNMODIFIEDFLAGS`
- [ ] `NPPM_ADDTOOLBARICON`
- [ ] `NPPM_ADDTOOLBARICON_DEPRECATED`
- [ ] `NPPM_ADDTOOLBARICON_FORDARKMODE`
- [ ] `NPPM_ALLOCATECMDID`
- [ ] `NPPM_ALLOCATEINDICATOR`
- [ ] `NPPM_ALLOCATEMARKER`
- [ ] `NPPM_ALLOCATESUPPORTED_DEPRECATED`
- [ ] `NPPM_CREATELEXER`
- [ ] `NPPM_CREATESCINTILLAHANDLE`
- [ ] `NPPM_DARKMODESUBCLASSANDTHEME`
- [ ] `NPPM_DECODESCI`
- [ ] `NPPM_DESTROYSCINTILLAHANDLE_DEPRECATED`
- [ ] `NPPM_DISABLEAUTOUPDATE`
- [ ] `NPPM_DMMGETPLUGINHWNDBYNAME`
- [ ] `NPPM_DMMHIDE`
- [ ] `NPPM_DMMREGASDCKDLG`
- [ ] `NPPM_DMMSHOW`
- [ ] `NPPM_DMMUPDATEDISPINFO`
- [ ] `NPPM_DMMVIEWOTHERTAB`
- [ ] `NPPM_DOCLISTDISABLEEXTCOLUMN`
- [ ] `NPPM_DOCLISTDISABLEPATHCOLUMN`
- [ ] `NPPM_DOOPEN`
- [ ] `NPPM_ENCODESCI`
- [ ] `NPPM_GETAPPDATAPLUGINSALLOWED`
- [ ] `NPPM_GETBOOKMARKID`
- [ ] `NPPM_GETBUFFERENCODING`
- [ ] `NPPM_GETBUFFERFORMAT`
- [ ] `NPPM_GETBUFFERIDFROMPOS`
- [ ] `NPPM_GETBUFFERLANGTYPE`
- [ ] `NPPM_GETCURRENTBUFFERID`
- [ ] `NPPM_GETCURRENTCMDLINE`
- [ ] `NPPM_GETCURRENTCOLUMN`
- [ ] `NPPM_GETCURRENTDIRECTORY`
- [ ] `NPPM_GETCURRENTDOCINDEX`
- [ ] `NPPM_GETCURRENTLANGTYPE`
- [ ] `NPPM_GETCURRENTLINE`
- [ ] `NPPM_GETCURRENTLINESTR`
- [ ] `NPPM_GETCURRENTMACROSTATUS`
- [ ] `NPPM_GETCURRENTNATIVELANGENCODING`
- [ ] `NPPM_GETCURRENTSCINTILLA`
- [ ] `NPPM_GETCURRENTVIEW`
- [ ] `NPPM_GETCURRENTWORD`
- [ ] `NPPM_GETDARKMODECOLORS`
- [ ] `NPPM_GETEDITORDEFAULTBACKGROUNDCOLOR`
- [ ] `NPPM_GETEDITORDEFAULTFOREGROUNDCOLOR`
- [ ] `NPPM_GETENABLETHEMETEXTUREFUNC`
- [ ] `NPPM_GETENABLETHEMETEXTUREFUNC_DEPRECATED`
- [ ] `NPPM_GETEXTERNALLEXERAUTOINDENTMODE`
- [ ] `NPPM_GETEXTPART`
- [ ] `NPPM_GETFILENAME`
- [ ] `NPPM_GETFILENAMEATCURSOR`
- [ ] `NPPM_GETFULLCURRENTPATH`
- [ ] `NPPM_GETFULLPATHFROMBUFFERID`
- [ ] `NPPM_GETLANGUAGEDESC`
- [ ] `NPPM_GETLANGUAGENAME`
- [ ] `NPPM_GETLINENUMBERWIDTHMODE`
- [ ] `NPPM_GETMENUHANDLE`
- [ ] `NPPM_GETNAMEPART`
- [ ] `NPPM_GETNATIVELANGFILENAME`
- [ ] `NPPM_GETNBOPENFILES`
- [ ] `NPPM_GETNBSESSIONFILES`
- [ ] `NPPM_GETNBUSERLANG`
- [ ] `NPPM_GETNPPDIRECTORY`
- [ ] `NPPM_GETNPPFULLFILEPATH`
- [ ] `NPPM_GETNPPSETTINGSDIRPATH`
- [ ] `NPPM_GETNPPVERSION`
- [ ] `NPPM_GETOPENFILENAMESPRIMARY_DEPRECATED`
- [ ] `NPPM_GETOPENFILENAMESSECOND_DEPRECATED`
- [ ] `NPPM_GETOPENFILENAMES_DEPRECATED`
- [ ] `NPPM_GETPLUGINHOMEPATH`
- [ ] `NPPM_GETPLUGINSCONFIGDIR`
- [ ] `NPPM_GETPOSFROMBUFFERID`
- [ ] `NPPM_GETSESSIONFILES`
- [ ] `NPPM_GETSETTINGSCLOUDPATH`
- [ ] `NPPM_GETSETTINGSONCLOUDPATH`
- [ ] `NPPM_GETSHORTCUTBYCMDID`
- [ ] `NPPM_GETTABCOLORID`
- [ ] `NPPM_GETTOOLBARICONSETCHOICE`
- [ ] `NPPM_GETWINDOWSVERSION`
- [ ] `NPPM_GETXXXXXXXXXXXXXXXX`
- [ ] `NPPM_HIDEMENU`
- [ ] `NPPM_HIDESTATUSBAR`
- [ ] `NPPM_HIDETABBAR`
- [ ] `NPPM_HIDETOOLBAR`
- [ ] `NPPM_ISAUTOINDENTON`
- [ ] `NPPM_ISDARKMODEENABLED`
- [ ] `NPPM_ISDOCLISTSHOWN`
- [ ] `NPPM_ISMENUHIDDEN`
- [ ] `NPPM_ISSTATUSBARHIDDEN`
- [ ] `NPPM_ISTABBARHIDDEN`
- [ ] `NPPM_ISTOOLBARHIDDEN`
- [ ] `NPPM_LAUNCHFINDINFILESDLG`
- [ ] `NPPM_LOADSESSION`
- [ ] `NPPM_MAKECURRENTBUFFERDIRTY`
- [ ] `NPPM_MENUCOMMAND`
- [ ] `NPPM_MODELESSDIALOG`
- [ ] `NPPM_MSGTOPLUGIN`
- [ ] `NPPM_RELOADBUFFERID`
- [ ] `NPPM_RELOADFILE`
- [ ] `NPPM_REMOVESHORTCUTBYCMDID`
- [ ] `NPPM_SAVEALLFILES`
- [ ] `NPPM_SAVECURRENTFILE`
- [ ] `NPPM_SAVECURRENTFILEAS`
- [ ] `NPPM_SAVECURRENTSESSION`
- [ ] `NPPM_SAVEFILE`
- [ ] `NPPM_SAVESESSION`
- [ ] `NPPM_SETBUFFERENCODING`
- [ ] `NPPM_SETBUFFERFORMAT`
- [ ] `NPPM_SETBUFFERLANGTYPE`
- [ ] `NPPM_SETCURRENTLANGTYPE`
- [ ] `NPPM_SETEDITORBORDEREDGE`
- [ ] `NPPM_SETEXTERNALLEXERAUTOINDENTMODE`
- [ ] `NPPM_SETLINENUMBERWIDTHMODE`
- [ ] `NPPM_SETMENUITEMCHECK`
- [ ] `NPPM_SETSMOOTHFONT`
- [ ] `NPPM_SETSTATUSBAR`
- [ ] `NPPM_SETTABCOLORID`
- [ ] `NPPM_SETUNTITLEDNAME`
- [ ] `NPPM_SHOWDOCLIST`
- [ ] `NPPM_SWITCHTOFILE`
- [ ] `NPPM_TRIGGERTABBARCONTEXTMENU`

## 12b. Notificações para plugins (`NPPN_`, 33)

- [ ] `NPPN_BEFORESHUTDOWN`
- [ ] `NPPN_BUFFERACTIVATED`
- [ ] `NPPN_CANCELSHUTDOWN`
- [ ] `NPPN_CMDLINEPLUGINMSG`
- [ ] `NPPN_DARKMODECHANGED`
- [ ] `NPPN_DOCORDERCHANGED`
- [ ] `NPPN_EXTERNALLEXERBUFFER`
- [ ] `NPPN_FILEBEFORECLOSE`
- [ ] `NPPN_FILEBEFOREDELETE`
- [ ] `NPPN_FILEBEFORELOAD`
- [ ] `NPPN_FILEBEFOREOPEN`
- [ ] `NPPN_FILEBEFORERENAME`
- [ ] `NPPN_FILEBEFORESAVE`
- [ ] `NPPN_FILECLOSED`
- [ ] `NPPN_FILEDELETED`
- [ ] `NPPN_FILEDELETEFAILED`
- [ ] `NPPN_FILELOADFAILED`
- [ ] `NPPN_FILEOPENED`
- [ ] `NPPN_FILERENAMECANCEL`
- [ ] `NPPN_FILERENAMED`
- [ ] `NPPN_FILESAVED`
- [ ] `NPPN_FIRST`
- [ ] `NPPN_GLOBALMODIFIED`
- [ ] `NPPN_LANGCHANGED`
- [ ] `NPPN_NATIVELANGCHANGED`
- [ ] `NPPN_READONLYCHANGED`
- [ ] `NPPN_READY`
- [ ] `NPPN_SHORTCUTREMAPPED`
- [ ] `NPPN_SHUTDOWN`
- [ ] `NPPN_SNAPSHOTDIRTYFILELOADED`
- [ ] `NPPN_TBMODIFICATION`
- [ ] `NPPN_TOOLBARICONSETCHANGED`
- [ ] `NPPN_WORDSTYLESUPDATED`


## 13. Linha de comando

Fonte: `PowerEditor/src/winmain.cpp`, `Parameters.cpp` e `NppIO.cpp`. Alguns switches são internos, como `-clean` (usado pelo gerenciador de plugins). O significado de cada um deve ser confirmado antes da implementação.

- [ ] `-alwaysOnTop`
- [ ] `-clean`
- [ ] `-export`
- [ ] `-fullReadOnly`
- [ ] `-fullReadOnlySavingForbidden`
- [ ] `-lLANG`
- [ ] `-loadingTime`
- [ ] `-monitor`
- [ ] `-monitoringMode`
- [ ] `-moveFolder`
- [ ] `-multiInst`
- [ ] `-noPlugin`
- [ ] `-nosession`
- [ ] `-notabbar`
- [ ] `-notepadStyleCmdline`
- [ ] `-openFoldersAsWorkspace`
- [ ] `-openSession`
- [ ] `-options`
- [ ] `-pluginMessage`
- [ ] `-qSpeed`
- [ ] `-qf`
- [ ] `-qn`
- [ ] `-qt`
- [ ] `-quickPrint`
- [ ] `-r`
- [ ] `-ro`
- [ ] `-settingsDir`
- [ ] `-systemtray`
- [ ] `-titleAdd`
- [ ] `-udl`
- [ ] `-unzipTo`
- [ ] `-v`
- [ ] `-z`


## 14. Arquivos de configuração (compatíveis com o Notepad++)

Compatibilidade com os arquivos do Notepad++ é um objetivo, para o usuário trazer as configurações sem perder nada.

- [ ] `config.xml` e `config.model.xml` (preferências)
- [ ] `stylers.xml` e `stylers.model.xml` (estilos)
- [ ] `langs.xml` e `langs.model.xml` (linguagens)
- [ ] `shortcuts.xml` e `shortcuts.model.xml` (atalhos)
- [ ] `contextMenu.xml` e `contextMenu.model.xml` (menu de contexto)
- [ ] `toolbarButtonsConf.xml` (barra de ferramentas)
- [ ] `session.xml` (sessão)
- [ ] `userDefineLang.xml` (linguagens do usuário)
- [ ] `disableNppAutoUpdate.xml` e `doLocalConf.xml` (`PowerEditor/installer/xml4Config`), para desativar a atualização e usar configuração local [A]
- [ ] Importar as configurações do Notepad++ (XML) para o Quill
- [ ] Exportar as configurações do Quill em XML
- [ ] Modo portátil: configurações na pasta do programa (`-settingsDir`)
- [ ] Pastas de temas, APIs, listas de funções e idiomas, do sistema e do usuário


## 15. Idiomas da interface (96, de `installer/nativeLang`)

- [ ] `abkhazian`
- [ ] `afrikaans`
- [ ] `albanian`
- [ ] `arabic`
- [ ] `aragonese`
- [ ] `aranese`
- [ ] `azerbaijani`
- [ ] `basque`
- [ ] `belarusian`
- [ ] `bengali`
- [ ] `bosnian`
- [ ] `brazilian_portuguese`
- [ ] `breton`
- [ ] `bulgarian`
- [ ] `catalan`
- [ ] `chineseSimplified`
- [ ] `corsican`
- [ ] `croatian`
- [ ] `czech`
- [ ] `danish`
- [ ] `dutch`
- [ ] `english`
- [ ] `english_customizable`
- [ ] `esperanto`
- [ ] `estonian`
- [ ] `extremaduran`
- [ ] `farsi`
- [ ] `finnish`
- [ ] `french`
- [ ] `friulian`
- [ ] `galician`
- [ ] `georgian`
- [ ] `german`
- [ ] `greek`
- [ ] `gujarati`
- [ ] `hebrew`
- [ ] `hindi`
- [ ] `hongKongCantonese`
- [ ] `hungarian`
- [ ] `indonesian`
- [ ] `irish`
- [ ] `italian`
- [ ] `japanese`
- [ ] `kabyle`
- [ ] `kannada`
- [ ] `kazakh`
- [ ] `korean`
- [ ] `kurdish`
- [ ] `kyrgyz`
- [ ] `lao`
- [ ] `latvian`
- [ ] `ligurian`
- [ ] `lithuanian`
- [ ] `luxembourgish`
- [ ] `macedonian`
- [ ] `malay`
- [ ] `malayalam`
- [ ] `marathi`
- [ ] `mongolian`
- [ ] `nepali`
- [ ] `norwegian`
- [ ] `nynorsk`
- [ ] `occitan`
- [ ] `piglatin`
- [ ] `polish`
- [ ] `portuguese`
- [ ] `punjabi`
- [ ] `romanian`
- [ ] `russian`
- [ ] `samogitian`
- [ ] `sardinian`
- [ ] `serbian`
- [ ] `serbianCyrillic`
- [ ] `sinhala`
- [ ] `slovak`
- [ ] `slovenian`
- [ ] `spanish`
- [ ] `spanish_ar`
- [ ] `swedish`
- [ ] `tagalog`
- [ ] `taiwaneseMandarin`
- [ ] `tajikCyrillic`
- [ ] `tamil`
- [ ] `tatar`
- [ ] `telugu`
- [ ] `thai`
- [ ] `turkish`
- [ ] `ukrainian`
- [ ] `urdu`
- [ ] `uyghur`
- [ ] `uzbek`
- [ ] `uzbekCyrillic`
- [ ] `venetian`
- [ ] `vietnamese`
- [ ] `welsh`
- [ ] `zulu`


## 16. Atualização e instalação

- [ ] Atualização automática do programa (WinGup, `NppCommands.cpp`, `winmain.cpp`) [W]
- [ ] Desativar a atualização automática (`disableNppAutoUpdate.xml`)
- [ ] Instalação para o usuário, sem root, e instalação para o sistema [A]
- [ ] Instalador: NSIS (`nppSetup.nsi`) e MSI (`msi/`) viram AppImage e `.deb` no Linux [A]
- [ ] Modo portátil (seção 14)


## 17. Integração com o sistema

- [ ] Item no menu de contexto do gerenciador de arquivos (`RegExt`, `IDD_REGEXT`) [W]
- [ ] Associação de tipos de arquivo pelo sistema (registro do Windows) [W]
- [ ] Substituir o Bloco de Notas (recurso `notepadStyleCmdline` e associações) [W]
- [ ] Abrir a pasta do arquivo no gerenciador de arquivos (equivalente ao Explorer, comandos da seção 2) [A]
- [ ] Abrir o arquivo no navegador (itens de navegador da seção 2) [A]
- [ ] Impressão, com diálogo do sistema e cabeçalho e rodapé (`ScintillaComponent/Printer.cpp`) [A]
- [ ] Executar comandos externos e abrir arquivos pelo sistema (`ShellExecute`) [A]
- [ ] Notificações do sistema [A]


## 18. Ferramentas

- [ ] MD5 de texto (`IDD_MD5FROMTEXT_DLG`) e de arquivos (`IDD_MD5FROMFILES_DLG`)
- [ ] SHA-1, SHA-2 e SHA-512: confirmar quais comandos existem em 2.8 e se têm diálogo próprio
- [ ] Caixa de valor (`IDD_VALUE_DLG`)
- [ ] Caixa de botões para escolhas (`IDD_BUTTON_DLG`)
- [ ] Caixa de entrada de texto para inserção (`IDD_INSERT_INPUT_TEXT`)
- [ ] Informações de depuração e de sistema (`IDD_DEBUGINFOBOX`)


## 19. Testes e qualidade

- [ ] Usar `PowerEditor/installer/filesForTesting` (`overrideMap.xml`, `regexGlobalTest.xml`) como dados de teste
- [ ] Autoteste no Linux com CTest
- [ ] Teste de codificação para cada uma das 46 codificações da seção 11
- [ ] Teste de expressões regulares com o arquivo de casos
- [ ] Teste de arquivos grandes (100 MB ou mais) e de linhas muito longas
- [ ] Teste de abrir muitos arquivos de uma vez
- [ ] Teste de importação das configurações do Notepad++ (seção 14)
- [ ] CI no Linux (GitHub Actions, Ubuntu)
- [ ] Acessibilidade por AT-SPI e navegação completa pelo teclado


## 20. Plano de desenvolvimento

Ordem sugerida. Cada fase termina com commit, CI verde e esta lista atualizada.

- [ ] **F0, infraestrutura**: CMake com `elseif(UNIX AND NOT APPLE)`, `build-linux.sh`, CI Linux, escolha de toolkit e de regex, Scintilla e Lexilla nas versões do Notepad++
- [ ] **F1, casca**: janela, abas, editor, abrir, salvar e barra de status
- [ ] **F2, menus**: os 520 comandos da seção 2, em lotes: Arquivo, Editar, Pesquisar, Exibir, Formatar, Linguagem, Configurações, Ferramentas, Macro, Executar, Janela, Ajuda
- [ ] **F3, pesquisa e codificação**: seções 9 e 11
- [ ] **F4, linguagens e estilos**: seções 10 e 10a, com compatibilidade de XML (seção 14)
- [ ] **F5, preferências e sessão**: seções 5, 7 e 14
- [ ] **F6, painéis**: seções 3, 4 e 6
- [ ] **F7, plugins**: host da API `NPPM_`/`NPPN_` (seção 12) e port dos plugins recomendados
- [ ] **F8, integração e instalação**: seções 16 e 17
- [ ] **F9, localização e testes**: seções 15 e 19
- [ ] **F10, release Linux**: tag `linux-vX.Y.Z`, AppImage e `.tar.gz`


## 21. Para discussão: o que pode não funcionar no Linux

Itens marcados `[W]` existem só no Windows. Cada um precisa de decisão: equivalente, adaptação ou fora do escopo.

- [ ] `IDM_FILE_OPEN_POWERSHELL` [W]
- [ ] `IDM_FORMAT_ANSI` [W]
- [ ] `IDM_FORMAT_CONV2_ANSI` [W]
- [ ] `IDM_UPDATE_NPP` [W]
- [ ] Compatibilidade binária com DLLs do Windows [W]
- [ ] Atualização automática do programa (WinGup, `NppCommands.cpp`, `winmain.cpp`) [W]
- [ ] Item no menu de contexto do gerenciador de arquivos (`RegExt`, `IDD_REGEXT`) [W]
- [ ] Associação de tipos de arquivo pelo sistema (registro do Windows) [W]
- [ ] Substituir o Bloco de Notas (recurso `notepadStyleCmdline` e associações) [W]

## 22. Decisões em aberto

Não são itens de implementação. Precisam de escolha antes da fase F0.

- [ ] **Toolkit de interface**: Qt 6 (recomendado: painéis, diálogos, tabelas e árvores já existem) ou GTK 4
- [ ] **Motor de regex**: Boost.Regex (mesma sintaxe do Notepad++), PCRE2 ou `std::regex`
- [ ] **Versões de Scintilla e Lexilla**: usar as do Notepad++ (569 / 555), ou fixar outra versão e justificar
- [ ] **Compatibilidade de plugins**: a API `NPPM_`/`NPPN_` é a mesma em Windows e Linux, mas as DLLs não rodam. Escolha: recompilar plugins como `.so` com um SDK próprio deste projeto, ou não oferecer compatibilidade
- [ ] **Fonte do manual**: `npp-user-manual.org` não resolveu no ambiente (`ENOTFOUND`). Esta lista se baseou no repositório e no código. Checar o manual antes de fechar os itens marcados com `[?]`
