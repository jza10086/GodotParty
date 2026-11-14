# 协议包与加载信息

大游戏只绑定一个协议，协议可以服务多个大游戏。小游戏每轮选择一个接入，
未选协议无需安装。协议完全自定义，不继承原版协议，也没有通用钱包。

协议脚本继承 RefCounted，至少提供：
- validate_request(request, players) -> Dictionary
- validate_result(result, request, players) -> Dictionary
- default_player_config() -> Dictionary
- validate_player_config(value) -> Dictionary
- get_appearance(value) -> Dictionary

校验成功返回 {ok: true}，失败返回 {ok: false, code: "...", message: "..."}。
players 是 core 提供的实际参与者快照；结果中的成员集合由协议校验，不能相信结果自报名单。
校验及数据转换同步、无副作用，不能联网、修改大游戏或加载整个玩法场景。

小游戏接入脚本固定为 `adapters/<协议ID>.gd`，实现 make_config(request)、map_result(raw_result, request)；
可选 check_request(request) 检查附加限制。每轮独立适配实例；需要恒等传递时在适配器中直接返回参数。
协议声明不是自动转换玩法的能力：所有实际行为必须由小游戏实现。

协议仅用包的 package_version 和依赖范围表达兼容性，没有另一套协议 API 主次版本。
协议包附带 doc/、合法非法例子和针对性测试；大小游戏接入验收随实际玩法补充。

当前原版：[GodotPartyDefaultProtocol 1.0](../../games/protocols/godot_party_default_protocol/doc/godot_party_default_protocol_guide.md)，提供玩家颜色、2D/3D 形象以及金币、钻石、道具和抵押结算契约。

## 加载页

当前正式轮换池仅开放阿瓦隆，使用 standard 排名局。原版资源契约保留；轮换不授权金币、钻石或道具。

小游戏介绍写入 README 或玩法界面，封面使用固定 cover 文件名，controls（逻辑动作 → 描述）由入口定义。
简介可包含规则、目标和所有其他说明。框架根据本地输入配置显示键位。
展示每位在线玩家是否就绪，包括观战者，不显示虚假的资源加载百分比。
