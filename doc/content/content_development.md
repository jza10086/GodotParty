# 内容开发待办索引

本页集中导航，具体任务和实施记录由所属内容包维护。包内记录保留来源日期、未完成项、最近实施结果及人工验收限制；本次文档整理未运行游戏，也未改变完成状态。

- [原版协议共享任务 G01–G03](../../games/protocols/GP_default_protocol/doc/GP_default_protocol_development.md)：先处理真实共享依赖，再修改调用方。
- [小游戏人工完成度](minigame_status.md)：与下表中的架构审查待办数量不同。

## 包内任务

下表数量仅统计原审查中的未勾选项目，不含正文中的人工验收限制；源审查日期为 2026-11-07，实施前需核对后续代码变化。

| 原任务 | 包内记录 | 未勾选项 |
| --- | --- | --- |
| M01 方向密码 | [GP_direction_code](../../games/minigame/GP_direction_code/doc/GP_direction_code_development.md) | 2 |
| M02 山脊竞速 | [GP_car_racing](../../games/minigame/GP_car_racing/doc/GP_car_racing_development.md) | 3 |
| M03 海岸飞行 | [GP_flight](../../games/minigame/GP_flight/doc/GP_flight_development.md) | 2 |
| M04 极速追逐 | [GP_chase](../../games/minigame/GP_chase/doc/GP_chase_development.md) | 0 |
| M05 圆角俄罗斯方块 | [GP_tetris](../../games/minigame/GP_tetris/doc/GP_tetris_development.md) | 3 |
| M06 霓虹节拍 | [GP_rhythm_game](../../games/minigame/GP_rhythm_game/doc/GP_rhythm_game_development.md) | 0 |
| M07 水果武士 | [GP_fruit_samurai](../../games/minigame/GP_fruit_samurai/doc/GP_fruit_samurai_development.md) | 0 |
| M08 云间跃行 | [GP_platformer](../../games/minigame/GP_platformer/doc/GP_platformer_development.md) | 4 |
| M09 贪吃蛇 | [GP_snake](../../games/minigame/GP_snake/doc/GP_snake_development.md) | 3 |
| M10 星潮 | [GP_star_wave](../../games/minigame/GP_star_wave/doc/GP_star_wave_development.md) | 3 |
| M11 竞拍大师 | [GP_auction_master](../../games/minigame/GP_auction_master/doc/GP_auction_master_development.md) | 0 |
| M12 3D 桌球 | [GP_billiards](../../games/minigame/GP_billiards/doc/GP_billiards_development.md) | 0 |
| M13 连连看 | [GP_matching](../../games/minigame/GP_matching/doc/GP_matching_development.md) | 0 |
| M14 合成大西八 | [GP_merge_ssibal](../../games/minigame/GP_merge_ssibal/doc/GP_merge_ssibal_development.md) | 1 |
| M15 吃豆蛇 | [GP_snake_battle](../../games/minigame/GP_snake_battle/doc/GP_snake_battle_development.md) | 0 |
| M16 3D 国际象棋 | [GP_3d_chess](../../games/minigame/GP_3d_chess/doc/GP_3d_chess_development.md) | 4 |
| M17 海战棋 | [GP_battleship](../../games/minigame/GP_battleship/doc/GP_battleship_development.md) | 0 |
| M18 记忆拼图 | [GP_jigsaw](../../games/minigame/GP_jigsaw/doc/GP_jigsaw_development.md) | 0 |
| M19 身份派对 | [GP_avalon](../../games/minigame/GP_avalon/doc/GP_avalon_development.md) | 0 |
| M20 心理博弈 | [GP_psych_party](../../games/minigame/GP_psych_party/doc/GP_psych_party_development.md) | 4 |
| M21 炮火争锋 | [GP_artillery](../../games/minigame/GP_artillery/doc/GP_artillery_development.md) | 4 |
| M22 雷霆战争 | [GP_tank_war](../../games/minigame/GP_tank_war/doc/GP_tank_war_development.md) | 0 |
| M23 纸牌会客厅原型 | [GP_cards](../../games/minigame/GP_cards/doc/GP_cards_development.md) | 4 |
| M24 铁鹰防线原型 | [GP_tank_battle](../../games/minigame/GP_tank_battle/doc/GP_tank_battle_development.md) | 3 |
| M25 西部牛仔对决占位 | [GP_west_duel](../../games/minigame/GP_west_duel/doc/GP_west_duel_development.md) | 0 |

## 维护方式

保留玩法、人数、计算权威、网络字段、保存格式与公开状态；改公共接口时同步直接调用方和契约文档。无音频的玩法不要求新增音频，场景整理不等于重建全部玩法。原型整理不等于完成正式接入。

完成事项后更新包内待办和该事项最新的验证结论，保留明确的失败、限制和待人工验收项。同一事项旧的成功流水无需累计。测试产物归所属工程 `tmp/test/`，历史报告不作为可执行验收入口。
