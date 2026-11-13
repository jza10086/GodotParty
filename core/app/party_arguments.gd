## Development arguments only select inputs to the formal app; there is no alternate runner.
extends RefCounted

static func read() -> Dictionary:
	var result: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--party-"):
			var pair: PackedStringArray = argument.trim_prefix("--party-").split("=", true, 1)
			result[pair[0]] = pair[1] if pair.size() > 1 else true
	return result
