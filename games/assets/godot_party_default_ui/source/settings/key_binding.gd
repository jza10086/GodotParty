class_name SettingKeyBinding
extends RefCounted
## Serializable logical keyboard keys, with modifier masks. Zero means unbound.
static func valid_pair(value: Variant) -> bool:
	if not value is Array or value.size() != 2: return false
	for code in value:
		if not code is int or code < 0: return false
		if code == 0: continue
		var base: int = code & KEY_CODE_MASK
		if base == 0 or base in [KEY_ESCAPE, KEY_BACKSPACE, KEY_DELETE, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]: return false
		# Only modifiers actually captured by this component may be configured.
		if code & ~(KEY_CODE_MASK | KEY_MASK_SHIFT | KEY_MASK_ALT | KEY_MASK_CTRL | KEY_MASK_META): return false
	return value[0] == 0 or value[0] != value[1]

static func label(code: int) -> String:
	return "未绑定" if code == 0 else OS.get_keycode_string(code)

static func event(code: int) -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = code & KEY_CODE_MASK
	key.shift_pressed = bool(code & KEY_MASK_SHIFT)
	key.alt_pressed = bool(code & KEY_MASK_ALT)
	key.ctrl_pressed = bool(code & KEY_MASK_CTRL)
	key.meta_pressed = bool(code & KEY_MASK_META)
	return key
