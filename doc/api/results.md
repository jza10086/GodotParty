# 大游戏状态与结算

大游戏入口仍可使用普通 Node。需要实现：

```text
party_setup(api, settings)
create_new_state(settings) -> Dictionary
get_state() -> Dictionary
restore_state(state)
create_view() -> Node
reduce_round_result(old_state, result) -> Dictionary
party_start()
party_suspend()
party_resume()
party_stop(reason)
```

create_new_state 仅在新会话房主调用。restore_state 只应用权威快照，不再发放奖励。
create_view 返回尚未挂树的视图。进入小游戏时释放视图，返回时重建，控制器持续存在。
非持久的 UI 动画、相机和临时对象不应放进可保存状态。

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
publish_standings 更新 Tab 总览；finish_session 保存终态。
小游戏结果直接交回父实例，不强制弹出阻断父流程的成绩页。

## 恢复

双槽存档使用 GPTYSAV3 包头、长度、结构和提交序号校验，不计算文件哈希。两个已存在槽位都必须有效，读取较新记录；任意槽位损坏或不可读都会明确报错，不静默退回旧槽位。GPTYSAV2 不自动迁移或回退，旧文件保留供人工处理。保存包含状态、轮次、内容版本、
配置、池、原玩家及协议形象快照。恢复需要原房主身份、匹配内容和全部原玩家。
恢复重新建房；正在运行的小游戏不会被恢复。已保存未广播的结果不会重复发奖。

协议可实现同步 `present_result(result, request) -> Dictionary`。core 校验展示结构并随状态保存。
大游戏在 round_committed 后可调用 `api.show_results(api.get_round_presentation())`。
这只打开本端公共成绩页；其他客户端何时展示由大游戏通知，框架不会自动阻断子游戏返回流程。
