## 大富翁业务规则；只处理可序列化状态，不操作 UI、文件或联网。调用者负责授权和持久化。
extends RefCounted
const PROPERTY_PRICE: int = 150
const UPGRADE_PRICE: int = 100
const MAX_LEVEL: int = 3
const DIAMOND_PRICE: int = 200
const ITEM_PRICE: int = 100
const MAX_ITEMS: int = 5

## 返回独立候选，失败不修改输入；actor 使用 player_id。
static func transact(state: Dictionary, actor: String, action: String, tile: String = "") -> Dictionary:
	if not state.get("players", {}).has(actor):
		return {"ok":false,"message":"玩家不存在"}
	var next: Dictionary = state.duplicate(true)
	var player: Dictionary = next.players[actor]
	var price: int = 0
	match action:
		"diamond":
			price = DIAMOND_PRICE
			if int(player.money) < price:
				return {"ok":false,"message":"金币不足"}
			player.diamonds += 1
		"item":
			price = ITEM_PRICE
			if int(player.get("items", 0)) >= MAX_ITEMS:
				return {"ok":false,"message":"背包已满"}
			if int(player.money) < price:
				return {"ok":false,"message":"金币不足"}
			player.items = int(player.get("items", 0)) + 1
		"property":
			if tile.is_empty():
				return {"ok":false,"message":"地产标识为空"}
			var estate: Dictionary = next.properties.get(tile, {})
			if estate.is_empty():
				price = PROPERTY_PRICE
				if int(player.money) < price:
					return {"ok":false,"message":"金币不足"}
				next.properties[tile] = {"owner":actor,"level":1}
			elif estate.owner == actor:
				if int(estate.level) >= MAX_LEVEL:
					return {"ok":false,"message":"地产已满级"}
				price = UPGRADE_PRICE
				if int(player.money) < price:
					return {"ok":false,"message":"金币不足"}
				estate.level += 1
			else:
				price = acquisition_price(int(estate.level))
				if int(player.money) < price or not next.players.has(estate.owner):
					return {"ok":false,"message":"无法收购"}
				next.players[estate.owner].money += price
				estate.owner = actor
		"rent":
			var estate: Dictionary = next.properties.get(tile, {})
			if estate.is_empty() or estate.owner == actor or not next.players.has(estate.owner):
				return {"ok":true,"state":next,"paid":0}
			price = mini(int(player.money), rent(int(estate.level)))
			next.players[estate.owner].money += price
		"use_item":
			if int(player.get("items", 0)) <= 0 or int(player.get("fixed_roll", 0)) != 0:
				return {"ok":false,"message":"道具不可用"}
			player.items -= 1
			player.fixed_roll = 3
		_:
			return {"ok":false,"message":"未知交易"}
	player.money -= price
	return {"ok":true,"state":next,"paid":price}

static func rent(level: int) -> int:
	return 40 * clampi(level, 1, MAX_LEVEL)

static func acquisition_price(level: int) -> int:
	return (PROPERTY_PRICE + UPGRADE_PRICE * (clampi(level, 1, MAX_LEVEL) - 1)) * 2

## 钻石优先、金币次之；完全同分并列，使用竞赛名次。顺序在同分时保持原玩家顺序。
static func standings(players: Dictionary, order: Array[String]) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for id: String in order:
		var player: Dictionary = players[id]
		entries.append({"player_id":id,"diamonds":int(player.diamonds),"money":int(player.money)})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.diamonds != b.diamonds:
			return a.diamonds > b.diamonds
		if a.money != b.money:
			return a.money > b.money
		return order.find(a.player_id) < order.find(b.player_id))
	var rank: int = 0
	for index: int in range(entries.size()):
		if index == 0 or entries[index].diamonds != entries[index - 1].diamonds or entries[index].money != entries[index - 1].money:
			rank = index + 1
		entries[index]["rank"] = rank
	return entries
