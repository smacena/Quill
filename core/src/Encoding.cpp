// SPDX-License-Identifier: GPL-3.0-or-later
#include "quill/Encoding.h"

#include <cstdint>

namespace quill {

namespace {

// Windows-1252 0x80..0x9F -> Unicode. 0 = undefined.
const uint16_t kCp1252High[32] = {
	0x20AC, 0, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, 0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0, 0x017D, 0,
	0, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, 0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0, 0x017E, 0x0178,
};

// Mac OS Roman 0x80..0xFF -> Unicode.
const uint16_t kMacRoman[128] = {
	0x00C4, 0x00C5, 0x00C7, 0x00C9, 0x00D1, 0x00D6, 0x00DC, 0x00E1, 0x00E0, 0x00E2, 0x00E4, 0x00E3, 0x00E5, 0x00E7, 0x00E9, 0x00E8,
	0x00EA, 0x00EB, 0x00ED, 0x00EC, 0x00EE, 0x00EF, 0x00F1, 0x00F3, 0x00F2, 0x00F4, 0x00F6, 0x00F5, 0x00FA, 0x00F9, 0x00FB, 0x00FC,
	0x2020, 0x00B0, 0x00A2, 0x00A3, 0x00A7, 0x2022, 0x00B6, 0x00DF, 0x00AE, 0x00A9, 0x2122, 0x00B4, 0x00A8, 0x2260, 0x00C6, 0x00D8,
	0x221E, 0x00B1, 0x2264, 0x2265, 0x00A5, 0x00B5, 0x2202, 0x2211, 0x220F, 0x03C0, 0x222B, 0x00AA, 0x00BA, 0x03A9, 0x00E6, 0x00F8,
	0x00BF, 0x00A1, 0x00AC, 0x221A, 0x0192, 0x2248, 0x2206, 0x00AB, 0x00BB, 0x2026, 0x00A0, 0x00C0, 0x00C3, 0x00D5, 0x0152, 0x0153,
	0x2013, 0x2014, 0x201C, 0x201D, 0x2018, 0x2019, 0x00F7, 0x25CA, 0x00FF, 0x0178, 0x2044, 0x20AC, 0x2039, 0x203A, 0xFB01, 0xFB02,
	0x2021, 0x00B7, 0x201A, 0x201E, 0x2030, 0x00C2, 0x00CA, 0x00C1, 0x00CB, 0x00C8, 0x00CD, 0x00CE, 0x00CF, 0x00CC, 0x00D3, 0x00D4,
	0xF8FF, 0x00D2, 0x00DA, 0x00DB, 0x00D9, 0x0131, 0x02C6, 0x02DC, 0x00AF, 0x02D8, 0x02D9, 0x02DA, 0x00B8, 0x02DD, 0x02DB, 0x02C7,
};

void appendUtf8(std::string &out, uint32_t cp) {
	if (cp < 0x80) out.push_back(static_cast<char>(cp));
	else if (cp < 0x800) {
		out.push_back(static_cast<char>(0xC0 | (cp >> 6)));
		out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
	} else if (cp < 0x10000) {
		out.push_back(static_cast<char>(0xE0 | (cp >> 12)));
		out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
		out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
	} else {
		out.push_back(static_cast<char>(0xF0 | (cp >> 18)));
		out.push_back(static_cast<char>(0x80 | ((cp >> 12) & 0x3F)));
		out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
		out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
	}
}

// Decodes one code point from UTF-8; returns false at end.
bool nextCodePoint(const std::string &s, size_t &i, uint32_t &cp) {
	if (i >= s.size()) return false;
	unsigned char c = static_cast<unsigned char>(s[i]);
	int extra;
	if (c < 0x80) { cp = c; extra = 0; }
	else if ((c & 0xE0) == 0xC0) { cp = c & 0x1F; extra = 1; }
	else if ((c & 0xF0) == 0xE0) { cp = c & 0x0F; extra = 2; }
	else if ((c & 0xF8) == 0xF0) { cp = c & 0x07; extra = 3; }
	else { cp = 0xFFFD; i++; return true; }
	if (i + static_cast<size_t>(extra) >= s.size()) {
		cp = 0xFFFD;
		i = s.size();
		return true;
	}
	for (int k = 1; k <= extra; k++) {
		unsigned char cc = static_cast<unsigned char>(s[i + k]);
		if ((cc & 0xC0) != 0x80) {
			cp = 0xFFFD;
			i++;
			return true;
		}
		cp = (cp << 6) | (cc & 0x3F);
	}
	i += static_cast<size_t>(extra) + 1;
	return true;
}

bool hasPrefix(const std::string &s, const char *p, size_t n) {
	return s.size() >= n && s.compare(0, n, p, n) == 0;
}

} // namespace

const char *encodingName(TextEncoding e) {
	switch (e) {
	case TextEncoding::UTF8: return "UTF-8";
	case TextEncoding::UTF8BOM: return "UTF-8 BOM";
	case TextEncoding::UTF16LE: return "UTF-16 LE BOM";
	case TextEncoding::UTF16BE: return "UTF-16 BE BOM";
	case TextEncoding::Windows1252: return "Windows-1252";
	case TextEncoding::Latin1: return "ISO-8859-1";
	case TextEncoding::MacRoman: return "Mac Roman";
	}
	return "UTF-8";
}

const char *lineEndingName(LineEnding e) {
	switch (e) {
	case LineEnding::LF: return "Unix (LF)";
	case LineEnding::CRLF: return "Windows (CR LF)";
	case LineEnding::CR: return "Macintosh (CR)";
	}
	return "Unix (LF)";
}

bool isValidUtf8(const std::string &b) {
	size_t i = 0, n = b.size();
	while (i < n) {
		unsigned char c = static_cast<unsigned char>(b[i]);
		if (c < 0x80) {
			i++;
			continue;
		}
		int extra;
		uint32_t cp;
		if ((c & 0xE0) == 0xC0) { extra = 1; cp = c & 0x1F; if (c < 0xC2) return false; }
		else if ((c & 0xF0) == 0xE0) { extra = 2; cp = c & 0x0F; }
		else if ((c & 0xF8) == 0xF0) { extra = 3; cp = c & 0x07; if (c > 0xF4) return false; }
		else return false;
		if (i + static_cast<size_t>(extra) >= n)
			return false; // truncated sequence
		for (int k = 1; k <= extra; k++) {
			unsigned char cc = static_cast<unsigned char>(b[i + k]);
			if ((cc & 0xC0) != 0x80) return false;
			cp = (cp << 6) | (cc & 0x3F);
		}
		if ((extra == 2 && cp < 0x800) || (extra == 3 && (cp < 0x10000 || cp > 0x10FFFF)) ||
		    (cp >= 0xD800 && cp <= 0xDFFF))
			return false;
		i += static_cast<size_t>(extra) + 1;
	}
	return true;
}

TextEncoding detectEncoding(const std::string &bytes) {
	if (hasPrefix(bytes, "\xEF\xBB\xBF", 3)) return TextEncoding::UTF8BOM;
	if (hasPrefix(bytes, "\xFF\xFE", 2)) return TextEncoding::UTF16LE;
	if (hasPrefix(bytes, "\xFE\xFF", 2)) return TextEncoding::UTF16BE;
	// UTF-16 without BOM: many zero bytes in alternating positions.
	if (bytes.size() >= 4) {
		size_t sample = bytes.size() < 4096 ? bytes.size() : 4096;
		size_t evenZero = 0, oddZero = 0;
		for (size_t i = 0; i + 1 < sample; i += 2) {
			if (bytes[i] == 0) evenZero++;
			if (bytes[i + 1] == 0) oddZero++;
		}
		size_t pairs = sample / 2;
		if (oddZero > pairs * 6 / 10 && evenZero <= pairs / 10) return TextEncoding::UTF16LE;
		if (evenZero > pairs * 6 / 10 && oddZero <= pairs / 10) return TextEncoding::UTF16BE;
	}
	if (isValidUtf8(bytes)) return TextEncoding::UTF8;
	return TextEncoding::Windows1252;
}

std::string decodeToUtf8(const std::string &bytes, TextEncoding enc) {
	std::string out;
	switch (enc) {
	case TextEncoding::UTF8:
		return bytes;
	case TextEncoding::UTF8BOM:
		return hasPrefix(bytes, "\xEF\xBB\xBF", 3) ? bytes.substr(3) : bytes;
	case TextEncoding::UTF16LE:
	case TextEncoding::UTF16BE: {
		bool le = enc == TextEncoding::UTF16LE;
		size_t i = 0;
		if (bytes.size() >= 2) {
			unsigned char b0 = static_cast<unsigned char>(bytes[0]);
			unsigned char b1 = static_cast<unsigned char>(bytes[1]);
			if ((le && b0 == 0xFF && b1 == 0xFE) || (!le && b0 == 0xFE && b1 == 0xFF)) i = 2;
		}
		out.reserve(bytes.size());
		auto unit = [&](size_t k) -> uint32_t {
			unsigned char a = static_cast<unsigned char>(bytes[k]);
			unsigned char b = static_cast<unsigned char>(bytes[k + 1]);
			return le ? (static_cast<uint32_t>(b) << 8 | a) : (static_cast<uint32_t>(a) << 8 | b);
		};
		while (i + 1 < bytes.size()) {
			uint32_t u = unit(i);
			i += 2;
			if (u >= 0xD800 && u <= 0xDBFF && i + 1 < bytes.size()) {
				uint32_t lo = unit(i);
				if (lo >= 0xDC00 && lo <= 0xDFFF) {
					i += 2;
					u = 0x10000 + ((u - 0xD800) << 10) + (lo - 0xDC00);
				} else {
					u = 0xFFFD;
				}
			} else if (u >= 0xD800 && u <= 0xDFFF) {
				u = 0xFFFD;
			}
			appendUtf8(out, u);
		}
		return out;
	}
	case TextEncoding::Windows1252:
	case TextEncoding::Latin1:
	case TextEncoding::MacRoman:
		out.reserve(bytes.size() + bytes.size() / 8);
		for (unsigned char c : bytes) {
			uint32_t cp = c;
			if (c >= 0x80) {
				if (enc == TextEncoding::MacRoman) cp = kMacRoman[c - 0x80];
				else if (enc == TextEncoding::Windows1252 && c < 0xA0) cp = kCp1252High[c - 0x80] ? kCp1252High[c - 0x80] : c;
			}
			appendUtf8(out, cp);
		}
		return out;
	}
	return bytes;
}

std::string encodeFromUtf8(const std::string &utf8, TextEncoding enc, size_t *unrepresentable) {
	size_t bad = 0;
	std::string out;
	switch (enc) {
	case TextEncoding::UTF8:
		out = utf8;
		break;
	case TextEncoding::UTF8BOM:
		out = "\xEF\xBB\xBF" + utf8;
		break;
	case TextEncoding::UTF16LE:
	case TextEncoding::UTF16BE: {
		bool le = enc == TextEncoding::UTF16LE;
		out.reserve(utf8.size() * 2 + 2);
		auto put = [&](uint32_t u) {
			char a = static_cast<char>(u & 0xFF), b = static_cast<char>((u >> 8) & 0xFF);
			if (le) {
				out.push_back(a);
				out.push_back(b);
			} else {
				out.push_back(b);
				out.push_back(a);
			}
		};
		put(0xFEFF);
		size_t i = 0;
		uint32_t cp;
		while (nextCodePoint(utf8, i, cp)) {
			if (cp >= 0x10000) {
				cp -= 0x10000;
				put(0xD800 + (cp >> 10));
				put(0xDC00 + (cp & 0x3FF));
			} else {
				put(cp);
			}
		}
		break;
	}
	case TextEncoding::Windows1252:
	case TextEncoding::Latin1:
	case TextEncoding::MacRoman: {
		size_t i = 0;
		uint32_t cp;
		while (nextCodePoint(utf8, i, cp)) {
			if (cp < 0x80) {
				out.push_back(static_cast<char>(cp));
				continue;
			}
			int found = -1;
			if (enc == TextEncoding::MacRoman) {
				for (int k = 0; k < 128; k++)
					if (kMacRoman[k] == cp) { found = 0x80 + k; break; }
			} else if (enc == TextEncoding::Latin1) {
				if (cp <= 0xFF) found = static_cast<int>(cp);
			} else {
				if (cp >= 0xA0 && cp <= 0xFF) found = static_cast<int>(cp);
				else
					for (int k = 0; k < 32; k++)
						if (kCp1252High[k] == cp) { found = 0x80 + k; break; }
			}
			if (found < 0) {
				bad++;
				out.push_back('?');
			} else {
				out.push_back(static_cast<char>(found));
			}
		}
		break;
	}
	}
	if (unrepresentable) *unrepresentable = bad;
	return out;
}

LineEnding detectLineEnding(const std::string &text) {
	size_t lf = 0, crlf = 0, cr = 0;
	for (size_t i = 0; i < text.size(); i++) {
		if (text[i] == '\r') {
			if (i + 1 < text.size() && text[i + 1] == '\n') {
				crlf++;
				i++;
			} else {
				cr++;
			}
		} else if (text[i] == '\n') {
			lf++;
		}
	}
	if (crlf > lf && crlf >= cr) return LineEnding::CRLF;
	if (cr > lf && cr > crlf) return LineEnding::CR;
	return LineEnding::LF;
}

std::string convertLineEndings(const std::string &text, LineEnding to) {
	const char *eol = to == LineEnding::CRLF ? "\r\n" : (to == LineEnding::CR ? "\r" : "\n");
	std::string out;
	out.reserve(text.size() + text.size() / 16);
	for (size_t i = 0; i < text.size(); i++) {
		char c = text[i];
		if (c == '\r') {
			if (i + 1 < text.size() && text[i + 1] == '\n') i++;
			out += eol;
		} else if (c == '\n') {
			out += eol;
		} else {
			out.push_back(c);
		}
	}
	return out;
}

} // namespace quill
