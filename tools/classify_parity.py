#!/usr/bin/env python3
"""Tags every item of docs/FULL_PARITY.md with how Quill will treat it.

  [IMPL]  implement the same function on macOS (the user's requirement)
  [MAC]   same purpose, macOS-native equivalent (Finder, Terminal, Safari, Cmd key,
          macOS dialogs). Counted as done when the equivalent works.
  [NA]    cannot exist on macOS (Windows registry, Windows updater, system tray
          of Windows, Administrator mode, Windows session exit, XP, OEM code pages
          tied to MS-DOS, Internet Explorer, etc.). Each NA item needs a reason.

Run after editing the rules; it rewrites docs/FULL_PARITY.md in place.
"""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PATH = os.path.join(ROOT, "docs", "FULL_PARITY.md")

NA_RULES = [
    (r"registry|regedit", "Registro do Windows"),
    (r"Administrator mode|administrator|run Notepad\+\+ as administrator|Administrator", "Modo administrador do Windows (UAC)"),
    (r"XP|Windows XP", "Windows XP"),
    (r"Windows session|session is about to be terminated", "Encerramento de sessão do Windows"),
    (r"Auto-updater|Update silently|Scroll to the last line after update|Update Notepad\+\+|Set Updater Proxy|Notepad\+\+ Updater|XpUpdater|updater is not compatible", "Atualizador do Notepad++ (Windows)"),
    (r"system tray|Tray Icon|tray", "Ícone da bandeja do Windows (no Mac vira ícone na barra de menus, tratado em MAC)"),
    (r"Internet Explorer|view current file in IE|\bin IE\b", "Internet Explorer (não existe no Mac)"),
    (r"Shortcuts\.xml|shortcuts\.xml|ShortcutsXmlHMAC|ShortcutsXmlTampered", "Verificação HMAC do arquivo de atalhos do Windows"),
    (r"Network Path Warning|networkpathwarning|serverWhiteList|Windows to automatically authenticate", "Caminho de rede UNC do Windows"),
    (r"Read-Only Attribute in Windows", "Atributo somente leitura do Windows"),
]

MAC_RULES = [
    (r"Explorer|Containing Folder|Open Containing|Explorer here|Explorer\b", "Finder (Mostrar no Finder)"),
    (r"PowerShell|Command Prompt|\bcmd\b|Windows Command", "Terminal do macOS (substitui cmd e PowerShell)"),
    (r"view current file in (Edge|Chrome|Firefox)|in Edge\b|in Chrome|in Firefox", "Navegador do macOS (Safari, Chrome, Firefox ou Edge, os instalados)"),
    (r"system tray|Tray Icon|tray", "Barra de menus do macOS (ícone equivalente)"),
    (r"Terminal|Command Prompt|cmd|PowerShell|PowerShell here|Explorer here", "Terminal do macOS"),
    (r"Ctrl\+|Ctrl|Alt\+|Alt|Win key|Print Screen|Shift\+", "Tecla ⌘/⌥/⇧/⌃ do macOS (mesma função, atalho do Mac)"),
    (r"Default Viewer|Default Open|Open in Default", "App padrão do macOS"),
    (r"Document Switcher|Ctrl\+TAB", "Ctrl+Tab do macOS (alternar abas)"),
    (r"Toolbar accent|accent color|Windows system accent", "Cor de destaque do macOS"),
]

RULES = {"NA": NA_RULES, "MAC": MAC_RULES}


def classify(text):
    for tag in ("NA", "MAC"):
        for pat, why in RULES[tag]:
            if re.search(pat, text):
                return tag, why
    return "IMPL", ""


def main():
    out = []
    counts = {"IMPL": 0, "MAC": 0, "NA": 0}
    with open(PATH, encoding="utf-8") as f:
        for line in f:
            m = re.match(r"- \[ \] \*\*(.+?)\*\*: (.*)$", line.rstrip("\n"))
            if not m:
                out.append(line.rstrip("\n"))
                continue
            tag, why = classify(m.group(2))
            counts[tag] += 1
            suffix = f" — {why}" if why else ""
            out.append(f"- [ ] [{tag}] **{m.group(1)}**: {m.group(2)}{suffix}")
    with open(PATH, "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")
    print(counts)


if __name__ == "__main__":
    main()
