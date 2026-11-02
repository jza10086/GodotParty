extends PanelContainer


func set_mode(pad: bool, cursor: bool) -> void:
	$Hints.visible = pad
	$KeyboardHints.visible = not pad
	$Hints/Title.text = "Xbox 光标" if cursor else "Xbox 手柄"
	$Hints/Accept.pad_caption = "A" if cursor else ""
	for prompt in [$Hints/Accept, $Hints/Context, $Hints/Home, $Hints/Previous, $Hints/Next]:
		prompt.set_gamepad(true)
	$Hints/Context.description = "右键" if cursor else "上下文菜单"
	set_navigation("左键 / 拖动" if cursor else "确认",
		"切回焦点导航" if cursor else "十字键 / 左摇杆导航", "返回")


func set_navigation(accept: String, direction: String, back: String) -> void:
	$Hints/Accept.description = accept
	$Hints/Navigation.description = direction
	$Hints/Back.description = back

## Only show shortcuts available on the foreground page.
func set_context(fold: String, on_header: bool, tabs: bool, back_to_tabs: bool, editing: bool, keyboard: bool, cursor: bool, field: Control) -> void:
	var accept: String = "左键 / 拖动" if cursor else "确认"
	var navigation: String = "切回焦点导航" if cursor else "十字键 / 左摇杆导航"
	if editing:
		accept = "完成调节"
		navigation = "左右调节" if field is HSlider else "上下调节"
	elif keyboard:
		accept = "输入"
	elif not cursor and (field is LineEdit or field is TextEdit):
		accept = "打开键盘"
	elif not cursor and field is Slider:
		accept = "调节滑条"
	var back: String = "返回标签栏" if back_to_tabs else "返回"
	set_navigation(accept, navigation, "取消输入" if keyboard else ("退出调节" if editing else back))
	$Hints/Accept.visible = not on_header or cursor
	$Hints/Context.visible = not editing and not keyboard and (not fold.is_empty() or cursor or field is LineEdit or field is TextEdit)
	$Hints/Context.description = fold if not fold.is_empty() else ("右键" if cursor else "上下文菜单")
	$Hints/Home.visible = not editing and not keyboard
	$Hints/Home.description = "首个标签页" if tabs and cursor else "首个选项"
	$Hints/Previous.visible = tabs and not editing and not keyboard
	$Hints/Next.visible = $Hints/Previous.visible
	$KeyboardHints/Accept.description = fold if on_header else "确认"
