## Check the actual client theme and glyph metrics without using device system fonts.
extends SceneTree

func _initialize() -> void:
	call_deferred("_check")

func _check() -> void:
	var scene: PackedScene = load("res://main.tscn") as PackedScene
	var client: Control = scene.instantiate() as Control
	root.add_child(client)
	await process_frame
	var font: FontFile = client.theme.default_font as FontFile
	if font == null or font.allow_system_fallback:
		push_error("Client must use its bundled FontFile without system fallback")
		quit(1)
		return
	var checked: Dictionary[int, bool] = {}
	for path: String in ["res://main.gd", "res://probe_client.gd", "res://probe_protocol.gd"]:
		var text: String = FileAccess.get_file_as_string(path)
		if text.is_empty():
			push_error("Cannot read client source: " + path)
			quit(1)
			return
		for index: int in range(text.length()):
			var codepoint: int = text.unicode_at(index)
			if codepoint < 32 or checked.has(codepoint):
				continue
			checked[codepoint] = true
			if not font.has_char(codepoint):
				push_error("Bundled font is missing U+%04X" % codepoint)
				quit(1)
				return
	for sample: String in ["连接测试", "UDP TCP", "192.168.1.10:7777", "[2001:db8::1]:7777"]:
		var extent: Vector2 = font.get_string_size(sample, HORIZONTAL_ALIGNMENT_LEFT, -1, 28)
		if extent.x <= 0.0 or extent.y <= 0.0:
			push_error("Bundled font returned empty text metrics: " + sample)
			quit(1)
			return
	print("BUNDLED_FONT: PASS (%d source characters; CJK, Latin and endpoint metrics)" % checked.size())
	client.queue_free()
	await process_frame
	quit(0)
