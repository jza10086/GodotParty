## Package-local Git ignore patterns. Collection keeps technical ownership boundaries separate.
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
	var source: String = file.get_as_text()
	if file.get_error() != OK:
		return {"ok": false, "error": "Cannot read export rules: " + path}
	var patterns: Array[Dictionary] = []
	var line_number: int = 0
	for raw: String in source.trim_prefix("\uFEFF").split("\n"):
		line_number += 1
		var line: String = raw.trim_suffix("\r")
		# Git ignores trailing spaces unless the final space is escaped.
		while line.ends_with(" "):
			var slashes: int = 0
			var cursor: int = line.length() - 2
			while cursor >= 0 and line[cursor] == "\\":
				slashes += 1
				cursor -= 1
			if slashes % 2 == 1:
				break
			line = line.left(-1)
		if line.is_empty() or line.begins_with("#"):
			continue
		var include: bool = line.begins_with("!")
		if include:
			line = line.substr(1)
		if line.is_empty():
			continue
		var directory: bool = line.ends_with("/")
		line = line.trim_suffix("/")
		var anchored: bool = line.begins_with("/") or line.contains("/")
		line = line.trim_prefix("/")
		if line.is_empty():
			continue
		var pattern: RegEx = RegEx.new()
		var error: Error = pattern.compile("^" + ("" if anchored else "(?:.*/)?") + _glob(line) + "$")
		if error != OK:
			return {"ok": false, "error": "%s:%d: invalid ignore pattern" % [path, line_number]}
		patterns.append({"pattern": pattern, "include": include, "directory": directory})
	return {"ok": true, "patterns": patterns}

static func _literal(character: String) -> String:
	return ("\\" if character in "\\.^$|+()[]{}*?" else "") + character

static func _glob(value: String) -> String:
	var result: String = ""
	var index: int = 0
	while index < value.length():
		var character: String = value[index]
		if character == "\\":
			index += 1
			if index == value.length():
				return "(?!)"
			result += _literal(value[index])
		elif character == "*":
			var end: int = index
			while end < value.length() and value[end] == "*":
				end += 1
			if end - index >= 2 and (index == 0 or value[index - 1] == "/") and (end == value.length() or value[end] == "/"):
				if end < value.length():
					result += "(?:[^/]+/)*"
					end += 1
				else:
					result += ".*"
			else:
				result += "[^/]*"
			index = end - 1
		elif character == "?":
			result += "[^/]"
		elif character == "[":
			var end: int = index + 1
			if end < value.length() and value[end] in "!^":
				end += 1
			if end < value.length() and value[end] == "]":
				end += 1
			while end < value.length():
				if value.substr(end, 2) == "[:":
					var close: int = value.find(":]", end + 2)
					if close >= 0:
						end = close + 2
						continue
				if value[end] == "]":
					break
				end += 1
			if end == value.length():
				result += "\\["
			else:
				var body: String = value.substr(index + 1, end - index - 1)
				if body.begins_with("!"):
					body = "^" + body.substr(1)
				for name: String in _classes():
					body = body.replace("[:" + name + ":]", _classes()[name])
				result += "(?!/)[" + body + "]"
				index = end
		else:
			result += _literal(character)
		index += 1
	return result

static func _classes() -> Dictionary:
	return {"alnum": "a-zA-Z0-9", "alpha": "a-zA-Z", "blank": " \\t", "cntrl": "\\x00-\\x1f\\x7f", "digit": "0-9", "graph": "!-~", "lower": "a-z", "print": " -~", "punct": "!-/:-@\\[-`{-~", "space": "\\s", "upper": "A-Z", "xdigit": "a-fA-F0-9"}

## Parent exclusions prune traversal; a child negation cannot restore an excluded ancestor.
static func ignored(relative: String, patterns: Array, directory: bool = false) -> bool:
	if relative == RULES_FILE:
		return false
	var segments: PackedStringArray = relative.split("/")
	var path: String = ""
	for index: int in segments.size():
		path = segments[index] if path.is_empty() else path.path_join(segments[index])
		var folder: bool = directory or index < segments.size() - 1
		var excluded: bool = false
		for rule: Dictionary in patterns:
			if (not rule.directory or folder) and rule.pattern.search(path) != null:
				excluded = not rule.include
		if excluded:
			return true
	var source: String = relative.trim_suffix(".import").trim_suffix(".uid")
	return not directory and source != relative and ignored(source, patterns)

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
	if not relative.is_empty() and ignored(relative, patterns, true):
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
		if ignored(child, patterns, true):
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
