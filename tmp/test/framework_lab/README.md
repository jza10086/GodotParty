# 框架验证工具 · 第一批基础闭环

测试工具与正式空白模板分开：模板在 games/minigame/godot_party_default_blank/；这里的 games/ 包含测试主游戏与测试小游戏。
使用正式应用、目录校验、原版协议、真实 ENet、就绪屏障和持久化流程，不使用替代运行器或模拟 PartyAPI。

## 生成隔离测试包

在工程根目录执行（Godot 由系统 PATH 提供；不转换工程）：

```powershell
godot --version
New-Item -ItemType Directory -Force tmp/test/framework_lab/output
godot --headless --path . --log-file tmp/test/framework_lab/output/build_engine.log --script res://tmp/test/framework_lab/build.gd
```

build.gd 将这里的两个测试包映射到标准 res://games/ 虚拟路径，生成 packages/{maingame,minigame}/<id>/content.pck 及描述文件。
只打包测试源码、清单和场景，不包含用户资料或输出。没有文件哈希。模板与原版协议仍使用工程中的真实源码。
测试包的 UID 不复用临时源场景的编辑器 UID；场景使用路径引用。修改测试源码后重新构建并重启测试实例。
任何构建错误、SCRIPT ERROR、ERROR 都须调查，不能只根据退出码或 LAB_BUILD_PASS 判定无错误通过。

## 编辑器人工联机入口

使用原工程 F5 与编辑器多实例功能，在每个实例的运行参数中添加：

```text
--party-pack-dir=F:/GodotProjects/GodotParty/tmp/test/framework_lab/packages
--party-profile=framework_lab_manual_1
```

各实例分别使用 manual_1、manual_2、manual_3、manual_4 资料名；参数放在 Godot 用户参数部分。
也可以手动从终端启动同一个正式项目：

```powershell
godot --path . -- --party-pack-dir=F:/GodotProjects/GodotParty/tmp/test/framework_lab/packages --party-profile=framework_lab_manual_1
```

1. 正式主菜单创建房间，选择原版协议与「GodotPartyDefault · 框架验证」。其他实例直连该房间。
2. 在测试主游戏自己的大厅打开小游戏池，勾选「框架探针」与「空白模板」，应用；客户端准备，房主开始。
3. 进入主游戏后勾选参赛者。取消房主的勾选，可验证房主观战但仍协调；至少保留一位参赛者。
4. 点击「启动两轮测试小游戏」。在正式加载页观察就绪状态；默认延迟 0.3 秒，可在小游戏房间规则中调整。
5. 每轮由房主点击「运行通信检查」，观察回执，完成后点击结束。参赛者可发送参赛操作，观战者该按钮禁用。
6. 第一轮正式提交后自动进入第二轮。第二轮结束回到父界面，核对提交数、恢复数、旧作用域清理证据和公共成绩页。
7. 「启动两轮空白模板」用于单独检查标准模板，每轮由房主手动结束。

不传 --party-pack-dir 时，正常应用不会发现这里的测试包；无需修改正式轮换白名单。

## 自动本机检查

先生成最新测试包，然后运行下面相互独立的场景（端口 39917，不同时运行）：

```powershell
python tmp/test/framework_lab/run_network.py --count 1
python tmp/test/framework_lab/run_network.py --count 2
python tmp/test/framework_lab/run_network.py --count 4 --spectator-host
python tmp/test/framework_lab/run_network.py --count 2 --scenario blank
```

脚本使用正式主菜单的建房/加入入口及真实大厅场景，驱动两轮实际游戏；网络检查包含真实发送者身份、广播、include_self=false、定向可靠流、父子回执、客户端无权结束、参赛子集、公共成绩、持久记录数量和各端清理。
最后一个客户端延迟就绪 1.2 秒，用于观察等待屏障；其他端为 0.1 秒。只有测试小游戏读取这个显式验收参数。
旧 API 在节点释放后发送必须返回 ERR_UNAVAILABLE。检查保留弱引用，不保留旧场景；本地审计不会伪造远端证据。
每次运行有独立 output/<运行号>/ 日志；资料和存档在工程 tmp/test/profiles/framework_lab_<运行号>_<端号>/。
运行器同时检查退出码、错误文本和结束记录；45 秒超时是失败，不自动重试。

本机自动检查不代表编辑器人工多人、视觉、外网、音频、八人或干净导出宿主通过。第一批未实现资源局、语音、输入配置、异常注入和恢复测试。
单人时无远端接收者，排除本机广播明确显示“不适用”，不发送空接收范围消息，也不计为多人通过。
自动检查完成后逐端退出；同时退出不属于本批验收。开发时同时退出曾出现 ENet `Unable to send packet on channel 0, max channels: 0`，尚未定位或修复，不把逐端退出成功等同于并发断线通过。
本机受限执行环境还出现 `Failed to read the root certificate store`。即使全部功能断言通过，运行器仍保留失败退出状态；不忽略此 ERROR，也不改证书或 TLS 设置绕过它。

## 维护边界

- game.gd 为具体检查与简单面板，没有动态注册器或新测试框架。
- 新能力加入对应真实操作、预期结果和观测；保留测试 ID/语义清晰，不把发送成功当接收成功。
- 本目录测试源码与 README 显式加入 Git；packages/、output/ 和用户资料不提交。
- 不从正式模板或框架源码引用这里的路径。测试包普通内容逻辑只依赖公开 API；build.gd/network.gd 作为测试工具可检查框架内部证据。
