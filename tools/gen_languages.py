#!/usr/bin/env python3
"""Generates app/resources/languages.json from the Notepad++ language models.

Inputs (GPL, from the Notepad++ project):
  tools/npp-data/langs.model.xml    keywords, extensions, comment tokens
  tools/npp-data/stylers.model.xml  style ids of every lexer

Run:  python3 tools/gen_languages.py
"""
import json
import os
import re
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "tools", "npp-data")
OUT = os.path.join(ROOT, "app", "resources", "languages.json")
LEXERS_DIR = os.path.join(ROOT, "third_party", "lexilla", "lexers")

# name, display name, LangType value (Notepad++ enum order), Lexilla lexer
LANGS = [
    ("normal", "Normal text", 0, "null"), ("php", "PHP", 1, "phpscript"), ("c", "C", 2, "cpp"),
    ("cpp", "C++", 3, "cpp"), ("cs", "C#", 4, "cpp"), ("objc", "Objective-C", 5, "cpp"),
    ("java", "Java", 6, "cpp"), ("rc", "RC", 7, "cpp"), ("html", "HTML", 8, "hypertext"),
    ("xml", "XML", 9, "xml"), ("makefile", "Makefile", 10, "makefile"), ("pascal", "Pascal", 11, "pascal"),
    ("batch", "Batch", 12, "batch"), ("ini", "INI", 13, "props"), ("nfo", "NFO", 14, "null"),
    ("asp", "ASP", 16, "hypertext"), ("sql", "SQL", 17, "sql"), ("vb", "Visual Basic", 18, "vb"),
    ("css", "CSS", 20, "css"), ("perl", "Perl", 21, "perl"), ("python", "Python", 22, "python"),
    ("lua", "Lua", 23, "lua"), ("tex", "TeX", 24, "tex"), ("fortran", "Fortran (free form)", 25, "fortran"),
    ("bash", "Shell", 26, "bash"), ("actionscript", "ActionScript", 27, "cpp"), ("nsis", "NSIS", 28, "nsis"),
    ("tcl", "Tcl", 29, "tcl"), ("lisp", "Lisp", 30, "lisp"), ("scheme", "Scheme", 31, "lisp"),
    ("asm", "Assembly", 32, "asm"), ("diff", "Diff", 33, "diff"), ("props", "Properties", 34, "props"),
    ("postscript", "PostScript", 35, "ps"), ("ruby", "Ruby", 36, "ruby"), ("smalltalk", "Smalltalk", 37, "smalltalk"),
    ("vhdl", "VHDL", 38, "vhdl"), ("kix", "KiXtart", 39, "kix"), ("autoit", "AutoIt", 40, "au3"),
    ("caml", "CAML", 41, "caml"), ("ada", "Ada", 42, "ada"), ("verilog", "Verilog", 43, "verilog"),
    ("matlab", "MATLAB", 44, "matlab"), ("haskell", "Haskell", 45, "haskell"), ("inno", "Inno Setup", 46, "inno"),
    ("cmake", "CMake", 48, "cmake"), ("yaml", "YAML", 49, "yaml"), ("cobol", "COBOL", 50, "COBOL"),
    ("gui4cli", "Gui4Cli", 51, "gui4cli"), ("d", "D", 52, "d"), ("powershell", "PowerShell", 53, "powershell"),
    ("r", "R", 54, "r"), ("jsp", "JSP", 55, "hypertext"), ("coffeescript", "CoffeeScript", 56, "coffeescript"),
    ("json", "JSON", 57, "json"), ("javascript.js", "JavaScript", 58, "cpp"), ("fortran77", "Fortran (fixed form)", 59, "f77"),
    ("baanc", "BaanC", 60, "baan"), ("srec", "S-Record", 61, "srec"), ("ihex", "Intel HEX", 62, "ihex"),
    ("tehex", "Tektronix HEX", 63, "tehex"), ("swift", "Swift", 64, "cpp"), ("asn1", "ASN.1", 65, "asn1"),
    ("avs", "AviSynth", 66, "avs"), ("blitzbasic", "BlitzBasic", 67, "blitzbasic"), ("purebasic", "PureBasic", 68, "purebasic"),
    ("freebasic", "FreeBasic", 69, "freebasic"), ("csound", "Csound", 70, "csound"), ("erlang", "Erlang", 71, "erlang"),
    ("escript", "ESCRIPT", 72, "escript"), ("forth", "Forth", 73, "forth"), ("latex", "LaTeX", 74, "latex"),
    ("mmixal", "MMIXAL", 75, "mmixal"), ("nim", "Nim", 76, "nimrod"), ("nncrontab", "Crontab", 77, "nncrontab"),
    ("oscript", "OScript", 78, "oscript"), ("rebol", "REBOL", 79, "rebol"), ("registry", "Registry", 80, "registry"),
    ("rust", "Rust", 81, "rust"), ("spice", "Spice", 82, "spice"), ("txt2tags", "txt2tags", 83, "txt2tags"),
    ("visualprolog", "Visual Prolog", 84, "visualprolog"), ("typescript", "TypeScript", 85, "cpp"),
    ("json5", "JSON5", 86, "json"), ("mssql", "Transact-SQL", 87, "mssql"), ("gdscript", "GDScript", 88, "gdscript"),
    ("hollywood", "Hollywood", 89, "hollywood"), ("go", "Go", 90, "cpp"), ("raku", "Raku", 91, "raku"),
    ("toml", "TOML", 92, "toml"), ("sas", "SAS", 93, "sas"), ("errorlist", "Error List", 94, "errorlist"),
    ("fcST", "Structured Text", 96, "fcST"),
]

# Languages Notepad++ does not ship but Lexilla supports. LangType 15 = L_USER.
EXTRA = [
    {
        "name": "markdown", "display": "Markdown", "langType": 15, "lexer": "markdown",
        "ext": ["md", "markdown", "mdown", "mkd", "mkdn", "mdx"],
        "commentStart": "<!--", "commentEnd": "-->", "keywords": {},
        "styles": [[1, "default"], [2, "string"], [3, "keyword"], [4, "keyword"], [5, "string"], [6, "keyword"],
                   [7, "keyword"], [8, "keyword"], [9, "keyword"], [10, "keyword"], [11, "keyword"], [12, "operator"],
                   [13, "operator"], [14, "operator"], [15, "comment"], [16, "operator"], [17, "string"], [18, "attribute"],
                   [19, "preprocessor"], [20, "preprocessor"], [21, "preprocessor"]],
        "bold": [6, 7, 8, 9, 10, 11, 2, 3], "italic": [4, 5],
    },
    {
        "name": "kotlin", "display": "Kotlin", "langType": 15, "lexer": "cpp",
        "ext": ["kt", "kts"], "commentLine": "//", "commentStart": "/*", "commentEnd": "*/",
        "keywords": {"0": "as break class continue do else false for fun if in interface is null object package return super this throw true try typealias typeof val var when while by catch constructor delegate dynamic field file finally get import init param property receiver set setparam where actual abstract annotation companion const crossinline data enum expect external final infix inline inner internal lateinit noinline open operator out override private protected public reified sealed suspend tailrec vararg",
                     "1": "Any Unit String Int Long Short Byte Double Float Boolean Char Array List MutableList Map MutableMap Set MutableSet Nothing Sequence Pair Triple"},
        "styles": "cpp",
    },
    {
        "name": "dockerfile", "display": "Dockerfile", "langType": 15, "lexer": "bash",
        "ext": ["dockerfile", "containerfile"], "filenames": ["Dockerfile", "Containerfile"], "commentLine": "#",
        "keywords": {"0": "FROM RUN CMD LABEL MAINTAINER EXPOSE ENV ADD COPY ENTRYPOINT VOLUME USER WORKDIR ARG ONBUILD STOPSIGNAL HEALTHCHECK SHELL AS from run cmd label expose env add copy entrypoint volume user workdir arg onbuild stopsignal healthcheck shell as"},
        "styles": "bash",
    },
    {
        "name": "julia", "display": "Julia", "langType": 15, "lexer": "julia",
        "ext": ["jl"], "commentLine": "#", "commentStart": "#=", "commentEnd": "=#",
        "keywords": {"0": "baremodule begin break catch const continue do else elseif end export finally for function global if import let local macro module quote return struct try using while abstract mutable primitive type where in isa true false nothing missing"},
        "styles": [[1, "comment"], [2, "number"], [3, "keyword"], [4, "type"], [5, "keyword"], [6, "keyword"], [7, "operator"],
                   [8, "operator"], [9, "default"], [10, "string"], [11, "string"], [12, "string"], [13, "string"], [14, "string"],
                   [15, "preprocessor"], [16, "string"], [17, "string"], [18, "type"], [19, "error"]],
    },
    {
        "name": "fsharp", "display": "F#", "langType": 15, "lexer": "fsharp",
        "ext": ["fs", "fsi", "fsx"], "commentLine": "//", "commentStart": "(*", "commentEnd": "*)",
        "keywords": {"0": "abstract and as assert base begin class default delegate do done downcast downto elif else end exception extern false finally fixed for fun function global if in inherit inline interface internal lazy let match member module mutable namespace new not null of open or override private public rec return select sig static struct then to true try type upcast use val void when while with yield"},
        "styles": [[1, "keyword"], [2, "keyword"], [3, "keyword"], [4, "keyword"], [5, "keyword"], [6, "default"], [7, "default"],
                   [8, "comment"], [9, "comment"], [10, "preprocessor"], [11, "number"], [12, "operator"], [13, "string"],
                   [14, "string"], [15, "string"], [16, "string"], [17, "string"], [18, "string"]],
    },
]

INDEX = {"instre1": 0, "instre2": 1, "type1": 2, "type2": 3, "type3": 4, "type4": 5, "type5": 6, "type6": 7, "type7": 8}


def lexilla_names():
    names = set()
    for fn in os.listdir(LEXERS_DIR):
        with open(os.path.join(LEXERS_DIR, fn), encoding="utf-8", errors="replace") as f:
            for m in re.finditer(r'LexerModule\s+\w+\s*\([^;]*?"([^"]+)"', f.read()):
                names.add(m.group(1))
    return names


def token_for(style_name, keyword_class):
    n = style_name.upper()
    if "COMMENT" in n:
        return "commentDoc" if "DOC" in n else "comment"
    if "ERROR" in n or n.startswith("BAD"):
        return "error"
    if "DELETED" in n or n == "REMOVED":
        return "deleted"
    if "ADDED" in n:
        return "added"
    if n in ("POSITION", "CHANGED", "COMMAND"):
        return "changed"
    if "NUMBER" in n or "NUMERIC" in n or n == "HEX" or "INTEGER" in n or "FLOAT" in n:
        return "number"
    if "REGEX" in n:
        return "regex"
    if any(k in n for k in ("STRING", "CHARACTER", "CHAR ", "VERBATIM", "HEREDOC", "TRIPLE", "BACKTICK", "QUOTE", "CDATA")) or n == "CHAR":
        return "string"
    if any(k in n for k in ("PREPROCESSOR", "DIRECTIVE", "PRAGMA", "MACRO", "DEFINE", "PREPROC")):
        return "preprocessor"
    if keyword_class and keyword_class.startswith("type"):
        return "type"
    if keyword_class and keyword_class.startswith("instre"):
        return "keyword" if keyword_class == "instre1" else "keyword2"
    if "TAG" in n:
        return "tag"
    if "ATTRIBUTE" in n or n.startswith("ATTR"):
        return "attribute"
    if "ENTITY" in n:
        return "entity"
    if "PROPERTY" in n or n == "KEY":
        return "attribute"
    if "OPERATOR" in n or "DELIMITER" in n or "PUNCTUATION" in n or "BRACE" in n or n == "SYMBOL":
        return "operator"
    if "CLASS" in n or "TYPE" in n:
        return "type"
    if "FUNCTION" in n or "METHOD" in n or "DEFNAME" in n or "DEF NAME" in n:
        return "function"
    if "KEYWORD" in n or "INSTRUCTION" in n or n == "WORD" or "WORD" in n:
        return "keyword"
    if "SECTION" in n or "HEADER" in n or n == "KEY":
        return "keyword2"
    if "LABEL" in n:
        return "label"
    if "VARIABLE" in n or "PARAM" in n:
        return "variable"
    return "default"


def main():
    known = lexilla_names()
    langs_xml = ET.parse(os.path.join(DATA, "langs.model.xml")).getroot()
    stylers_xml = ET.parse(os.path.join(DATA, "stylers.model.xml")).getroot()

    lang_nodes = {n.get("name"): n for n in langs_xml.iter("Language")}
    lexer_nodes = {n.get("name"): n for n in stylers_xml.iter("LexerType")}

    out = []
    style_cache = {}
    for name, display, lang_type, lexer in LANGS:
        if lexer not in known and lexer != "null":
            print("warning: lexer %s for %s not in Lexilla, using null" % (lexer, name))
            lexer = "null"
        node = lang_nodes.get(name)
        entry = {"name": name, "display": display, "langType": lang_type, "lexer": lexer,
                 "ext": [], "keywords": {}, "styles": [], "bold": [], "italic": []}
        if node is not None:
            entry["ext"] = [e for e in (node.get("ext") or "").split() if e]
            for attr in ("commentLine", "commentStart", "commentEnd"):
                if node.get(attr):
                    entry[attr] = node.get(attr)
            words = {}
            for kw in node.iter("Keywords"):
                cls = kw.get("name")
                text = " ".join((kw.text or "").split())
                if text and cls in INDEX:
                    words[cls] = text
            if lexer == "cpp":
                mapping = {"instre1": 0, "type1": 1, "type2": 2, "instre2": 3}
            elif lexer == "xml":
                mapping = {"instre1": 5}
            elif lexer in ("hypertext", "phpscript"):
                mapping = {"instre1": 0, "instre2": 5}
            else:
                mapping = INDEX
            for cls, text in words.items():
                if cls in mapping:
                    entry["keywords"][str(mapping[cls])] = text
            if lexer in ("hypertext", "phpscript"):
                # Embedded scripts get the keywords of their own languages.
                emb = {"1": "javascript", "2": "vb", "3": "python", "4": "php"}
                for idx, lname in emb.items():
                    n2 = lang_nodes.get(lname)
                    if n2 is not None:
                        for kw in n2.iter("Keywords"):
                            if kw.get("name") == "instre1" and kw.text:
                                entry["keywords"][idx] = " ".join(kw.text.split())
            if name == "javascript.js" or name == "typescript":
                entry["keywords"].setdefault("2", " ".join((lang_nodes["cpp"].find("Keywords[@name='type2']").text or "").split()))
        styler_name = {"javascript.js": "javascript.js"}.get(name, name)
        sty = lexer_nodes.get(styler_name)
        if sty is not None:
            for ws in sty.iter("WordsStyle"):
                sid = int(ws.get("styleID"))
                if sid in (32, 33, 34, 35, 36, 37, 38, 39):
                    continue
                tok = token_for(ws.get("name") or "", ws.get("keywordClass"))
                entry["styles"].append([sid, tok])
                fs = int(ws.get("fontStyle") or 0)
                if fs & 2 and tok in ("comment", "commentDoc"):
                    entry["italic"].append(sid)
        style_cache[name] = entry["styles"]
        if name in ("nfo", "normal"):
            entry["styles"] = []
        out.append(entry)

    for extra in EXTRA:
        e = dict(extra)
        if isinstance(e.get("styles"), str):
            e["styles"] = style_cache[e["styles"]]
        e.setdefault("bold", [])
        e.setdefault("italic", [])
        out.append(e)

    # File name based detection (no extension)
    filenames = {
        "makefile": ["Makefile", "makefile", "GNUmakefile"],
        "cmake": ["CMakeLists.txt"],
        "ruby": ["Gemfile", "Rakefile", "Podfile", "Fastfile", "Brewfile"],
        "bash": [".bashrc", ".bash_profile", ".zshrc", ".zprofile", ".profile", ".zshenv"],
        "props": [".gitconfig", ".editorconfig", ".npmrc"],
        "python": ["SConstruct", "SConscript"],
    }
    for e in out:
        if e["name"] in filenames:
            e["filenames"] = filenames[e["name"]]
        if e["name"] == "bash":
            e["ext"] = sorted(set(e["ext"] + ["zsh", "command", "tool"]))
        if e["name"] == "props":
            e["ext"] = sorted(set(e["ext"] + ["gitignore", "gitattributes", "env", "conf"]))
        if e["name"] == "xml":
            e["ext"] = sorted(set(e["ext"] + ["plist", "svg", "xib", "storyboard", "entitlements", "csproj", "resx"]))
        if e["name"] == "objc":
            e["ext"] = sorted(set(e["ext"] + ["m", "mm"]))
        if e["name"] == "javascript.js":
            e["ext"] = sorted(set(e["ext"] + ["mjs", "cjs", "jsx"]))
        if e["name"] == "typescript":
            e["ext"] = sorted(set(e["ext"] + ["tsx", "mts", "cts"]))

    # Objective-C claims ".h" too in Notepad++; leave .h to C++.
    for e in out:
        if e["name"] == "objc":
            e["ext"] = [x for x in e["ext"] if x != "h"]

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1, sort_keys=True)
    print("wrote %d languages to %s" % (len(out), OUT))


if __name__ == "__main__":
    main()
