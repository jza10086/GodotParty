# GodotParty

在线多人派对游戏与内容开发框架，最多八名玩家。完整仓库是开发环境：`core/` 负责框架，`games/` 放协议、主游戏、小游戏及资产包。

## 开始开发

1. `git clone --recurse-submodules <主仓地址>`，获取主仓记录的小游戏提交。
2. 在 Godot 编辑器打开 `project.godot`；引擎升级和项目转换由用户手动完成。
3. F5 运行正式主菜单，从创建房间选择协议与主游戏，再在大厅配置小游戏池。

小游戏在自己的仓库中修改、提交和推送，再更新主仓的子模块引用。新增源码包放入相应 `games/<类别>/<id>/`，由包根 `manifest.json` 参与发现。

- [开发文档总入口](doc/project_index.md)
- [小游戏作者入门](doc/api/game_authoring.md)
- [当前小游戏状态](doc/content/minigame_status.md)
- [内容包与版本声明](doc/api/content_packages.md)
- [项目执行规则](AGENTS.md)
- [原创资产许可与第三方例外](ASSET_LICENSES.md)

框架版本来源为 `core/framework_version.gd`；各内容包版本由自身 `manifest.json` 声明，与用户维护的 Godot 项目版本独立。

## 许可证与商业发行

- [框架许可证 Apache-2.0](LICENSE)：仅适用于有权授权且没有更具体独立许可的新版框架代码与工具。
- [授权范围与历史 MIT / CC0 记录](ASSET_LICENSES.md)：历史权利保留，框架与内容包分开授权。
- [EULA 草案（未生效）](EULA.md)：计划用于未来商业发行；尚不构成正式玩家使用条款。

`games/` 中以 Git Submodule 接入的内容包分别由各自仓库管理许可证及公开性，不因主仓采用 Apache-2.0 而自动改为该许可证。商业及受限内容包应检查各自的授权、素材来源与再分发许可。

> 注意：当前公开主仓仍包含部分内容包源码，私有化这些包必须另行迁移目录及调整仓库可见性。仅变更 LICENSE 不会使已公开的内容消失。
