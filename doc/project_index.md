# GodotParty 开发文档索引

## 阅读路线

| 工作 | 入口 |
| --- | --- |
| 框架开发 | [架构与边界](development/project_architecture.md)、[正式 UI](development/framework_ui.md)、[验证与调试](development/project_validation.md) |
| 小游戏制作 | [作者入门](api/game_authoring.md)、目标包的 `doc/<包ID>_guide.md`、目标协议文档 |
| 主游戏制作 | [状态与结算](api/main_game_state.md)、[配置与游戏池](api/configuration.md) |
| 协议与形象 | [协议契约](api/protocols_and_briefing.md)、[玩家形象](api/player_appearance.md) |
| 打包发布 | [内容声明、版本与导出](api/content_packages.md)、[资源与排除规则](api/external_resources.md) |
| AI 作者 | [内容作者 Skill](skills/godot-party-authoring/SKILL.md) |

## 公共契约

[API 签名](api/party_api_reference.md) · [生命周期](api/activity_lifecycle.md) · [网络通信](api/networking.md) · [配置](api/configuration.md) · [本地化](api/localization.md) · [人数约束](api/player_counts.md) · [语音](api/voice.md)

精确签名和错误语义以 `core/api/` 实现及文档注释为准。当前框架、内容包和配置分别按所属声明维护；不要从历史文档里的数字推断当前版本。

## 内容与进度

- [小游戏状态](content/minigame_status.md)：保留人工完成度和备注，人数声明不等于验收结果。
- [开发待办索引](content/content_development.md)：共享任务和各包最近记录。
- [原版协议](../games/protocols/godot_party_default_protocol/doc/godot_party_default_protocol_guide.md)
- [小游戏轮换](../games/maingame/godot_party_default_maingame_minigame_playlist/doc/godot_party_default_maingame_minigame_playlist_guide.md)
- [大富翁原型](../games/maingame/godot_party_default_main_game_millionaire/doc/godot_party_default_main_game_millionaire_guide.md)

## 资源与维护

[资产登记与待核实来源](assets/project_asset_register.md) · [统一署名](assets/project_credits.md) · [BGM 候选](assets/project_bgm_candidates.md) · [许可范围](../ASSET_LICENSES.md) · [受限资产](../third_party_assets/restricted_assets_index.md) · [连通性诊断](development/connectivity_diagnostics.md) · [阿瓦隆历史恢复点](../games/minigame/gp_avalon/doc/gp_avalon_recovery.md)

## 文档组织约定

- 根目录仅保留项目 `README.md`、`AGENTS.md` 和许可文件。项目级文档位于 `doc/`：`development/` 管框架开发，`api/` 管公开契约，`content/` 管跨包索引，`assets/` 管全项目来源与署名。
- 游戏、协议、资产包的专属说明与待办放在包内 `doc/`；工具说明放在各自工具目录。独立包使用 `<包ID>_<用途>.md`，其他自有文档使用能识别对象的 `snake_case` 名称，避免重名的 README、SOURCE、QA 等。
- `AGENTS.md`、`SKILL.md`、许可证及第三方原始声明保留约定名称；第三方插件文档不改名。
- 同一规则只在所属专题维护，入口与 Skill 使用链接。包版本只从声明读取，说明文档不重复维护易过时的版本号。
- 待办保留状态与来源日期；同一事项保留最新有依据的记录，较早记录仅在解释未解决问题或独立验收边界时保留。文档整理不会自动把待办标成完成。
- 测试脚本、报告、截图和缓存归所属工程 `tmp/test/`；开发文档只保留必要结论、限制和后续事项。删除或迁移前确认 Git 恢复点，并同步更新引用。
