extends Node2D

var _stars: Array[Vector4] = []
var _speeds: Array[Vector2] = []
var _colors: Array[Color] = []

func _ready() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 812
	for index: int in 85:
		_stars.append(Vector4(rng.randf(), rng.randf(), rng.randf_range(0.6, 2.6), rng.randf_range(0.5, 2.0)))
		_speeds.append(Vector2(rng.randf_range(-7.5, 7.5), -rng.randf_range(7.2, 34.2)))
		var tint: Color = Color("#5ed3f3") if rng.randf() > 0.72 else Color("#e2e8f0")
		tint.a = rng.randf_range(0.15, 0.8)
		_colors.append(tint)

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var area: Vector2 = get_parent().size.max(Vector2.ONE)
	for index: int in _stars.size():
		var travel: Vector2 = _speeds[index] * delta / area
		_stars[index].x = fposmod(_stars[index].x + travel.x, 1.0)
		_stars[index].y = fposmod(_stars[index].y + travel.y, 1.0)
	queue_redraw()

func _draw() -> void:
	var area: Vector2 = get_parent().size.max(Vector2.ONE)
	var offset: Vector2 = (get_local_mouse_position() / area - Vector2(0.5, 0.5)).clamp(Vector2(-0.5,-0.5), Vector2(0.5,0.5)) * Vector2(28,20)
	for index: int in _stars.size():
		var star: Vector4 = _stars[index]
		draw_circle(Vector2(star.x, star.y) * area - offset * star.w, star.z, _colors[index], true, -1.0, true)
