extends Node
## An invisible pickup claimed through actual top-face contact, once per racer.
var claimed: Array[ParkourEffectReceiver] = []

func _ready() -> void:
	get_parent().add_to_group(&"parkour_scoring_platform")

func collect(racer: ParkourEffectReceiver) -> void:
	if racer not in claimed:
		claimed.append(racer)
		racer.collect_token()
