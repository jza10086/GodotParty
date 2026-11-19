## Launch arguments for the formal application.
extends RefCounted

static func read() -> Dictionary:
	var result: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--party-"):
			var pair: PackedStringArray = argument.trim_prefix("--party-").split("=", true, 1)
			result[pair[0]] = pair[1] if pair.size() > 1 else true
	return result

## Explicit platform takes precedence over Steam launch context. An empty result is invalid.
static func platform(arguments: PackedStringArray, steam_app_id: String) -> String:
	var selected: String = ""
	for argument: String in arguments:
		if argument == "--party-platform" or argument.begins_with("--party-platform="):
			var value: String = argument.trim_prefix("--party-platform=")
			if not selected.is_empty() or value not in ["standalone", "steam"]:
				return ""
			selected = value
	if not selected.is_empty():
		return selected
	return "steam" if steam_app_id.to_int() > 0 or arguments.has("+connect_lobby") else "standalone"
