## Two-stage room content transfer. Requests address offered files only; installed PCKs
## are replaced by the existing archive bootstrap on the next launch.
extends Node
const Data = preload("res://core/runtime/party_data.gd")
const Paths = preload("res://core/config/party_paths.gd")
const Packages = preload("res://core/content/party_packages.gd")
const Archive = preload("res://core/content/party_content_archive.gd")
const CHUNK: int = 32768
const WINDOW: int = 8
const UPLOAD_QUEUE_LIMIT: int = 16
const CHUNKS_PER_FRAME: int = 16
const FLUSH_BYTES: int = 1048576
const MAX_FILE: int = 2147483648
signal changed()
var connection: Node
var directory: String
var rows: Array[Dictionary] = []
var message: String = ""
var staged: bool = false
var _offers: Dictionary = {}
var _uploads: Dictionary = {}
var _upload_cursor: int = 0
var _task: String = ""
var _generation: int = 0
var _pending_chunks: Dictionary = {}
var _requested_offset: int = 0
var _flush_bytes: int = 0
var _finishing: bool = false
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
			_uploads.erase(player.peer_id)
			if player.connected:
				connection._send(player.peer_id, {"kind": "content_stop", "payload": {"check_id": previous}})
	changed.emit()

func stop_received(payload: Dictionary) -> void:
	if phase == "start" and payload.get("check_id") == check_id:
		reset()
		connection.connection_state = "connected"

func peer_left(peer: int) -> void:
	_uploads.erase(peer)
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
	_generation += 1
	_end_task(true)
	_stage = ""
	_uploads.clear()
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

## Source tests exchange versions; published peers offer build identities and payload sizes.
func offer(peer: int, requirements: Dictionary, stage: String = "join", token: String = "") -> void:
	_uploads.erase(peer)
	var offered: Dictionary = {}
	for id: String in (requirements.packages.keys() if not connection.catalog.source_mode else []):
		var required: Dictionary = requirements.packages[id]
		var manifest: Dictionary = connection.catalog.packages[id]
		var files: Array[Dictionary] = connection.catalog.distribution_files(id)
		offered[id] = {"id": id, "name": manifest.name, "version": required.version, "build_id": required.build_id, "relative": Paths.package_relative(manifest), "kind": manifest.kind, "files": files, "error": "无法读取内容文件" if files.is_empty() else ""}
	_offers[peer] = offered
	if connection._player_peer(peer).is_empty():
		connection._hello_peers[peer] = Time.get_ticks_msec() + 600000
	connection._send(peer, {"kind": "content_offer", "payload": {"requirements": requirements, "items": offered.values(), "phase": stage, "check_id": token}})

func prepare(peer: int, payload: Dictionary) -> void:
	if not _offers.has(peer) or not payload.get("task") is String or payload.task.length() != 32 or not payload.get("id") is String or not _offers[peer].has(payload.id):
		return
	_uploads[peer] = {"task": payload.task, "id": payload.id, "queue": [], "file": null, "index": 0, "requested": 0, "served": 0, "complete": false}
	var row: Dictionary = _offers[peer][payload.id]
	row["_root"] = connection.catalog.artifacts[row.id].root
	if connection._player_peer(peer).is_empty():
		connection._hello_peers[peer] = Time.get_ticks_msec() + 600000
	connection._send(peer, {"kind": "content_prepared", "payload": {"task": payload.task, "id": row.id, "files": row.files, "error": row.error}})

func receive_prepared(payload: Dictionary) -> void:
	if _active.is_empty() or payload.get("task") != _task or payload.get("id") != _active or not _preparing:
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
		if not entry is Dictionary or not entry.get("path") is String or not entry.get("size") is int or entry.size < 0 or entry.size > MAX_FILE or not Data.relative_path(entry.path) or entry.path != entry.path.simplify_path() or not Packages.safe_payload_path(entry.path) or seen.has(entry.path):
			return "无效的内容文件清单"
		seen[entry.path] = true
	if not seen.has("content.pck.json"):
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
	if not requirements.get("packages") is Dictionary:
		connection.leave("内容同步清单不完整")
		return
	var framework_check: Dictionary = {"mode": requirements.get("mode"), "framework": requirements.get("framework"), "packages": {}}
	var issue: String = connection.catalog.requirements_issue(framework_check)
	if not issue.is_empty():
		connection.leave(issue)
		return
	if connection.catalog.source_mode:
		if not payload.items.is_empty():
			connection.leave("源码测试不能接收分发包")
			return
		reset()
		phase = payload.phase
		check_id = payload.check_id
		message = connection.catalog.requirements_issue(requirements)
		if phase == "join":
			if not message.is_empty():
				connection.leave("源码内容检查失败，请同步工程后重新运行：\n" + message)
				return
			connection._send(1, {"kind": "hello", "payload": connection.profiles.identity()})
		else:
			if message.is_empty():
				message = connection._room_content_issue({"room": connection.room, "players": connection.players}, true)
			_checked = message.is_empty()
			connection.connection_state = "connected"
		changed.emit()
		return
	if payload.items.size() != requirements.packages.size():
		connection.leave("内容同步清单不完整")
		return
	reset()
	phase = payload.phase
	check_id = payload.check_id

	var ids: Dictionary = {}
	for value: Variant in payload.items:
		if not value is Dictionary or not value.get("id") is String or not Paths.folder(value.id) or not value.get("name") is String or not value.get("version") is String or not value.get("relative") is String or not value.get("files") is Array or not value.get("error") is String:
			connection.leave("无效的内容包条目")
			return
		if ids.has(value.id) or not requirements.packages.get(value.id) is Dictionary or requirements.packages[value.id].get("version") != value.version or requirements.packages[value.id].get("build_id") != value.get("build_id"):
			connection.leave("内容同步条目与房间要求不一致")
			return
		if value.get("kind") not in Packages.Catalog.KINDS or not Packages.valid_build_id(value.get("build_id")) or Packages.Versions.parse(value.version).is_empty():
			connection.leave("无效的包类型、版本或构建标识")
			return
		ids[value.id] = true
		var row: Dictionary = value.duplicate(true)
		if not Packages.safe_payload_path(row.relative):
			connection.leave("无效的内容安装路径")
			return
		if not row.files.is_empty() and not _files_issue(row.files).is_empty():
			connection.leave("无效的内容文件清单")
			return
		var local: Dictionary = connection.catalog.packages.get(row.id, {})
		if local.get("package_version") == row.version and local.get("build_id") == row.build_id:
			continue
		row["current"] = local.get("package_version", "未安装")
		row["state"] = "pending"
		row["received"] = 0
		row["total"] = _file_bytes(row.files)
		row["speed"] = 0.0
		row["unsupported"] = false
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
	if _finishing or staged:
		return
	if not rows.is_empty() and rows.all(func(row: Dictionary) -> bool: return row.state == "done"):
		_finish()
		return
	for row: Dictionary in rows:
		download(row.id)

func _next() -> void:
	if _finishing or staged or not _active.is_empty() or _queue.is_empty():
		return
	if _stage.is_empty():
		_stage = directory.path_join("tmp/content_download/" + Data.token())
	_task = Data.token()
	_pending_chunks.clear()
	_requested_offset = 0
	_flush_bytes = 0
	_active = _queue.pop_front()
	_index = 0
	_offset = 0
	_preparing = true
	_row().state = "正在准备分发包"
	_row().received = 0
	_row().speed = 0.0
	_deadline = Time.get_ticks_msec() + 600000
	connection._send(1, {"kind": "content_prepare", "payload": {"task": _task, "id": _active}})
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
		_task = ""
		_deadline = 0
		changed.emit()
		if rows.all(func(item: Dictionary) -> bool: return item.state == "done"):
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
	while _pending_chunks.size() < WINDOW and (_requested_offset < entry.size or entry.size == 0 and _pending_chunks.is_empty()):
		_pending_chunks[_requested_offset] = mini(CHUNK, entry.size - _requested_offset)
		var error: Error = connection._send(1, {"kind": "content_get", "payload": {"task": _task, "id": _active, "index": _index, "offset": _requested_offset}})
		if error != OK:
			_fail("请求下载失败：" + error_string(error))
			return
		_requested_offset += mini(CHUNK, entry.size - _requested_offset)
		if entry.size == 0:
			break
	changed.emit()

## Requests enter a bounded per-peer queue; disk IO happens fairly in _process.
func serve(peer: int, payload: Dictionary) -> void:
	if not _uploads.has(peer) or not payload.get("index") is int or not payload.get("offset") is int:
		return
	var upload: Dictionary = _uploads[peer]
	if payload.get("task") != upload.task or payload.get("id") != upload.id or payload.index != upload.index or payload.offset != upload.requested or upload.complete:
		return
	var row: Dictionary = _offers[peer][upload.id]
	if not row.has("_root") or not row.error.is_empty() or upload.index >= row.files.size() or upload.queue.size() >= UPLOAD_QUEUE_LIMIT:
		return
	var entry: Dictionary = row.files[upload.index]
	if payload.offset < 0 or payload.offset > entry.size:
		return
	upload.queue.append(payload.duplicate())
	upload.requested += mini(CHUNK, entry.size - payload.offset)
	upload.complete = upload.requested == entry.size

func finish_upload(peer: int, payload: Dictionary, cancelled: bool) -> void:
	if not _uploads.has(peer):
		return
	var upload: Dictionary = _uploads[peer]
	if payload.get("task") != upload.task or payload.get("id") != upload.id:
		return
	if cancelled:
		_uploads.erase(peer)
		return
	var row: Dictionary = _offers[peer][upload.id]
	if payload.get("index") != upload.index or not upload.queue.is_empty() or upload.served != row.files[upload.index].size:
		return
	upload.file = null
	upload.index += 1
	upload.requested = 0
	upload.served = 0
	upload.complete = false
	if upload.index == row.files.size():
		_uploads.erase(peer)

func _serve_queued(peer: int) -> void:
	var upload: Dictionary = _uploads[peer]
	var payload: Dictionary = upload.queue.pop_front()
	var row: Dictionary = _offers[peer][upload.id]
	var entry: Dictionary = row.files[upload.index]
	var reply: Dictionary = {"task": upload.task, "id": upload.id, "index": upload.index, "offset": payload.offset, "error": "", "bytes": PackedByteArray()}
	if upload.file == null:
		upload.file = FileAccess.open(str(row._root).path_join(entry.path), FileAccess.READ)
	if upload.file == null or upload.file.get_length() != entry.size:
		reply.error = "房主文件已变化，请重新加入"
	else:
		var input: FileAccess = upload.file
		input.seek(payload.offset)
		var size: int = mini(CHUNK, entry.size - payload.offset)
		reply.bytes = input.get_buffer(size)
		if reply.bytes.size() != size:
			reply.error = "读取房主文件失败"
		else:
			upload.served += size
	if connection._player_peer(peer).is_empty():
		connection._hello_peers[peer] = Time.get_ticks_msec() + 600000
	var error: Error = connection._send(peer, {"kind": "content_chunk", "payload": reply})
	if error != OK or not reply.error.is_empty():
		_uploads.erase(peer)

func receive_chunk(payload: Dictionary) -> void:
	if _active.is_empty() or payload.get("task") != _task:
		return
	if payload.get("id") != _active or payload.get("index") != _index or payload.get("offset") != _offset or not _pending_chunks.has(_offset):
		_fail("下载文件或偏移不匹配")
		return
	if not payload.get("error") is String or not payload.get("bytes") is PackedByteArray:
		_fail("无效的下载数据")
		return
	if not payload.error.is_empty():
		_fail(payload.error)
		return
	var row: Dictionary = _row()
	var expected: int = _pending_chunks[_offset]
	if payload.bytes.size() != expected:
		_fail("下载长度不匹配")
		return
	_pending_chunks.erase(_offset)
	_file.store_buffer(payload.bytes)
	_offset += expected
	_flush_bytes += expected
	row.received += expected
	var complete: bool = _offset == row.files[_index].size
	if _flush_bytes >= FLUSH_BYTES or complete:
		_file.flush()
		_flush_bytes = 0
	if _file.get_error() != OK:
		_fail("写入失败：" + error_string(_file.get_error()))
		return
	if complete:
		_file.close()
		_file = null
		var error: Error = connection._send(1, {"kind": "content_complete", "payload": {"task": _task, "id": _active, "index": _index}})
		if error != OK:
			_fail("完成下载失败：" + error_string(error))
			return
		_index += 1
		_offset = 0
		_requested_offset = 0
	_request()

## Queue one bundle only after every requested version is present.
func _finish() -> void:
	if _finishing or staged:
		return
	_finishing = true
	var generation: int = _generation
	var stage: String = _stage
	var zip_path: String = stage.path_join("download.zip")
	var error: Error = await _write_bundle(zip_path, generation)
	var archive: RefCounted = Archive.new()
	if error == OK and generation == _generation:
		error = await archive.queue_update(zip_path, directory, func() -> bool: return generation == _generation, func(done: int, total: int) -> void:
			message = "整理文件 %d%%" % (100 * done / maxi(1, total))
			changed.emit())
	if generation != _generation:
		var cleanup_error: Error = archive._remove_stage(stage)
		if cleanup_error != OK:
			push_error("Cannot clear cancelled download: " + stage + " " + error_string(cleanup_error))
		_finishing = false
		_next()
		return
	_finishing = false
	if error != OK:
		_fail("同步安装计划失败：" + archive.last_error + " " + error_string(error))
		return
	staged = true
	message = "更新后需要重启"
	_end_task(true)
	changed.emit()

func _write_bundle(zip_path: String, generation: int) -> Error:
	for row: Dictionary in rows:
		var raw: Dictionary = Data.read_json(_stage.path_join(row.relative).path_join("content.pck.json"))
		if raw.get("id") != row.id or raw.get("version") != row.version or raw.get("build_id") != row.build_id or raw.get("kind") != row.kind:
			return ERR_INVALID_DATA
	var writer: ZIPPacker = ZIPPacker.new()
	var error: Error = writer.open(zip_path)
	if error != OK:
		return error
	var directories: Array[String] = []
	var total: int = 0
	var done: int = 0
	var budget: int = 0
	for row: Dictionary in rows:
		total += row.total
	for row: Dictionary in rows:
		directories.append(row.relative)
		for entry: Dictionary in row.files:
			if error != OK:
				break
			error = writer.start_file(row.relative.path_join(entry.path))
			if error != OK:
				break
			var input: FileAccess = FileAccess.open(_stage.path_join(row.relative).path_join(entry.path), FileAccess.READ)
			if input == null:
				error = FileAccess.get_open_error()
				break
			while input.get_position() < input.get_length() and error == OK:
				var bytes: PackedByteArray = input.get_buffer(CHUNK)
				if bytes.is_empty():
					error = ERR_FILE_CANT_READ
				else:
					error = writer.write_file(bytes)
					done += bytes.size()
					budget += bytes.size()
				if budget >= FLUSH_BYTES:
					message = "整理文件 %d%%" % (100 * done / maxi(1, total))
					changed.emit()
					await get_tree().process_frame
					budget = 0
					if generation != _generation:
						error = ERR_SKIP
			input.close()
			if error == OK:
				error = writer.close_file()
	if error == OK:
		error = writer.start_file("bundle.json")
	if error == OK:
		error = writer.write_file(JSON.stringify({"format": 2, "id": Data.token(), "packages": directories}).to_utf8_buffer())
	if error == OK:
		error = writer.close_file()
	var close_error: Error = writer.close()
	return error if error != OK else close_error

## Shared task exit: close IO, invalidate requests and reclaim only this download task.
func _end_task(remove_stage: bool) -> void:
	if not _task.is_empty() and connection.online and not connection.host:
		connection._send(1, {"kind": "content_cancel", "payload": {"task": _task, "id": _active}})
	_task = ""
	if _file != null:
		_file.close()
	_file = null
	_pending_chunks.clear()
	_preparing = false
	_active = ""
	_queue.clear()
	_deadline = 0
	if remove_stage and not _stage.is_empty() and not _finishing:
		var archive: RefCounted = Archive.new()
		var error: Error = archive._remove_stage(_stage)
		if error != OK:
			message += "；无法清理下载目录：" + error_string(error)
		_stage = ""

func _fail(reason: String) -> void:
	message = reason
	for row: Dictionary in rows:
		row.state = "失败，可重试"
		row.speed = 0.0
		row.received = 0
	_end_task(true)
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
	var peers: Array = _uploads.keys()
	if not peers.is_empty():
		for work: int in CHUNKS_PER_FRAME:
			var peer: int = peers[_upload_cursor % peers.size()]
			_upload_cursor += 1
			if _uploads.has(peer) and not _uploads[peer].queue.is_empty():
				_serve_queued(peer)
	var now: int = Time.get_ticks_msec()
	if _deadline > 0 and now > _deadline:
		_fail("下载超时，请重试或返回")
	if not _active.is_empty() and not _preparing and now - _speed_time >= 500:
		var row: Dictionary = _row()
		row.speed = float(row.received - _speed_bytes) * 1000.0 / float(now - _speed_time)
		_speed_bytes = row.received
		_speed_time = now
		changed.emit()
