# PartyAPI / PartyNet 参考

版本：框架 4.2.0，API 4，联机协议 16。实例由 core 注入，不要自行创建“当前游戏”全局单例。

## PartyAPI

| 签名 | 使用者与有效阶段 | 语义 |
|---|---|---|
| is_host() -> bool | 全部 | 当前本端是否协调房主，房主不一定参赛 |
| is_open() -> bool | 全部 | 尚未开始关闭 |
| get_players() -> Array[Dictionary] | 活跃作用域 | 参与者快照，包含断线者 |
| get_room_players() -> Array[Dictionary] | 活跃作用域 | 房间名单快照 |
| get_spectators() -> Array[Dictionary] | 活跃作用域 | 本局未参赛者 |
| get_appearance(player_id: String) -> Dictionary | 活跃作用域 | 协议定义的数据，未知玩家为空 |
| get_settings() -> Dictionary | 全部 | 本活动锁定配置的副本 |
| get_pool(name: String) -> Array | 大游戏 | 房主选择的小游戏 ID |
| get_game_name(id: String) -> String | 活跃作用域 | 当前目录中的游戏显示名称 |
| i18n.text(key: StringName, parameters: Dictionary = {}, package_id: String = "") -> String | 已注入作用域 | 本包译文；可显式读取协议/core，翻译后填入命名参数 |
| i18n.effective_locale() -> String | 已注入作用域 | 本包独立解析后的语言 |
| get_minigame_settings(id: String) -> Dictionary | 大游戏 | 已选择小游戏的配置 |
| get_seed() -> int | 活跃作用域 | 本局公开种子 |
| load_asset(ref: Dictionary) -> Resource | 活跃作用域 | 已激活包公开资源；失败为 null |
| get_external_path(relative: String) -> String | 活跃作用域 | 本包声明的外置文件/目录绝对路径；未声明路径报错，返回空字符串 |
| get_preparation_status() -> Dictionary | 当前实例 | 技术准备快照：session_id、scope_id、phase、required_peers、ready_peers；关闭后为空；不代表玩家手动准备 |
| mark_ready() -> Error | 大小游戏准备阶段 | 本端初始化完成；准备期间重复为 OK |
| finish(result: Dictionary) -> Error | 小游戏房主运行阶段 | 同步转换与校验，接受候选结果 |
| commit_state(next_state: Dictionary) -> Error | 大游戏房主空闲阶段 | 接受普通状态提交，保存后应用广播 |
| request_minigame(id: String, request: Dictionary, participants: Array[String] = []) -> Error | 大游戏房主空闲阶段 | 空名单为在线主游戏玩家；必须来自已勾选池 |
| finish_session(presentation: Dictionary = {}) -> Error | 大游戏房主空闲阶段 | 保存终态后显示最终结果 |
| publish_standings(presentation: Dictionary) -> Error | 大游戏房主空闲阶段 | 更新可选 Tab 总览，不解释业务状态 |
| get_round_presentation() -> Dictionary | 活跃作用域 | 最近一次已提交小游戏结果的协议展示副本；没有转换器时为空 |
| show_results(presentation: Dictionary) -> Error | 活跃作用域任意端 | 本端打开公共成绩页，不广播、不改变奖励 |
| fail(code: String, message: String) -> Error | 任意活跃端 | 报告不能继续，由房主取消轮次或会话 |
| on_close(callback: Callable) -> Error | 关闭前 | 同步、LIFO、至多一次；节点释放前执行 |

只读标识：session_id、scope_id、round_id、package_id、protocol_id。

语言声明与回退见 [本地化](localization.md)。PartyRoomAPI.i18n 同样可用，默认绑定主游戏。
玩家字段：player_id、peer_id、name、connected、is_local，以及协议资料快照。不要把 peer_id 写成永久业务身份。

信号：players_changed；state_committed(revision)；commit_failed(code, message)；
round_committed(round_id, result)；round_cancelled(round_id, reason)。
round_committed 是发布通知，不能在其中再次发放已由 reducer 处理的奖励。

## 成功与错误

OK 表示同步检查通过或请求已接受，不能推导远端已处理、奖励已发放或文件已保存。
同一轮相同已接受结果返回 OK；不同候选返回 ERR_ALREADY_IN_USE。关闭后变更返回 ERR_UNAVAILABLE。
客户端提交权威结果返回 ERR_UNAUTHORIZED；已有轮次或提交返回 ERR_BUSY；非法结构为 ERR_INVALID_PARAMETER。

finish、commit_state 的后续写入失败由 commit_failed 通知；候选保留，宿主提供重试按钮。
清理回调不能 await，也不保证在强杀进程或不可恢复脚本错误下执行。

## PartyNet

- send_to_host(topic: StringName, payload: Dictionary) -> Error：任意端，可靠发送给房主。
- broadcast(topic: StringName, payload: Dictionary, include_self: bool = true) -> Error：房主可靠广播。
- send_to_player(player_id: String, stream_id: StringName, payload: Variant) -> Error。
- send_to_peer(peer_id: int, stream_id: StringName, payload: Variant) -> Error。
- broadcast_stream(stream_id: StringName, payload: Variant, audience: String = "", include_self: bool = true) -> Error。
- send_to_parent(topic: StringName, payload: Variant) -> Error：小游戏发给房主父实例。
- send_to_child(topic: StringName, payload: Variant) -> Error：房主父实例发给当前子实例。
- get_multiplayer_api()、get_instance_root()、get_native_channel_base()：原生联网入口。

信号 message_received(sender, topic, payload)、parent_message_received、child_message_received。
sender 来自真实传输层，包含 peer_id 和 player_ids。不可相信业务载荷自报身份。
默认广播和向自己发送都只投递一次；include_self=false 排除本机。

## PartyInput

api.input 按实例持有输入上下文。is_pressed、is_communication_pressed、get_vector、event_matches、get_bindings、binding_text
提供逻辑输入；通过 api.config 修改绑定字段，公共动作来自当前协议，游戏覆盖按协议分支保存。
准备阶段及观战者默认读到中性值。原始 Input 和自定义观战操作仍由作者负责。

网络单个序列化信封最大 1 MiB；消息、状态、结果及恢复记录超限返回 ERR_INVALID_DATA。
状态候选在写入前检查发布及恢复信封，拒绝后可提交更小状态，不进入待重试保存状态。


## PartyConfig

由 api.config 注入。读取快照与效果状态见 [配置说明](configuration.md)。

- get_common(key: StringName, fallback: Variant = null) -> Variant
- get_own(key: StringName, fallback: Variant = null) -> Variant
- inspect_common(key: StringName) -> Dictionary：value、protocol_base、source、overridden、audience、apply。
- snapshot_effective() -> Dictionary：common、own；含本地偏好，不得整体同步。
- set_common_override(key: StringName, value: Variant) -> Error / clear_common_override(key: StringName) -> Error
- set_own_local(key: StringName, value: Variant) -> Error / clear_own_local(key: StringName) -> Error
- effective_changed(common_keys: PackedStringArray, own_keys: PackedStringArray)

写入只允许活跃游戏的本地字段；暂停/关闭返回 ERR_UNAVAILABLE，未知/房间/不可覆盖字段返回 ERR_UNAUTHORIZED，值错误返回 ERR_INVALID_PARAMETER。
重复写相同显式值不增加版本；首次写入与基值相同的值仍创建覆盖。
OK 表示偏好已保存，不表示硬件效果已应用；effects 提供 applied/deferred/unsupported/error 状态。
get_settings() 仍是本实例 own/room 快照。get_minigame_settings() 为下一轮已确认草稿中的专属规则。

## PartyVoice

api.voice 的完整签名、身份、设备与路由说明见 [基础语音](voice.md)。
句柄属于本次激活；不要在主游戏恢复后继续保存旧语音句柄。
