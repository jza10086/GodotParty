extends RefCounted
## Pure queue construction and round settlement. The saved queue is never redrawn on resume.

static func make_queue(pool: Array, settings: Dictionary, seed_value: int) -> Array[String]:
	var selected: Array[String] = []
	for value: Variant in pool:
		if value is String and not value.is_empty() and value not in selected:
			selected.append(value)
	var result: Array[String] = []
	if selected.is_empty():
		return result
	var count: int = selected.size() if settings.rounds == 0 else int(settings.rounds)
	var random_order: bool = settings.rotation == "随机"
	var repeat: bool = not (random_order and settings.avoid_repeat)
	if not repeat:
		count = mini(count, selected.size())
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	if random_order and not repeat:
		for index: int in range(selected.size() - 1, 0, -1):
			var other: int = rng.randi_range(0, index)
			var saved: String = selected[index]
			selected[index] = selected[other]
			selected[other] = saved
	for index: int in count:
		result.append(selected[rng.randi_range(0, selected.size() - 1)] if random_order and repeat else selected[index % selected.size()])
	return result

static func initial(pool: Array, settings: Dictionary, players: Array[Dictionary], seed_value: int) -> Dictionary:
	var scores: Dictionary = {}
	for player: Dictionary in players:
		scores[player.player_id] = 0
	return {"queue": make_queue(pool, settings, seed_value), "cursor": 0, "completed": 0,
		"requested_rounds": pool.size() if settings.rounds == 0 else int(settings.rounds), "rotation": settings.rotation,
		"avoid_repeat": settings.rotation == "随机" and settings.avoid_repeat, "interval": int(settings.interval),
		"scores": scores, "attempt": 0, "launch": {}, "pause_reason": "", "last": {}, "history": []}

## Only the pending request can advance the queue. Cancellation leaves the slot available for retry.
static func settle(old_state: Dictionary, result: Dictionary) -> Dictionary:
	var next: Dictionary = old_state.duplicate(true)
	var launch: Dictionary = next.get("launch", {})
	if launch.is_empty() or result.get("request_id") != launch.get("request_id"):
		return next
	next.launch = {}
	if result.get("reason") != "completed":
		next.pause_reason = "小游戏取消，本局未计分。可重试本局或结束轮换。"
		return next
	var count: int = launch.participants.size()
	for row: Dictionary in result.get("rankings", []):
		if row.get("status") == "completed" and int(row.get("rank", 0)) > 0 and next.scores.has(row.player_id):
			next.scores[row.player_id] += maxi(0, count - int(row.rank) + 1)
	next.history.append({"game_id": launch.game_id, "request_id": launch.request_id})
	next.cursor += 1
	next.completed += 1
	next.last = result.duplicate(true)
	next.pause_reason = ""
	return next
