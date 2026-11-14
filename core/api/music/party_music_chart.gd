## Shared chart binding; the consuming game interprets its data and scoring.
class_name PartyMusicChart
extends Resource
const DEFAULT_BASE_SCORE: int = 1000000
@export var difficulty: String = "Normal"
## Absolute res:// path to the chart data, independent of the consuming game's folder.
@export_file("*.json") var chart_path: String = ""
@export_range(1, 1000000000, 1) var base_score: int = DEFAULT_BASE_SCORE
