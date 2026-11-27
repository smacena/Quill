// SPDX-License-Identifier: GPL-3.0-or-later
#include "quill/TextTools.h"

#include <algorithm>
#include <random>
#include <cstdlib>
#include <cstdint>
#include <cctype>
#include <cstdio>
#include <cstdlib>
#include <set>
#include <sstream>

extern "C" {
#include "md4c-html.h"
}

namespace quill {

// ---- Hex --------------------------------------------------------------------

std::string hexDumpLine(const std::string &bytes, size_t offset, size_t perLine) {
	char buf[32];
	std::string line;
	snprintf(buf, sizeof(buf), "%08zX  ", offset);
	line += buf;
	std::string ascii;
	for (size_t i = 0; i < perLine; i++) {
		size_t k = offset + i;
		if (k < bytes.size()) {
			unsigned char c = static_cast<unsigned char>(bytes[k]);
			snprintf(buf, sizeof(buf), "%02X ", c);
			line += buf;
			ascii.push_back(c >= 0x20 && c < 0x7F ? static_cast<char>(c) : '.');
		} else {
			line += "   ";
		}
		if (i == 7) line.push_back(' ');
	}
	line += " |" + ascii + "|";
	return line;
}

std::string hexDump(const std::string &bytes, size_t perLine) {
	std::string out;
	for (size_t off = 0; off < bytes.size(); off += perLine) {
		out += hexDumpLine(bytes, off, perLine);
		out.push_back('\n');
	}
	return out;
}

bool parseHexBytes(const std::string &text, std::string &out) {
	out.clear();
	std::string digits;
	for (size_t i = 0; i < text.size(); i++) {
		char c = text[i];
		if (c == '0' && i + 1 < text.size() && (text[i + 1] == 'x' || text[i + 1] == 'X')) {
			i++;
			continue;
		}
		if (isxdigit(static_cast<unsigned char>(c)))
			digits.push_back(c);
		else if (c == ' ' || c == ',' || c == '\t' || c == '\n' || c == '\r' || c == ';')
			continue;
		else
			return false;
	}
	if (digits.size() % 2) return false;
	for (size_t i = 0; i < digits.size(); i += 2)
		out.push_back(static_cast<char>(std::strtol(digits.substr(i, 2).c_str(), nullptr, 16)));
	return true;
}

std::string toHex(const std::string &bytes, bool spaced, bool upper) {
	std::string out;
	char buf[4];
	for (size_t i = 0; i < bytes.size(); i++) {
		snprintf(buf, sizeof(buf), upper ? "%02X" : "%02x", static_cast<unsigned char>(bytes[i]));
		if (spaced && i) out.push_back(' ');
		out += buf;
	}
	return out;
}

// ---- Variables ----------------------------------------------------------------

namespace {
std::string upper(std::string s) {
	for (auto &c : s) c = static_cast<char>(std::toupper(static_cast<unsigned char>(c)));
	return s;
}
std::string lower(std::string s) {
	for (auto &c : s) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
	return s;
}
} // namespace

std::string expandVariables(const std::string &command, const std::map<std::string, std::string> &vars) {
	std::map<std::string, std::string> uv;
	for (const auto &kv : vars) uv[upper(kv.first)] = kv.second;
	std::string out;
	size_t i = 0;
	while (i < command.size()) {
		if (command[i] == '$' && i + 1 < command.size() && command[i + 1] == '(') {
			size_t end = command.find(')', i + 2);
			if (end != std::string::npos) {
				std::string name = upper(command.substr(i + 2, end - i - 2));
				auto it = uv.find(name);
				if (it != uv.end()) {
					out += it->second;
					i = end + 1;
					continue;
				}
				if (name.rfind("SYS.", 0) == 0) {
					const char *env = getenv(command.substr(i + 6, end - i - 6).c_str());
					out += env ? env : "";
					i = end + 1;
					continue;
				}
			}
		}
		out.push_back(command[i]);
		i++;
	}
	return out;
}

std::string shellQuote(const std::string &s) {
	std::string out = "'";
	for (char c : s) {
		if (c == '\'')
			out += "'\\''";
		else
			out.push_back(c);
	}
	out.push_back('\'');
	return out;
}

std::map<std::string, std::string> fileVariables(const std::string &fullPath) {
	std::map<std::string, std::string> v;
	v["FULL_CURRENT_PATH"] = fullPath;
	size_t slash = fullPath.find_last_of('/');
	std::string dir = slash == std::string::npos ? std::string() : fullPath.substr(0, slash);
	std::string file = slash == std::string::npos ? fullPath : fullPath.substr(slash + 1);
	size_t dot = file.find_last_of('.');
	std::string name = (dot == std::string::npos || dot == 0) ? file : file.substr(0, dot);
	std::string ext = (dot == std::string::npos || dot == 0) ? std::string() : file.substr(dot + 1);
	v["CURRENT_DIRECTORY"] = dir;
	v["FILE_NAME"] = file;
	v["NAME_PART"] = name;
	v["EXT_PART"] = ext;
	return v;
}

std::string defaultRunCommand(const std::string &extension) {
	static const std::map<std::string, std::string> runners = {
		{"py", "python3 \"$(FULL_CURRENT_PATH)\""},
		{"js", "node \"$(FULL_CURRENT_PATH)\""},
		{"mjs", "node \"$(FULL_CURRENT_PATH)\""},
		{"ts", "npx --yes tsx \"$(FULL_CURRENT_PATH)\""},
		{"rb", "ruby \"$(FULL_CURRENT_PATH)\""},
		{"pl", "perl \"$(FULL_CURRENT_PATH)\""},
		{"php", "php \"$(FULL_CURRENT_PATH)\""},
		{"lua", "lua \"$(FULL_CURRENT_PATH)\""},
		{"sh", "bash \"$(FULL_CURRENT_PATH)\""},
		{"bash", "bash \"$(FULL_CURRENT_PATH)\""},
		{"zsh", "zsh \"$(FULL_CURRENT_PATH)\""},
		{"swift", "swift \"$(FULL_CURRENT_PATH)\""},
		{"go", "go run \"$(FULL_CURRENT_PATH)\""},
		{"rs", "cd \"$(CURRENT_DIRECTORY)\" && rustc -o /tmp/\"$(NAME_PART)\" \"$(FILE_NAME)\" && /tmp/\"$(NAME_PART)\""},
		{"c", "cd \"$(CURRENT_DIRECTORY)\" && clang -o /tmp/\"$(NAME_PART)\" \"$(FILE_NAME)\" && /tmp/\"$(NAME_PART)\""},
		{"cpp", "cd \"$(CURRENT_DIRECTORY)\" && clang++ -std=c++17 -o /tmp/\"$(NAME_PART)\" \"$(FILE_NAME)\" && /tmp/\"$(NAME_PART)\""},
		{"cc", "cd \"$(CURRENT_DIRECTORY)\" && clang++ -std=c++17 -o /tmp/\"$(NAME_PART)\" \"$(FILE_NAME)\" && /tmp/\"$(NAME_PART)\""},
		{"m", "cd \"$(CURRENT_DIRECTORY)\" && clang -framework Foundation -o /tmp/\"$(NAME_PART)\" \"$(FILE_NAME)\" && /tmp/\"$(NAME_PART)\""},
		{"java", "cd \"$(CURRENT_DIRECTORY)\" && java \"$(FILE_NAME)\""},
		{"r", "Rscript \"$(FULL_CURRENT_PATH)\""},
		{"applescript", "osascript \"$(FULL_CURRENT_PATH)\""},
		{"scpt", "osascript \"$(FULL_CURRENT_PATH)\""},
		{"html", "open \"$(FULL_CURRENT_PATH)\""},
		{"htm", "open \"$(FULL_CURRENT_PATH)\""},
		{"md", "open \"$(FULL_CURRENT_PATH)\""},
	};
	auto it = runners.find(lower(extension));
	return it == runners.end() ? std::string() : it->second;
}

// ---- Remote listings -------------------------------------------------------------

std::vector<RemoteEntry> parseDirectoryListing(const std::string &listing) {
	std::vector<RemoteEntry> out;
	std::istringstream in(listing);
	std::string line;
	while (std::getline(in, line)) {
		if (!line.empty() && line.back() == '\r') line.pop_back();
		if (line.empty()) continue;
		if (line.rfind("total ", 0) == 0) continue;
		if (line.rfind("sftp>", 0) == 0) continue;
		RemoteEntry e;
		char first = line[0];
		if (first == 'd' || first == '-' || first == 'l' || first == 'c' || first == 'b' || first == 'p' || first == 's') {
			// perms links owner [group] size month day time/year name...
			// Tokenize remembering offsets so names with spaces survive.
			std::vector<std::pair<size_t, std::string>> tok;
			size_t q = 0;
			while (q < line.size() && tok.size() < 12) {
				while (q < line.size() && line[q] == ' ') q++;
				if (q >= line.size()) break;
				size_t st = q;
				while (q < line.size() && line[q] != ' ') q++;
				tok.emplace_back(st, line.substr(st, q - st));
			}
			static const char *months[] = {"jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"};
			int monthIdx = -1;
			for (size_t k = 3; k < tok.size(); k++) {
				std::string m = lower(tok[k].second);
				bool isMonth = false;
				for (const char *mn : months)
					if (m == mn) isMonth = true;
				if (isMonth && k + 2 < tok.size()) {
					monthIdx = static_cast<int>(k);
					break;
				}
			}
			if (monthIdx < 0 || monthIdx + 3 > static_cast<int>(tok.size())) continue;
			size_t mi = static_cast<size_t>(monthIdx);
			size_t nameStart = mi + 3 < tok.size() ? tok[mi + 3].first : std::string::npos;
			if (nameStart == std::string::npos) continue;
			std::string name = line.substr(nameStart);
			e.permissions = tok[0].second;
			e.isDirectory = first == 'd';
			e.isLink = first == 'l';
			if (e.isLink) {
				size_t arrow = name.find(" -> ");
				if (arrow != std::string::npos) name = name.substr(0, arrow);
			}
			e.size = std::strtoull(tok[mi - 1].second.c_str(), nullptr, 10);
			e.modified = tok[mi].second + " " + tok[mi + 1].second + " " + tok[mi + 2].second;
			e.name = name;
		} else if (isdigit(static_cast<unsigned char>(first))) {
			// MS-DOS: 01-02-23  10:00AM       <DIR>          folder
			std::istringstream ls(line);
			std::string date, time, sizeOrDir;
			if (!(ls >> date >> time >> sizeOrDir)) continue;
			std::string name;
			std::getline(ls, name);
			size_t p = name.find_first_not_of(' ');
			name = p == std::string::npos ? std::string() : name.substr(p);
			if (name.empty()) continue;
			e.isDirectory = sizeOrDir == "<DIR>";
			if (!e.isDirectory) e.size = std::strtoull(sizeOrDir.c_str(), nullptr, 10);
			e.modified = date + " " + time;
			e.name = name;
		} else {
			continue;
		}
		if (e.name == "." || e.name == "..") continue;
		out.push_back(e);
	}
	std::stable_sort(out.begin(), out.end(), [](const RemoteEntry &a, const RemoteEntry &b) {
		if (a.isDirectory != b.isDirectory) return a.isDirectory;
		return lower(a.name) < lower(b.name);
	});
	return out;
}

std::string joinRemotePath(const std::string &dir, const std::string &name) {
	if (dir.empty()) return name.empty() || name[0] == '/' ? name : "/" + name;
	if (name.empty()) return dir;
	if (dir.back() == '/') return dir + (name[0] == '/' ? name.substr(1) : name);
	return dir + (name[0] == '/' ? name : "/" + name);
}

std::string parentRemotePath(const std::string &path) {
	if (path.empty() || path == "/") return "/";
	std::string p = path;
	while (p.size() > 1 && p.back() == '/') p.pop_back();
	size_t slash = p.find_last_of('/');
	if (slash == std::string::npos) return "/";
	if (slash == 0) return "/";
	return p.substr(0, slash);
}

// ---- Lines ----------------------------------------------------------------------

namespace {
struct SplitText {
	std::vector<std::string> lines;
	std::string eol = "\n";
	bool trailingEol = false;
};

SplitText split(const std::string &text) {
	SplitText st;
	if (text.find("\r\n") != std::string::npos) st.eol = "\r\n";
	else if (text.find('\r') != std::string::npos && text.find('\n') == std::string::npos) st.eol = "\r";
	std::string cur;
	for (size_t i = 0; i < text.size(); i++) {
		char c = text[i];
		if (c == '\r' || c == '\n') {
			if (c == '\r' && i + 1 < text.size() && text[i + 1] == '\n') i++;
			st.lines.push_back(cur);
			cur.clear();
		} else {
			cur.push_back(c);
		}
	}
	st.trailingEol = !text.empty() && (text.back() == '\n' || text.back() == '\r');
	if (!st.trailingEol) st.lines.push_back(cur);
	return st;
}

std::string join(const SplitText &st) {
	std::string out;
	for (size_t i = 0; i < st.lines.size(); i++) {
		out += st.lines[i];
		if (i + 1 < st.lines.size() || st.trailingEol) out += st.eol;
	}
	return out;
}
} // namespace

std::string sortLines(const std::string &text, SortMode mode, bool removeDuplicates) {
	SplitText st = split(text);
	auto &l = st.lines;
	switch (mode) {
	case SortMode::Ascending: std::stable_sort(l.begin(), l.end()); break;
	case SortMode::Descending: std::stable_sort(l.begin(), l.end(), std::greater<std::string>()); break;
	case SortMode::AscendingCaseInsensitive:
		std::stable_sort(l.begin(), l.end(), [](const std::string &a, const std::string &b) { return lower(a) < lower(b); });
		break;
	case SortMode::Numeric:
		std::stable_sort(l.begin(), l.end(), [](const std::string &a, const std::string &b) {
			return std::strtod(a.c_str(), nullptr) < std::strtod(b.c_str(), nullptr);
		});
		break;
	}
	if (removeDuplicates) l.erase(std::unique(l.begin(), l.end()), l.end());
	return join(st);
}

std::string trimTrailingWhitespace(const std::string &text) {
	SplitText st = split(text);
	for (auto &line : st.lines) {
		size_t end = line.find_last_not_of(" \t");
		line = end == std::string::npos ? std::string() : line.substr(0, end + 1);
	}
	return join(st);
}

std::string removeDuplicateLines(const std::string &text) {
	SplitText st = split(text);
	std::set<std::string> seen;
	std::vector<std::string> kept;
	for (auto &line : st.lines)
		if (seen.insert(line).second) kept.push_back(line);
	st.lines = kept;
	return join(st);
}

std::string removeEmptyLines(const std::string &text) {
	SplitText st = split(text);
	std::vector<std::string> kept;
	for (auto &line : st.lines)
		if (line.find_first_not_of(" \t") != std::string::npos) kept.push_back(line);
	st.lines = kept;
	return join(st);
}

// ---- Markdown --------------------------------------------------------------------

namespace {
void mdOutput(const MD_CHAR *text, MD_SIZE size, void *userdata) {
	static_cast<std::string *>(userdata)->append(text, size);
}
} // namespace

std::string markdownToHtml(const std::string &markdown) {
	std::string html;
	html.reserve(markdown.size() * 2);
	unsigned parserFlags = MD_DIALECT_GITHUB;
	md_html(markdown.data(), static_cast<MD_SIZE>(markdown.size()), mdOutput, &html, parserFlags, 0);
	return html;
}

} // namespace quill

namespace quill {

namespace {
bool isBlank(char c) {
	return c == ' ' || c == '\t' || c == '\r' || c == '\n' || c == '\v' || c == '\f';
}
std::string ltrim(const std::string &s) {
	size_t b = s.find_first_not_of(" \t");
	return b == std::string::npos ? std::string() : s.substr(b);
}
std::string rtrim(const std::string &s) {
	size_t e = s.find_last_not_of(" \t");
	return e == std::string::npos ? std::string() : s.substr(0, e + 1);
}
// Parses a number following the chosen decimal convention. Returns false if not a number.
bool parseNumber(const std::string &line, NumericSort kind, double &out) {
	std::string s = ltrim(rtrim(line));
	if (s.empty()) return false;
	if (kind == NumericSort::DecimalComma) {
		for (auto &c : s)
			if (c == ',') c = '.';
	}
	char *end = nullptr;
	if (kind == NumericSort::Integer) {
		long long v = std::strtoll(s.c_str(), &end, 10);
		if (end == s.c_str() || *end != '\0') return false;
		out = static_cast<double>(v);
		return true;
	}
	out = std::strtod(s.c_str(), &end);
	return end != s.c_str() && *end == '\0';
}
bool isWordChar(char c) {
	return std::isalnum(static_cast<unsigned char>(c)) || c == '_' || (static_cast<unsigned char>(c) & 0x80);
}
} // namespace

std::string trimLeadingWhitespace(const std::string &text) {
	SplitText st = split(text);
	for (auto &line : st.lines) line = ltrim(line);
	return join(st);
}

std::string trimBothWhitespace(const std::string &text) {
	SplitText st = split(text);
	for (auto &line : st.lines) line = ltrim(rtrim(line));
	return join(st);
}

std::string eolToSpace(const std::string &text) {
	std::string out;
	out.reserve(text.size());
	for (size_t i = 0; i < text.size(); i++) {
		if (text[i] == '\r' || text[i] == '\n') {
			if (text[i] == '\r' && i + 1 < text.size() && text[i + 1] == '\n') i++;
			out.push_back(' ');
		} else {
			out.push_back(text[i]);
		}
	}
	return out;
}

std::string trimBothAndEolToSpace(const std::string &text) {
	SplitText st = split(text);
	std::string out;
	for (auto &line : st.lines) {
		std::string t = ltrim(rtrim(line));
		if (t.empty()) continue;
		if (!out.empty()) out += ' ';
		out += t;
	}
	return out;
}

std::string removeBlankLines(const std::string &text) {
	SplitText st = split(text);
	std::vector<std::string> kept;
	for (auto &line : st.lines) {
		bool blank = std::all_of(line.begin(), line.end(), isBlank);
		if (!blank) kept.push_back(line);
	}
	st.lines = kept;
	return join(st);
}

std::string sortLinesNumeric(const std::string &text, NumericSort kind, bool descending) {
	SplitText st = split(text);
	std::vector<std::pair<double, std::string>> numbered;
	std::vector<std::string> others;
	for (auto &line : st.lines) {
		double v;
		if (parseNumber(line, kind, v)) numbered.emplace_back(v, line);
		else others.push_back(line);
	}
	std::stable_sort(numbered.begin(), numbered.end(), [&](const auto &a, const auto &b) {
		return descending ? a.first > b.first : a.first < b.first;
	});
	st.lines.clear();
	for (auto &p : numbered) st.lines.push_back(p.second);
	for (auto &l : others) st.lines.push_back(l);
	return join(st);
}

std::string sortLinesByLength(const std::string &text, bool descending) {
	SplitText st = split(text);
	std::stable_sort(st.lines.begin(), st.lines.end(), [&](const std::string &a, const std::string &b) {
		return descending ? a.size() > b.size() : a.size() < b.size();
	});
	return join(st);
}

std::string reverseLines(const std::string &text) {
	SplitText st = split(text);
	std::reverse(st.lines.begin(), st.lines.end());
	return join(st);
}

std::string shuffleLines(const std::string &text, unsigned seed) {
	SplitText st = split(text);
	std::mt19937 rng(seed);
	std::shuffle(st.lines.begin(), st.lines.end(), rng);
	return join(st);
}

std::string removeConsecutiveDuplicateLines(const std::string &text) {
	SplitText st = split(text);
	std::vector<std::string> kept;
	for (auto &line : st.lines)
		if (kept.empty() || kept.back() != line) kept.push_back(line);
	st.lines = kept;
	return join(st);
}

std::string properCase(const std::string &text, bool blend) {
	std::string out = text;
	bool start = true;
	for (size_t i = 0; i < out.size(); i++) {
		unsigned char c = static_cast<unsigned char>(out[i]);
		if (isWordChar(out[i])) {
			if (start) {
				out[i] = static_cast<char>(std::toupper(c));
				start = false;
			} else if (!blend) {
				out[i] = static_cast<char>(std::tolower(c));
			}
		} else {
			start = true;
		}
	}
	return out;
}

std::string sentenceCase(const std::string &text, bool blend) {
	std::string out = text;
	bool start = true;
	for (size_t i = 0; i < out.size(); i++) {
		unsigned char c = static_cast<unsigned char>(out[i]);
		if (std::isalpha(c)) {
			if (start) {
				out[i] = static_cast<char>(std::toupper(c));
				start = false;
			} else if (!blend) {
				out[i] = static_cast<char>(std::tolower(c));
			}
		} else if (out[i] == '.' || out[i] == '!' || out[i] == '?') {
			start = true;
		}
	}
	return out;
}

std::string randomCase(const std::string &text, unsigned seed) {
	std::mt19937 rng(seed);
	std::string out = text;
	for (auto &c : out) {
		if (!std::isalpha(static_cast<unsigned char>(c))) continue;
		bool up = rng() & 1;
		c = static_cast<char>(up ? std::toupper(static_cast<unsigned char>(c)) : std::tolower(static_cast<unsigned char>(c)));
	}
	return out;
}

} // namespace quill
