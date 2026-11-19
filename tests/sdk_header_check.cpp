// Compile-only check of the plugin SDK headers.
// SPDX-License-Identifier: GPL-3.0-or-later
#include "PluginInterface.h"
#include "Docking.h"
#include "QuillExtensions.h"
#include "QuillPluginKit.h"

int sdkHeaderCheck() {
	tTbData data;
	data.uMask = DWS_DF_CONT_RIGHT;
	FuncItem item;
	quill::copyName(item._itemName, menuItemSize, quill::widen("Ol\xC3\xA1"));
	return static_cast<int>(NPPM_GETCURRENTSCINTILLA + NPPN_READY + QUILLM_GETUILANGUAGE + data.uMask + item._itemName[2]);
}
