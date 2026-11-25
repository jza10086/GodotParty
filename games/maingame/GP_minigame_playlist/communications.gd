## Local, session-only conversations owned by the playlist controller, including while suspended.
extends GPPartyDialog

const TOPIC: StringName = &"playlist/whisper"
const MAX_LENGTH: int = 256
const HISTORY_LIMIT: int = 100

@onready var _recipients: OptionButton = %Recipients
@onready var _history: RichTextLabel = %History
@onready var _draft: LineEdit = %Draft
@onready var _status: Label = %SendStatus
var _api: PartyAPI
var _recipient: String = ""
var _players: Dictionary[String, String] = {}
var _online: Dictionary[String, bool] = {}
var _messages: Dictionary[String, Array] = {}
var _drafts: Dictionary[String, String] = {}
var _unread: Dictionary[String, int] = {}

func _ready() -> void:
	title = "通讯面板"
	ok_button_text = "发送"
	cancel_button_text = "关闭"
	dialog_hide_on_ok = false
	scroll_content = false
	super()
	_draft.max_length = MAX_LENGTH
	_recipients.item_selected.connect(_select_recipient)
	_draft.text_changed.connect(_edit_draft)
	_draft.text_submitted.connect(func(_value: String) -> void: _send())
	confirmed.connect(_send)
	visibility_changed.connect(_on_visibility)

func configure(api: PartyAPI) -> void:
	_api = api
	api.net.message_received.connect(_receive)
	api.players_changed.connect(_refresh_players)
	_refresh_players()

func _refresh_players() -> void:
	var names: Dictionary[String, String] = {}
	var online: Dictionary[String, bool] = {}
	for player: Dictionary in _api.get_room_players():
		if not player.is_local:
			names[player.player_id] = player.name
			online[player.player_id] = player.connected
	if names == _players and online == _online:
		return
	_players = names
	_online = online
	if _recipient.is_empty() and not names.is_empty():
		_recipient = names.keys()[0]
	_render()

func _select_recipient(index: int) -> void:
	_recipient = _recipients.get_item_metadata(index)
	_status.text = ""
	_render()

func _on_visibility() -> void:
	if visible:
		_render()

func _render() -> void:
	if visible and not _recipient.is_empty():
		_unread.erase(_recipient)
	_recipients.clear()
	for id: String in _players:
		var caption: String = _players[id]
		if _players.values().count(caption) > 1:
			caption += " · " + id.left(8)
		if not _online[id]:
			caption += "（已离线）"
		if _unread.has(id):
			caption += " · %d 条未读" % _unread[id]
		_recipients.add_item(caption)
		var index: int = _recipients.item_count - 1
		_recipients.set_item_metadata(index, id)
		if id == _recipient:
			_recipients.select(index)
	_recipients.disabled = _players.is_empty()
	if _players.is_empty():
		_recipients.text = "暂无其他玩家"
	_history.text = "\n".join(_messages.get(_recipient, []))
	_draft.editable = _online.get(_recipient, false)
	var draft: String = _drafts.get(_recipient, "")
	if _draft.text != draft:
		_draft.text = draft
	_update_send()

func _edit_draft(value: String) -> void:
	_drafts[_recipient] = value
	_status.text = ""
	_update_send()

func _update_send() -> void:
	get_ok_button().disabled = not _draft.editable or _draft.text.strip_edges().is_empty()

func _send() -> void:
	var message: String = _draft.text.strip_edges()
	if not _draft.editable or message.is_empty():
		return
	var error: Error = _api.net.send_to_player(_recipient, TOPIC, message)
	if error != OK:
		_status.text = "发送失败 · " + error_string(error)
		return
	_drafts.erase(_recipient)
	_status.text = ""
	_append(_recipient, "我", message)
	_render()
	_draft.grab_focus()

func _receive(sender: Dictionary, topic: StringName, payload: Variant) -> void:
	if topic != TOPIC or not payload is String or payload.length() > MAX_LENGTH:
		return
	var message: String = payload.strip_edges()
	if message.is_empty() or "\n" in message or "\r" in message:
		return
	var id: String = sender.player_ids[0]
	if not _online.get(id, false):
		return
	_append(id, _players[id], message)
	if not visible or id != _recipient:
		_unread[id] = _unread.get(id, 0) + 1
		var error: Error = _api.show_notice(_players[id] + " 发来一条私聊")
		if error != OK:
			push_error(error_string(error))
	_render()

func _append(id: String, author: String, message: String) -> void:
	if not _messages.has(id):
		_messages[id] = []
	var lines: Array = _messages[id]
	lines.append("%s：%s" % [author, message])
	if lines.size() > HISTORY_LIMIT:
		lines.pop_front()
