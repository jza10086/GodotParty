# 小游戏 BGM 候选清单

整理日期：2026-11-08。依据当前 `games/minigame/*/manifest.json` 的 26 个条目选择音乐，覆盖可玩游戏、3 个未开放原型和空白模板。共选入 29 个音频候选版本，已下载 29 个，均从 OpenGameArt 曲目发布页取得，逐曲选择 **CC0 1.0**。同一作品的原版、循环编辑版或高潮版分别标注。

音频位置：[`core/assets/audio/bgm_candidates/audio/`](../core/assets/audio/bgm_candidates/audio/)。曲目表内“本地音频”可直接打开；同目录素材库包含逐曲来源旁档、机器可读目录、CC0 全文，以及 Exploration Theme 的原始 ZIP。

## 免费商用与使用方式

[CC0 1.0 官方说明](https://creativecommons.org/publicdomain/zero/1.0/)允许复制、修改、分发和商业使用，无须付费或强制署名。本库仍保留作者和来源便于维护；多许可曲目 Quirky Jazz 选择源页提供的 CC0（[OpenGameArt 多许可规则](https://opengameart.org/node/5571)允许选择其中一种）。本清单只覆盖下列曲目和所下载文件，不延伸至作者网站上的其他作品、付费 Deluxe 包或被提及的游戏原声。

这些是候选素材，尚未配置到小游戏。素材库带 `.gdignore`，避免候选音频被自动导入；选定后将对应音频与来源、许可旁档复制到所属小游戏包再接入。下载文件仅规范了本地文件名，未转码、剪辑或调整响度；Exploration Theme 的 OGG 由原 ZIP 提取。

风格匹配依据作者描述、标签与游戏规则，是选曲建议；尚未逐首人工试听或在游戏中混音验收。“作者标称循环”不等同于已验证接缝；完整曲建议试听后制作循环点或交叉淡化。

## 按小游戏选择

候选按建议顺序排列；同一行也可能包含不同阶段的音乐。B 编号对应下方曲目表。

| 小游戏 | 适合风格与使用阶段 | BGM 候选 |
| --- | --- | --- |
| [方向密码](../games/minigame/gp_direction_code/manifest.json) | 轻电子、稀疏节奏；展示方向序列时建议低音量 | B01 Puzzling；B02 Sci-fi Puzzle In-Game 1 |
| [3D 国际象棋／中国象棋](../games/minigame/gp_3d_chess/manifest.json) | 舒缓钢琴、环境音乐；长时间思考不宜用强鼓点 | B23 Calm Piano 1 (Vaporware)；B18 Exploration Theme |
| [炮火争锋](../games/minigame/gp_artillery/manifest.json) | 瞄准阶段克制，炮击阶段提高战斗感 | B07 Battle Theme；B24 Technological Messup |
| [竞拍大师](../games/minigame/gp_auction_master/manifest.json) | 诙谐爵士用于交易，暗标阶段可用轻悬念 | B03 Quirky Jazz；B21 Insistent: background loop |
| [海战棋](../games/minigame/gp_battleship/manifest.json) | 部署／选点用悬念氛围，齐射用管弦战斗 | B21 Insistent: background loop；B09 Battle Theme A |
| [3d桌球](../games/minigame/gp_billiards/manifest.json) | 球房爵士、轻 Lo-fi；保留击球音效空间 | B27 Richer；B16 Chill lofi inspired [loop edit]；B29 Chill lofi inspired |
| [空白小游戏](../games/minigame/gp_blank/manifest.json) | 模板预览用轻松菜单音乐 | B19 Menu Chill Music；B17 Sherwood |
| [山脊竞速](../games/minigame/gp_car_racing/manifest.json) | Techno／Drum & Bass；末圈可换高潮版，休闲比赛可试 Jazz Funk | B04 Hot Roadway；B05 Hot Roadway (Climax)；B12 Hyper Ultra-Racing；B06 Detour |
| [纸牌会客厅](../games/minigame/gp_cards/manifest.json) | 休闲爵士、Lo-fi；原型尚未开放 | B03 Quirky Jazz；B29 Chill lofi inspired |
| [COASTLINE · 海岸飞行](../games/minigame/gp_flight/manifest.json) | 宽松的海洋氛围与钢琴，保留航行提示空间 | B18 Exploration Theme；B23 Calm Piano 1 (Vaporware) |
| [水果武士](../games/minigame/gp_fruit_samurai/manifest.json) | 东方音色与轻快街机；切割／炸弹提示优先 | B10 Ninja Theme；B15 Happy Adventure (Loop) |
| [阿瓦隆](../games/minigame/gp_avalon/manifest.json) | 森林悬疑用于推理，中世纪民谣用于准备；发言时低音量 | B13 Dark Forest Theme；B22 Medieval: The Old Tower Inn；B21 Insistent: background loop |
| [记忆拼图](../games/minigame/gp_jigsaw/manifest.json) | 柔和钢琴、Lo-fi；便于观察与记忆 | B23 Calm Piano 1 (Vaporware)；B16 Chill lofi inspired [loop edit] |
| [极速追逐](../games/minigame/gp_chase/manifest.json) | 明快电子与竞速节奏 | B04 Hot Roadway；B28 Happier Tune |
| [连连看](../games/minigame/gp_matching/manifest.json) | 轻盈、规律的休闲电子 | B17 Sherwood；B01 Puzzling |
| [合成大西八](../games/minigame/gp_merge_ssibal/manifest.json) | 轻松短循环；突出落球与合成音效 | B19 Menu Chill Music；B17 Sherwood |
| [蛇蛇大作战](../games/minigame/gp_snake_battle/manifest.json) | 持续推进的街机电子；高潮版适合后半局 | B24 Technological Messup；B05 Hot Roadway (Climax) |
| [云间跃行](../games/minigame/gp_platformer/manifest.json) | 明亮冒险、轻快 Chiptune | B14 A New Day；B15 Happy Adventure (Loop) |
| [心理博弈](../games/minigame/gp_psych_party/manifest.json) | 安静悬念或电子氛围；讨论阶段降低音量 | B21 Insistent: background loop；B20 MindStream |
| [圆角俄罗斯方块](../games/minigame/gp_tetris/manifest.json) | 稳定电子律动、轻快 Synthpop | B02 Sci-fi Puzzle In-Game 1；B28 Happier Tune |
| [贪吃蛇](../games/minigame/gp_snake/manifest.json) | 复古电子、轻 Chiptune | B01 Puzzling；B15 Happy Adventure (Loop) |
| [星潮](../games/minigame/gp_star_wave/manifest.json) | 复古电子战斗；Boss 可切换高能曲 | B24 Technological Messup；B25 8-Bit RPG Battle/Encounter Theme；B12 Hyper Ultra-Racing |
| [铁鹰防线](../games/minigame/gp_tank_battle/manifest.json) | 管弦战斗；准备阶段用开战主题；原型尚未开放 | B09 Battle Theme A；B08 Prepare to fight |
| [雷霆战争](../games/minigame/gp_tank_war/manifest.json) | 管弦战斗、史诗动作；保留机炮与导弹提示 | B07 Battle Theme；B09 Battle Theme A；B08 Prepare to fight |
| [西部牛仔对决](../games/minigame/gp_west_duel/manifest.json) | 西部吉他／铜管，酒馆曲用于准备；尚为占位模板 | B11 Spaghetti Western；B27 Richer；B26 Crowded Pub |
| [霓虹节拍](../games/minigame/gp_rhythm_game/manifest.json) | 菜单可用舒缓电子／Lo-fi；演奏时只播放谱面歌曲 | B20 MindStream；B16 Chill lofi inspired [loop edit]；B02 Sci-fi Puzzle In-Game 1；B04 Hot Roadway；B05 Hot Roadway (Climax) |

霓虹节拍：B02（138 BPM）、B04（160 BPM）、B05（175 BPM）可作为制谱候选，速度来自作者说明／文件名；**本次未制谱，也未测定拍点偏移**。进入演奏时需停止菜单音乐，避免第二条背景音乐干扰判定和听感。

## 曲目与下载文件

| 编号与曲目来源 | 作者 | 风格 | 时长 | 本地音频 | 循环说明 |
| --- | --- | --- | --- | --- | --- |
| B01 [Puzzling](https://opengameart.org/content/puzzling) | Ruskerdax | 极简复古电子，DX7 与 TR909 | 2:00 | [本地音频](../core/assets/audio/bgm_candidates/audio/puzzling.mp3) | 未标称循环 |
| B02 [Sci-fi Puzzle In-Game 1](https://opengameart.org/content/sci-fi-puzzle-in-game-1) | MintoDog | 科幻解谜电子，138 BPM | 2:19 | [本地音频](../core/assets/audio/bgm_candidates/audio/sci_fi_puzzle_in_game_1.ogg) | 作者标称可循环 |
| B03 [Quirky Jazz](https://opengameart.org/content/quirky-jazz) | Spring Spring | 俏皮摇摆、合成器与芯片爵士 | 8:31 | [本地音频](../core/assets/audio/bgm_candidates/audio/quirky_jazz.mp3) | 未标称循环；源页双许可，选择 CC0 |
| B04 [Hot Roadway](https://opengameart.org/content/hot-roadway) | MintoDog | 积极竞速 Techno，160 BPM | 2:00 | [本地音频](../core/assets/audio/bgm_candidates/audio/hot_roadway.ogg) | 作者标称可循环 |
| B05 [Hot Roadway (Climax)](https://opengameart.org/content/hot-roadway) | MintoDog | 竞速高潮版，175 BPM，增加拍手 | 1:50 | [本地音频](../core/assets/audio/bgm_candidates/audio/hot_roadway_climax.ogg) | 作者标称可循环 |
| B06 [Detour](https://opengameart.org/content/detour) | Zane Little Music | 复古竞速 Jazz Funk Fusion | 4:11 | [本地音频](../core/assets/audio/bgm_candidates/audio/detour.mp3) | 完整曲；本次不含 Deluxe 版付费素材 |
| B07 [Battle Theme](https://opengameart.org/content/battle-theme-0) | Ted Kerr / Wolfgang_ | 紧张管弦战斗 | 1:56 | [本地音频](../core/assets/audio/bgm_candidates/audio/battle_theme_0.mp3) | 未标称循环 |
| B08 [Prepare to fight](https://opengameart.org/content/prepare-to-fight) | Basil | 史诗开战与准备阶段 | 2:03 | [本地音频](../core/assets/audio/bgm_candidates/audio/prepare_to_fight.mp3) | 未标称循环 |
| B09 [Battle Theme A](https://opengameart.org/content/battle-theme-a) | The Cynic Project / cynicmusic | 弦乐、铜管、史诗战斗 | 1:36 | [本地音频](../core/assets/audio/bgm_candidates/audio/battle_theme_a.mp3) | 未标称循环 |
| B10 [Ninja Theme](https://opengameart.org/content/ninja-theme) | Julie Damsgaard / Spring Spring | 日本筝（Koto）、笛、铃与合成器 | 2:44 | [本地音频](../core/assets/audio/bgm_candidates/audio/ninja_theme.ogg) | 未标称循环 |
| B11 [Spaghetti Western](https://opengameart.org/content/spaghetti-western) | Julie Damsgaard / Spring Spring | 诙谐西部、吉他与铜管 | 2:03 | [本地音频](../core/assets/audio/bgm_candidates/audio/spaghetti_western.ogg) | 未标称循环 |
| B12 [Hyper Ultra-Racing](https://opengameart.org/content/hyper-ultra-racing) | The Cynic Project / cynicmusic | 高速 Drum & Bass 与电影感氛围 | 1:20 | [本地音频](../core/assets/audio/bgm_candidates/audio/hyper_ultra_racing.wav) | 未标称循环；含人声音色铺底 |
| B13 [Dark Forest Theme](https://opengameart.org/content/dark-forest-theme) | The Cynic Project / cynicmusic | 阴暗原声吉他与弦乐 | 1:33 | [本地音频](../core/assets/audio/bgm_candidates/audio/dark_forest_theme.mp3) | 未标称循环 |
| B14 [A New Day](https://opengameart.org/content/a-new-day) | SpiderDave | 明亮冒险 | 1:29 | [本地音频](../core/assets/audio/bgm_candidates/audio/a_new_day.ogg) | 未标称循环 |
| B15 [Happy Adventure (Loop)](https://opengameart.org/content/happy-adventure-loop) | TinyWorlds | 轻快复古 Chiptune | 0:47 | [本地音频](../core/assets/audio/bgm_candidates/audio/happy_adventure_loop.mp3) | 作者标称循环；MP3 接缝须试听；Autotracker 生成后编辑 |
| B16 [Chill lofi inspired [loop edit]](https://opengameart.org/content/chill-lofi-inspired-loop-edit) | omfgdude；qubodup 循环编辑 | 钢琴、鼓与 Lo-fi Hip Hop | 1:37 | [本地音频](../core/assets/audio/bgm_candidates/audio/chill_lofi_inspired_loop_edit.ogg) | 作者制作的无缝循环编辑版 |
| B17 [Sherwood](https://opengameart.org/content/sherwood) | Chris Murphy / zesona | 柔和轻松背景电子，110 BPM | 0:35 | [本地音频](../core/assets/audio/bgm_candidates/audio/sherwood.ogg) | 作者标称可循环 |
| B18 [Exploration Theme](https://opengameart.org/content/exploration-theme) | Cleyton Kauffman | 钢琴与渐进合成器，海洋／探索氛围 | 2:14 | [本地音频](../core/assets/audio/bgm_candidates/audio/exploration_theme.ogg) | 作者标称无缝循环；从原 ZIP 提取 OGG |
| B19 [Menu Chill Music](https://opengameart.org/content/menu-chill-music) | etrock | 轻松街机菜单音乐 | 0:17 | [本地音频](../core/assets/audio/bgm_candidates/audio/menu_chill_music.wav) | 作者标称循环 |
| B20 [MindStream](https://opengameart.org/content/mindstream) | DST | 舒缓 Techno 与 Ambient | 4:29 | [本地音频](../core/assets/audio/bgm_candidates/audio/mindstream.mp3) | 源页标有 loop；完整长曲 |
| B21 [Insistent: background loop](https://opengameart.org/content/insistent-background-loop) | yd | 安静、阴暗、悬念氛围 | 2:09 | [本地音频](../core/assets/audio/bgm_candidates/audio/insistent_background_loop.ogg) | 作者标称循环 |
| B22 [Medieval: The Old Tower Inn](https://opengameart.org/content/medieval-the-old-tower-inn) | RandomMind | 平和中世纪民谣／旅店 | 0:50 | [本地音频](../core/assets/audio/bgm_candidates/audio/medieval_the_old_tower_inn.wav) | 下载作者提供的 Loop WAV 版 |
| B23 [Calm Piano 1 (Vaporware)](https://opengameart.org/content/calm-piano-1-vaporware) | The Cynic Project / cynicmusic | 舒缓钢琴旋律与氛围铺底 | 2:45 | [本地音频](../core/assets/audio/bgm_candidates/audio/calm_piano_1_vaporware.mp3) | 未标称循环 |
| B24 [Technological Messup](https://opengameart.org/content/technological-messup) | Centurion_of_war | 复古合成器、Techno 战斗 | 1:47 | [本地音频](../core/assets/audio/bgm_candidates/audio/technological_messup.ogg) | 源页标有 loop |
| B25 [8-Bit RPG Battle/Encounter Theme](https://opengameart.org/content/8-bit-rpg-battleencounter-theme) | Ted Kerr / Wolfgang_ | 8-bit NES 战斗 | 1:05 | [本地音频](../core/assets/audio/bgm_candidates/audio/8_bit_rpg_battleencounter_theme.ogg) | 下载作者提供的 Loopable OGG 版 |
| B26 [Crowded Pub](https://opengameart.org/content/crowded-pub) | Bobjt | 欢乐酒馆／西部港口 | 0:34 | [本地音频](../core/assets/audio/bgm_candidates/audio/crowded_pub.ogg) | 2025 鼓点扩展循环版 |
| B27 [Richer](https://opengameart.org/content/richer) | Alex McCulloch / Pro Sensory | 西部吉他与爵士 | 2:41 | [本地音频](../core/assets/audio/bgm_candidates/audio/richer.wav) | 未标称循环 |
| B28 [Happier Tune](https://opengameart.org/content/happier-tune) | Gena Sealov | 轻快 Synthpop | 2:09 | [本地音频](../core/assets/audio/bgm_candidates/audio/happier_tune.mp3) | 作者明确不是循环曲 |
| B29 [Chill lofi inspired](https://opengameart.org/content/chill-lofi-inspired) | omfgdude | Lo-fi Hip Hop 原版 | 2:05 | [本地音频](../core/assets/audio/bgm_candidates/audio/chill_lofi_inspired.ogg) | 完整原版；与循环编辑版区分 |

## 下载结果

29 / 29 个音频文件下载成功，音频合计 149.4 MiB。

已核对入选曲目来源页的 CC0 标签；成功下载文件的原始链接、发布大小与实际大小一致，并用 ffprobe 读取时长／编码，再用 ffmpeg 完整解码 29 个音频，均通过。未使用文件哈希，未启动游戏或执行项目导入，未做人工试听、循环接缝或游戏内混音验收。

没有未下载的入选曲目。

详细记录：[catalog.json](../core/assets/audio/bgm_candidates/catalog.json)；[逐曲来源旁档](../core/assets/audio/bgm_candidates/sources/)；[CC0 许可全文](../core/assets/audio/bgm_candidates/LICENSE-CC0.txt)。
