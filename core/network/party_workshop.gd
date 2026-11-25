## Workshop subscriptions for one Steam friends room, published by its owner.
## The snapshot is split across lobby keys so it is available before a multiplayer peer is opened.
extends RefCounted

const IDS_PER_KEY: int = 128
const SUBSCRIBED: int = 1
const INSTALLED: int = 4
const NEEDS_UPDATE: int = 8
const DOWNLOADING: int = 16
const PENDING: int = 32
const STALL_MS: int = 120000

var api: Object
var last_error: String = ""
var _generation: int = 0
var _item: int = 0
var _query: int = 0
var _query_result: int = -1
var _returned: int = 0
var _subscribe_result: int = -1
var _download_result: int = -1

func _subscribed(result: int, id: int) -> void:
	if id == _item:
		_subscribe_result = result

func _downloaded(result: int, id: int, app: int) -> void:
	if id == _item and app == api.getAppID():
		_download_result = result

func _queried(handle: int, result: int, returned: int, _total: int, _cached: bool, _cursor: String) -> void:
	if handle == _query:
		_query_result = result
		_returned = returned

func _release_query() -> void:
	if _query not in [0, -1]:
		api.releaseQueryUGCRequest(_query)
	_query = 0

func cancel() -> void:
	_release_query()
	_generation += 1
	_item = 0

func _fail(message: String) -> Error:
	last_error = message
	return FAILED

## Write the inactive bank, then publish its bank and count together. A failed write
## leaves the previous list readable, including when both lists have the same length.
func publish(lobby: int, ids: Array) -> Error:
	var previous: String = api.getLobbyData(lobby, "ugc_manifest")
	var bank: String = "1" if previous.begins_with("0/") else "0"
	for offset: int in range(0, ids.size(), IDS_PER_KEY):
		var words: PackedStringArray = []
		for id: int in ids.slice(offset, offset + IDS_PER_KEY):
			words.append(str(id))
		if not api.setLobbyData(lobby, "ugc_%s_%d" % [bank, offset / IDS_PER_KEY], ",".join(words)):
			return _fail("无法发布完整的工坊清单")
	if not api.setLobbyData(lobby, "ugc_manifest", "%s/%d" % [bank, ids.size()]):
		return _fail("无法发布工坊清单长度")
	return OK

func read_manifest(lobby: int) -> Dictionary:
	var header: String = api.getLobbyData(lobby, "ugc_manifest")
	var fields: PackedStringArray = header.split("/")
	if fields.size() != 2 or fields[0] not in ["0", "1"]:
		return {"ok": false, "message": "房主未提供有效的工坊清单"}
	var raw: String = fields[1]
	if not raw.is_valid_int() or raw != str(raw.to_int()) or raw.to_int() < 0:
		return {"ok": false, "message": "房主的工坊清单长度无效"}
	var count: int = raw.to_int()
	var ids: Array[int] = []
	var seen: Dictionary[int, bool] = {}
	# A missing chunk fails immediately without allocating from an untrusted count.
	while ids.size() < count:
		var offset: int = ids.size()
		var chunk: String = api.getLobbyData(lobby, "ugc_%s_%d" % [fields[0], offset / IDS_PER_KEY])
		var words: PackedStringArray = chunk.split(",")
		if words.size() != mini(IDS_PER_KEY, count - offset):
			return {"ok": false, "message": "房主的工坊清单分段不完整"}
		for word: String in words:
			var id: int = word.to_int()
			if id <= 0 or word != str(id) or seen.has(id):
				return {"ok": false, "message": "房主的工坊物品 ID 无效或重复"}
			seen[id] = true
			ids.append(id)
	return {"ok": true, "ids": ids}

static func _current(state: int) -> bool:
	return (state & (INSTALLED | NEEDS_UPDATE | DOWNLOADING | PENDING)) == INSTALLED

## Lobby metadata is supplied by a peer. Check new items against this game's App ID
## before making any changes to the player's Steam subscriptions.
func _verify_new(ids: Array, tree: SceneTree, generation: int) -> Error:
	var local: Dictionary = {}
	for id: int in api.getSubscribedItems(true):
		local[id] = true
	var missing: Array[int] = []
	for id: int in ids:
		if not local.has(id):
			missing.append(id)
	for offset: int in range(0, missing.size(), 50):
		var batch: Array[int] = missing.slice(offset, offset + 50)
		_query_result = -1
		_query = api.createQueryUGCDetailsRequest(batch)
		if _query in [0, -1]:
			return _fail("无法查询工坊物品")
		api.sendQueryUGCRequest(_query)
		var deadline: int = Time.get_ticks_msec() + STALL_MS
		while _query_result == -1:
			await tree.create_timer(0.2).timeout
			if generation != _generation:
				return ERR_SKIP
			if Time.get_ticks_msec() >= deadline:
				_release_query()
				return _fail("检查工坊物品所属游戏超时")
		var needed: Dictionary = {}
		for id: int in batch:
			needed[id] = true
		if _query_result == 1:
			for index: int in _returned:
				var item: Dictionary = api.getQueryUGCResult(_query, index)
				if item.get("result") == 1 and item.get("consumer_app_id") == api.getAppID():
					needed.erase(item.get("file_id"))
		_release_query()
		if not needed.is_empty():
			return _fail("工坊物品 %d 不可用或不属于当前游戏（查询结果 %d）" % [needed.keys()[0], _query_result])
	return OK

## GodotSteam uses one outstanding SubscribeItem call result. Process IDs in order;
## let Steam retain subscriptions and ongoing downloads if the player leaves.
func synchronize(ids: Array, tree: SceneTree) -> Error:
	cancel()
	if not api.subscribe_item.is_connected(_subscribed):
		api.ugc_query_completed.connect(_queried)
		api.subscribe_item.connect(_subscribed)
		api.item_downloaded.connect(_downloaded)
	last_error = ""
	var generation: int = _generation
	var verified: Error = await _verify_new(ids, tree, generation)
	if verified != OK:
		return verified
	for id: int in ids:
		_item = id
		_subscribe_result = -1
		_download_result = -1
		var state: int = api.getItemState(id)
		if (state & SUBSCRIBED) == 0:
			api.subscribeItem(id)
			var deadline: int = Time.get_ticks_msec() + STALL_MS
			while _subscribe_result == -1:
				await tree.create_timer(0.2).timeout
				if generation != _generation:
					return ERR_SKIP
				if Time.get_ticks_msec() >= deadline:
					return _fail("订阅工坊物品 %d 超时" % id)
			if _subscribe_result != 1:
				return _fail("订阅工坊物品 %d 失败（%d）" % [id, _subscribe_result])
			state = api.getItemState(id)
		if not _current(state):
			if not api.downloadItem(id, true):
				return _fail("Steam 拒绝下载工坊物品 %d" % id)
			var deadline: int = Time.get_ticks_msec() + STALL_MS
			var previous: int = -1
			while not _current(api.getItemState(id)):
				if _download_result != -1 and _download_result != 1:
					return _fail("下载工坊物品 %d 失败（%d）" % [id, _download_result])
				var info: Dictionary = api.getItemDownloadInfo(id)
				var downloaded: int = int(info.get("downloaded", 0))
				if downloaded > previous:
					previous = downloaded
					deadline = Time.get_ticks_msec() + STALL_MS
				if Time.get_ticks_msec() >= deadline:
					return _fail("下载工坊物品 %d 超时" % id)
				await tree.create_timer(0.2).timeout
				if generation != _generation:
					return ERR_SKIP
		var installed: Dictionary = api.getItemInstallInfo(id)
		if not installed.ret:
			return _fail("Steam 未提供工坊物品 %d 的安装目录" % id)
	_item = 0
	return OK

## Released items contain one exported package directory. Steam owns these directories.
func refresh_catalog(catalog: RefCounted, directory: String) -> Error:
	if catalog.source_mode:
		return OK
	var descriptors: Dictionary[String, int] = {}
	for id: int in api.getSubscribedItems(false):
		if not _current(api.getItemState(id)):
			continue
		var info: Dictionary = api.getItemInstallInfo(id)
		if not info.ret:
			return _fail("工坊物品 %d 缺少安装目录" % id)
		var path: String = String(info.folder).path_join("content.pck.json")
		if not FileAccess.file_exists(path) or descriptors.has(path):
			return _fail("工坊物品 %d 的内容包描述缺失或重复" % id)
		descriptors[path] = id
	var store: RefCounted = catalog.package_store
	if descriptors.is_empty() and store.workshop_ids.is_empty():
		return OK
	var candidate: RefCounted = preload("res://core/content/party_packages.gd").new()
	if candidate.prepare(directory, {}, [], descriptors) != OK:
		return _fail(candidate.last_error)
	for id: String in store.installed:
		if candidate.installed.has(id) and candidate.installed[id].build_id != store.installed[id].build_id:
			return _fail("已登记的内容已更新，请重启游戏再加入：" + id)
	for id: String in store.mounted:
		if not candidate.installed.has(id) or candidate.installed[id].build_id != store.mounted[id].build_id or candidate.unavailable.has(id):
			return _fail("已挂载的内容已变更，请重启游戏再加入：" + id)
	# Keep the app, catalog and package installer on the same store. Mounted PCKs stay in place.
	store.installed = candidate.installed
	store.roots = candidate.roots
	store.unavailable = candidate.unavailable
	store.workshop_ids = candidate.workshop_ids
	var error: Error = catalog.use_installed(store)
	if error != OK:
		return _fail(str(catalog.errors))
	return OK
