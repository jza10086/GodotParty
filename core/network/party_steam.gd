## Optional desktop Steam transport. Steam lobby membership supplies the host identity.
## ENet and mobile builds can load the framework without the native extension.
extends RefCounted

const PlayerCounts = preload("res://core/config/party_player_counts.gd")
const APP_ID_SETTING: String = "steam/initialization/app_data/app_id"
const PRODUCT: String = "GodotParty"

var connection: Node
var api: Object
var initialized: bool = false
var lobby_id: int = 0
var _creating: bool = false
var _joining: int = 0
var _wanted: bool = false
var _title: String
var _main: String

func _init(owner_connection: Node) -> void:
	connection = owner_connection
	if Engine.has_singleton("Steam"):
		api = Engine.get_singleton("Steam")

func initialize() -> Error:
	if initialized:
		return OK
	if api == null:
		connection.status = "当前构建未安装 GodotSteam"
		return ERR_UNAVAILABLE
	var app_id: int = int(ProjectSettings.get_setting(APP_ID_SETTING, 0))
	if app_id == 0 and OS.get_environment("SteamAppId").to_int() <= 0:
		connection.status = "请通过 Steam 启动游戏，或先配置开发用 Steam App ID"
		return ERR_UNCONFIGURED
	var result: Dictionary = api.steamInitEx(app_id, false)
	if result.status != 0:
		connection.status = "Steam 初始化失败：" + str(result.verbal)
		return ERR_CANT_CONNECT
	api.lobby_created.connect(_created)
	api.lobby_joined.connect(_joined)
	api.join_requested.connect(_invite_received)
	api.initRelayNetworkAccess()
	initialized = true
	return OK

## Both Steam launch parameters and the running overlay resolve to a lobby ID.
func boot(arguments: PackedStringArray) -> void:
	var index: int = arguments.find("+connect_lobby")
	if index >= 0:
		if index + 1 >= arguments.size() or not arguments[index + 1].is_valid_int() or arguments[index + 1].to_int() <= 0:
			connection.leave("无效的 Steam 大厅邀请")
			return
		_invite_received(arguments[index + 1].to_int(), 0)
	elif api != null and (OS.get_environment("SteamAppId").to_int() > 0 or (int(ProjectSettings.get_setting(APP_ID_SETTING, 0)) > 0 and api.isSteamRunning())):
		if initialize() != OK:
			connection.changed.emit()

func create(title: String, main_id: String) -> Error:
	if connection.online or _creating or _joining != 0:
		return ERR_ALREADY_IN_USE
	var error: Error = initialize()
	if error != OK:
		return error
	_creating = true
	_wanted = true
	_title = title
	_main = main_id
	connection.begin_steam_request(true)
	api.createLobby(1, PlayerCounts.MAX_PLAYERS) # k_ELobbyTypeFriendsOnly
	return OK

func _invite_received(id: int, _friend: int) -> void:
	if connection.online or _creating or _joining != 0:
		connection.status = "请先离开当前房间再接受 Steam 邀请"
		connection.changed.emit()
		return
	if initialize() != OK:
		connection.changed.emit()
		return
	_joining = id
	_wanted = true
	connection.begin_steam_request(false)
	api.joinLobby(id)

func _created(result: int, id: int) -> void:
	if not _creating:
		return
	_creating = false
	if not _wanted:
		if result == 1:
			api.leaveLobby(id)
		return
	if result != 1:
		connection.leave("Steam 创建大厅失败（%d）" % result)
		return
	lobby_id = id
	if not api.setLobbyData(id, "game", PRODUCT):
		connection.leave("无法设置 Steam 大厅标识")
		return
	var peer: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
	peer.set("server_relay", true)
	var error: Error = peer.call("create_host", 0)
	if error != OK:
		connection.leave("Steam 房主监听失败：" + error_string(error))
		return
	connection.start_host_session(peer, _title, _main)

func _joined(id: int, _permissions: int, _locked: bool, result: int) -> void:
	# Steam also reports entry to our own newly created lobby.
	if _joining != id:
		return
	_joining = 0
	if not _wanted:
		if result == 1:
			api.leaveLobby(id)
		return
	if result != 1:
		connection.leave("Steam 加入大厅失败（%d）" % result)
		return
	lobby_id = id
	if api.getLobbyData(id, "game") != PRODUCT:
		connection.leave("该 Steam 大厅不属于 GodotParty")
		return
	var peer: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
	peer.set("server_relay", true)
	var error: Error = peer.call("create_client", api.getLobbyOwner(id), 0)
	if error != OK:
		connection.leave("Steam 连接房主失败：" + error_string(error))
		return
	connection.attach_client(peer)

func is_member(peer_id: int) -> bool:
	var peer: MultiplayerPeer = connection.multiplayer.multiplayer_peer
	var steam_id: int = peer.call("get_steam_id_for_peer_id", peer_id)
	for i: int in range(api.getNumLobbyMembers(lobby_id)):
		if api.getLobbyMemberByIndex(lobby_id, i) == steam_id:
			return true
	return false

## Query the native RTT only after Steam has collected its first latency sample.
func ping_msec(peer_id: int) -> int:
	var peer: MultiplayerPeer = connection.multiplayer.multiplayer_peer
	var packet_peer: Object = peer.call("get_peer", peer_id)
	var sample: Dictionary = api.getConnectionRealTimeStatus(packet_peer.get_connection_handle(), 0, true)
	return int(sample.connection_status.ping) if sample.response == 1 else -1

func invite() -> void:
	if not api.isOverlayEnabled():
		connection.status = "Steam 好友面板当前不可用"
		connection.changed.emit()
		return
	api.activateGameOverlayInviteDialog(lobby_id)

func leave() -> void:
	_wanted = false
	if lobby_id != 0:
		api.leaveLobby(lobby_id)
		lobby_id = 0
