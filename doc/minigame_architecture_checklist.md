# 小游戏架构与编码风格改造清单

审查日期：2026-11-07。基准为空白模板提交 `57a49c3`、[标准接入规范](api/authoring.md)和当前工作区源码。覆盖空白模板之外的 **25 个包：22 个可玩包、2 个可运行但未开放的原型包、1 个纯占位包**。这是供后续会话执行的静态审查清单；本轮没有改动游戏、运行游戏或重新做联机/视觉验收。[场景与 HUD 清单](minigame_scene_inventory.md)中的历史运行记录保留，但不能代替本次改造后的验证。

主要差距集中在共享回合的停止方式、单人正式接入的输入/画质/配置、旧音频与偏好来源，以及少量仍在运行时构建的固定外观。多数游戏已有可编辑场景，不需要重做全部场景化，也不需要全部继承空白模板的控制器。

## 执行约定

- **A：先处理接入契约或行为风险。** 例如旧设置来源、输入绕过作用域、预览写正式数据、关键发送结果被忽略。表示源码确认存在差距，不表示本轮已经复现运行故障。
- **B：完成标准化。** 场景编辑值、静态外观、音频归属、明确依赖、语言模板和职责整理。
- **C：低优先级整理或保留。** 不以改目录、减少行数、消除所有重复为目标；没有具体收益的文件保持现状。
- 文中路径均相对各包目录；点击文件链接可定位源码。函数名是执行定位点，后续行号变化时以函数为准。所有任务初始均为“待实施”，不要将检查清单当成已修复记录。
- 每个会话先核对该包的当前代码和 Git 状态。审查时 3D 国际象棋有未跟踪的 `.import`，海战棋有已修改的 `ocean_fields.png.import`，均属于已有工作，不得顺带覆盖或提交。
- 不改变玩法、参赛人数、判定权威方、消息字段、保存格式、公开/私有权限或未开放状态。确实需要改变公开接口时另列明确变更，同步调用方和规范。
- 只补已声明语言；除空白模板外，当前只有合成大西八声明中英双语。中文包不因本清单被要求补英文。动态文字使用稳定键和命名占位，F6 共用包内默认 Translation。
- 不给没有声音的游戏强加 BGM、音效或空的 GameAudio。已有普通音频迁入作用域组件；玩家语音和精确节奏播放按各自语义保留。

## 共享依赖先单独处理

以下任务属于协议包，不能由多个小游戏会话各自修改。单包会话默认只读取共享文件；需要共享修改时先完成对应 G 任务，再迁移调用方。

### G01 原版回合页面与排名基类　A

证据：[round_pages.gd](../games/protocols/godot_party_default_protocol/round_pages.gd) 的 `prepare()`、`_show_result()` 递归收集/隐藏所有 CanvasLayer，并把整个游戏根设置为 `PROCESS_MODE_DISABLED`；[ranked_round.gd](../games/protocols/godot_party_default_protocol/ranked_round.gd) 的 `send_action()`、`publish()` 没有处理网络返回 Error，`party_stop()` 只切换 running/process 标志。

- [ ] 将准备/结算展示与游戏运行状态分开：页面只管理自己的节点；调用方显式停止玩法输入、模拟、音频和相关 HUD。保留适用的页面组件，不要求所有游戏改成同一种继承方式。
- [ ] 同步现有所有调用方后移除旧的整树禁用行为，避免迁一半时出现准备阶段提前模拟或结算遮挡失效。共享接口变化必须一次明确登记，不能长期并存新旧别名。
- [ ] 对关键动作与快照发送处理 Error；停止后不继续运行依赖发送成功的逻辑。明确 transient 状态流和最终结果的失败语义，不增加自动重试。
- [ ] 停止时解除本类建立的连接并清理页面，支持中途取消和重复停止。不要靠节点稍后被释放来表达生命周期契约。
- [ ] 状态文字、默认成绩列等固定文案使用协议翻译资源；保留现有 `standing_row.tscn` 复用方式。

直接使用排名基类：桌球、连连看、贪吃蛇、星潮、竞拍大师、合成大西八。其他 round_pages 使用方包括 3D 国际象棋、记忆拼图、阿瓦隆、水果武士、云间跃行、心理博弈、蛇蛇大作战、雷霆战争、霓虹节拍及 solo_round。海战棋、炮火争锋直接组合 gate，不能被误纳入同一入口迁移。

验证：选一个排名类、一个自有控制器、一个带持续音频的调用方覆盖准备→运行→结算→取消；涉及公共行为变化时补受影响双端和跨轮检查。客户端、观战房主都必须继续处理协调消息；输入阻止不等于游戏计时暂停。

### G02 单人正式接入边界　A

原审查证据：[solo_round.gd](../games/protocols/godot_party_default_protocol/solo_round.gd) 在 `_play()` 中才实例化玩法，未向玩法注入输入/偏好/画质接入，也没有 `godot_party_graphics_targets()`；其五个调用方是方向密码、山脊竞速、海岸飞行、极速追逐、圆角俄罗斯方块。多个玩法通过 `get_parent() is SoloRound` 只取翻译，输入仍由自己的全局 InputMap 或物理按键控制。

- [x] 为这些调用方确定一个小而明确的接入约定，直接注入需要的 PartyInput、翻译、偏好和开始/停止控制；可以使用包内入口，不新建通用插件注册框架。
- [x] 初始化、技术 ready、真正开始与停止分别可定位。处理玩法实例化时机和协议画质/音频 attach 时机，不能只在子场景增加 hook、却让框架仍只看到不转发的 SoloRound。
- [x] 正式模式使用已声明动作与 `api.input`；F6 输入走清楚隔离的预览边界。固定依赖不再通过父节点类型猜测。
- [x] 三维调用方登记实际 World/Sun；把画质交给协议。接入正式 Esc 菜单及 `party_minimal_hud` 时同步处理原暂停菜单，避免双重响应。
- [x] 保留当前单参赛者语义：观战端不运行该玩家的模拟，观战房主仍负责收结果。不要为了统一外观顺带新增多人玩法。

实施记录（2026-11-07）：G02 及五个调用方已统一迁移。SoloRound 直接组合准备/结算 gate；输入由 PartyInput 与包内 schema 提供，协议作用域负责画质/音量。无本机模拟的观战端允许空画质/音频目标。五包定向检查、真实大厅连续五局、本机 ENet 双进程六局（含极速追逐重复轮）及运行中取消通过；重复完成只上报一次，无遗留 InputMap 或音频总线。1920×1080 五包预览通过；未进行跨机器联机和真人操作/听感验收。G01 以及其余包的 G03 迁移仍待完成。

验证：一个本机参赛者和一个观战房主，确认唯一成绩提交、退出取消、连续两轮无重复 InputMap 事件；再按各游戏操作特点验证门控。没有运行模拟的观战端不要求凭空出现本机玩法画面。

### G03 音频接入边界　B，霓虹节拍单独安排

参考 [音频组件文档](../games/protocols/godot_party_default_protocol/doc/audio.md)。普通音频主要分布在贪吃蛇、星潮、水果武士、云间跃行、山脊竞速、海岸飞行、极速追逐、雷霆战争；原型还包括铁鹰、海战棋旧原型和火炮旧原型。

- [ ] 普通声音保存 Cue 与固定播放器场景，通过入口公开目标、setup 准备作用域、停止时回收；保留原声音、循环、音高和播放节奏。
- [ ] 不复制空白模板的测试面板到正式游戏。已有 sound/muted 偏好与协议音量的组合规则必须写清，不能建立两套互相覆盖的音量来源。
- [ ] 霓虹节拍保留自己的播放时钟、按键时间采样、长按音和校准；只统一配置与作用域音量/资源生命周期。若公共接口不足以承载专用播放器，先单独设计公开接入点，再迁移；不能访问协议 `_audio_mixer` 等私有状态。
- [ ] 心理博弈的麦克风与搭档语音继续使用 PartyVoice，不能替换成 GameAudio 的预录配音队列。

## 逐包任务

### M01 方向密码　A　依赖 G02

包：`direction_password`。定位：[direction_password.gd](../games/minigame/direction_password/direction_password.gd) 的 `_ready()`、`_unhandled_key_input()`、`activate_primary()`、`enter_direction()`。

- [x] 从父节点探测改为显式注入；正式方向、撤销、确认动作使用 PartyInput，按钮和键盘共用阶段/菜单门控。当前只有本地键码匹配，没有正式输入上下文。
- [ ] 保留两排八个答案槽和六行成绩，补齐仍散落的阶段/反馈文字模板；预览继续使用已有 DEFAULT_TEXT。
- [ ] 规则、六轮流程和计分留在现有 `direction_password_rules.gd`/玩法中，不为了 312 行脚本再拆控制器。

验证：六轮、撤销/超时、菜单遮挡和唯一提交；改输入后检查自定义绑定。无需重建静态题面。

### M02 山脊竞速　A　依赖 G02、G03

包：`godot_party_default_car_racing`。定位：[scripts/main.gd](../games/minigame/godot_party_default_car_racing/scripts/main.gd) 的 `_setup_inputs()`；[scripts/arcade_car.gd](../games/minigame/godot_party_default_car_racing/scripts/arcade_car.gd) 的 `_ready()`、`_physics_process()`；`scenes/car.tscn`。

- [x] 用正式输入注入替换运行时添加/删除全局动作，保留 F6 独立操作；处理原 Esc 暂停和框架菜单，菜单打开时车辆不能继续采纳驾驶输入。
- [ ] 四个车轮 pivot 目前仍在 `_ready()` 查名、创建并 reparent；保存到车辆子场景并显式引用。固定发动机播放器入场景/音频组件。
- [ ] 清理本包业务代码中的 `:=` 和未声明类型；场景专用类型只在确有共享需求时保留全局 `class_name`。
- [ ] 港区场景和赛道 Curve3D 保留。`harbor_scenery.gd` 的生成器当前未发现正式场景引用，先确认作者工具用途再归档/删除，不能把它误报为当前重复生成。道路网格根据曲线生成继续保留。

验证：四轮转向/滚动、漂移和氮气、赛道曲线编辑、三圈成绩、退出后无遗留输入/发动机声。

### M03 海岸飞行　A　依赖 G02、G03

包：`godot_party_default_flight`。定位：[scripts/main.gd](../games/minigame/godot_party_default_flight/scripts/main.gd) 的 `_bind_inputs()`、`_make_audio()`、`_physics_process()`、`_capture_mouse()`、`_set_paused()`。

- [x] 分离正式输入与 F6 输入，覆盖轴轮询、鼠标捕获、失焦、菜单及释放后重新允许输入的流程；保持已有键鼠混合控制优先级。
- [x] 螺旋桨循环通过 Cue/作用域音频管理；当前直接修改 load 得到的共享 AudioStreamWAV 的循环参数，改为资源配置或修改前复制。
- [ ] 清晰划分飞行模拟、场景协调和 HUD；优先保留已经独立的 `flight_model.gd`、`mouse_flight_input.gd`，不重复建立控制器层。
- [ ] 补正式画质挂点、显式类型及导航/状态文字模板；机场、飞机和航标继续使用现有场景。

验证：捕获/释放鼠标、Esc、失焦、航标穿越、着陆/坠机唯一结果、循环音退出清理。

### M04 极速追逐　A　依赖 G02、G03

包：`godot_party_default_lighthouse_isles`，原清单称灯塔群岛。定位：[scripts/main.gd](../games/minigame/godot_party_default_lighthouse_isles/scripts/main.gd) 的 `_setup_inputs()`、`_course_forward()`、`_build_sounds()`、`_play_sound()`；`scripts/player.gd`。

- [x] 正式移动、跳跃、地图、重试和暂停统一走输入上下文；保留检查点/坠落规则。
- [x] 将已确定的 course 依赖声明成具体脚本类型，直接调用 `camera_forward_at()`，移除相应 `has_method` 猜测与静默备用方向。
- [x] 固定合成声音导出为资源，普通播放使用作用域池；不再每次 `_play_sound()` 创建播放器。
- [x] 统一显式类型；相机可调参数放 Inspector，固定关卡和移动平台初始位置保持已有场景。

实施记录（2026-11-07）：M04 四项已落地，五个固定音效为 Cue 资源；相机编辑值、顺序存档/重试、四个平台运动、总览切换、输入改键/屏蔽及唯一完成/退出已做定向运行检查。1920×1080 画面已查看；未重跑正常输入全路线通关，原型历史通关记录不作为本次验收。

验证：跳跃/检查点/重试、四个平台运动、总览切换、菜单输入屏蔽、通关与退出。

### M05 圆角俄罗斯方块　A　依赖 G02

包：`godot_party_default_russian_block`。定位：[scripts/main.gd](../games/minigame/godot_party_default_russian_block/scripts/main.gd)、[scripts/party.gd](../games/minigame/godot_party_default_russian_block/scripts/party.gd)、`scripts/battle_session.gd`。

- [x] 正式经典模式的横移、软降、硬降、旋转、暂存全部改为声明动作；连续物理键轮询也必须遵守输入门控，不能只改事件回调。
- [ ] 经典玩法、独立多盘演示和正式 Party 接入明确分开；保留现有多盘预览，不把同屏演示自动宣布为已接入的在线多人模式。
- [ ] 补齐 `:=`/未类型变量；固定方块外观、幽灵材质做资源或可编辑子场景，数量和格位仍按实时棋盘数据实例化。已有 2D 预览槽、棋盘和主视口渲染保留。
- [ ] `party.gd.capture()` 当前写包内 `screenshots/`。验收截图移至根 `tmp/test/`，测试专用入口与正式业务分开；若保留用户截图功能，应另定义用户输出契约。

验证：按键连发、菜单关闭后不补发旧输入、暂存/下一块、两种多盘模式往返、选盘与状态隔离、正式成绩。

### M06 霓虹节拍　A　依赖 G01，专用音频按 G03

包：`gp_rhythm_game`。定位：[rhythm_backend.gd](../games/minigame/gp_rhythm_game/rhythm_backend.gd) 的 `preview_settings_path()`、DEFAULTS、`_load_settings()`、`_save_settings()`；[music_game.gd](../games/minigame/gp_rhythm_game/music_game.gd) 的 `_ready()`；`party_round.gd`。

- [x] 正式偏好从旧 `user://party/prototypes/rhythm_1k.json` 与私有 `core/config/party_json_config.gd` 迁到包声明和 PartyConfig；同步正式调用方。F6/作者工具的设置边界明确，不能让演奏场景悄悄读写旧用户文件。
- [x] 固定 Track、TapPreview、四声道反馈与确定数量的播放器池保存为场景。保留现有节奏时钟、延迟校准、键源释放与长按子判定，不强行改为通用播放句柄驱动判分。
- [x] 正式层不要直接改 `backend._key_sources` 或读 `_best_combo`；提供有实际语义的释放输入/成绩读取方法。停止时覆盖播放、process_frame 连接和正式网络连接。
- [x] 排名、完成、等待与观战文字统一模板。作者工具放作者功能目录，保留谱面编辑器 SubViewport 和校准试听；`calibration_test` 是用户可用校准功能，不能仅因文件名带 test 就删除或移动到不可发行的临时目录。

本包 M06 代码改造已落地：正式使用 `settings.gd` / PartyConfig，作者设置独立保存，固定播放器见 `ui/playback_audio.tscn`。共享 G01、G03 未在本包会话中修改，仍待统一处理。已通过定向运行检查：声明/翻译、PartyConfig 注入、JSON 按键、固定播放器、输入释放、重复停止清理与原生预览初始化；未重跑跨进程联机与真机听感验收。

验证：真实音频设备上的短音/长按/校准、菜单与失焦释放、试听结束清理；两端准备至结算以及观战房主。音频时间精度需要人工听感/操作验收。

### M07 水果武士　A/B　依赖 G01、G03

包：`godot_party_default_fruit_samurai`。定位：[game.gd](../games/minigame/godot_party_default_fruit_samurai/game.gd)、[scripts/main.gd](../games/minigame/godot_party_default_fruit_samurai/scripts/main.gd)、[scripts/hud_skin.gd](../games/minigame/godot_party_default_fruit_samurai/scripts/hud_skin.gd)。

- [x] 入口复制了云间跃行的 IS_PLATFORM 常量分支，删去本包永远不会执行的分支，直接声明 Fruit 玩法依赖；不为去重引入新的通用挑战框架。
- [x] 处理 `_send_progress()`、`_publish()` 的 Error，停止时解除连接并结束切割状态。保持本地灵敏切割、房主有界成绩汇总。
- [x] `_create_decor()` 的四个固定水果、`hud_skin.configure()` 的固定文字/装饰/布局/样式迁成场景或皮肤子场景。运行时抛出的水果、切片和刀光继续动态生成。
- [x] 八声音池接作用域音频；已知类型的 Variant 换为具体类型。HUD 展示用的测试注入与 `--hud-capture` 从正式玩法整理到预览/临时验收入口。

本包 M07 已落地：固定装饰、菜单、四种 HUD 与八声音池已保存为场景，音效使用协议作用域 Cue；保留 1–8 人和现有消息/成绩格式。2026-11-07 使用系统 Godot 4.7.2 完成定向运行检查（输入遮挡、连击、低动态、跨轮重置、音频清理、发送失败与重复停止），查看四种皮肤的 1920×1080 渲染；真实本机 ENet 双端连续两轮的 45/60 分成绩、排名、结算与订阅清理通过。共享 G01 仍待统一迁移，本包未修改协议；真人手感、听感和跨机器联机未验收。

验证：四种现有皮肤和低动态效果、划动输入遮挡、跨轮切割清理、双端成绩和音频停止。

### M08 云间跃行　A/B　依赖 G01、G03

包：`godot_party_default_platformer`。定位：[game.gd](../games/minigame/godot_party_default_platformer/game.gd)、`scripts/world11.gd`、`scripts/world11_player.gd`、`scripts/sound.gd`。

- [ ] 移除水果分支和 IS_PLATFORM 开关，使用明确的 world/player 依赖；处理进度/排名发送返回值并清理连接。
- [ ] 普通声音接作用域组件。保留当前课程场景、出生点和运行时敌人/拾取状态，不重新生成固定地图。
- [ ] 对固定敌人类型的 `has_method("defeat")` 改为明确契约；碰撞得到的可交互对象是实际动态边界，`bump` 判断要按砖块类型/组件契约处理，不能机械删除所有检查。
- [ ] 游戏规则数据、资源外观、HUD 与输入职责沿用现有分离，仅整理不准确的通用 shapes/sound 命名和跨场景长路径。

验证：死亡重载、地下金币、顶砖与敌人、菜单/失焦输入、双端成绩、连玩两轮。

### M09 贪吃蛇　B　依赖 G01、G03

包：`godot_party_default_snake_game`。定位：[game.gd](../games/minigame/godot_party_default_snake_game/game.gd)、[sound_bank.gd](../games/minigame/godot_party_default_snake_game/sound_bank.gd)、`board_view.gd`。

- [ ] 用 Cue 与作用域声音池替换四个动态播放器；将 `_tone()` 中明确的数值/数组/播放器 Variant 改成具体类型。保留现有音色。
- [ ] 速度枚举和必需配置使用已校验的配置，不再把未知值静默变成“标准”；状态与排行榜的中文拼接转为命名模板。
- [ ] 保留 model/view/entry 分层、动态蛇身和食物。当前 `api.input.event_matches()` 自带输入许可检查，不能仅因入口没有手写 `input_blocked` 就认定漏门控。

验证：变向、死亡/胜利声音、菜单后输入恢复、本地进度上报与最终成绩。

### M10 星潮　B　依赖 G01、G03

包：`godot_party_default_star_wave`。定位：[game.gd](../games/minigame/godot_party_default_star_wave/game.gd)、[visual.gd](../games/minigame/godot_party_default_star_wave/visual.gd)、`arena.gd`、`game_core.gd`。

- [ ] `visual._ready()` 中音频播放器/合成音接作用域；把调用 `visual._play()` 改为明确的反馈入口。
- [ ] 保留 host arena、本机展示预测与既有 150ms 上限。改善 `render_game()` 按快照 key 对模型 `set()` 的边界：明确允许字段与接收方法，保留网络载荷校验，不把展示状态散写到任意模型属性。
- [ ] 团队第二个显示面可作为模式场景中的固定实例；敌机、弹幕、曲线尾迹及 RenderingServer 批绘继续动态。1085/813 行本身不是拆分依据，仅按音频、显示反馈和规则的真实边界整理。

验证：个人/团队视图、Boss 收尾、负分与生命 HUD、预测停止、菜单中自动开火停止、作用域音频清理。

### M11 竞拍大师　B　依赖 G01

包：`godot_party_default_auction_master`。定位：[game.gd](../games/minigame/godot_party_default_auction_master/game.gd) 的 `make_snapshot()`、`render_game()`、`_open_catalog()`；`session.gd`、`warehouse_view.gd`。

- [x] 私有快照发送的 Error 不得忽略；为 session 的 locked 状态、warehouse 的揭晓进度提供明确读取/更新入口，避免跨模块访问 `_locked`、`_animation_time`。
- [x] 补齐阶段、报价状态、成交、羁绊等仍直接拼接的文字模板；固定彩虹品质条保存到 `catalog_item.tscn`，按品质显示。
- [x] 保留规则/仓库显示/入口分离。`item_catalog.gd` 主要是静态目录数据，不能因为 1586 行就拆成大量转发模块；若需编辑器配置收益，再转专用 Resource。

验证：封仓不可见、私有鉴定、观战不泄露、平价加时/提前成交和最终金币；不要改变现行五轮规则。

实施记录（2026-11-07）：已完成 M11 包内调整。快照生成不再执行发送，私有或公共快照发送失败立即停止并报告；锁定状态通过复制读取入口提供，揭晓时钟通过公开更新入口同步。动态文案补入简体中文 PO，既有网络文字字段保持原格式；图鉴彩虹条改为固定场景节点，目录与五轮规则保留。既有自动检查及新增发送失败/揭晓时钟用例通过，覆盖单人最终金币、提前成交边界、连续同价加拍、封仓和鉴定隐私；已检查 1920×1080 的封仓、揭晓和图鉴画面。G01 共享页面/动作发送/生命周期仍待独立实施，本次未修改协议基类，未做真人多人或外网验收。

### M12 3D 桌球　B　依赖 G01

包：`godot_party_default_billiards`。定位：[game.gd](../games/minigame/godot_party_default_billiards/game.gd) 的 `_table_input()`、`_tip_input()`、`render_game()`；`pool_table.tscn`。

- [x] 保留 tournament / pool_physics / 场景分离和 30Hz 展示同步；输入与提示标签明确属于视图，网络动作由入口负责。
- [x] 出杆高低/左右塞、进行中/名次等剩余拼接转模板。选桌、回到本人桌与重置击球点明确遵守菜单和本地弹层的操作门控。
- [x] 固定球桌、十球、力度控件已场景化，不再拆掉重建；球位、瞄准线与自由球摆位继续动态。

验证：主相机拾取、自由球摆位、观战切桌、击球点与力度、双端击球至结算。无现有音频，不强制新增音频系统。

实施记录（2026-11-07）：M12 包内改造已提交至 Billiards `d42df0f`。视图操作改为具名回调，统一菜单/选桌弹层门控；观战者可切桌但不能出杆；击球点使用事件本地坐标。杆法、排名及固定操作提示接入中文 PO 模板。保留现有物理、比赛模型、固定场景、30Hz 同步、人数与消息字段，不新增音频。`tmp/test/billiards_physics/architecture_network.gd` 使用正式大厅两端和九号球残局夹具，检查菜单/弹层阻止、观战切桌、返回本人桌、杆法模板、主相机拾取及真实出杆→物理→双方结算；两端退出码为 0，无 SCRIPT ERROR/ERROR。已检查 1920×1080 Godot 直接渲染的详情/杆法界面。自由球鼠标摆位、完整赛事、真人杆法手感和外网仍待人工验收。G01 共享发送错误处理与页面生命周期仍待独立任务，本次未修改协议基类。

### M13 连连看　B　依赖 G01

包：`godot_party_default_matching_game`。定位：[game.gd](../games/minigame/godot_party_default_matching_game/game.gd) 的 `handle_action()`、`_update_controls()`；`board_3d.gd`、`matching_piece.tscn`。

- [x] 私有 hint 发送结果处理失败；提示扣减与失败后的控制流要一致，不默认为发送成功。
- [x] 观战提示等剩余文案改成翻译键；固定交互面、80 个棋子实例和现有 world/sun 挂点保留。
- [x] 动态连线路径和游标继续按实时数据绘制；不要把每次连线当成必须落盘的静态节点。

验证：主相机点选、洗牌后旧选择失效、提示次数与私有提示、两端争用同一对、远端游标和结算。

2026-11-07：本包三项完成，G01 公共依赖仍待单独迁移。MCP 脚本诊断、提示发送失败注入、1920×1080 单人及双端 ENet 自动检查通过：点选、洗牌失效、提示扣减与私密性、游标数据同步、争抢消除和 40 对结算。本轮未重新做视觉及真人联机验收。

### M14 合成大西八　B　依赖 G01

包：`godot_party_default_merge_big_ssibal`。定位：[game.gd](../games/minigame/godot_party_default_merge_big_ssibal/game.gd)、[arena_view.gd](../games/minigame/godot_party_default_merge_big_ssibal/arena_view.gd)。

- [x] 此包已声明中英双语，但 footer、倒计时、排行、下一球和溢出警告仍直接写中文；补稳定键、命名参数及两份翻译。
- [x] 固定箱体外框、下一球标题和进化图例改为场景可编辑控件；不同玩家的箱体外观做子场景。球体、瞄准线和溢出实时状态继续绘制或按需生成。
- [ ] 保留现有 world/view 分离与网络 Error 处理。G01 完成后检查本包重写 send_action/publish 的真实差异，只有语义已一致才合并，不先删掉其正确处理。

验证：两种语言、放球/合并、菜单释放门控、观战者不能放球、独立玩家箱体与结算。

实施记录（2026-11-07，子仓提交 `ad8b834`）：M14 包内双语与场景化两项完成。新增 arena_view.tscn 和复用 bin_view.tscn，保留 Inspector 外框样式；视图接收翻译 Callable，默认预览使用包内中文 Translation。补全包内中英文简介、设置及动态模板；world、玩法、人数、消息字段和现有网络 Error 处理保持不变。G01 尚未实施，send_action/publish 合并及共享页面生命周期迁移继续待办，本次未修改协议。

验证记录：现有规则检查及单人正式大厅→落球→结算→回合保存检查通过；覆盖菜单阻止/恢复、观战身份不发送、两个独立箱体的状态文字、溢出提示及场景样式保留；1920×1080 中英文游戏画面已直接渲染检查。本轮未重跑双端网络，未做真人多人、跨机器网络或手感验收。

### M15 蛇蛇大作战　C/B　依赖 G01

包：`godot_party_default_multi_snake_game`。定位：[game.gd](../games/minigame/godot_party_default_multi_snake_game/game.gd)、`snake_world.gd`、`arena_view.gd`。

- [x] 当前 host 模拟、鉴权/序号、世界与视图分层、信号清理已比较明确，无需重拆架构。
- [x] `_update_hud()` 的排行榜用可编辑玩家行或明确的文本模板，成员变化才增删行，分数/排序变化更新原行；固定字体/Theme 可保存资源并注入。
- [x] 保留动态蛇身、食物、插值、世界网格和随相机变化的小地图绘制。只调整固定 HUD 外框/标签，不将实时几何错误地静态化。

本包 M15 已落地：排行榜保留同一 Label，使用命名参数模板且仅在显示内容变化时更新；计时和结算列补齐中文模板，Theme/字体与 HUD 示例保存在场景。修复了本地全榜 Tab 同时触发框架排名弹窗的冲突，仍遵守作用域输入门控。2026-11-07 使用系统 Godot 4.7.2 复用正式大厅验证入口，单人运行检查覆盖转向、加速、菜单内持续模拟/输入屏蔽、前三/全榜/重新排序、死亡复活与结算，退出码 0、无脚本或运行错误；查看了 1920×1080 画面。共享 G01 未修改，仍待统一迁移；本次未重跑跨轮、跨进程联机或人工手感验收。

验证：转向/加速、菜单打开仍继续房主模拟、重生/保护状态、前三与全榜切换；共享页面变化后再验证跨轮。

### M16 3D 国际象棋　B　依赖 G01

包：`godot_party_default_3d_chess`。定位：[game.gd](../games/minigame/godot_party_default_3d_chess/game.gd)、[chess_view.gd](../games/minigame/godot_party_default_3d_chess/chess_view.gd) 的 `_ready()`、`configure_mode()`、`_update_camera()`、`_rebuild_markers()`。

- [ ] 给视图声明具体脚本类型/可替换引用；必需视图和页面准备完成后的调用按内部契约访问，保留初始化取消时真正需要的判断。
- [ ] 相机初始方位/距离现在由脚本常量和 `_update_camera()` 重设；改为可编辑模式机位/参数，以这些场景值作为 reset 基准，保留运行中 orbit。
- [ ] 合法步点、轮廓和选中标记外观做可编辑资源/子场景，数量和位置按棋局生成；保留两套棋盘、26 种棋子与纯规则实现。
- [ ] 模式介绍、操作说明、结果和状态模板补齐；`_preferences_changed()` 只刷新实际相关偏好。

验证：两种棋盘互切、场景机位编辑生效、升变/和棋/认输、旁观者操作权限和完整双端对局。

### M17 海战棋　B

包：`godot_party_default_battleship_chess`。定位：[party_round.gd](../games/minigame/godot_party_default_battleship_chess/party_round.gd)、[battle_view.gd](../games/minigame/godot_party_default_battleship_chess/battle_view.gd) 的 `_rebuild_ships()`、[ship_display.tscn](../games/minigame/godot_party_default_battleship_chess/ship_display.tscn)。

- [x] 保留独立 gate 组合、逐接收者私有视图和观战房主权威计算；沿用当前共同回合、个人抢选、哑弹及个人分数规则，未修改纯规则文件或消息格式。
- [x] 舰船 holder、名字牌、水线 Plane/ShaderMaterial 保存到 `ship_display.tscn`；导出五组完好/残骸资源，按舰型、舰长、朝向和沉没状态配置。水线资源按场景实例独立，名字牌样式可直接编辑；保留海面、格网、标记及弹着实现。
- [x] 准备操作说明、HUD、规则和结算展示补稳定键与命名占位模板；独立视图使用同一默认 Translation。接收最终视图时先验证协议结果及所需成绩列；结算展示只修改副本。停止清理本包信号、HUD、输入和弹着，延迟结算保留 `_stopped` 检查。
- [x] README 明确 `prototype/` 为由 `.gdignore` 隔离的旧原型，非正式入口；本批未改动旧原型。

2026-11-07 已实施，子模块提交 `57e09c7`。Godot 4.7.2 定向验证：既有三客户端真实大厅联机通过（私有视图、布阵归属、抢选、齐射和结算）；1920×1080 实际渲染/鼠标操作检查通过并查看截图；五组残骸切换、水线实例隔离、名字牌编辑值和默认翻译检查通过。结果边界/生命周期自动检查覆盖非房主消息、无效结果、观战房主无隐藏舰船节点、末轮弹着后结算、延迟期间取消、重复停止及唯一提交，均通过。

检查脚本及输出在 `tmp/test/battleship/`：`preview.gd`、`network.gd`、`architecture_display.gd`、`architecture_lifecycle.gd`。观战房主本批为定向 API/视图检查，尚未做完整观战房主多端人工验收；真人操作手感、跨机器/外网和导出包验收仍待进行。原有 `ocean_fields.png.import` 改动未纳入提交。

### M18 记忆拼图　A/B　依赖 G01

包：`godot_party_default_jigsaw_puzzle`。定位：[scripts/main.gd](../games/minigame/godot_party_default_jigsaw_puzzle/scripts/main.gd) 的 `_ready()`、`start_match()`、`_apply_view()`；[scripts/picture_library.gd](../games/minigame/godot_party_default_jigsaw_puzzle/scripts/picture_library.gd)。

- [x] F6 自动配置 preview 后仍创建 PartyInput 获取正式 storage，随后 `picture_stats.record()` 写正式图片使用次数。预览改用本次内存统计或显式预览存储；正式持久化只由正式入口注入，不能把测试目录变成正式代码依赖。
- [x] 入口已经是清楚的协议边界，保留逻辑动作信号、私有本机输入、host 规则和快照检查，不再叠一层通用管理器。
- [x] `puzzle_state.gd` 等残留 `:=` 改显式类型。相机 zoom 的基准构图改可编辑参数，保留根据本机席位计算的动态聚焦。
- [x] 桌面、中央答案和八席槽位保留；拼片内容与席位归属继续随对局更新。

验证：F6 不改变正式统计，正式三轮计数仍准确；交换、旋转、断线、观战房主和最终结算。

实施记录（2026-11-07，子仓提交 `e595c01`）：包内四项已完成。F6 使用内存统计，正式入口显式打开并注入持久化统计；保持原协议边界，补显式停止、监听解除及中文动态文字模板。相机远景沿用场景 Camera 的构图和 FOV，近景缩放参数可在 Inspector 编辑。未改变玩法、人数、网络字段或统计格式。

验证记录：F6 三轮隔离与停止检查、正式双端三轮统计/结算/清理检查、规则检查、旁观主机加八个 ENet 客户端检查均通过；1920×1080 远近景检查及八席三档缩放点击定位通过。人工八人操作和跨机器/外网联机未验收。G01 尚未迁移，协议现有整树禁用行为不属于本次已完成项，待共享改造后补验收。

### M19 身份派对　A/B　依赖 G01

包：`godot_party_default_identity_party`，当前正式名称阿瓦隆。定位：[game.gd](../games/minigame/godot_party_default_identity_party/game.gd)、`identity_match.gd`、`scripts/session/game_session.gd`。

- [x] 无效动作分支的 `send_to_player/send_to_peer` 也要处理 Error；停止时解除监听和清除本机私密展示，避免只禁用 stage 的处理。
- [x] 入口目前调用 `stage._render()`、`stage._on_error()` 并写 exited；改为明确的展示/退出反馈方法，入口不依赖视图私有实现。
- [x] Avalon/Werewolf 的固定桌面继续保存在各自场景；模式选择动态实例化是合理的。会随玩家数变化的座位/卡片继续实例化模板。
- [x] 保留 host-only 随机身份、每人 snapshot、观战房主推进和本人角色授权。狼人杀仍按现有开放范围处理，不借本轮重构扩大正式支持。

验证：不同身份与观战快照、无效动作反馈、阶段切换清除私密内容、断线取消、阿瓦隆多轮；狼人杀单独标注原型验收范围。

实施记录（2026-11-07）：M19 包内调整已提交并推送至子模块 `1ce852d`。入口使用明确类型及公开反馈/停止方法；快照或无效动作反馈发送失败立即停止并报告，计时器不再继续访问已清理的模型。停止解除入口、会话与页面监听，清空本机身份、卡片、目标选择及字幕，停止音效和动画；重复停止与初始化前取消均可用。保留现有场景、消息字段、随机分配、权限和计分。`AVALON_ARCHITECTURE PASS` 覆盖 8 人角色视图、观战切换、取消、迟到消息、发送失败、重复停止与重新绑定；五个本地进程连续两轮均通过 `AVALON_FRAMEWORK PASS`，覆盖真实无效动作反馈和返回大游戏结算。狼人杀仅验证共用视图清理路径，仍为原型。G01 的共享页面整树禁用仍待独立改造，本次未修改共享协议；未做本轮真人操作、视觉/音量或外网验收。

### M20 心理博弈　A/B　依赖 G01

包：`godot_party_default_psychological_party`。定位：[game.gd](../games/minigame/godot_party_default_psychological_party/game.gd) 的 `_choose()`、`_send_snapshots()`、`_toggle_microphone()`、`party_stop()`。

- [ ] `_choose()` 当前发送后直接禁用选择按钮，未检查 Error；处理失败后才决定锁定。逐人快照发送也不能忽略返回值。
- [ ] 麦克风按钮加入明确的正式生命周期/菜单门控。停止时检查端点/路由关闭结果、解除连接，保证作用域总线清理顺序；重复停止不能误操作其它作用域。
- [ ] 保留 Session 的搭档与路由确认机制；PartyVoice 的真正麦克风/分组业务不能迁成预录配音。视图只呈现本机获准看到的选择和搭档。
- [ ] 麦克风、轮空、锁定、失败信息补语言模板，不把 F6 预览接入真实端点。

验证：发送失败不伪装已锁定、搭档变更/轮空/断线、停止后旧语音不残留；实际收听需双设备人工验收。

### M21 炮火争锋　B

包：`godot_party_default_artillery_game`。定位：[game.gd](../games/minigame/godot_party_default_artillery_game/game.gd)、`battle.gd`、`battlefield.gd`。

- [ ] 保留独立 gate、host 模拟和当前载荷校验；入口里的训练 F6 分支明确隔离为本机预览配置，不能影响正式 request/settings。
- [ ] 角度/力度、弹药详情、回合及结果文字补稳定模板；固定 16 种弹药按钮用显式绑定/资源配置，不再依赖容器子节点顺序隐式决定武器身份。
- [ ] 保留 battle/battlefield 的职责，只有入口的展示/输入代码确实妨碍阅读时提取小视图组件。可破坏地形、弹道和爆炸几何继续动态生成。
- [ ] `prototype/scripts/` 的旧单人实现和音效另列原型整理任务；不要将它们复制进正式规则，也不因此给目前正式玩法补新声音。

验证：训练/自由战/队伍人数约束、移动与燃油、全部弹药选择、菜单遮挡、双端回合与结束。

### M22 雷霆战争　A/B　依赖 G01、G03

包：`godot_party_default_tank_range`，旧清单称坦克训练场，当前已有多人坦克战。定位：[scripts/main.gd](../games/minigame/godot_party_default_tank_range/scripts/main.gd)、`scripts/range_target.gd`、`scripts/tank_visual.gd`、`scripts/tank_controller.gd`。

- [x] 相机／瞄具移入 `tank_camera.gd`，通过显式引用绑定载具；音频移入 `combat_audio.gd` 和固定场景。入口仍协调部署、作用域输入与房主模拟，没有拆分网络状态机。
- [x] 发动机循环和炮击／命中 Cue 接入协议作用域音频；车辆碰撞、炮口与履带挂点保存在 `vehicles/*.tscn`。三种训练靶保存独立凸碰撞与明确部件配置，残骸通过显式网格引用同步碰撞，不再在 ready 猜名称生成。
- [x] 三种载具的固定履带片及路径均保存到场景；运行时只推进相位与车轮旋转。保留动态弹丸、爆炸和按参赛人数实例化车辆。
- [x] 清除本包剩余 `:=`／未类型字段和重复静态模型路径；确认没有正式引用、且原文件可从提交 `8759bdc` 恢复后，删除旧坦克／靶场生成器与被三车场景替代的 `player_tank.tscn`。动态选车、装填文案补齐中文命名参数模板。

本包 M22 已落地，未修改共享协议。G01 的准备／结算整树禁用仍待统一迁移；本包 G03 音频接入已完成。2026-11-07 使用系统 Godot 4.7.2：单人六靶实弹与结算、部件配置／残骸碰撞、履带运动、Q／Shift／滚轮／双准星、菜单／失焦、两车机炮与导弹、作用域音频与重复取消检查通过；本机双端混合载具击杀与双方结算通过，八实例混合选车／移动／断线退出／结算停声复跑通过。八实例首轮有一个客户端移动检查失败并导致后续 ENet 通道错误、房主等待结果超时；仅增加诊断后的复跑未复现，保留该偶发记录，未将其视为已定位修复。已检查 1920×1080 选车、战斗与瞄准镜画面；未完成跨机器网络与真人手感验收。

验证：单人六靶与多人战分别验收；选车部署、炮塔/履带/部件损伤、瞄具、自动武器、失焦/菜单、断线与结算。保留目前网络 Error 处理和客户端视觉/房主伤害分工。

### M23 纸牌会客厅原型　B，正式接入另立任务

包：`godot_party_default_card_game`，`playable:false`；运行根为 `prototype/project.godot`。定位：[prototype/scripts/blackjack_game.gd](../games/minigame/godot_party_default_card_game/prototype/scripts/blackjack_game.gd) 的 `_open_betting()`、`_apply_fixture()`；`prototype/scripts/table_demo.gd`、`card_session.gd`。

- [ ] 固定下注窗口、菜单、模式控件仍由代码创建，迁到相应场景；按席位数量变化的下注行与卡牌用子场景。保留已有各玩法牌桌、机位和 HUD。
- [ ] 清理 `:=`、未类型参数/变量、分号压缩流程和无实际用途的 presenter 兼容字段。`--blackjack-fixture` 等测试夹具移到该独立工程根的 `tmp/test/`；验收截图不再写 `res://captures`。
- [ ] CardSession Autoload 目前是独立原型的跨场景服务，不在本次整理中硬删。正式接入时再用作用域注入取代，明确真正玩家的私有手牌、座位与动作权限。
- [ ] 保留现有 AI 庄家/同屏操作原型以便参考，但不扩展，也不能在正式接入中默认为已获授权的在线 AI/同屏玩法。保持包未开放。

验证：各原型独立运行、牌桌切换、下注→发牌→行动→结算和菜单；本项不宣称完成正式 PartyAPI 多人接入。

### M24 铁鹰防线原型　B，正式接入另立任务

包：`godot_party_default_tank_battle`，`playable:false`；运行根为 `prototype/project.godot`。定位：[prototype/scripts/main.gd](../games/minigame/godot_party_default_tank_battle/prototype/scripts/main.gd)、`network.gd`、`battle.gd`。

- [ ] 保留 UI/network/battle 分层及“本地菜单不暂停服务器”语义；补显式类型，固定八声音池和声音资源入场景。
- [ ] 独立原型的输入/连接设置与正式接入分开。未来接入时让 PartyAPI 拥有正式连接，不能再启动一套原型网络；在完成之前不改 playable 或适配器声明。
- [ ] 既有固定地图布局保留，实时破坏状态和对局坦克仍由模型维护。HUD 固定控件保持可编辑，阶段/比分模板与默认语言资源统一。

验证：原型双端入房、准备、移动/炮弹、基地受损、菜单、返回房间和再战；公网体验另验。

### M25 西部牛仔对决占位　C，当前无需代码改造

包：`godot_party_default_west_showdown`。定位：[manifest.json](../games/minigame/godot_party_default_west_showdown/manifest.json)、`game.tscn`。

- 当前只有空 Node3D 场景和 `playable:false`、空 adapters，没有已有玩法可重构。
- [x] 已核对并保持未开放；没有添加空管理器、伪造生命周期或提前开放。
- 后续真正开发时按标准模板建立入口、可编辑世界/HUD、作用域依赖与协议实现；这些属于后续玩法开发，本次未实施。

2026-11-07 核对完成：子仓仍为 `825f2f7`，无代码或资源改动，主仓仅更新本条状态。已静态检查清单 JSON、入口/中文翻译路径及场景文本：保留空 Node3D、`playable:false`、空 adapters 和原有 2–8 人声明。未运行游戏或联机/视觉验收；当前没有可玩内容，相关验收留待实际开发。

## 建议分批与会话交接

1. **共享先行：G01、G02。** 各由一个会话维护；改接口必须带直接调用方与文档。它们可以分批提交，但同一次发布不能留下接口不匹配。
2. **优先单包：M06、M18、M20，以及 G02 的五个调用方。** 先处理旧偏好、预览正式数据、发送锁定、输入与画质边界。音频专用时钟不要和普通音效迁移混成一项。
3. **已有场景的增量整理：M07–M17、M19、M21、M22。** 按每包实际差距迁移外观、声音与生命周期，保留既有协议和玩法分层。
4. **原型：M23、M24；占位 M25 保留。** 整理独立原型不等于批准正式接入。需要开放时另给玩法/人数/私密数据与网络计划。

给其他会话的任务可以直接使用下面的格式：

> 请按 `doc/minigame_architecture_checklist.md` 的 Mxx 改造指定包，并阅读其中标注的 G 依赖和 `doc/api/authoring.md`。先核对现状，保留现有玩法、演示、已编辑场景与未提交工作。默认不修改其他小游戏或共享协议；如任务依赖尚未完成的公共接口，先列出具体接口和受影响调用方，不在本包复制备用实现。只运行与修改有关的验证，UI 使用 1920×1080 Godot 直接渲染；测试及输出放所属工程根 `tmp/test/`。验收后先提交推送该子模块，再更新主仓库引用，并更新本条实施/验证/待人工验收状态。

每项完成时记录：实际提交、改了什么、保留了什么接口、运行了哪些相关检查、哪些仍待人工验收。文案/目录修改只做相应文本/引用检查，不因为“整合完成”而自动启动整套多人或全项目测试。删除旧实现前核对真实引用及 Git 恢复点，禁止把未跟踪文件当成已备份。
