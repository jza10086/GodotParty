extends RefCounted

const CONTROLS: Dictionary[String, String] = {
	"ac130_pulse": "发射脉冲", "ac130_polarity": "切换黑热与白热", "ac130_zoom": "切换倍率"
}

static func party_definition() -> Dictionary:
	return {"player_counts": [1], "controls": CONTROLS.duplicate()}
