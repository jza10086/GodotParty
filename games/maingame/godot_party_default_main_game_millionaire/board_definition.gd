## 棋盘静态定义。next 是唯一合法出口；地产展示格不承担行走。
extends Resource
@export var tiles: Array[Dictionary] = []

func find_tile(id: String) -> Dictionary:
	for tile: Dictionary in tiles:
		if tile.id == id:
			return tile.duplicate(true)
	return {}

## 功能格进入消耗一点；出生点、路口和连接用免费道路不消耗行动力。
func cost(tile: Dictionary) -> int:
	return 0 if tile.kind in ["start", "junction", "road"] else 1

## 纯移动裁定，不买卖资产、不抽事件。交易结束由调用方继续本次剩余行动。
## 行动力用完停在付费格；不能再进入免费道路或路口，也不允许常规移动回起点。
func step(from_id: String, to_id: String, remaining: int) -> Dictionary:
	var source: Dictionary = find_tile(from_id)
	var target: Dictionary = find_tile(to_id)
	if source.is_empty() or target.is_empty() or to_id not in source.next or target.kind == "start":
		return {"ok": false, "code": "ILLEGAL_DIRECTION"}
	if remaining <= 0:
		return {"ok": false, "code": "NO_ACTIONS"}
	var left: int = remaining - cost(target)
	var interaction: String = target.kind if target.kind in ["shop", "diamond"] else ""
	var settlement: String = target.kind if left == 0 and target.kind in ["property", "event"] else ""
	return {"ok": true, "tile": to_id, "remaining": left, "choose_exit": target.kind == "junction" and target.next.size() > 1, "interaction": interaction, "settlement": settlement, "finished": left == 0}
