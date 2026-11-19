// Line based diff (Myers O(ND) with linear space "middle snake" refinement).
// SPDX-License-Identifier: GPL-3.0-or-later
#include "quill/Diff.h"

#include <algorithm>
#include <cstdint>
#include <cctype>
#include <unordered_map>

namespace quill {

namespace {

struct Seq {
	std::vector<int> data;
	std::vector<bool> modified;
};

struct Point {
	int x = 0;
	int y = 0;
};

Point middleSnake(const Seq &a, int lowerA, int upperA, const Seq &b, int lowerB, int upperB,
		  std::vector<int> &down, std::vector<int> &up) {
	const int max = static_cast<int>(a.data.size() + b.data.size()) + 1;
	const int downK = lowerA - lowerB;
	const int upK = upperA - upperB;
	const int delta = (upperA - lowerA) - (upperB - lowerB);
	const bool oddDelta = (delta & 1) != 0;
	const int downOffset = max - downK;
	const int upOffset = max - upK;
	const int maxD = ((upperA - lowerA + upperB - lowerB) / 2) + 1;

	down[downOffset + downK + 1] = lowerA;
	up[upOffset + upK - 1] = upperA;

	for (int d = 0; d <= maxD; d++) {
		for (int k = downK - d; k <= downK + d; k += 2) {
			int x;
			if (k == downK - d) {
				x = down[downOffset + k + 1];
			} else {
				x = down[downOffset + k - 1] + 1;
				if (k < downK + d && down[downOffset + k + 1] >= x)
					x = down[downOffset + k + 1];
			}
			int y = x - k;
			while (x < upperA && y < upperB && a.data[x] == b.data[y]) {
				x++;
				y++;
			}
			down[downOffset + k] = x;
			if (oddDelta && upK - d < k && k < upK + d) {
				if (up[upOffset + k] <= down[downOffset + k])
					return Point{down[downOffset + k], down[downOffset + k] - k};
			}
		}
		for (int k = upK - d; k <= upK + d; k += 2) {
			int x;
			if (k == upK + d) {
				x = up[upOffset + k - 1];
			} else {
				x = up[upOffset + k + 1] - 1;
				if (k > upK - d && up[upOffset + k - 1] < x)
					x = up[upOffset + k - 1];
			}
			int y = x - k;
			while (x > lowerA && y > lowerB && a.data[x - 1] == b.data[y - 1]) {
				x--;
				y--;
			}
			up[upOffset + k] = x;
			if (!oddDelta && downK - d <= k && k <= downK + d) {
				if (up[upOffset + k] <= down[downOffset + k])
					return Point{down[downOffset + k], down[downOffset + k] - k};
			}
		}
	}
	// Not reachable for valid input; fall back to "everything changed".
	return Point{upperA, upperB};
}

void lcs(Seq &a, int lowerA, int upperA, Seq &b, int lowerB, int upperB,
	 std::vector<int> &down, std::vector<int> &up) {
	while (lowerA < upperA && lowerB < upperB && a.data[lowerA] == b.data[lowerB]) {
		lowerA++;
		lowerB++;
	}
	while (lowerA < upperA && lowerB < upperB && a.data[upperA - 1] == b.data[upperB - 1]) {
		--upperA;
		--upperB;
	}
	if (lowerA == upperA) {
		while (lowerB < upperB)
			b.modified[lowerB++] = true;
	} else if (lowerB == upperB) {
		while (lowerA < upperA)
			a.modified[lowerA++] = true;
	} else {
		Point p = middleSnake(a, lowerA, upperA, b, lowerB, upperB, down, up);
		if ((p.x == upperA && p.y == upperB) || (p.x == lowerA && p.y == lowerB)) {
			// Degenerate split, mark the whole range as changed to guarantee progress.
			for (int i = lowerA; i < upperA; i++) a.modified[i] = true;
			for (int i = lowerB; i < upperB; i++) b.modified[i] = true;
			return;
		}
		lcs(a, lowerA, p.x, b, lowerB, p.y, down, up);
		lcs(a, p.x, upperA, b, p.y, upperB, down, up);
	}
}

void runDiff(Seq &a, Seq &b) {
	a.modified.assign(a.data.size() + 2, false);
	b.modified.assign(b.data.size() + 2, false);
	const size_t max = a.data.size() + b.data.size() + 1;
	std::vector<int> down(2 * max + 2, 0);
	std::vector<int> up(2 * max + 2, 0);
	lcs(a, 0, static_cast<int>(a.data.size()), b, 0, static_cast<int>(b.data.size()), down, up);
}

std::string normalize(const std::string &line, const DiffOptions &opt) {
	if (!opt.ignoreWhitespace && !opt.ignoreCase)
		return line;
	std::string out;
	out.reserve(line.size());
	for (char c : line) {
		if (opt.ignoreWhitespace && (c == ' ' || c == '\t'))
			continue;
		out.push_back(opt.ignoreCase ? static_cast<char>(std::tolower(static_cast<unsigned char>(c))) : c);
	}
	return out;
}

std::vector<DiffBlock> blocksFrom(const Seq &a, const Seq &b) {
	std::vector<DiffBlock> blocks;
	const size_t n = a.data.size();
	const size_t m = b.data.size();
	size_t la = 0, lb = 0;
	while (la < n || lb < m) {
		if (la < n && !a.modified[la] && lb < m && !b.modified[lb]) {
			size_t sa = la, sb = lb;
			while (la < n && lb < m && !a.modified[la] && !b.modified[lb]) {
				la++;
				lb++;
			}
			blocks.push_back(DiffBlock{DiffKind::Equal, sa, la - sa, sb, lb - sb});
		} else {
			size_t sa = la, sb = lb;
			while (la < n && (lb >= m || a.modified[la]))
				la++;
			while (lb < m && (la >= n || b.modified[lb]))
				lb++;
			if (sa == la && sb == lb) {
				// Should not happen; avoid an infinite loop.
				if (la < n) la++;
				if (lb < m) lb++;
				blocks.push_back(DiffBlock{DiffKind::Change, sa, la - sa, sb, lb - sb});
				continue;
			}
			DiffKind kind = DiffKind::Change;
			if (la == sa)
				kind = DiffKind::Insert;
			else if (lb == sb)
				kind = DiffKind::Delete;
			blocks.push_back(DiffBlock{kind, sa, la - sa, sb, lb - sb});
		}
	}
	return blocks;
}

} // namespace

std::vector<std::string> splitLines(const std::string &text) {
	std::vector<std::string> lines;
	std::string current;
	for (size_t i = 0; i < text.size(); i++) {
		char c = text[i];
		if (c == '\r') {
			lines.push_back(current);
			current.clear();
			if (i + 1 < text.size() && text[i + 1] == '\n')
				i++;
		} else if (c == '\n') {
			lines.push_back(current);
			current.clear();
		} else {
			current.push_back(c);
		}
	}
	if (!current.empty())
		lines.push_back(current);
	return lines;
}

std::vector<DiffBlock> diffLines(const std::vector<std::string> &left,
				 const std::vector<std::string> &right,
				 const DiffOptions &options) {
	std::unordered_map<std::string, int> ids;
	auto idOf = [&](const std::string &line) {
		std::string key = normalize(line, options);
		if (options.ignoreEmptyLines) {
			bool blank = std::all_of(key.begin(), key.end(), [](char c) { return c == ' ' || c == '\t'; });
			if (blank)
				key.clear();
		}
		auto it = ids.find(key);
		if (it != ids.end())
			return it->second;
		int id = static_cast<int>(ids.size());
		ids.emplace(std::move(key), id);
		return id;
	};
	Seq a, b;
	a.data.reserve(left.size());
	b.data.reserve(right.size());
	for (const auto &l : left)
		a.data.push_back(idOf(l));
	for (const auto &l : right)
		b.data.push_back(idOf(l));
	runDiff(a, b);
	return blocksFrom(a, b);
}

void diffChars(const std::string &left, const std::string &right,
	       std::vector<CharRange> &leftRanges, std::vector<CharRange> &rightRanges) {
	leftRanges.clear();
	rightRanges.clear();
	if (left.size() > 4000 || right.size() > 4000) {
		if (!left.empty()) leftRanges.push_back({0, left.size()});
		if (!right.empty()) rightRanges.push_back({0, right.size()});
		return;
	}
	Seq a, b;
	for (unsigned char c : left) a.data.push_back(c);
	for (unsigned char c : right) b.data.push_back(c);
	runDiff(a, b);
	auto collect = [](const Seq &s, const std::string &text, std::vector<CharRange> &out) {
		size_t i = 0;
		while (i < s.data.size()) {
			if (!s.modified[i]) {
				i++;
				continue;
			}
			size_t start = i;
			while (i < s.data.size() && s.modified[i])
				i++;
			// Widen to UTF-8 code point boundaries.
			while (start > 0 && (static_cast<unsigned char>(text[start]) & 0xC0) == 0x80)
				start--;
			while (i < text.size() && (static_cast<unsigned char>(text[i]) & 0xC0) == 0x80)
				i++;
			if (!out.empty() && out.back().start + out.back().length >= start) {
				out.back().length = i - out.back().start;
			} else {
				out.push_back({start, i - start});
			}
		}
	};
	collect(a, left, leftRanges);
	collect(b, right, rightRanges);
}

DiffStats diffStats(const std::vector<DiffBlock> &blocks) {
	DiffStats s;
	for (const auto &bl : blocks) {
		switch (bl.kind) {
		case DiffKind::Equal:
			break;
		case DiffKind::Delete:
			s.removed += bl.leftCount;
			s.blocks++;
			break;
		case DiffKind::Insert:
			s.added += bl.rightCount;
			s.blocks++;
			break;
		case DiffKind::Change:
			s.changed += bl.leftCount;
			s.blocks++;
			break;
		}
	}
	return s;
}

} // namespace quill
