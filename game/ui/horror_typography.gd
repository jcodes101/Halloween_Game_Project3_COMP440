extends RefCounted
## Shared, portable serif typography. Uses installed serif fonts with safe fallbacks.

static var _shared: Theme

static func theme() -> Theme:
	if _shared != null:
		return _shared
	_shared = Theme.new()
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "Times New Roman", "Liberation Serif", "serif"])
	serif.allow_system_fallback = true
	_shared.default_font = serif
	_shared.default_font_size = 14
	return _shared
