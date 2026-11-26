extends Control
## Pixel-space sight and short confirmation marks, independent of the thermal pass.
var wide: bool = false
var hit_flash: float = 0.0
var kick: float = 0.0

func _draw() -> void:
	var center: Vector2 = size*0.5
	var gap: float = (18.0 if wide else 8.0)+kick*9.0
	for ink: Color in [Color(0.05,0.1,0.1,0.8),Color("#e9fff4")]:
		var width: float = 4.0 if ink.r < 0.1 else 1.6
		if wide:
			draw_arc(center,gap,0,TAU,52,ink,width,true)
		for direction: Vector2 in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
			draw_line(center+direction*(gap+3),center+direction*(gap+15),ink,width,true)
	draw_circle(center,2.0,Color.WHITE)
	if hit_flash > 0:
		for i: int in range(4):
			var ray: Vector2 = Vector2.RIGHT.rotated(PI*(0.25+0.5*i))
			draw_line(center+ray*7,center+ray*14,Color("#ffba56"),3.0,true)
