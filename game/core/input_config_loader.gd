## Loads local common input bindings from ConfigFile and applies them to InputMap.
class_name InputConfigLoader
extends RefCounted

const SETTINGS_PATH: String = "user://settings.cfg"
const INPUT_SECTION: String = "input"

const DEFAULT_KEYS: Dictionary[StringName, int] = {
	&"move_up": KEY_W,
	&"move_down": KEY_S,
	&"move_left": KEY_A,
	&"move_right": KEY_D,
}


static func ensure_global_movement_actions() -> Error:
	var config: ConfigFile = ConfigFile.new()
	var load_error: Error = config.load(SETTINGS_PATH)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		return load_error
	var should_save: bool = load_error == ERR_FILE_NOT_FOUND
	for action: StringName in DEFAULT_KEYS:
		var default_key: int = DEFAULT_KEYS[action]
		var raw_key: Variant = config.get_value(INPUT_SECTION, String(action), default_key)
		if typeof(raw_key) != TYPE_INT:
			return ERR_INVALID_DATA
		var physical_keycode: int = int(raw_key)
		if physical_keycode <= 0:
			return ERR_INVALID_DATA
		if not config.has_section_key(INPUT_SECTION, String(action)):
			config.set_value(INPUT_SECTION, String(action), physical_keycode)
			should_save = true
		_apply_key(action, physical_keycode)
	if should_save:
		return config.save(SETTINGS_PATH)
	return OK


static func _apply_key(action: StringName, physical_keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	var key_event: InputEventKey = InputEventKey.new()
	key_event.physical_keycode = physical_keycode
	InputMap.action_add_event(action, key_event)
