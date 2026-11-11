# 框架界面与 Ambient Reveal

正式入口为 `res://core/app/party_main.tscn`。在编辑器中打开此场景即可查看背景、PartyUI、游戏操作栏、加载说明和屏幕键盘。主页可从 PartyUI 实例打开对应子场景编辑。大厅内容由房间选定的主游戏提供。主菜单、房间列表、共用大厅、框架弹窗和本机设置使用从 GodotUICase 移入的 Ambient Reveal。运行所需的主题、字体、图标、着色器和交互音效在 `core/ui/ambient_reveal/`。

Ambient Reveal 是项目主主题，项目设置 gui/theme/custom 指向 ambient_reveal/ambient_theme.tres，供没有单独指定 Theme 的控件使用。旧 UI 仅保留 source/ui/theme/party_theme.tres 的蓝白轻 Godot 风格及其 ui_config.tres 配置；soft、sage 配色、背景和专用插画已移除。

`GPPartyTheme.create()` 返回共享的 `ambient_theme.tres`。调整外观时可在编辑器直接打开 `ambient_reveal/components/` 内的预制体。需要悬停、焦点和按下反馈的动态控件也实例化这些预制体。按钮使用透明的默认表面，鼠标悬停或键盘聚焦时显出圆角边缘。菜单交互音效使用 CoreUI 音频总线。

框架控件的禁用、可用、聚焦边框由主题直接引用 theme/frames/ 中的三份 StyleBoxFlat 资源。可用和禁用框均为无描边的同色背景，禁用只将文字设为灰色并退出焦点导航；聚焦、悬停使用柔和的细边框。输入框使用原生 normal、read_only 和 focus 样式，单行、多行和数字输入光标以 0.53 秒间隔持续闪烁；无常态背景的按钮在悬停或聚焦时逐渐显出聚焦框。面板的屏幕采样只参与底色混合，轮廓由主题绘制。小游戏列表行的选中样式和设置页内边距在 ambient_theme.tres 中，设置输入及其原生弹出菜单的字号在 settings/field_theme.tres 中。开关的静止状态使用主题图标，过渡时由 Tween 驱动滑块材质。

主菜单与大厅的排版位于 `core/ui/source/ui/`。配置业务声明生成 `core/ui/settings/` 内的设置行，由行预制体组合原生输入控件。系统设置、协议设置、本机偏好、连接诊断、小游戏浏览器和弹窗均有同名 .tscn。弹窗的固定内容在 core/ui/dialogs/，原版协议的资料预览及普通局布局分别在协议目录的 profile_panel.tscn 和 ranked_round.tscn。小游戏浏览器每页有 12 个卡位，超出时可翻页。框架统一提供外观，具体设置的可编辑性、继承和保存由配置模块管理。

小游戏轮换大厅仅保留成员、游戏与规则两张卡片，不再启用大厅语音。左上角为带 Esc 图标的返回主界面按钮；房间标题、副标题及右上角网络状态在大厅中不显示。底部键鼠提示省略设备名称。蓝色“复制房间地址”位于准备按钮左侧，复制实际连接的地址与端口（IPv6 使用方括号）。右下角共用准备／开始按钮：准备绿色、取消准备红色、开始游戏橙黄色；房主等待其他玩家准备时显示禁用的红色“玩家未准备”。其他开始限制显示在底部。纯色按钮由 `source/ui/lobby_action_theme.tres` 定义，文字使用 `lobby_cutout_text.gdshader` 和背景捕获形成镂空效果。主菜单标题与入口直接显示在背景上。

框架玩家/延迟面板为 `core/ui/network_panel.tscn`，由正式 app 注入现有连接和翻译服务。大厅与游戏中按住 Tab 查看、松开关闭；使用居中容器与四列表格呈现最多八名玩家、到房主的 RTT、连接状态和原生可靠包丢失率估计（约每 10 秒更新）。它不获取焦点、不拦截鼠标、不暂停玩法；设置、文本输入和模态页保留 Tab 焦点导航。隐藏时不轮询，显示时每 0.5 秒读缓存，不产生网络请求。小游戏轮换大厅每秒仅刷新状态文字，名单变化才重建对应列表内容。总积分快捷键为 F3。

页面底部使用 Ambient Reveal 的输入提示条，随键鼠、Xbox 焦点导航、右摇杆光标和编辑状态更新。在设置中点击当前层的标题行可折叠，Xbox X 操作焦点或光标所在标题行。无子项的设置和行间空白不会触发上级折叠。A 操作行内控件。Xbox 十字键或左摇杆在当前页面、弹窗或展开的设置之间移动焦点。A 确认、打开屏幕键盘或进入滑条调节，B 退出当前操作。普通手柄模式仅 LB / RB 切换设置分类，焦点直接进入新页内容。上下逐行移动，左右选择同行控件，Y 回到当前页首项。右摇杆切换到光标，A 单击或拖动，X 右击。其他带上下文菜单的控件使用 X 请求右键操作。

| 框架文件 | 接入职责 |
|---|---|
| `frontend/party_frontend.tscn` | 承载按可用空间缩放的前端页面。前端弹窗和通用弹窗挂在主场景的全窗口 DialogHost 下，遮罩铺满窗口，面板按窗口中心定位 |
| `frontend/party_frontend.gd` | 真实连接、Catalog、玩家资料、准备/开始、预设与页面导航；固定高度单行 Label 垂直居中、状态徽标水平居中 |
| `components/settings_page.gd` | 继承源设置页，仅调整宿主容器尺寸和底部操作区 |
| `party_system_settings.gd` | 系统设置草稿、取消、默认值及保存后应用 |
| `party_protocol_page.gd` | 协议目录、独立草稿、revision 校验、偏好与形象入口 |
| `party_config_form.gd` | 按业务 Schema 的 fields/layout 组合同行控件、最多三级层级、继承与条件禁用，维护全部分类的草稿 |
| `settings/settings_workspace.tscn` | 本地设置统一布局：顶部横向分类及左右导航、左侧设置列表、右侧上下文说明、底部操作栏 |
| `party_dialog.gd` | 绑定 party_dialog.tscn 中的面板、标题和按钮，承载可滚动或填满窗口的业务内容、焦点隔离与顶层弹窗 Esc 关闭 |
| `minigame_browser/minigame_browser.gd` | 小游戏列表行高亮与入池勾选分离，支持范围高亮及批量勾选、单游戏预设、临时规则草稿与高级设置；右侧预览读取包 cover，缺失时显示占位图 |

## 正式入口行为

- 创建房间：先选已安装协议，再选兼容的大游戏；第二步填写房间名称、端口并选择监听网卡 / IP，再调用 `host_from_ui`。隐藏并禁用“全部网卡”，必须选择具体本机 IPv4/IPv6；首次打开或保存的是通配地址时显示“请选择监听网卡 / IP”，未选择不能建房。刷新保留选择，已消失的地址显示为不可用，必须重新选择。链路本地 IPv6 不列出。成功建房时保存 `connection/host_bind_address`，下次恢复；隧道的本地转发目标需与监听 IP 匹配。返回上一步不会建房，房间建立后固定协议与大游戏，规则在大厅配置。
- 加入房间：地址直连使用一个输入框，支持 `192.168.1.10:7777`、`example.com:7777`、`[2001:db8::1]:7777`；省略端口时使用 7777，裸 IPv6 始终作为完整地址。DNS 主机名支持 ASCII / Punycode（含 localhost），由 ENet 解析；端口范围为 1–65535，不接受 URL 或路径。解析后调用 `join_from_ui`，收到大厅快照后切页。上次地址仍按 address / port 保存，打开输入框时合成为完整端点。
- 大厅：加入者自动跟随房主的大游戏与协议，显示真实玩家和准备状态；客户端准备/取消准备送到房主；开始仍由原协调器和就绪校验决定。小游戏池与配置沿用大游戏的轮换入口。
- 主菜单保留监听测试、连接测试及系统设置，移除独立协议选择入口。系统设置的玩家身份页显示并允许复制持久 `player_id`；不随房间或协议切换而改变。
- 头像和形象属于协议资料：原版协议使用其自有头像资源。进入房间后从本人资料或协议设置编辑；主菜单仅编辑昵称，不提供全局头像选择。
- 大游戏、小游戏池、协议规则、预设、资料、内容安装、存档恢复、排名总览均保留现有业务接口。框架业务弹窗改用源组件宿主。
- 客户端房间配置只读；房主配置经原协调器提交。UI 不复制网络、经济或存档规则。
- 房间发现、密码和好友可见性仍明确禁用，不显示模拟成功。

## 设置 API

框架宿主实例化 `res://core/ui/components/settings_page.tscn`。组件提供：

- `configure(tabs: Array) -> bool`，错误见 `last_error`；稳定且唯一的 tab/option ID。
- `add_tab` / `add_option`、`get_value` / `get_values`、`set_value(id, value, notify = false)`。
- `get_control` / `get_number_control`；数值框提交由框架 Apply 处理。
- `setting_changed(id, value)`、`back_requested()`；单项 `callback(value, id)`，动作项 `callback(id)`。
- 支持 `label/select/toggle/number/slider/note/divider/action/group/keybinding/bindings_header`，下拉项为 `{label, value}`，组用 `children`，条件显隐用 `visible_when`。
- 框架额外提供 `actions: HBoxContainer` 放入保存/默认按钮，`focus_back()` 恢复返回按钮焦点，`add_content(tab_id, content)` 将配置表单加入已有页签；重新 configure 会释放旧表单。

组件只维护草稿，不保存、不操作 InputMap、不联网。系统 Apply 先写配置，成功后才应用；写入失败恢复内存并保留草稿。协议切换保留各自草稿，返回丢弃未应用部分，恢复默认仅取消显式覆盖，Apply 才持久化。

源 `keybinding` API 接受两个带修饰键掩码的逻辑键整数。业务表单使用 `settings/binding.tscn` 和 `binding_slot.tscn`：主按键、备用按键最多两个记录，保存 `{kind, code, physical}` 与可选 ctrl/alt/shift/meta，不强转为源整数格式。键盘通过录入按钮修改，鼠标按钮通过下拉枚举修改；Esc 取消录入，独立清除按钮清空槽位，Delete/Backspace 可绑定。combinations:false 只允许录入单键；readonly:true 固定键只显示主槽，不能修改或持久化。

系统、协议页、游戏偏好和房间规则实例化 `party_config_form.tscn` 后调用 configure。configure(value, editable, context) 的 context 包含 schema、audience；需要继承的页面另传 base、overrides、inherit 和 inherit_label，按阶段锁定的字段传 locked。get_value() 返回有效值，explicit_values() 返回待保存的显式值。表单只维护草稿，业务调用者负责 Apply。

Schema 由业务 settings.gd 的 schema() 声明，通过 fields 的 type/control 和 layout 生成 `settings/` 下的预制体：toggle、select、text、number、numbers、switches、color、path、binding。单选统一下拉；数值统一数字框加有界滑条；多选复用开关组；区间/分量复用紧凑的 number_component；文件/目录使用原生选择器；主键和备用键各占一行。setting_section 的名称、控件、继承开关同排，有 children 才显示折叠箭头。继承或 enabled_when 不成立时禁用编辑并保留草稿。

系统设置、协议设置和游戏本机偏好由 settings_workspace 承载。顶层分组成为分类标签，分类下最多三级；支持字段 children。add_form(form, prefix) 接入表单，add_page(title, content, description) 接入资料/内容操作页，actions 与 tools_row 分别放置底部操作和顶部辅助控件。右侧说明由表单 help_requested 更新；分类切换保留草稿，“恢复默认设置”重置本页可编辑草稿，点击应用后保存。游戏本机偏好通过同一全屏页面打开。旧 components/settings_page 仍保留原源组件 API，本地 Schema 设置不再经它转换 option 格式。

弹窗打开时隔离背景键盘焦点和玩法输入，关闭恢复焦点；未保存的业务草稿仍由对应配置会话管理。

## 验证入口与边界

旧 UI 集成脚本已退役归档。当前验收从正式主菜单和大厅检查设置草稿、只读状态、弹窗焦点、建房/直连、准备和离开；测试资料与输出统一位于 tmp/test/。

人工验收请 F5 运行正式入口。当前大富翁为视觉原型，没有正式大游戏 manifest，正式建房禁用是预期行为。自动化和截图检查不能替代多人手动体验、2K/4K/超宽屏实机验收或外网/Steam 验收。
## 系统设置的实际效果

“显示模式”提供窗口化、无边框全屏和独占全屏。窗口化分辨率支持 1280×720、1366×768、1600×900、1920×1080、2560×1440、3840×2160；窗口居中，超过屏幕工作区时缩小实际窗口但保留选择。无边框全屏使用 Window.MODE_FULLSCREEN，铺满整个显示器（包括任务栏区域）；独占全屏使用 Window.MODE_EXCLUSIVE_FULLSCREEN。两种全屏均使用当前屏幕分辨率，对应分辨率设置自动折叠并半透明禁用，保留窗口化草稿；退出全屏恢复窗口化的分辨率和边框。这里不修改游戏的 3D 渲染比例。

垂直同步调用目标窗口的 DisplayServer API，帧率上限直接应用 Engine.max_fps。两者共同影响帧率；窗口驱动不接受 VSync 选择时显示实际结果。仍先保存，再应用；取消和恢复默认草稿不会操作窗口，存盘失败也不会改变实际效果。启动时重新读取并应用已保存选择。

当前 JSON 的 display 对象保存 mode（windowed=窗口化、borderless=无边框全屏、fullscreen=独占全屏）、resolution（[宽,高] 数组）、vsync 和 fps；消费时转换为 Vector2i。无效文件或值明确报错，首次初始化才使用默认值，偏好读取不写盘。不提供旧 CFG 读取或迁移。

在本地设置的“声音与设备”中，可分别选择麦克风和扬声器／耳机，并选择自由麦或长按 V 开麦。“刷新音频设备”重新枚举设备并保留整页草稿，断开的选择标为“不可用”。应用并保存后，语音、游戏声音和 CoreUI 提示音共用所选输出。输出缺失时保留偏好并提示，麦克风缺失时仍可收听。“试听提示音”使用已应用的输出设备和 CoreUI 音量，音量为 0 时静音。

“声音与设备”先显示“播放”，可选择输出设备、调整提示音量、试听提示音，以及刷新播放和录制设备列表。“录制”包含输入设备、麦克风授权、开麦模式和麦克风检测。点击“开始监听”可通过耳机听自己的声音，并观察输入电平。收起录制区域或离开该标签页会停止监听。若更换了设备或刚开启麦克风授权，请先应用保存。

编辑器内嵌运行时保存模式/分辨率，并明确提示关闭“嵌入游戏”后运行；不会把受编辑器限制的窗口尺寸谎报为已生效。窗口模式实现采用 [Godot Window API](https://docs.godotengine.org/en/stable/classes/class_window.html)。

旧显示设置脚本已退役归档。窗口化/全屏往返、VSync、限帧和设备音量使用正式设置页人工检查，不能用旧脚本的 PASS 代替验收。

## 图标按键提示

单行预制体为 core/ui/ambient_reveal/components/navigation/action_prompt.tscn，采用 Kenney 图标组加操作说明。action 读取当前 InputMap 绑定，组合键用 + 分隔、备用绑定用 / 分隔。keyboard_icons、gamepad_icons 可直接指定 Texture2D 数组，优先于 action，适合 WASD、摇杆等组合手势。description 设置说明，icon_size 设置图标高度。set_gamepad(bool) 切换键鼠／Xbox；修改映射后调用 refresh()。素材没有对应图案的罕见键使用通用键图标，绑定名称保留在提示信息中。

纵向预制体为 core/ui/ambient_reveal/components/navigation/vertical_hints.tscn。在全屏 HUD Control 或 CanvasLayer 下实例化，默认使用 24 像素边距贴左下角；Inspector 的 Side 选择 Right 后贴右下角，每行仍保持图标在说明前。Prompts 下预置移动、交互和菜单三行，开启可编辑子节点后可以修改或复制这些 ActionPrompt。示例的 WASD、鼠标左键、Esc 和 Xbox 图标是显示配置，需按游戏实际绑定调整。

Gamepad 可在编辑器中预览手柄图标，Follow Input Device 默认开启，在运行时随键鼠／手柄输入切换，也可关闭后由宿主调用 set_gamepad()。组件不接管游戏输入。主菜单底部提示条和协议准备提示已使用同一套图标组件；在小游戏 HUD 中使用纵向提示时，遵循 party_minimal_hud 的框架提示收起约定。

## 内容包浏览

主菜单的“内容包”打开 `core/ui/content_browser/content_browser.tscn` 固定页面，按协议、主游戏、小游戏分类，并支持名称或 ID 搜索。选中内容包后显示版本和本机配置路径；“配置本机设置”复用偏好设置页，显式应用后写入 JSON。主游戏使用绑定协议，小游戏可选择已安装且适配的协议。无可用协议时只编辑自身设置，保留已有协议覆盖文件。房主规则仍由大厅配置。

大厅右栏以 16:9 预览图和主游戏设置卡片组成。轮换包的 `preview.svg` 是可替换的占位封面，同时登记为 manifest 的 cover；`room.tscn` 直接引用，编辑器可预览。卡片首行并列轮换模式下拉框（顺序轮换／随机轮换）和小游戏池按钮，下方整行主游戏高级设置打开完整房间规则。房主切换模式后立即应用并同步，客机只读显示。
