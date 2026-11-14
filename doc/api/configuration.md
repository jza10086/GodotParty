# 配置继承与房间规则

框架 0.0.1 / 配置声明 Schema 3。完整工程是开发环境。

## 本地文件位置

主菜单手动语言选择保存在 core/config/settings.json 的 localization.locale，默认 zh_Hans，可选 en，不读取系统语言。包清单独立声明语言与中文回退，设置表单只翻译展示字段，见 [本地化](localization.md)。

配置按三个职责组织：`manifest.json` 保存包 ID、名称、包/API 版本、协议及依赖；包内业务脚本 `settings.gd` 的静态 `schema()` 声明字段、默认值、限制、控件与层级；用户 JSON 文件只保存持久数据，不定义 UI。Schema 中 `audience: local` 属于本地偏好（画质、热键等），`audience: room` 属于房主规则。说明和默认值不复制到每份用户设置中；`settings_version` 标识数据结构版本，独立于包发布版本。只有房主规则提供命名预设。

用户配置均为 UTF-8 JSON，可使用普通文本编辑器修改，位于项目根目录（编辑器）或可执行文件所在目录（桌面导出）。Android 使用应用私有 `user://` 的绝对路径，保留下面相同的目录结构。`PartyInput.installation_directory()` 返回当前平台的安装数据根目录；实例 `storage_directory()` 返回当前资料槽根目录。路径不依赖工作目录。读取偏好不生成默认配置；显式应用才保存；首次启动仍会持久化必要的 player_id。开发用 `--party-profile=<slot>` 将完整配置树隔离到 `tmp/test/profiles/<slot>/`，安装内容仍来自正式安装根目录。运行时不读取或迁移 CFG；JSON 语法和字段值无效时明确报错。

Android 的“内容包”界面通过系统文件选择器导入内容 ZIP，并导入/导出系统配置 JSON。系统配置传输不包含或替换本机 player_id；协议资料和游戏偏好继续通过游戏内设置修改，不包含在此 JSON 中。同包名、同签名 APK 覆盖安装保留应用数据；卸载或清除应用数据会删除这些配置。

```text
GodotParty/
  GodotParty.exe                         # 内嵌框架核心，双击运行
  core/
    config/settings.json                # 系统、连接、唯一 player_id
    saves/                              # 框架会话记录
    notices/                            # 必需许可信息
  protocols/<protocol_id>/
    content.pck
    content.pck.json                     # 工具生成的包描述，不是用户设置
    config/preferences.json             # 协议公共本地偏好
    config/profile.json                 # 此协议的昵称、形象等资料
    config/presets/朋友聚会.json
    avatars/<avatar_id>/content.pck
    avatars/<avatar_id>/content.pck.json
  maingame/<id>/
    content.pck
    content.pck.json
    config/preferences.json             # 与协议无关的游戏自身偏好
    config/<协议指定目录>/overrides.json   # 该协议的显式本地覆盖
    config/<协议指定目录>/presets/周末.json
  minigame/<id>/                         # 与 maingame 相同结构
```

协议清单必须声明 `config_directories: {"maingame": "godot_party_default_v1", "minigame": "godot_party_default_v1"}`。只允许单层安全名称，拒绝路径穿越、系统保留名；同一类别下不同协议不能使用相同目录名（忽略大小写）。契约主版本变化时作者应换目录名；配置元数据也检查主版本，拒绝误读旧文件。核心不提供头像素材或固定形象槽位，稳定身份只有 player_id，协议负责昵称和形象。

源码安装的协议、主游戏和小游戏位于 `games/` 下，配置目录紧邻各自包。引擎自己的工程、插件、导出配置与日志缓存不属于用户配置，不改变其原生格式。

主菜单“内容包”可浏览当前已加载的协议、主游戏、小游戏，并进入各包的本地偏好设置。小游戏可选择其已安装的适配协议；未选择协议的自身设置提交只写入 `preferences.json`，不改动任何协议覆盖文件。公共覆盖仍必须明确指定协议，房间规则继续在大厅编辑。

## 定义与权威来源

业务声明脚本固定为 `settings.gd`；协议的可选设置效果脚本固定为 `settings_runtime.gd`。声明脚本继承 RefCounted，静态 schema() 返回字典，不读取用户文件、不修改运行状态。
旧 fields、defaults、input_actions 清单字段已移除。形象 player_fields 与玩家资料不属于本设置系统。

Schema 包含 schema_format: 3、settings_version 正整数、fields 字典和 layout 数组。
字段 key 是平面字符串；例如 audio.bgm 不代表递归字典路径。
字段包含 type、default、title、description、audience、apply；协议公共字段必须声明 overridable。
基础类型只有 bool、int、float、string、array、object；数值的整数/小数限制只属于数据校验，用户使用同一个数字控件。`control` 指定表现，`layout` 定义可折叠层级，均不写入用户文件。

| control | 数据声明 | 表现 |
| --- | --- | --- |
| toggle | bool | 开关 |
| select | string/int/float/array + values，labels 可选 | 下拉单选，枚举不是独立类型 |
| text | string；multiline 可选 | 单行或多行文本 |
| number | int/float；min/max/step 可选 | 数字框；上下界均存在时同时显示滑条 |
| numbers | 定长数值 array + items；labels 可选 | 复用多个 number 表达分量或区间 |
| switches | array，items 为带 values 的 string/int | 多选开关组 |
| color | 四个 [0,1] float 的 array | RGBA 选择器；alpha:false 固定 A=1 |
| path | string；path_mode 为 file/directory | 系统文件/目录选择器；filters 为文件过滤列表 |
| binding | array，items 为 object/format:binding，max_items:2 | 主按键和备用按键；键盘录入或鼠标下拉枚举 |

bool/int/float/string 省略 control 时分别使用 toggle/number/number/text。object 用于数组项或嵌套数据校验，不提供任意对象编辑器。每个显示字段必须在 layout 中恰好引用一次。

数值支持 min/max 和正数 step，整数类型的限制也必须为整数。step 只控制箭头和滑条增量，不量化手动输入的文件值；小数框保留精度。suffix 仅显示单位；display_scale 将存储值换算成显示值，如 0–1 音量使用 100 显示为百分数。数组使用 items 声明元素类型，min_items/max_items 限定长度；numbers 要求正整数定长，区间额外声明 ordered:true 拒绝倒置，多选拒绝重复或未知候选。不裁剪非法值或交换端点。

字符串支持 max_length（默认 4096）和 placeholder。文件路径由原生 FileDialog 选择，是否存在、能否打开及具体资源语义由消费业务处理。

绑定示例为 `[{"kind":"key","code":86,"physical":true,"ctrl":true}]`；鼠标使用 kind:mouse 和按钮枚举 code。字段必须提供 action 逻辑标识；combinations:false 限制录入为单键，默认允许组合键。空数组表示明确不绑定；仅备用槽有值时第一个元素为 `{}`。Esc 取消录入，清除使用独立按钮；Delete、Backspace 和单独修饰键可录入。固定键使用 readonly:true，只显示、不保存或覆盖；Esc 仅允许作为固定导航键。没有手柄或分屏设备映射。

```gdscript
extends RefCounted

static func schema() -> Dictionary:
	return {
		"schema_format": 3,
		"settings_version": 1,
		"fields": {
			"audio.bgm": {
				"type": "float", "control": "number", "default": 0.8,
				"min": 0, "max": 1, "step": 0.01,
				"display_scale": 100, "suffix": "%",
				"audience": "local", "apply": "immediate", "overridable": true,
				"title": "音乐音量"
			}
		},
		"layout": [{"id": "audio", "title": "声音", "expanded": true,
			"children": [{"field": "audio.bgm"}]}]
	}
```

分组使用 id/title/expanded/children；顶层分组在设置工作区中显示为横向分类标签，分类下最多三级设置行。字段使用 `{field: "字段键"}`，也可带 children，把相关设置直接挂在当前控件下，例如显示模式下面的窗口分辨率。分组或字段可带 `enabled_when: {field: "其他字段键", equals: 某值}` 和 disabled_reason。条件不满足的同级项灰显，子项收起；父字段所有子项均不适用时禁用展开箭头，父字段自身仍可操作。保存时保留原值，条件恢复后恢复草稿与展开状态。条件只控制编辑，不改变业务的有效值规则。

游戏偏好提供整体和逐项“继承协议”开关，整体开关位于页内设置列表首行。继承时显示协议有效值摘要、折叠并半透明禁用编辑器；取消继承可填写独立覆盖。开关本身不存盘，应用时删除覆盖键表示继承。游戏自身偏好直接编辑，不显示逐项“默认”开关；缺少用户值时显示业务声明的默认值。仅修改草稿或取消不写入文件。

本地公共值：协议默认 → 协议用户值 → 当前游戏的协议覆盖。
本地专属值：游戏默认 → 游戏用户值。大游戏和小游戏平行继承协议，不互相继承。
覆盖分支按协议 ID@契约主版本隔离，实际文件目录由协议声明；未选分支不解析，也不加载对应协议脚本。
0、false、合法空字符串、空绑定数组都可以覆盖；null 不合法。
显式值等于基值仍然是覆盖；只有 clear/unset 才恢复继承。

api.config.get_common/get_own 返回当前有效值。snapshot_effective 含本地偏好，不得整体广播。
get_settings() 只返回当前游戏锁定的 own/room 规则；小游戏 setup config 仍是协议适配后的请求。
不要在协议请求中再次声明另一个同义权威规则；适配器负责契约转换，不合并用户偏好。

## 保存与编辑

系统设置、原版协议公共偏好、游戏本地覆盖和房主规则均通过 `core/ui/party_config_form.gd` 动态实例化 `core/ui/settings/<control>.tscn`。九种控件场景共用 setting_row.gd；numbers 复用紧凑的 number_component，switches 复用 switch_option，binding 以两行展示主键和备用键；setting_section 将名称、控件、继承开关放在同一行，一级分类和含子项的设置点击本层标题行或聚焦标题按 Enter / 空格展开、收起；Xbox 使用 X，动画期间屏蔽子项输入，重新展开时保留嵌套分组状态。场景可在 Godot 编辑器直接调整。

本地设置页使用框架内置的 Ambient Reveal 主题与全屏 settings_workspace.tscn 布局：顶部为可横向浏览的分类，鼠标停在选项卡区域时滚轮横向滚动，下方显示不可拖动、两端闭合的位置指示条。深色表示当前可见范围，浅色表示未覆盖范围；分类全部可见时整条显示深色。左侧设置行均带边框，内容垂直居中，开关右对齐并复用无方形外框的 switch_option.tscn；右侧随鼠标悬停或键盘焦点显示字段 title/description、当前值与禁用原因。左下角“恢复默认设置”重置本页所有分类的可编辑草稿，并清除协议覆盖；点击应用才写入文件。readonly 不受重置影响。分类切换不销毁控件，返回小游戏池或协议页时保留其原草稿。
共享行脚本只绑定字段和维护草稿，不读文件、不应用游戏效果。party_schema.gd 校验声明和值；party_json_config.gd 负责分区 JSON 读写；party_config_store.gd 负责版本、继承、revision 和原子保存。业务包的 settings.gd 是声明唯一来源，通用 UI 不硬编码小游戏字段。
原版协议已有渲染比例使用滑条。新增类型仅提供通用表达能力，不向正式配置添加没有实际效果的示例字段。示例中的强调色、偏移等需由游戏或协议作者实现消费逻辑。

系统、身份、连接位于 core/config/settings.json；协议与游戏分别使用上表中的 JSON 文件。
本地偏好数据格式 2 使用根对象下的 meta 和 values 对象，元数据包括 schema_id、settings_version、revision。数据格式 2 与代码声明 Schema 3 是独立版本。游戏自身偏好与选中协议覆盖分别保存，内存聚合为 own/common_overrides。settings_version 不等于包版本。字段 key 中的点仍是键名的一部分，例如 `"values": {"graphics.render_scale": 0.8}`，不是递归路径。JSON 不支持注释；枚举值、数据类型和范围必须符合业务声明。
应用以固定目标、预期 revision、set/unset 操作组成；整批校验后，写临时文件、备份并替换，成功才更新缓存及通知。
格式或设置版本不匹配明确报错；显式重置保留 .bak，不存在自动迁移。
系统配置读取和保存时校验显示、外观与音量；非法值不替换为默认值。协议资料仅在文件不存在时采用首次使用默认值；读取失败或资料字段错误会报告错误并停止入房或资料编辑。本机身份必须成功持久化后才能参与连接。
普通 API 只能修改当前活跃游戏的本地值。协议基值通过正式协议设置页修改。
暂停的大游戏保持 room 快照，恢复时重新读取 local 偏好。

## 房间草稿与预设

协议、大游戏与所有已选小游戏的静态人数及配置限制共同决定允许开局人数。声明方式、交集及参赛子集规则见 [可开局人数](player_counts.md)；变更配置或池后立即重算，空交集禁止开始。

房主编辑 RoomDraft，客户端只读；保存命名预设是独立操作，没有自动 @recent 写入。
协议、大游戏、小游戏均使用自己 config 目录下 presets/<名称>.json，核心没有预设。文件名即显示名称，无中央索引、无内部重复名称；直接复制或重命名文件后刷新即可识别。

预设格式 3 仅保存房主规则，不保存本地偏好。JSON 的 `meta` 对象包含 format、kind、package_id、package_version、protocol_id、settings_version、protocol_settings_version。

- 协议预设：`room_own` 对象保存协议房间基值，`room_common` 必须为空。
- 小游戏预设：`room_own` 保存自身规则，`room_common` 保存协议规则覆盖。
- 大游戏整场预设：另有 `room` 对象，包含协议 common、小游戏 children、命名 pools、common_overrides 以及各小游戏版本 versions。通过大厅“大游戏配置”保存和加载整场。

文件不包含身份、昵称、形象、热键、画质、设备或运行状态。空规则分区可以省略。旧格式明确拒绝，不自动转换；原文件保留，用户可重新另存当前规则。

仅房主可操作预设。工具条提供加载、另存、覆盖、重命名、删除、刷新及打开目录。加载完整校验版本、字段、依赖、池及小游戏配置后进入草稿，点击应用才提交房间。另存不应用；覆盖和删除明确确认。整场预设完整替换对应房间配置，不合并旧池；本地偏好页面不再提供预设。规则编辑页保留协议和小游戏单独预设，大游戏整场预设集中在大厅大游戏配置入口。

大厅“大游戏配置”与“小游戏池”分开。小游戏列表的行高亮与入池勾选独立：单击只高亮并预览，Ctrl 单击切换高亮，Shift 按可见顺序连续高亮，Ctrl+Shift 追加范围；Ctrl+A / Ctrl+I 全选 / 反选高亮，不修改小游戏池。点击高亮行右侧的勾选框，会将当前可见的高亮项统一勾选或取消；点击未高亮行的勾选框只修改该项。工具栏提供全部勾选、反向勾选与清空勾选；搜索过滤下，全选和反选只作用于可见项，清空勾选作用于整个池。只有外层“应用小游戏池”才提交草稿，并检查房间规则 revision，避免覆盖已经变化的配置。
右侧预设与房间规则只作用于当前查看的单个小游戏。高级设置应用前校验，应用到草稿显示“临时预设”，只在本次草稿与房间使用；预设另存是独立按钮，不写入或应用其他游戏。外层取消丢弃房间草稿；显式保存的命名预设独立保留。重新打开时按当前规则匹配已保存预设，否则显示临时预设。临时预设不会成为以后新房间的默认设置。

小游戏池右侧“本机设置”打开当前高亮小游戏的本地偏好与协议继承/覆盖。无需勾选入池或开始游戏，客户端也可编辑自己的偏好；“应用并保存”直接写入本机 preferences.json 和协议目录下 overrides.json，不进入房主规则草稿，关闭外层小游戏池不会撤销已保存的本机设置。
固定 `config_panel.tscn` 仍优先于公共表单，用 configure(value, editable, context)/get_value()；必须遵守 editable。房间面板 context.pools 提供当前选池快照；载入预设时使用预设的选池，业务面板可据此显示自动局数等派生值。
公共字段表单只编辑草稿，点击应用才提交。协议规则与覆盖使用同样的批次应用边界。

每次 PREPARE 生成 RuleSnapshot，包含游戏/协议/设置版本、基值、覆盖、解析结果及摘要；所有端确认摘要再 READY。
房间规则不包含本地音量、画质、设备或物理键位。
room/lobby 开局后锁定；room/next_round 仅影响之后启动的小游戏；room/live 不支持。
大游戏自身 room 字段只能 lobby。影响长期经济的公共规则也应 lobby。
运行中编辑复用持久化提交队列，保存后发布；失败可重试，不运行奖励归约。
主游戏初始规则独立保存在会话记录中；当前小游戏和结果处理使用当轮快照。

## 生效与生命周期

local/immediate：活跃效果实现重新应用。
local/next_activation：保存后待下次激活；local/restart：待进程重新启动。
非活跃游戏只保存，下次进入读取。来源变但有效值不变，不触发 effective_changed。
保存成功与效果成功分开；能力不支持时保留期望值。
刷新或效果应用失败会输出运行时错误，不继续发送成功变更通知；活跃连接在回调返回后退出，避免继续使用失效设置。`PartyConfig.failed(message)` 报告异步刷新失败，由设置作用域传递给协调器。

协议 settings_runtime 使用 configure(api)、enter()、attach_view(view_root)、apply(common_keys, own_keys)、leave()。
这些方法同步执行；enter/attach/apply 返回 {ok:true, applied:[], deferred:[], unsupported:[]} 或 {ok:false,code,message}。
configure 不修改全局状态；enter 在游戏入树前执行；attach_view 在根节点/大游戏视图入树后执行，并参与 READY 门槛。
leave 必须幂等并清理自身回调、播放器、总线和视口修改；主游戏恢复会创建新的 runtime。
普通主状态提交只重新 attach 视图，不重复 enter。不要保存过期节点或裸音频 bus index。

公共音频总线和画质语义由协议定义，core 不根据字段字符串猜测效果。
协议总音量作用于自己的 GameRoot，不写真正的 Master；同一视口属性只交给一个实现。
可用 party_settings_changed(common_keys, own_keys) 钩子或 effective_changed 信号，避免同时处理两次。
原生 Input 读取仍由作者负责焦点和活跃门控；api.input 已处理观战、弹窗与松键重置。

协议在自己的包目录提供 settings.gd 和可选 settings_runtime.gd。旧测试协议源码已清理；原版协议 1.0 已提供形象与资源契约，公共输入/音频偏好待具体玩法需求确定。

原版协议的四档画质、独立效果开关和三维视图登记见 [原版协议画质](../../games/protocols/godot_party_default_protocol/doc/godot_party_default_protocol_guide.md#共享画质本地偏好)。后续原版内容复用该设置 runtime，不再复制画质实现；场景美术参数保持游戏所有。

## 框架显示设置

框架系统页由 PartyInput.settings_schema() 声明，复用通用表单。`settings.json` 的 display 对象保存 mode（windowed=窗口化、borderless=无边框全屏、fullscreen=独占全屏）、resolution（JSON 数组 [宽,高]）、vsync（bool）和 fps（0–1000 的整数，0 表示不限帧率，默认 160），不进入协议 Schema 或房间快照。PartyInput.display_values() 只读校验并将分辨率转换为 Vector2i；apply_display(viewport) 应用帧率及指定视口所属原生窗口，display_feedback(viewport) 在窗口事件完成后读回实际状态。编辑器内嵌与 headless 明确报告未应用的窗口效果，保留保存值。帧率上限复用通用数字输入框与滑条，步长为 1 FPS。首次启动和恢复默认采用无边框全屏，保存的窗口尺寸为 1920×1080。两种全屏固定使用屏幕尺寸，分辨率设置折叠、半透明并禁用，保留窗口化草稿；无边框全屏采用 Window.MODE_FULLSCREEN，独占全屏采用 Window.MODE_EXCLUSIVE_FULLSCREEN。回到窗口化恢复保存的窗口尺寸与边框，窗口化分辨率不改变 3D 渲染比例。系统设置始终先保存，成功后才应用显示与 CoreUI 总线，并在启动时重新应用。
