@tool
extends Theme
const Config = preload("res://core/ui/source/ui/theme/ui_config.gd")
const SwitchGraphics = preload("res://core/ui/source/ui/theme/switch_graphics.gd")
## Shared defaults only: Godot's normal per-node Theme Overrides win.
## Generated from tokens, never traverses controls or removes local overrides.
const CARD = preload("res://core/ui/source/ui/theme/card.tres")
const PRIMARY = preload("res://core/ui/source/ui/theme/primary.tres")
const MUTED = preload("res://core/ui/source/ui/theme/muted.tres")
const HOVER = preload("res://core/ui/source/ui/theme/hover.tres")
const FOCUS = preload("res://core/ui/source/ui/theme/focus.tres")
const TAB_ACTIVE = preload("res://core/ui/source/ui/theme/tab_active.tres")
const TAB_INACTIVE = preload("res://core/ui/source/ui/theme/tab_inactive.tres")
const TYPE_SIZES = {
	"Micro": "micro_size", "Debug": "debug_size", "Meta": "meta_size",
	"Detail": "detail_size", "Note": "note_size", "Secondary": "secondary_size",
	"Body": "body_size", "Player": "player_size", "Setting": "setting_size",
	"Action": "action_size", "Section": "section_size", "CompactTitle": "compact_title_size", "Subheading": "subheading_size", "DialogTitle": "dialog_title_size",
	"Display": "display_size", "PageTitle": "page_title_size", "Brand": "brand_size"
}
const VARIANTS = [
	["PartyButtonAction", "Button", "Action", ""],
	["PartyButtonActionPrimary", "Button", "Action", "Primary"],
	["PartyButtonSetting", "Button", "Setting", ""],
	["PartyButtonSettingPrimary", "Button", "Setting", "Primary"],
	["PartyCheckButtonBody", "CheckButton", "Body", ""],
	["PartyLabelAction", "Label", "Action", ""],
	["PartyLabelBody", "Label", "Body", ""],
	["PartyLabelBodyDisplayCaption", "Label", "Body", "DisplayCaption"],
	["PartyLabelBodyOnPrimary", "Label", "Body", "OnPrimary"],
	["PartyLabelBrand", "Label", "Brand", ""],
	["PartyLabelCompactTitle", "Label", "CompactTitle", ""],
	["PartyLabelDebug", "Label", "Debug", ""],
	["PartyLabelDetail", "Label", "Detail", ""],
	["PartyLabelDialogTitle", "Label", "DialogTitle", ""],
	["PartyLabelDisplay", "Label", "Display", ""],
	["PartyLabelDisplayDisplayText", "Label", "Display", "DisplayText"],
	["PartyLabelMeta", "Label", "Meta", ""],
	["PartyLabelMicro", "Label", "Micro", ""],
	["PartyLabelNote", "Label", "Note", ""],
	["PartyLabelNoteError", "Label", "Note", "Error"],
	["PartyLabelPageTitle", "Label", "PageTitle", ""],
	["PartyLabelPlayer", "Label", "Player", ""],
	["PartyLabelSecondary", "Label", "Secondary", ""],
	["PartyLabelSection", "Label", "Section", ""],
	["PartyLabelSetting", "Label", "Setting", ""],
	["PartyLabelSettingOnPrimary", "Label", "Setting", "OnPrimary"],
	["PartyLabelSubheading", "Label", "Subheading", ""],
	["PartyLineEditBody", "LineEdit", "Body", ""],
	["PartyOptionButtonSetting", "OptionButton", "Setting", ""],
	["PartySpinBoxSetting", "SpinBox", "Setting", ""],
	["PartyTabContainerAction", "TabContainer", "Action", ""],
]
@export var configuration: Config = preload("res://core/ui/source/ui/theme/ui_config.tres"):
	set(value):
		if configuration != null and configuration.changed.is_connected(rebuild): configuration.changed.disconnect(rebuild)
		configuration = value
		_connect_config()
		rebuild()
var _flat_styles: Dictionary = {}
var _icons: Dictionary = {}
var _icon_colors: Dictionary = {}
var _dirty := false

func _init() -> void:
	_connect_config()
	rebuild()

func _connect_config() -> void:
	if configuration != null and not configuration.changed.is_connected(rebuild): configuration.changed.connect(rebuild)

func _flat(key: String, color: Color, minimum: Vector2 = Vector2.ZERO) -> StyleBoxFlat:
	if not _flat_styles.has(key): _flat_styles[key] = StyleBoxFlat.new()
	var style: StyleBoxFlat = _flat_styles[key]
	if style.bg_color != color: style.bg_color = color
	if style.content_margin_left != minimum.x / 2.0: style.content_margin_left = minimum.x / 2.0
	if style.content_margin_right != minimum.x / 2.0: style.content_margin_right = minimum.x / 2.0
	if style.content_margin_top != minimum.y / 2.0: style.content_margin_top = minimum.y / 2.0
	if style.content_margin_bottom != minimum.y / 2.0: style.content_margin_bottom = minimum.y / 2.0
	return style

## Subtle filled fields stay distinguishable from the paper panels in sage mode.
func _input_surface() -> StyleBoxFlat:
	if configuration.visual_style != "sage":
		return CARD
	var field: StyleBoxFlat = _flat("sage_input", configuration.muted_surface, Vector2(24, 12))
	field.set_corner_radius_all(10)
	return field

func _icon(key: String, color: Color) -> GradientTexture2D:
	if not _icons.has(key):
		var texture := GradientTexture2D.new()
		texture.width = 16
		texture.height = 16
		texture.gradient = Gradient.new()
		_icons[key] = texture
	var icon: GradientTexture2D = _icons[key]
	if icon.gradient.colors != PackedColorArray([color, color]): icon.gradient.colors = PackedColorArray([color, color])
	return icon

func _tinted_builtin_icon(item: String, type: String, color: Color) -> Texture2D:
	# PopupMenu has no radio/check icon tint theme item. Preserve the engine's
	# symbol geometry and shading as alpha, while supplying the semantic RGBA.
	var key := type + "/" + item
	if _icons.has(key) and _icon_colors.get(key) == color: return _icons[key]
	var source := ThemeDB.get_default_theme().get_icon(item, type)
	if source == null: return null
	var source_pixels := source.get_image()
	if source_pixels == null or source_pixels.is_empty(): return source
	var pixels: Image = source_pixels.duplicate()
	pixels.convert(Image.FORMAT_RGBA8)
	var peak_luminance := 0.0
	for y in pixels.get_height():
		for x in pixels.get_width():
			var mask := pixels.get_pixel(x, y)
			if mask.a > 0.01: peak_luminance = maxf(peak_luminance, mask.get_luminance())
	# Unchecked icons are dark gray already: using raw luminance would apply
	# their darkness a second time as transparency and make them disappear.
	for y in pixels.get_height():
		for x in pixels.get_width():
			var mask := pixels.get_pixel(x, y)
			pixels.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * mask.a * (clampf(mask.get_luminance() / peak_luminance, 0.0, 1.0) if peak_luminance > 0.0 else 1.0)))
	_icons[key] = ImageTexture.create_from_image(pixels)
	_icon_colors[key] = color
	return _icons[key]

func _switch_icon(item: String) -> Texture2D:
	var c := configuration
	var palette := [c.toggle_off, c.toggle_on, c.toggle_thumb, c.toggle_border, c.disabled_opacity]
	var key := "CheckButton/" + item
	if _icons.has(key) and _icon_colors.get(key) == palette: return _icons[key]
	var active := item.begins_with("checked")
	var opacity: float = c.disabled_opacity if item.contains("disabled") else 1.0
	_icons[key] = SwitchGraphics.texture(1.0 if active else 0.0, SwitchGraphics.DESIGN_SIZE, c.toggle_off, c.toggle_on, c.toggle_thumb, c.toggle_border, opacity, item.ends_with("mirrored"))
	_icon_colors[key] = palette
	return _icons[key]

func rebuild() -> void:
	if configuration == null: return
	var c := configuration
	# Batch notifications so live editing causes one coherent theme refresh.
	set_block_signals(true)
	_dirty = false
	if default_font != c.font:
		default_font = c.font
		_dirty = true
	if default_font_size != c.body_size:
		default_font_size = c.body_size
		_dirty = true
	for type in ["Button", "OptionButton", "CheckButton", "CheckBox", "MenuButton"]:
		# A checked native toggle is logically pressed even after the pointer
		# leaves. Its indicator owns the value; the row still follows hover.
		var is_check: bool = type in ["CheckButton", "CheckBox"]
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			var resting: bool = state == "normal" or (is_check and state == "pressed")
			_put_stylebox(state, type, FOCUS if state == "focus" else (MUTED if state == "disabled" else ((_input_surface() if type == "OptionButton" else CARD) if resting else HOVER)))
		for item in ["font_color", "font_focus_color"]: _put_color(item, type, c.text)
		for item in ["font_hover_color", "font_hover_pressed_color"]: _put_color(item, type, c.text_hover)
		_put_color("font_pressed_color", type, c.text if is_check else c.text_hover)
		_put_color("font_disabled_color", type, c.text_disabled)
		for item in ["icon_normal_color", "icon_focus_color"]: _put_color(item, type, c.text)
		for item in ["icon_hover_color", "icon_hover_pressed_color"]: _put_color(item, type, c.text_hover)
		_put_color("icon_pressed_color", type, c.text if is_check else c.text_hover)
		_put_color("icon_disabled_color", type, c.text_disabled)
	_put_constant("modulate_arrow", "OptionButton", 1)
	# Indicator textures contain full track/thumb RGBA. Keep native modulation
	# neutral so a white thumb stays white through every interaction state.
	_put_color("button_checked_color", "CheckButton", Color.WHITE)
	_put_color("button_unchecked_color", "CheckButton", Color.WHITE)
	for item in ["checked", "unchecked", "checked_disabled", "unchecked_disabled", "checked_mirrored", "unchecked_mirrored", "checked_disabled_mirrored", "unchecked_disabled_mirrored"]:
		_put_icon(item, "CheckButton", _switch_icon(item))
	for direction in ["up", "down"]:
		_put_color(direction + "_icon_modulate", "SpinBox", c.text)
		_put_color(direction + "_hover_icon_modulate", "SpinBox", c.text_hover)
		_put_color(direction + "_pressed_icon_modulate", "SpinBox", c.text_hover)
		_put_color(direction + "_disabled_icon_modulate", "SpinBox", c.text_disabled)
		_put_stylebox(direction + "_background", "SpinBox", _flat("spin_normal", c.surface))
		_put_stylebox(direction + "_background_hovered", "SpinBox", _flat("spin_hover", c.hover_surface))
		_put_stylebox(direction + "_background_pressed", "SpinBox", _flat("spin_pressed", c.hover_surface))
		_put_stylebox(direction + "_background_disabled", "SpinBox", _flat("spin_disabled", c.muted_surface))
	for type in ["Label", "RichTextLabel", "LineEdit", "TextEdit", "PopupMenu", "TooltipLabel"]:
		_put_color("font_color", type, c.text)
		_put_color("default_color", type, c.text)
		_put_color("font_disabled_color", type, c.text_disabled)
		_put_color("font_uneditable_color", type, c.text_disabled)
		_put_color("font_placeholder_color", type, c.text_disabled)
		_put_color("font_hover_color", type, c.text_hover)
		_put_color("font_selected_color", type, c.text)
		_put_color("selection_color", type, c.selection)
		_put_color("caret_color", type, c.text)
	for type in ["LineEdit", "TextEdit"]:
		_put_stylebox("normal", type, _input_surface())
		_put_stylebox("read_only", type, MUTED)
		_put_stylebox("focus", type, FOCUS)
	_put_constant("minimum_character_width", "LineEdit", 6)
	_put_stylebox("panel", "Panel", CARD)
	_put_stylebox("panel", "PanelContainer", CARD)
	for item in ["checked", "unchecked", "radio_checked", "radio_unchecked", "checked_disabled", "unchecked_disabled", "radio_checked_disabled", "radio_unchecked_disabled", "submenu", "submenu_mirrored"]:
		_put_icon(item, "PopupMenu", _tinted_builtin_icon(item, "PopupMenu", c.text_disabled if item.ends_with("_disabled") else c.text))
	_put_color("font_accelerator_color", "PopupMenu", c.text_disabled)
	_put_color("font_separator_color", "PopupMenu", c.text)
	_put_stylebox("panel", "PopupMenu", CARD)
	_put_stylebox("hover", "PopupMenu", HOVER)
	_put_stylebox("separator", "PopupMenu", _flat("popup_divider", c.divider, Vector2(0, 1)))
	_put_constant("v_separation", "PopupMenu", 18)
	_put_stylebox("panel", "TooltipPanel", CARD)
	for type in ["TabContainer", "TabBar"]:
		_put_font_size("font_size", type, c.action_size)
		_put_color("font_selected_color", type, c.text_on_primary)
		_put_color("font_unselected_color", type, c.text)
		_put_color("font_hovered_color", type, c.text_hover)
		_put_color("font_disabled_color", type, c.text_disabled)
		_put_stylebox("tab_selected", type, TAB_ACTIVE)
		_put_stylebox("tab_unselected", type, TAB_INACTIVE)
		_put_stylebox("tab_hovered", type, TAB_INACTIVE)
		_put_stylebox("tab_disabled", type, TAB_INACTIVE)
		_put_stylebox("tab_focus", type, FOCUS)
	_put_stylebox("panel", "TabContainer", CARD)
	_put_constant("side_margin", "TabContainer", 20)
	for type in ["HSlider", "VSlider"]:
		var minimum := Vector2(0, 6) if type == "HSlider" else Vector2(6, 0)
		_put_stylebox("slider", type, _flat("slider_" + type, c.muted_surface, minimum))
		_put_stylebox("grabber_area", type, _flat("slider_fill_" + type, c.primary, minimum))
		_put_stylebox("grabber_area_highlight", type, _flat("slider_active_" + type, c.focus, minimum))
		_put_icon("grabber", type, _icon("grabber", c.primary))
		_put_icon("grabber_highlight", type, _icon("grabber_hover", c.focus))
		_put_icon("grabber_disabled", type, _icon("grabber_disabled", c.text_disabled))
	for type in ["HScrollBar", "VScrollBar"]:
		var minimum := Vector2(0, 12) if type == "HScrollBar" else Vector2(12, 0)
		_put_stylebox("scroll", type, _flat("scroll_" + type, c.muted_surface, minimum))
		_put_stylebox("scroll_focus", type, FOCUS)
		_put_stylebox("grabber", type, _flat("scroll_grabber_" + type, c.border, minimum))
		_put_stylebox("grabber_highlight", type, _flat("scroll_hover_" + type, c.focus, minimum))
		_put_stylebox("grabber_pressed", type, _flat("scroll_pressed_" + type, c.primary, minimum))
	for type in ["HSeparator", "VSeparator"]: _put_stylebox("separator", type, _flat("separator_" + type, c.divider, Vector2(1, 1)))
	# Named sizes preserve the authored hierarchy while following a single font.
	for spec in VARIANTS:
		var variant: String = spec[0]
		var type: String = spec[1]
		var role: String = spec[2]
		var suffix: String = spec[3]
		_put_type_variation(variant, type)
		_put_font_size("font_size", variant, c.get(TYPE_SIZES[role]))
		if suffix in ["OnPrimary", "Error", "DisplayText", "DisplayCaption", "Primary"]:
			var color: Color = c.text_on_primary if suffix in ["OnPrimary", "Primary"] else (c.error if suffix == "Error" else (c.display_text if suffix == "DisplayText" else c.display_caption))
			_put_color("font_color", variant, color)
			_put_color("font_focus_color", variant, color)
		if suffix == "Primary": _put_stylebox("normal", variant, PRIMARY)
	set_block_signals(false)
	if _dirty: emit_changed()

func _put_color(item: String, type: String, value: Color) -> void:
	if not has_color(item, type) or get_color(item, type) != value:
		set_color(item, type, value)
		_dirty = true

func _put_font_size(item: String, type: String, value: int) -> void:
	if not has_font_size(item, type) or get_font_size(item, type) != value:
		set_font_size(item, type, value)
		_dirty = true

func _put_type_variation(type: String, base: String) -> void:
	if get_type_variation_base(type) != base:
		set_type_variation(type, base)
		_dirty = true

func _put_stylebox(item: String, type: String, value: StyleBox) -> void:
	if not has_stylebox(item, type) or get_stylebox(item, type) != value:
		set_stylebox(item, type, value)
		_dirty = true

func _put_icon(item: String, type: String, value: Texture2D) -> void:
	if not has_icon(item, type) or get_icon(item, type) != value:
		set_icon(item, type, value)
		_dirty = true

func _put_constant(item: String, type: String, value: int) -> void:
	if not has_constant(item, type) or get_constant(item, type) != value:
		set_constant(item, type, value)
		_dirty = true

func _validate_property(property: Dictionary) -> void:
	# Save only the source configuration, never an editor-generated snapshot.
	var name: String = property.name
	if name.contains("/") or name in ["default_font", "default_font_size", "default_base_scale"]:
		property.usage &= ~PROPERTY_USAGE_STORAGE
