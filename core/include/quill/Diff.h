// Line based diff (Myers O(ND) algorithm) used by the Compare plugin.
// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include <string>
#include <vector>

namespace quill {

struct DiffOptions {
	bool ignoreWhitespace = false;   // ignore all spaces / tabs when comparing lines
	bool ignoreCase = false;
	bool ignoreEmptyLines = false;   // not used for alignment, only for equality
};

enum class DiffKind { Equal, Delete, Insert, Change };

// A block of consecutive lines. Lines are 0-based, [start, start + count).
struct DiffBlock {
	DiffKind kind = DiffKind::Equal;
	size_t leftStart = 0;
	size_t leftCount = 0;
	size_t rightStart = 0;
	size_t rightCount = 0;
};

// Splits text into lines (handles \n, \r\n and \r). The line terminators are not
// included. A trailing terminator does not create an extra empty line.
std::vector<std::string> splitLines(const std::string &text);

// Computes the diff between two sequences of lines. Adjacent Delete + Insert
// blocks are merged into Change blocks.
std::vector<DiffBlock> diffLines(const std::vector<std::string> &left,
				 const std::vector<std::string> &right,
				 const DiffOptions &options = DiffOptions());

// Character ranges that differ inside a pair of changed lines.
struct CharRange {
	size_t start = 0;
	size_t length = 0;
};
void diffChars(const std::string &left, const std::string &right,
	       std::vector<CharRange> &leftRanges, std::vector<CharRange> &rightRanges);

struct DiffStats {
	size_t added = 0;    // lines only on the right
	size_t removed = 0;  // lines only on the left
	size_t changed = 0;  // lines changed (counted on the left)
	size_t blocks = 0;   // number of non equal blocks
};
DiffStats diffStats(const std::vector<DiffBlock> &blocks);

} // namespace quill
