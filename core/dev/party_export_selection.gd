## Build-time dependency closure, shared by the editor window and CLI exporter.
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
