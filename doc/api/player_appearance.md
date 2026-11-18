# 协议定义的玩家资料与形象

core 仅拥有 player_id 和连接身份；昵称和形象属于协议。形象没有固定四槽或统一颜色结构。
get_appearance 返回当前协议生成的数据，游戏按协议读取，不能猜测字段。

GodotPartyDefaultProtocol 1.0 定义 color、avatar_2d、character_3d。具体约定见 [原版协议](../../games/protocols/GP_default_protocol/doc/GP_default_protocol_guide.md)。这些字段属于原版协议，不是 core 对所有协议的共同要求。

原版形象使用 games/assets/ 下的独立 assets 包。special_type 为 GP_default_avatar_2d 或 GP_default_character_3d，appearance_resources 将包内 .tscn 相对路径映射到选项显示名。个人资料页读取已安装包的清单，预览与游戏使用时才加载场景。协议依赖 GP_default_avatars_2d 和 GP_default_avatars。GP_default_extra_avatars_2d 提供测试图片，GP_default_extra_avatars_3d 提供圆柱体；玩家实际选用的扩展包加入房间依赖。
资料中的资源引用为 {package_id, resource_path}。包可以只提供 2D、3D、头像，
或者协议需要的其他素材；颜色等纯数据也不要求加载人物模型。

load_asset 只解析当前依赖集合，失败返回 null；游戏或协议负责匹配类型并报告实际加载失败。
修改材质时独立实例化材质，不能污染共享资源。移动、碰撞、authority 和同步都归游戏。

## 配置页面

协议提供固定 profile_panel.tscn 场景。
面板契约与活动配置相同，context 提供已安装资源描述和 preview_asset 回调。
框架负责草稿、应用/取消和回执；协议决定选择列表、模型视角及配色等界面内容。

已确认的资料按协议保存在当前资料槽 protocols/<协议 ID>/config/profile.json，同协议的多个大游戏共用，
不同协议隔离。新会话开始后冻结快照。存档恢复使用原快照，不读取后来修改的本地选择。

房主按连接身份修改玩家资料，不能通过请求修改 player_id、peer_id 或房主身份。
接纳新玩家前，房主先解析其形象资源与房间依赖；无效引用会直接拒绝加入，并显示包 ID、资源路径和当前包版本，不改变现有玩家列表或房间内容清单。开房自动应用本机资料时同样检查形象资源，失败会明确结束创建，不保留默认形象伪装成功。
超时和断线保留编辑内容；旧请求回执不覆盖新草稿。
联机已生效但本地保存失败应提示，可重新应用以重试本机保存。

只有当前打开的协议详情页创建预览。3D 预览使用独立 SubViewport/世界，
页面隐藏后停止更新，不能改变全局鼠标模式或正式游戏世界。

主菜单的“协议个人资料”可离线配置已安装协议；大厅编辑仍须房主确认。

核心不含内置形象。协议昵称、形象资料保存在 `protocols/<id>/config/profile.json`，不包含在配置预设中。

## 可选房间资料约束

协议可提供同步的 `resolve_player_config(value: Dictionary, player_id: String, players: Array) -> Dictionary`，返回 `{ok, value, message}` 或 `{ok: false, message}`。房主在新玩家入房和资料提交时调用，传入独立的权威玩家快照；不提供此钩子的协议使用原值。结果仍须通过 `validate_player_config`。core 不解释颜色等字段。

协议面板 context 在普通大厅房主端提供 `room_players()` 快照和 `assign_room_profile(player_id, assignment)` 回调。协议实现 `assign_player_config(player_id, assignment, players)`，返回 `{ok, profiles}`；profiles 按玩家 ID 索引完整资料。框架整批验证、应用并广播，不写入被分配玩家的本机偏好。活动/恢复期间、客户端均不可调用。面板不应长期缓存玩家列表；提交时以房主当前名单为准。

原版协议 1.0.1 的 2D 头像公开资源属于 GP_default_avatars_2d；3D Cube 仍属于 GP_default_avatars。两个包都通过协议依赖激活。本轮已有 profile.json 已先备份再转换 resource_path；运行时不保留旧资源 key 兼容读取器。
