// Unit tests for the portable core library. Runs on macOS and Linux.
// SPDX-License-Identifier: GPL-3.0-or-later
#include <cstdio>
#include <cstring>
#include <functional>
#include <string>
#include <vector>

#include "quill/Diff.h"
#include "quill/Encoding.h"
#include "quill/Json.h"
#include "quill/TextTools.h"

static int failures = 0;
static int checks = 0;

#define CHECK(cond)                                                                 \
	do {                                                                        \
		checks++;                                                           \
		if (!(cond)) {                                                      \
			failures++;                                                 \
			std::fprintf(stderr, "%s:%d: CHECK failed: %s\n", __FILE__, __LINE__, #cond); \
		}                                                                   \
	} while (0)

#define CHECK_EQ(a, b)                                                              \
	do {                                                                        \
		checks++;                                                           \
		auto va = (a);                                                      \
		auto vb = (b);                                                      \
		if (!(va == vb)) {                                                  \
			failures++;                                                 \
			std::fprintf(stderr, "%s:%d: CHECK_EQ failed: %s != %s\n", __FILE__, __LINE__, #a, #b); \
		}                                                                   \
	} while (0)

using namespace quill;

static std::vector<std::string> L(std::initializer_list<const char *> l) {
	std::vector<std::string> v;
	for (auto s : l) v.push_back(s);
	return v;
}

// Applies the blocks to left and checks that the result equals right.
static bool replay(const std::vector<std::string> &a, const std::vector<std::string> &b, const std::vector<DiffBlock> &blocks) {
	std::vector<std::string> out;
	size_t la = 0, lb = 0;
	for (const auto &bl : blocks) {
		if (bl.leftStart != la || bl.rightStart != lb) return false;
		if (bl.kind == DiffKind::Equal) {
			if (bl.leftCount != bl.rightCount) return false;
			for (size_t i = 0; i < bl.leftCount; i++) {
				if (a[la + i] != b[lb + i]) return false;
				out.push_back(a[la + i]);
			}
		} else {
			for (size_t i = 0; i < bl.rightCount; i++) out.push_back(b[lb + i]);
		}
		la += bl.leftCount;
		lb += bl.rightCount;
	}
	return la == a.size() && lb == b.size() && out == b;
}

static void testDiff() {
	auto a = L({"a", "b", "c", "d", "e"});
	auto b = L({"a", "x", "c", "d", "f", "g"});
	auto blocks = diffLines(a, b);
	CHECK(replay(a, b, blocks));
	auto st = diffStats(blocks);
	CHECK_EQ(st.blocks, (size_t)2);
	CHECK_EQ(st.changed, (size_t)2);

	auto same = diffLines(a, a);
	CHECK_EQ(same.size(), (size_t)1);
	CHECK(same[0].kind == DiffKind::Equal);

	auto ins = diffLines(L({"1", "2"}), L({"1", "new", "2"}));
	CHECK(replay(L({"1", "2"}), L({"1", "new", "2"}), ins));
	CHECK_EQ(diffStats(ins).added, (size_t)1);

	auto del = diffLines(L({"1", "2", "3"}), L({"1", "3"}));
	CHECK_EQ(diffStats(del).removed, (size_t)1);

	auto empty = diffLines(L({}), L({"x", "y"}));
	CHECK(replay(L({}), L({"x", "y"}), empty));
	auto empty2 = diffLines(L({"x"}), L({}));
	CHECK(replay(L({"x"}), L({}), empty2));

	DiffOptions ws;
	ws.ignoreWhitespace = true;
	CHECK_EQ(diffStats(diffLines(L({"a  b"}), L({"ab"}), ws)).blocks, (size_t)0);
	DiffOptions ic;
	ic.ignoreCase = true;
	CHECK_EQ(diffStats(diffLines(L({"ABC"}), L({"abc"}), ic)).blocks, (size_t)0);

	// Pseudo random sequences must always replay exactly.
	unsigned seed = 12345;
	auto rnd = [&]() {
		seed = seed * 1103515245u + 12345u;
		return (seed >> 16) & 0x7fff;
	};
	for (int round = 0; round < 300; round++) {
		std::vector<std::string> x, y;
		int nx = rnd() % 40, ny = rnd() % 40;
		for (int i = 0; i < nx; i++) x.push_back(std::string(1, static_cast<char>('a' + rnd() % 5)));
		for (int i = 0; i < ny; i++) y.push_back(std::string(1, static_cast<char>('a' + rnd() % 5)));
		auto r = diffLines(x, y);
		CHECK(replay(x, y, r));
	}

	auto lines = splitLines("a\r\nb\rc\nd");
	CHECK_EQ(lines.size(), (size_t)4);
	CHECK_EQ(splitLines("a\n").size(), (size_t)1);

	std::vector<CharRange> lr, rr;
	diffChars("hello world", "hello there world", lr, rr);
	CHECK(lr.empty());
	CHECK_EQ(rr.size(), (size_t)1);
	diffChars("café", "cafe", lr, rr);
	CHECK_EQ(lr.size(), (size_t)1);
	CHECK_EQ(lr[0].start, (size_t)3);
	CHECK_EQ(lr[0].length, (size_t)2);
}

static void testJson() {
	JsonError err;
	auto v = parseJson("{\"b\": [1, 2.5e3, -0], \"a\": {\"x\": null, \"y\": true}, \"s\": \"h\\u00e9\\n\"}", err);
	CHECK(err.ok);
	CHECK(v != nullptr);
	if (!v) return;
	CHECK_EQ(v->members.size(), (size_t)3);
	CHECK_EQ(v->members[0].first, std::string("b"));
	CHECK_EQ(v->members[2].second->text, std::string("h\xC3\xA9\n"));
	CHECK_EQ(minifyJson(*v), std::string("{\"b\":[1,2.5e3,-0],\"a\":{\"x\":null,\"y\":true},\"s\":\"h\xC3\xA9\\n\"}"));

	JsonFormatOptions o;
	o.indent = 2;
	std::string pretty = formatJson(*v, o);
	CHECK(pretty.find("\n  \"a\": {\n    \"x\": null,") != std::string::npos);
	o.sortKeys = true;
	std::string sorted = formatJson(*v, o);
	CHECK(sorted.find("\"a\"") < sorted.find("\"b\""));

	// Round trip
	JsonError err2;
	auto v2 = parseJson(pretty, err2);
	CHECK(err2.ok);
	CHECK(v2 && minifyJson(*v2) == minifyJson(*v));

	JsonError bad;
	CHECK(parseJson("{\n  \"a\": 1,\n  \"b\" 2\n}", bad) == nullptr);
	CHECK(!bad.ok);
	CHECK_EQ(bad.line, (size_t)3);

	JsonError e3;
	CHECK(parseJson("[1, 2,]", e3) != nullptr);
	JsonParseOptions strict;
	strict.allowTrailingCommas = false;
	strict.allowComments = false;
	JsonError e4;
	CHECK(parseJson("[1, 2,]", e4, strict) == nullptr);
	JsonError e5;
	CHECK(parseJson("// c\n{\"a\": /* x */ 1}", e5) != nullptr);
	JsonError e6;
	CHECK(parseJson("\"\\ud83d\\ude00\"", e6) != nullptr);
	JsonError e7;
	CHECK(parseJson("01", e7) == nullptr);
	JsonError e8;
	CHECK(parseJson("", e8) == nullptr);
	CHECK_EQ(jsonPreview(*v), std::string("{3}"));
}

static void testEncoding() {
	CHECK(detectEncoding("plain ascii") == TextEncoding::UTF8);
	CHECK(detectEncoding("caf\xC3\xA9") == TextEncoding::UTF8);
	CHECK(detectEncoding("caf\xE9") == TextEncoding::Windows1252);
	CHECK(detectEncoding("\xEF\xBB\xBFhi") == TextEncoding::UTF8BOM);
	CHECK(detectEncoding(std::string("\xFF\xFEh\0i\0", 6)) == TextEncoding::UTF16LE);
	CHECK(detectEncoding(std::string("\xFE\xFF\0h\0i", 6)) == TextEncoding::UTF16BE);
	CHECK(detectEncoding(std::string("h\0e\0l\0l\0o\0", 10)) == TextEncoding::UTF16LE);
	CHECK(!isValidUtf8("\xC3"));
	CHECK(!isValidUtf8("\xED\xA0\x80")); // surrogate

	CHECK_EQ(decodeToUtf8("caf\xE9 \x80", TextEncoding::Windows1252), std::string("caf\xC3\xA9 \xE2\x82\xAC"));
	CHECK_EQ(decodeToUtf8(std::string("\xFF\xFE" "h\0\xE9\0", 6), TextEncoding::UTF16LE), std::string("h\xC3\xA9"));
	CHECK_EQ(decodeToUtf8(std::string("\xFE\xFF\xD8\x3D\xDE\x00", 6), TextEncoding::UTF16BE), std::string("\xF0\x9F\x98\x80"));
	CHECK_EQ(encodeFromUtf8("h\xC3\xA9", TextEncoding::UTF16LE), std::string("\xFF\xFEh\0\xE9\0", 6));
	CHECK_EQ(encodeFromUtf8("\xF0\x9F\x98\x80", TextEncoding::UTF16BE), std::string("\xFE\xFF\xD8\x3D\xDE\x00", 6));
	size_t bad = 0;
	CHECK_EQ(encodeFromUtf8("\xE2\x82\xAC\xE6\x97\xA5", TextEncoding::Windows1252, &bad), std::string("\x80?"));
	CHECK_EQ(bad, (size_t)1);
	CHECK_EQ(encodeFromUtf8("x", TextEncoding::UTF8BOM), std::string("\xEF\xBB\xBFx"));
	CHECK_EQ(decodeToUtf8("\x8E", TextEncoding::MacRoman), std::string("\xC3\xA9"));
	CHECK_EQ(encodeFromUtf8("\xC3\xA9", TextEncoding::MacRoman), std::string("\x8E"));

	CHECK(detectLineEnding("a\r\nb\r\nc\n") == LineEnding::CRLF);
	CHECK(detectLineEnding("a\nb") == LineEnding::LF);
	CHECK(detectLineEnding("a\rb\r") == LineEnding::CR);
	CHECK(detectLineEnding("abc") == LineEnding::LF);
	CHECK_EQ(convertLineEndings("a\r\nb\rc\n", LineEnding::CRLF), std::string("a\r\nb\r\nc\r\n"));
	CHECK_EQ(convertLineEndings("a\r\nb\rc\n", LineEnding::LF), std::string("a\nb\nc\n"));
}

static void testTextTools() {
	std::string bytes;
	CHECK(parseHexBytes("48 65 6c 6C 6f", bytes));
	CHECK_EQ(bytes, std::string("Hello"));
	CHECK(parseHexBytes("0x48,0x69", bytes));
	CHECK_EQ(bytes, std::string("Hi"));
	CHECK(!parseHexBytes("4", bytes));
	CHECK(!parseHexBytes("zz", bytes));
	CHECK_EQ(toHex("Hi"), std::string("48 69"));
	std::string line = hexDumpLine("Hello, world!\n", 0);
	CHECK(line.rfind("00000000  48 65 6C 6C 6F", 0) == 0);
	CHECK(line.find("|Hello, world!.|") != std::string::npos);

	auto vars = fileVariables("/Users/me/src/app.test.py");
	CHECK_EQ(vars["FILE_NAME"], std::string("app.test.py"));
	CHECK_EQ(vars["NAME_PART"], std::string("app.test"));
	CHECK_EQ(vars["EXT_PART"], std::string("py"));
	CHECK_EQ(vars["CURRENT_DIRECTORY"], std::string("/Users/me/src"));
	CHECK_EQ(expandVariables("python3 \"$(full_current_path)\" $(UNKNOWN)", vars),
		 std::string("python3 \"/Users/me/src/app.test.py\" $(UNKNOWN)"));
	CHECK_EQ(shellQuote("it's"), std::string("'it'\\''s'"));
	CHECK(!defaultRunCommand("PY").empty());
	CHECK(defaultRunCommand("xyz").empty());

	auto entries = parseDirectoryListing(
		"total 12\n"
		"drwxr-xr-x    2 user     staff        4096 Jan  1 10:00 my folder\n"
		"-rw-r--r--    1 user     staff         123 Feb 10  2023 notes.txt\r\n"
		"lrwxrwxrwx    1 user     staff          11 Mar  3 09:15 link -> target\n"
		"-rw-r--r--    1 ftp      12 Mar  3 09:15 nogroup.txt\n"
		"drwxr-xr-x    2 user     staff        4096 Jan  1 10:00 .\n"
		"01-02-23  10:00AM       <DIR>          Dos Folder\n"
		"01-02-23  10:00AM                 77 dos.txt\n");
	CHECK_EQ(entries.size(), (size_t)6);
	if (entries.size() == 6) {
		CHECK_EQ(entries[0].name, std::string("Dos Folder"));
		CHECK(entries[0].isDirectory);
		CHECK_EQ(entries[1].name, std::string("my folder"));
		CHECK_EQ(entries[2].name, std::string("dos.txt"));
		CHECK_EQ(entries[2].size, 77ull);
		CHECK_EQ(entries[3].name, std::string("link"));
		CHECK(entries[3].isLink);
		CHECK_EQ(entries[4].name, std::string("nogroup.txt"));
		CHECK_EQ(entries[4].size, 12ull);
		CHECK_EQ(entries[5].name, std::string("notes.txt"));
		CHECK_EQ(entries[5].size, 123ull);
	}
	CHECK_EQ(joinRemotePath("/a/", "b"), std::string("/a/b"));
	CHECK_EQ(joinRemotePath("/a", "b"), std::string("/a/b"));
	CHECK_EQ(parentRemotePath("/a/b/"), std::string("/a"));
	CHECK_EQ(parentRemotePath("/a"), std::string("/"));

	CHECK_EQ(sortLines("b\na\nc\n", SortMode::Ascending), std::string("a\nb\nc\n"));
	CHECK_EQ(sortLines("b\r\na\r\nc", SortMode::Descending), std::string("c\r\nb\r\na"));
	CHECK_EQ(sortLines("10\n9\n100", SortMode::Numeric), std::string("9\n10\n100"));
	CHECK_EQ(sortLines("B\na\nb", SortMode::AscendingCaseInsensitive), std::string("a\nB\nb"));
	CHECK_EQ(trimTrailingWhitespace("a  \nb\t\n"), std::string("a\nb\n"));
	CHECK_EQ(removeDuplicateLines("a\nb\na\nc"), std::string("a\nb\nc"));
	CHECK_EQ(removeEmptyLines("a\n\n  \nb\n"), std::string("a\nb\n"));

	std::string html = markdownToHtml("# Title\n\nSome *em* and `code`.\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\n- [x] done\n");
	CHECK(html.find("<h1>Title</h1>") != std::string::npos);
	CHECK(html.find("<em>em</em>") != std::string::npos);
	CHECK(html.find("<table>") != std::string::npos);
	CHECK(html.find("checkbox") != std::string::npos);
}


static void testLineAndCase() {
	CHECK_EQ(trimLeadingWhitespace("  a\n\tb \nc"), std::string("a\nb \nc"));
	CHECK_EQ(trimBothWhitespace("  a  \n\t b\t\n"), std::string("a\nb\n"));
	CHECK_EQ(eolToSpace("a\r\nb\nc"), std::string("a b c"));
	CHECK_EQ(trimBothAndEolToSpace("  a \n\n b  \n"), std::string("a b"));
	CHECK_EQ(removeBlankLines("a\n \t\nb\n\n"), std::string("a\nb\n"));
	CHECK_EQ(sortLinesNumeric("10\n9\nx\n100", NumericSort::Integer, false), std::string("9\n10\n100\nx"));
	CHECK_EQ(sortLinesNumeric("10\n9\n100", NumericSort::Integer, true), std::string("100\n10\n9"));
	CHECK_EQ(sortLinesNumeric("1,5\n1,25\n0,5", NumericSort::DecimalComma, false), std::string("0,5\n1,25\n1,5"));
	CHECK_EQ(sortLinesNumeric("1.5\n1.25\n0.5", NumericSort::DecimalDot, true), std::string("1.5\n1.25\n0.5"));
	CHECK_EQ(sortLinesByLength("ccc\na\nbb", false), std::string("a\nbb\nccc"));
	CHECK_EQ(sortLinesByLength("a\nccc\nbb", true), std::string("ccc\nbb\na"));
	CHECK_EQ(reverseLines("1\n2\n3\n"), std::string("3\n2\n1\n"));
	CHECK_EQ(shuffleLines("a\nb\nc\nd", 7).size(), std::string("a\nb\nc\nd").size());
	CHECK_EQ(removeConsecutiveDuplicateLines("a\na\nb\na"), std::string("a\nb\na"));
	CHECK_EQ(properCase("hello WORLD foo-bar", false), std::string("Hello World Foo-Bar"));
	CHECK_EQ(properCase("hello WORLD", true), std::string("Hello WORLD"));
	CHECK_EQ(sentenceCase("hello WORLD. this is it! ok?", false), std::string("Hello world. This is it! Ok?"));
	CHECK_EQ(sentenceCase("hello WORLD. this", true), std::string("Hello WORLD. This"));
	CHECK(randomCase("abc", 1) != "" && randomCase("abc", 1).size() == 3);
	CHECK_EQ(randomCase("ab 1", 3).substr(2, 2), std::string(" 1"));
}

int main() {
	testDiff();
	testJson();
	testEncoding();
	testTextTools();
	testLineAndCase();
	std::printf("%d checks, %d failures\n", checks, failures);
	return failures == 0 ? 0 : 1;
}
