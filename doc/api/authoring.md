# 小游戏入门

使用完整 GodotParty 工程。在 games/minigame/<包ID>/ 中创建 manifest.json、场景和自己的资源。
游戏可以读取框架源码，但普通内容包只能依赖公开接口；依赖修改版 core 的游戏应连同定制框架发行。

## 主游戏房间入口

主游戏还必须声明 `room_scene`（包内场景路径），提供自己的大厅视图。原版轮换的 `room.tscn` 继承公共 `core/ui/source/ui/lobby_page.tscn`，场景驱动位于轮换包中。框架负责挂载、切换、连接与配置服务。

房间脚本实现 `room_setup(context)`、`room_refresh()`、`room_focus()`、`room_stop()`。setup 在入树前调用；stop 必须可重复调用。context 来自公开 `core/api/party_room_api.gd`：`get_state()` 返回房间和玩家快照，`get_game_name(id)` 读取内容名称；`ready_or_start()`、`leave()`、`show_player(peer)`、`open_settings(panel)` 和 `show_notice(message)` 调用框架服务。panel 支持 pool/main/protocol/rules/system。`activity` 为本次大厅作用域 PartyAPI，配置变更或离开时关闭；通过 `on_close` 清理语音等资源。房间代码不依赖框架前端的私有节点。

主游戏可声明 `minigames: [包ID...]` 限制可选池；省略时使用全部协议兼容项，显式空数组不开放任何项。目录解析同时拒绝越界选择，不能只在界面过滤。主游戏声明的每个池开局前须至少选一项；空池可以作为可编辑草稿保留。

## 最小玩法入口

```gdscript
extends Node
var _api: PartyAPI

func party_setup(api: PartyAPI, _config: Dictionary) -> void:
    _api = api

func _ready() -> void:
    if _api == null:
        push_error("请从 GodotParty 启动本场景")
        return
    _api.mark_ready()

func party_start() -> void:
    # 开始玩法；不能把本地 _ready 当成联机开局。
    pass

func party_stop(_reason: StringName) -> void:
    pass
```

setup 在入树前同步执行，不访问 @onready。异步初始化在入树后开始，完成后显式 mark_ready。
finish 仅由房主调用；客户端的本地判定先通过 PartyNet 上报，房主玩法自行决定如何采用。

## 最小清单

```json
{
  "manifest_version": 2,
  "id": "author.example",
  "kind": "minigame",
  "package_version": "1.0.0",
  "core_api_major": 4,
  "player_counts": [2, 3, 4, 5, 6, 7, 8],
  "entry": "game.tscn",
  "adapters": [
    {"id": "ranked", "protocol": {"id": "your.protocol", "api_major": 1, "min_api_minor": 0}}
  ]
}
```

已登记但尚不能从框架开局的原型须声明 `playable: false` 和空的 `adapters` 数组，并提供包内状态场景作为 entry。目录仍可读取这些包，大游戏无法选择它们。可玩包默认 `playable: true`，至少声明一个真正支持的适配器。

没有适配脚本时，setup 的 config 就是原协议请求，finish 的字典就是协议结果。
协议、大游戏和小游戏均须声明 `player_counts`；配置依赖的限制与交集规则见 [可开局人数](player_counts.md)。
需要转换时，接入条目提供 entry，指向实现 make_config(request)、map_result(raw_result, request) 的脚本。
大厅的小游戏配置通过 api.get_settings() 读取，不隐式混入协议请求。

旧计时示例已清理；按本文钩子编写自己的小游戏。自行决定 Node/Node2D/Node3D/Control 根节点、内部状态机、碰撞、输入算法与联网算法。
