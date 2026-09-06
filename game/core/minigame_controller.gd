## Shared lifecycle boundary for minigames; concrete games own their internal states and rules.
class_name MinigameController
extends Node

signal local_action_requested(action_id: StringName, payload: Dictionary)
signal authoritative_progress_updated(
	results: Array[MinigamePlayerResult],
	finish_requested: bool
)
signal replay_requested()
signal return_to_lobby_requested()
signal leave_session_requested()

var active_round_id: int = 0
var active_random_seed: int = 0
var active_definition: MinigameDefinition = null
var round_players: Array[SessionPlayer] = []
var authoritative_results: Array[MinigamePlayerResult] = []


## Initializes one freshly-instantiated minigame scene.
func prepare_round(
		round_id: int,
		random_seed_value: int,
		players: Array[SessionPlayer],
		definition: MinigameDefinition
) -> Error:
	if round_id <= 0 or random_seed_value <= 0 or players.is_empty():
		return ERR_INVALID_PARAMETER
	if definition == null or definition.validate() != OK:
		return ERR_INVALID_PARAMETER
	active_round_id = round_id
	active_random_seed = random_seed_value
	active_definition = definition
	round_players = players.duplicate()
	authoritative_results.clear()
	return OK


func begin_countdown(_duration_seconds: float) -> void:
	pass


func begin_play() -> void:
	pass


func apply_authoritative_results(results: Array[MinigamePlayerResult]) -> void:
	authoritative_results = _duplicate_results(results)


func show_final_results(results: Array[MinigamePlayerResult]) -> void:
	apply_authoritative_results(results)


func cleanup_round() -> void:
	active_round_id = 0
	active_random_seed = 0
	active_definition = null
	round_players.clear()
	authoritative_results.clear()


## Runs only on the host instance after NetworkManager validates the RPC envelope.
func handle_authoritative_action(
		_peer_id: int,
		_action_id: StringName,
		_payload: Dictionary
) -> Error:
	return ERR_UNAVAILABLE


func handle_authoritative_time_expired() -> void:
	pass


func _duplicate_results(
		results: Array[MinigamePlayerResult]
) -> Array[MinigamePlayerResult]:
	var duplicates: Array[MinigamePlayerResult] = []
	for result: MinigamePlayerResult in results:
		duplicates.append(result.duplicate_result())
	return duplicates
