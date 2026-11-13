## Join/start downloads use the shared dialog and theme's native progress bar.
extends RefCounted
var app: Control
var dialog: GPPartyDialog
var labels: Dictionary = {}
var buttons: Dictionary = {}
var progress_bars: Dictionary = {}
var progress_labels: Dictionary = {}
var status_label: Label
var _layout: String = ""

func initialize(application: Control) -> void:
	app = application
	app.connection.content_sync.changed.connect(refresh)
	app.connection.changed.connect(refresh)

func _close() -> void:
	if is_instance_valid(dialog):
		dialog.hide()
		if app._dialog == dialog:
			app._dialog = null
		dialog.queue_free()
		dialog = null
	_layout = ""

func refresh() -> void:
	var sync: Node = app.connection.content_sync
	var host_view: bool = app.connection.host and sync.waiting
	if not host_view and sync.rows.is_empty():
		_close()
		return
	if host_view:
		if sync.start_ready():
			_close()
			_start.call_deferred()
			return
		# Normal checks finish without opening a dialog; show only actionable waits.
		var blocked: bool = sync.reports.values().any(func(report: Dictionary) -> bool: return not report.ready and not report.checking)
		if not blocked and not is_instance_valid(dialog):
			return
	var completed: bool = not host_view and sync.staged
	var ids: Array = sync.reports.keys() if host_view else sync.rows.map(func(row: Dictionary) -> String: return row.id)
	if completed:
		ids = []
	var layout: String = str(host_view) + str(completed) + str(ids)
	if _layout != layout:
		_close()
	if not is_instance_valid(dialog):
		var content: VBoxContainer = app._modal(("等待客机检查" if app.catalog.source_mode else "等待客机下载") if host_view else ("更新完成" if completed else "同步房间内容"))
		dialog = app._dialog
		_layout = layout
		dialog.dialog_hide_on_ok = false
		dialog.cancel_enabled = not completed
		dialog.cancel_button_text = "终止并返回房间" if host_view else "返回"
		dialog.get_ok_button().visible = not host_view
		dialog.confirmed.connect(_confirm)
		dialog.canceled.connect(_cancel)
		status_label = Label.new()
		status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(status_label)
		labels.clear()
		buttons.clear()
		progress_bars.clear()
		progress_labels.clear()
		for id: String in ids:
			var line: HBoxContainer = HBoxContainer.new()
			content.add_child(line)
			var column: VBoxContainer = VBoxContainer.new()
			column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.add_child(column)
			var label: Label = Label.new()
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			column.add_child(label)
			labels[id] = label
			if not host_view:
				var progress: ProgressBar = ProgressBar.new()
				progress.custom_minimum_size.y = 20
				progress.show_percentage = false
				column.add_child(progress)
				progress_bars[id] = progress
				var detail: Label = Label.new()
				column.add_child(detail)
				progress_labels[id] = detail
				var button: Button = Button.new()
				button.custom_minimum_size = Vector2(180, 64)
				button.pressed.connect(sync.download.bind(id))
				line.add_child(button)
				buttons[id] = button
		dialog.popup_centered(Vector2i(1100, 850) if not completed else Vector2i(800, 400))
	if host_view:
		status_label.text = "等待客机完成检查、下载并重新加入。全部就绪后自动开始，也可终止并返回房间。"
		for id: String in ids:
			var report: Dictionary = sync.reports[id]
			labels[id].text = report.name + "\n" + report.message
			labels[id].add_theme_color_override("font_color", Color(1, 0.35, 0.35) if report.message.contains("平台不支持") else Color.WHITE)
		return
	status_label.text = sync.message
	if completed:
		status_label.text = "更新后需要重启"
		dialog.get_ok_button().text = "退出游戏"
		dialog.get_ok_button().disabled = false
		return
	for row: Dictionary in sync.rows:
		labels[row.id].text = "%s\n%s → %s%s" % [row.name, row.current, row.version, "\n" + row.error if not row.error.is_empty() else ""]
		labels[row.id].add_theme_color_override("font_color", Color(1, 0.35, 0.35) if row.unsupported else Color.WHITE)
		progress_bars[row.id].value = 100.0 * float(row.received) / float(row.total) if row.total > 0 else (100.0 if row.state == "done" else 0.0)
		progress_labels[row.id].text = sync.progress_text(row)
		var button: Button = buttons[row.id]
		button.text = "已下载" if row.state == "done" else ("下载" if row.current == "未安装" else "更新")
		if str(row.state).begins_with("下载中") or row.state == "正在准备分发包":
			button.text = row.state
		button.disabled = row.state == "done" or not row.error.is_empty() or sync._active == row.id or row.id in sync._queue
	dialog.get_ok_button().text = "全部同步"
	dialog.get_ok_button().disabled = not sync._active.is_empty() or sync.rows.any(func(row: Dictionary) -> bool: return row.unsupported)

func _cancel() -> void:
	if app.connection.host:
		app.connection.content_sync.stop_start()
	else:
		app.connection.leave()

## Defer startup until the status callback finishes; cancellation invalidates queued starts.
func _start() -> void:
	var sync: Node = app.connection.content_sync
	if not app.connection.host or not sync.start_ready():
		return
	var error: Error = app.runner.begin()
	sync.stop_start()
	if error != OK:
		app._notice("开始失败：" + error_string(error))

func _confirm() -> void:
	var sync: Node = app.connection.content_sync
	if sync.staged:
		app.get_tree().quit()
	else:
		sync.download_all()
