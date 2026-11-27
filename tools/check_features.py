#!/usr/bin/env python3
"""Checks every checked item of docs/FULL_PARITY.md against the repository code.

An item stays [x] only if its selector(s) from feature_map.py exist as methods
in app/src and plugins/. Items without a mapping and not proven by an IDM
command id are unchecked, and the script prints them.
"""
import glob, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from feature_map import FEATURES

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
src = ''.join(open(f, encoding='utf-8', errors='ignore').read()
              for f in glob.glob('app/src/*.mm') + glob.glob('app/src/*.h') + glob.glob('plugins/*/*.mm'))
defined = set(re.findall(r'^\s*-\s*\([^)]*\)\s*(\w+)', src, re.M))
wired = set(re.findall(r'IDM_[A-Z0-9_]+', open('app/src/MainWindowController+Npp.mm', encoding='utf-8').read()))

def norm(t):
    t = t.replace('&', '').replace('…', '').replace('...', '')
    t = re.sub(r'\s*`id \d+`.*$', '', t)
    return re.sub(r'\s+', ' ', t).strip().rstrip(':').lower()

path = 'docs/FULL_PARITY.md'
lines = open(path, encoding='utf-8').read().split('\n')
sec = None
kept = unproven = 0
for i, l in enumerate(lines):
    if l.startswith('## '):
        sec = l[3:]
    if not l.startswith('- [x]'):
        continue
    ok = False
    if sec and sec.startswith('Comandos de menu'):
        m = re.search(r'\*\*(IDM_[A-Z0-9_]+)\*\*', l)
        ok = bool(m) and m.group(1) in wired
    else:
        m = re.match(r'- \[x\] \[\w+\] \*\*(.+?)\*\*: (.*)$', l)
        if m:
            sels = FEATURES.get(norm(m.group(2)), [])
            ok = bool(sels) and all(s in defined for s in sels)
    if ok:
        kept += 1
    else:
        unproven += 1
        lines[i] = l.replace('- [x]', '- [ ]', 1)
        print('sem prova no código:', l[:100])
open(path, 'w', encoding='utf-8').write('\n'.join(lines))
print(f'provados pelo nome/seletor: {kept} | sem prova: {unproven}')
