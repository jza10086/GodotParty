@tool
## Platform release picker. Business/export policy lives in core/dev and package manifests.
extends ConfirmationDialog
const Catalog = preload("res://core/content/party_catalog.gd")
const Selection = preload("res://core/dev/party_export_selection.gd")
var platform: String = "Windows"
var _catalog: RefCounted
var _tree: Tree
var _directory: LineEdit
var _browse: Button
var _picker: FileDialog
var _status: Label
var _items: Dictionary[String, TreeItem] = {}
var _requested: Array[String] = []
var _core: TreeItem
var _selection: Dictionary = {"ok": true, "ids": []}
var _worker: Thread
var _job: String
var _poll: float = 0.0

func _ready() -> void:
	title = "GodotParty · 导出 " + platform + " 可玩包"
	size = Vector2i(820, 720)
	min_size = Vector2i(660, 520)
	exclusive = true
	dialog_hide_on_ok = false
	get_ok_button().text = "开始导出"
	get_cancel_button().text = "关闭"
	var body: VBoxContainer = VBoxContainer.new()
	body.custom_minimum_size.x = 620
	body.add_theme_constant_override("separation", 12)
	add_child(body)
	var heading: Label = Label.new()
	heading.text = "导出内容"
	body.add_child(heading)
	_tree = Tree.new()
	_tree.hide_root = true
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.custom_minimum_size.y = 400
	body.add_child(_tree)
	_tree.item_edited.connect(_item_edited)
	var row: HBoxContainer = HBoxContainer.new()
	body.add_child(row)
	var label: Label = Label.new()
	label.text = "导出目录"
	row.add_child(label)
	_directory = LineEdit.new()
	_directory.placeholder_text = "选择可玩包的安装目录"
	_directory.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_directory)
	_directory.text_changed.connect(func(_value: String) -> void: _update_button())
	_browse = Button.new()
	_browse.text = "浏览…"
	row.add_child(_browse)
	_picker = FileDialog.new()
	_picker.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_picker.access = FileDialog.ACCESS_FILESYSTEM
	add_child(_picker)
	_picker.dir_selected.connect(func(path: String) -> void:
		_directory.text = path
		_update_button())
	_browse.pressed.connect(func() -> void: _picker.popup_centered_ratio(0.7))
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(620, 70)
	body.add_child(_status)
	confirmed.connect(_start_export)
	close_requested.connect(func() -> void:
		if not _busy(): hide())
	set_process(false)

func open() -> void:
	if _busy():
		popup_centered()
		return
	_catalog = Catalog.new()
	_catalog.scan()
	_tree.clear()
	_items.clear()
	_requested.clear()
	var root: TreeItem = _tree.create_item()
	_core = _tree.create_item(root)
	_core.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
	_core.set_text(0, {"Windows": "核心框架 · Windows x64", "Android": "核心框架 · Android APK", "iOS": "核心框架 · iOS IPA（SideStore）"}[platform])
	_core.set_metadata(0, "@core")
	_core.set_editable(0, true)
	_core.set_checked(0, true)
	for kind: String in ["protocols", "maingame", "minigame", "assets"]:
		var group: TreeItem = _tree.create_item(root)
		group.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		group.set_editable(0, true)
		group.set_metadata(0, "@" + kind)
		group.set_text(0, {"protocols": "协议与形象资产", "maingame": "主游戏", "minigame": "小游戏", "assets": "资产包"}[kind])
		for id: String in _catalog.ids(kind):
			var item: TreeItem = _add_package(group, id)
			if kind == "protocols":
				for avatar: String in _catalog.ids("avatars"):
					if _catalog.packages[avatar].owner_protocol == id:
						_add_package(item, avatar)
	if not _catalog.errors.is_empty():
		_status.text = "\n".join(_catalog.errors)
		_selection = {"ok": false}
	else:
		_refresh_selection()
	_update_button()
	popup_centered()

func _add_package(parent: TreeItem, id: String) -> TreeItem:
	var manifest: Dictionary = _catalog.get_package(id)
	var item: TreeItem = _tree.create_item(parent)
	item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
	item.set_metadata(0, id)
	item.set_text(0, _package_label(manifest))
	item.set_tooltip_text(0, id + "\n" + manifest._root)
	item.set_editable(0, manifest.get("playable", true))
	_items[id] = item
	return item

func _package_label(manifest: Dictionary) -> String:
	var label: String = manifest.get("name", manifest.id)
	if manifest.kind == "avatars":
		var slots: Array = []
		for info: Dictionary in manifest.get("appearance_resources", {}).values():
			if not slots.has(info.slot):
				slots.append(info.slot)
		var types: Array[String] = []
		for slot: String in slots:
			types.append({"avatar_2d": "2D 头像", "character_3d": "3D 形象"}.get(slot, slot))
		label += " · " + ", ".join(types)
		for info: Dictionary in manifest.get("appearance_resources", {}).values():
			if "占位" in info.get("name", ""):
				label += "（占位）"
				break
	if not manifest.get("playable", true):
		label += "（未开放）"
	return label

func _item_edited() -> void:
	var item: TreeItem = _tree.get_edited()
	var id: String = item.get_metadata(0)
	if id == "@core":
		_update_button()
		return
	if id.begins_with("@"):
		for package: String in _items:
			var kind: String = _catalog.packages[package].kind
			if kind == id.trim_prefix("@") or (id == "@protocols" and kind == "avatars"):
				if _catalog.packages[package].get("playable", true):
					_set_requested(package, item.is_checked(0))
	else:
		_set_requested(id, item.is_checked(0))
	_refresh_selection()

func _set_requested(id: String, selected: bool) -> void:
	if selected and not _requested.has(id):
		_requested.append(id)
	elif not selected:
		_requested.erase(id)

func _refresh_selection() -> void:
	_selection = Selection.resolve(_catalog, _requested)
	var ids: Array = _selection.get("ids", [])
	for id: String in _items:
		var item: TreeItem = _items[id]
		var required: bool = ids.has(id) and not _requested.has(id)
		item.set_checked(0, ids.has(id) or _requested.has(id))
		item.set_editable(0, not required and _catalog.packages[id].get("playable", true))
		item.set_text(0, _package_label(_catalog.get_package(id)) + ("（依赖）" if required else ""))
	for group: TreeItem in _tree.get_root().get_children():
		if group == _core:
			continue
		var selected: int = 0
		var total: int = 0
		for child: TreeItem in group.get_children():
			total += 1
			selected += int(child.is_checked(0))
		group.set_checked(0, total > 0 and selected == total)
		group.set_indeterminate(0, selected > 0 and selected < total)
	var description: String = "已选择 %d 个内容包（含依赖）。" % ids.size()
	if platform == "iOS":
		description += "GitHub 云构建：仅使用已推送的当前提交，不包含未提交修改。勾选核心生成需 SideStore 重签的 IPA；输出目录接收下载产物。需先运行 gh auth login。"
	else:
		description += "勾选核心生成测试签名 APK；内容 ZIP 可在游戏中导入，重启后生效。" if platform == "Android" else "已有配置及外置文件会保留。请先退出目标目录中的游戏。"
	_status.text = description if _selection.ok else _selection.error
	_update_button()

func _update_button() -> void:
	get_ok_button().disabled = _busy() or not _selection.ok or (_requested.is_empty() and not _core.is_checked(0)) or not _directory.text.is_absolute_path()

func _busy() -> bool:
	return _worker != null

func _start_export() -> void:
	if EditorInterface.get_resource_filesystem().is_scanning():
		_status.text = "请等待编辑器完成资源导入。"
		return
	EditorInterface.save_all_scenes()
	_job = ProjectSettings.globalize_path("res://tmp/exports/").path_join(str(Time.get_unix_time_from_system()).replace(".", "_") + "_" + str(randi()))
	var error: Error = DirAccess.make_dir_recursive_absolute(_job)
	if error != OK:
		_status.text = "无法创建构建目录：" + error_string(error)
		return
	var request: FileAccess = FileAccess.open(_job.path_join("request.json"), FileAccess.WRITE)
	if request == null:
		_status.text = "无法写入导出请求：" + error_string(FileAccess.get_open_error())
		return
	request.store_string(JSON.stringify({"platform": platform, "core": _core.is_checked(0), "packages": _requested, "output": _directory.text}))
	request.flush()
	error = request.get_error()
	request.close()
	if error != OK:
		_status.text = "写入导出请求失败：" + error_string(error)
		return
	_worker = Thread.new()
	var backend: String = "export_ios_cloud.ps1" if platform == "iOS" else "export_release.ps1"
	error = _worker.start(_run_export.bind(_job, ProjectSettings.globalize_path("res://core/dev/" + backend)))
	if error != OK:
		_worker = null
		_status.text = "无法启动导出：" + error_string(error)
		return
	_tree.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for item: TreeItem in _items.values():
		item.set_editable(0, false)
	_core.set_editable(0, false)
	for group: TreeItem in _tree.get_root().get_children():
		group.set_editable(0, false)
	_directory.editable = false
	_browse.disabled = true
	get_cancel_button().disabled = true
	_status.text = "正在导出…\n构建日志：" + _job
	_update_button()
	set_process(true)

func _run_export(job: String, script: String) -> Dictionary:
	var output: Array = []
	var code: int = OS.execute("powershell.exe", ["-NoProfile", "-ExecutionPolicy", "RemoteSigned", "-File", script, "-RequestPath", job.path_join("request.json")], output, true, false)
	return {"code": code, "output": "\n".join(output)}

func _process(delta: float) -> void:
	_poll -= delta
	if _worker.is_alive():
		if _poll <= 0.0:
			_poll = 0.5
			var path: String = _job.path_join("status.txt")
			if FileAccess.file_exists(path):
				_status.text = FileAccess.get_file_as_string(path) + "\n构建日志：" + _job
		return
	var result: Dictionary = _worker.wait_to_finish()
	_worker = null
	set_process(false)
	_tree.mouse_filter = Control.MOUSE_FILTER_STOP
	_core.set_editable(0, true)
	for group: TreeItem in _tree.get_root().get_children():
		group.set_editable(0, true)
	_directory.editable = true
	_browse.disabled = false
	get_cancel_button().disabled = false
	_refresh_selection()
	var passed: bool = result.code == 0 and "EXPORT_RELEASE_PASS" in result.output
	_status.text = ("导出完成：" + _directory.text) if passed else ("导出失败（%d）：\n" % result.code + result.output.right(1600))
	if passed and platform == "iOS":
		_status.text = "导出完成：" + FileAccess.get_file_as_string(_job.path_join("result.txt")) + "\nIPA 需要通过 SideStore 重签后安装。"
	_status.text += "\n构建日志：" + _job

func _exit_tree() -> void:
	if _worker != null:
		_worker.wait_to_finish()
