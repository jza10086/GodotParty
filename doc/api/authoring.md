# 小游戏入门

使用完整 GodotParty 工程。在 games/minigame/<包ID>/ 中创建 manifest.json、场景和自己的资源。
游戏可以读取框架源码，但普通内容包只能依赖公开接口；依赖修改版 core 的游戏应连同定制框架发行。

项目标准游戏美术布局参考记忆拼图：**全幅画面＋简要叠加 HUD**。场景或棋盘占满视口，计时、分数、当前任务和必要操作贴边叠加；用描边或小面积半透明底保证可读性，不用常驻标题栏、宽侧栏和大面板挤压游戏区域。详细规则、完整排行、图鉴和设置按需展开；准备、暂停与结算可以使用临时模态页。保留各游戏自己的题材、色彩和必要仪表，不强制改成同一种配色。

`games/minigame/gp_blank/game.tscn` 是可复制的场景示例：原生 Node3D 展台与可切换的 Node2D 航道直接显示，CanvasLayer 叠加 HUD。固定模型、二维物件、灯光、相机和控件优先保存在场景文件中。使用 1920×1080 检查画面；HUD 使用锚点与容器，装饰与标签不拦截指针。原版排名回合的 `ranked_round.tscn` 预置全幅 Stage、CanvasLayer HUD 和按需展开的详情。继承场景可直接编辑标题、提示和固定操作。

所有通过框架启动的小游戏自动接入共享 Esc 菜单，无需在每个入口手动添加 UI 组。大游戏仍可用 `party_minimal_hud` 选择同样的全幅菜单布局。小游戏处于前台时，框架默认收起顶部会话工具栏；玩家按 Esc 展开/收起独立场景 `core/ui/session_menu/session_menu.tscn`：半透明遮罩中央的卡片纵向排列“返回游戏、框架设置、小游戏设置、返回大厅”。小游戏设置直接打开前台子活动的本机偏好，无子活动时禁用；框架设置打开系统设置。大厅按住 Tab 查看玩家/延迟面板；游戏中 Tab 面板的名次、成绩和排序由主游戏通过 `publish_standings` 接管，同时保留网络统计，松开或失焦关闭；面板不暂停玩法、不改变鼠标捕获。总排名改用 F3，房间规则在大厅设置。Esc/Tab/F3 属于框架快捷键，正式小游戏不应占用；输入文字、设置和模态页面中保留原有焦点导航。房主返回大厅会结束本局，客机沿用退出会话行为。保存失败另有重试弹窗。菜单展开时 `api.input.input_blocked` 为 true，游戏的鼠标与键盘入口必须遵守它；计时和联网继续运行。设置页或模态页优先处理返回，关闭设置后回到菜单；退出该作用域后工具栏自动恢复。框架菜单、设置和模态 UI 位于 `FrameworkUI`（CanvasLayer 64），游戏 HUD 应使用低于 64 的层级。打开菜单时释放鼠标捕获，返回游戏恢复原鼠标模式。游戏自身浮层需要优先关闭时，应消费该次 Esc，不能同时打开第二套暂停或退出菜单。游戏应自行显示 Esc 操作提示，不访问框架私有 UI 节点。单人场景正式接入该菜单时，Esc 只由框架处理，独立暂停可使用其他声明动作；F6 可保留自身 Esc 暂停。不能让同一按键同时切换两个菜单。

Android 在左上角提供常态隐藏的 ESC 虚拟按钮（`core/ui/party_touch_escape.tscn`，CanvasLayer 128）：首次触碰附近区域只显现按钮，松开后再次点中按钮才发送一次标准 Escape 按下/释放事件；3 秒无操作自动隐藏，按住时不计时，拖出按钮后松手取消。唤醒区域消费触摸模拟的鼠标点击，不点穿下层界面；桌面端不显示也不拦截点击。显示时长可在 WakeArea 的 Inspector 调整。

## 网络通信

接入前阅读[内容网络通信指南](networking.md)。只发送必要数据，离散数据尽可能一次传输后本地处理；禁止周期性广播完整玩法快照。直接使用原生 `@rpc` 或 `PartyNet`，发送时选择可靠性，manifest 不声明 `streams` / `native_channels`。

## 主游戏房间入口

主游戏还必须提供固定的 `room.tscn`，提供自己的大厅视图。原版轮换的 `room.tscn` 继承公共 `games/assets/godot_party_default_ui/source/ui/lobby_page.tscn`，场景驱动位于轮换包中。框架负责挂载、切换、连接与配置服务。

房间脚本实现 `room_setup(context)`、`room_refresh()`、`room_focus()`、`room_stop()`。setup 在入树前调用；stop 必须可重复调用。context 来自公开 `core/api/party_room_api.gd`：`get_state()` 返回房间和玩家快照，`get_game_name(id)` 读取内容名称；`ready_or_start()`、`leave()`、`show_player(peer)`、`open_settings(panel)` 和 `show_notice(message)` 调用框架服务。panel 支持 pool/main/preferences/protocol/rules/system；preferences 打开当前主游戏的本地偏好与协议继承设置。`activity` 为本次大厅作用域 PartyAPI，配置变更或离开时关闭；通过 `on_close` 清理语音等资源。房间代码不依赖框架前端的私有节点。`update_main_settings(values)` 在房主大厅合并并应用部分主游戏规则，保留选池及其他配置，复用现有校验与同步流程；客机或恢复中的房间不能修改。

小游戏轮换自动列出目录中所有适配所选协议的小游戏；新增或更新小游戏后重启即可。其他主游戏可声明 `minigames: [包ID...]` 限制可选池，省略时使用全部协议兼容项，显式空数组不开放任何项。房主勾选的项目组成实际轮换池，每个声明的池开局前须至少选一项。

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
    var error: Error = _api.mark_ready()
    if error != OK:
        _api.fail("load_failed", error_string(error))

func party_start() -> void:
    # 开始玩法；不能把本地 _ready 当成联机开局。
    pass

func party_stop(_reason: StringName) -> void:
    pass
```

setup 在入树前同步执行，不访问 @onready。异步初始化在入树后开始，完成后显式 mark_ready。
finish 仅由房主调用；客户端的本地判定先通过 PartyNet 上报，房主玩法自行决定如何采用。

采用原版 `solo_round` 的单参赛者游戏须实现 `solo_setup(input, text_source)`、`solo_start()`、可重复的 `solo_stop()` 与画质/音频目标方法，并发出 `completed(metrics)`。入口在准备阶段创建本机玩法、注入依赖并转发协议挂点，观战端不运行模拟；正式开始等待公共准备页完成。F6 输入只读包内默认绑定，正式使用 PartyInput。完整边界见协议文档的[单参赛者接入](../../games/protocols/godot_party_default_protocol/doc/README.md#单参赛者接入)。

## 内容声明与入口

所有内容包统一使用以下声明。包 ID 取目录名，形象包的所属协议取父目录；作者不重复填写身份。

```json
{
  "name": "示例游戏",
  "kind": "minigame",
  "package_version": "0.0.1",
  "framework_version": "0.0.1",
  "remark": "",
  "supported_languages": ["zh-CN"],
  "dependencies": {"godot_party_default_protocol": "~0.0.1"}
}
```

`remark` 为必需字符串，可以为空。`supported_languages` 为必需的非空语言代码数组，元素不得为空或重复；当前所有内容声明 `["zh-CN"]`（简体中文）。`dependencies` 没有依赖时省略，资产包必须无依赖。声明只维护这些字段；入口、资源别名、平台、协议 API 主次版本、翻译文件路径和玩法参数不进入 manifest。

主游戏和小游戏入口固定为 `game.tscn`，协议入口固定为 `protocol.gd`。协议、主游戏和小游戏在包根目录的 `definition.gd`（继承 `RefCounted`）中实现 `static func party_definition() -> Dictionary`，只返回玩法拥有的数据：`player_counts`、可选 `player_count_rules` / `tags` / `controls`；主游戏另给出 `protocol: {"id": "..."}`、`pools` 及可选 `minigames`。`definition.gd` 不引用玩法脚本、场景或素材；目录扫描只加载定义，实际启动玩法时才加载 `game.tscn`。协议同样在 `definition.gd` 提供 `party_definition()`，可声明自己的 `config_directories`，保持配置目录与包版本无关。人数计算见 [可开局人数](player_counts.md)。

小游戏适配器固定为 `adapters/<协议ID>.gd`，实现 `check_request(request)`、`make_config(request)`、`map_result(result, request)`；其 `party_definition()` 只声明该适配器的可选条件依赖 `dependencies`。只在选择该协议时检查这些依赖。无适配器的原型仍可列入目录，但不进入可玩池。

配置固定为 `settings.gd`，自定义面板为 `config_panel.tscn`，协议资料页为 `profile_panel.tscn`，设置效果脚本为 `settings_runtime.gd`，可选配置校验器为 `config_validator.gd`，主游戏大厅为 `room.tscn`。封面按 `cover.png`、`cover.svg`、`cover.webp`、`cover.jpg` 的顺序发现。玩法介绍写入 README 或所属玩法界面。语言按 `i18n/<locale>.po` 发现，见 [本地化](localization.md)。

框架版本只由 `core/framework_version.gd` 声明，与用户维护的 Godot 项目版本独立。依赖支持精确版本、`~`、`^`，规则及构建标识 见 [内容打包](source_packages.md)。构建和代码修改均不自动递增版本。

## 标准模板的职责与目录

空白模板同时提供正式接入骨架和可移植演示。`game.gd` 持有 PartyAPI、阶段、网络消息、准备与结算；`ui/briefing.tscn` 和 `ui/settlement.tscn` 继承协议页面，`ui/round_pages.tscn` 在 CanvasLayer 中静态组合它们；`examples/demo_hub.tscn` 组合演示；`examples/graphics/`、`examples/navigation_2d/`、`examples/audio/` 分别保存各功能的场景、脚本和专用资源。`adapters/<协议ID>.gd` 只检查/转换协议请求与结果，`settings.gd` 声明配置，`i18n/` 保存语言模板。可选的大型美术资源留在包内 `assets/`。

随机题库、地图、图片可参考空白模板的 [随机统计组件用法](../../games/minigame/gp_blank/README.md#通用随机统计模板)：主机从本机最少次数项中选取，各端对主机本局序列去重并更新自己的统计；正式入口注入存储路径，F6 只用内存。实现由协议的 `random/least_played_pool.gd` 提供，直接引用已声明的协议依赖，不复制模板代码，也不依赖空白模板包。

新游戏按实际功能命名目录，不强制照搬 `examples/`，也不机械建立 `scenes/`、`scripts/`、`managers/`。一个场景脚本能清楚表达的流程不再拆转发层。跨场景可替换依赖用带类型的 `@export`；同一场景拥有的固定节点用 `%UniqueNode`。只有共享组件、资源和核心数据类型注册 `class_name`。GDScript 使用显式类型，不使用 `:=`。

入口可直接调用自己的视图；视图通过信号报告玩家意图，并只接收所需的翻译、配置、音频或输入谓词。不要为了标准化，把整套 PartyAPI、网络发送和候选提交分散进每个按钮。空白模板的 `DemoHub.finish_requested` 回到入口后，才发送逻辑动作；网络边界继续验证发送者、会话、作用域、载荷与协议结果。

## 场景与运行时数据

固定的 2D、3D、HUD、相机、灯光、物理拾取表面和操作区保存为场景节点。固定身份、数量和出生位置的移动物体仍然入场景，脚本更新位置或动画。外观固定而数量取决于对局的对象做成可编辑子场景，按需实例化。实时几何（蛇身、弹道、可破坏地形、音符轨迹）可以生成或绘制，固定绘制层与挂点仍入场景。

3D 世界和活动相机直接使用主视口，HUD 放入 CanvasLayer；二维玩法使用原生 Node2D/Control。SubViewport 仅用于确实需要独立纹理的内容，不作为普通游戏主画面的默认容器。静态参数只保留一个来源：相机姿态/FOV、灯光方向/能量、环境和材质由原生节点编辑，启动脚本不能再用一组镜像字段覆盖。

原版协议的画质入口是 `godot_party_graphics_targets()`，返回 `world` 与 `sun`（纯二维或本端不创建玩法时可返回空字典），仅需要协议处理模型采样时才返回 `materials_root`。正式对局不自行覆盖同一视口的抗锯齿或渲染比例。空白展台保留的实验性画质字段只用于 F6，离开预览恢复视口；正式画质由协议 settings runtime 的 enter/attach/apply/leave 管理。效果开关可能改变，游戏自己的构图与美术参数保留。详见原版协议 [画质与接入](../../games/protocols/godot_party_default_protocol/doc/README.md)。

## 可编辑 HUD 与本地化

场景中写可读示例，例如 `航标  2 / 3`；语言资源保存稳定键 `game.beacon_status` 和模板 `航标  {current} / {total}`。状态改变时更新同一 Label：

```gdscript
%BeaconStatus.text = api.i18n.text(&"game.beacon_status", {
    "current": current_beacon, "total": beacon_count,
})
```

键名显式绑定到节点，动作显式绑定到 Callable 或枚举。不要根据当前显示文字或节点名字推断翻译键、网络动作或业务含义。修改示例文案、翻译和动作相互独立。固定容器不重建；玩家数量变化才增删行，比分变化只更新该行。假名、手牌或身份示例不得进入真实游戏状态、网络快照或结算；私有视图只使用本机获准收到的数据。

F6 默认语言直接读取包内 `i18n/zh_Hans.po`，使用与正式 `api.i18n.text()` 相同的键和命名参数，不再维护一份脚本字符串字典。只有提供独立预览的组件才处理未注入 API 的状态，正式依赖缺失必须失败。

## 生命周期、输入与计算模型

1. `party_setup` 在入树前注入依赖并复制当前协议请求，不能访问 `@onready`。本地偏好来自 `api.config`；房间规则来自 `api.get_settings()`；请求不是设置表。
2. `_ready` 连接场景、完成初始化，成功后调用并检查 `mark_ready()`。只有框架的 `party_start()` 才表示技术屏障通过。原版准备页还要求人工确认：在 `party_start()` 通知 `transport_started()`，在 `play_requested` 启动玩法。
3. 玩家输入先检查玩法阶段、`api.input.input_blocked` 和本地模态面板。菜单遮挡只禁止相应输入，不能顺带停掉联网、房主协调或所有节点的 `_process`。玩法模拟暂停、菜单遮挡和音频暂停分别处理。
4. 房主形成候选；客户展示允许接收的结果。使用协议结算页时，等待 continued 后由房主提交一次 `api.finish()` 并检查 Error；OK 只表示候选接受。父游戏负责最终提交与奖励，小游戏不得重复发奖。
5. `party_stop` 停止本游戏的发送、输入、Tween、计时器和音频，释放协议页面与信号。允许重复停止和初始化未完成时取消，但不要用反射与默认对象掩盖必需依赖错误。

统一的是边界和编码方式，不强制所有玩法继承同一个排名控制器：

| 计算模型 | 适用方式 | 必须保留的边界 |
|---|---|---|
| 本地判定、房主汇总 | 节奏、竞速等本地实时体验 | 明确上报数据、结束条件与房主采用规则 |
| 房主权威 | 棋类、拍卖、身份游戏等 | 校验逻辑动作；分别构造公开和私有视图 |
| 混合模拟 | 响应敏感、需要共同状态的玩法 | 明确各字段权威方与校正时机 |
| 独立 F6 预览 | 场景、美术、交互演示 | 不伪造 PartyAPI，不写正式偏好或提交成绩 |

观战者可以查看公开内容和操作本机相机，不能提交参赛动作；房主即使是观战者，也继续运行权威逻辑。`get_players()` 的参赛者身份与本机/连接状态共同决定操作权，不能把“房主”等同于“本机参赛者”。私有身份、手牌等不进入广播。可复用的加载页、结算页、音频、光标、相机与随机池均来自协议，不引用空白模板。加载/结算在小游戏里保存继承场景，通过导出节点引用连接入口；运行时只配置/显示，不重新创建。固定布局与行模板可直接编辑，编辑器示例不进入真实状态。具体步骤见[协议场景接入](../../games/protocols/godot_party_default_protocol/doc/README.md#加载与结算场景)。共享协议场景按适用性组合：`ranked_round`、`round_pages` 和准备/结算 gate 各有用途，不作为所有游戏必须采用的继承层。

## 偏好与音频

配置默认值与 UI 声明集中在 `settings.gd`。未修改的字段保留继承，只有明确 Apply 才持久化草稿，明确恢复继承才 clear。`effective_changed` 仅刷新受影响且没有未保存草稿的控件；不要因一次配置通知覆盖用户正在编辑的其它字段。逐字段保存时考虑通知会同步触发：保留尚未写入的草稿，失败后停止后续依赖步骤并向入口报告。

原版音频组件保存在游戏场景中，入口公开 `godot_party_audio_target()`。`party_setup` 调用其 `prepare_scope()`，由协议绑定作用域总线；F6 使用预览总线。Cue 通过 `@export` 注入，音乐、音效、环境音、预录配音与 UI 分类播放；音量、句柄、中断、循环、淡切和队列调用见 [音频组件](../../games/protocols/godot_party_default_protocol/doc/audio.md)。菜单输入遮挡不自动暂停音乐，配音也不是玩家语音聊天。需要精确节拍时仍由玩法的音频时钟驱动判定，通用音效池不能代替谱面时钟。

## 复制、验证与交付

复制空白包时先阅读其 [README](../../games/minigame/gp_blank/README.md)。改 manifest 的 ID、名称、版本与真实协议声明，再替换 DemoHub；内部代码与场景引用使用相对路径。协议资源属于声明的外部依赖，不能把其 UID 或路径重写成新包自身。

复制不是移动：新包不能沿用原包脚本 `.uid`、场景/资源自身 UID、内部 `ext_resource` UID 或导入资源 UID。让 Godot 为复制内容生成独立标识，同时保留所需导入参数；不要修改原包或协议资源的 UID。检查引用解析到新包或显式依赖，搜索原包 ID 和绝对路径，检查 manifest、翻译、导入资源和代码加载入口。移动原包内文件时则保留 UID 并更新路径。

仅根据变化选择验证：文档做文本检查；逻辑做相关行为检查；场景从 F6 和正式入口验证编辑值保留；UI 只使用 1920×1080 的 Godot 直接渲染检查。生命周期、跨轮、权限或消息发生改变时才选相应主客机测试。所有测试源码、场景、日志与截图放根目录 `tmp/test/`，不能成为正式运行依赖。分别记录自动化、视觉、人工体验及外网验证的实际范围。

发布时只提交当前包与直接相关文档。属于登记子模块时先提交推送子模块，再更新主仓库引用；保留其它小游戏工作区。复制接入或发布的新包另按 [源码/PCK 交付](source_packages.md) 验证无作者缓存环境，不能把当前开发环境通过视为已验证导出交付。


## 原版资源开发与发布目录

原版协议、主游戏、小游戏及框架使用所属根目录下的 `authoring/` 保存不发布的开发素材。默认导出规则排除各层 `authoring/`；包根 `export_ignore.txt` 可完整替代默认规则，作者须保留本包需要的排除项。详见 [外部资源与作者导出规则](external_resources.md)。不放置 `.gdignore` 隐藏开发目录：Godot 文件系统正常显示、导入，开发场景可直接打开并 F6 运行。目录仍由各内容包自己的仓库管理，可按 `audio/`、`images/`、`models/`、`references/`、`tools/` 分类保存候选素材、未采用版本、分层工程、创作母版、离线生成脚本和下载原档。正式脚本、场景和资源继续放在现有功能目录及 `assets/`，不要求整体搬迁。

- 同一逻辑图片或音效只维护一个正式导入路径。PSD/KRA/Blend、高清母版、未经裁剪或未混音版本，以及只用于预览的 PNG、WAV、MP3 放入 `authoring/`；正式使用的 PNG/SVG、WAV/OGG、GLB 保留在运行目录。不能按扩展名一概删除 PNG、WAV 或 SVG。
- 音效只保留实际使用的最终音频作为运行输入，不同时导入同一内容的母版和多种备用转码。图片只保留实际使用的成品；图集与单图若并存，须分别有明确运行用途。共享素材由所属协议或显式依赖包提供，不复制到每个小游戏。
- 保留并提交正式资源的 `.import` 设置和 `.uid`，移动资源保留身份并更新引用；不通过删 `.import` 重置导入，不提交 `.godot/` 缓存。正式场景、脚本和清单不得引用 `authoring/`。
- `core/ui/source/` 是现有运行时 UI 实现，不能仅凭 source 目录名将其当作创作素材排除。
- 正式原样运行数据固定放在包内 `external/`，由工具自动收集；个人可编辑数据放到 `config/` 或存档目录；它属于交付内容，不放进 `authoring/`。构建副本中的外置目录禁止自动导入，外置图片/音频不再同时作为普通资源打包。
- 玩家 `config/`、测试 `tmp/test/`、受限素材 `third_party_assets/` 和未解决来源的 `private_assets/` 继续遵守各自边界，不迁入 `authoring/`。发布所需许可证和署名必须随正式素材保留，不能只留在被忽略的目录中。

发布检查区分三个问题：开发素材是否进入构建目录、同一资源是否被重复收集、PCK 是否同时保留了已转换的原文件和导入产物。以路径清单、导入日志、导入参数和实际资源加载验证，不做文件哈希校验。共享包中的桌面/移动纹理变体是不同运行需求，不作为重复资源删除。核心与内容的独立干净工程仍各自需要导入，本规则不宣称跨工程零导入。

公共 UI 和代码可进入 `games/assets/<id>/` 资产包，使用方声明精确依赖后直接引用资源路径；资产包只引用自身和框架，不引用其他内容包。六字段声明及安装规则见 [资产包](source_packages.md#资产包)。原版 UI 已从原版协议提取至 `godot_party_default_ui`。
