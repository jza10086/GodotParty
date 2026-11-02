extends RefCounted
## Original pastel palette inspired by the supplied lavender / cream / blue reference.
## No downloaded assets; these colors affect framework UI, never game-owned artwork.
const COLORS: Dictionary[String, Color] = {
	"text": Color("#45465e"), "text_hover": Color("#303247"),
	"text_disabled": Color("#77768b"), "text_on_primary": Color("#fff9ef"),
	"error": Color("#a34961"), "success": Color("#48766a"),
	"demo_inactive": Color("#77768b"), "info": Color("#62658c"),
	"surface": Color("#fff9ef"), "muted_surface": Color("#e5e1ec"),
	"primary": Color("#777795"), "hover_surface": Color("#d5e3f3"),
	"border": Color("#b7b2ca"), "hover_border": Color("#b7cbe4"),
	"focus": Color("#859fc4"), "divider": Color("#d7d2e1"),
	"selection": Color("#b9cce3"), "toggle_border": Color.TRANSPARENT,
	"toggle_active_text": Color("#45465e"), "toggle_off": Color("#c8c3d5"),
	"toggle_on": Color("#8da9c8"), "toggle_thumb": Color("#fff9ef"),
	"page_background": Color("#eeeaf2"), "menu_backdrop": Color("#e5e0ee"),
	"rooms_backdrop": Color("#eeeaf2"), "lobby_backdrop": Color("#eeeaf2"),
	"status_backdrop": Color("#e5e0ee"), "modal_overlay": Color("#34334799"),
	"capture_overlay": Color("#34334766"), "ruler": Color("#777795"),
	"display_background": Color("#eeeaf2"), "display_far_left": Color("#ded8e9"),
	"display_far_center": Color("#e8e2ec"), "display_far_right": Color("#d1dced"),
	"display_near_left": Color("#c6c0d6"), "display_near_right": Color("#b5c8e1"),
	"display_ground": Color("#ddd6e5"), "display_horizon": Color("#ddd6e5"),
	"display_text": Color("#45465e"), "display_caption": Color("#77768b")
}
