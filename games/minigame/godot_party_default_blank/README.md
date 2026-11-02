# GodotPartyDefault · 空白小游戏模板

API 4 / manifest 2 / 配置 Schema 3；1–8 人；只实现原版协议 standard 普通局。
无玩法计分、道具或语音。结束时明确提交本轮 `metrics.score=0`；在线玩家并列第1，断线者未排名。父游戏奖励与本轮分数相互独立。

## 开发入口

从正常主菜单创建兼容主游戏，加入小游戏池并启动。主游戏若声明 minigames 白名单，须加入本包 ID。
要从正式轮换运行框架检查，请选择[框架测试小游戏](../godot_party_default_framework_probe/README.md)。
单独 F6 不会创建 PartyAPI；错误提示是预期行为。

## 复制为新游戏

1. 将本目录复制到 games/minigame/<新包ID>/，修改 manifest 的 id、name、introduction 和 package_version。
2. 更新 game.tscn 中的脚本路径；复制场景或脚本时不要沿用原包 UID，让编辑器为新资源生成独立 UID。
3. party_setup 在入树前执行；挂载协议加载场景，初始化后 mark_ready。party_start 仅通知技术屏障完成，等协议 play_requested 后启动玩法。party_stop 清理两个页面及消息。
4. 在 game.tscn 的 Content 容器中编辑内容，保留全屏根和容器布局。状态与结束按钮为模板示例，可按玩法替换。
5. 配置只在 settings.gd 的 schema() 中声明；确有消费逻辑后再添加字段。房间规则使用 api.get_settings()，setup 的 config 是协议请求。
6. 实现自己的结束条件与本轮分数。此模板由房主冻结并广播候选，所有客户端挂载结算场景，自动回执后倒计时3秒；只有房主在 continued 时调用 finish 一次。返回 OK 是候选已接受，正式提交由父游戏观察。
7. 需要网络时显式声明流并验证外部消息；需要其他协议或 resource 模式时实现其适配与业务语义，再声明兼容。

加载时本端技术完成后按Enter/空格准备；全部参赛者确认后默认3秒开始，观战无需人工确认。结算不再按键：所有在线端装好页面后默认3秒自动结束。两个页面始终由空白小游戏自身持有，提交前不会被父游戏卸载；不需要修改父游戏或core终态逻辑。

模板的独立运行入口由兼容主游戏的小游戏池提供。
