@tool
extends Node2D
## 本机 2D 航标样例。场景保存地图、船、三个航标和 HUD，脚本只负责切换目标。
@onready var hud: CanvasLayer = %DemoHUD
@onready var _boat: Polygon2D = %Boat
@onready var _beacons: Array[Node2D] = [%West, %North, %East]
var input_allowed: Callable
var _index: int = 0
var _motion: Tween
var caption: String = "航标"

func _ready() -> void:
	visibility_changed.connect(_sync_visibility)
	_sync_visibility()
	if not Engine.is_editor_hint():
		%NextBeacon.pressed.connect(_advance)

func _sync_visibility() -> void:
	hud.visible = is_visible_in_tree()

func localize(i18n: RefCounted) -> void:
	caption = i18n.text(&"game.beacon")
	%DemoTitle.text = i18n.text(&"game.channel")
	%NextBeacon.text = i18n.text(&"game.next_beacon")
	%BeaconStatus.text = "%s  %d / %d" % [caption, _index + 1, _beacons.size()]

func _advance() -> void:
	if input_allowed.is_valid() and not input_allowed.call():
		return
	_index = (_index + 1) % _beacons.size()
	if _motion != null:
		_motion.kill()
	var destination: Vector2 = _beacons[_index].position
	_boat.rotation = (destination - _boat.position).angle()
	_motion = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_motion.tween_property(_boat, "position", destination, 0.55)
	%BeaconStatus.text = "%s  %d / %d" % [caption, _index + 1, _beacons.size()]
