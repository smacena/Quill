// SPDX-License-Identifier: GPL-3.0-or-later
#include "quill/Json.h"

#include <algorithm>
#include <cstdint>
#include <cstdio>

namespace quill {

namespace {

class Parser {
public:
	Parser(const std::string &t, const JsonParseOptions &o) : s(t), opt(o) {}

	std::shared_ptr<JsonValue> run(JsonError &err) {
		skip();
		if (failed) return finish(err);
		auto v = value(0);
		if (failed) return finish(err);
		skip();
		if (failed) return finish(err);
		if (pos < s.size()) fail("Unexpected content after the JSON value");
		return finish(err, v);
	}

private:
	const std::string &s;
	JsonParseOptions opt;
	size_t pos = 0;
	bool failed = false;
	std::string message;
	size_t errPos = 0;

	std::shared_ptr<JsonValue> finish(JsonError &err, std::shared_ptr<JsonValue> v = nullptr) {
		if (failed) {
			err.ok = false;
			err.message = message;
			err.offset = errPos;
			size_t line = 1, col = 1;
			for (size_t i = 0; i < errPos && i < s.size(); i++) {
				if (s[i] == '\n') {
					line++;
					col = 1;
				} else {
					col++;
				}
			}
			err.line = line;
			err.column = col;
			return nullptr;
		}
		err.ok = true;
		return v;
	}

	void fail(const std::string &m) {
		if (!failed) {
			failed = true;
			message = m;
			errPos = pos;
		}
	}

	void skip() {
		while (pos < s.size()) {
			char c = s[pos];
			if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
				pos++;
			} else if (opt.allowComments && c == '/' && pos + 1 < s.size() && s[pos + 1] == '/') {
				while (pos < s.size() && s[pos] != '\n') pos++;
			} else if (opt.allowComments && c == '/' && pos + 1 < s.size() && s[pos + 1] == '*') {
				size_t end = s.find("*/", pos + 2);
				if (end == std::string::npos) {
					fail("Unterminated comment");
					return;
				}
				pos = end + 2;
			} else if (static_cast<unsigned char>(c) == 0xEF && pos + 2 < s.size() &&
				   static_cast<unsigned char>(s[pos + 1]) == 0xBB && static_cast<unsigned char>(s[pos + 2]) == 0xBF) {
				pos += 3; // BOM
			} else {
				break;
			}
		}
	}

	std::shared_ptr<JsonValue> value(int depth) {
		if (depth > 2000) {
			fail("Nesting too deep");
			return nullptr;
		}
		if (pos >= s.size()) {
			fail("Unexpected end of text, a value was expected");
			return nullptr;
		}
		auto v = std::make_shared<JsonValue>();
		v->offset = pos;
		char c = s[pos];
		if (c == '{') {
			v->type = JsonValue::Type::Object;
			pos++;
			skip();
			if (pos < s.size() && s[pos] == '}') {
				pos++;
				return v;
			}
			while (!failed) {
				skip();
				if (opt.allowTrailingCommas && pos < s.size() && s[pos] == '}' && !v->members.empty()) {
					pos++;
					return v;
				}
				if (pos >= s.size() || s[pos] != '"') {
					fail("Expected a property name in double quotes");
					return nullptr;
				}
				std::string key;
				if (!string(key)) return nullptr;
				skip();
				if (pos >= s.size() || s[pos] != ':') {
					fail("Expected ':' after the property name");
					return nullptr;
				}
				pos++;
				skip();
				auto child = value(depth + 1);
				if (!child) return nullptr;
				v->members.emplace_back(std::move(key), child);
				skip();
				if (pos < s.size() && s[pos] == ',') {
					pos++;
					continue;
				}
				if (pos < s.size() && s[pos] == '}') {
					pos++;
					return v;
				}
				fail("Expected ',' or '}' in object");
				return nullptr;
			}
			return nullptr;
		}
		if (c == '[') {
			v->type = JsonValue::Type::Array;
			pos++;
			skip();
			if (pos < s.size() && s[pos] == ']') {
				pos++;
				return v;
			}
			while (!failed) {
				skip();
				if (opt.allowTrailingCommas && pos < s.size() && s[pos] == ']' && !v->items.empty()) {
					pos++;
					return v;
				}
				auto child = value(depth + 1);
				if (!child) return nullptr;
				v->items.push_back(child);
				skip();
				if (pos < s.size() && s[pos] == ',') {
					pos++;
					continue;
				}
				if (pos < s.size() && s[pos] == ']') {
					pos++;
					return v;
				}
				fail("Expected ',' or ']' in array");
				return nullptr;
			}
			return nullptr;
		}
		if (c == '"') {
			v->type = JsonValue::Type::String;
			if (!string(v->text)) return nullptr;
			return v;
		}
		if (c == 't' && s.compare(pos, 4, "true") == 0) {
			v->type = JsonValue::Type::Bool;
			v->boolean = true;
			pos += 4;
			return v;
		}
		if (c == 'f' && s.compare(pos, 5, "false") == 0) {
			v->type = JsonValue::Type::Bool;
			pos += 5;
			return v;
		}
		if (c == 'n' && s.compare(pos, 4, "null") == 0) {
			v->type = JsonValue::Type::Null;
			pos += 4;
			return v;
		}
		if (c == '-' || (c >= '0' && c <= '9')) {
			size_t start = pos;
			if (s[pos] == '-') pos++;
			if (pos >= s.size() || !isdigit(s[pos])) {
				fail("Invalid number");
				return nullptr;
			}
			if (s[pos] == '0') {
				pos++;
			} else {
				while (pos < s.size() && isdigit(s[pos])) pos++;
			}
			if (pos < s.size() && s[pos] == '.') {
				pos++;
				if (pos >= s.size() || !isdigit(s[pos])) {
					fail("Invalid number: digits expected after '.'");
					return nullptr;
				}
				while (pos < s.size() && isdigit(s[pos])) pos++;
			}
			if (pos < s.size() && (s[pos] == 'e' || s[pos] == 'E')) {
				pos++;
				if (pos < s.size() && (s[pos] == '+' || s[pos] == '-')) pos++;
				if (pos >= s.size() || !isdigit(s[pos])) {
					fail("Invalid number: digits expected in exponent");
					return nullptr;
				}
				while (pos < s.size() && isdigit(s[pos])) pos++;
			}
			v->type = JsonValue::Type::Number;
			v->text = s.substr(start, pos - start);
			return v;
		}
		fail(std::string("Unexpected character '") + c + "'");
		return nullptr;
	}

	static bool isdigit(char c) { return c >= '0' && c <= '9'; }

	static int hexval(char c) {
		if (c >= '0' && c <= '9') return c - '0';
		if (c >= 'a' && c <= 'f') return c - 'a' + 10;
		if (c >= 'A' && c <= 'F') return c - 'A' + 10;
		return -1;
	}

	static void append(std::string &out, uint32_t cp) {
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

	bool hex4(uint32_t &out) {
		if (pos + 4 > s.size()) {
			fail("Invalid \\u escape");
			return false;
		}
		out = 0;
		for (int i = 0; i < 4; i++) {
			int h = hexval(s[pos + i]);
			if (h < 0) {
				fail("Invalid \\u escape");
				return false;
			}
			out = (out << 4) | static_cast<uint32_t>(h);
		}
		pos += 4;
		return true;
	}

	bool string(std::string &out) {
		pos++; // opening quote
		while (pos < s.size()) {
			char c = s[pos];
			if (c == '"') {
				pos++;
				return true;
			}
			if (c == '\\') {
				pos++;
				if (pos >= s.size()) break;
				char e = s[pos++];
				switch (e) {
				case '"': out.push_back('"'); break;
				case '\\': out.push_back('\\'); break;
				case '/': out.push_back('/'); break;
				case 'b': out.push_back('\b'); break;
				case 'f': out.push_back('\f'); break;
				case 'n': out.push_back('\n'); break;
				case 'r': out.push_back('\r'); break;
				case 't': out.push_back('\t'); break;
				case 'u': {
					uint32_t cp;
					if (!hex4(cp)) return false;
					if (cp >= 0xD800 && cp <= 0xDBFF && pos + 1 < s.size() && s[pos] == '\\' && s[pos + 1] == 'u') {
						pos += 2;
						uint32_t lo;
						if (!hex4(lo)) return false;
						if (lo >= 0xDC00 && lo <= 0xDFFF)
							cp = 0x10000 + ((cp - 0xD800) << 10) + (lo - 0xDC00);
						else {
							append(out, 0xFFFD);
							cp = lo;
						}
					}
					append(out, cp);
					break;
				}
				default:
					pos--;
					fail("Invalid escape sequence in string");
					return false;
				}
				continue;
			}
			if (static_cast<unsigned char>(c) < 0x20) {
				fail("Control character in string (use an escape sequence)");
				return false;
			}
			out.push_back(c);
			pos++;
		}
		fail("Unterminated string");
		return false;
	}
};

void writeIndent(std::string &out, const JsonFormatOptions &o, int level) {
	if (o.useTabs)
		out.append(static_cast<size_t>(level), '\t');
	else
		out.append(static_cast<size_t>(level * o.indent), ' ');
}

void write(std::string &out, const JsonValue &v, const JsonFormatOptions &o, int level, bool pretty) {
	switch (v.type) {
	case JsonValue::Type::Null: out += "null"; break;
	case JsonValue::Type::Bool: out += v.boolean ? "true" : "false"; break;
	case JsonValue::Type::Number: out += v.text; break;
	case JsonValue::Type::String:
		out.push_back('"');
		out += escapeJsonString(v.text);
		out.push_back('"');
		break;
	case JsonValue::Type::Array:
		if (v.items.empty()) {
			out += "[]";
			break;
		}
		out.push_back('[');
		for (size_t i = 0; i < v.items.size(); i++) {
			if (pretty) {
				out += o.eol;
				writeIndent(out, o, level + 1);
			}
			write(out, *v.items[i], o, level + 1, pretty);
			if (i + 1 < v.items.size()) out.push_back(',');
		}
		if (pretty) {
			out += o.eol;
			writeIndent(out, o, level);
		}
		out.push_back(']');
		break;
	case JsonValue::Type::Object: {
		if (v.members.empty()) {
			out += "{}";
			break;
		}
		std::vector<size_t> order(v.members.size());
		for (size_t i = 0; i < order.size(); i++) order[i] = i;
		if (o.sortKeys)
			std::stable_sort(order.begin(), order.end(),
					 [&](size_t a, size_t b) { return v.members[a].first < v.members[b].first; });
		out.push_back('{');
		for (size_t n = 0; n < order.size(); n++) {
			const auto &m = v.members[order[n]];
			if (pretty) {
				out += o.eol;
				writeIndent(out, o, level + 1);
			}
			out.push_back('"');
			out += escapeJsonString(m.first);
			out += pretty && o.spaceAfterColon ? "\": " : "\":";
			write(out, *m.second, o, level + 1, pretty);
			if (n + 1 < order.size()) out.push_back(',');
		}
		if (pretty) {
			out += o.eol;
			writeIndent(out, o, level);
		}
		out.push_back('}');
		break;
	}
	}
}

} // namespace

std::shared_ptr<JsonValue> parseJson(const std::string &text, JsonError &error, const JsonParseOptions &options) {
	Parser p(text, options);
	return p.run(error);
}

std::string escapeJsonString(const std::string &s) {
	std::string out;
	out.reserve(s.size() + 2);
	for (unsigned char c : s) {
		switch (c) {
		case '"': out += "\\\""; break;
		case '\\': out += "\\\\"; break;
		case '\b': out += "\\b"; break;
		case '\f': out += "\\f"; break;
		case '\n': out += "\\n"; break;
		case '\r': out += "\\r"; break;
		case '\t': out += "\\t"; break;
		default:
			if (c < 0x20) {
				char buf[8];
				snprintf(buf, sizeof(buf), "\\u%04x", c);
				out += buf;
			} else {
				out.push_back(static_cast<char>(c));
			}
		}
	}
	return out;
}

std::string formatJson(const JsonValue &value, const JsonFormatOptions &options) {
	std::string out;
	bool pretty = options.useTabs || options.indent > 0;
	write(out, value, options, 0, pretty);
	return out;
}

std::string minifyJson(const JsonValue &value) {
	JsonFormatOptions o;
	o.indent = 0;
	o.useTabs = false;
	std::string out;
	write(out, value, o, 0, false);
	return out;
}

std::string jsonTypeName(JsonValue::Type type) {
	switch (type) {
	case JsonValue::Type::Null: return "null";
	case JsonValue::Type::Bool: return "boolean";
	case JsonValue::Type::Number: return "number";
	case JsonValue::Type::String: return "string";
	case JsonValue::Type::Array: return "array";
	case JsonValue::Type::Object: return "object";
	}
	return "";
}

std::string jsonPreview(const JsonValue &value, size_t maxLen) {
	std::string s;
	switch (value.type) {
	case JsonValue::Type::Array: s = "[" + std::to_string(value.items.size()) + "]"; break;
	case JsonValue::Type::Object: s = "{" + std::to_string(value.members.size()) + "}"; break;
	case JsonValue::Type::String: s = "\"" + escapeJsonString(value.text) + "\""; break;
	default: s = minifyJson(value); break;
	}
	if (s.size() > maxLen) {
		size_t cut = maxLen;
		while (cut > 0 && (static_cast<unsigned char>(s[cut]) & 0xC0) == 0x80) cut--;
		s = s.substr(0, cut) + "…";
	}
	return s;
}

} // namespace quill
