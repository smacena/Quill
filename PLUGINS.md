# Writing Quill plugins / Escrevendo plugins para o Quill

Quill loads plugins with the **same interface as Notepad++**. A plugin is a `.dylib` exporting:

```cpp
extern "C" void setInfo(NppData data);
extern "C" const wchar_t *getName();
extern "C" FuncItem *getFuncsArray(int *count);
extern "C" void beNotified(SCNotification *notification);
extern "C" LRESULT messageProc(UINT msg, WPARAM wParam, LPARAM lParam);
extern "C" BOOL isUnicode();
```

Include `sdk/include/PluginInterface.h` (plus `Docking.h`, `menuCmdID.h`). `QuillWin32.h` provides the Windows types, `SendMessage` and `MessageBox`, so most Notepad++ plugin logic compiles unchanged. Strings are `wchar_t` (UTF-32 on macOS); Scintilla text is UTF-8.

## Porting a Notepad++ plugin

1. Keep the plugin logic; remove `windows.h`, `DllMain` and Win32 dialogs.
2. Rewrite the UI with AppKit (Objective-C++ `.mm` files). Docked panels: pass an `NSView*` as `tTbData.hClient` to `NPPM_DMMREGASDCKDLG`, then `NPPM_DMMSHOW` / `NPPM_DMMHIDE`.
3. Shortcuts: `_isCtrl` maps to ⌘ and `_isAlt` to ⌥.
4. Build:

```bash
clang++ -std=c++17 -fobjc-arc -dynamiclib -undefined dynamic_lookup \
  -I sdk/include -I third_party/scintilla/include -I third_party/scintilla/cocoa \
  MyPlugin.mm -framework Cocoa -o MyPlugin.dylib
```

5. Copy `MyPlugin.dylib` to `~/Library/Application Support/Quill/plugins/` and restart Quill.

## Quill extensions (`QuillExtensions.h`)

| Message | Purpose |
|---|---|
| `QUILLM_GETUILANGUAGE` | 0 = English, 1 = Portuguese |
| `QUILLM_GETBUFFERTEXT` | UTF-8 text of any open buffer |
| `QUILLM_APPLYEDITORSTYLE` | Apply theme + syntax highlighting to your own Scintilla view |
| `QUILLM_GETMAINWINDOW` / `QUILLM_GETSCINTILLAVIEW` | Native `NSWindow*` / `ScintillaView*` |
| `QUILLM_NEWDOCUMENT` | Open a new tab with text |
| `QUILLM_SETSTATUSMESSAGE` | Status bar message |
| `QUILLM_ADDTOOLBARBUTTON` | Toolbar button with an SF Symbol |
| `QUILLM_ADDCONTEXTMENUHANDLER` | Add items to the editor context menu |
| `QUILLN_PANELCLOSED`, `QUILLN_THEMECHANGED` | Extra notifications |

The bundled plugins in `plugins/` are complete examples (`plugins/common/PluginCommon.h` has helpers).
