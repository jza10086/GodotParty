# 源码与 PCK 内容包

启动时只枚举各分类的直接子目录并读取 manifest，按 ID 登记及分配网络通道。协议、主游戏与小游戏须声明 localization；显示文本时按需读取包内 PO，访问设置时才加载设置脚本。发布源码 ZIP 或 PCK 时检查该包的完整声明、设置与翻译。见 [本地化](localization.md)。

完整开发工程保留 core/、games/、doc/、addons/；测试专用内容只放在 tmp/test/，不属于发布包。源码包位于 games/{protocols,maingame,minigame}/<id>/；形象包位于 games/protocols/<protocol_id>/avatars/<id>/，其清单声明 owner_protocol。manifest.json 是唯一作者维护的内容目录项，包 ID 全局唯一。

玩家安装目录见 [配置与预设](configuration.md)。协议、maingame、minigame 分别放入对应根文件夹，每包单独目录，包含 content.pck 和 content.pck.json；形象包放入所属协议 avatars/。替换版本时只替换这两个生成文件，保留 config/。安装、删除、更新及来源切换后重新启动，不做热替换。

编辑器“项目 → 工具”只提供“GodotParty：导出 Windows 可玩包”和“GodotParty：导出 Android 可玩包”两个入口。窗口内勾选内容并选择输出目录；不勾选核心即可仅导出独立内容更新。导出前完成资源导入，导出器跳过含 .gdignore 的目录及其整个子树，不收集其中的旧原型、资源和导入映射。批量导出脚本 core/dev/export_content.gd 自动生成标准目录和 content.pck 文件名。

描述格式 3 包含构建信息、包 ID/版本/类别、文件路径索引、UID 索引和 script_classes 类型清单，形象包另含 owner_protocol；不含文件哈希。框架检查目录归属、声明路径、UID 和类型名冲突、核心/引擎版本、挂载后清单及依赖版本。协议 PCK 不重复包含 avatars 子包。房间比较包版本与配置快照；相同版本号不证明文件字节相同，作者修改内容后必须更新 package_version。

若同 ID 同时有源码和 PCK，必须在内容包来源中明确选择，或使用 --party-source=<id>:source/pck 后重启。--party-pack-dir=<安装根目录> 支持隔离验收，里面仍使用三个分类目录。源码与 PCK 保持相同 res://games 虚拟路径；用户局部配置不放入 PCK。

dependencies 是包 ID 到精确 package_version 的映射。升级协议时，须检查全部已安装主游戏、小游戏及适配器的依赖；确认调用契约后同步依赖值，并递增修改过的内容包自身版本，再成套导出。不要只改导出描述文件的版本号，因为实际清单在 PCK 内。小游戏 adapters 的依赖只在选中接入时激活。公开资源通过 package_id/resource_key 引用。不要预加载未选协议或依赖另一份 core；普通内容只引用公开 core/api、core/ui 契约。内容使用普通 Godot 脚本能力，加载检查不是安全沙箱。

独立内容包支持直接使用 `class_name` 注册的类型，例如 `var audio: PartyGameAudio`。导出器从已导入的类型信息中只提取本包实际打包的脚本，生成 script_classes；作者不维护第二份注册表。共享组件、资源和核心数据类型才注册全局名称，名称必须在整个安装中唯一。跨包引用须声明相应依赖，不要引用未安装的可选协议。

启动时先校验全部描述和类型继承关系，再挂载普通 PCK、校验清单与依赖，最后合并核心及所选内容的类型注册信息，完成注册后才加载内容脚本。普通 PCK 仍不覆盖框架资源；只有框架生成的注册表 ZIP 覆盖 `.godot/global_script_class_cache.cfg`。这不需要把整个开发工程的缓存塞入核心。生成文件位于安装目录 `tmp/content_classes/<进程ID>.zip`，每次启动重建，全部实例退出后可以删除该缓存目录。

从旧描述格式升级时，须重新导出核心及所有已安装内容包；旧格式会明确拒绝加载。manifest 格式仍为 2。完成这次升级后，普通小游戏更新仍可单独导出并替换其 content.pck 和 content.pck.json；若改变依赖版本，须一起更新对应依赖。退出游戏后更新并重新启动，保留 config/。新增或修改全局类型后，发布验收应覆盖实际导出的 EXE 创建房间和受影响小游戏入口，不能只依赖编辑器运行。

## 可视化 Windows 导出

编辑器打开“项目 → 工具 → GodotParty：导出 Windows 可玩包”。界面只需勾选核心、协议及形象包、主游戏、小游戏，再选择输出目录。点击开始导出后显示进度、错误和构建日志目录。

勾选内容会自动补齐精确版本依赖、所属协议以及小游戏适配器的协议和依赖；自动勾选项标注“依赖”。导出会包含所选小游戏的全部已声明适配器依赖。主游戏的小游戏池由房主在运行时选择，导出主游戏不会自动打包所有候选小游戏。仅勾选内容可生成独立更新包，勾选核心时同时构建 Windows x64 EXE。

原版协议包含两个独立形象包。godot_party_default_avatars_2d 提供六个 2D 头像，godot_party_default_avatars 提供 Cube 3D 占位。包均位于 protocols/<协议ID>/avatars/<包ID>/，默认依赖会一起勾选。旧玩家资料中的协议内头像引用需在个人资料界面重新选择并应用。

选择项目外目录，或本项目 tmp/releases/ 下的目录（验收产物可放 tmp/test/）。后台使用 PATH 上的 godot 和匹配的 Windows 模板，在 tmp/exports/ 下构建核心副本、日志和中间产物。核心副本排除内容、开发插件、个人 JSON 配置和存档，并关闭场景文本到二进制转换以保留嵌套 UI。不会启动项目升级。

全部构建成功后才写入输出目录。已有 EXE、content.pck 和 content.pck.json 成套更新；已有配置、用户新增文件与外置资源文件保留，缺少的外置资源补齐。分发更新的外置默认数据时，作者应使用新路径或指导用户显式替换。发布失败会回滚已覆盖文件，备份保留在构建目录。导出期间请关闭目标目录中的游戏；同一目标目录同时只允许一次导出。

完整安装目录可直接通过 Windows 文件资源管理器合并。形象包保留所属协议路径。首次分发时不要附带测试启动生成的 core/config/settings.json，避免复制 player_id。应用偏好后生成的 JSON 位于各包 config/ 下，退出游戏后可以手动编辑。

core/dev/export_release.ps1 是窗口使用的同一后端，接收 RequestPath 指向的 JSON。请求包含 core 布尔值、output 绝对目录和 packages 包 ID 数组。export_windows_host.ps1 可单独构建核心；export_windows_minimal.ps1 是原版轮换与阿瓦隆的预设，复用同一后端和依赖计算。运行后仍需检查正式菜单、设置和实际开局；导出成功不等于多人或外网验收。

## 可视化 Android 导出

通常使用 Godot 编辑器设置中的 SDK 路径。若运行中的编辑器反复写回旧 SDK 配置，可在本机 `tmp/local/android_export.json` 写入 `{"android_sdk_path":"F:/AndroidSDK"}`。可视化导出器会提前检查该目录，并在隔离的 APK 导出进程内应用此路径；该文件不提交、不进入可玩包，也不增加导出窗口选项。没有此文件时仍使用编辑器设置，存在但无效时明确失败，不自动猜测 SDK 位置。

编辑器打开“项目 → 工具 → GodotParty：导出 Android 可玩包”。仍只需勾选内容和选择输出目录，依赖选择规则与 Windows 相同。勾选核心会生成 `GodotParty.apk`，同时生成 `GodotParty-content-android.zip`；不勾选核心则只生成内容 ZIP，用于单独更新小游戏。后端请求增加 `platform: "Android"`，省略时仍导出 Windows。

当前 APK 是 ARM64、横屏、调试签名的测试包，使用本机 Godot 已配置的 Android SDK、Java 和匹配导出模板。导出器在隔离工程中导入 Android 资源，使用 Compatibility 渲染器，并启用屏幕触摸模拟鼠标左键；不会把触摸变成键盘操作，也不提供虚拟摇杆。需要键盘或鼠标右键的小游戏仍须另行适配。初版选择小游戏轮换与竞拍大师。

APK 内置所选内容 ZIP；首次启动在应用私有存储中安装各包，再挂载 PCK 和注册 `class_name`。每个新 APK 构建首次运行会更新内置内容，已有 config/ 和已存在的外置数据文件保留，缺少的默认外置文件补齐。内容安装前校验平台、描述和路径，失败时报告原因。独立 ZIP 也使用相同目录与校验，不将配置打包。

Android 不使用 Windows 文件资源管理器直接合并安装目录。在“内容包”中选择 Android 内容 ZIP，完全退出应用再打开后生效，不热替换正在使用的 PCK。原生文件选择器要求 Android 10 或更新系统；系统配置 JSON 可在此导出、编辑并导入，玩家身份保留。游戏偏好仍通过游戏内设置修改。覆盖安装 APK 时需保持包名与签名；卸载或清除应用数据会删除配置。

APK 构建成功仅证明导出流程完成。真机验收需检查首次启动、创建/加入房间、竞拍大师触摸操作及再次启动后的配置保留。

## 外置文件与目录

内容作者在 manifest.json 的 external_files 数组声明包内相对路径，目录必须以 / 结尾，文件不带结尾 /。例如 "external_files": ["charts/", "maps/default.json"]。省略时表示没有外置数据。路径大小写应与磁盘一致，不支持通配符、上级路径、链接、重叠声明及 config/、avatars/、manifest.json、content.pck、content.pck.json 等保留位置。

声明的文件和目录必须存在，空目录保留。导出器把它们原样复制到包安装目录，保留层级，并从 PCK 排除相应文件、UID 与导入映射。包内 config/、隐藏目录、备份和临时文件不发布。工具生成的描述文件记录 external_files 和 external_directories；启动和安装时检查这些数据是否齐全。使用内置安装器安装外置资源包时，PCK、描述文件和外置内容必须按原相对位置放在一起。

游戏通过 api.get_external_path("charts") 或 api.get_external_path("maps/default.json") 获取本包声明范围内的绝对路径。编辑器运行返回源码包下的位置，导出运行返回安装目录；--party-pack-dir 验收目录也被支持。此接口不创建文件，未声明路径明确报错。FileAccess、DirAccess 可直接使用返回路径；原始 PNG、OGG 等应使用支持运行时文件的加载 API。预加载资源仍须放在 PCK 中，不能将预加载所依赖的文件改成外置。

普通场景、贴图和脚本按包内相对结构装入 PCK。外置声明用于确实需要用户编辑、扩展或通过文件系统读取的数据。作者负责文件格式校验，文件内容不参与联机一致性比较。
