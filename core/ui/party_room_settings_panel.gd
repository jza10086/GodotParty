## Host rule drafts reuse the same hierarchy and inheritance controls as local preferences.
extends VBoxContainer
const Schema = preload("res://core/config/party_schema.gd")
const Form = preload("res://core/ui/party_config_form.gd")
const SectionScene: PackedScene = preload("res://core/ui/settings/setting_section.tscn")
var rows: Array[Dictionary] = []
var main_id: String
var store: RefCounted
var protocol_id: String

func configure(room: Dictionary, catalog: RefCounted, editable: bool, running: bool, config_store: RefCounted = null) -> void:
	store = config_store
	main_id = room.main
	protocol_id = catalog.get_package(room.main).protocol.id
	_preset_controls(protocol_id, editable and not running)
	_section("协议规则", "protocol_base", "", catalog.schema(protocol_id), room.common, {}, editable, running)
	for game: String in [String(room.main)] + room.children.keys():
		_preset_controls(game, editable and not running)
		_section(catalog.get_package(game).name + " · 协议覆盖", "game_common", game, catalog.schema(protocol_id), room.common_overrides.get(game, {}), room.common, editable, running)
		_section(catalog.get_package(game).name + " · 专属规则", "game_own", game, catalog.schema(game), room.settings if game == main_id else room.children[game], {}, editable, running)

func _section(title: String, target: String, game: String, schema: Dictionary, original: Dictionary, base: Dictionary, editable: bool, running: bool) -> void:
	var locked: Array = []
	for key: String in schema.fields:
		if running and (schema.fields[key].apply != "next_round" or game == main_id):
			locked.append(key)
	var context: Dictionary = {"schema": schema, "audience": "room", "inherit": true, "overrides": target == "game_common", "base": base, "locked": locked, "inherit_label": "继承协议" if target == "game_common" else "使用默认值"}
	var section: Control = SectionScene.instantiate()
	section.configure(title, true)
	add_child(section)
	var form: Form = preload("res://core/ui/party_config_form.tscn").instantiate()
	form.configure(original, editable, context)
	section.body().add_child(form)
	rows.append({"target": target, "game_id": game, "schema": schema, "original": original.duplicate(true), "form": form, "context": context, "editable": editable})

func edits() -> Array:
	var result: Array = []
	for row: Dictionary in rows:
		var values: Dictionary = row.form.explicit_values()
		for field: Dictionary in Schema.fields(row.schema, "room"):
			if not row.editable or field.key in row.context.locked or (row.target == "game_common" and not field.overridable):
				continue
			if values.has(field.key):
				if not row.original.has(field.key) or row.original[field.key] != values[field.key]:
					result.append({"target": row.target, "game_id": row.game_id, "key": field.key, "op": "set", "value": values[field.key]})
			elif row.original.has(field.key):
				result.append({"target": row.target, "game_id": row.game_id, "key": field.key, "op": "unset"})
	return result

func _preset_controls(id: String, editable: bool) -> void:
	if store == null or not editable or id == main_id:
		return
	var bar: Control = preload("res://core/ui/party_preset_bar.tscn").instantiate()
	add_child(bar)
	bar.configure(store, id, protocol_id, func() -> Dictionary: return _preset_snapshot(id, bar.service), editable)
	bar.loaded.connect(func(value: Dictionary) -> void:
		for row: Dictionary in rows:
			if _belongs(row, id) and row.editable:
				row.form.configure(value.room_common if row.target == "game_common" else value.room_own, row.editable, row.context))

func _belongs(row: Dictionary, id: String) -> bool:
	return row.target == "protocol_base" if id == protocol_id else row.game_id == id

func _preset_snapshot(id: String, service: RefCounted) -> Dictionary:
	var own: Dictionary = {}
	var common: Dictionary = {}
	for row: Dictionary in rows:
		if _belongs(row, id):
			if row.target == "game_common":
				common = row.form.explicit_values()
			else:
				own = row.form.explicit_values()
	return service.snapshot(id, protocol_id, own, common)
