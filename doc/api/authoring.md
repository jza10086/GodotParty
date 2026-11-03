# 小游戏入门

使用完整 GodotParty 工程。在 games/minigame/<包ID>/ 中创建 manifest.json、场景和自己的资源。
游戏可以读取框架源码，但普通内容包只能依赖公开接口；依赖修改版 core 的游戏应连同定制框架发行。

项目标准游戏美术布局参考记忆拼图：**全幅画面＋简要叠加 HUD**。场景或棋盘占满视口，计时、分数、当前任务和必要操作贴边叠加；用描边或小面积半透明底保证可读性，不用常驻标题栏、宽侧栏和大面板挤压游戏区域。详细规则、完整排行、图鉴和设置按需展开；准备、暂停与结算可以使用临时模态页。保留各游戏自己的题材、色彩和必要仪表，不强制改成同一种配色。

`games/minigame/godot_party_default_blank/game.tscn` 是可复制的场景示例：全幅 GraphicsLab、左上标题与状态、左下主要操作、右下简短提示。使用 1920×1080 检查画面；HUD 使用锚点与容器，装饰与标签不拦截指针。继承原版 `ranked_round.gd` 的游戏可以在构建自身 UI 后调用 `compose_fullscreen_hud()`，将 Stage 铺满、把 Sidebar 改为按需展开的浮层；必要操作应单独留在边缘。

使用框架菜单的全幅小游戏在入口根节点加入公开 UI 组 `party_minimal_hud`。该作用域处于前台时，框架默认收起顶部会话工具栏；玩家按 Esc 展开/收起菜单，保留本地设置、房间规则、排名及离开入口。菜单展开时 `api.input.input_blocked` 为 true，游戏的鼠标与键盘入口必须遵守它；计时和联网继续运行。模态页优先处理返回，退出该作用域后工具栏自动恢复。游戏应自行显示 Esc 操作提示，不访问框架私有 UI 节点。保有独立暂停菜单的单人场景继续由自身菜单处理 Esc，不能只添加组标记而让同一按键同时切换两个菜单。

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

所有协议、主游戏与小游戏须声明独立语言及回退资源，见 [本地化](localization.md)。

```json
{
  "manifest_version": 2,
  "id": "author.example",
  "kind": "minigame",
  "package_version": "1.0.0",
  "core_api_major": 4,
  "player_counts": [2, 3, 4, 5, 6, 7, 8],
  "entry": "game.tscn",
  "localization": {
    "supported_locales": ["zh_Hans"],
    "fallback_locale": "zh_Hans",
    "translations": {"zh_Hans": "i18n/zh_Hans.po"}
  },
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
