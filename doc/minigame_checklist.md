# 当前小游戏清单

更新日期：2026-11-09。按 `games/minigame/` 下当前 `manifest.json` 核对，共 27 个小游戏包（含空白小游戏模板）。名称省略统一的 `GodotPartyDefault · ` 前缀；包名称使用完整包 ID。

完成度、备注留空，由人工填写。完成度只能填写以下四种状态之一：

| 完成度   | 参考标准                                        |
| -------- | ----------------------------------------------- |
| 完整可玩 | 小游戏完整可玩，仅需后续打磨。                  |
| 初步可玩 | 可以联机正常游戏，音效、UI 等次要系统尚未实现。 |
| 尚未可玩 | 仅实现初步原型，无法接入联机框架。              |
| 不可玩   | 几乎空白，仅占位。                              |

人数取自包声明，不代表已通过开局或联机验收；实际可开局人数还受模式配置、协议与大游戏的人数交集限制。

| 序号 | 名称                                                                             | 包名称                                      | 声明人数 | 完成度   | 备注                                                 |
| ---- | -------------------------------------------------------------------------------- | ------------------------------------------- | -------- | -------- | ---------------------------------------------------- |
| 1    | [方向密码](../games/minigame/gp_direction_code/manifest.json)                      | `gp_direction_code`                      | 1        | 尚未可玩 |                                                      |
| 2    | [3D 2048](../games/minigame/gp_2048/manifest.json)                 | `gp_2048`                | 1–8     | 尚未可玩 |                                                      |
| 3    | [3D 国际象棋](../games/minigame/gp_3d_chess/manifest.json)         | `gp_3d_chess`            | 2–8     | 尚未可玩 |                                                      |
| 4    | [炮火争锋](../games/minigame/gp_artillery/manifest.json)      | `gp_artillery`      | 1–8     | 初步可玩 |                                                      |
| 5    | [竞拍大师](../games/minigame/gp_auction_master/manifest.json)      | `gp_auction_master`      | 1–8     | 完整可玩 | 需要优化网络通信                                     |
| 6    | [海战棋](../games/minigame/gp_battleship/manifest.json)      | `gp_battleship`    | 1–8     | 初步可玩 | 还要有炮击效果，回合间隔                             |
| 7    | [3d桌球](../games/minigame/gp_billiards/manifest.json)             | `gp_billiards`           | 2–8     | 尚未可玩 |                                                      |
| 8    | [山脊竞速](../games/minigame/gp_car_racing/manifest.json)          | `gp_car_racing`          | 1        | 不可玩   | 需要完整重构并合并                                   |
| 9    | [纸牌会客厅](../games/minigame/gp_cards/manifest.json)         | `gp_cards`           | 1–8     | 不可玩   | 需要完整重构                                         |
| 10   | [COASTLINE · 海岸飞行](../games/minigame/gp_flight/manifest.json) | `gp_flight`              | 1        | 不可玩   | 需要完整重构                                         |
| 11   | [水果武士](../games/minigame/gp_fruit_samurai/manifest.json)       | `gp_fruit_samurai`       | 1–8     | 尚未可玩 |                                                      |
| 12   | [阿瓦隆](../games/minigame/gp_avalon/manifest.json)        | `gp_avalon`      | 5–8     | 初步可玩 | 尚未进行多人测试，美术风格有待调整，可以参考王权系列 |
| 13   | [记忆拼图](../games/minigame/gp_jigsaw/manifest.json)       | `gp_jigsaw`       | 1–8     | 初步可玩 | 需要优化ui、操作、结算                               |
| 14   | [极速追逐](../games/minigame/gp_chase/manifest.json)    | `gp_chase`    | 1        | 不可玩   | 需要完整重构                                         |
| 15   | [连连看](../games/minigame/gp_matching/manifest.json)         | `gp_matching`       | 1–8     | 尚未可玩 |                                                      |
| 16   | [合成大西八](../games/minigame/gp_merge_ssibal/manifest.json)  | `gp_merge_ssibal`    | 1–8     | 尚未可玩 |                                                      |
| 17   | [蛇蛇大作战](../games/minigame/gp_snake_battle/manifest.json)  | `gp_snake_battle`    | 1–8     | 初步可玩 | 优化帧数、网络同步、尾巴                             |
| 18   | [云间跃行](../games/minigame/gp_platformer/manifest.json)          | `gp_platformer`          | 2–8     | 不可玩   | 已有重构方案，需要改名                               |
| 19   | [心理博弈](../games/minigame/gp_psych_party/manifest.json) | `gp_psych_party` | 2–8     | 不可玩   | 没有接入实体系统，仅逻辑，需要改名                   |
| 20   | [圆角俄罗斯方块](../games/minigame/gp_tetris/manifest.json) | `gp_tetris`       | 1        | 尚未可玩 | 需要改名                                             |
| 21   | [贪吃蛇](../games/minigame/gp_snake/manifest.json)            | `gp_snake`          | 1–8     | 尚未可玩 |                                                      |
| 22   | [星潮](../games/minigame/gp_star_wave/manifest.json)               | `gp_star_wave`           | 1–8     | 尚未可玩 |                                                      |
| 23   | [铁鹰防线](../games/minigame/gp_tank_battle/manifest.json)         | `gp_tank_battle`         | 2–8     | 尚未可玩 | 需要改名                                             |
| 24   | [雷霆战争](../games/minigame/gp_tank_war/manifest.json)          | `gp_tank_war`          | 1–8     | 尚未可玩 |                                                      |
| 25   | [西部牛仔对决](../games/minigame/gp_west_duel/manifest.json)   | `gp_west_duel`       | 2–8     | 不可玩   | 占位，尚未接入fps系统，需要改名                      |
| 26   | [霓虹节拍](../games/minigame/gp_rhythm_game/manifest.json)                          | `gp_rhythm_game`                          | 1–8     | 完整可玩 | 优化加载界面选择、分数结算                           |
