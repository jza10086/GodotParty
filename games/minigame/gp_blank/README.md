# GodotPartyDefault · 空白小游戏模板

API 5 / manifest 2 / 配置 Schema 3；1–8 人；只实现原版协议 standard 普通局。
本包是「全幅画面＋简要叠加 HUD」和小游戏接入的参考。每位在线参赛者按一次「结束游戏」，房主按首次收到有效点击的先后排名；全部在线参赛者按完才展示成绩，退出者不排名。第一名得在线完成人数对应的分数，之后逐名减一。结束点击与排名仍遵循原版协议约定；随机池只决定本局初始展示。

## 目录与职责

```text
game.tscn / game.gd         正式入口：阶段、准备、结果、网络、提交
adapter.gd                 standard 请求检查与结果映射
settings.gd / manifest.json 配置声明、包信息与依赖
i18n/                      中英文翻译与命名占位模板
ui/                        继承协议的准备页、结算页，以及固定 CanvasLayer
examples/
  demo_hub.tscn / .gd       组合演示、HUD、本机切换和输入门控
  graphics/                展台、建筑陈列、协议相机的配置与调用
  navigation_2d/           航道、船、航标与二维 HUD
  audio/                   音频测试面板、七个 Cue 与 samples/
assets/kenney_city/         三个 Kenney City Kit 模型包及许可
```

入口持有 DemoHub 和固定的协议页面场景。`ui/briefing.tscn` / `ui/settlement.tscn` 继承协议场景，编辑 `View` 子节点即可调整布局；`ui/round_pages.tscn` 以 CanvasLayer 32 组合它们，初始隐藏，由入口显式激活。DemoHub 用 `finish_requested` 报告意图，用 `failed(error)` 报告配置写入失败；入口负责网络发送及 `api.fail()`。演示组件只接收所需的翻译、偏好、音频节点与输入 Callable，不直接依赖 PartyAPI。未提供 API 的 F6 预览隐藏结束按钮，不产生比赛或持久化设置。

完整标准见 [小游戏接入规范](../../../doc/api/authoring.md)，包括场景化、计算模型、权限、配置草稿、复制、验证与发布。本包的文件划分用于说明实际职责，不要求所有小游戏拥有同样的目录数量或相同的协议控制器。

公共组件和页面生命周期见[协议场景接入](../../protocols/godot_party_default_protocol/doc/README.md#加载与结算场景)。其他游戏依赖协议，不依赖本模板；演示内容与示例音频仍留在本包。Esc 菜单由框架拥有，游戏不复制或重新绑定 Esc。

## 开发与预览入口

正式验证使用主菜单和真实大厅。在「小游戏轮换」里单选「空白小游戏」，总局数设为 1，即可检查准备、按钮名次与结算；其他主游戏若声明小游戏白名单，需要包含本包 ID。

打开 `game.tscn` 按 F6，使用内存随机池选定初始 3D 展台或 2D 航道；右上角可切换 2D 航道和音频测试。也可以 F6 运行 `examples/demo_hub.tscn`、`examples/graphics/graphics_lab.tscn` 或 `examples/navigation_2d/navigation_2d.tscn`。音频面板是需要注入 GameAudio 的组件，通过 DemoHub 预览。视觉检查统一为 1920×1080。

固定模型、2D 图形、相机、灯光、碰撞体和 HUD 都直接保存在场景中。打开子场景即可编辑位置、材质、灯光和文字示例；运行时只更新运动、当前状态和确实依赖对局的数据。3D 直接使用主视口，没有 SubViewportContainer。HUD 使用 CanvasLayer，框架菜单之下的演示层为 -4 至 -2，协议页面为 -1。

## 3D 展台与相机

`examples/graphics/building_display.tscn` 保留 Commercial 41 件、Industrial 37 件、Suburban 40 件，共 118 个 GLB 实例，按原排列展示。材质展台保留金属/非金属粗糙度球、透明球、旋转样品、发光块、阴影块、台阶、细杆和背景墙。拾取碰撞体已保存为场景节点，运行时不再遍历创建。编辑模型实例的位置时碰撞体随父节点移动；替换模型几何时同时更新对应 Shape。

滚轮围绕画面中心缩放；中键拖动调整方位和俯仰；Shift＋中键沿地面平移。开始旋转或缩放时，以中心射线命中的表面为支点；射线落空保留原支点。移动物体会带着支点移动。

将协议公开的 `camera/orbit_camera.gd` 挂到活动 Camera3D，在 `_unhandled_input` 中转发 `handle_input(event)`，返回 true 时消费事件。`input_allowed` 指定阶段与菜单门控。可选的 `initial_focus` 引用一个 Marker3D，只初始化支点，不重摆相机；初始构图直接在编辑器移动 Camera3D。需要程序切换构图时调用 `set_orbit(中心, 距离, 方位角, 俯角)`；调用 `focus_on(unit, local_anchor)` 跟随单位。`focus_mask` 对应场景物理层。透视缩放改变距离，正交缩放改变视野尺寸。

美术参数直接编辑原生节点：World 的 Environment；Camera 的投影、FOV、裁剪与 Camera Attributes；Sun/Omni/Spot 的颜色、能量、方向和阴影参数；Samples 下模型的材质与初始姿态。不会再由根节点镜像字段覆盖这些编辑。

GraphicsLab 根节点的 **F6 Preview Rendering** 保留 MSAA、TAA、屏幕抗锯齿、升频、渲染比例、锐化、去色带、各向异性、mipmap 偏移、LOD、调试视图与局部阴影图参数，仅供 F6 实验，出树后恢复视口。正式对局通过入口 `godot_party_graphics_targets()` 将 World/Sun 登记给协议画质；正式设置不会与预览字段竞争。Animate Sample/Rotation Speed 仅控制演示样品运动。各效果受渲染器支持限制；FSR2 自带时间抗锯齿，基础几何没有导入 LOD。

## 2D 与 HUD

`examples/navigation_2d/navigation_2d.tscn` 预置航道、小船、三个航标和 HUD，点击「前往下一航标」移动小船。场景保留可读示例 `航标  1 / 3`，翻译资源中的 `game.beacon_status` 使用 `{current}`、`{total}`；脚本更新同一 Label。F6 与正式模式使用同一份默认语言模板，英文模式由 `api.i18n` 提供。技术样品上的英文标签保留。

场景节点名与显示文字不承担业务分发。音频按钮通过明确的 Button→Callable 绑定执行操作，静态字幕通过明确的节点→翻译键绑定更新。编辑器示例不会进入真实成绩。

## 正式生命周期与输入

`party_setup` 入树前接收 API 和当前协议请求，配置 DemoHub，并为 GameAudio 标记正式作用域。初始化完成后入口显式检查 `mark_ready()`；`party_start()` 通知准备页技术屏障已通过，等 `play_requested` 后进入 RUNNING。

参赛者在准备页按 Enter/空格确认，全部确认后默认三秒开始；观战者不需要确认。每人只能提交一次有效结束点击。房主冻结候选并广播，客户端检查会话/作用域/协议结果后挂载结算页；所有在线端装好页面后默认三秒结束，只有房主在 continued 时调用一次 finish。父游戏负责最终提交和奖励。

框架 Esc 菜单通过 `api.input.input_blocked` 遮挡输入；本地音频面板另行阻止相机、航标、视图切换和结束动作。两者都不暂停联网和房主协调。进入结算时只停止本地演示运动与音频、隐藏演示 HUD/指针，协议结算页继续工作。`party_stop` 清理页面、消息和音频作用域，不停用整棵游戏树来代替清理。

通过协议公开资源 `player_cursors` 挂载共享鼠标层，manifest 声明 `cursors` 有序实例流。正式开局显示彩色指针，个人点击结束后仍显示至全员完成；准备、结算及停止时隐藏。协议本机设置“显示其他玩家鼠标”控制远端指针；不影响按钮点击、身份校验与名次。

## 本机设置样例

大厅 → 小游戏池 → 高亮“空白小游戏” → 本机设置，可测试开关、整数/小数、单行/多行文字、下拉、多选、区间/三分量、RGBA/不透明颜色、文件/目录、主键/备用键/组合键/鼠标/空绑定/只读 Esc、条件启用与三级折叠。所有声明集中于 settings.gd。

这些字段仅演示表单、校验和保存，不实际控制窗口、音量或玩法，也不进入房主规则或联网结果。协议公共偏好可以继承或覆盖；取消不保存。复制为实际游戏时移除未消费的示例字段，只保留实际设置。本包名称、简介、设置、HUD 和按钮提供中英文，语言由框架主菜单手动选择，协议公共页面使用协议翻译。

## 通用音频示例

DemoHub 内预置协议 `audio/game_audio.tscn` 和 `examples/audio/audio_panel.tscn`。面板支持两段 BGM 淡切、循环环境音、音效连发、配音中断/排队/跳过、分类音量与独立音频暂停。七个 Cue 在 `examples/audio/*.tres`，音轨在 `examples/audio/samples/`。配音是预录中文示例，英文界面显示英文字幕，与玩家语音聊天无关。

F6 调整音量立即生效，仅当前预览有效。正式模式维护草稿，点“应用本游戏音量”只保存修改过的分类，未修改分类仍继承协议。无关配置通知不覆盖草稿；外部修改只刷新未编辑分类。“恢复继承”明确清除六个分类的游戏覆盖。面板收起后不持续刷新播放状态文字。

移植只需要 GameAudio 与实际 Cue，不必复制测试面板。准备作用域、播放、停止、循环、切换、配音队列与句柄示例见 [音频组件](../../protocols/godot_party_default_protocol/doc/audio.md)。

## 通用随机统计模板

协议的 `random/least_played_pool.gd` 从记忆拼图的统计机制整理而来。通过已声明的协议依赖直接引用，供地图、题库、图片等随机内容使用；不再从空白模板复制实现。它不依赖 PartyAPI 或模板资源，内容 ID、网络权限和存储路径由游戏负责。

- `new(content_ids)` 指定非空且不重复的稳定内容 ID，每局建立新实例。
- `open_file(absolute_path)` 显式启用持久化，仅正式入口调用。路径通过 `api.input.storage_directory()` 和当前 `api.package_id` 组成。未调用时只维护内存计数，F6 不接触正式文件。
- `choose(rng)` 只从本机累计次数最少的内容中随机选择；同次数时等概率抽取。主机使用 `api.get_seed()` 初始化并持续使用本局 RNG，客机不自行抽取。
- `history()` 返回本局完整抽取序列的副本；主机在每个内容真正开始时追加选择，再调用 `accept_history(sequence)` 成功记账后广播序列。选择本身不计数，开始后取消也不扣回。
- 主机、客机和观战端各自在收到主机序列后调用 `accept_history()`。相同或更短的匹配序列不重复记账；跳过中间快照时补记未见后缀；已见前缀冲突或未知 ID 返回错误。网络入口仍负责校验发送者、会话、作用域、阶段与长度上限。
- `counts()` 返回本端历史的副本。网络只发送选取序列，不发送或覆盖各端累计次数；不同设备保留不同历史，以后成为主机时用自己的次数选取。

最小主机流程（每局只初始化一次 `pool` 与 `rng`）：

```gdscript
const RandomPool: GDScript = preload("res://games/protocols/godot_party_default_protocol/random/least_played_pool.gd")
const CONTENT_IDS: Array[String] = ["map_a", "map_b", "map_c"]
var pool: RandomPool = RandomPool.new(CONTENT_IDS)
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# 正式入口在初始化时检查 pool.open_file(...) 的 Error，再准备开局。
# F6 跳过 open_file()，正式主机 rng.seed = api.get_seed()。
func choose_next() -> Error:
	var draws: Array[String] = pool.history()
	draws.append(pool.choose(rng))
	var error: Error = pool.accept_history(draws)
	if error != OK:
		return error
	return api.net.broadcast(&"game/draw", {
		"session": api.session_id, "scope": api.scope_id, "draws": draws})
```

`game.gd` 是完整联网接入样例：每局准备结束后主机在 `graphics` 和 `navigation_2d` 中选一个初始展示，客户端可以在本端准备页结束前接收并记账，进入运行阶段后再应用。所有端选取一致，原结束按钮排名不变。个人手动切换视图不会新增游玩次数。DemoHub 的 F6 使用同一个组件但不打开文件。

正式统计文件为安装资料根目录的 `minigame/<package_id>/config/random_pool_stats.json`，格式为 `{"version": 1, "plays": {"graphics": 0, "navigation_2d": 0}}`。首次读取不存在的文件不会创建它，首次接受新选择才落盘。完整文件先写入 `.pending` 再替换，写入成功后才更新内存计数与已见序列。损坏、版本错误、内容 ID 集合不符和读写失败会向入口返回 Error 并结束本局，不自动清零。修改内容 ID 集合时须明确安排存档处理，组件不自动迁移；同一安装资料的文件由一个进程写入，多实例测试使用独立 `--party-profile`。

去重只针对一个活动实例内的重复/乱序快照。重新进入新局会新建序列，并在既有累计次数上继续计数；没有增加重连、崩溃恢复或跨设备历史合并协议。现有记忆拼图继续使用自己的图片实现，不产生对空白模板的运行时依赖。

## 复制为新游戏

1. 复制包，修改 manifest 的 id、name、introduction、package_version 与真实兼容声明；保留当前 API/manifest/schema 格式。
2. 这是新资源身份：清除复制品的脚本 .uid、自身场景/资源 UID、内部 ext_resource UID 及导入 UID，让编辑器分配新标识并重新导入；保留所需导入参数。不要修改原包或所依赖协议资源的 UID。包内相对路径可以直接跟随目录；协议绝对路径是明确依赖。
3. 在 game.tscn 替换 DemoHub 为实际玩法场景，同步入口的依赖、信号和画质/音频挂点；不要保留指向已删除演示的加载路径。不需要演示时可在新包移除 examples 和专用模型，但不能修改原模板。
4. 实现实际计算模型、结束条件与协议结果，只声明已实现的协议/模式。观战房主仍承担协调，私有数据按接收权限发送；本地视图切换不写入规则快照。
5. 检查 manifest、脚本、场景、翻译和导入引用；在 F6 与真实大厅验证场景编辑值、准备、输入遮挡、结算和停止。测试文件/输出只放根目录 tmp/test/。按改动选择联机检查，再提交、推送受影响包及主仓库引用。

所有参赛者准备后倒计时三秒开局。每人点击一次「结束游戏」，按房主收到点击的先后排名。所有在线参赛者按完后显示本轮结算，退出者不排名。 大厅“本机设置”提供控件、协议继承/覆盖与保存测试；样例值不改变玩法。
