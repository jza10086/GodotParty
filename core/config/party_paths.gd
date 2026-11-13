## Portable installation paths. Protocols own their game configuration namespace.
extends RefCounted

static func application_root() -> String:
	if OS.has_feature("android") or OS.has_feature("ios"):
		return ProjectSettings.globalize_path("user://").trim_suffix("/")
	return ProjectSettings.globalize_path("res://").trim_suffix("/") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()

static func folder(value: Variant) -> bool:
	if not value is String or not preload("res://core/runtime/party_data.gd").identifier(value) or value.length() > 80:
		return false
	return value.get_slice(".", 0).to_lower() not in ["con", "prn", "aux", "nul", "com1", "com2", "com3", "com4", "com5", "com6", "com7", "com8", "com9", "lpt1", "lpt2", "lpt3", "lpt4", "lpt5", "lpt6", "lpt7", "lpt8", "lpt9"]

static func package_relative(manifest: Dictionary) -> String:
	var id: Variant = manifest.get("id", "")
	var kind: Variant = manifest.get("kind", "")
	if not folder(id) or kind not in ["protocols", "maingame", "minigame", "avatars", "assets"]:
		return ""
	if kind == "avatars":
		var protocol: Variant = manifest.get("owner_protocol", "")
		return "protocols/" + protocol + "/avatars/" + id if folder(protocol) else ""
	return kind + "/" + id

static func configuration(root: String, catalog: RefCounted, id: String, protocol: String = "") -> String:
	var manifest: Dictionary = catalog.get_package(id)
	var relative: String = package_relative(manifest)
	if relative.is_empty() or manifest.kind in ["avatars", "assets"]:
		return ""
	var base: String = root.path_join(relative).path_join("config")
	if manifest.kind == "protocols" or protocol.is_empty():
		return base
	var name_value: Variant = catalog.get_package(protocol).get("config_directories", {}).get(manifest.kind, "")
	return base.path_join(name_value) if folder(name_value) else ""
