@tool
## Platform release picker. Business/export policy lives in core/dev and package manifests.
extends ConfirmationDialog
const Catalog = preload("res://core/content/party_catalog.gd")
const Selection = preload("res://core/content/party_content_selection.gd")
const Versions = preload("res://core/content/party_versions.gd")

## Keep invalid dependency declarations visible for review even when the build catalog rejects their manifest.
class ReviewCatalog extends Catalog:
	var rejected_requirements: Array[Dictionary] = []
	var rejected_roots: Dictionary[String, String] = {}

	func register_manifest(path: String, load_names: bool = true) -> Error:
		var error: Error = super.register_manifest(path, load_names)
		if error == OK:
			return OK
		var manifest: Dictionary = read_manifest(path)
		if manifest.get("id") is String and manifest.get("dependencies") is Dictionary:
			for id: String in manifest.dependencies:
				var version: Variant = manifest.dependencies[id]
				if not Versions.valid_range(version) or not Data.identifier(id):
					rejected_roots[manifest.id] = path.get_base_dir()
					rejected_requirements.append({"id": id, "version": version, "required_by": manifest.id, "issue": "依赖声明无效"})
		return error

var platform: String = "Windows"
var _catalog: ReviewCatalog
var _tree: Tree
var _dependencies: Tree
var _directory: LineEdit
var _browse: Button
var _picker: FileDialog
var _status: Label
var _progress: ProgressBar
var _progress_label: Label
var _names: Dictionary[String, String] = {}
var _items: Dictionary[String, TreeItem] = {}
var _requested: Array[String] = []
var _core: TreeItem
var _selection: Dictionary = {"ok": true, "ids": []}
var _pid: int = -1
var _job: String
var _poll: float = 0.0

func _ready() -> void:
	title = "GodotParty · 导出 " + platform + " 可玩包"
	size = Vector2i(1360, 720)
	min_size = Vector2i(660, 520)
	exclusive = true
	dialog_hide_on_ok = false
	get_ok_button().text = "开始导出"
	get_cancel_button().text = "关闭"
	var body: VBoxContainer = VBoxContainer.new()
	body.custom_minimum_size.x = 620
	body.add_theme_constant_override("separation", 12)
	add_child(body)
	var tabs: TabContainer = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.custom_minimum_size.y = 400
	body.add_child(tabs)
	_tree = Tree.new()
	_tree.name = "导出内容"
	_tree.hide_root = true
	_tree.columns = 3
	_tree.column_titles_visible = true
	_tree.set_column_title(0, "id")
	_tree.set_column_title(1, "版本")
	_tree.set_column_title(2, "中文名")
	_tree.set_column_expand(1, false)
	_tree.set_column_custom_minimum_width(1, 90)
	tabs.add_child(_tree)
	_tree.item_edited.connect(_item_edited)
	_dependencies = Tree.new()
	_dependencies.name = "必要依赖"
	_dependencies.hide_root = true
	_dependencies.columns = 6
	_dependencies.column_titles_visible = true
	for column: int in _dependencies.columns:
		_dependencies.set_column_title(column, ["依赖 ID", "依赖中文名", "要求版本", "来源 ID", "来源中文名", "状态"][column])
		_dependencies.set_column_expand(column, column != 2 and column != 5)
	_dependencies.set_column_custom_minimum_width(2, 95)
	_dependencies.set_column_custom_minimum_width(5, 200)
	tabs.add_child(_dependencies)
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
	_progress = ProgressBar.new()
	_progress.name = "ExportProgress"
	_progress.show_percentage = false
	_progress.custom_minimum_size.y = 20
	_progress.hide()
	body.add_child(_progress)
	_progress_label = Label.new()
	_progress_label.name = "ExportProgressLabel"
	_progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_progress_label.hide()
	body.add_child(_progress_label)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(620, 70)
	body.add_child(_status)
	confirmed.connect(_start_export)
	close_requested.connect(hide)
	set_process(false)

func open() -> void:
	if _busy():
		popup_centered()
		return
	_progress.hide()
	_progress_label.hide()
	_catalog = ReviewCatalog.new()
	_catalog.scan(false)
	_tree.clear()
	_dependencies.clear()
	_items.clear()
	_names.clear()
	for id: String in _catalog.rejected_roots:
		_names[id] = _chinese_name({"id": id, "_root": _catalog.rejected_roots[id]})
	_requested.clear()
	var root: TreeItem = _tree.create_item()
	_core = _tree.create_item(root)
	_core.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
	_core.set_text(0, {"Windows": "核心框架 · Windows x64", "Android": "核心框架 · Android APK", "iOS": "核心框架 · iOS IPA（SideStore）"}[platform])
	_core.set_text(1, preload("res://core/framework_version.gd").VERSION)
	_core.set_metadata(0, "@core")
	_core.set_editable(0, true)
	_core.set_checked(0, true)
	for kind: String in ["protocols", "assets", "maingame", "minigame"]:
		var group: TreeItem = _tree.create_item(root)
		group.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		group.set_editable(0, true)
		group.set_metadata(0, "@" + kind)
		group.set_text(0, {"protocols": "协议", "assets": "资产包", "maingame": "主游戏", "minigame": "小游戏"}[kind])
		for id: String in _catalog.ids(kind):
			_add_package(group, id)
	_refresh_selection()
	popup_centered()

func _add_package(parent: TreeItem, id: String) -> TreeItem:
	var manifest: Dictionary = _catalog.packages[id]
	var item: TreeItem = _tree.create_item(parent)
	item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
	item.set_metadata(0, id)
	item.set_text(0, id)
	item.set_text(1, manifest.package_version)
	_names[id] = _chinese_name(manifest)
	item.set_text(2, _names[id])
	item.set_tooltip_text(2, item.get_text(2))
	item.set_tooltip_text(0, id + "\n" + manifest._root)
	item.set_editable(0, manifest.get("playable", true))
	_items[id] = item
	return item

func _chinese_name(manifest: Dictionary) -> String:
	var path: String = manifest._root.path_join("i18n/zh_Hans.po")
	if not FileAccess.file_exists(path):
		return manifest.id
	var translation: Translation = load(path)
	if translation == null or translation.locale != "zh_Hans":
		_catalog.errors.append("无效的中文翻译资源：" + path)
		return manifest.id
	var display_name: String = translation.get_message("package.name").strip_edges()
	return manifest.id if display_name.is_empty() else display_name

func _item_edited() -> void:
	var item: TreeItem = _tree.get_edited()
	var id: String = item.get_metadata(0)
	if id == "@core":
		_update_button()
		return
	if id.begins_with("@"):
		for package: String in _items:
			var kind: String = _catalog.packages[package].kind
			if kind == id.trim_prefix("@"):
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
	_selection = Selection.resolve(_catalog, _requested) if _catalog.errors.is_empty() else {"ok": false, "error": "\n".join(_catalog.errors)}
	for id: String in _items:
		var item: TreeItem = _items[id]
		item.set_checked(0, _requested.has(id))
		item.set_editable(0, _catalog.packages[id].get("playable", true))
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
	_refresh_dependencies()
	var description: String = "已选择 %d 个内容包。" % _requested.size()
	if platform == "iOS":
		description += "GitHub 云构建：仅使用已推送的当前提交，不包含未提交修改。勾选核心生成需 SideStore 重签的 IPA；输出目录接收下载产物。需先运行 gh auth login。"
	else:
		description += "勾选核心生成测试签名 APK；内容 ZIP 可在游戏中导入，重启后生效。" if platform == "Android" else "保留个人配置；正式外置文件随包更新。请先退出目标目录中的游戏。"
	_status.text = description if _selection.ok else _selection.error
	_update_button()

func _refresh_dependencies() -> void:
	_dependencies.clear()
	var root: TreeItem = _dependencies.create_item()
	var rows: Array[Dictionary] = Selection.requirements(_catalog, _requested)
	rows.append_array(_catalog.rejected_requirements)
	for dependency: Dictionary in rows:
		var item: TreeItem = _dependencies.create_item(root)
		var included: bool = _requested.has(dependency.id)
		var id: String = dependency.id
		var source: String = dependency.required_by
		var issue: String = _dependency_issue(dependency)
		item.set_text(0, id)
		item.set_text(1, _names.get(id, id))
		item.set_text(2, str(dependency.get("version", "未限定")))
		item.set_text(3, source)
		item.set_text(4, _names.get(source, source))
		item.set_text(5, issue if not issue.is_empty() else ("已勾选" if included else "未随本次导出"))
		for column: int in _dependencies.columns:
			item.set_tooltip_text(column, item.get_text(column))
			if not issue.is_empty():
				item.set_custom_color(column, Color("#ff7676"))
			elif not included:
				item.set_custom_color(column, Color("#ffd166"))

func _dependency_issue(row: Dictionary) -> String:
	if row.has("issue"):
		return row.issue
	if row.has("version") and not Versions.valid_range(row.version):
		return "版本声明无效"
	if not _catalog.packages.has(row.id):
		return "缺少内容包"
	var target: Dictionary = _catalog.packages[row.id]
	if row.has("version") and not Versions.matches(target.package_version, row.version):
		return "版本不符（当前 %s）" % target.package_version
	if row.get("protocol", false) and target.kind != "protocols":
		return "依赖目标不是协议"
	return _catalog.unavailable.get(row.id, "")

func _update_button() -> void:
	get_ok_button().disabled = _busy() or not _selection.ok or (_requested.is_empty() and not _core.is_checked(0)) or not _directory.text.is_absolute_path()

func _busy() -> bool:
	return _pid >= 0

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
	var script: String = ProjectSettings.globalize_path("res://core/dev/export_job.ps1")
	_pid = OS.create_process("powershell.exe", ["-NoProfile", "-ExecutionPolicy", "RemoteSigned", "-File", script, "-RequestPath", _job.path_join("request.json")], false)
	if _pid < 0:
		_status.text = "无法启动导出进程。"
		return
	_tree.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for item: TreeItem in _items.values():
		item.set_editable(0, false)
	_core.set_editable(0, false)
	for group: TreeItem in _tree.get_root().get_children():
		group.set_editable(0, false)
	_directory.editable = false
	_browse.disabled = true
	_progress.max_value = 1
	_progress.value = 0
	_progress.indeterminate = false
	_progress.show()
	_progress_label.text = "准备导出"
	_progress_label.show()
	_poll = 0.0
	_status.text = "正在导出…\n构建日志：" + _job
	_update_button()
	set_process(true)

## Progress counts completed build stages, not estimated time. The worker replaces this file atomically.
func _read_progress() -> void:
	var path: String = _job.path_join("progress.json")
	if not FileAccess.file_exists(path):
		return
	var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	_progress.max_value = record.total
	_progress.value = record.completed
	_progress.indeterminate = record.indeterminate
	_progress_label.text = "阶段 %d/%d · %s" % [record.completed, record.total, record.stage]

## The job continues independently if the dialog/plugin/editor closes.
func _process(delta: float) -> void:
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = 0.5
	_read_progress()
	if OS.is_process_running(_pid):
		var path: String = _job.path_join("status.txt")
		if FileAccess.file_exists(path):
			_status.text = FileAccess.get_file_as_string(path) + "\n构建日志：" + _job
		return
	var code: int = OS.get_process_exit_code(_pid)
	_pid = -1
	set_process(false)
	_tree.mouse_filter = Control.MOUSE_FILTER_STOP
	_core.set_editable(0, true)
	for group: TreeItem in _tree.get_root().get_children():
		group.set_editable(0, true)
	_directory.editable = true
	_browse.disabled = false
	_refresh_selection()
	var result_path: String = _job.path_join("job-result.json")
	var result: Variant = JSON.parse_string(FileAccess.get_file_as_string(result_path)) if FileAccess.file_exists(result_path) else null
	_progress.indeterminate = false
	if code == 0 and result is Dictionary and result.get("ok") == true:
		_progress.value = _progress.max_value
		_progress_label.text = "导出完成"
		_status.text = "导出完成：" + str(result.output)
		if platform == "iOS":
			_status.text += "\nIPA 需要通过 SideStore 重签后安装。"
	else:
		_progress_label.text = "导出失败"
		var reason: String = str(result.get("error", "")) if result is Dictionary else "后台任务未写入完成结果，请查看 export.log。"
		_status.text = "导出失败（%d）：\n%s" % [code, reason]
	_status.text += "\n构建日志：" + _job
