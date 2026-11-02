# GodotPartyDefaultProtocol 1.0

包 ID `godot_party_default_protocol`，包版本 1.0.0，契约 1.0，API 4 / 清单 2。显示名称以 GodotPartyDefault 为前缀，文件和包 ID 使用蛇形命名。依赖 `godot_party_default_avatars` 1.0.0。

协议只校验语义、生成展示和纯结算建议，不保存钱包、执行道具效果或决定奖励。金币、钻石、道具实例和已处理请求都由大游戏持久状态管理。所有身份使用框架提供的参与者 player_id，不使用 peer_id；观战者不能提交参赛结果。

## 形象与玩家颜色

`default_player_config()` 返回 `color`（不透明 #RRGGBB）、`avatar_2d`、`character_3d`。两个选择都是 `{package_id, resource_key}`，互不覆盖。`validate_player_config(value)` 校验数据结构；`get_appearance(value)` 返回独立快照。目录负责资源依赖，消费方负责实际类型检查，不把缺失资源静默视为正确安装。

2D 公开资源为六个 Bot 正面头像 Node2D 场景：银紫短发、蜂蜜金双马尾、鼠尾草绿长发、灰粉短发、浅蓝侧编发、栗棕低马尾，默认银紫短发。保留原图背景与颜色，底部标记显示玩家颜色，原点 (0,0) 位于表现底部。六张原始 PNG 和来源说明存放在 `appearance/avatar_sources/bot_avatars_upright/`；公开资源键为 `avatar_silver_lavender` 等，位于本协议包。旧 Godot 图标占位已移除；旧资料如仍引用它，需重新选择头像，不自动映射。默认 3D 为原版形象包公开的 Cube `godot_party_default_avatars/character_3d`，一米高、脚底原点、Y 向上、面向 -Z。2D 和 3D 均提供 `apply_color(Color)`；Cube 使用实例独立的材质。没有碰撞、输入、根节点移动、authority 或逐帧网络同步。本机颜色是入房偏好；房主在冲突时分配剩余颜色，也可在大厅强制交换颜色，不改写本机偏好。

通过 `api.get_appearance(player_id)` 取得快照，`api.load_asset(appearance.avatar_2d)` 或 `character_3d` 得到 PackedScene。实例化后检查 Node2D/Node3D，调用 `apply_color(Color(appearance.color))`，再交给游戏自己的表现节点管理。外部资产包可在 manifest 的 `appearance_resources` 中声明公开 key 的 `{protocol: "godot_party_default_protocol", slot: "avatar_2d" 或 "character_3d", name: "显示名称"}`；对应 key 必须也在 `resources` 中。此元数据属于本协议，不是 core 的通用形象槽。

个人资料面板仅维护草稿；框架负责应用、取消、保存和房主确认。2D/3D 分别预览，页面隐藏后停止 SubViewport 更新。3D 选择列表提供“Cube · 3D 占位”。已有资料若引用已移除的人物资源，需要重新选择并应用；不自动迁移旧资源引用。

### 共享 Cube 表现

大游戏和小游戏通过玩家资料中的公开资源引用加载 Cube，位置、朝向、碰撞和网络状态由游戏管理。Cube 只提供颜色表现，不提供动作或步态接口，也不依赖原生扩展。

```gdscript
var appearance: Dictionary = api.get_appearance(player_id)
var scene: PackedScene = api.load_asset(appearance.character_3d) as PackedScene
var visual: Node3D = scene.instantiate() as Node3D
visual.apply_color(Color(appearance.color))
add_child(visual)
```

## 请求

`validate_request(request: Dictionary, players: Array[Dictionary]) -> Dictionary` 同步无副作用。成功 `{ok:true}`，失败 `{ok:false, code, message}`。

必填 `request_id`（本会话唯一、非空）、`mode`（standard/resource）。可选 `game_data` 字典。

- standard：普通局；不能出现 resource_grant 或 item_offers。
- resource：必须提供按完整参与者 ID 索引的 resource_grant；可选 item_offers。

每位参与者 grant：

```json
{"coins":10,"diamonds":2,"coin_limit":80,"diamond_limit":2,
 "collateral":[{"instance_id":"item-1","definition_id":"main.token","coin_value":30}]}
```

coins / diamonds 是本局授权使用的现金数量，不是总钱包。coins 不包含抵押价值；小游戏初始金币下注单位为 coins + collateral 估值之和。coin_limit / diamond_limit 是最终可返还额度上限，必须覆盖初始额度；大游戏确定自己能兑现的上限。金额为 0 到 10^12 的整数，JSON 中整数值的 float 也接受；拒绝负数、小数、非有限数和溢出。抵押估值必须大于零。抵押实例全体参与者间不可重复，顺序就是承担损失的顺序。

大游戏在启动前确认玩家选择、余额、所有权、道具估值及兑现能力，将锁定请求保存在自身状态中。协议无法从传入数据证明所有权或玩家同意。不得把玩家整个背包自动纳入额度，不默认钻石能兑换金币。

## 道具

定义为 `{definition_id, name, description, data, icon?}`；实例为 `{instance_id, definition_id, data}`。icon 是公开资源引用。`validate_item_definition` / `validate_item_instance` 检查结构；`validate_resources({coins, diamonds, items})` 检查一份大游戏资源快照及实例唯一性。大游戏可在此快照外维护任意其他状态。

item_offers 按玩家索引数组，每项：

```text
{item: 道具实例, effect_id: 双方约定的效果标识,
 parameters: 效果参数字典, consumable: 是否允许本轮消耗}
```

同一道具不能重复授权，也不能同时使用和抵押。effects 不由协议自动执行；小游戏适配器的 check_request 必须拒绝不支持的 effect_id，大游戏只能提供双方真正实现的效果。纯抵押道具不需要小游戏理解其效果。

## 结果与成绩

`validate_result(result, request, players)` 先检查原请求，随后检查结果。必填：

```text
request_id: 必须等于原请求
reason: completed / cancelled
rankings: [{player_id, rank, status, metrics?}]
```

rank 为非负整数；0 表示未排名。status 为 completed / withdrawn / disqualified / unranked；unranked 必须 rank=0。允许空结果、缺少部分排名、并列和跳号，不重算作者名次。metrics 仅数字和文本；可选 columns 数组为 `{key,title,format}`，format 支持 integer/decimal/text/time（毫秒）。可选 game_data 字典保存业务结果。

resource 正常结果必须含全体参与者 resource_result，每人 `{coins, diamonds}` 是最终额度，包括断线者和零余额者。item_result 可选，按玩家索引已消耗的实例 ID 数组，只能引用本轮 consumable 授权；不允许重复。抵押道具由父游戏清算，不能混入消耗列表。cancelled 和普通局都不得携带资源或道具结算。

`present_result(result, request)` 在通过校验后调用，转换成 core 的标题/列/玩家行；保留排名和行顺序。未声明 columns 时不猜测金币、钻石或奖励。

扩展 game_data、道具 data 和 parameters 支持 JSON 风格值及 PackedByteArray；字典键接受 String / StringName。禁止 Node、Resource、Callable。固定契约字段严格校验，扩展内容放入上述字典，不添加兼容别名。

## 纯清算与父游戏接入

`calculate_settlement(result, request, players)` 返回 `{ok, request_id, players}`；每位玩家的建议包含 coins_delta、diamonds_delta、forfeited_items、consumed_items。普通局或取消返回空 players；输入无效返回错误报告。函数不更新任何状态，多次调用结果相同，不代表调用方可以重复应用。

金币损失先由授权现金承担，再依顺序扣整件抵押道具，超出损失的估值找零；未动用的道具保留。盈利不扣抵押物。10 现金 + 30 估值道具，最终下注单位 22 表示亏损 18：coins_delta=12，扣道具一件；原现金 10 变为 22。最终 48 表示盈利 8：coins_delta=8，道具保留。钻石直接按最终额度减初始额度，不换算金币。

父游戏 reducer 使用 state 中已锁定的 request 和玩家名单计算建议，复核资源和实例，更新自身副本并记录已处理 request_id；排名奖励另算，只在 reason=completed 时按自身规则决定。不要在 reducer 中写文件或发消息。core 的成功持久化与轮次去重负责正式提交，finish 返回 OK 不等于保存已完成。

不在启动小游戏前永久扣款。小游戏期间父状态冻结，资产不能另用；加载失败/取消恢复此前已提交状态，无额外补款。保存失败重试同一候选，不重新发奖。初版没有中途追加抵押、长期借贷、利息、赎回、交易、通用钱包或商城。

## 样例与检查

../examples/ 包含普通局、资源局请求/结果及超额非法结果。旧协议与资料测试已归档到 tmp/test/archive/，不再作为运行入口或当前验收依据。当前轮换与大厅定向检查在 tmp/test/playlist_room/；资源系统本轮未修改。

当前正式轮换仅使用 standard 阿瓦隆局；资源契约和纯清算实现保留，尚未接入正式主游戏经济循环。

## 共享画质（本地偏好）

公共偏好页使用框架通用 Schema 表单和 `core/ui/settings/` 场景预制体；渲染比例采用滑条与数值框。本协议 `settings.gd` 按 [配置契约](../../../../doc/api/configuration.md) 声明 type、default、control、限制和 layout 层级，实际效果仍由 settings_runtime 或游戏消费方实现。配置值保存在 preferences.json 及游戏独立 overrides.json 中；继承开关开启后折叠并半透明禁用对应覆盖，应用时删除覆盖键恢复继承。

在轮换大厅“协议与本地设置”中编辑公共偏好。所有采用本协议的大小游戏平行继承；游戏可使用正式游戏设置页单独覆盖，恢复继承后重新使用协议值。设置不会进入房间规则或网络数据。

| 档位 | 阴影图 | 阴影过滤 | MSAA | AO 质量/分辨率 |
| --- | --- | --- | --- | --- |
| 低 | 2048 | 最低 | 关闭 | 低 / 半分辨率 |
| 中 | 4096 | 低 | 2x | 中 / 半分辨率 |
| 高 | 4096 | 高 | 4x | 高 / 全分辨率 |
| 极高（默认） | 8192 | 极高 | 8x | 极高 / 全分辨率 |

`graphics.quality` 使用枚举值 `低/中/高/极高`。独立开关为 `graphics.shadows`（默认开）、`graphics.pcss`（默认关）、`graphics.ao`（默认关）、`graphics.taa`（默认开）、`graphics.bloom`（默认关）；`graphics.render_scale` 默认 1，范围 0.5–2。切换档位不重置开关。所有字段可覆盖、立即应用于活跃三维视图；保存成功与效果报告仍按框架约定分开。PCSS 关闭使用 PCF；开启可能出现采样噪点，不保证更好观感。非 Forward+ 下 AO/TAA 报告不支持，不更改用户期望值。

正式游戏不要自行创建画质 runtime，也不要重复写 RenderingServer。清单选择本协议后，由 core 的 settings scope 自动创建 `graphics_settings.gd`。三维视图根提供以下协议专属登记方法（大游戏放在 create_view 返回的节点，小游戏放在入口根）：

```gdscript
@export var graphics_world: WorldEnvironment
@export var graphics_sun: DirectionalLight3D
@export var graphics_models: Node3D

func godot_party_graphics_targets() -> Dictionary:
    return {"world": graphics_world, "sun": graphics_sun, "materials_root": graphics_models}
```

world 必须有 Environment。sun 的 `light_angular_distance` 定义开启 PCSS 时的角尺寸；0 表示不使用可变半影。灯光方向、能量、曝光、AO 半径/强度、辉光强度、阴影偏移/距离、FOV 属于游戏美术，在场景中配置，不被档位覆盖。帧率、垂直同步、窗口仍由 core 系统设置控制。暂不启用 LOD。

`materials_root` 可省略；登记后其模型的普通表面材质使用局部副本和线性各向异性采样，避开色板最近邻条带，不修改共享资源。不覆盖 ShaderMaterial 或整体 material_override。不要给像素风或需要特殊采样的模型登记此节点。

未提供登记方法的二维游戏、大厅不接管三维画质，效果报告为不适用。退出或重建视图恢复原 Environment、材质覆盖与视口，全局质量恢复项目基准；下一设置作用域随后取得应用权。游戏不要与该 runtime 并行写同一属性。

Millionaire 当前仍是独立 F6 视觉原型：读取同一资料槽的协议偏好，调用相同画质实现，不保存第二套配置。更改公共偏好后重新 F6。正式接入时移除其 `_start_graphics()` 预览桥接，仅保留登记方法，由框架接管。

## 原版小游戏的语音授权

原版协议委托小游戏轮换的 room.gd 独占该大厅的语音端点。大厅默认只收听，主动开启麦克风仍需系统授权；房主设置 global 路由。规则修改重建、开局、离房和断线时关闭端点并清理总线。阿瓦隆和轮换局间不启用此端点。协议画质 runtime 不创建语音端点。

原版协议允许 `godot_party_default_psychological_party` 在自身活跃作用域内登记玩家实体、创建一个语音端点并切换配对 group 策略。仅同一开放配对的玩家互通，未参赛者无端点；配对关闭或作用域销毁后停止音频。房主编排路由，客户端必须主动启用麦克风，并继续遵守 core 系统麦克风授权。游戏不改变其他游戏或协议的端点，也不开放全房间广播。

## 玩家颜色与房主分配

资料包含 `avatar_2d`（2D 头像场景）、`color`、`character_3d`（3D 形象场景）。不读取旧 `character_2d` 资料格式；原文件保留，需重新应用当前资料。

固定八色：红 `#e53935`、绿 `#43b047`、蓝 `#2962ff`、亮青 `#00d9e8`、紫 `#9c42d4`、黄 `#ffda24`、黑 `#252832`、白 `#f5f5f5`。资料面板显示色块与名称，不支持任意 RGB 输入。

玩家本机选择是入房偏好。房主使用 `resolve_player_config(value, player_id, players)` 检查房间占用；冲突时随机选择剩余颜色，已占用颜色的玩家不变。入房与大厅提交均检查，本房间调整不覆盖本机保存的偏好。

房主在大厅打开玩家资料，可以使用“强制分配”。`assign_player_config(player_id, assignment, players)` 接受 `{color}`，返回 `{ok: true, profiles: {player_id: 完整资料}}`。占用时交换目标玩家与占用者的颜色；头像、名字和身份不变。框架校验整批资料及资源依赖后一次性广播。客户端、活动期间及恢复大厅不能分配；恢复使用存档原快照。

## 公共字体

协议界面默认使用与框架相同的黑体，文件独立保存在协议 fonts/。大小游戏可通过公开资源 `font_sans`（黑体）或 `font_serif`（思源宋体 Regular）选择字体，参见 [字体调用示例](../fonts/README.md)。不依赖 core 的字体路径，也不修改框架主题。

## 共享玩家鼠标

公开资源 `player_cursors` 为 Control 脚本。游戏创建后先 `setup(api)`，再作为实际交互区域（例如棋盘）的子节点加入；组件铺满父节点并忽略鼠标事件。清单声明 `cursors: {mode: "ordered", audience: "instance"}`。组件通过便利消息 pointer 发给主机，再经声明流广播；只接纳当前在线参赛者的消息。仅相对区域的 0–1 坐标过网，不发送屏幕像素；主机验证类型、有限数、范围、序号和发送间隔。每秒最多约 15 次发送，收到的显示数据 1.5 秒过期，断线/失焦/离开区域后隐藏。颜色取 api.get_appearance 的 color，另显示名字和高对比描边。鼠标数据只作表现，不能据此判断点击或奖励。

协议公共偏好 `ui.player_cursors`（默认开，可被小游戏覆盖，立即生效）控制本机是否显示其他玩家鼠标；不影响发送自己位置。组件 `enabled` 则由游戏在离开交互阶段时关闭发送与显示。组件的生命周期限于本次活动，释放后信号连接自动清理。果园连线使用此组件；其他游戏可按需接入。

公开资源 `ranked_round` 为原版五款街机小游戏复用的 Control 基类，提供 standard 生命周期、受发送者身份与单调序号约束的逻辑行动、主机快照、一次性结果提交和基础布局；不定义玩法和奖励。游戏入口场景继承协议的 ranked_round.tscn，根节点挂载对应的子类脚本。子类通过 build_game/start_game/tick_game/handle_action/make_snapshot/render_game 实现各自玩法。state 使用可靠快照；大型星潮状态另作压缩，视觉短时外推不改变裁定。清单应声明 state（reliable/instance）及需要时的 private_view（reliable/instance）。

## 加载与结算场景

协议公开 `briefing_view` / `briefing_gate` 与 `settlement_view` / `settlement_gate`；主游戏或小游戏按需挂载，不改变未接入游戏。

- 加载：helper入树前 `configure(api, content)`，content含title/introduction/cover/controls；`read_content(manifest_path, api)`可读取自己的简介和实际绑定。初始化后游戏正常`mark_ready()`，`party_start()`中调用`transport_started()`；等`play_requested`才启动玩法。人工确认使用Enter/空格，观战无需确认；技术准备与人工准备独立，全员满足后默认3秒开始。
- 结算：helper入树前`configure(api, presentation, result_token)`，presentation为`{title, rows:[{player_id, rank, metrics:{score}}]}`。score是本轮小游戏分数，不是父游戏奖励；作者给定rank，视图稳定处理并列，不按分数重排。所有在线端装好页面后自动回执，默认3秒发出`continued`，没有人工准备/退出按钮。
- helper不调用`finish()`或发奖。拥有者自行选择提交前展示，或在父游戏持有已提交结果后展示；必须保证节点在展示期间仍存活。同一轮使用唯一token，消息校验session/scope/token/revision和真实发送者，退出时调用`stop()`。
- 纯view可单独使用：加载view提供`configure`/`set_state`与`ready_requested`；结算view提供`configure(presentation, players)`与`set_countdown`，不拥有网络或计时。

空白模板是接入示例：自己持有加载和结算页面；在线参赛者各按一次结束按钮，房主按收到有效点击的顺序生成并广播排名，所有端自动看完结算后才`finish()`一次。页面使用已有主菜单背景/主题/面板，不引入外部资产。其他小游戏与正式轮换保持原实现。
