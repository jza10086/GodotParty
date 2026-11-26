extends RefCounted

const CONTROLS: Dictionary[String, String] = {
	"ac130_pulse": "开火", "ac130_polarity": "切换彩色与白热", "ac130_zoom": "切换倍率",
	"ac130_needle": "选择点射器", "ac130_wave": "选择震荡炮", "ac130_reload": "装填"
}

static func party_definition() -> Dictionary:
	return {"player_counts": [1], "controls": CONTROLS.duplicate()}
