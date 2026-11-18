extends Control

func _ready() -> void:
	%ModalCard.reparent(%Modal.content, false)
	%SettingsCard.reparent(%Page.content, false)
	%Modal.content.get_node("ModalCard/Body/Close").pressed.connect(%Modal.close)
	%Page.content.get_node("SettingsCard/Body/Close").pressed.connect(%Page.close)
	%ShowModal.pressed.connect(%Modal.open)
	%ShowPage.pressed.connect(%Page.open)
