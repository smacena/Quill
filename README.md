# Quill

A **100% native macOS** text and code editor inspired by Notepad++, built on the same editing engine (Scintilla + Lexilla) and offering a **Notepad++-compatible plugin API**.

*[Versão em português](README.pt-BR.md)*

## Install

### Option 1: download
1. Open [Releases](../../releases/tag/latest) and download **Quill-macOS.zip**.
2. Unzip and move **Quill.app** to **Applications**.
3. First launch: **right-click → Open** (the app is ad-hoc signed).
   If macOS still blocks it: `xattr -dr com.apple.quarantine /Applications/Quill.app`

### Option 2: build on your Mac
Requires macOS 13+, Xcode Command Line Tools (`xcode-select --install`) and CMake (`brew install cmake`).

```bash
./build.sh install
```

Universal binary (Apple Silicon + Intel).

## Editor features

- Tabs (drag to reorder, context menu, reopen closed tab ⇧⌘T)
- Syntax highlighting for ~100 languages, code folding, line numbers
- Find/replace with regular expressions, mark all, **Find in Files** (⇧⌘F)
- Multiple cursors (⌥⌘D next occurrence, ⇧⌘L all), rectangular selection (⌥-drag)
- Line operations: duplicate, move, sort, remove duplicates/empty lines, trim whitespace
- Toggle comment (⌘/), case conversion, indentation, tabs ↔ spaces
- Encodings: UTF-8, UTF-8 BOM, UTF-16 LE/BE, Windows-1252, ISO-8859-1, Mac Roman; LF/CRLF/CR
- Bookmarks (⌘F2 / F2), go to line (⌘L), matching brace, word completion
- Change history margin, highlight of the selected word
- Automatic light/dark theme, session restore, **unsaved changes kept across restarts**
- Detects files changed by other programs
- **English** and **Portuguese** UI (Quill → Language / Idioma)

## Bundled plugins

| Plugin | What it does |
|---|---|
| **Compare** | Side-by-side diff with previous/next tab, saved version, clipboard or two files; char-level highlights, synced scrolling |
| **JSON Viewer** | Tree view, format, minify, sort keys, validate with error position |
| **XML Tools** | Pretty print, linearize, syntax check, XPath, entity escaping |
| **Exec** | Run commands and scripts (⌘R runs the current file) in a console with NppExec-style variables and clickable `file:line` links |
| **Explorer** | Folder tree panel with create, rename, trash, drag & drop, filter |
| **Markdown Viewer** | Live preview, export/copy HTML |
| **Spell Check** | macOS spell checker, suggestions in the context menu |
| **Hex Editor** | View and edit bytes, go to offset, find bytes |
| **FTP** | SFTP, FTP and FTPS; passwords in the Keychain; open remote files and upload on save |

## Third-party plugins

Plugins are `.dylib` files in `~/Library/Application Support/Quill/plugins/`. Notepad++'s Windows DLLs cannot run on macOS, but open-source plugins can be recompiled against the SDK in `sdk/include`, which mirrors the Notepad++ API. See the [plugin guide](PLUGINS.md).

## License

GPL v3. Uses Scintilla and Lexilla (Scintilla license), md4c (MIT) and language data from the Notepad++ project (GPL).
