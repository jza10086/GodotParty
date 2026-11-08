## 原版协议二维头像表现：保留原图颜色与宽高比，底部标记表达玩家颜色。
## 无移动、输入、碰撞或网络逻辑，原点位于表现底部。
extends Node2D
@export var portrait: Texture2D
@export_range(16.0, 256.0) var display_size: float = 76.0
var _player_color: Color = Color("#478cbf")

func _ready() -> void:
	assert(portrait != null, "原版头像必须指定源图片")
	queue_redraw()

## 可以在入树前调用；颜色不污染原图或其他玩家实例。
func apply_color(value: Color) -> void:
	_player_color = value
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2(0.0, -5.0), 12.0, _player_color)
	if portrait == null:
		return
	var original: Vector2 = portrait.get_size()
	var displayed: Vector2 = original * (display_size / maxf(original.x, original.y))
	draw_texture_rect(portrait, Rect2(Vector2(-displayed.x * 0.5, -16.0 - displayed.y), displayed), false)
