# 源码与 PCK 内容包

启动时只枚举各分类的直接子目录并读取 manifest，按 ID 登记及分配网络通道。协议、主游戏与小游戏须声明 localization；显示文本时按需读取包内 PO，访问设置时才加载设置脚本。发布源码 ZIP 或 PCK 时检查该包的完整声明、设置与翻译。见 [本地化](localization.md)。

完整开发工程保留 core/、games/、doc/、addons/；测试专用内容只放在 tmp/test/，不属于发布包。源码包位于 games/{protocols,maingame,minigame}/<id>/；形象包位于 games/protocols/<protocol_id>/avatars/<id>/，其清单声明 owner_protocol。manifest.json 是唯一作者维护的内容目录项，包 ID 全局唯一。

玩家安装目录见 [配置与预设](configuration.md)。协议、maingame、minigame 分别放入对应根文件夹，每包单独目录，包含 content.pck 和 content.pck.json；形象包放入所属协议 avatars/。替换版本时只替换这两个生成文件，保留 config/。安装、删除、更新及来源切换后重新启动，不做热替换。

编辑器 Tools → GodotParty 支持源码 ZIP 和 PCK 导出；导出前完成资源导入。单独导出选择任意 PCK 文件名后，可由主界面内容包安装器复制到标准 content.pck 名称；手动安装必须将文件及描述中的 artifact 统一为 content.pck。批量导出脚本 core/dev/export_content.gd 自动生成标准目录。

描述格式 2 包含构建信息、包 ID/版本/类别、文件路径索引、UID 索引，形象包另含 owner_protocol；不含文件哈希。框架检查目录归属、声明路径、UID 冲突、核心/引擎版本、挂载后清单及依赖版本。协议 PCK 不重复包含 avatars 子包。房间比较包版本与配置快照；相同版本号不证明文件字节相同，作者修改内容后必须更新 package_version。

若同 ID 同时有源码和 PCK，必须在内容包来源中明确选择，或使用 --party-source=<id>:source/pck 后重启。--party-pack-dir=<安装根目录> 支持隔离验收，里面仍使用三个分类目录。源码与 PCK 保持相同 res://games 虚拟路径；用户局部配置不放入 PCK。

dependencies 是包 ID 到精确 package_version 的映射。小游戏 adapters 的依赖只在选中接入时激活。公开资源通过 package_id/resource_key 引用。不要预加载未选协议或依赖另一份 core；普通内容只引用公开 core/api、core/ui 契约。内容使用普通 Godot 脚本能力，加载检查不是安全沙箱。

## Windows 导出脚本

使用 PATH 上的 godot 和匹配的导出模板：

```powershell
./core/dev/export_windows_host.ps1
./core/dev/export_windows_minimal.ps1
```

标准宿主脚本创建 tmp/ 下的隔离副本，只输出内嵌核心 PCK 的 GodotParty.exe，分类安装空目录及 core/notices 中的引擎许可。无控制台启动器、外置框架 PCK、开始游玩.txt。核心设置保存在 core/config/，玩家无需移动核心文件。

最简脚本复制原版协议、协议形象、小游戏轮换、身份派对，副本将玩法限定为阿瓦隆（5–8 人）及默认一局。它先将这四个内容包导出到各自安装目录，再从框架 EXE 中排除 games/。开发源码玩法不改变；本机配置、存档和导入缓存不进入发行目录。必要第三方许可集中于 core/notices，最终 ZIP 位于 tmp/windows_minimal_<时间>/。

脚本默认读取系统 Godot，不锁死单独引擎版本，不进行项目升级。模板须由用户安装。导出成功不等于设备验收；发布前还须在无作者源码和导入缓存的干净宿主中验证正式大厅、内容加载与结果返回。

当前实现改动没有执行导出或生成新发行包。
