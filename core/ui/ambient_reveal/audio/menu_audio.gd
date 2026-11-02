extends AudioStreamPlayer

enum Cue { CLICK, PAGE }

const CLICK: AudioStream = preload("res://core/ui/ambient_reveal/audio/UI_Single_Set 13_01-001.wav")
const PAGE: AudioStream = preload("res://core/ui/ambient_reveal/audio/UI_Swell Down_Set 12_02.wav")

@export_range(-40.0, 0.0) var menu_gain_db: float = -8.0
var _pending: int = -1
var _next_slider_step_ms: int = 0


func slider_step() -> void:
	var now: int = Time.get_ticks_msec()
	if now >= _next_slider_step_ms:
		_next_slider_step_ms = now + 85
		click()


func click() -> void:
	_queue(Cue.CLICK)


func page() -> void:
	_queue(Cue.PAGE)


func _queue(cue: Cue) -> void:
	# A button that changes the active tab should only play the page sound.
	if _pending == -1:
		_play_pending.call_deferred()
	_pending = maxi(_pending, cue)


func _play_pending() -> void:
	var cue: int = _pending
	_pending = -1
	match cue:
		Cue.CLICK:
			stream = CLICK
			volume_db = menu_gain_db - 3.0
		Cue.PAGE:
			stream = PAGE
			volume_db = menu_gain_db - 2.0
	play()
