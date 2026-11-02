extends SceneTree
## Drives the real app for repeatable local ENet validation; manual editor acceptance stays separate.
const MAIN: String = "godot_party_default_framework_lab"
const MINI: String = "godot_party_default_framework_probe"
const BLANK: String = "godot_party_default_blank"
var app: Control
var role: String = "client"
var count: int = 2
var port: int = 39917
var scenario: String = "probe"
var spectator_host: bool = false
var deadline: int
var stage: int = 0
var seen: Dictionary = {}
var checked: Dictionary = {}
var failures: Array[String] = []
var complete_peers: Dictionary = {}
var complete_sent: bool = false
var ending: bool = false
var barrier_seen: bool = false
var exit_target: int = 0

func _init() -> void:
	ProjectSettings.set_setting("autoload/MCPRuntimeServer", null)

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--lab-role="):
			role = argument.trim_prefix("--lab-role=")
		elif argument.begins_with("--lab-count="):
			count = argument.trim_prefix("--lab-count=").to_int()
		elif argument.begins_with("--lab-port="):
			port = argument.trim_prefix("--lab-port=").to_int()
		elif argument.begins_with("--lab-scenario="):
			scenario = argument.trim_prefix("--lab-scenario=")
		elif argument == "--lab-spectator-host":
			spectator_host = true
	deadline = Time.get_ticks_msec() + 45000
	start.call_deferred()

func start() -> void:
	app = load("res://core/app/party_main.tscn").instantiate()
	root.add_child(app)
	verify(app._content_error.is_empty() and app.catalog.errors.is_empty(), "content mount/catalog")
	app.connection.control_received.connect(_control)
	app.runner.failed.connect(func(message: String) -> void: verify(false, "runner: " + message))
	if role == "host":
		verify(app.host_from_ui(MAIN, "Framework lab acceptance", port) == OK, "formal create room")
		verify(app.connection.configure(MAIN, {}, {MINI: app.catalog.defaults(MINI), BLANK: {}},
			{"minigames": [MINI, BLANK]}) == OK, "configure pool")
	else:
		verify(app.join_from_ui("127.0.0.1", port) == OK, "formal join room")

func _control(sender: int, kind: String, _payload: Dictionary) -> void:
	if kind == "lab_complete":
		complete_peers[sender] = true
	elif kind == "lab_exit" and role != "host":
		finish.call_deferred()

func verify(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error("LAB_ASSERT: " + message)

func _process(_delta: float) -> bool:
	if app == null or ending:
		return false
	if Time.get_ticks_msec() > deadline:
		verify(false, "timeout stage=" + str(stage))
		finish()
		return false
	var runner: Node = app.runner
	if not app.connection.online or app.connection.room.is_empty():
		return false
	if stage == 0 and app.connection.players.size() == count:
		verify(app._frontend._room_view != null, "formal room scene")
		if role != "host":
			app.connection.set_ready(true)
			stage = 1
		elif app.connection.start_reason().is_empty():
			verify(runner.begin() == OK, "main readiness barrier")
			stage = 1
	if runner.phase == "loading" and not runner._child_id.is_empty():
		var child: Node = runner._scopes[runner._child_id].root
		if scenario == "probe":
			verify(child.phase == child.Phase.PREPARING, "no early child start")
			barrier_seen = true
	if runner.phase == "main":
		var parent: Node = runner._scopes[runner._main_id].root
		if stage == 1 and role == "host":
			var participants: Array[String] = []
			for player: Dictionary in app.connection.players:
				if not spectator_host or player.peer_id != 1:
					participants.append(player.player_id)
			parent.start_rounds(participants, BLANK if scenario == "blank" else MINI)
			stage = 2
		if parent.state.history.size() == 2 and parent.state.remaining == 0 and not complete_sent:
			if scenario == "probe" and parent.audit.size() != 2:
				return false
			verify(seen.size() == 2, "two distinct child scopes")
			verify(runner.record.rounds.size() == 2, "two durable records, no duplicate commit")
			verify(parent.committed_notifications == 2 and parent.resumed == 2, "one notification and resume per round")
			if scenario == "probe":
				verify(barrier_seen, "observed delayed readiness")
				for passed: bool in parent.audit.values():
					verify(passed, "stop/cleanup/free and stale API rejected")
				for result: Dictionary in parent.state.history:
					verify(result.game_data.receipts == count, "real receipts from every peer")
					verify(result.game_data.host_participating == not spectator_host, "host spectator semantics")
			var presentation: Dictionary = parent.api.get_round_presentation()
			verify(presentation.rows.size() == (count - 1 if spectator_host else count), "protocol result rows")
			for row: Dictionary in presentation.rows:
				verify(row.rank == 0, "blank result remains unranked")
			verify(parent.api.show_results(presentation) == OK, "public result panel")
			complete_sent = true
			app.connection.control("lab_complete", {}, 1)
		if role == "host" and complete_sent and complete_peers.size() == count and stage != 3:
			stage = 3
	if role == "host" and stage == 3:
		var remaining_peers: Array[int] = []
		for player: Dictionary in app.connection.players:
			if player.connected and player.peer_id != 1:
				remaining_peers.append(player.peer_id)
		if remaining_peers.is_empty():
			finish()
			return false
		# Shut down one peer at a time after its completed check, not simultaneous disconnect stress.
		if exit_target not in remaining_peers:
			exit_target = remaining_peers[0]
			app.connection.control("lab_exit", {}, exit_target)
	if runner.phase == "child":
		var scope: Dictionary = runner._scopes[runner._child_id]
		var child: Node = scope.root
		if not seen.has(scope.id):
			seen[scope.id] = Time.get_ticks_msec()
			verify(scope.api.get_players().size() == (count - 1 if spectator_host else count), "participant subset")
			verify(scope.api.get_spectators().size() == (1 if spectator_host else 0), "spectator list")
			if role != "host":
				verify(scope.api.finish({}) == ERR_UNAUTHORIZED, "client cannot finish")
		if role == "host" and not checked.has(scope.id) and Time.get_ticks_msec() - int(seen[scope.id]) > 500:
			checked[scope.id] = true
			if scenario == "probe":
				child.run_checks()
			else:
				child.finish_round()
		if role == "host" and scenario == "probe" and checked.has(scope.id) and not child._finish.disabled:
			child.finish_round()
	return false

func finish() -> void:
	if ending:
		return
	ending = true
	print("LAB_NETWORK ", scenario, " ", role, " count=", count, " spectator_host=", spectator_host,
		" scopes=", seen.size(), " failures=", failures)
	app.connection.leave()
	app.queue_free()
	quit(0 if failures.is_empty() else 1)
