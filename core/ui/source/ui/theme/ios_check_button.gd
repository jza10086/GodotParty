@tool
extends CheckButton
## Native CheckButton interaction and row styling, with a sliding iOS indicator.
## Explicit per-node icon, color, and style overrides still take precedence.
const Config = preload("res://core/ui/source/ui/theme/ui_config.gd")
const SwitchGraphics = preload("res://core/ui/source/ui/theme/switch_graphics.gd")
const GeneratedTexture = preload("res://core/ui/source/ui/theme/generated_switch_texture.gd")
const ICON_NAMES := ["checked", "unchecked", "checked_disabled", "unchecked_disabled", "checked_mirrored", "unchecked_mirrored", "checked_disabled_mirrored", "unchecked_disabled_mirrored"]

@export var use_global_colors := true:
	set(value):
		use_global_colors = value
		_refresh_graphics()
@export var configuration: Config = preload("res://core/ui/source/ui/theme/ui_config.tres"):
	set(value):
		_disconnect_config()
		configuration = value
		_connect_config()
		_refresh_graphics()
@export var switch_size := Vector2i(102, 62):
	set(value):
		switch_size = Vector2i(maxi(value.x, 2), maxi(value.y, 2))
		_refresh_graphics()
@export_range(0.0, 1.0, 0.01) var duration := 0.20
@export var off_color := Color("#b8b8bd"):
	set(value):
		off_color = value
		_refresh_graphics()
@export var on_color := Color("#478cbf"):
	set(value):
		on_color = value
		_refresh_graphics()
@export var thumb_color := Color.WHITE:
	set(value):
		thumb_color = value
		_refresh_graphics()
@export var border_color := Color("#8b9299"):
	set(value):
		border_color = value
		_refresh_graphics()
@export_range(0.0, 1.0, 0.01) var disabled_opacity := 0.45:
	set(value):
		disabled_opacity = value
		_refresh_graphics()

var _slide := 0.0:
	set(value):
		_slide = value
		_refresh_graphics()
var _target := -1.0
var _initialized := false
var _tween: Tween
var _frames: Dictionary = {}
# Exact raster inputs retained for diagnostics; renderer-backed textures stay stable.
var _frame_images: Dictionary = {}
var _graphics_key: Array = []
var _generated_icons: Dictionary = {}
var _installing_icons := false

func _enter_tree() -> void:
	_connect_config()
	# Re-entered nodes keep their signals but must not resume a stale animation.
	if _initialized: sync_visual(false)

func _ready() -> void:
	if not toggled.is_connected(_on_toggled): toggled.connect(_on_toggled)
	if not theme_changed.is_connected(_install_icons): theme_changed.connect(_install_icons)
	sync_visual(false)

func _process(_delta: float) -> void:
	# Native set_pressed_no_signal() is not virtual. Observe its value without
	# synthesizing a toggled signal or restarting user-triggered animation.
	var target := 1.0 if button_pressed else 0.0
	if not is_equal_approx(target, _target): sync_visual(false)

func _on_toggled(_value: bool) -> void:
	sync_visual(true)

func sync_visual(animate: bool = true) -> void:
	var target := 1.0 if button_pressed else 0.0
	if _initialized and is_equal_approx(target, _target) and animate: return
	if _tween:
		_tween.kill()
		_tween = null
	_target = target
	if animate and _initialized and duration > 0.0 and is_inside_tree() and is_visible_in_tree():
		_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "_slide", target, duration)
	else:
		_slide = target
	_initialized = true
	_refresh_graphics()

func _connect_config() -> void:
	if is_inside_tree() and configuration != null and not configuration.changed.is_connected(_refresh_graphics):
		configuration.changed.connect(_refresh_graphics)

func _disconnect_config() -> void:
	if configuration != null and configuration.changed.is_connected(_refresh_graphics):
		configuration.changed.disconnect(_refresh_graphics)

func _refresh_graphics() -> void:
	if not _initialized or not is_inside_tree(): return
	var global_colors := use_global_colors and configuration != null
	var off: Color = configuration.toggle_off if global_colors else off_color
	var on: Color = configuration.toggle_on if global_colors else on_color
	var thumb: Color = configuration.toggle_thumb if global_colors else thumb_color
	var border: Color = configuration.toggle_border if global_colors else border_color
	var dim: float = configuration.disabled_opacity if global_colors else disabled_opacity
	var graphics_key := [_slide, switch_size, off, on, thumb, border, dim]
	if graphics_key == _graphics_key: return
	_graphics_key = graphics_key
	# Four persistent textures cover enabled/disabled and LTR/RTL. Both native
	# checked states reference the same current frame, so reversing is seamless.
	var normal := SwitchGraphics.image(_slide, switch_size, off, on, thumb, border)
	var disabled_pixels := normal.get_data()
	for alpha_index in range(3, disabled_pixels.size(), 4):
		disabled_pixels[alpha_index] = roundi(disabled_pixels[alpha_index] * clampf(dim, 0.0, 1.0))
	var disabled_image := Image.create_from_data(switch_size.x, switch_size.y, false, Image.FORMAT_RGBA8, disabled_pixels)
	var mirrored: Image = normal.duplicate()
	mirrored.flip_x()
	var disabled_mirrored: Image = disabled_image.duplicate()
	disabled_mirrored.flip_x()
	var images := {"normal": normal, "disabled": disabled_image, "mirrored": mirrored, "disabled_mirrored": disabled_mirrored}
	_frame_images = images
	var dimensions_changed := false
	for key in images:
		var pixels: Image = images[key]
		if _frames.has(key):
			var frame: ImageTexture = _frames[key]
			if frame.get_size() == Vector2(switch_size): frame.update(pixels)
			else:
				frame.set_image(pixels)
				dimensions_changed = true
		else:
			var frame := GeneratedTexture.new()
			frame.set_image(pixels)
			_frames[key] = frame
	_install_icons()
	if dimensions_changed:
		# CheckButton caches horizontal icon padding on theme changes. Preserve
		# texture identity while refreshing that cache after an authored resize.
		notification(NOTIFICATION_THEME_CHANGED)
		update_minimum_size()
	queue_redraw()

func _install_icons() -> void:
	if _installing_icons or _frames.is_empty() or not is_inside_tree(): return
	_installing_icons = true
	begin_bulk_theme_override()
	for icon_name in ICON_NAMES:
		# Preserve user textures by identity. Empty saved marker resources are
		# our own generated overrides, so replace them with fresh local frames.
		if has_theme_icon_override(icon_name):
			var current := get_theme_icon(icon_name)
			if current != _generated_icons.get(icon_name) and current.get_script() != GeneratedTexture: continue
		var key := "disabled" if icon_name.contains("disabled") else "normal"
		if icon_name.ends_with("mirrored"): key = "disabled_mirrored" if key == "disabled" else "mirrored"
		var frame: ImageTexture = _frames[key]
		_generated_icons[icon_name] = frame
		if not has_theme_icon_override(icon_name) or get_theme_icon(icon_name) != frame:
			add_theme_icon_override(icon_name, frame)
	end_bulk_theme_override()
	_installing_icons = false

func _exit_tree() -> void:
	if _tween:
		_tween.kill()
		_tween = null
	_disconnect_config()
