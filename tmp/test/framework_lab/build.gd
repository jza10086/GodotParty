extends SceneTree
## Build isolated test packs at canonical virtual paths; production catalog code is unchanged.
const Catalog: Script = preload("res://core/content/party_catalog.gd")
const Packages: Script = preload("res://core/content/party_packages.gd")
const Data: Script = preload("res://core/runtime/party_data.gd")
const ROOT: String = "res://tmp/test/framework_lab/"
var failure: String = ""

func _init() -> void:
	# Packaging needs no editor runtime server or writes to its external registry.
	ProjectSettings.set_setting("autoload/MCPRuntimeServer", null)

func _initialize() -> void:
	var catalog: RefCounted = Catalog.new()
	for relative: String in ["minigame/godot_party_default_framework_probe", "maingame/godot_party_default_framework_lab"]:
		var source: String = ROOT + "games/" + relative
		if catalog.register_manifest(source + "/manifest.json") != OK:
			failure = str(catalog.errors)
			break
		if not _pack(source, relative, catalog):
			break
	if not failure.is_empty():
		push_error(failure)
		quit(1)
		return
	print("LAB_BUILD_PASS")
	quit(0)

func _pack(source: String, relative: String, catalog: RefCounted) -> bool:
	var destination: String = ROOT + "packages/" + relative
	var error: Error = DirAccess.make_dir_recursive_absolute(destination)
	if error != OK:
		return _fail("mkdir", error)
	var pack: PCKPacker = PCKPacker.new()
	error = pack.pck_start(destination + "/content.pck")
	if error != OK:
		return _fail("pck_start", error)
	var paths: Array[String] = []
	var pattern: RegEx = RegEx.new()
	error = pattern.compile(' uid="uid://[^"]*"')
	if error != OK:
		return _fail("UID pattern", error)
	for physical: String in Catalog.files(source):
		if physical.get_extension() not in ["gd", "tscn", "json"]:
			continue
		var virtual: String = physical.replace(ROOT + "games/", "res://games/")
		var stage: String = ROOT + "output/staging/" + physical.trim_prefix(ROOT + "games/")
		error = DirAccess.make_dir_recursive_absolute(stage.get_base_dir())
		if error != OK:
			return _fail("staging mkdir", error)
		var text: String = FileAccess.get_file_as_string(physical)
		error = FileAccess.get_open_error()
		if error != OK:
			return _fail("read " + physical, error)
		text = text.replace(ROOT + "games/", "res://games/")
		# Test sources are ignored by the editor. Packs use path references, not their editor UIDs.
		if physical.ends_with(".tscn"):
			text = pattern.sub(text, "", true)
		if not _write(stage, text):
			return false
		error = pack.add_file(virtual, stage)
		if error != OK:
			return _fail("add_file", error)
		paths.append(virtual)
	error = pack.flush()
	if error != OK:
		return _fail("flush pack", error)
	var id: String = relative.get_file()
	var manifest: Dictionary = catalog.get_package(id)
	var descriptor: Dictionary = {"format": 2, "engine": Engine.get_version_info().string,
		"core": Data.VERSION, "id": id, "version": manifest.package_version,
		"kind": manifest.kind, "artifact": "content.pck", "files": paths, "uids": {}}
	var issue: String = Packages.new().validate_descriptor(descriptor)
	if not issue.is_empty():
		failure = issue
		return false
	return _write(destination + "/content.pck.json", JSON.stringify(descriptor, "\t"))

func _write(path: String, text: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _fail(path, FileAccess.get_open_error())
	file.store_string(text)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	return true if error == OK else _fail(path, error)

func _fail(operation: String, error: Error) -> bool:
	failure = operation + ": " + error_string(error)
	return false
