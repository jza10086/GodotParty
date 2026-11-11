## Persistent native ENet RTT display. Traffic staleness never changes simulation speed.
extends Label

@export var connection: Node

func _ready() -> void:
	assert(connection != null, "Network status requires the app connection")
	connection.changed.connect(_refresh)
	connection.stats_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	visible = connection.online and connection.room.get("phase") != "lobby"
	if not visible:
		return
	if connection.host:
		text = "HOST · 实验" if connection.is_network_lab_active() else "HOST"
		tooltip_text = "房主 · 按住 Tab 查看玩家与延迟"
		modulate = Color.WHITE
		return
	var sample: Dictionary = connection.get_peer_stats(1)
	var state: String = sample.state
	text = "%d ms" % roundi(sample.rtt_msec) if sample.has("rtt_msec") and state != "stalled" else "… ms"
	if state == "stalled":
		text += " · 无响应"
	elif state == "degraded":
		text += " · 波动"
	modulate = Color("#f3b960") if state in ["stalled", "degraded"] else Color.WHITE
	tooltip_text = "到房主的往返延迟 RTT · 按住 Tab 查看玩家列表"
	if connection.is_network_lab_active():
		text += " · 实验"
		tooltip_text += " · 本机网络实验已启用"
	if sample.has("jitter_msec"):
		tooltip_text += " · 波动 %d ms · 最近通信 %d ms 前" % [roundi(sample.jitter_msec), sample.age_msec]
