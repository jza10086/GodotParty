extends RefCounted
## Owns only this activation's bus names. Resolve indices on demand because other scopes can remove buses.
const CHANNELS: Array[String] = ["music", "sfx", "dialogue", "ambience", "ui"]
const KEYS: PackedStringArray = ["audio.master", "audio.music", "audio.sfx", "audio.dialogue", "audio.ambience", "audio.ui"]
var buses: Dictionary[String, StringName] = {}

func open(scope: String) -> void:
	assert(buses.is_empty(), "Audio mixer already open.")
	var root_bus: StringName = StringName("party." + scope + ".GameRoot")
	_add("master", root_bus, &"Master")
	for channel: String in CHANNELS:
		_add(channel, StringName(str(root_bus) + "." + channel), root_bus)

func _add(channel: String, name: StringName, send: StringName) -> void:
	assert(AudioServer.get_bus_index(name) == -1, "Audio scope bus collision.")
	AudioServer.add_bus()
	var index: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, name)
	AudioServer.set_bus_send(index, send)
	buses[channel] = name

func set_volume(channel: String, linear: float) -> void:
	var index: int = AudioServer.get_bus_index(buses[channel])
	AudioServer.set_bus_volume_linear(index, clampf(linear, 0.0, 1.0))
	AudioServer.set_bus_mute(index, linear <= 0.0)

func apply(config: PartyConfig) -> void:
	for key: String in KEYS:
		set_volume(key.trim_prefix("audio."), float(config.get_common(key)))

func close() -> void:
	var channels: Array[String] = buses.keys()
	channels.reverse()
	for channel: String in channels:
		AudioServer.remove_bus(AudioServer.get_bus_index(buses[channel]))
	buses.clear()
