## GodotPartyDefaultProtocol 1.0. Pure contracts, never a wallet or item-effect runner.
## Hosts validate ownership/consent against main-game state before authorizing a request.
extends RefCounted
const ID: String = "godot_party_default_protocol"
## Eight room identities: red, green, blue, bright cyan, purple, yellow, black and white.
const COLORS: Array[String] = ["#e53935", "#43b047", "#2962ff", "#00d9e8", "#9c42d4", "#ffda24", "#252832", "#f5f5f5"]
const COLOR_NAMES: Array[String] = ["红 R", "绿 G", "蓝 B", "亮青 C", "紫 M", "黄 Y", "黑 B", "白 W"]
const MAX_AMOUNT: int = 1000000000000
const STATUSES: Array[String] = ["completed", "withdrawn", "disqualified", "unranked"]

func _failure(code: String, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}

func _text(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length() <= 256

func _amount(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= 0 and value <= MAX_AMOUNT

func _keys(value: Dictionary, required: Array, optional: Array = []) -> bool:
	for key: Variant in required:
		if not value.has(key):
			return false
	for key: Variant in value:
		if key not in required and key not in optional:
			return false
	return true

## Business extensions use JSON-like values plus bytes; no executable engine objects.
func _data(value: Variant, depth: int = 0) -> bool:
	if depth > 24:
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING, TYPE_PACKED_BYTE_ARRAY:
			return true
		TYPE_FLOAT:
			return is_finite(value)
		TYPE_ARRAY:
			for entry: Variant in value:
				if not _data(entry, depth + 1):
					return false
			return true
		TYPE_DICTIONARY:
			for key: Variant in value:
				if not (key is String or key is StringName) or not _data(value[key], depth + 1):
					return false
			return true
	return false

func _reference(value: Variant) -> bool:
	return value is Dictionary and _keys(value, ["package_id", "resource_key"]) and _text(value.package_id) and _text(value.resource_key)

## Profile values are independent snapshots; the color is opaque sRGB RRGGBB.
func default_player_config() -> Dictionary:
	return {"color": COLORS[2], "avatar_2d": {"package_id": "godot_party_default_avatars_2d", "resource_key": "avatar_silver_lavender"}, "character_3d": {"package_id": "godot_party_default_avatars", "resource_key": "character_3d"}}

func validate_player_config(value: Dictionary) -> Dictionary:
	if not _keys(value, ["color", "avatar_2d", "character_3d"]) or not value.color is String:
		return _failure("PROFILE_INVALID", "需要玩家颜色、2D 头像及 3D 形象")
	if value.color not in COLORS:
		return _failure("COLOR_INVALID", "请从协议八种玩家颜色中选择")
	if not _reference(value.avatar_2d) or not _reference(value.character_3d):
		return _failure("APPEARANCE_INVALID", "形象必须是公开资源引用")
	return {"ok": true}

## Host-only room resolution. Does not change the preferred profile saved on this machine.
## Existing assignments win; the requesting player randomly takes a remaining color on conflict.
func resolve_player_config(value: Dictionary, player_id: String, players: Array) -> Dictionary:
	var report: Dictionary = validate_player_config(value)
	if not report.ok:
		return report
	var available: Array[String] = COLORS.duplicate()
	for player: Dictionary in players:
		if player.get("player_id") != player_id:
			available.erase(str(player.get("profile", {}).get("color", "")))
	if available.is_empty():
		return _failure("COLORS_FULL", "房间没有剩余玩家颜色")
	var result: Dictionary = value.duplicate(true)
	var message: String = ""
	if result.color not in available:
		result.color = available.pick_random()
		message = "所选颜色已被占用，本房间已分配：" + COLOR_NAMES[COLORS.find(result.color)]
	return {"ok": true, "value": result, "message": message}

## An explicit host assignment swaps an occupied color with the target's current color.
## Returns complete room-only profiles; never changes names, IDs or saved personal preferences.
func assign_player_config(player_id: String, assignment: Dictionary, players: Array) -> Dictionary:
	if not _keys(assignment, ["color"]) or assignment.color not in COLORS:
		return _failure("COLOR_INVALID", "请选择协议玩家颜色")
	var target: Dictionary = {}
	for player: Dictionary in players:
		if player.player_id == player_id:
			target = player
	if target.is_empty():
		return _failure("PLAYER_MISSING", "玩家已经离开")
	var values: Dictionary = {}
	var selected: Dictionary = target.profile.duplicate(true)
	selected.color = assignment.color
	values[player_id] = selected
	for player: Dictionary in players:
		if player.player_id != player_id and player.profile.get("color") == assignment.color:
			var swapped: Dictionary = player.profile.duplicate(true)
			swapped.color = target.profile.color
			values[player.player_id] = swapped
	return {"ok": true, "profiles": values, "message": "已分配本房间颜色；目标颜色被占用时已交换"}

func get_appearance(value: Dictionary) -> Dictionary:
	return value.duplicate(true) if validate_player_config(value).ok else {}

## Definition data stays author-owned. These are presentation/identity checks, not effect semantics.
func validate_item_definition(value: Dictionary) -> Dictionary:
	if not _keys(value, ["definition_id", "name", "description", "data"], ["icon"]):
		return _failure("ITEM_DEFINITION", "道具定义字段不完整")
	if not _text(value.definition_id) or not _text(value.name) or not value.description is String or not value.data is Dictionary or not _data(value.data):
		return _failure("ITEM_DEFINITION", "道具定义无效")
	if value.has("icon") and not _reference(value.icon):
		return _failure("ITEM_ICON", "道具图标必须是资源引用")
	return {"ok": true}

func validate_item_instance(value: Dictionary) -> Dictionary:
	if not _keys(value, ["instance_id", "definition_id", "data"]) or not _text(value.instance_id) or not _text(value.definition_id) or not value.data is Dictionary or not _data(value.data):
		return _failure("ITEM_INSTANCE", "道具实例无效")
	return {"ok": true}

## A canonical main-owned inventory snapshot; games may keep other state outside this dictionary.
func validate_resources(value: Dictionary) -> Dictionary:
	if not _keys(value, ["coins", "diamonds", "items"]) or not _amount(value.coins) or not _amount(value.diamonds) or not value.items is Array:
		return _failure("RESOURCES_INVALID", "金币、钻石须为非负整数，道具须为数组")
	var seen: Dictionary = {}
	for item: Variant in value.items:
		if not item is Dictionary or not validate_item_instance(item).ok or seen.has(item.get("instance_id")):
			return _failure("ITEM_DUPLICATE", "道具实例无效或重复")
		seen[item.instance_id] = true
	return {"ok": true}

func _members(players: Array[Dictionary]) -> Dictionary:
	var ids: Dictionary = {}
	for player: Dictionary in players:
		var id: Variant = player.get("player_id")
		if not _text(id) or ids.has(id):
			return {}
		ids[id] = true
	return ids

## standard has no asset effects. resource requires an explicit grant for every participant.
## A grant's coins are cash only; initial betting units add the ordered collateral valuations.
func validate_request(request: Dictionary, players: Array[Dictionary]) -> Dictionary:
	var ids: Dictionary = _members(players)
	if ids.is_empty() or not _data(request) or not _keys(request, ["request_id", "mode"], ["resource_grant", "item_offers", "game_data"]):
		return _failure("REQUEST_INVALID", "请求结构或参与者无效")
	if not _text(request.request_id) or request.mode not in ["standard", "resource"] or not request.get("game_data", {}) is Dictionary:
		return _failure("REQUEST_INVALID", "请求标识或模式无效")
	if request.mode == "standard":
		return {"ok": true} if not request.has("resource_grant") and not request.has("item_offers") else _failure("STANDARD_RESOURCES", "普通局不能操作父游戏资源")
	var grants: Variant = request.get("resource_grant")
	var offers: Variant = request.get("item_offers", {})
	if not grants is Dictionary or not offers is Dictionary or grants.size() != ids.size():
		return _failure("GRANT_REQUIRED", "资源局需要全体参与者的明确额度")
	var items: Dictionary = {}
	for id: Variant in grants:
		var grant: Variant = grants[id]
		if not ids.has(id) or not grant is Dictionary or not _keys(grant, ["coins", "diamonds", "coin_limit", "diamond_limit", "collateral"]):
			return _failure("GRANT_INVALID", "额度身份或字段无效")
		for key: String in ["coins", "diamonds", "coin_limit", "diamond_limit"]:
			if not _amount(grant[key]):
				return _failure("AMOUNT_INVALID", "金额须为有效非负整数")
		if not grant.collateral is Array:
			return _failure("COLLATERAL_INVALID", "抵押清单须为数组")
		var initial: int = int(grant.coins)
		for pledge: Variant in grant.collateral:
			if not pledge is Dictionary or not _keys(pledge, ["instance_id", "definition_id", "coin_value"]) or not _text(pledge.instance_id) or not _text(pledge.definition_id) or not _amount(pledge.coin_value) or pledge.coin_value == 0:
				return _failure("COLLATERAL_INVALID", "抵押实例或估值无效")
			if items.has(pledge.instance_id) or int(pledge.coin_value) > MAX_AMOUNT - initial:
				return _failure("COLLATERAL_DUPLICATE", "抵押重复或额度溢出")
			items[pledge.instance_id] = true
			initial += int(pledge.coin_value)
		if int(grant.coin_limit) < initial or grant.diamond_limit < grant.diamonds:
			return _failure("LIMIT_INVALID", "结算上限不得低于初始额度")
	for id: Variant in offers:
		if not ids.has(id) or not offers[id] is Array:
			return _failure("OFFER_INVALID", "道具授权身份无效")
		for offer: Variant in offers[id]:
			if not offer is Dictionary or not _keys(offer, ["item", "effect_id", "parameters", "consumable"]) or not offer.item is Dictionary or not validate_item_instance(offer.item).ok or not _text(offer.effect_id) or not offer.parameters is Dictionary or not offer.consumable is bool:
				return _failure("OFFER_INVALID", "道具效果授权无效")
			var instance: String = offer.item.instance_id
			if items.has(instance):
				return _failure("ITEM_DUPLICATE", "同一道具不能重复授权或同时使用和抵押")
			items[instance] = true
	return {"ok": true}

## Final budgets are independent of rank. Disconnected participants still need resource results.
func validate_result(result: Dictionary, request: Dictionary, players: Array[Dictionary]) -> Dictionary:
	var checked: Dictionary = validate_request(request, players)
	if not checked.ok:
		return checked
	if not _data(result) or not _keys(result, ["request_id", "reason", "rankings"], ["resource_result", "item_result", "game_data", "columns"]):
		return _failure("RESULT_INVALID", "结果结构无效")
	if result.request_id != request.request_id or result.reason not in ["completed", "cancelled"] or not result.rankings is Array or not result.get("game_data", {}) is Dictionary:
		return _failure("RESULT_INVALID", "请求标识或完成原因不匹配")
	var ids: Dictionary = _members(players)
	var seen: Dictionary = {}
	for row: Variant in result.rankings:
		if not row is Dictionary or not _keys(row, ["player_id", "rank", "status"], ["metrics"]):
			return _failure("RANK_INVALID", "排名字段无效")
		if not ids.has(row.player_id) or seen.has(row.player_id) or not _amount(row.rank) or row.status not in STATUSES or (row.status == "unranked" and row.rank != 0) or not row.get("metrics", {}) is Dictionary:
			return _failure("RANK_INVALID", "排名身份、状态或名次无效")
		for metric: Variant in row.get("metrics", {}).values():
			if not (metric is String or metric is int or metric is float):
				return _failure("METRIC_INVALID", "成绩仅支持数字和文本")
		seen[row.player_id] = true
	var columns: Variant = result.get("columns", [])
	if not columns is Array:
		return _failure("COLUMNS_INVALID", "成绩列须为数组")
	seen.clear()
	for column: Variant in columns:
		if not column is Dictionary or not _keys(column, ["key", "title", "format"]) or not _text(column.key) or not _text(column.title) or column.format not in ["integer", "decimal", "text", "time"] or seen.has(column.key):
			return _failure("COLUMNS_INVALID", "成绩列无效或重复")
		seen[column.key] = true
		for row: Dictionary in result.rankings:
			if row.get("metrics", {}).has(column.key):
				var metric: Variant = row.metrics[column.key]
				if column.format != "text" and not (metric is int or metric is float):
					return _failure("METRIC_INVALID", "数值列不能接收文本")
				if column.format in ["integer", "time"] and (float(metric) != floor(float(metric)) or (column.format == "time" and metric < 0)):
					return _failure("METRIC_INVALID", "整数或时间成绩无效")
	if request.mode == "standard" or result.reason == "cancelled":
		return {"ok": true} if not result.has("resource_result") and not result.has("item_result") else _failure("NO_SETTLEMENT", "普通局或取消结果不能结算资源")
	var outcomes: Variant = result.get("resource_result")
	var consumed: Variant = result.get("item_result", {})
	if not outcomes is Dictionary or outcomes.size() != ids.size() or not consumed is Dictionary:
		return _failure("SETTLEMENT_REQUIRED", "缺少完整参与者结算")
	for id: Variant in outcomes:
		var value: Variant = outcomes[id]
		if not ids.has(id) or not value is Dictionary or not _keys(value, ["coins", "diamonds"]) or not _amount(value.coins) or not _amount(value.diamonds):
			return _failure("SETTLEMENT_INVALID", "结算身份或金额无效")
		if value.coins > request.resource_grant[id].coin_limit or value.diamonds > request.resource_grant[id].diamond_limit:
			return _failure("SETTLEMENT_LIMIT", "结算超出锁定上限")
	seen.clear()
	for id: Variant in consumed:
		if not ids.has(id) or not consumed[id] is Array:
			return _failure("ITEM_RESULT", "消耗道具身份无效")
		var allowed: Dictionary = {}
		for offer: Dictionary in request.get("item_offers", {}).get(id, []):
			if offer.consumable:
				allowed[offer.item.instance_id] = true
		for instance: Variant in consumed[id]:
			if not instance is String or not allowed.has(instance) or seen.has(instance):
				return _failure("ITEM_RESULT", "道具未授权消耗或重复")
			seen[instance] = true
	return {"ok": true}

## Pure settlement proposal for a parent's reducer. It never persists/applies rewards.
## The parent must retain the locked request in its state, recheck ownership and apply once.
func calculate_settlement(result: Dictionary, request: Dictionary, players: Array[Dictionary]) -> Dictionary:
	var checked: Dictionary = validate_result(result, request, players)
	if not checked.ok:
		return checked
	var changes: Dictionary = {}
	if request.mode == "standard" or result.reason == "cancelled":
		return {"ok": true, "request_id": request.request_id, "players": changes}
	for id: String in request.resource_grant:
		var grant: Dictionary = request.resource_grant[id]
		var total: int = int(grant.coins)
		for pledge: Dictionary in grant.collateral:
			total += int(pledge.coin_value)
		var delta: int = int(result.resource_result[id].coins) - total
		var remaining: int = maxi(0, -delta - int(grant.coins))
		var forfeited: Array[String] = []
		for pledge: Dictionary in grant.collateral:
			if remaining <= 0:
				break
			forfeited.append(pledge.instance_id)
			delta += int(pledge.coin_value)
			remaining -= int(pledge.coin_value)
		changes[id] = {"coins_delta": delta, "diamonds_delta": int(result.resource_result[id].diamonds) - int(grant.diamonds), "forfeited_items": forfeited, "consumed_items": result.get("item_result", {}).get(id, []).duplicate()}
	return {"ok": true, "request_id": request.request_id, "players": changes}

## Author order and ties survive; the core's presentation UI performs only display sorting.
func present_result(result: Dictionary, _request: Dictionary) -> Dictionary:
	var rows: Array = []
	var labels: Dictionary = {"completed": "完成", "withdrawn": "退出", "disqualified": "失格", "unranked": "未排名"}
	for row: Dictionary in result.get("rankings", []):
		rows.append({"player_id": row.player_id, "rank": int(row.rank), "status": labels[row.status], "metrics": row.get("metrics", {}).duplicate(true)})
	return {"title": "小游戏结果", "columns": result.get("columns", []).duplicate(true), "rows": rows}

