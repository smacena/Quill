// Encoding and line ending detection / conversion.
// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include <string>

namespace quill {

enum class TextEncoding {
	UTF8,        // UTF-8 without BOM
	UTF8BOM,     // UTF-8 with BOM
	UTF16LE,     // with BOM
	UTF16BE,     // with BOM
	Windows1252, // "ANSI" (Western)
	Latin1,      // ISO-8859-1
	MacRoman,
};

enum class LineEnding { LF, CRLF, CR };

const char *encodingName(TextEncoding e);
const char *lineEndingName(LineEnding e);

// Detects the encoding of raw file bytes.
TextEncoding detectEncoding(const std::string &bytes);

// True if bytes (without BOM) are valid UTF-8.
bool isValidUtf8(const std::string &bytes);

// Converts raw bytes in the given encoding to UTF-8 (BOM removed).
std::string decodeToUtf8(const std::string &bytes, TextEncoding enc);

// Converts UTF-8 text to bytes in the given encoding (BOM added when the
// encoding has one). Characters that cannot be represented become '?'.
// unrepresentable receives the number of replaced characters.
std::string encodeFromUtf8(const std::string &utf8, TextEncoding enc, size_t *unrepresentable = nullptr);

// Detects the dominant line ending; defaults to LF when there is none.
LineEnding detectLineEnding(const std::string &text);

// Converts every line ending in text to the requested one.
std::string convertLineEndings(const std::string &text, LineEnding to);

} // namespace quill
