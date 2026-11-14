## Author-owned publication filtering, shared by source ZIPs, PCK staging and loose payloads.
## Rules are package-relative; the control file survives staging so repeated collection is identical.
extends RefCounted
const RULES_FILE: String = "export_ignore.txt"
const DEFAULT_RULES: String = "res://core/content/default_export_ignore.txt"

static func rules(root: String) -> Dictionary:
	var path: String = root.path_join(RULES_FILE)
	if not FileAccess.file_exists(path):
		path = DEFAULT_RULES
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "Cannot read export rules: " + path}
	var text: String = file.get_as_text()
	if file.get_error() != OK:
		return {"ok": false, "error": "Cannot read export rules: " + path}
	var patterns: Array[RegEx] = []
	var line_number: int = 0
	for raw: String in text.split("\n"):
		line_number += 1
		var line: String = raw.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line.begins_with("!") or line.begins_with("/") or line.contains("\\") or line.contains(":") or ".." in line.split("/"):
			return {"ok": false, "error": "%s:%d: use relative paths with /; negation is not supported" % [path, line_number]}
		var directory: bool = line.ends_with("/")
		var expression: String = ""
		for character: String in line.trim_suffix("/"):
			if character == "*":
				expression += ".*"
			elif character == "?":
				expression += "."
			else:
				expression += ("\\" if character in "\\.^$|+()[]{}" else "") + character
		var pattern: RegEx = RegEx.new()
		var error: Error = pattern.compile("(?i)^" + expression + ("(?:/.*)?" if directory else "") + "$")
		if error != OK:
			return {"ok": false, "error": "%s:%d: invalid export pattern" % [path, line_number]}
		patterns.append(pattern)
	return {"ok": true, "patterns": patterns}

static func ignored(relative: String, patterns: Array) -> bool:
	if relative == RULES_FILE:
		return false
	var source: String = relative.trim_suffix(".import").trim_suffix(".uid")
	for pattern: RegEx in patterns:
		if pattern.search(relative) != null or pattern.search(source) != null:
			return true
	return false

## An absent optional subtree is empty; an unreadable existing root is an error.
static func collect(root: String, subtree: String = "") -> Dictionary:
	var parsed: Dictionary = rules(root)
	if not parsed.ok:
		return parsed
	var files: Array[String] = []
	var directories: Array[String] = []
	var package: bool = FileAccess.file_exists(root.path_join("manifest.json"))
	if package and ignored("manifest.json", parsed.patterns):
		return {"ok": false, "error": "Export rules exclude required manifest.json: " + root}
	if not subtree.is_empty() and not DirAccess.dir_exists_absolute(root.path_join(subtree)):
		return {"ok": true, "files": files, "directories": directories}
	var start: String = root if subtree.is_empty() else root.path_join(subtree)
	var parent: DirAccess = DirAccess.open(start.get_base_dir())
	if parent != null and parent.is_link(start.get_file()):
		return {"ok": false, "error": "Cannot export linked directory: " + start}
	var issue: String = _walk(root, subtree, parsed.patterns, package and subtree.is_empty(), files, directories)
	if not issue.is_empty():
		return {"ok": false, "error": issue}
	files.sort()
	directories.sort()
	return {"ok": true, "files": files, "directories": directories}

static func _walk(root: String, relative: String, patterns: Array, package: bool, files: Array[String], directories: Array[String]) -> String:
	if not relative.is_empty() and ignored(relative, patterns):
		return ""
	var path: String = root if relative.is_empty() else root.path_join(relative)
	var folder: DirAccess = DirAccess.open(path)
	if folder == null:
		return "Cannot collect export directory: " + path
	if not relative.is_empty():
		directories.append(relative)
	for file: String in folder.get_files():
		var child: String = file if relative.is_empty() else relative.path_join(file)
		if file.to_lower() in [".git", ".godot"] or ignored(child, patterns):
			continue
		if folder.is_link(file):
			return "Cannot export linked file: " + path.path_join(file)
		files.append(root.path_join(child))
	for directory: String in folder.get_directories():
		if directory.to_lower() in [".git", ".godot"] or (package and relative.is_empty() and directory.to_lower() == "config"):
			continue
		var child: String = directory if relative.is_empty() else relative.path_join(directory)
		if ignored(child, patterns):
			continue
		if folder.is_link(directory):
			return "Cannot export linked directory: " + path.path_join(directory)
		# Independent package roots are collected under their own identity and rules.
		if package and not (child == "external" or child.begins_with("external/")) and FileAccess.file_exists(path.path_join(directory).path_join("manifest.json")):
			continue
		var issue: String = _walk(root, child, patterns, package, files, directories)
		if not issue.is_empty():
			return issue
	return ""
