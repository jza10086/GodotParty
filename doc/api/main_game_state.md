# 大游戏状态与结算

大游戏入口仍可使用普通 Node。需要实现：

```text
party_setup(api, settings)
create_new_state(settings) -> Dictionary
restore_state(state)
create_view() -> Node
reduce_round_result(old_state, result) -> Dictionary
party_start()
party_suspend()
party_resume()
party_stop(reason)
```

create_new_state 仅在新会话房主调用。restore_state 只应用权威快照，不再发放奖励。
create_view 返回尚未挂树的视图，由框架全尺寸内容容器承载；布局边距由内容自身声明。普通状态提交调用 restore_state 并发出 state_committed，不替换视图，视图需更新已有控件并保持焦点与滚动位置。进入小游戏时释放视图，返回时重建，控制器持续存在。
权威状态只取显式提交记录；主游戏入口不再要求 get_state。PartyRoomAPI.get_state 仍供房间界面读取快照。
非持久的 UI 动画、相机和临时对象不应放进可保存状态。

## 跨轮常驻面板

需要在小游戏运行期间收信、保留草稿或查看资料的面板，可以挂在主游戏 `game.tscn` 的控制器下。将继承 `res://core/ui/party_dialog.tscn` 的面板放在 CanvasLayer 63，加入 `party_main_menu_panel` 组，并在就绪时设置非空 `title`。打开共享 Esc 菜单时，框架按标题列出当前主游戏控制器下的面板。选中后沿用模态输入和鼠标管理，关闭返回菜单，加载切换时收起。普通游戏 HUD 应位于面板下方。

面板在主游戏的准备阶段连接其 PartyAPI，随控制器销毁。放在 `create_view()` 中的节点进入小游戏时会释放。每个玩家的临时界面数据放在本地节点上，定向消息使用 `api.net.send_to_player()`，从接收信号的 `sender.player_ids` 取得发送者身份。轮换包的 `communications.tscn` 是可运行的例子。

## 提交

普通回合先计算 next_state，再调用 commit_state；保存成功后 core 调用 restore_state 并广播。
小游戏结果经过所选适配器和协议校验，再由房主调用纯函数 reduce_round_result。
状态与已处理轮次写在同一存档记录中，保存成功才发布。

reducer 不能发消息、写文件或直接播放奖励。重复 finish 不重复执行已接受提交；
写入失败保留同一候选，重试不重新归约。失败或取消恢复上一份已提交状态。

金币、胜利点、筹码及奖励只属于大游戏。协议可以描述额度预留、最终额度与退款；
排名本身不代表资金结算。没有对应资源的大游戏不能伪造协议兼容。

## 展示数据

可选 presentation：

```json
{
  "title": "最终排名",
  "columns": [{"key":"points","title":"积分","format":"integer"}],
  "rows": [{"player_id":"persistent-id","rank":1,"status":"完成","metrics":{"points":30}}]
}
```

队伍行使用 team_id、name 和 members，包含稳定 player_id。名次由作者提供，可并列、跳号或用 0 表示未排名。
框架按作者名次展示，0 放在已排名后；并列行保留作者顺序，不重算名次和奖励。没有展示数据时不猜测业务字段。
publish_standings 同时控制游戏内 Tab 面板的玩家顺序、名次和成绩列，以及 F3 总览；子游戏运行期间仍使用父主游戏最近发布的成绩。Tab 保留网络统计，团队成绩展开到对应成员，未提供成绩的玩家列在末尾。开始或恢复会话时主游戏应发布当前成绩，持久化结算后再更新；返回大厅不沿用上一会话成绩。finish_session 保存终态。
小游戏结果直接交回父实例，不强制弹出阻断父流程的成绩页。

`finish_session` 持久化成功后，应用以全屏页面展示最终排名和“返回大厅”按钮；共享房间同时回到大厅并重置客机准备状态。每位玩家独立关闭自己的结算页，不断开连接，也不关闭其他玩家的结算页；客机返回后需要重新准备才能开始下一轮。房主离开房间仍按既有规则结束房间。

## 恢复

双槽存档使用 GPTYSAV3 包头、长度、结构和提交序号校验，不计算文件哈希。两个已存在槽位都必须有效，读取较新记录；任意槽位损坏或不可读都会明确报错，不静默退回旧槽位。GPTYSAV2 不自动迁移或回退，旧文件保留供人工处理。保存包含状态、轮次、内容版本、
配置、池、原玩家及协议形象快照。恢复需要原房主身份、匹配内容和全部原玩家。
恢复重新建房；正在运行的小游戏不会被恢复。已保存未广播的结果不会重复发奖。

协议可实现同步 `present_result(result, request) -> Dictionary`。core 校验展示结构并随状态保存。
大游戏在 round_committed 后可调用 `api.show_results(api.get_round_presentation())`。
这只打开本端公共成绩页；其他客户端何时展示由大游戏通知，框架不会自动阻断子游戏返回流程。

父主游戏可以订阅本机 `api.foreground_child_attached(root, scope_id, config)`。该信号在子场景和协议效果挂载后、技术准备屏障前发出。以子根节点的 `tree_exiting` 结束本次绑定。谱面等玩法必需的音乐可在子游戏根节点加 `party_gameplay_music` 组，轮换会在整局让出音乐。
