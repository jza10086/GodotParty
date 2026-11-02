# 基础语音

core 提供实际媒体后端，协议定义用户偏好与路由规则；使用完整正式大厅，不存在独立语音启动器。

## 公共接口

每次激活重新注入 api.voice；旧句柄因 scope/generation 不匹配而失效。主游戏恢复后重新取得句柄。

- configure_local_endpoint(options: Dictionary) -> Error：当前作用域本端调用。必须完整提供 capture_requested、transmit_requested、receive_requested（bool）与 playback_bus（String）。发送要求同时请求采集。
- register_playback_bus(bus_name: String) -> Error：登记已存在、前缀为 party.<scope_id>. 的协议总线；由设置 runtime 在 enter 中调用。
- set_policy(policy: Dictionary) -> Error：当前房主调用。mode 为 off/global/group/proximity/custom；proximity 需要正数 radius。
- update_entities(entities: Dictionary) -> Error：当前房主提供 player_id 索引的数据；分组使用 group，距离使用 Vector3 position 与 space。2D 玩法可映射为 Vector3(x,y,0)。单位和世界空间由协议规定。
- set_route_evaluator(evaluator: Callable) -> Error：房主自定义路由，回调 (sender_player_id, receiver_player_id, entities_snapshot) -> bool。没有回调时 custom 模式不会传给任何人。
- bind_anchor(player_id: String, anchor: Node) -> Error：本地 Node2D/Node3D 播放位置；不改变房主确定的可听关系。
- get_status() -> Dictionary：端点、采集/发送/接收状态、收发帧计数、错误及真实能力。
- `get_local_devices() -> Dictionary` 返回本机设备快照。有效句柄返回 `available = true`、`microphone_allowed` 和 `input`、`output` 两组数据。每组的 `devices` 是驱动枚举的设备名列表（PackedStringArray），`selected` 是保存的名称，`current` 是 AudioServer 当前报告的名称，`available` 表示保存的名称仍在列表内。`Default` 表示跟随系统默认设备。查询不会开启采集。失效句柄只返回 `{"available": false, "reason": "inactive_scope"}`。

协议 runtime 负责端点，游戏只在协议明确委托下接管。原版协议委托小游戏轮换的房间场景管理该大厅端点；协议画质 runtime 不创建语音端点。二者不应争用同一端点。
这些接口不是系统权限沙箱；同进程内容仍具有普通 Godot 能力。
关闭的句柄返回 ERR_UNAVAILABLE；非房主路由调用返回 ERR_UNAUTHORIZED；无效参数返回 ERR_INVALID_PARAMETER；未登记播放总线返回 ERR_UNCONFIGURED。

设备选择和麦克风授权使用系统设置页；协议调用不修改设备、不保存偏好、不授予授权。
原版轮换大厅默认关麦、开收听，每次进入都需要主动启用麦克风。系统设置的 `system.microphone_mode` 决定端点请求采集后的行为。默认 `open`（自由麦）持续采集，`push_to_talk`（长按开麦）只在游戏窗口聚焦且按住 V 时采集，输入文字时暂停。两种模式都须取得本地授权，且只有请求发送的端点才能传输。有效句柄的 `get_status().microphone_mode` 返回已应用的模式。
本地设置“声音与设备 → 录制”中的“麦克风检测”使用已应用的授权和设备，直接回放到本机并显示输入电平。检测独占本机麦克风，期间暂停房间上行语音，停止后按原端点请求和开麦模式恢复。
本机没有麦克风仍可以收听。所选设备失效时停止采集，不静默选择另一支麦克风。
无协议主界面不开启语音；协议大厅有独立作用域，读取协议基值；准备期间禁止发送。
离开作用域先停止媒体、清空缓冲，再释放协议总线；接收增益只在 Voice 总线执行一次。

## 媒体格式与边界

16 kHz、单声道、PCM16、小端，20 ms/320 样本/640 字节一帧。
AudioEffectCapture 提取引擎混音采样，使用流式低通与重采样后发送；AudioStreamGenerator 按 16 kHz 播放。
不提供 Opus、降噪、自动增益、回声消除或语音录制。
单说话者纯载荷约 256 kbit/s；房主扇出会增加总上行带宽。

通道 0 控制，1 通用可靠消息，2 不可靠语音，3 起为内容声明流/原生通道。
客户端上传房主，发送者来自连接身份；房主按规则转发，不回放本人声音。
媒体包带会话、scope、epoch、说话段和序号；与普通游戏消息分开处理。
每位说话者独立乱序队列，目标缓冲 60 ms、最大 200 ms，过期丢弃、缺帧静音，不补播旧录音。
发送停止、设备变更、切场、离线都会清理相关状态。

## 当前验证边界

原版轮换大厅已接入全房间路由，离开大厅时停止；阿瓦隆与轮换局间视图不启用语音。定向网络检查位于 tmp/test/playlist_room/，通过正式应用和真实本机 ENet 传输合成 PCM。旧双进程 PCM 脚本已经归档，既往结果不作为当前验收依据。
这不代表真实麦克风、主观音质、近距离听感、弱网或八人体验验收通过。
后续原版协议阶段再完成四人矩阵、设备热插拔、弱网、导出宿主与平台验收。
