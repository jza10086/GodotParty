## Xbox gestures follow Ambient Reveal. Navigation resolves against the current Party page or modal.
extends Control

const Workspace = preload("res://core/ui/settings/settings_workspace.gd")
const Section = preload("res://core/ui/settings/setting_section.gd")
const HintStrip = preload("res://core/ui/ambient_reveal/components/navigation/xbox_hints.gd")
const PadKeyboard = preload("res://core/ui/ambient_reveal/pad_keyboard.gd")
const PAD_DIRECTIONS: Array[StringName] = [&"ui_left", &"ui_up", &"ui_right", &"ui_down"]
const PAD_REPEAT_ACTIONS: Array[StringName] = [&"ui_left", &"ui_up", &"ui_right", &"ui_down", &"ambient_previous_tab", &"ambient_next_tab"]
const PAD_REPEAT_DELAY: float = 0.40
const PAD_REPEAT_INTERVAL: float = 0.12
const CURSOR_DEADZONE: float = 0.22
const CURSOR_SPEED: float = 1150.0
const CURSOR_EVENT_DEVICE: int = -42
enum InputSource { MOUSE, KEYBOARD, GAMEPAD, PAD_CURSOR }

@onready var _hints: HintStrip = %InputHints
var _hint_scope: Control
var _hint_hover: Control
@onready var _keyboard: PadKeyboard = %PadKeyboard
var _source: InputSource = InputSource.MOUSE
var _pad_device: int = -1
var _repeat_action: StringName
var _repeat_remaining: float
var _repeat_viewport: Viewport
var _repeat_event: InputEvent
var _repeat_scope: Control
var _adjusting_slider: Slider
var _masked_parent: Control
var _previous_focus_behavior: Control.FocusBehaviorRecursive
var _cursor_position: Vector2
var _last_warp: Vector2i
var _cursor_mask: int = 0
var _accept_pad_bindings: Array[InputEvent] = []
@onready var _initial_mouse_mode: Input.MouseMode = Input.mouse_mode
@export var app: Control

func initialize() -> void:
	assert(app != null, "UI navigation requires the application shell")
	_hints.set_mode(false, false)
	app.catalog.i18n.changed.connect(_refresh_hints)
	_keyboard.key_pressed.connect(app._ui_audio.click)
	_keyboard.closed.connect(func() -> void:
		if is_instance_valid(_masked_parent):
			_masked_parent.focus_behavior_recursive = _previous_focus_behavior)
	Input.joy_connection_changed.connect(_on_pad_connection)
	get_viewport().gui_focus_changed.connect(func(focus: Control) -> void:
		if is_instance_valid(_adjusting_slider) and focus != _adjusting_slider:
			_end_slider_adjustment()
		_refresh_hints.call_deferred())
	get_tree().node_added.connect(_watch_window)
	for window: Node in app.find_children("*", "Window", true, false):
		_watch_window(window)

func _watch_window(node: Node) -> void:
	if node is Window and app.is_ancestor_of(node):
		var observe: Callable = _window_input.bind(node)
		if node.window_input.is_connected(observe):
			return
		node.window_input.connect(observe)
		node.visibility_changed.connect(func() -> void: _repeat_action = &"")

func _window_input(event: InputEvent, window: Window) -> void:
	if app.navigation_scope() != null:
		_observe_input(event, window)

func _input(event: InputEvent) -> void:
	if app.navigation_scope() == null:
		return
	_observe_input(event, get_viewport())
	if event is InputEventMouseButton or event is InputEventJoypadButton or event is InputEventKey:
		_refresh_hints.call_deferred()
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	var was_editing: bool = _keyboard.visible or is_instance_valid(_adjusting_slider)
	if _source == InputSource.GAMEPAD or _keyboard.visible:
		_handle_pad_edit(event)
	if event.is_action_pressed(&"ui_cancel"):
		if not was_editing:
			var workspace: Workspace = _workspace(app.navigation_scope())
			if _source == InputSource.PAD_CURSOR and workspace != null and workspace.inside_category_content(get_viewport().gui_get_focus_owner()):
				workspace.focus_selected_category()
			else:
				app.navigation_back()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ambient_home") and not was_editing:
		_home()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ambient_context_menu") and _source == InputSource.GAMEPAD and not _keyboard.visible:
		var focus: Control = get_viewport().gui_get_focus_owner()
		var section: Section = _fold_target(focus, app.navigation_scope())
		if section != null and not was_editing:
			section.toggle_fold()
			app._ui_audio.click()
		elif focus != null and not was_editing:
			_cursor_position = focus.get_global_rect().get_center()
			_cursor_button(MOUSE_BUTTON_RIGHT, true)
			_cursor_button(MOUSE_BUTTON_RIGHT, false)
		get_viewport().set_input_as_handled()

## A child row owns its input even when it has no children of its own.
func _fold_target(control: Control, scope: Control) -> Section:
	if control == null or scope == null or not scope.is_ancestor_of(control):
		return null
	var ancestor: Node = control
	while ancestor != scope:
		if ancestor is Section:
			return ancestor if ancestor.owns_fold_target(control) else null
		ancestor = ancestor.get_parent()
	return null

func _refresh_hints() -> void:
	var scope: Control = app.navigation_scope()
	if scope == null:
		return
	var cursor: bool = _source == InputSource.PAD_CURSOR
	var field: Control = get_viewport().gui_get_hovered_control() if cursor else get_viewport().gui_get_focus_owner()
	var section: Section = _fold_target(field, scope)
	var fold: String = ""
	var on_header: bool = false
	if section != null:
		fold = "收起面板" if section.is_expanded() else "展开面板"
		on_header = field == section.get_node("%Header")
	var workspace: Workspace = _workspace(scope)
	var back_to_tabs: bool = cursor and workspace != null and workspace.inside_category_content(get_viewport().gui_get_focus_owner())
	_hints.set_context(fold, on_header, workspace != null, back_to_tabs, is_instance_valid(_adjusting_slider), _keyboard.visible, cursor, field)
	var keyboard_text: Dictionary = {
		"Title": "键盘与鼠标", "Navigate/Action": "移动焦点",
		"Next/Action": "切换焦点", "Previous/Action": "切换焦点", "Back/Action": "返回",
		"Accept/Action": fold if on_header else "确认"
	}
	for path: String in keyboard_text:
		_hints.get_node("KeyboardHints/" + path).text = app.catalog.i18n.text("core", keyboard_text[path])

func _track_pad_repeat(event: InputEvent, viewport: Viewport) -> void:
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	if _source not in [InputSource.GAMEPAD, InputSource.PAD_CURSOR] or event.device != _pad_device:
		return
	var main: bool = viewport == get_viewport()
	# PopupMenu and popup sliders implement their own native joypad repeat.
	if not main and (viewport is PopupMenu or viewport.gui_get_focus_owner() is Slider):
		_repeat_action = &""
		return
	for action in PAD_REPEAT_ACTIONS:
		if not event.is_action_pressed(action, false, true):
			continue
		if action not in PAD_DIRECTIONS and (not main or _keyboard.visible or _adjusting_slider != null):
			_repeat_action = &""
			return
		if event is InputEventJoypadButton or Input.is_action_just_pressed_by_event(action, event, true):
			_repeat_action = action
			_repeat_viewport = viewport
			_repeat_scope = app.navigation_scope()
			_repeat_event = event
			_repeat_remaining = PAD_REPEAT_DELAY
			if main:
				_dispatch_pad_step(action, viewport)
		if main:
			viewport.set_input_as_handled()
		return
	if event is InputEventJoypadButton and event.pressed:
		_repeat_action = &""


func _repeat_is_held() -> bool:
	if _repeat_event is InputEventJoypadButton:
		return Input.is_joy_button_pressed(_repeat_event.device, _repeat_event.button_index)
	var stick: InputEventJoypadMotion = _repeat_event as InputEventJoypadMotion
	var strength: float = Input.get_joy_axis(stick.device, stick.axis) * signf(stick.axis_value)
	return strength > InputMap.action_get_deadzone(_repeat_action)


func _handle_pad_edit(event: InputEvent) -> void:
	var viewport: Viewport = get_viewport()
	if _keyboard.visible:
		if event.is_action_pressed(&"ui_cancel"):
			viewport.set_input_as_handled()
			app._ui_audio.click()
			_keyboard.finish(false)
		return
	var field: Control = viewport.gui_get_focus_owner()
	if not (field is Slider or field is LineEdit or field is TextEdit):
		return
	if event.is_action_pressed(&"ui_accept") and field.editable:
		viewport.set_input_as_handled()
		app._ui_audio.click()
		if field is Slider:
			if _adjusting_slider == field:
				_end_slider_adjustment()
			else:
				_adjusting_slider = field
		else:
			move_to_front()
			_keyboard.open_for(field)
			_masked_parent = app.navigation_scope()
			_previous_focus_behavior = _masked_parent.focus_behavior_recursive
			_masked_parent.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
		return
	if _adjusting_slider != null and event.is_action_pressed(&"ui_cancel"):
		viewport.set_input_as_handled()
		_end_slider_adjustment()
		app._ui_audio.click()
		return


func _dispatch_pad_step(action: StringName, viewport: Viewport) -> void:
	var side: int = PAD_DIRECTIONS.find(action)
	if viewport == get_viewport():
		if side < 0:
			_change_category(-1 if action == &"ambient_previous_tab" else 1)
			return
		if _keyboard.visible:
			_keyboard.move_focus(side as Side)
			return
		if not is_instance_valid(_adjusting_slider):
			_move_focus(side as Side)
			return
		if (side in [SIDE_LEFT, SIDE_RIGHT]) != (_adjusting_slider is HSlider):
			return
	var step: InputEventAction = InputEventAction.new()
	step.action = action
	step.pressed = true
	viewport.push_input(step)

func _workspace(scope: Control) -> Workspace:
	for workspace: Workspace in get_tree().get_nodes_in_group(&"settings_workspace"):
		if workspace.is_visible_in_tree() and (workspace == scope or scope.is_ancestor_of(workspace)):
			return workspace
	return null

func _change_category(direction: int) -> bool:
	var workspace: Workspace = _workspace(app.navigation_scope())
	if workspace == null:
		return false
	workspace.pad_category(direction, _source == InputSource.PAD_CURSOR)
	if _source == InputSource.GAMEPAD:
		_focus_first(workspace)
	return true

func _home() -> void:
	var scope: Control = app.navigation_scope()
	var workspace: Workspace = _workspace(scope)
	if workspace != null and _source == InputSource.PAD_CURSOR:
		workspace.pad_category(0, true)
	else:
		_focus_first(scope)

func focus_settings_on_open(workspace: Workspace) -> void:
	if _source == InputSource.GAMEPAD:
		_focus_first(workspace)
	else:
		workspace.focus_back()

func _can_focus(control: Control) -> bool:
	if not control.is_visible_in_tree() or control.get_focus_mode_with_override() != FOCUS_ALL:
		return false
	if control is BaseButton:
		return not control.disabled
	if control is LineEdit or control is TextEdit or control is Slider:
		return control.editable
	return not control is ScrollBar and not control is ScrollContainer

func _focus_targets(scope: Control) -> Array[Control]:
	var targets: Array[Control] = []
	for node: Control in scope.find_children("*", "Control", true, false):
		var item: Control = node.get_line_edit() if node is SpinBox else node
		if item.get_viewport() == get_viewport() and _can_focus(item) and not targets.has(item):
			targets.append(item)
	return targets

func _focus_first(scope: Control) -> void:
	var targets: Array[Control] = _focus_targets(scope)
	var workspace: Workspace = _workspace(scope)
	if _source == InputSource.GAMEPAD and workspace != null:
		workspace.focus_pad_target(workspace.first_pad_target(targets))
	elif not targets.is_empty():
		targets[0].grab_focus()

func _lobby_card(item: Control, scope: Control) -> Control:
	var ancestor: Node = item
	while ancestor != scope:
		if ancestor.is_in_group(&"lobby_card"):
			return ancestor as Control
		ancestor = ancestor.get_parent()
	return null

## Prefer controls in the same row or column. Scroll containers reveal the chosen control,
## including rows that currently lie outside the visible portion of the settings list.
func _move_focus(side: Side) -> void:
	var scope: Control = app.navigation_scope()
	var focus: Control = get_viewport().gui_get_focus_owner()
	var workspace: Workspace = _workspace(scope)
	if workspace != null and _source == InputSource.GAMEPAD:
		workspace.focus_pad_target(workspace.pad_neighbor(focus, side, _focus_targets(workspace)))
		return
	if focus == null or not scope.is_ancestor_of(focus) or not _can_focus(focus):
		_focus_first(scope)
		return
	var axis: Vector2 = [Vector2.LEFT, Vector2.UP, Vector2.RIGHT, Vector2.DOWN][side]
	var start: Rect2 = focus.get_global_rect()
	var best: Control
	var score: float = INF
	var from_card: Control = _lobby_card(focus, scope)
	for candidate: Control in _focus_targets(scope):
		if candidate == focus:
			continue
		var rect: Rect2 = candidate.get_global_rect()
		var offset: Vector2 = rect.get_center() - start.get_center()
		var forward: float = offset.dot(axis)
		if forward <= 1.0:
			continue
		if from_card != null:
			var to_card: Control = _lobby_card(candidate, scope)
			var origin: Rect2 = from_card.get_global_rect() if to_card != from_card else start
			var target: Rect2 = to_card.get_global_rect() if to_card != null and to_card != from_card else rect
			var advance: float = (target.get_center() - origin.get_center()).dot(axis)
			if advance < (target.size + origin.size).dot(axis.abs()) * 0.5 - 1.0:
				continue
		var cross: float = absf(offset.dot(axis.orthogonal()))
		var half_span: float = (rect.size + start.size).dot(axis.orthogonal().abs()) * 0.5
		var distance: float = forward + 0.7 * cross + 5.0 * maxf(0.0, cross - half_span)
		if distance < score:
			score = distance
			best = candidate
	if best != null:
		best.grab_focus()
		var ancestor: Node = best.get_parent()
		while ancestor != scope:
			if ancestor is ScrollContainer:
				ancestor.ensure_control_visible(best)
			ancestor = ancestor.get_parent()

func _end_slider_adjustment() -> void:
	_repeat_action = &""
	_adjusting_slider = null

func _observe_input(event: InputEvent, viewport: Viewport) -> void:
	if event.device == CURSOR_EVENT_DEVICE:
		return
	var next: InputSource = _source
	if event is InputEventJoypadButton:
		if _source == InputSource.PAD_CURSOR and event.device == _pad_device:
			if event.button_index in [JOY_BUTTON_A, JOY_BUTTON_X]:
				viewport.set_input_as_handled()
				if event.button_index == JOY_BUTTON_X and viewport == get_viewport() and not _keyboard.visible and not (_cursor_mask & MOUSE_BUTTON_MASK_RIGHT):
					var section: Section = _fold_target(viewport.gui_get_hovered_control(), app.navigation_scope())
					if section != null:
						if event.pressed:
							section.toggle_fold()
							app._ui_audio.click()
						return
				var button: MouseButton = MOUSE_BUTTON_LEFT if event.button_index == JOY_BUTTON_A else MOUSE_BUTTON_RIGHT
				_cursor_button(button, event.pressed)
				return
			if event.button_index not in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]:
				if event.pressed:
					_track_pad_repeat(event, viewport)
				return
		if not event.pressed:
			return
		next = InputSource.GAMEPAD
	elif event is InputEventJoypadMotion:
		if event.axis in [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
			if absf(event.axis_value) <= CURSOR_DEADZONE:
				return
			next = InputSource.PAD_CURSOR
		elif event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y] and absf(event.axis_value) > InputMap.action_get_deadzone(&"ui_left"):
			next = InputSource.GAMEPAD
		else:
			return
	elif event is InputEventKey and event.pressed:
		if _keyboard.visible and event.is_action_pressed(&"ui_cancel"):
			_keyboard.finish(false)
			viewport.set_input_as_handled()
		next = InputSource.KEYBOARD
	elif (event is InputEventMouseMotion and not event.relative.is_zero_approx()) or (event is InputEventMouseButton and event.pressed):
		if event is InputEventMouseMotion and _source == InputSource.PAD_CURSOR and DisplayServer.mouse_get_position() == _last_warp:
			return # Motion generated by warping the system cursor.
		next = InputSource.MOUSE
	else:
		return
	if next in [InputSource.GAMEPAD, InputSource.PAD_CURSOR]:
		if _pad_device != event.device:
			_repeat_action = &""
		_pad_device = event.device
	_set_input_source(next)
	if not is_pointer() and viewport == get_viewport() and not _keyboard.visible:
		var scope: Control = app.navigation_scope()
		var focus: Control = viewport.gui_get_focus_owner()
		var workspace: Workspace = _workspace(scope)
		var invalid: bool = focus == null or (_source == InputSource.GAMEPAD and workspace != null and workspace.in_tab_strip(focus))
		# A direction event already supplies an entry point. Priming focus here as well would
		# move twice when coming from a mouse-selected tab or after a row disappeared.
		if invalid and not PAD_REPEAT_ACTIONS.any(func(action: StringName) -> bool: return event.is_action_pressed(action)):
			_focus_first(scope)
	_track_pad_repeat(event, viewport)


func _set_input_source(next: InputSource) -> void:
	if _source == next:
		return
	_repeat_action = &""
	if _source == InputSource.PAD_CURSOR:
		_end_cursor()
	_end_slider_adjustment()
	if _keyboard.visible and next == InputSource.KEYBOARD:
		_keyboard.finish(true, false)
		var field: Control = get_viewport().gui_get_focus_owner()
		if field is LineEdit:
			field.edit()
	_source = next
	if _keyboard.visible:
		_keyboard.set_pointer_mode(is_pointer())
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if next == InputSource.GAMEPAD else Input.MOUSE_MODE_VISIBLE
	var cursor: bool = next == InputSource.PAD_CURSOR
	if cursor:
		_cursor_position = get_viewport().get_mouse_position()
		_last_warp = DisplayServer.mouse_get_position()
		# PopupMenu handles ui_accept before GUI input. Let only the synthetic click activate it.
		for binding in InputMap.action_get_events(&"ui_accept"):
			if binding is InputEventJoypadButton and binding.button_index == JOY_BUTTON_A:
				_accept_pad_bindings.append(binding)
				InputMap.action_erase_event(&"ui_accept", binding)
	get_tree().call_group(&"ambient_feedback", &"set_pointer_mode", is_pointer())
	_hints.set_mode(next == InputSource.GAMEPAD or cursor, cursor)
	_refresh_hints()

func is_pointer() -> bool:
	return _source in [InputSource.MOUSE, InputSource.PAD_CURSOR]


func _process(delta: float) -> void:
	var scope: Control = app.navigation_scope()
	var hover: Control = get_viewport().gui_get_hovered_control() if _source == InputSource.PAD_CURSOR else null
	if scope != _hint_scope or hover != _hint_hover or %HintMargin.visible != (scope != null):
		_hint_scope = scope
		_hint_hover = hover
		%HintMargin.visible = scope != null
		_refresh_hints()
	if _source in [InputSource.GAMEPAD, InputSource.PAD_CURSOR]:
		if _keyboard.visible and (not is_instance_valid(_masked_parent) or _masked_parent != scope):
			_keyboard.finish(false)
		if scope == null:
			_set_input_source(InputSource.MOUSE)
			return
		if scope != _repeat_scope:
			_repeat_action = &""
	if _repeat_action != &"":
		if not _repeat_is_held():
			_repeat_action = &""
		else:
			_repeat_remaining -= delta
			if _repeat_remaining <= 0.0:
				_repeat_remaining = PAD_REPEAT_INTERVAL
				_dispatch_pad_step(_repeat_action, _repeat_viewport)
	if _source != InputSource.PAD_CURSOR:
		return
	var stick: Vector2 = Vector2(Input.get_joy_axis(_pad_device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(_pad_device, JOY_AXIS_RIGHT_Y))
	var speed: float = clampf(inverse_lerp(CURSOR_DEADZONE, 1.0, stick.length()), 0.0, 1.0)
	if speed == 0.0:
		return
	var previous: Vector2 = _cursor_position
	var bounds: Rect2 = get_viewport_rect()
	_cursor_position = (_cursor_position + stick.normalized() * speed * speed * CURSOR_SPEED * delta).clamp(bounds.position, bounds.end - Vector2.ONE)
	if previous.round() == _cursor_position.round():
		return
	get_viewport().warp_mouse(_cursor_position.round())
	_last_warp = DisplayServer.mouse_get_position()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.device = CURSOR_EVENT_DEVICE
	motion.position = _cursor_position
	motion.global_position = _cursor_position
	motion.relative = _cursor_position.round() - previous.round()
	motion.button_mask = _cursor_mask
	get_viewport().push_input(motion, true)


func _cursor_button(button: MouseButton, pressed: bool) -> void:
	var bit: int = 1 << (int(button) - 1)
	if ((_cursor_mask & bit) != 0) == pressed:
		return
	_cursor_mask = (_cursor_mask | bit) if pressed else (_cursor_mask & ~bit)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.device = CURSOR_EVENT_DEVICE
	click.position = _cursor_position
	click.global_position = _cursor_position
	click.button_index = button
	click.button_mask = _cursor_mask
	click.pressed = pressed
	get_viewport().push_input(click, true)


func _end_cursor() -> void:
	_cursor_button(MOUSE_BUTTON_LEFT, false)
	_cursor_button(MOUSE_BUTTON_RIGHT, false)
	for binding in _accept_pad_bindings:
		InputMap.action_add_event(&"ui_accept", binding)
	_accept_pad_bindings.clear()


func _exit_tree() -> void:
	if _keyboard.visible and is_instance_valid(_masked_parent):
		_masked_parent.focus_behavior_recursive = _previous_focus_behavior
	if _source == InputSource.PAD_CURSOR:
		_end_cursor()
	Input.mouse_mode = _initial_mouse_mode


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _source in [InputSource.GAMEPAD, InputSource.PAD_CURSOR]:
		_set_input_source(InputSource.KEYBOARD)


func _on_pad_connection(device: int, connected: bool) -> void:
	if not connected and device == _pad_device:
		_pad_device = -1
		if _source in [InputSource.GAMEPAD, InputSource.PAD_CURSOR]:
			_set_input_source(InputSource.KEYBOARD)


