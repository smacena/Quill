// Assorted text helpers shared by the app and the plugins.
// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include <map>
#include <string>
#include <vector>

namespace quill {

// ---- Hex ------------------------------------------------------------------

// One line of a classic hex dump: "00000010  48 65 6c 6c ...  |Hello...|"
std::string hexDumpLine(const std::string &bytes, size_t offset, size_t bytesPerLine = 16);
std::string hexDump(const std::string &bytes, size_t bytesPerLine = 16);

// Parses "48 65 6C" / "48656c" / "0x48,0x65" into bytes. Returns false on
// invalid input (odd number of digits or non hex characters).
bool parseHexBytes(const std::string &text, std::string &out);

std::string toHex(const std::string &bytes, bool spaced = true, bool upper = true);

// ---- Command variables (Exec plugin) ---------------------------------------

// Replaces $(NAME) occurrences using vars. Unknown variables are kept as is.
// Names are case insensitive. $(SYS.NAME) is looked up in the environment.
std::string expandVariables(const std::string &command, const std::map<std::string, std::string> &vars);

// Quotes a string for /bin/sh using single quotes.
std::string shellQuote(const std::string &s);

// Builds the variable map for a file path (FULL_CURRENT_PATH, CURRENT_DIRECTORY,
// FILE_NAME, NAME_PART, EXT_PART).
std::map<std::string, std::string> fileVariables(const std::string &fullPath);

// Default command used by "Run current file" for a file extension ("py", "js"...)
// Returns an empty string when there is no known runner.
std::string defaultRunCommand(const std::string &extension);

// ---- Remote directory listings (FTP plugin) ---------------------------------

struct RemoteEntry {
	std::string name;
	bool isDirectory = false;
	bool isLink = false;
	unsigned long long size = 0;
	std::string modified;     // as printed by the server
	std::string permissions;  // "drwxr-xr-x"
};

// Parses a Unix "ls -l" style listing (what FTP LIST and sftp "ls -l" print).
// "." and ".." entries are skipped. Also understands MS-DOS style FTP listings.
std::vector<RemoteEntry> parseDirectoryListing(const std::string &listing);

// Joins remote paths with exactly one '/'.
std::string joinRemotePath(const std::string &dir, const std::string &name);
std::string parentRemotePath(const std::string &path);

// ---- Lines ------------------------------------------------------------------

enum class SortMode { Ascending, Descending, AscendingCaseInsensitive, Numeric };
std::string sortLines(const std::string &text, SortMode mode, bool removeDuplicates = false);
std::string trimTrailingWhitespace(const std::string &text);
std::string removeDuplicateLines(const std::string &text);
std::string removeEmptyLines(const std::string &text);

// ---- Markdown ----------------------------------------------------------------

// Renders Markdown (CommonMark + GitHub tables, strikethrough, task lists,
// autolinks) to an HTML fragment.
std::string markdownToHtml(const std::string &markdown);

} // namespace quill
