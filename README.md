# GodotParty 0.0.1

开发检出使用 `git clone --recurse-submodules <主仓地址>` 获取主仓记录的小游戏版本。在 `games/minigame/<id>/` 中切到小游戏自己的分支，修改、提交和推送后，重启游戏就能使用本机检出的内容。只有需要更新主仓为其他人锁定的子模块版本时，才提交版本指针。

新增小游戏可以作为独立仓库直接克隆到 `games/minigame/<id>/`，包根放置 `manifest.json`。主仓忽略这些新增目录；GodotParty 启动时会发现它们。声明兼容原版协议适配器后，就会出现在小游戏轮换的候选列表。其他开发机分别检出所需小游戏，玩家安装对应的内容包。

完整 Godot 4.7.stable 工程是开发、测试与调试环境。内容通过 PartyAPI 接入正式宿主；不再提供独立 SDK 工程。

- [文档入口](doc/README.md)
- [小游戏入门](doc/api/authoring.md)
- [公共 API](doc/api/reference.md)
- [大游戏状态与结算](doc/api/results.md)
- [协议及玩家形象](doc/api/protocols_and_briefing.md)
- [源码与 PCK 发布](doc/api/source_packages.md)

core/ 负责联机协调、注入式 PartyAPI、输入设置、内容安装挂载及基础 UI；协议包负责协议与准备/结算薄适配；主游戏负责长期状态、编排与纯归约；小游戏负责本局状态和表现。games/assets/ 是独立叶子资产包，不依赖其他资产包。avatars 位于所属协议目录下；doc/ 存放文档和作者技能。

框架 0.0.1，唯一版本来源为 core/framework_version.gd，与用户维护的 Godot 项目版本独立。原型仅支持当前格式；旧 GPActivity 接口不再是作者接入方式。

现已提供 [GodotPartyDefaultProtocol 1.0](games/protocols/godot_party_default_protocol/doc/README.md) 及默认占位形象包：玩家颜色、2D Godot 图标和 3D Cube。主菜单“协议 → 个人资料与形象”可配置。已安装[原版小游戏轮换](games/maingame/godot_party_default_maingame_minigame_playlist/README.md)，可从正式大厅创建房间，游玩水果武士、云间跃行、纸牌会客厅及心理博弈。旧测试内容恢复点为 `1a9e842`。

每个包 ID 安装一个当前版本，依赖支持精确、~ 和 ^ 范围；启动校验实际包 Hash 并缓存可用包与不可用原因。加入仅比较当前房间协议、主游戏及必需依赖的实际版本和 Hash，开始加入所选小游戏池。同版本不同内容也需要同步。更新下载为待安装 ZIP，下次启动整批验证后生效；不可用额外内容不妨碍可用房间。

同进程内容拥有普通 Godot 脚本能力；框架提供开发接口和会话协调，不是沙箱。


- [配置继承与设置作用域](doc/api/configuration.md)
- [基础语音](doc/api/voice.md)

配置支持来源/覆盖与下一轮规则快照，基础语音使用房主转发。设备听感、真机和外网结果需单独验收。

## 正式界面

唯一启动入口是 `core/app/party_main.tscn`，F5 运行正式框架。
界面使用 Ambient Reveal 原生页面和 Schema 设置组件；组件保存在 `core/ui/source/`，在 `core/ui/frontend/party_frontend.gd` 接入按钮行为，在 `core/ui/source/ui/theme/ui_config.tres` 调整全局外观。

- 创建房间 → 选择已安装大游戏、填写房间名和监听端口 → 确认后建房；同一端口同时接受 IPv4 / IPv6。
- 加入房间 → 房间页 → IP 直连 → 填写地址与可选端口 → 握手成功后进入大厅。IPv6 可填写 `2001:db8::1` 或 `[2001:db8::1]`，带 IPv6 端口时使用 `[地址]:端口`。
- 大厅显示真实玩家、准备状态和游戏配置；不填充模拟玩家。
- 设置 → 协议与游戏页签提供内容安装和房主存档恢复入口。
- 房间发现、密码和好友可见性尚未实现，界面明确禁用。

[UI 接入说明](doc/ui_components.md)。旧根目录原型入口、旧测试和重复资源已清理，恢复点为 `cf6d1e8`。

直连端口默认为 `7777`，允许 `1–65535`。创建端口与上次加入的地址/端口分别保存在本机 `settings.json` 的 connection 对象的 host_port、address / port 字段；取消弹窗不保存。大厅显示实际使用的 UDP 端口，恢复存档也使用已保存的创建端口（启动参数指定端口时优先使用参数）。

开发启动参数支持 `--party-host --party-port=17891` 或 `--party-join=::1 --party-port=17891`（放在 Godot 的 `--` 后）。同机测试使用 `127.0.0.1` / `::1`；跨机 IPv6 需使用房主可达的实际地址。房主防火墙需允许选定的 UDP 端口；IPv4 NAT 环境可能还需要路由器端口转发。项目不自动修改防火墙或路由器配置。

旧自动测试已退役归档，不再作为当前验收入口。按改动需要在 `tmp/test/` 中进行定向验证；归档与测试目录规则见 [验证与调试](doc/testing.md)。公网 IPv6 可达性及编辑器多窗口交互需要人工验收。

## 原版大游戏视觉原型

[GodotPartyDefaultMainGameMillionaire](games/maingame/godot_party_default_main_game_millionaire/README.md)：Kenney 城市素材组成的 24 格环形棋盘。打开其 `map_preview.tscn` 按 F6 查看；暂不接入大厅或实现玩法逻辑。

## 原版小游戏轮换

[GodotPartyDefault · 小游戏轮换](games/maingame/godot_party_default_maingame_minigame_playlist/README.md) 是自动连续小游戏的大游戏入口，包 ID 为 `godot_party_default_maingame_minigame_playlist`。在正式大厅配置 minigames 池，可选择顺序或随机、总局数、是否重复及局间间隔。只选一个小游戏并开启重复即可连续测试；无需逐局手动启动。关闭重复时，实际局数不超过所选小游戏数量。

玩家安装包分为 protocols/、maingame/、minigame/、assets/；框架内嵌在 GodotParty.exe。每包配置放在局部 config/，协议指定游戏覆盖目录；独立预设文件可直接重命名和分享。详见[便携目录与预设](doc/api/configuration.md)。

- [原创内容许可与第三方例外](ASSET_LICENSES.md)
- [受限资产分类登记](third_party_assets/README.md)
