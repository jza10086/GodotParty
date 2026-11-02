extends Node

const Backdrop = preload("res://core/ui/ambient_reveal/components/popup_backdrop.gd")
const BackdropScene: PackedScene = preload("res://core/ui/ambient_reveal/components/parts/popup_backdrop.tscn")


func _ready() -> void:
	get_parent().ready.connect(_install, CONNECT_ONE_SHOT)


func _install() -> void:
	var button: Node = get_parent()
	var popup: Window = button.get_popup()
	var backdrop: Backdrop = BackdropScene.instantiate()
	if button is OptionButton:
		backdrop.inset = Vector2.ZERO
		popup.theme_type_variation = &"DropdownPopup"
		popup.about_to_popup.connect(_fit_options.bind(button, popup))
	popup.add_child(backdrop)
	if button is ColorPickerButton:
		button.get_picker().theme = preload("res://core/ui/ambient_reveal/compact_picker_theme.tres")

## Match the native popup's screen pixels and its logical row height to the opener.
func _fit_options(button: OptionButton, popup: PopupMenu) -> void:
	var screen_scale: Vector2 = button.get_screen_transform().get_scale()
	popup.content_scale_factor = screen_scale.y
	var viewport: Viewport = button.get_viewport()
	var max_height: int = roundi(viewport.get_visible_rect().size.y) if viewport.is_embedding_subwindows() else DisplayServer.screen_get_usable_rect(button.get_window().current_screen).size.y
	popup.max_size = Vector2i(roundi(button.size.x * screen_scale.x), max_height)
	var font: Font = popup.get_theme_font(&"font")
	var font_size: int = popup.get_theme_font_size(&"font_size")
	var content_height: int = ceili(font.get_height(font_size))
	content_height = maxi(content_height, popup.get_theme_icon(&"radio_checked").get_height())
	content_height = maxi(content_height, popup.get_theme_icon(&"checked").get_height())
	popup.add_theme_constant_override(&"v_separation", maxi(0, roundi(button.size.y) - content_height))
