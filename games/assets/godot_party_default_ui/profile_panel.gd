## Draft-only editor. Core owns Apply/Cancel, persistence and profile confirmation.
extends VBoxContainer
var protocol_id: String
var colors: Array
var color_names: Array
var _value: Dictionary = {}
var _context: Dictionary = {}
var _color: OptionButton
var _choices: Dictionary = {}
var _assignment_choices: Dictionary = {}
var _views: Array[SubViewport] = []
var _visuals: Array[Node] = []
var _error: Label

func configure(value: Dictionary, editable: bool, context: Dictionary = {}) -> void:
	_value = value.duplicate(true)
	_context = context
	_color = %ColorChoice
	_color.clear()
	_choices = {"avatar_2d": %AvatarChoice, "character_3d": %CharacterChoice}
	_views.assign([%AvatarView, %CharacterView])
	_error = %Error
	for index: int in colors.size():
		var swatch: Image = Image.create(24, 24, false, Image.FORMAT_RGBA8)
		swatch.fill(Color(colors[index]))
		_color.add_icon_item(ImageTexture.create_from_image(swatch), color_names[index])
	_color.select(colors.find(_value.color))
	_color.disabled = not editable
	if not _color.item_selected.is_connected(_select_color):
		_color.item_selected.connect(_select_color)
	for slot: String in _choices:
		var choice: OptionButton = _choices[slot]
		choice.clear()
		choice.disabled = not editable
		for package_id: String in context.get("resources", {}):
			var manifest: Dictionary = context.resources[package_id]
			for key: String in manifest.get("appearance_resources", {}):
				var info: Variant = manifest.appearance_resources[key]
				if not info is Dictionary or info.get("protocol") != protocol_id or info.get("slot") != slot or not manifest.get("resources", {}).has(key):
					continue
				var ref: Dictionary = {"package_id": package_id, "resource_key": key}
				choice.add_item(info.get("name", key))
				choice.set_item_metadata(choice.item_count - 1, ref)
		var selected: int = -1
		for index: int in choice.item_count:
			if choice.get_item_metadata(index) == _value[slot]:
				selected = index
		if selected == -1:
			choice.add_item("缺失资源 · " + str(_value[slot].resource_key))
			selected = choice.item_count - 1
			choice.set_item_metadata(selected, _value[slot].duplicate(true))
		choice.select(selected)
		var update: Callable = _select_asset.bind(slot)
		if not choice.item_selected.is_connected(update):
			choice.item_selected.connect(update)
	_rebuild_previews()
	_build_host_assignments()

func _select_color(index: int) -> void:
	_recolor(Color(colors[index]))

func _select_asset(index: int, slot: String) -> void:
	_value[slot] = _choices[slot].get_item_metadata(index).duplicate(true)
	_rebuild_previews()

func _ready() -> void:
	_update_visibility()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_update_visibility()

func _update_visibility() -> void:
	for view: SubViewport in _views:
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED

func _rebuild_previews() -> void:
	for visual: Node in _visuals:
		visual.get_parent().remove_child(visual)
		visual.queue_free()
	_visuals.clear()
	_error.text = ""
	for index: int in _views.size():
		var view: SubViewport = _views[index]
		var slot: String = "avatar_2d" if index == 0 else "character_3d"
		var resolve: Callable = _context.get("preview_asset", Callable())
		var asset: Resource = resolve.call(_value[slot]) if resolve.is_valid() else null
		if not asset is PackedScene:
			_error.text += slot + "：资源缺失或不是场景；请重新选择。\n"
			continue
		var visual: Node = asset.instantiate()
		if (index == 0 and not visual is Node2D) or (index == 1 and not visual is Node3D):
			visual.free()
			_error.text += slot + "：场景根类型不匹配。\n"
			continue
		view.add_child(visual)
		_visuals.append(visual)
		if visual is Node2D:
			visual.position = Vector2(180, 190)
			visual.scale = Vector2(2, 2)
	_recolor(Color(_value.color))
	_update_visibility()

func _recolor(value: Color) -> void:
	_value.color = "#" + value.to_html(false)
	for visual: Node in _visuals:
		if visual.has_method("apply_color"):
			visual.apply_color(value)

func get_value() -> Dictionary:
	return _value.duplicate(true)

func show_error(message: String) -> void:
	_error.text = message


## The core provides a guarded host callback; color semantics and controls stay in this protocol.
func _build_host_assignments() -> void:
	var assign: Callable = _context.get("assign_room_profile", Callable())
	var roster: Callable = _context.get("room_players", Callable())
	%HostAssignments.visible = assign.is_valid() and roster.is_valid()
	if not %HostAssignments.visible:
		return
	var players: Array = roster.call()
	_assignment_choices.clear()
	for index: int in 8:
		var row: HBoxContainer = %HostAssignments.get_child(index + 1)
		row.visible = index < players.size()
		if not row.visible:
			continue
		var player: Dictionary = players[index]
		row.get_node("Player").text = player.name
		var choice: OptionButton = row.get_node("Color")
		choice.clear()
		for name_value: String in color_names:
			choice.add_item(name_value)
		choice.select(colors.find(str(player.profile.get("color", ""))))
		_assignment_choices[player.player_id] = choice
		row.set_meta("player_id", player.player_id)
		var button: Button = row.get_node("Assign")
		var handler: Callable = _assign_color.bind(row)
		if not button.pressed.is_connected(handler):
			button.pressed.connect(handler)

func _assign_color(row: Control) -> void:
	var assign: Callable = _context.assign_room_profile
	var roster: Callable = _context.room_players
	var choice: OptionButton = row.get_node("Color")
	var report: Dictionary = assign.call(str(row.get_meta("player_id")), {"color": colors[choice.selected]})
	_error.text = report.get("message", "已分配" if report.get("ok", false) else "分配失败")
	for current: Dictionary in roster.call():
		if _assignment_choices.has(current.player_id):
			_assignment_choices[current.player_id].select(colors.find(str(current.profile.get("color", ""))))
