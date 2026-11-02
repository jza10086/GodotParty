@tool
extends Button
const Config = preload("res://core/ui/source/ui/theme/ui_config.gd")
const SwitchGraphics = preload("res://core/ui/source/ui/theme/switch_graphics.gd")
## Button-compatible classic iOS switch. The historical file/API name is retained.
## Click anywhere toggles; one tab stop, Space/Enter toggle, Left/Right choose.
@export var use_global_colors := true:
	set(value):
		use_global_colors = value
		queue_redraw()
@export var configuration: Config = preload("res://core/ui/source/ui/theme/ui_config.tres"):
	set(value):
		if configuration != null and configuration.changed.is_connected(queue_redraw): configuration.changed.disconnect(queue_redraw)
		configuration = value
		_connect_config()
		queue_redraw()
@export_range(0.0, 1.0, 0.01) var duration := 0.20
@export var inactive_text_color := Color("19384f"):
	set(value):
		inactive_text_color = value
		queue_redraw()
@export var active_text_color := Color("174d73"):
	set(value):
		active_text_color = value
		queue_redraw()
@export var focus_color := Color("2f6f9f"):
	set(value):
		focus_color = value
		queue_redraw()
## 关闭全局配色后，以下颜色直接控制本地开关；保留完整 RGBA。
@export var off_color := Color("b8b8bd"):
	set(value):
		off_color = value
		queue_redraw()
@export var on_color := Color("478cbf"):
	set(value):
		on_color = value
		queue_redraw()
@export var thumb_color := Color.WHITE:
	set(value):
		thumb_color = value
		queue_redraw()
@export var border_color := Color("8b9299"):
	set(value):
		border_color = value
		queue_redraw()
@export_range(0.0, 1.0, 0.01) var disabled_opacity := 0.45:
	set(value):
		disabled_opacity = value
		queue_redraw()
## 自定义状态文字保留原 API，显示在胶囊外侧，不挤占滑块空间。
@export var off_text := "关":
	set(value):
		off_text = value
		queue_redraw()
@export var on_text := "开":
	set(value):
		on_text = value
		queue_redraw()
var _slide := 0.0:
	set(value):
		_slide = value
		queue_redraw()
var _tween: Tween
var _initialized := false
var _label_themes: Array[Theme] = []
var _graphics_key: Array = []
var _texture: ImageTexture
# Retain the exact CPU source used for uploads (also available on dummy renderers).
var _frame_image: Image

func _connect_config() -> void:
	if is_inside_tree() and configuration != null and not configuration.changed.is_connected(queue_redraw): configuration.changed.connect(queue_redraw)

func _enter_tree() -> void:
	_connect_config()
	if _initialized: sync_visual(false)

func _ready() -> void:
	_connect_config()
	# Native child Theme Overrides remain higher priority than generated colors.
	_label_themes = [Theme.new(), Theme.new()]
	$Off.theme = _label_themes[0]
	$On.theme = _label_themes[1]
	resized.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	toggled.connect(_on_toggled)
	sync_visual(false)

func _on_toggled(_value: bool) -> void:
	sync_visual(true)

func _gui_input(event: InputEvent) -> void:
	if disabled: return
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		button_pressed = event.is_action_pressed("ui_left") if is_layout_rtl() else event.is_action_pressed("ui_right")
		accept_event()

func sync_visual(animate: bool = true) -> void:
	var target := 1.0 if button_pressed else 0.0
	# Model synchronization after toggled must not restart an in-flight tween.
	if animate and _initialized and is_equal_approx(target, get_meta("target", -1.0)): return
	set_meta("target", target)
	if _tween: _tween.kill()
	if animate and _initialized and is_inside_tree() and is_visible_in_tree() and duration > 0:
		_tween = create_tween()
		_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "_slide", target, duration)
	else:
		_slide = target
	_initialized = true
	queue_redraw()

func _exit_tree() -> void:
	if _tween: _tween.kill()
	if configuration != null and configuration.changed.is_connected(queue_redraw): configuration.changed.disconnect(queue_redraw)

func _draw() -> void:
	if not is_node_ready(): return
	# Native silent state updates redraw the Button without emitting toggled.
	if not is_equal_approx(1.0 if button_pressed else 0.0, get_meta("target", -1.0)): sync_visual(false)
	var global_colors := use_global_colors and configuration != null
	var off: Color = configuration.toggle_off if global_colors else off_color
	var on: Color = configuration.toggle_on if global_colors else on_color
	var thumb: Color = configuration.toggle_thumb if global_colors else thumb_color
	var border: Color = configuration.toggle_border if global_colors else border_color
	var opacity: float = (configuration.disabled_opacity if global_colors else disabled_opacity) if disabled else 1.0
	# Scene-authored Track dimensions remain editable. Keep 51:31 geometry even
	# when the parent expands or the texture rect is resized non-uniformly.
	var extent: Vector2 = $Track.size
	var height := maxf(2.0, minf(extent.y, extent.x * 31.0 / 51.0))
	var pixels := Vector2i(roundi(height * 51.0 / 31.0), roundi(height))
	var mirrored := is_layout_rtl()
	var key := [_slide, pixels, off, on, thumb, border, opacity, mirrored]
	if key != _graphics_key:
		var bitmap: Image = SwitchGraphics.image(_slide, pixels, off, on, thumb, border, opacity, mirrored)
		_frame_image = bitmap
		if _texture == null or _texture.get_size() != Vector2(pixels):
			_texture = ImageTexture.create_from_image(bitmap)
			$Track.texture = _texture
		else:
			_texture.update(bitmap)
		_graphics_key = key
	$Off.text = off_text
	$On.text = on_text
	$Off.visible = not button_pressed
	$On.visible = button_pressed
	for index in range(2):
		var selected := button_pressed if index else not button_pressed
		var inactive: Color = configuration.text if global_colors else inactive_text_color
		var active: Color = configuration.toggle_active_text if global_colors else active_text_color
		var color := active if selected else inactive
		color.a *= opacity
		if _label_themes.size() == 2 and (not _label_themes[index].has_color("font_color", "Label") or _label_themes[index].get_color("font_color", "Label") != color):
			_label_themes[index].set_color("font_color", "Label", color)
	if has_focus() or (is_hovered() and not disabled):
		var outline := StyleBoxFlat.new()
		outline.bg_color = Color.TRANSPARENT
		outline.border_color = (configuration.focus if global_colors else focus_color) if has_focus() else (configuration.hover_border if global_colors else focus_color)
		outline.set_border_width_all(3 if has_focus() else 1)
		outline.set_corner_radius_all(roundi(height / 2.0 + 4.0))
		var area := Rect2($Track.position + (extent - Vector2(pixels)) / 2.0, Vector2(pixels)).grow(4)
		draw_style_box(outline, area)
