## Temporary blank content package. Edit its local settings from the lobby's minigame pool.
extends Control
var _api: PartyAPI

func party_setup(api: PartyAPI, _config: Dictionary) -> void:
	_api = api

func _ready() -> void:
	$Notice.text = _api.i18n.text(&"game.notice") + "\n\n" + _api.i18n.text(&"game.locale", {"locale": _api.i18n.effective_locale()})
	_api.mark_ready()

func party_start() -> void:
	pass

func party_stop(_reason: StringName) -> void:
	pass
