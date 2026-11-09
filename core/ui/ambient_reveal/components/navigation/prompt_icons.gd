## Kenney input glyphs for local InputMap bindings. Explicit textures cover composite gestures.
extends RefCounted

const ROOT: String = "res://core/ui/ambient_reveal/icons/kenney_input/"
const KEYS: Dictionary = {
	KEY_ESCAPE: "escape", KEY_TAB: "tab", KEY_BACKSPACE: "backspace",
	KEY_ENTER: "enter", KEY_KP_ENTER: "numpad_enter", KEY_SPACE: "space",
	KEY_SHIFT: "shift", KEY_CTRL: "ctrl", KEY_ALT: "alt", KEY_META: "command",
	KEY_UP: "arrow_up", KEY_DOWN: "arrow_down", KEY_LEFT: "arrow_left", KEY_RIGHT: "arrow_right",
	KEY_HOME: "home", KEY_END: "end", KEY_PAGEUP: "page_up", KEY_PAGEDOWN: "page_down",
	KEY_INSERT: "insert", KEY_DELETE: "delete", KEY_CAPSLOCK: "capslock", KEY_NUMLOCK: "numlock",
	KEY_SCROLLLOCK: "scroll_lock", KEY_PRINT: "printscreen", KEY_PAUSE: "pause",
	KEY_KP_ADD: "numpad_plus", KEY_KP_SUBTRACT: "minus", KEY_KP_MULTIPLY: "asterisk",
	KEY_KP_DIVIDE: "slash_forward", KEY_KP_PERIOD: "period",
	KEY_MINUS: "minus", KEY_EQUAL: "equals", KEY_PLUS: "plus", KEY_COMMA: "comma",
	KEY_PERIOD: "period", KEY_SLASH: "slash_forward", KEY_BACKSLASH: "slash_back",
	KEY_SEMICOLON: "semicolon", KEY_APOSTROPHE: "apostrophe",
	KEY_BRACKETLEFT: "bracket_open", KEY_BRACKETRIGHT: "bracket_close", KEY_QUOTELEFT: "tilde",
}
const MOUSE: Dictionary = {
	MOUSE_BUTTON_LEFT: "left", MOUSE_BUTTON_RIGHT: "right", MOUSE_BUTTON_MIDDLE: "scroll",
	MOUSE_BUTTON_WHEEL_UP: "scroll_up", MOUSE_BUTTON_WHEEL_DOWN: "scroll_down",
	MOUSE_BUTTON_WHEEL_LEFT: "horizontal", MOUSE_BUTTON_WHEEL_RIGHT: "horizontal",
	MOUSE_BUTTON_XBUTTON1: "side_back", MOUSE_BUTTON_XBUTTON2: "side_forward",
}
const PAD: Dictionary = {
	JOY_BUTTON_A: "button_color_a", JOY_BUTTON_B: "button_color_b", JOY_BUTTON_X: "button_color_x", JOY_BUTTON_Y: "button_color_y",
	JOY_BUTTON_BACK: "button_view", JOY_BUTTON_GUIDE: "guide", JOY_BUTTON_START: "button_menu",
	JOY_BUTTON_LEFT_STICK: "ls", JOY_BUTTON_RIGHT_STICK: "rs",
	JOY_BUTTON_LEFT_SHOULDER: "lb", JOY_BUTTON_RIGHT_SHOULDER: "rb",
	JOY_BUTTON_DPAD_UP: "dpad_up", JOY_BUTTON_DPAD_DOWN: "dpad_down",
	JOY_BUTTON_DPAD_LEFT: "dpad_left", JOY_BUTTON_DPAD_RIGHT: "dpad_right",
}

static func for_event(event: InputEvent) -> Array[Texture2D]:
	var icons: Array[Texture2D] = []
	if event is InputEventKey:
		if event.ctrl_pressed: icons.append(_keyboard(KEY_CTRL))
		if event.alt_pressed: icons.append(_keyboard(KEY_ALT))
		if event.shift_pressed: icons.append(_keyboard(KEY_SHIFT))
		if event.meta_pressed: icons.append(_keyboard(KEY_META))
		icons.append(_keyboard(event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode))
	elif event is InputEventMouseButton:
		icons.append(load(ROOT + "keyboard_mouse/mouse_" + MOUSE.get(event.button_index, "outline") + ".svg"))
	elif event is InputEventJoypadButton:
		var file: String = "xbox_" + PAD[event.button_index] if PAD.has(event.button_index) else "controller_xboxseries"
		icons.append(load(ROOT + "xbox/" + file + ".svg"))
	elif event is InputEventJoypadMotion:
		var name: String
		match event.axis:
			JOY_AXIS_LEFT_X: name = "stick_l_left" if event.axis_value < 0 else "stick_l_right"
			JOY_AXIS_LEFT_Y: name = "stick_l_up" if event.axis_value < 0 else "stick_l_down"
			JOY_AXIS_RIGHT_X: name = "stick_r_left" if event.axis_value < 0 else "stick_r_right"
			JOY_AXIS_RIGHT_Y: name = "stick_r_up" if event.axis_value < 0 else "stick_r_down"
			JOY_AXIS_TRIGGER_LEFT: name = "lt"
			JOY_AXIS_TRIGGER_RIGHT: name = "rt"
			_:
				push_error("Unsupported prompt axis: " + str(event.axis))
				return []
		icons.append(load(ROOT + "xbox/xbox_" + name + ".svg"))
	return icons

static func _keyboard(code: int) -> Texture2D:
	var name: String = KEYS.get(code, "any")
	if code >= KEY_A and code <= KEY_Z:
		name = String.chr(code).to_lower()
	elif code >= KEY_0 and code <= KEY_9:
		name = String.chr(code)
	elif code >= KEY_F1 and code <= KEY_F12:
		name = "f" + str(code - KEY_F1 + 1)
	elif code >= KEY_KP_0 and code <= KEY_KP_9:
		name = str(code - KEY_KP_0)
	return load(ROOT + "keyboard_mouse/keyboard_" + name + ".svg")
