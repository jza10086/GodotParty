extends RefCounted
## Offline scenario driver. All playable states are reached via the real rules.
## Full-role information is confined to the simulator console and scenario builder.
const Protocol: Script = preload("res://games/protocols/godot_party_default_protocol/protocol.gd")
const MatchModel: Script = preload("res://games/minigame/godot_party_default_identity_party/identity_match.gd")
const CASES: Array[Dictionary] = [
	{"id": "intro", "name": "01 开场序言", "hint": "逐行字幕；空格跳过，重播可重新观看。"},
	{"id": "proposal", "name": "02 队长选人", "hint": "点击卡片选人、取消、选满及超额选择；确认后进入投票。"},
	{"id": "selected", "name": "03 队伍头像入列", "hint": "先空队伍，再自动点选两位；继续点选/取消可检查返回动画。"},
	{"id": "handoff", "name": "04 皇冠交接", "hint": "队伍被否决后自动轮换队长，观察皇冠轨迹。"},
	{"id": "vote", "name": "05 队伍投票·无人提交", "hint": "本机投票后，用代操作提交其余玩家；票面应保持隐藏。"},
	{"id": "partial_vote", "name": "06 队伍投票·部分完成", "hint": "卡片显示各自是否完成；支持切换到已投票或未投票者。"},
	{"id": "last_vote", "name": "07 队伍投票·最后一票", "hint": "你是最后一人，实际点击确认即可触发统一翻票。"},
	{"id": "approved", "name": "08 多数赞成·统一翻票", "hint": "混合赞成/反对票；达到严格多数才通过。"},
	{"id": "rejected", "name": "09 多数反对·统一翻票", "hint": "否决后的翻票；点击推进结果查看下一位队长。"},
	{"id": "tie", "name": "10 平票·提案被否决", "hint": "需要偶数人数，5/7 人自动切到 6/8 人。"},
	{"id": "quest_good", "name": "11 好人提交任务", "hint": "好人只能提交成功；确认后等待其余远征队员。"},
	{"id": "quest_evil", "name": "12 坏人提交任务", "hint": "坏人可选成功或失败；任务票不显示其他人的提交状态。"},
	{"id": "quest_wait", "name": "13 非远征队员等待", "hint": "不在队伍内时只能等待；控制台可以代其他人行动。"},
	{"id": "quest_last", "name": "14 远征·最后一张牌", "hint": "其余队员已提交；你确认后即可查看结算落格。"},
	{"id": "success", "name": "15 远征成功·结果落格", "hint": "圣杯出现、飞行、落入第一格；重复快照不应打断。"},
	{"id": "failure", "name": "16 远征失败·结果落格", "hint": "破碎徽章落格；全程只公布任务票总数。"},
	{"id": "fourth_one", "name": "17 第四轮·一张失败仍成功", "hint": "7/8 人第四轮需要两张失败；较少人数自动切到 7 人。"},
	{"id": "fourth_two", "name": "18 第四轮·两张失败判失败", "hint": "检查第四格判定、两种失败票计数和后续第五轮。"},
	{"id": "fifth", "name": "19 第五轮·决胜组队", "hint": "前四轮两胜两负；检查五格记录和最后一轮组队。"},
	{"id": "assassin", "name": "20 刺客选择目标", "hint": "三次任务成功；刺客从好人中选目标并确认。"},
	{"id": "assassin_wait", "name": "21 等待刺客行动", "hint": "好人视角只能看到等待刺客，不泄露刺客是谁。"},
	{"id": "good_win", "name": "22 刺杀落空·好人胜利", "hint": "查看胜利字幕、全部身份揭晓以及结束按钮。"},
	{"id": "evil_hit", "name": "23 刺中梅林·邪恶胜利", "hint": "查看刺杀命中终局与全部身份揭晓。"},
	{"id": "evil_quests", "name": "24 三次失败·邪恶胜利", "hint": "第三次失败直接终局；终局结果也应落格。"},
	{"id": "evil_rejects", "name": "25 连续五次否决·邪恶胜利", "hint": "第五次否决直接结束；检查终局与最后一次翻票。"},
	{"id": "full_track", "name": "26 五格全部完成", "hint": "五轮结果为胜、负、胜、负、负，检查完整轨道。"},
	{"id": "spectator", "name": "27 观战者视角", "hint": "没有自己的身份和行动权限；可用控制台代玩家操作。"},
	{"id": "cancelled", "name": "28 玩家退出·本局取消", "hint": "取消状态来自真实模型；控制台显示取消原因，不产生胜负。"},
	{"id": "long_names", "name": "29 八人·长名字布局", "hint": "八人卡片与长名字，切换各座位检查边缘布局和省略。"}
]
const NAMES: Array[String] = ["青岚", "Mira", "月下旅人", "阿北 07", "星河", "小小骑士", "墨", "长名字的远征旅人"]
var model: RefCounted
var roster: Array[Dictionary] = []
var before_views: Dictionary = {}
var preferred_seat: int = 1
var player_count: int = 5
var case_id: String = ""
var errors: Array[String] = []

func build(id: String, count: int) -> bool:
	case_id = id
	player_count = clampi(count, 5, 8)
	if id == "tie" and player_count % 2 != 0:
		player_count += 1
	if id in ["fourth_one", "fourth_two"]:
		player_count = maxi(player_count, 7)
	if id == "long_names":
		player_count = 8
	before_views.clear()
	errors.clear()
	roster.clear()
	for index: int in player_count:
		var display_name: String = NAMES[index]
		if id == "long_names":
			display_name = ["这是一位名字非常长的圆桌骑士", "Long Knight Name 2026", "月下旅人 · 圣杯守望者", "阿北 07", "星河与远方的旅人", "小小骑士", "墨", "长名字的远征旅人"][index]
		roster.append({"player_id": "avalon-sim-%d" % (index + 1), "name": display_name, "color": Protocol.COLORS[index], "is_local": false, "connected": true})
	model = MatchModel.new()
	if not model.start(roster, {"mode": "阿瓦隆"}, 715):
		errors.append("模拟对局初始化失败")
		return false
	preferred_seat = int(model.rules.state.leader_id)
	match id:
		"intro", "proposal", "selected", "long_names":
			pass
		"handoff":
			_propose()
			_vote_all(false, true)
			advance()
			preferred_seat = int(model.rules.state.leader_id)
		"vote", "partial_vote", "last_vote", "spectator":
			_propose()
			preferred_seat = 1
			if id == "partial_vote":
				act(2, "team_vote", 1)
				act(3, "team_vote", 0)
			elif id == "last_vote":
				for seat: int in range(2, player_count + 1):
					act(seat, "team_vote", 1 if seat % 3 != 0 else 0)
			elif id == "spectator":
				preferred_seat = 0
		"approved", "rejected", "tie":
			_propose()
			var approvals: int = player_count / 2 + 1 if id == "approved" else (player_count / 2 if id == "tie" else 1)
			for seat: int in range(1, player_count + 1):
				if seat == player_count:
					capture_before()
				act(seat, "team_vote", 1 if seat <= approvals else 0)
		"quest_good", "quest_evil", "quest_wait", "quest_last", "success", "failure":
			_begin_quest()
			if id == "quest_evil":
				preferred_seat = _team_role(true)
			elif id == "quest_wait":
				for seat: int in range(1, player_count + 1):
					if seat not in model.rules.state.team:
						preferred_seat = seat
						break
			else:
				preferred_seat = _team_role(false)
			if id == "quest_last":
				var members: Array = model.rules.state.team.duplicate()
				for seat: int in members:
					if seat != preferred_seat:
						act(seat, "quest_vote", 1)
			elif id in ["success", "failure"]:
				_quest_votes(1 if id == "failure" else 0, true)
		"fourth_one", "fourth_two", "fifth", "full_track":
			for won: bool in [true, false, true]:
				_play_quest(won)
				advance()
			if id in ["fourth_one", "fourth_two"]:
				_begin_quest()
				_quest_votes(1 if id == "fourth_one" else 2, true)
			else:
				_play_quest(false)
				advance()
				if id == "full_track":
					_begin_quest()
					_quest_votes(1, true)
			preferred_seat = int(model.rules.state.leader_id)
		"assassin", "assassin_wait", "good_win", "evil_hit":
			for index: int in 3:
				_play_quest(true)
				advance()
			preferred_seat = seat_for_role("assassin")
			if id == "assassin_wait":
				preferred_seat = seat_for_role("loyal")
			elif id in ["good_win", "evil_hit"]:
				capture_before()
				act(preferred_seat, "assassinate", seat_for_role("merlin" if id == "evil_hit" else "loyal"))
		"evil_quests":
			for index: int in 3:
				_begin_quest()
				_quest_votes(1, index == 2)
				if index < 2:
					advance()
		"evil_rejects":
			for index: int in 5:
				_propose()
				_vote_all(false, index == 4)
				if index < 4:
					advance()
		"cancelled":
			_propose()
			model.cancel("模拟玩家退出，本局取消，不计胜负。", roster[1].player_id)
		_:
			errors.append("未知模拟场景：" + id)
	return errors.is_empty()

func snapshot(seat: int) -> Dictionary:
	return model.snapshot_for(player_key(seat))

func player_key(seat: int) -> String:
	return str(roster[seat - 1].player_id) if seat > 0 and seat <= roster.size() else "sim-spectator"

func seat_for_role(role: String) -> int:
	for player: Dictionary in model.rules.state.players:
		if str(player.role) == role:
			return int(player.id)
	return 0

func role_for(seat: int) -> String:
	return str(model.rules._player(seat).get("role", ""))

func is_evil(seat: int) -> bool:
	return role_for(seat) in ["assassin", "minion"]

## Copies are filtered per viewer before storage; the UI never receives host state.
func capture_before() -> void:
	before_views.clear()
	for seat: int in range(player_count + 1):
		before_views[seat] = snapshot(seat)

func act(seat: int, action: String, payload: Variant) -> Dictionary:
	var response: Dictionary = model.act(player_key(seat), action, payload, model.epoch)
	if not response.get("ok", false):
		errors.append(str(response.get("error", "行动失败")))
	return response

func advance() -> bool:
	return model.advance_time(model.RESULT_DISPLAY_SECONDS)

func pending() -> Array:
	return [] if model.finished() else model.rules.pending_player_ids()

func team_for_quest() -> Array[int]:
	var team: Array[int] = []
	var required: int = int(model.rules.state.quest_sizes[int(model.rules.state.quest_number) - 1])
	# Evil seats first make failure branches reachable; always include a good seat.
	for player: Dictionary in model.rules.state.players:
		if is_evil(int(player.id)) and team.size() < mini(required - 1, 2):
			team.append(int(player.id))
	for player: Dictionary in model.rules.state.players:
		if not is_evil(int(player.id)) and team.size() < required:
			team.append(int(player.id))
	for player: Dictionary in model.rules.state.players:
		if team.size() < required and int(player.id) not in team:
			team.append(int(player.id))
	return team

## One deterministic stand-in action, only in the simulator. Never a network bot.
func step(seat: int, positive: bool = true) -> Dictionary:
	if seat not in pending():
		return {"ok": false, "error": "这位玩家当前无需行动。"}
	match str(model.rules.state.phase):
		"team_proposal":
			return act(seat, "propose_team", team_for_quest())
		"team_vote":
			return act(seat, "team_vote", 1 if positive else 0)
		"quest":
			return act(seat, "quest_vote", 1 if positive or not is_evil(seat) else 0)
		"assassination":
			return act(seat, "assassinate", seat_for_role("loyal" if positive else "merlin"))
	return {"ok": false, "error": "当前阶段没有代操作。"}

func _propose() -> void:
	act(int(model.rules.state.leader_id), "propose_team", team_for_quest())

func _vote_all(approve: bool, record: bool = false) -> void:
	for seat: int in range(1, player_count + 1):
		if record and seat == player_count:
			capture_before()
		act(seat, "team_vote", 1 if approve else 0)

func _begin_quest() -> void:
	_propose()
	_vote_all(true)
	advance()

func _team_role(evil: bool) -> int:
	for seat: int in model.rules.state.team:
		if is_evil(seat) == evil:
			return seat
	return int(model.rules.state.team[0])

func _quest_votes(failures: int, record: bool = false) -> void:
	var team: Array = model.rules.state.team.duplicate()
	for index: int in team.size():
		var seat: int = int(team[index])
		if record and index == team.size() - 1:
			capture_before()
		var fail_vote: bool = failures > 0 and is_evil(seat)
		if fail_vote:
			failures -= 1
		act(seat, "quest_vote", 0 if fail_vote else 1)
	if failures > 0:
		errors.append("队伍内坏人不足，无法构造指定失败票数。")

func _play_quest(success: bool) -> void:
	_begin_quest()
	var required: int = int(model.rules.public_view(0).fails_required)
	_quest_votes(0 if success else required)
