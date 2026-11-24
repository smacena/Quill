#!/usr/bin/env python3
"""Builds docs/FULL_PARITY.md: one checkbox per UI string of Notepad++.

Usage: python3 tools/gen_parity.py path/to/english.xml
english.xml is PowerEditor/installer/nativeLang/english.xml from the
Notepad++ source (GPL). Every menu entry, dialog label, option, tooltip,
message and panel title becomes one checkbox.
"""
import os
import sys
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "FULL_PARITY.md")


def clean(s):
    return " ".join((s or "").replace("&", "").split())


def main(src):
    root = ET.parse(src).getroot()
    native = root.find("Native-Langue")
    lines = [
        "# Quill × Notepad++ — lista completa de 1 para 1",
        "",
        "Gerada de `PowerEditor/installer/nativeLang/english.xml` (fonte oficial do Notepad++).",
        "Cada linha é um texto de interface do Notepad++: item de menu, opção, rótulo de",
        "diálogo, dica, mensagem ou título de painel. Marque `[x]` só quando o Quill tiver",
        "o mesmo item, com o mesmo comportamento, validado no autoteste.",
        "",
        "Para cada item: a seção (Menu, Dialog, MessageBox, ...) e o texto original em inglês.",
        "",
    ]
    total = done = 0
    for section in native:
        items = []
        for el in section.iter():
            if el is section:
                continue
            name = el.get("name") or el.get("title") or el.get("value") or el.get("message") or el.get("label")
            ident = el.get("id") or el.get("CMDID")
            text = clean(name)
            if el.get("titleFind") or el.get("titleReplace") or el.get("titleFindInFiles") or el.get("titleMark"):
                for k in ("titleFind", "titleReplace", "titleFindInFiles", "titleFindInProjects", "titleMark", "title"):
                    if el.get(k):
                        items.append((el.tag, clean(el.get(k)), ""))
            if el.get("message"):
                items.append((el.tag, clean(el.get("message")), ""))
            if text:
                items.append((el.tag, text, ident or ""))
        seen = set()
        out = []
        for tag, text, ident in items:
            key = (tag, text)
            if key in seen or not text:
                continue
            seen.add(key)
            out.append((tag, text, ident))
        if not out:
            continue
        lines.append(f"## {section.tag} ({len(out)})")
        lines.append("")
        for tag, text, ident in out:
            ref = f" `id {ident}`" if ident else ""
            lines.append(f"- [ ] **{tag}**: {text}{ref}")
            total += 1
        lines.append("")
    lines.insert(8, f"Total de itens: **{total}**. Feitos: **0**. (Atualizado pelo script; marque conforme implementa.)")
    lines.insert(9, "")
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("wrote", OUT, "items:", total)


if __name__ == "__main__":
    main(sys.argv[1])
