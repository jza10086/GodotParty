## Static editor-authored metadata used to load and time one minigame.
class_name MinigameDefinition
extends Resource

enum SyncPolicy {
	HOST_AUTHORITATIVE,
	CLIENT_RESPONSIVE,
	PREDICTED_REALTIME,
}

enum RankingMode {
	STRICT_ORDER,
	COMPETITION_SCORE,
}

@export var game_id: StringName = &""
@export var display_name: String = ""
@export var scene: PackedScene
@export var tags: Array[StringName] = []
@export var sync_policy: int = SyncPolicy.CLIENT_RESPONSIVE
@export var ranking_mode: int = RankingMode.STRICT_ORDER
@export_range(1.0, 60.0, 0.5) var load_timeout_seconds: float = 15.0
@export_range(0.0, 10.0, 0.5) var countdown_seconds: float = 3.0
@export_range(1.0, 600.0, 0.5) var time_limit_seconds: float = 20.0
@export_range(0.0, 2.0, 0.05) var result_grace_seconds: float = 0.5


func validate() -> Error:
	if game_id.is_empty() or String(game_id).length() > 64:
		return ERR_INVALID_PARAMETER
	if display_name.strip_edges().is_empty():
		return ERR_INVALID_PARAMETER
	if scene == null:
		return ERR_DOES_NOT_EXIST
	if (
		sync_policy < SyncPolicy.HOST_AUTHORITATIVE
		or sync_policy > SyncPolicy.PREDICTED_REALTIME
	):
		return ERR_INVALID_PARAMETER
	if ranking_mode < RankingMode.STRICT_ORDER or ranking_mode > RankingMode.COMPETITION_SCORE:
		return ERR_INVALID_PARAMETER
	if (
		load_timeout_seconds <= 0.0
		or countdown_seconds < 0.0
		or time_limit_seconds <= 0.0
		or result_grace_seconds < 0.0
	):
		return ERR_INVALID_PARAMETER
	return OK
