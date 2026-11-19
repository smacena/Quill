// Small JSON parser / formatter used by the JSON Viewer plugin.
// Keeps object key order and the original text of numbers.
// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include <memory>
#include <string>
#include <utility>
#include <vector>

namespace quill {

struct JsonValue {
	enum class Type { Null, Bool, Number, String, Array, Object };
	Type type = Type::Null;
	bool boolean = false;
	std::string text;  // number text (as written) or decoded string (UTF-8)
	std::vector<std::shared_ptr<JsonValue>> items;                         // arrays
	std::vector<std::pair<std::string, std::shared_ptr<JsonValue>>> members; // objects
	size_t offset = 0; // byte offset of the value in the source text
};

struct JsonError {
	bool ok = true;
	std::string message;
	size_t offset = 0;
	size_t line = 0;    // 1-based
	size_t column = 0;  // 1-based, in bytes
};

struct JsonParseOptions {
	bool allowComments = true;        // // and /* */ comments (JSONC)
	bool allowTrailingCommas = true;
};

std::shared_ptr<JsonValue> parseJson(const std::string &text, JsonError &error,
				     const JsonParseOptions &options = JsonParseOptions());

struct JsonFormatOptions {
	int indent = 4;            // spaces per level; 0 with useTabs = false means compact
	bool useTabs = false;
	bool sortKeys = false;
	bool spaceAfterColon = true;
	std::string eol = "\n";
};

std::string formatJson(const JsonValue &value, const JsonFormatOptions &options);
std::string minifyJson(const JsonValue &value);
std::string escapeJsonString(const std::string &s);

// Label of a value for a tree view, e.g. "name : \"Bob\"" or "items [3]".
std::string jsonTypeName(JsonValue::Type type);
std::string jsonPreview(const JsonValue &value, size_t maxLen = 80);

} // namespace quill
