@tool
extends "res://core/ui/source/ui/theme/theme_color_rect.gd"
## Keep the original ColorRect's layout/API, but draw through an editable child
## so an expanded group's closing edge can omit the unwanted outer segment.
func _process(_delta: float) -> void:
	if not is_visible_in_tree(): return
	var stroke: ColorRect = $Stroke
	var rows := get_parent()
	var details := rows.get_parent() if rows != null else null
	var spine := details.get_node_or_null("HierarchyLine") as Line2D if details != null else null
	var start_x := 0.0
	if spine != null and rows.name == "Rows" and spine.get_point_count() >= 2:
		start_x = (get_global_transform().affine_inverse() * spine.to_global(spine.get_point_position(0))).x
	if rows != null:
		for index in range(get_index() - 1, -1, -1):
			var sibling := rows.get_child(index) as Control
			if sibling == null or not sibling.visible: continue
			if sibling.has_method("closing_spine_global") and not sibling.get_visible_rows().is_empty():
				start_x = (get_global_transform().affine_inverse() * sibling.closing_spine_global()).x
			break
	start_x = minf(start_x, size.x)
	stroke.position = Vector2(start_x, 0)
	stroke.size = Vector2(size.x - start_x, size.y)
	stroke.color = color
