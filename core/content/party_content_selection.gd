## Content dependency closure, shared by the editor window and CLI exporter.
extends RefCounted

static func resolve(catalog: RefCounted, requested: Array) -> Dictionary:
	var selected: Dictionary = {}
	var queue: Array = requested.duplicate()
	var visited: Dictionary = {}
	while not queue.is_empty():
		var id: Variant = queue.pop_front()
		if not id is String or not catalog.packages.has(id):
			return {"ok": false, "error": "Unknown export package: " + str(id)}
		if visited.has(id):
			continue
		visited[id] = true
		var issue: String = catalog._visit(id, selected, {})
		if not issue.is_empty():
			return {"ok": false, "error": issue}
		var manifest: Dictionary = catalog.packages[id]
		if manifest.kind == "maingame":
			queue.append(manifest.protocol.id)
		elif manifest.kind == "avatars":
			queue.append(manifest.owner_protocol)
		elif manifest.kind == "minigame":
			for adapter: Dictionary in manifest.adapters:
				if not catalog.protocol_matches(adapter.protocol):
					return {"ok": false, "error": id + ": missing compatible protocol " + adapter.protocol.id}
				queue.append(adapter.protocol.id)
				issue = catalog._dependencies(adapter.get("dependencies", {}), selected, {})
				if not issue.is_empty():
					return {"ok": false, "error": issue}
		for dependency: String in selected:
			if not visited.has(dependency) and not queue.has(dependency):
				queue.append(dependency)
	var ids: Array = selected.keys()
	ids.sort()
	return {"ok": true, "ids": ids}


## Compute startup availability without loading content scripts or adapter-specific dependencies.
static func unavailable_packages(packages: Dictionary) -> Dictionary:
	var unavailable: Dictionary = {}
	var previous_size: int = -1
	# Ownership is an activation boundary, not a version dependency: protocols may require their avatars.
	while previous_size != unavailable.size():
		previous_size = unavailable.size()
		for id: String in packages:
			if unavailable.has(id):
				continue
			var reason: String = _dependency_issue(id, packages, [], unavailable)
			if not reason.is_empty():
				unavailable[id] = reason
	return unavailable

static func _dependency_issue(id: String, packages: Dictionary, visiting: Array[String], unavailable: Dictionary) -> String:
	if unavailable.has(id):
		return unavailable[id]
	if id in visiting:
		return "循环依赖：" + " → ".join(visiting) + " → " + id
	var path: Array[String] = visiting.duplicate()
	path.append(id)
	var manifest: Dictionary = packages[id]
	if manifest.kind == "avatars":
		if not packages.has(manifest.owner_protocol):
			return "缺少所属协议：" + manifest.owner_protocol
		if unavailable.has(manifest.owner_protocol):
			return "所属协议不可用：" + manifest.owner_protocol + " · " + unavailable[manifest.owner_protocol]
	for dependency: String in manifest.get("dependencies", {}):
		var version: String = manifest.dependencies[dependency]
		if not packages.has(dependency):
			return "缺少依赖：" + dependency + " " + version
		if packages[dependency].package_version != version:
			return "依赖版本不匹配：" + dependency + "（需要 " + version + "，已安装 " + str(packages[dependency].package_version) + "）"
		var reason: String = _dependency_issue(dependency, packages, path, unavailable)
		if not reason.is_empty():
			return dependency + " 不可用：" + reason
	return ""
