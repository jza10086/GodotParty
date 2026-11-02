# 生命周期与通信

## 运行顺序

创建实例 API 和处理器 → 实例化 → 入树前 setup → 入树初始化 → 显式 mark_ready →
所有在线必要端就绪 → party_start → finish / fail → 提交或取消 → 关闭 API →
party_stop → LIFO 清理 → 释放场景。

准备阶段的 ready 后续处理排队执行，避免从 _ready 重入 party_start。
一轮只有一个终态；旧局消息不交给新局。每局参与者名单固定，断线仅更新 connected。

一个顶层大游戏可以拥有一个前台小游戏，未参赛者全部加载并观战。
房主即使观战也继续执行房主玩法逻辑。加载失败或超时取消本轮；全部参赛者退出取消本轮；
房主退出结束会话。没有运行中加入、重连、迁移或多层嵌套。

## 通信声明

```json
{
  "streams": {
    "snapshots": {"mode": "unreliable", "audience": "instance"},
    "inputs": {"mode": "ordered", "audience": "participants"},
    "events": {"mode": "reliable", "audience": "participants"}
  },
  "native_channels": 1
}
```

audience 为 participants、spectators、instance。定向消息可选择房间成员。
可靠和有序流按作用域、发送者、流及目标去重；无序流不应用“丢弃旧序号”。

基础值、数组、字典及已支持的 Godot 值可发送；Node、Resource、Callable、Signal 和 RID 不能发送。
自定义编码使用 PackedByteArray。框架不提供自动预测、回滚或插值。

框架控制通信使用通道 0，便利消息使用通道 1，PCM 媒体使用通道 2；内容流从 3 开始。清单声明流和原生通道按房间固定映射分配。
原生 RPC 使用稳定实例根路径，可通过 rpc_config 配置分配到的通道；
只使用自己声明的通道数量，勿替换平台 MultiplayerPeer。
原生消息不受 PartyNet 的作用域过滤承诺约束，作者负责节点存活和迟到消息。

父实例在子游戏期间仍能处理协议消息，但持久业务状态冻结，最终变更进入 reducer。

设置 runtime.enter 在玩法入树前执行，attach_view 在入树后执行；最终 READY 同时要求游戏就绪、设置就绪和规则摘要一致。详细约束见 [配置生命周期](configuration.md)。
