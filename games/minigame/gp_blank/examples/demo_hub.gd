extends Control
## Owns local demonstrations and their HUD. The entry owns protocol and ranking.
## Without configure(), F6 uses default translations and session-only audio settings.
signal finish_requested()
signal failed(error: Error)
const DEFAULT_TEXT: Translation = preload("../i18n/zh_Hans.po")
const RandomPool: GDScript = preload("res://games/protocols/godot_party_default_protocol/random/least_played_pool.gd")
const RANDOM_DEMOS: Array[String] = ["graphics", "navigation_2d"]
const GraphicsLab = preload("graphics/graphics_lab.gd")
const NavigationDemo = preload("navigation_2d/navigation_2d.gd")
var _i18n: RefCounted
var _preferences: PartyConfig
var _input_allowed: Callable
var _active: bool = true
@onready var _graphics: GraphicsLab = %GraphicsLab
@onready var _navigation: NavigationDemo = %Navigation2D
@onready var _audio_panel: Control = %AudioPanel
@onready var _hud: CanvasLayer = $GameHUD
@onready var _content: CenterContainer = $GameHUD/Content
@onready var _details: Control = $GameHUD/HUD
@onready var finish_button: Button = %Finish

## Called before tree insertion. Formal settings are owned by the protocol runtime.
func configure(i18n: RefCounted, preferences: PartyConfig, allowed: Callable) -> void:
	_i18n = i18n
	_preferences = preferences
	_input_allowed = allowed
	_active = false
	%GameAudio.prepare_scope()
	%GraphicsLab.protocol_managed = true

func audio_target() -> PartyGameAudio:
	return %GameAudio

func graphics_targets() -> Dictionary:
	return %GraphicsLab.graphics_targets()

func _ready() -> void:
	_audio_panel.failed.connect(func(error: Error) -> void: failed.emit(error))
	_audio_panel.configure(%GameAudio, _i18n, _preferences, _actions_allowed)
	_graphics.orbit_camera.input_allowed = _camera_input_allowed
	_navigation.input_allowed = _controls_allowed
	_navigation.localize(_i18n)
	%SwitchView.pressed.connect(_switch_view)
	finish_button.pressed.connect(_request_finish)
	%SwitchView.text = _text(&"game.show_2d")
	%Title.text = _text(&"空白小游戏")
	%Status.text = _text(&"game.hud_ready" if _preferences != null else &"game.preview")
	%Controls.text = _text(&"game.hud_controls" if _preferences != null else &"game.preview_controls")
	finish_button.text = _text(&"game.finish")
	if _i18n != null:
		finish_button.tooltip_text = _text(&"game.settings_hint") + "\n" + _text(&"game.locale", {"locale": _i18n.effective_locale()})
	_content.hide()
	_hud.visible = _active
	if _preferences == null:
		# Preview never opens a file or creates PartyInput.
		var pool: RandomPool = RandomPool.new(RANDOM_DEMOS)
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.randomize()
		var chosen: String = pool.choose(rng)
		var error: Error = pool.accept_history([chosen])
		if error != OK:
			push_error(error_string(error))
			return
		show_demo(chosen)

func _text(key: StringName, params: Dictionary = {}) -> String:
	return String(DEFAULT_TEXT.get_message(key)).format(params) if _i18n == null else _i18n.text(key, params)

func _actions_allowed() -> bool:
	return _active and (not _input_allowed.is_valid() or _input_allowed.call())

func _controls_allowed() -> bool:
	return _actions_allowed() and not _audio_panel.is_expanded()

func _camera_input_allowed() -> bool:
	return _graphics.visible and _controls_allowed()

func _switch_view() -> void:
	if not _controls_allowed():
		return
	show_demo("graphics" if _navigation.visible else "navigation_2d")

## The entry supplies a validated draw ID; switching locally does not record a draw.
func show_demo(id: String) -> void:
	var show_2d: bool = id == "navigation_2d"
	_navigation.visible = show_2d
	_graphics.visible = not show_2d
	_details.visible = not show_2d
	%SwitchView.text = _text(&"game.show_3d" if show_2d else &"game.show_2d")

func _request_finish() -> void:
	if _controls_allowed() and not finish_button.disabled:
		finish_requested.emit()

func begin_play(can_finish: bool) -> void:
	_active = true
	_hud.show()
	%Status.text = _text(&"game.hud_playing")
	_content.show()
	finish_button.disabled = not can_finish

func wait_for_players() -> void:
	finish_button.disabled = true
	finish_button.text = _text(&"game.waiting")
	%Status.text = _text(&"game.waiting")

## Stop local motion and audio; protocol pages and host coordination remain active.
func stop_demo() -> void:
	_active = false
	_navigation.stop_motion()
	_navigation.hud.hide()
	_graphics.set_process(false)
	%GameAudio.stop_all()
	_audio_panel.close()
	_hud.hide()
	finish_button.disabled = true
