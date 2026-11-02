extends Control
## Transparent presentation only. The external game owns dice, rules and every value.
signal roll_requested
signal item_requested(item_id: String)
signal event_choice_requested(event_id: String, choice_id: String)
signal event_dismissed(event_id: String, reason: String)
signal modal_visibility_changed(open: bool)
const OPTION = preload("res://core/ui/source/ui/components/monopoly_option.tscn")
const RANK = preload("res://core/ui/source/ui/components/monopoly_rank_row.tscn")
const DEFAULTS := {"money": 0, "diamonds": 0, "leaderboard": [], "inventory": [], "roll_enabled": false, "roll_hint": "等待游戏状态", "status": ""}
const EVENT_CONTENT := "EventModal/Center/Dialog/Margin/Content"
var last_error := ""
var _snapshot: Dictionary = DEFAULTS.duplicate(true)
var _event: Dictionary = {}
var _event_generation := 0
var _roll_pending := false
var _item_pending := {}
var _choice_pending := false
var _focus_before_modal: WeakRef
var _inventory_open := false
var _inventory_generation := 0

func _ready() -> void:
	$Roll/Button.pressed.connect(request_roll)
	$Inventory/Toggle.pressed.connect(func(): set_inventory_open(not _inventory_open))
	get_node(EVENT_CONTENT + "/Close").pressed.connect(close_event)
	_render()
	if not _event.is_empty(): _render_event()

func _reject(message: String) -> bool:
	last_error = message
	return false

func _valid_entries(entries: Variant, kind: String, limit: int) -> bool:
	if not entries is Array or entries.size() > limit: return _reject(kind + " 数量或类型无效。")
	var ids := {}
	for entry in entries:
		if not entry is Dictionary: return _reject(kind + " 必须为 Dictionary。")
		if not entry.get("id") is String or entry.id.strip_edges().is_empty() or ids.has(entry.id): return _reject(kind + " ID 必须为唯一非空字符串。")
		ids[entry.id] = true
		var text_key := "name" if kind in ["leaderboard", "inventory"] else "label"
		if not entry.get(text_key) is String: return _reject(kind + " 缺少文案字符串。")
		for key in ["enabled", "is_self"]:
			if entry.has(key) and not entry[key] is bool: return _reject(key + " 必须为 bool。")
		for key in ["reason", "description"]:
			if entry.has(key) and not entry[key] is String: return _reject(key + " 必须为 String。")
		if kind == "leaderboard":
			for key in ["money", "diamonds"]:
				if not entry.get(key) is int or entry[key] < 0: return _reject("排行 " + key + " 必须为非负整数。")
		if kind == "inventory" and (not entry.get("count") is int or entry.count < 0): return _reject("道具 count 必须为非负整数。")
	return true

## Full replacement. Omitted fields take safe defaults; failures are atomic.
func set_snapshot(state: Dictionary) -> bool:
	last_error = ""
	if state.has("actions"): return _reject("actions 已移除；请使用 show_event 的 choices。")
	var next := DEFAULTS.duplicate(true)
	next.merge(state, true)
	for key in ["money", "diamonds"]:
		if not next[key] is int or next[key] < 0: return _reject(key + " 必须为非负整数。")
	if not next.roll_enabled is bool: return _reject("roll_enabled 必须为 bool。")
	for key in ["roll_hint", "status"]:
		if not next[key] is String: return _reject(key + " 必须为 String。")
	if not _valid_entries(next.leaderboard, "leaderboard", 8): return false
	if not _valid_entries(next.inventory, "inventory", 128): return false
	_snapshot = next.duplicate(true)
	_roll_pending = false
	_item_pending.clear()
	if is_node_ready(): _render()
	return true

func get_snapshot() -> Dictionary: return _snapshot.duplicate(true)
func get_event() -> Dictionary: return _event.duplicate(true)
func _patch(patch: Dictionary, reset: String = "") -> bool:
	var pending_roll := _roll_pending
	var pending_items := _item_pending.duplicate()
	var next := get_snapshot()
	next.merge(patch, true)
	if not set_snapshot(next): return false
	if reset != "roll": _roll_pending = pending_roll
	if reset != "inventory": _item_pending = pending_items
	if is_node_ready(): _update_enabled()
	return true
func set_wallet(money: int, diamonds: int) -> bool: return _patch({"money": money, "diamonds": diamonds})
func set_leaderboard(entries: Array) -> bool: return _patch({"leaderboard": entries})
func set_inventory(entries: Array) -> bool: return _patch({"inventory": entries}, "inventory")
func set_roll_enabled(enabled: bool, hint: String = "") -> bool: return _patch({"roll_enabled": enabled, "roll_hint": hint}, "roll")
func set_status(text: String) -> bool: return _patch({"status": text})

func _clear_rows(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
func _format_number(value: int) -> String:
	var digits := str(value)
	var result := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0: result += ","
		result += digits[i]
	return result
func _label(node: Label, value: String) -> void:
	node.text = value
	node.tooltip_text = value
func _render() -> void:
	_label($Wallet/Margin/Values/Money/Value, _format_number(_snapshot.money))
	_label($Wallet/Margin/Values/Diamonds/Value, _format_number(_snapshot.diamonds))
	var ranks := $Leaderboard/Body/Margin/Rows
	_clear_rows(ranks)
	for i in _snapshot.leaderboard.size():
		var entry: Dictionary = _snapshot.leaderboard[i]
		var row = RANK.instantiate()
		ranks.add_child(row)
		_label(row.get_node("Margin/Row/Rank"), "%02d" % (i + 1))
		_label(row.get_node("Margin/Row/Name"), entry.name + (" · 我" if entry.get("is_self", false) else ""))
		_label(row.get_node("Margin/Row/Money/Value"), _format_number(entry.money))
		_label(row.get_node("Margin/Row/Diamonds/Value"), _format_number(entry.diamonds))
	if _snapshot.leaderboard.is_empty(): _empty(ranks, "暂无排行")
	_inventory_generation += 1
	var inventory := $Inventory/Body/Margin/Scroll/Items
	_clear_rows(inventory)
	for entry in _snapshot.inventory:
		var button := _option(inventory, entry, entry.name + "  × " + str(entry.count))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.custom_minimum_size = Vector2(210, 62)
		button.pressed.connect(_request_item_generation.bind(entry.id, _inventory_generation))
	if _snapshot.inventory.is_empty(): _empty(inventory, "背包是空的")
	_label($Roll/Hint, _snapshot.roll_hint if _snapshot.status.is_empty() else _snapshot.status)
	_update_enabled()
	set_inventory_open(_inventory_open)
func _empty(parent: Node, value: String) -> void:
	var text := Label.new()
	text.text = value
	text.theme_type_variation = &"PartyLabelNote"
	text.add_theme_color_override("font_color", Color(0.95, 0.98, 1))
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(text)
func _option(parent: Node, entry: Dictionary, title: String) -> Button:
	var button: Button = OPTION.instantiate()
	button.text = title
	button.tooltip_text = title
	for key in ["description", "reason"]:
		if not str(entry.get(key, "")).is_empty(): button.tooltip_text += "\n" + entry[key]
	button.set_meta("stable_id", entry.id)
	parent.add_child(button)
	return button
func set_inventory_open(open: bool) -> void:
	_inventory_open = open
	if not is_node_ready(): return
	var focus := get_viewport().gui_get_focus_owner()
	if not open and focus and $Inventory/Body.is_ancestor_of(focus) and not is_modal_open():
		$Inventory/Toggle.grab_focus()
	$Inventory/Body.visible = open
	$Inventory/Toggle.tooltip_text = ("收起背包" if open else "展开背包") + " · %d 种道具" % _snapshot.inventory.size()
func _update_enabled() -> void:
	var blocked := is_modal_open()
	$Roll/Button.disabled = blocked or _roll_pending or not _snapshot.roll_enabled
	$Roll/Button.tooltip_text = "请求已发送，等待游戏确认" if _roll_pending else "掷骰子 · " + _snapshot.roll_hint
	$Roll/Button.self_modulate = Color(1, 1, 1, 0.4 if $Roll/Button.disabled else 1.0)
	$Inventory/Toggle.disabled = blocked
	$Inventory/Toggle.self_modulate = Color(1, 1, 1, 0.4 if blocked else 1.0)
	for button in $Inventory/Body/Margin/Scroll/Items.get_children():
		if not button is Button: continue
		for entry in _snapshot.inventory:
			if entry.id == button.get_meta("stable_id"):
				button.disabled = blocked or _item_pending.has(entry.id) or not entry.get("enabled", true) or entry.count == 0
func request_roll() -> void:
	if not is_node_ready() or not is_visible_in_tree() or is_modal_open() or _roll_pending or not _snapshot.roll_enabled: return
	_roll_pending = true
	_update_enabled()
	roll_requested.emit()
func _request_item_generation(id: String, generation: int) -> void:
	if generation == _inventory_generation: request_item(id)
func request_item(id: String) -> void:
	if not is_node_ready() or not is_visible_in_tree() or is_modal_open() or _item_pending.has(id): return
	for entry in _snapshot.inventory:
		if entry.id != id: continue
		if not entry.get("enabled", true) or entry.count == 0: return
		_item_pending[id] = true
		_update_enabled()
		item_requested.emit(id)
		return

func show_event(data: Dictionary) -> bool:
	last_error = ""
	for key in ["id", "title", "body"]:
		if not data.get(key) is String: return _reject("事件 " + key + " 必须为 String。")
	if data.id.strip_edges().is_empty(): return _reject("事件 ID 不能为空。")
	if data.has("dismissible") and not data.dismissible is bool: return _reject("dismissible 必须为 bool。")
	if not _valid_entries(data.get("choices", []), "choices", 32): return false
	if data.get("illustration") != null and not data.illustration is Texture2D: return _reject("illustration 必须为 Texture2D 或 null；请由宿主解析资源。")
	if data.has("illustration_alt") and not data.illustration_alt is String: return _reject("illustration_alt 必须为 String。")
	var was_open := is_modal_open()
	var old_id: String = _event.get("id", "")
	if not was_open and is_node_ready():
		var focus := get_viewport().gui_get_focus_owner()
		_focus_before_modal = weakref(focus) if focus else null
	_event = data.duplicate(true)
	_event_generation += 1
	var generation := _event_generation
	_choice_pending = false
	if is_node_ready(): _render_event()
	if not was_open: modal_visibility_changed.emit(true)
	# Commit first. A listener may close/replace the new event safely.
	if was_open and old_id != data.id and generation == _event_generation:
		event_dismissed.emit(old_id, "replaced")
	return true
func is_modal_open() -> bool: return not _event.is_empty()
func close_event() -> bool:
	if not is_modal_open() or not _event.get("dismissible", true): return false
	return _dismiss_event("closed")
## External authoritative dismissal, including non-dismissible events.
func dismiss_event(event_id: String) -> bool:
	if not is_modal_open() or _event.id != event_id: return false
	return _dismiss_event("controller")
func _dismiss_event(reason: String) -> bool:
	var id: String = _event.id
	_event.clear()
	_event_generation += 1
	_choice_pending = false
	if is_node_ready():
		$EventModal.hide()
		_update_enabled()
		var focus: Control = _focus_before_modal.get_ref() if _focus_before_modal else null
		_focus_before_modal = null
		if is_instance_valid(focus) and focus.is_visible_in_tree() and (not focus is BaseButton or not focus.disabled): focus.grab_focus()
		elif is_visible_in_tree():
			if not $Roll/Button.disabled: $Roll/Button.grab_focus()
			else: $Inventory/Toggle.grab_focus()
	modal_visibility_changed.emit(false)
	# Always report the completed dismissal; no UI/state writes after callbacks.
	event_dismissed.emit(id, reason)
	return true
func _render_event() -> void:
	var content := get_node(EVENT_CONTENT)
	var illustration: TextureRect = content.get_node("Illustration")
	illustration.texture = _event.get("illustration")
	illustration.visible = illustration.texture != null
	illustration.tooltip_text = _event.get("illustration_alt", "")
	_label(content.get_node("Title"), _event.title)
	_label(content.get_node("BodyScroll/Body"), _event.body)
	var choices := content.get_node("ChoicesScroll/Choices")
	_clear_rows(choices)
	for entry in _event.get("choices", []):
		var button := _option(choices, entry, entry.label)
		button.disabled = _choice_pending or not entry.get("enabled", true)
		button.pressed.connect(_request_choice.bind(entry.id, _event_generation))
	content.get_node("Close").visible = _event.get("dismissible", true)
	content.get_node("BodyScroll").scroll_vertical = 0
	content.get_node("ChoicesScroll").scroll_vertical = 0
	$EventModal.show()
	_update_enabled()
	var focusables := _modal_focusables()
	if not focusables.is_empty(): focusables[0].grab_focus()
func request_event_choice(id: String) -> void:
	_request_choice(id, _event_generation)
func _request_choice(id: String, generation: int) -> void:
	if not is_node_ready() or not is_modal_open() or not is_visible_in_tree() or generation != _event_generation or _choice_pending: return
	for entry in _event.get("choices", []):
		if entry.id == id and entry.get("enabled", true):
			_choice_pending = true
			var event_id: String = _event.id
			for button in get_node(EVENT_CONTENT + "/ChoicesScroll/Choices").get_children(): button.disabled = true
			event_choice_requested.emit(event_id, id)
			return
func _modal_focusables() -> Array[Control]:
	var result: Array[Control] = []
	for button in get_node(EVENT_CONTENT + "/ChoicesScroll/Choices").get_children():
		if button is Button and not button.disabled: result.append(button)
	var close: Button = get_node(EVENT_CONTENT + "/Close")
	if close.visible: result.append(close)
	result.append(get_node(EVENT_CONTENT + "/BodyScroll"))
	result.append(get_node(EVENT_CONTENT + "/ChoicesScroll"))
	return result
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not is_modal_open(): return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if not event.echo: close_event()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_TAB:
			var choices := _modal_focusables()
			var index := choices.find(get_viewport().gui_get_focus_owner())
			choices[posmod(index + (-1 if event.shift_pressed else 1), choices.size())].grab_focus()
			get_viewport().set_input_as_handled()
func _unhandled_input(_event_input: InputEvent) -> void:
	if is_visible_in_tree() and is_modal_open(): get_viewport().set_input_as_handled()
