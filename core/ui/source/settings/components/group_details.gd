@tool
extends MarginContainer
## The scene owns gutter, stroke styling and branch template; actual arranged
## controls determine connections, so edited scenes and dynamic schemas agree.
var header_control: Button

func get_visible_rows() -> Array[Control]:
	var rows: Array[Control] = []
	for child in $Rows.get_children():
		if child is Control and child.visible and not child.has_method("divider_boundary_y") and not child.has_node("Stroke"):
			rows.append(child)
	return rows

# Godot Button draws using resolved margins (including StyleBox borders),
# and normally reserves the largest margins across all interaction states.
func _header_icon_center(header: Button, icon_size: Vector2) -> Vector2:
	var style_names: Array[String] = ["normal", "hover", "pressed", "hover_pressed", "disabled"]
	if header.get_theme_constant("align_to_largest_stylebox") == 0:
		var current := "normal"
		match header.get_draw_mode():
			BaseButton.DRAW_HOVER: current = "hover"
			BaseButton.DRAW_PRESSED: current = "pressed"
			BaseButton.DRAW_HOVER_PRESSED: current = "hover_pressed" if header.has_theme_stylebox("hover_pressed") else "pressed"
			BaseButton.DRAW_DISABLED: current = "disabled"
		style_names = [current]
	var left := 0.0
	var top := 0.0
	var bottom := 0.0
	for style_name in style_names:
		if not header.has_theme_stylebox(style_name): continue
		var style := header.get_theme_stylebox(style_name)
		left = maxf(left, style.get_margin(SIDE_LEFT))
		top = maxf(top, style.get_margin(SIDE_TOP))
		bottom = maxf(bottom, style.get_margin(SIDE_BOTTOM))
	return Vector2(left + icon_size.x / 2.0, (header.size.y + top - bottom) / 2.0)

func _process(_delta: float) -> void:
	var line: Line2D = $HierarchyLine
	var rows := get_visible_rows()
	line.visible = not rows.is_empty()
	$Branches.visible = line.visible
	$HeaderConnection.visible = line.visible
	if not is_visible_in_tree(): return
	for branch in $Branches.get_children():
		branch.visible = false
	if not line.visible or line.get_point_count() != 2: return
	var start := line.get_point_position(0)
	# Align the entire spine with the actual arrow center. A hand-drawn
	# annotation is not a diagonal lead-in; both segments must be collinear.
	var header := header_control
	if not is_instance_valid(header):
		var previous := get_parent().get_child(get_index() - 1) if get_index() > 0 else null
		header = previous as Button
		if header == null and previous != null: header = previous.get_node_or_null("Function") as Button
	if is_instance_valid(header):
		var icon_size := header.icon.get_size() if header.icon != null else Vector2.ZERO
		var icon_center := _header_icon_center(header, icon_size)
		start = line.to_local(header.get_global_transform() * Vector2(icon_center.x, icon_center.y + icon_size.y))
		var lead: Line2D = $HeaderConnection
		lead.points = PackedVector2Array([lead.to_local(header.get_global_transform() * icon_center), lead.to_local(line.to_global(start))])
	else:
		$HeaderConnection.visible = false
	var endpoint := line.to_local(Vector2(global_position.x, divider_boundary_y()))
	line.set_point_position(0, start)
	line.set_point_position(1, Vector2(start.x, endpoint.y))
	for row in rows:
		var branch := $Branches.get_node_or_null(NodePath(row.name)) as Line2D
		if branch == null:
			branch = $BranchTemplate.duplicate() as Line2D
			branch.name = row.name
			$Branches.add_child(branch)
		branch.width = $BranchTemplate.width
		branch.default_color = $BranchTemplate.default_color
		branch.visible = true
		var destination := row.get_global_transform() * Vector2(0, row.size.y / 2.0)
		var end := branch.to_local(destination)
		var spine_x := branch.to_local(line.to_global(start)).x
		branch.points = PackedVector2Array([Vector2(spine_x, end.y), end])

## The closing separator starts at the final expanded child's spine, without
## drawing back into the preceding outer gutter (the erased red segment).
func closing_spine_global() -> Vector2:
	for index in range($Rows.get_child_count() - 1, -1, -1):
		var child := $Rows.get_child(index) as Control
		if child == null or not child.visible: continue
		if child.has_method("closing_spine_global") and not child.get_visible_rows().is_empty():
			return child.closing_spine_global()
		break
	var line: Line2D = $HierarchyLine
	return line.to_global(line.get_point_position(1))

func divider_boundary_y() -> float:
	var container := get_parent()
	if container is VBoxContainer:
		for index in range(get_index() + 1, container.get_child_count()):
			var sibling := container.get_child(index) as Control
			if sibling == null or not sibling.visible: continue
			if sibling is ColorRect and sibling.has_node("Stroke"):
				return (sibling.get_global_transform() * Vector2(0, sibling.size.y / 2.0)).y
			return (get_global_transform() * Vector2(0, size.y)).y
		var ancestor := container.get_parent()
		if container.name == "Rows" and ancestor != null and ancestor.has_method("divider_boundary_y"):
			return ancestor.divider_boundary_y()
	return (get_global_transform() * Vector2(0, size.y)).y
