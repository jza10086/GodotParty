# 极简连通性测试客户端

用系统 Godot 打开 `project/project.godot`，运行主场景即可使用。它是独立工程，父目录的 `.gdignore` 让正式游戏不会导入或打包此工具。没有游戏内容、原生插件或配置持久化，也可以通过 Android 预设导出独立 APK。

1. 在 GodotParty 主界面打开「监听测试」，选择 UDP 或 TCP、地址族及端口，开始监听。UDP 还需选择本机监听 / 回包 IP。
2. 选择实际联网网卡的 IPv4 或 IPv6，复制客户端链接。回环地址只供本机使用，链路本地 IPv6 暂不支持。
3. 客户端粘贴链接，或分别填写 IP 和端口，选择相同协议，开始测试。
4. 每次探测最多等 3 秒，正常情况下每秒一次。成功必须匹配完整回复；停止时尚未完成的探测计为取消。TCP 每次建立新连接，RTT 包括连接时间，不能直接等同于 UDP RTT 或 ICMP ping。
5. 可复制统计结果。进入后台自动停止，返回前台需手动开始；Android 返回键停止当前测试。

界面采用竖屏滚动布局、大按钮、系统字体、可见区域及软键盘避让。无需保存设置或申请存储权限。Windows 上可直接在 Godot 编辑器运行同一工程；尚未生成 Windows 包。

## Android 导出准备

已提供 Android ARM64 导出预设，并开启 `INTERNET`、ETC2/ASTC 纹理导入及应用图标。导出需要本机安装匹配的导出模板、JDK / Android SDK，并配置签名；此仓库不保存签名密码或凭据。安装与真机网络权限、软键盘、系统字体显示仍需真机验收。

当前预设使用预编译模板，不使用 Gradle。此次构建使用 Platform Tools 37.0.1 和 Build Tools 35.0.1，无需 Android Studio、NDK 或 CMake。Godot 的 Android SDK Path 应指向同时含有 `platform-tools/` 和 `build-tools/` 的目录，例如 `F:/AndroidSDK`。

导出的调试签名 APK 可直接发给使用 ARM64 安卓手机的玩家安装测试，无需在手机上安装 Godot。安装时按系统提示允许所用文件管理器或浏览器安装应用；该测试签名包不用于应用商店发布。

参考：[Godot Android 导出文档](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)、[PacketPeerUDP 的 INTERNET 权限要求](https://docs.godotengine.org/en/stable/classes/class_packetpeerudp.html)。将来提高 Android target SDK 时，也需检查该版本的本地网络权限要求。

协议见主项目的 `doc/connectivity_test.md`。`project/probe_protocol.gd` 是该协议的独立副本；修改协议时同步两份实现和网络回归检查。客户端不依赖父项目目录，可以整份复制 `project/` 后独立打开。

PC 主界面的「连接测试」提供相同的主动探测功能。`project/probe_client.gd` 与主项目 `core/network/connectivity/probe_client.gd` 保持同一实现，仅协议脚本的资源路径不同。

## iPhone / iPad：GitHub Actions + SideStore

同一项目提供 `iOS SideStore` 预设，目标为 iOS / iPadOS 15+、真机 ARM64、iPhone 和 iPad 通用。UDP/TCP、IPv4/IPv6 和 PC 使用相同协议。界面适配安全区域、键盘和 iPad 宽屏，进入后台停止探测。应用没有账号、存储或后台运行需求；访问局域网需要允许“本地网络”。第一次权限询问可能让本轮探测超时，允许后可停止并重新开始。

仓库根目录 `.github/workflows/build-connectivity-ios.yml` 支持手动构建；向 `main` 推送客户端或此工作流的修改也会自动构建，其他游戏文件的修改不会触发：

1. 将此工作流以及整个 `tools/connectivity_client/` 提交到 GitHub 仓库默认分支。也可以仅把这两部分保留原目录结构上传到独立仓库，不需要上传游戏内容。
2. 在 Actions 中选择 **Build connectivity client for SideStore → Run workflow**。Godot 版本默认 `4.7.2`，与本次本机版本一致；项目手动升级后再调整此输入。工作流下载同版本编辑器和 iOS 模板，只在 macOS runner 中编译。
3. 成功后下载 **GodotParty-Connectivity-iOS-SideStore** artifact，解压取得 `.ipa`、`INSTALL.txt` 和 `build-info.json`。另有构建日志 artifact。工作流不会创建 Release，也不需要 Apple 密码、付费证书或任何仓库 Secrets。
4. 首次在 iPad/iPhone 安装 SideStore：按其官方说明，用 Windows + USB + iloader 安装，完成信任开发者、开发者模式、LocalDevVPN 和 Apple 账号设置。然后在 SideStore 导入 `.ipa`，由设备自己的账号重新签名安装。
5. 免费账号通常每 7 天需要刷新签名，最多同时启用 3 个应用（包含 SideStore）。安装/刷新需要按 SideStore 要求开启 LocalDevVPN；实际测试前建议关闭它，避免额外 VPN 配置影响排查。
6. PC 打开“监听测试”，匹配协议、地址和端口后开始监听；在 iPad 粘贴连接链接并开始。UDP 必须填写 PC 实际绑定的监听/回包 IP。

该 IPA 只有构建用 ad-hoc 签名，没有 Apple 分发证书和设备描述文件，必须通过 SideStore 重签；不是 TestFlight 包，也不能直接点击安装。`0000000000` 是满足 Godot 工程导出要求的占位 Team ID，编译时禁用正式签名，最终由 SideStore 替换。这里的 ad-hoc 签名也不是苹果付费的 Ad Hoc 分发方案。

构建脚本 `build_ios.py` 使用 PATH 中的 `godot`（可通过 `--godot` 指定已安装的命令）和 Xcode，在新的输出目录复制项目后构建，不修改源工程，也不删除旧产物。在 macOS 上可运行：

```sh
python3 tools/connectivity_client/build_ios.py --output "$PWD/tmp/ios-build" --build-number 1
```

GitHub CLI 已登录且有仓库 Actions 权限时，可以在 Windows 触发和下载：

```powershell
gh workflow run build-connectivity-ios.yml --repo jza10086/GodotParty --ref main -f godot_version=4.7.2
gh run list --repo jza10086/GodotParty --workflow build-connectivity-ios.yml --limit 3
gh run watch RUN_ID --repo jza10086/GodotParty --exit-status
gh run download RUN_ID --repo jza10086/GodotParty --name GodotParty-Connectivity-iOS-SideStore --dir tmp/ios-download
```

云端检查会确认构建退出状态、Godot 错误日志、IPA 的 Payload 结构、真机 ARM64、iPhone/iPad 设备类型和本地网络用途说明。它不代表真机安装成功或真实网络验收；SideStore 安装、中文字体、横竖屏/键盘、权限与 UDP/TCP 收发仍需 iPhone/iPad 实测。

参考：[Godot iOS 导出](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_ios.html)、[SideStore 安装要求](https://docs.sidestore.io/docs/installation/prerequisites)、[SideStore 安装步骤](https://docs.sidestore.io/docs/installation/install)、[SideStore 免费账号限制](https://docs.sidestore.io/docs/faq)。
