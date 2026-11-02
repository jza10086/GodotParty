## 从场景地格推导单行路网。只返回数据和错误，不修改作者场景。
extends RefCounted
const DIRECTIONS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

const JUNCTION_MODES: Array[String] = ["split", "merge", "cross_merge", "cross_split", "cross_balanced"]

## 返回各端口的局部方向及是否为出口，供路线和箭头共同使用。
static func junction_ports(record: Dictionary, neighbors: Array = []) -> Dictionary:
	var turn: int = int(record.get("turn", 0))
	var primary: Vector2i = direction(turn)
	var mode: String = record.get("junction_mode", "split")
	var ports: Array[Vector2i] = []
	if mode.begins_with("cross_"):
		ports.assign(DIRECTIONS)
	elif neighbors.size() == 3:
		for point: Vector2i in neighbors:
			ports.append(point - Vector2i(record.position))
	else:
		ports = [primary, direction(turn + 1), direction(turn + 3)]
	var result: Dictionary = {}
	for d: Vector2i in ports:
		match mode:
			"merge", "cross_merge":
				result[d] = d == primary
			"cross_balanced":
				var second: Vector2i = direction(turn + (2 if record.get("exit_layout", "adjacent") == "opposite" else 1))
				result[d] = d == primary or d == second
			_:
				result[d] = d != primary
	return result

static func direction(turn: int) -> Vector2i:
	return DIRECTIONS[posmod(turn, 4)]

static func footprint(record: Dictionary) -> Array[Vector2i]:
	var p: Vector2i = record.position
	var points: Array[Vector2i] = [p]
	if record.kind == "decor":
		points.clear()
		for x: int in range(clampi(int(record.get("width", 1)), 1, 32)):
			for z: int in range(clampi(int(record.get("length", 1)), 1, 32)):
				points.append(p + direction(int(record.get("turn", 0))) * x + direction(int(record.get("turn", 0)) + 1) * z)
	if record.kind in ["property", "shop"]:
		points.append(p + direction(int(record.get("turn", 0))))
	return points

static func solve(records: Array[Dictionary]) -> Dictionary:
	var errors: Array[String] = []
	var roads: Dictionary = {}
	var occupied: Dictionary = {}
	var starts: Array[Vector2i] = []
	var ids: Dictionary = {}
	for item: Dictionary in records:
		var p: Vector2i = item.position
		var id: String = str(item.id)
		if ids.has(id):
			errors.append("重复 ID：" + id)
		ids[id] = true
		for point: Vector2i in footprint(item):
			if occupied.has(point):
				errors.append("占地重叠：" + str(point))
			occupied[point] = id
		if item.kind == "decor":
			continue
		roads[p] = item
		if item.kind == "start":
			starts.append(p)
	if starts.size() != 1:
		errors.append("地图必须有且只有一个起点")
	var adjacent: Dictionary = {}
	var outgoing: Dictionary = {}
	for p: Vector2i in roads:
		outgoing[p] = []
	for p: Vector2i in roads:
		var neighbors: Array[Vector2i] = []
		for d: Vector2i in DIRECTIONS:
			var q: Vector2i = p + d
			if roads.has(q) and roads[q].kind != "start":
				neighbors.append(q)
		adjacent[p] = neighbors
		if roads[p].kind == "start":
			var target: Vector2i = p + direction(int(roads[p].get("turn", 0)))
			if target not in neighbors:
				errors.append("起点右侧缺少道路：" + str(p))
			else:
				outgoing[p].append(target)
			if neighbors.size() != 1:
				errors.append("起点只能连接一个道路格：" + str(p))
		elif roads[p].kind == "junction":
			var mode: String = roads[p].get("junction_mode", "split")
			if mode not in JUNCTION_MODES:
				errors.append("未知路口类型：" + str(p))
			var count: int = 4 if mode.begins_with("cross_") else 3
			if neighbors.size() != count:
				errors.append("路口需要 %d 条相邻道路：%s" % [count, p])
			var ports: Dictionary = junction_ports(roads[p], neighbors)
			var primary: Vector2i = p + direction(int(roads[p].get("turn", 0)))
			if primary not in neighbors:
				errors.append("路口指定方向没有道路：" + str(p))
			for q: Vector2i in neighbors:
				var is_exit: bool = ports.get(q - p, false)
				_orient(p if is_exit else q, q if is_exit else p, outgoing, errors)
		elif neighbors.size() != 2:
			errors.append("普通道路需要两个相邻道路格：" + str(p))
	# All nodes must exist before junction constraints are applied.
	for p: Vector2i in roads:
		if not outgoing.has(p):
			outgoing[p] = []
	_propagate(roads, adjacent, outgoing, errors)
	# Without a junction constraint, the starting intersection chooses the right turn.
	if starts.size() == 1 and not outgoing[starts[0]].is_empty():
		var start: Vector2i = starts[0]
		var entry: Vector2i = outgoing[start][0]
		if roads[entry].kind != "junction" and outgoing[entry].is_empty():
			var heading: Vector2i = entry - start
			var choices: Array[Vector2i] = [Vector2i(-heading.y, heading.x), heading, Vector2i(heading.y, -heading.x)]
			for d: Vector2i in choices:
				if entry + d in adjacent[entry]:
					_orient(entry, entry + d, outgoing, errors)
					break
			_propagate(roads, adjacent, outgoing, errors)
	var tiles: Array[Dictionary] = []
	for p: Vector2i in roads:
		var item: Dictionary = roads[p]
		var exits: Array = outgoing[p]
		var wanted: int = 1
		var ports: Dictionary = junction_ports(item, adjacent[p]) if item.kind == "junction" else {}
		if item.kind == "junction":
			wanted = ports.values().count(true)
		if exits.size() != wanted:
			errors.append("方向未确定或出口数量冲突：" + str(p))
		var next: Array[String] = []
		for q: Vector2i in exits:
			next.append(str(roads[q].id))
		tiles.append({"id": str(item.id), "kind": item.kind, "x": p.x, "z": p.y, "next": next, "ports": ports,
			"property_cell": str(item.node_name) + "/Visual/Side" if item.kind == "property" else "",
			"shop_cell": str(item.node_name) + "/Visual/Side" if item.kind == "shop" else ""})
	if starts.size() == 1:
		var reached: Dictionary = {}
		var queue: Array[Vector2i] = [starts[0]]
		while not queue.is_empty():
			var p: Vector2i = queue.pop_front()
			if reached.has(p):
				continue
			reached[p] = true
			for q: Vector2i in outgoing[p]:
				queue.append(q)
		if reached.size() != roads.size():
			errors.append("存在无法从起点到达的道路")
	return {"ok": errors.is_empty(), "errors": errors, "tiles": tiles, "adjacent": adjacent, "outgoing": outgoing}

static func _orient(a: Vector2i, b: Vector2i, outgoing: Dictionary, errors: Array[String]) -> void:
	if not outgoing.has(a):
		outgoing[a] = []
	if not outgoing.has(b):
		outgoing[b] = []
	if a in outgoing[b]:
		var message: String = "双向违规：" + str(a) + " ↔ " + str(b)
		if message not in errors:
			errors.append(message)
	if b not in outgoing[a]:
		outgoing[a].append(b)

static func _propagate(roads: Dictionary, adjacent: Dictionary, outgoing: Dictionary, errors: Array[String]) -> void:
	for pass_index: int in range(roads.size() + 1):
		var changed: bool = false
		for p: Vector2i in roads:
			if roads[p].kind in ["start", "junction"] or adjacent[p].size() != 2:
				continue
			var a: Vector2i = adjacent[p][0]
			var b: Vector2i = adjacent[p][1]
			if p in outgoing[a] or b in outgoing[p]:
				if b not in outgoing[p] or p not in outgoing[a]:
					changed = true
				_orient(a, p, outgoing, errors)
				_orient(p, b, outgoing, errors)
			if p in outgoing[b] or a in outgoing[p]:
				if a not in outgoing[p] or p not in outgoing[b]:
					changed = true
				_orient(b, p, outgoing, errors)
				_orient(p, a, outgoing, errors)
		if not changed:
			break
