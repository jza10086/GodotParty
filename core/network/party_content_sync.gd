## Two-stage room content transfer. Requests address offered files only; installed PCKs
## are replaced by the existing archive bootstrap on the next launch.
extends Node
const Data = preload("res://core/runtime/party_data.gd")
const Paths = preload("res://core/config/party_paths.gd")
const Packages = preload("res://core/content/party_packages.gd")
const Archive = preload("res://core/content/party_content_archive.gd")
const CHUNK: int = 32768
const MAX_FILE: int = 2147483648
signal changed()
var connection: Node
var directory: String
var rows: Array[Dictionary] = []
var message: String = ""
var staged: bool = false
var _offers: Dictionary = {}
var _active: String = ""
var _index: int = 0
var _offset: int = 0
var _speed_time: int = 0
var _speed_bytes: int = 0
var _file: FileAccess
var _queue: Array[String] = []
var _stage: String = ""
var _deadline: int = 0
var _preparing: bool = false
var _building: bool = false
var waiting: bool = false
var _gate_requirements: Dictionary = {}
var reports: Dictionary = {}
var phase: String = "join"
var check_id: String = ""
var _checked: bool = false
var _last_report: String = ""
var _report_time: int = 0

func _ready() -> void:
	changed.connect(_report_progress)

## The host freezes a roster until it stops the check or starts with every member verified.
func begin_start() -> void:
	if waiting or not connection.host or not connection.start_reason().is_empty():
		return
	waiting = true
	_gate_requirements = connection.room.start_requirements.duplicate(true)
	check_id = Data.token()
	reports.clear()
	for player: Dictionary in connection.players:
		if not player.connected:
			continue
		reports[player.player_id] = {"name": player.name, "ready": false, "checking": player.peer_id != 1, "message": "正在检查"}
		if player.peer_id == 1:
			var issue: String = connection._room_content_issue({"room": connection.room, "players": connection.players}, true)
			reports[player.player_id].ready = issue.is_empty()
			reports[player.player_id].message = "已就绪" if issue.is_empty() else issue
		else:
			offer(player.peer_id, connection.room.start_requirements, "start", check_id)
	changed.emit()

func start_ready() -> bool:
	if not waiting or reports.is_empty():
		return false
	for id: String in reports:
		if not reports[id].ready:
			return false
		var present: bool = false
		for player: Dictionary in connection.players:
			if player.player_id == id and player.connected:
				present = true
		if not present:
			return false
	return connection.start_reason().is_empty()

func stop_start() -> void:
	if not waiting:
		return
	var previous: String = check_id
	waiting = false
	reports.clear()
	check_id = ""
	for player: Dictionary in connection.players:
		if player.peer_id != 1:
			_offers.erase(player.peer_id)
			if player.connected:
				connection._send(player.peer_id, {"kind": "content_stop", "payload": {"check_id": previous}})
	changed.emit()

func stop_received(payload: Dictionary) -> void:
	if phase == "start" and payload.get("check_id") == check_id:
		reset()
		connection.connection_state = "connected"

func peer_left(peer: int) -> void:
	_offers.erase(peer)
	if waiting:
		var player: Dictionary = connection._player_peer(peer)
		if not player.is_empty() and reports.has(player.player_id):
			reports[player.player_id].ready = false
			reports[player.player_id].checking = false
			reports[player.player_id].message = "等待重连（客机已断开）"
			changed.emit()

func peer_joined(player: Dictionary) -> void:
	if not waiting:
		return
	if connection.room.start_requirements != _gate_requirements:
		stop_start()
		return
	reports[player.player_id] = {"name": player.name, "ready": false, "checking": true, "message": "正在复查"}
	offer(player.peer_id, connection.room.start_requirements, "start", check_id)
	changed.emit()

func receive_status(peer: int, payload: Dictionary) -> void:
	if not waiting or payload.get("check_id") != check_id or not payload.get("ready") is bool or not payload.get("message") is String or payload.message.length() > 2048:
		return
	var player: Dictionary = connection._player_peer(peer)
	if player.is_empty() or not reports.has(player.player_id):
		return
	reports[player.player_id].checking = false
	reports[player.player_id].ready = payload.ready
	reports[player.player_id].message = payload.message
	changed.emit()

func _report_progress() -> void:
	if connection.host or not connection.online or phase != "start":
		return
	var state: String = message
	if _checked:
		state = "已就绪"
	elif staged:
		state = "下载完成，等待客机重启后手动加入"
	elif not _active.is_empty():
		state = _row().name + "：" + str(_row().state)
		if not _preparing:
			state += " · " + progress_text(_row())
	else:
		for row: Dictionary in rows:
			if not row.error.is_empty():
				state = row.name + "：" + row.error
				break
	if state == _last_report or (not _checked and not staged and not _active.is_empty() and Time.get_ticks_msec() < _report_time):
		return
	_last_report = state
	_report_time = Time.get_ticks_msec() + 250
	connection._send(1, {"kind": "content_status", "payload": {"check_id": check_id, "ready": _checked, "message": state.left(2048)}})


func reset() -> void:
	waiting = false
	reports.clear()
	phase = "join"
	check_id = ""
	_checked = false
	_last_report = ""
	_report_time = 0
	_preparing = false
	_file = null
	_active = ""
	_queue.clear()
	_offers.clear()
	rows.clear()
	staged = false
	message = ""
	_deadline = 0
	changed.emit()

## Advertise source packages immediately; build only the package actually requested.
func offer(peer: int, requirements: Dictionary, stage: String = "join", token: String = "") -> void:
	var offered: Dictionary = {}
	for id: String in requirements.packages:
		var required: Dictionary = requirements.packages[id]
		var manifest: Dictionary = connection.catalog.packages[id]
		var relative: String = Paths.package_relative(manifest)
		var row: Dictionary = {"id": id, "name": required.name, "version": required.version, "relative": relative, "kind": manifest.kind, "supported_systems": required.supported_systems, "files": [], "error": ""}
		if not _editor_source(manifest):
			_describe(row, directory.path_join(relative))
		offered[id] = row
	_offers[peer] = offered
	if connection._player_peer(peer).is_empty():
		connection._hello_peers[peer] = Time.get_ticks_msec() + 600000
	connection._send(peer, {"kind": "content_offer", "payload": {"requirements": requirements, "items": offered.values(), "phase": stage, "check_id": token}})

func _editor_source(manifest: Dictionary) -> bool:
	return OS.has_feature("editor") and FileAccess.file_exists(ProjectSettings.globalize_path(str(manifest.get("_root", ""))).path_join("manifest.json"))

func _describe(row: Dictionary, root: String) -> void:
	row.files = []
	row.error = ""
	var descriptor: String = root.path_join("content.pck.json")
	var description: Variant = JSON.parse_string(FileAccess.get_file_as_string(descriptor)) if FileAccess.file_exists(descriptor) else null
	var validator: RefCounted = Packages.new()
	if not description is Dictionary or not validator.validate_descriptor(description).is_empty() or description.get("id") != row.id or description.get("version") != row.version or Paths.package_relative(description) != row.relative or description.get("artifact") != "content.pck" or description.get("supported_systems", []) != row.supported_systems or description.get("kind") != row.kind:
		row.error = "房主缺少对应版本的可分发 PCK"
		return
	var names: Array = ["content.pck.json", "content.pck"]
	names.append_array(description.get("external_files", []))
	for name: String in names:
		var input: FileAccess = FileAccess.open(root.path_join(name), FileAccess.READ)
		if input == null or input.get_length() > MAX_FILE:
			row.error = "房主发布文件缺失或过大：" + name
			return
		row.files.append({"path": name, "size": input.get_length()})

## Resolve a fixed generation before sending its file list; peers never see partial exports.
func prepare(peer: int, payload: Dictionary) -> void:
	if not _offers.has(peer) or not payload.get("id") is String or not _offers[peer].has(payload.id):
		return
	var row: Dictionary = _offers[peer][payload.id]
	var manifest: Dictionary = connection.catalog.packages[row.id]
	var root: String = directory.path_join(row.relative)
	row.error = ""
	if manifest.package_version != row.version:
		row.error = "房主内容版本已变化，请重新加入"
	elif _editor_source(manifest):
		while _building:
			await get_tree().process_frame
			if not _offers.has(peer) or not is_same(_offers[peer].get(payload.id), row):
				return
		_building = true
		var exporter: RefCounted = Packages.new()
		root = await exporter.distribution_root(connection.catalog, row.id, directory.path_join("tmp/content_distribution"))
		_building = false
		if not _offers.has(peer) or not is_same(_offers[peer].get(payload.id), row):
			return
		if root.is_empty():
			row.error = "房主自动生成分发包失败：" + exporter.last_error
	if row.error.is_empty():
		_describe(row, root)
	if row.error.is_empty():
		row["_root"] = root
	if connection._player_peer(peer).is_empty():
		connection._hello_peers[peer] = Time.get_ticks_msec() + 600000
	connection._send(peer, {"kind": "content_prepared", "payload": {"id": row.id, "files": row.files, "error": row.error}})

func receive_prepared(payload: Dictionary) -> void:
	if _active.is_empty() or payload.get("id") != _active or not _preparing:
		return
	if not payload.get("error") is String:
		_fail("无效的分发包准备结果")
		return
	if not payload.error.is_empty():
		_fail(payload.error)
		return
	var issue: String = _files_issue(payload.get("files"))
	if not issue.is_empty():
		_fail(issue)
		return
	_row().files = payload.files
	_row().total = _file_bytes(payload.files)
	_speed_time = Time.get_ticks_msec()
	_speed_bytes = 0
	_preparing = false
	_request()

func _files_issue(files: Variant) -> String:
	if not files is Array:
		return "无效的内容文件清单"
	var seen: Dictionary = {}
	for entry: Variant in files:
		if not entry is Dictionary or not entry.get("path") is String or not entry.get("size") is int or entry.size < 0 or entry.size > MAX_FILE or not Data.relative_path(entry.path) or entry.path != entry.path.simplify_path() or entry.path.split("/")[0] in ["config", "avatars"] or seen.has(entry.path):
			return "无效的内容文件清单"
		seen[entry.path] = true
	if not seen.has("content.pck") or not seen.has("content.pck.json"):
		return "分发包缺少 PCK 或描述文件"
	return ""

func receive_offer(payload: Dictionary) -> void:
	if payload.get("phase") not in ["join", "start"] or not payload.get("check_id") is String:
		connection.leave("无效的内容检查阶段")
		return
	if not payload.get("requirements") is Dictionary or not payload.get("items") is Array:
		connection.leave("无效的内容同步清单")
		return
	var requirements: Dictionary = payload.requirements
	if not requirements.get("packages") is Dictionary or payload.items.size() != requirements.packages.size():
		connection.leave("内容同步清单不完整")
		return
	var framework_check: Dictionary = {"framework": requirements.get("framework"), "packages": {}}
	var issue: String = connection.catalog.requirements_issue(framework_check)
	if not issue.is_empty():
		connection.leave(issue + "\n请手动更新框架")
		return
	reset()
	phase = payload.phase
	check_id = payload.check_id
	_stage = directory.path_join("tmp/content_download/" + Data.token())
	var ids: Dictionary = {}
	for value: Variant in payload.items:
		if not value is Dictionary or not value.get("id") is String or not Paths.folder(value.id) or not value.get("name") is String or not value.get("version") is String or not value.get("relative") is String or not value.get("files") is Array or not value.get("error") is String:
			connection.leave("无效的内容包条目")
			return
		if ids.has(value.id) or not requirements.packages.get(value.id) is Dictionary or requirements.packages[value.id].get("version") != value.version or requirements.packages[value.id].get("name") != value.name or requirements.packages[value.id].get("supported_systems") != value.get("supported_systems") or requirements.packages[value.id].get("kind") != value.get("kind"):
			connection.leave("内容同步条目与房间要求不一致")
			return
		if value.get("kind") not in Packages.Catalog.KINDS or not value.get("supported_systems") is Array or (value.kind == "assets" and not value.supported_systems.is_empty()) or (value.kind != "assets" and value.supported_systems.is_empty()):
			connection.leave("无效的平台声明")
			return
		for system: Variant in value.supported_systems:
			if not system is String:
				connection.leave("无效的平台声明")
				return
		ids[value.id] = true
		var row: Dictionary = value.duplicate(true)
		var parts: PackedStringArray = row.relative.split("/")
		if parts.size() < 2 or parts[0] not in ["protocols", "maingame", "minigame", "assets"] or not Data.relative_path(row.relative) or row.relative != row.relative.simplify_path() or parts[-1] != row.id:
			connection.leave("无效的内容安装路径")
			return
		if Paths.package_relative({"id": row.id, "kind": row.kind, "owner_protocol": parts[1]}) != row.relative:
			connection.leave("内容类型与安装路径不一致")
			return
		if not row.files.is_empty() and not _files_issue(row.files).is_empty():
			connection.leave("无效的内容文件清单")
			return
		var local: Dictionary = connection.catalog.packages.get(row.id, {})
		var supported: bool = row.kind == "assets" or Data.supports_system(row.supported_systems)
		if supported and local.get("package_version") == row.version and local.get("name", row.id) == row.name:
			continue
		row["current"] = local.get("package_version", "未安装")
		row["state"] = "pending"
		row["received"] = 0
		row["total"] = _file_bytes(row.files)
		row["speed"] = 0.0
		row["unsupported"] = not supported
		if OS.has_feature("editor") and FileAccess.file_exists("res://games/" + row.relative + "/manifest.json"):
			row.error = "开发源码不自动替换；请使用导出的游戏验证更新"
		if not supported:
			row.error = "平台不支持（" + Data.SYSTEM + "）"
		rows.append(row)
	if rows.is_empty():
		if phase == "join":
			connection._send(1, {"kind": "hello", "payload": connection.profiles.identity()})
		else:
			message = connection._room_content_issue({"room": connection.room, "players": connection.players}, true)
			_checked = message.is_empty()
			connection.connection_state = "connected"
	else:
		connection._connection_deadline = 0
		connection.connection_state = "syncing"
		message = "同步完成后需要重新启动。个人配置与存档保留。"
	changed.emit()

func download(id: String) -> void:
	for row: Dictionary in rows:
		if row.id == id and row.state != "done" and row.error.is_empty() and id != _active and id not in _queue:
			_queue.append(id)
	_next()

func download_all() -> void:
	if not rows.is_empty() and rows.all(func(row: Dictionary) -> bool: return row.state == "done"):
		_finish()
		return
	for row: Dictionary in rows:
		download(row.id)

func _next() -> void:
	if not _active.is_empty() or _queue.is_empty():
		return
	_active = _queue.pop_front()
	_index = 0
	_offset = 0
	_preparing = true
	_row().state = "正在准备分发包"
	_row().received = 0
	_row().speed = 0.0
	_deadline = Time.get_ticks_msec() + 600000
	connection._send(1, {"kind": "content_prepare", "payload": {"id": _active}})
	changed.emit()

func _row() -> Dictionary:
	for row: Dictionary in rows:
		if row.id == _active:
			return row
	return {}

func _request() -> void:
	var row: Dictionary = _row()
	if _index >= row.files.size():
		row.state = "done"
		row.speed = 0.0
		_active = ""
		_deadline = 0
		changed.emit()
		var complete: bool = true
		for item: Dictionary in rows:
			complete = complete and item.state == "done"
		if complete:
			_finish()
		else:
			_next()
		return
	var entry: Dictionary = row.files[_index]
	if _file == null:
		var path: String = _stage.path_join(row.relative).path_join(entry.path)
		var error: Error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		if error != OK:
			_fail(error_string(error))
			return
		_file = FileAccess.open(path, FileAccess.WRITE)
		if _file == null:
			_fail(error_string(FileAccess.get_open_error()))
			return
	row.state = "下载中 %d/%d" % [_index + 1, row.files.size()]
	_deadline = Time.get_ticks_msec() + 30000
	connection._send(1, {"kind": "content_get", "payload": {"id": _active, "index": _index, "offset": _offset}})
	changed.emit()

func serve(peer: int, payload: Dictionary) -> void:
	if not _offers.has(peer) or not payload.get("id") is String or not payload.get("index") is int or not payload.get("offset") is int:
		return
	var offered: Dictionary = _offers[peer]
	if not offered.has(payload.id):
		return
	var row: Dictionary = offered[payload.id]
	if not row.has("_root") or not row.error.is_empty() or payload.index < 0 or payload.index >= row.files.size():
		return
	var entry: Dictionary = row.files[payload.index]
	if payload.offset < 0 or payload.offset > entry.size:
		return
	var input: FileAccess = FileAccess.open(str(row._root).path_join(entry.path), FileAccess.READ)
	var reply: Dictionary = {"id": payload.id, "index": payload.index, "offset": payload.offset, "error": "", "bytes": PackedByteArray()}
	if input == null or input.get_length() != entry.size:
		reply.error = "房主文件已变化，请重新加入"
	else:
		input.seek(payload.offset)
		reply.bytes = input.get_buffer(mini(CHUNK, entry.size - payload.offset))
		if reply.bytes.size() != mini(CHUNK, entry.size - payload.offset):
			reply.error = "读取房主文件失败"
	if connection._player_peer(peer).is_empty():
		connection._hello_peers[peer] = Time.get_ticks_msec() + 600000
	connection._send(peer, {"kind": "content_chunk", "payload": reply})

func receive_chunk(payload: Dictionary) -> void:
	if _active.is_empty() or payload.get("id") != _active or payload.get("index") != _index or payload.get("offset") != _offset:
		return
	if not payload.get("error") is String or not payload.get("bytes") is PackedByteArray:
		_fail("无效的下载数据")
		return
	if not payload.error.is_empty():
		_fail(payload.error)
		return
	var row: Dictionary = _row()
	var expected: int = mini(CHUNK, int(row.files[_index].size) - _offset)
	if payload.bytes.size() != expected:
		_fail("下载长度不匹配")
		return
	_file.store_buffer(payload.bytes)
	_file.flush()
	if _file.get_error() != OK:
		_fail("写入失败：" + error_string(_file.get_error()))
		return
	_offset += expected
	row.received += expected
	if _offset == row.files[_index].size:
		_file = null
		_index += 1
		_offset = 0
	_request()

## Queue one bundle only after every requested version is present.
func _finish() -> void:
	for row: Dictionary in rows:
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(_stage.path_join(row.relative).path_join("content.pck.json")))
		if not raw is Dictionary or raw.get("id") != row.id or raw.get("version") != row.version or Paths.package_relative(raw) != row.relative or raw.get("supported_systems", []) != row.supported_systems or raw.get("kind") != row.kind:
			row.state = "失败，可重试"
			message = "下载包与房主声明不一致：" + row.id
			changed.emit()
			return
	var zip_path: String = _stage.path_join("download.zip")
	var writer: ZIPPacker = ZIPPacker.new()
	var error: Error = writer.open(zip_path)
	if error != OK:
		message = error_string(error)
		changed.emit()
		return
	var directories: Array[String] = []
	for row: Dictionary in rows:
		directories.append(row.relative)
		for entry: Dictionary in row.files:
			if error == OK:
				error = writer.start_file(row.relative.path_join(entry.path))
			if error == OK:
				var input: FileAccess = FileAccess.open(_stage.path_join(row.relative).path_join(entry.path), FileAccess.READ)
				if input == null:
					error = FileAccess.get_open_error()
				else:
					while input.get_position() < input.get_length() and error == OK:
						var bytes: PackedByteArray = input.get_buffer(CHUNK)
						if bytes.is_empty():
							error = ERR_FILE_CANT_READ
						else:
							error = writer.write_file(bytes)
			if error == OK:
				error = writer.close_file()
	if error == OK:
		error = writer.start_file("bundle.json")
	if error == OK:
		error = writer.write_file(JSON.stringify({"format": 2, "id": Data.token(), "packages": directories}).to_utf8_buffer())
	if error == OK:
		error = writer.close_file()
	var close_error: Error = writer.close()
	if error == OK:
		error = close_error
	var archive: RefCounted = Archive.new()
	if error == OK:
		error = archive.queue_update(zip_path, directory)
	staged = error == OK
	message = "更新后需要重启" if staged else "同步安装计划失败：" + archive.last_error + " " + error_string(error)
	changed.emit()

func _fail(reason: String) -> void:
	_preparing = false
	_row().state = "失败，可重试"
	_row().speed = 0.0
	_file = null
	_active = ""
	_queue.clear()
	_deadline = 0
	message = reason
	changed.emit()

## Report each package across all of its files; MB uses 1,000,000 bytes.
static func progress_text(row: Dictionary) -> String:
	var total: String = "%.2f MB" % (float(row.total) / 1000000.0) if not row.files.is_empty() else "待获取"
	return "%.2f MB / %s · %.2f MB/s" % [float(row.received) / 1000000.0, total, float(row.speed) / 1000000.0]

func _file_bytes(files: Array) -> int:
	var total: int = 0
	for entry: Dictionary in files:
		total += int(entry.size)
	return total

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	if _deadline > 0 and now > _deadline:
		_fail("下载超时，请重试或返回")
	if not _active.is_empty() and not _preparing and now - _speed_time >= 500:
		var row: Dictionary = _row()
		row.speed = float(row.received - _speed_bytes) * 1000.0 / float(now - _speed_time)
		_speed_bytes = row.received
		_speed_time = now
		changed.emit()
