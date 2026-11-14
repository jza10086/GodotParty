# 内容开发待办索引

本页集中导航，具体任务和实施记录由所属内容包维护。包内记录保留来源日期、未完成项、最近实施结果及人工验收限制；本次文档整理未运行游戏，也未改变完成状态。

- [原版协议共享任务 G01–G03](../../games/protocols/godot_party_default_protocol/doc/godot_party_default_protocol_development.md)：先处理真实共享依赖，再修改调用方。
- [小游戏人工完成度](minigame_status.md)：与下表中的架构审查待办数量不同。

## 包内任务

下表数量仅统计原审查中的未勾选项目，不含正文中的人工验收限制；源审查日期为 2026-11-07，实施前需核对后续代码变化。

| 原任务 | 包内记录 | 未勾选项 |
| --- | --- | --- |
| M01 方向密码 | [gp_direction_code](../../games/minigame/gp_direction_code/doc/gp_direction_code_development.md) | 2 |
| M02 山脊竞速 | [gp_car_racing](../../games/minigame/gp_car_racing/doc/gp_car_racing_development.md) | 3 |
| M03 海岸飞行 | [gp_flight](../../games/minigame/gp_flight/doc/gp_flight_development.md) | 2 |
| M04 极速追逐 | [gp_chase](../../games/minigame/gp_chase/doc/gp_chase_development.md) | 0 |
| M05 圆角俄罗斯方块 | [gp_tetris](../../games/minigame/gp_tetris/doc/gp_tetris_development.md) | 3 |
| M06 霓虹节拍 | [gp_rhythm_game](../../games/minigame/gp_rhythm_game/doc/gp_rhythm_game_development.md) | 0 |
| M07 水果武士 | [gp_fruit_samurai](../../games/minigame/gp_fruit_samurai/doc/gp_fruit_samurai_development.md) | 0 |
| M08 云间跃行 | [gp_platformer](../../games/minigame/gp_platformer/doc/gp_platformer_development.md) | 4 |
| M09 贪吃蛇 | [gp_snake](../../games/minigame/gp_snake/doc/gp_snake_development.md) | 3 |
| M10 星潮 | [gp_star_wave](../../games/minigame/gp_star_wave/doc/gp_star_wave_development.md) | 3 |
| M11 竞拍大师 | [gp_auction_master](../../games/minigame/gp_auction_master/doc/gp_auction_master_development.md) | 0 |
| M12 3D 桌球 | [gp_billiards](../../games/minigame/gp_billiards/doc/gp_billiards_development.md) | 0 |
| M13 连连看 | [gp_matching](../../games/minigame/gp_matching/doc/gp_matching_development.md) | 0 |
| M14 合成大西八 | [gp_merge_ssibal](../../games/minigame/gp_merge_ssibal/doc/gp_merge_ssibal_development.md) | 1 |
| M15 蛇蛇大作战 | [gp_snake_battle](../../games/minigame/gp_snake_battle/doc/gp_snake_battle_development.md) | 0 |
| M16 3D 国际象棋 | [gp_3d_chess](../../games/minigame/gp_3d_chess/doc/gp_3d_chess_development.md) | 4 |
| M17 海战棋 | [gp_battleship](../../games/minigame/gp_battleship/doc/gp_battleship_development.md) | 0 |
| M18 记忆拼图 | [gp_jigsaw](../../games/minigame/gp_jigsaw/doc/gp_jigsaw_development.md) | 0 |
| M19 身份派对 | [gp_avalon](../../games/minigame/gp_avalon/doc/gp_avalon_development.md) | 0 |
| M20 心理博弈 | [gp_psych_party](../../games/minigame/gp_psych_party/doc/gp_psych_party_development.md) | 4 |
| M21 炮火争锋 | [gp_artillery](../../games/minigame/gp_artillery/doc/gp_artillery_development.md) | 4 |
| M22 雷霆战争 | [gp_tank_war](../../games/minigame/gp_tank_war/doc/gp_tank_war_development.md) | 0 |
| M23 纸牌会客厅原型 | [gp_cards](../../games/minigame/gp_cards/doc/gp_cards_development.md) | 4 |
| M24 铁鹰防线原型 | [gp_tank_battle](../../games/minigame/gp_tank_battle/doc/gp_tank_battle_development.md) | 3 |
| M25 西部牛仔对决占位 | [gp_west_duel](../../games/minigame/gp_west_duel/doc/gp_west_duel_development.md) | 0 |

## 维护方式

保留玩法、人数、计算权威、网络字段、保存格式与公开状态；改公共接口时同步直接调用方和契约文档。无音频的玩法不要求新增音频，场景整理不等于重建全部玩法。原型整理不等于完成正式接入。

完成事项后更新包内待办和该事项最新的验证结论，保留明确的失败、限制和待人工验收项。同一事项旧的成功流水无需累计。测试产物归所属工程 `tmp/test/`，历史报告不作为可执行验收入口。
