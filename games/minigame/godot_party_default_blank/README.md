# GodotPartyDefault · 空白小游戏模板

API 4 / manifest 2 / 配置 Schema 3；1–8 人；只实现原版协议 standard 普通局。
无计分、奖励、道具、语音或测试逻辑。房主点击结束后，全部在线参赛者以 rank=0、unranked 返回；断线者为 withdrawn。

## 开发入口

从正常主菜单创建兼容主游戏，加入小游戏池并启动。主游戏若声明 minigames 白名单，须加入本包 ID。
本模板也可以在独立框架验证主游戏中运行，见 [测试工具说明](../../../tmp/test/framework_lab/README.md)。
单独 F6 不会创建 PartyAPI；错误提示是预期行为。

## 复制为新游戏

1. 将本目录复制到 games/minigame/<新包ID>/，修改 manifest 的 id、name、introduction 和 package_version。
2. 更新 game.tscn 中的脚本路径；复制场景或脚本时不要沿用原包 UID，让编辑器为新资源生成独立 UID。
3. game.gd 的 party_setup 在入树前执行；初始化结束才 mark_ready；从 party_start 开始玩法；party_stop 停止自己创建的输入、计时器和发送器。
4. 在 game.tscn 的 Content 容器中编辑内容，保留全屏根和容器布局。状态与结束按钮为模板示例，可按玩法替换。
5. 配置只在 settings.gd 的 schema() 中声明；确有消费逻辑后再添加字段。房间规则使用 api.get_settings()，setup 的 config 是协议请求。
6. 实现自己的结束条件与结果；只有房主调用 finish。返回 OK 是候选已接受，正式提交由父游戏观察。
7. 需要网络时显式声明流并验证外部消息；需要其他协议或 resource 模式时实现其适配与业务语义，再声明兼容。

模板不依赖 tmp/test。所有功能探针、测试主游戏、断言和生成输出都位于 tmp/test/framework_lab/。
