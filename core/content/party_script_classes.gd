## Package-owned class metadata and the one merged registry mounted before content scripts.
extends RefCounted

static func collect(files: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if files.has(entry.path):
			result.append({"class": str(entry["class"]), "base": str(entry.base),
				"path": str(entry.path), "language": str(entry.language),
				"is_abstract": entry.is_abstract, "is_tool": entry.is_tool})
	return result

## Descriptor input boundary: a package can register only its own indexed GDScript files.
static func validate(entries: Variant, root: String, files: Array) -> String:
	if not entries is Array:
		return "Missing script_classes array; re-export this content package"
	var names: Dictionary = {}
	var paths: Dictionary = {}
	for entry: Variant in entries:
		if not entry is Dictionary:
			return "Invalid script class record"
		for key: String in ["class", "base", "path", "language"]:
			if not entry.get(key) is String:
				return "Script class requires string " + key
		if not entry.get("is_abstract") is bool or not entry.get("is_tool") is bool:
			return "Script class requires is_abstract and is_tool flags"
		var name_value: String = entry["class"]
		if not name_value.is_valid_identifier() or not entry.base.is_valid_identifier() or entry.language != "GDScript":
			return "Invalid GDScript class: " + name_value
		if not entry.path.begins_with(root + "/") or not entry.path.ends_with(".gd") or not files.has(entry.path):
			return "Class path is outside package files: " + name_value + " -> " + entry.path
		if names.has(name_value) or paths.has(entry.path):
			return "Duplicate script class name/path: " + name_value
		if ClassDB.class_exists(name_value):
			return "Script class conflicts with engine type: " + name_value
		names[name_value] = true
		paths[entry.path] = true
	return ""

## Merge with core (and editor source) registrations; validate all added inheritance chains.
static func merge(existing: Array[Dictionary], descriptions: Dictionary) -> Dictionary:
	var classes: Dictionary = {}
	for entry: Dictionary in existing:
		classes[str(entry["class"])] = entry.duplicate(true)
	var added: Dictionary = {}
	for id: String in descriptions:
		for entry: Dictionary in descriptions[id].script_classes:
			var name_value: String = entry["class"]
			if added.has(name_value):
				return {"ok": false, "error": "Class name conflict: " + name_value + " in " + added[name_value] + " and " + id}
			if classes.has(name_value) and classes[name_value].path != entry.path:
				return {"ok": false, "error": "Class name conflict: " + name_value + " in " + id + " and " + str(classes[name_value].path)}
			added[name_value] = id
			classes[name_value] = entry.duplicate(true)
	for name_value: String in added:
		var chain: Dictionary = {}
		var current: String = name_value
		while not ClassDB.class_exists(current):
			if not classes.has(current):
				return {"ok": false, "error": added[name_value] + ": missing base type " + current + " for " + name_value}
			if chain.has(current):
				return {"ok": false, "error": added[name_value] + ": cyclic class inheritance at " + current}
			chain[current] = true
			current = str(classes[current].base)
	var result: Array[Dictionary] = []
	for name_value: String in classes:
		result.append(classes[name_value])
	return {"ok": true, "classes": result, "has_content_classes": not added.is_empty()}

## Only the framework-generated registry may replace Godot metadata; content stays non-replacing.
## Per-process caches avoid two running copies overwriting a ZIP that the other has mounted.
static func register(directory: String, classes: Array[Dictionary]) -> Error:
	var cache_directory: String = directory.path_join("tmp/content_classes")
	var error: Error = DirAccess.make_dir_recursive_absolute(cache_directory)
	if error != OK:
		return error
	var cache: ConfigFile = ConfigFile.new()
	cache.set_value("", "list", classes)
	var path: String = cache_directory.path_join(str(OS.get_process_id()) + ".zip")
	var writer: ZIPPacker = ZIPPacker.new()
	error = writer.open(path)
	if error != OK:
		return error
	error = writer.start_file(".godot/global_script_class_cache.cfg")
	if error == OK:
		error = writer.write_file(cache.encode_to_text().to_utf8_buffer())
	if error == OK:
		error = writer.close_file()
	var close_error: Error = writer.close()
	if error != OK:
		return error
	if close_error != OK:
		return close_error
	if not ProjectSettings.load_resource_pack(path, true):
		return ERR_CANT_OPEN
	return OK
