# GodotParty 资产登记

核查日期：2026-11-08。范围：本机 `F:/GodotProjects/GodotParty` 的当前文件，包括全部 26 个小游戏目录、2 个主游戏目录、默认协议、`core/`、`addons/`、连接测试工具，以及保留的 `temp_game/` 原型、`private_assets/`、`third_party_assets/`、`backups/`。制作所用 SoundFont、模型和直接依赖另检查 `tmp/` 的对应目录。

本表固定为“资产名称、作者、来源、许可协议”四列；同一来源、作者和许可的系列合并登记，路径与数量用于定位。主清单覆盖 **1007 个当前目录资产文件 + 238 个原型副本**，包括图片、模型、音频、字体、着色器、独立资源及资产压缩包；`.tscn` 内嵌几何、材质、动画和脚本生成表现按所属 G／P 项登记，未将每个场景节点当成新资产。`private_assets/`、`third_party_assets/` 和备份也在“当前目录”统计中，文件存在不代表当前运行时引用或已进入导出包。

不把 `.git/`、`.godot/`、导入派生文件、UID、测试截图／缓存、用户设置、SDK／Python 虚拟环境及下载缓存的全部传递依赖逐件作为游戏资产。`tmp/` 仅登记与现有资产直接相关的原始采样、模型和制作工具；不声称完成整台机器或每个历史导出包的 SBOM 审计。原型副本依据各自来源说明和目录对应合并，未做文件内容同一性鉴定。

作者口径依据本次用户确认：**本项目原创的程序美术和合成音效统一为“GPT（代码生成）”**；内置图像生成工具输出统一为 **“GPT（图像生成）”**。代码绘制的 SVG、程序纹理、波形及几何与 ImageGen 图片分开。外部字体、模型、采样经脚本处理后仍保留原作者。AstraBlender 舰船与装甲车辆同时对照既有制作记录和当前源工程路径登记，不凭 GLB 文件格式判断。

许可更新：依据用户 2026-11-08 的明确授权，项目原创／GPT 代码采用 MIT、原创媒体采用 CC0-1.0；[完整范围与例外](../ASSET_LICENSES.md)。第三方许可不改写，未知来源仍待确认；不把“免费／可下载／AI 生成／仓库有 MIT”当作第三方授权。网页仅在需要补证据时核对，已有包内许可证为直接证据。本次未计算、比较或使用文件哈希。

## 当前需要补齐的记录

- **来源链缺口**：U01–U05 继续单列；原创许可声明不消除 MIDI、字体、参考图、截图、DLL 的来源问题。
- **许可未确认**：S09/S10 音源／原谱、S12 配音、T12 DDPM 及 T11/T15 未完整核对的组件；S11/G29 仅原创贡献获 CC0，整份派生谱面仍需补齐底层授权。
- **已分类隔离**：A21 MCP 品牌图标与 L01 Atomic Realm 船包已移至 [third_party_assets/](../third_party_assets/README.md)，实际素材被 Git／Godot 忽略。原型／发布目录发现的 3 份 MCP 图标副本已并入 A21 的 4 文件统计。
- **原创授权已补齐**：I 系列、G 系列、S11 与各内容包原创部分已按 MIT／CC0 声明；G07/G13 包含明确列出的同源原创 Blender 模型。第三方字体、音色、歌曲、图标不受本项目声明影响。

## 第三方美术、模型与纹理

| 资产名称 | 作者 | 来源 | 许可协议 |
| --- | --- | --- | --- |
| **A01 · City Kit Roads<br>当前目录 10 文件** | Kenney / Kenney Vleugels | [作者页面](https://kenney.nl/assets/city-kit-roads)；[本地来源／许可](../games/maingame/godot_party_default_main_game_millionaire/assets/roads/License.txt)<br>位置：`games/maingame/godot_party_default_main_game_millionaire/assets/roads/*` | CC0 1.0；派生、裁选或运行时调色不改变原作者署名。 |
| **A02 · City Kit Commercial<br>当前目录 48 文件** | Kenney / Kenney Vleugels | [作者页面](https://kenney.nl/assets/city-kit-commercial)；[本地来源／许可](../games/maingame/godot_party_default_main_game_millionaire/assets/commercial/License.txt)<br>位置：`games/maingame/godot_party_default_main_game_millionaire/assets/commercial/*`；`games/minigame/gp_blank/assets/kenney_city/commercial/*` | CC0 1.0；派生、裁选或运行时调色不改变原作者署名。 |
| **A03 · City Kit Industrial<br>当前目录 42 文件** | Kenney / Kenney Vleugels | [作者页面](https://kenney.nl/assets/city-kit-industrial)；[本地来源／许可](../games/maingame/godot_party_default_main_game_millionaire/assets/industrial/License.txt)<br>位置：`games/maingame/godot_party_default_main_game_millionaire/assets/industrial/*`；`games/minigame/gp_blank/assets/kenney_city/industrial/*` | CC0 1.0；派生、裁选或运行时调色不改变原作者署名。 |
| **A04 · City Kit Suburban<br>当前目录 57 文件** | Kenney / Kenney Vleugels | [作者页面](https://kenney.nl/assets/city-kit-suburban)；[本地来源／许可](../games/maingame/godot_party_default_main_game_millionaire/assets/suburban/License.txt)<br>位置：`games/maingame/godot_party_default_main_game_millionaire/assets/suburban/*`；`games/minigame/gp_blank/assets/kenney_city/suburban/*` | CC0 1.0；派生、裁选或运行时调色不改变原作者署名。 |
| **A05 · Nature Kit（城市花园及山脊竞速）<br>当前目录 10 文件；原型副本 4 文件** | Kenney / Kenney Vleugels | [作者页面](https://kenney.nl/assets/nature-kit)；[本地来源／许可](../games/maingame/godot_party_default_main_game_millionaire/assets/nature/License.txt)<br>位置：`games/maingame/godot_party_default_main_game_millionaire/assets/nature/*`；`games/minigame/gp_car_racing/assets/kenney_nature_kit/*` | CC0 1.0；派生、裁选或运行时调色不改变原作者署名。 |
| **A06 · Car Kit 3.1<br>当前目录 2 文件；原型副本 2 文件** | Kenney / Kenney Vleugels | [作者页面](https://kenney.nl/assets/car-kit)；[本地来源／许可](../games/minigame/gp_car_racing/ASSET_CREDITS.md)<br>位置：`games/minigame/gp_car_racing/assets/kenney_car_kit/*` | CC0 1.0；派生、裁选或运行时调色不改变原作者署名。 |
| **A07 · Racing Kit 1.2<br>当前目录 4 文件；原型副本 4 文件** | Kenney / Kenney Vleugels | [作者页面](https://kenney.nl/assets/racing-kit)；[本地来源／许可](../games/minigame/gp_car_racing/ASSET_CREDITS.md)<br>位置：`games/minigame/gp_car_racing/assets/kenney_racing_kit/*` | CC0 1.0；派生、裁选或运行时调色不改变原作者署名。 |
| **A08 · Food Kit 2.0（10 个水果模型及色板）<br>当前目录 11 文件；原型副本 11 文件** | Kenney / Kenney Vleugels | [作者页面](https://kenney.nl/assets/food-kit)；[本地来源／许可](../games/minigame/gp_fruit_samurai/assets/ASSET_SOURCES.md)<br>位置：`games/minigame/gp_fruit_samurai/assets/models/*` | CC0 1.0；派生、裁选或运行时调色不改变原作者署名。 |
| **A09 · Platformer Kit 4.1（含旗布、蘑菇派生模型）<br>当前目录 17 文件；原型副本 17 文件** | Kenney / Kenney Vleugels | [作者页面](https://kenney.nl/assets/platformer-kit)；[本地来源／许可](../games/minigame/gp_platformer/ASSET_SOURCES.md)<br>位置：`games/minigame/gp_platformer/assets/kenney/*` | CC0 1.0；派生、裁选或运行时调色不改变原作者署名。 |
| **A10 · Watercraft Kit / Pack 2.0（正式与 prototype）<br>当前目录 13 文件；原型副本 7 文件** | Kenney / Kenney Vleugels | [作者页面](https://kenney.nl/assets/watercraft-kit)；[本地来源／许可](../games/minigame/gp_battleship/prototype/assets/SOURCES.md)<br>位置：`games/minigame/gp_battleship/assets/kenney-watercraft/*`；`games/minigame/gp_battleship/prototype/assets/kenney-watercraft/*` | CC0 1.0；派生、裁选或运行时调色不改变原作者署名。 |
| **A11 · Particle Pack（star_04、star_05）<br>当前目录 2 文件** | Kenney / Kenney Vleugels | [作者页面](https://kenney.nl/assets/particle-pack)；[本地来源／许可](../games/minigame/gp_avalon/upstream_art_sources.md)<br>位置：`games/minigame/gp_avalon/assets/art/avalon_particles/*`；`games/minigame/gp_battleship/assets/impact/*` | CC0 1.0；派生、裁选或运行时调色不改变原作者署名。 |
| **A12 · Light Masks（window_j_blur）<br>当前目录 1 文件** | Kenney / Kenney Vleugels | [作者页面](https://kenney.nl/assets/light-masks)；[本地来源／许可](../games/minigame/gp_avalon/upstream_art_sources.md)<br>位置：`games/minigame/gp_avalon/assets/art/avalon_light_masks/*` | CC0 1.0；派生、裁选或运行时调色不改变原作者署名。 |
| **A13 · Tanks（侧视车体、履带、炮管 PNG）<br>当前目录 3 文件** | Kenney / Kenney Vleugels | [作者页面](https://kenney.nl/assets/tanks)；[本地来源／许可](../games/minigame/gp_artillery/assets/kenney_tanks/License.txt)<br>位置：`games/minigame/gp_artillery/assets/kenney_tanks/*` | CC0 1.0；派生、裁选或运行时调色不改变原作者署名。 |
| **A14 · KayKit Board Game Bits 1.0 · D6_A 骰子<br>当前目录 3 文件** | Kay Lousberg | [作者页面](https://kaylousberg.itch.io/board-game-bits)；[包内许可](../games/maingame/godot_party_default_main_game_millionaire/assets/kaykit/License.txt)；`games/maingame/godot_party_default_main_game_millionaire/assets/kaykit/`（gltf、bin、纹理） | CC0 1.0。 |
| **A15 · Animated Tanks Pack（2019；4 个坦克／训练靶 GLB）<br>当前目录 4 文件；原型副本 4 文件** | Quaternius | [作者页面](https://quaternius.com/packs/animatedtanks.html)；[来源及转换说明](../games/minigame/gp_tank_war/CREDITS.md)；`games/minigame/gp_tank_war/assets/quaternius/` | CC0 1.0；依据本地 2019 包 License.txt，非仅依据作者其他产品许可。 |
| **A16 · Wood Table 001（diffuse、normal、roughness）<br>当前目录 3 文件** | Dimitrios Savva（摄影）、Rico Cilliers（处理）/ Poly Haven | [资产页面](https://polyhaven.com/a/wood_table_001)；[本地来源](../games/minigame/gp_billiards/ART_SOURCES.md)；`games/minigame/gp_billiards/assets/textures/wood_table_001/` | CC0 1.0；本地 LICENSE_CC0.txt。 |
| **A17 · UI Casual Free #5（4 张 PNG）<br>当前目录 4 文件；原型副本 4 文件** | Wenrexa | [作者页面](https://wenrexa.itch.io/free-ui5)；[包来源说明](../games/minigame/gp_fruit_samurai/third_party/ui/ASSET-SOURCES-AND-LICENSES.md)；`games/minigame/gp_fruit_samurai/assets/ui/wenrexa5/` | CC0 1.0；本次核对作者页明确的 Asset license／License 字段。 |
| **A18 · UI Casual Game Interface / Mobile（4 张 PNG）<br>当前目录 4 文件；原型副本 4 文件** | Wenrexa | [作者页面](https://wenrexa.itch.io/uimobile-free)；[包来源说明](../games/minigame/gp_fruit_samurai/third_party/ui/ASSET-SOURCES-AND-LICENSES.md)；`games/minigame/gp_fruit_samurai/assets/ui/mobile/` | CC0 1.0；本次核对作者页明确的 Asset license／License 字段。 |
| **A19 · Hyper Casual UI（7 张 PNG）<br>当前目录 7 文件；原型副本 7 文件** | MadFireOn / Swapnil Rane | [作者页面](https://swapnilrane24.itch.io/hyper-casual-ui-free)；[包来源说明](../games/minigame/gp_fruit_samurai/third_party/ui/ASSET-SOURCES-AND-LICENSES.md)；`games/minigame/gp_fruit_samurai/assets/ui/hypercasual/` | CC0 1.0；本次核对作者页明确的 Asset license／License 字段。 |
| **A20 · Godot 官方图标（主工程、UI、连接测试客户端）<br>当前目录 3 文件** | Godot Engine 项目标志作者／贡献者 | [官方媒体页](https://godotengine.org/press/)；`icon.svg`、`core/ui/components/assets/godot_icon.svg`、`tools/connectivity_client/project/icon.svg` | CC BY 4.0；标志与引擎源码 MIT 分开登记。 |
| **A21 · Godot MCP Toolkit 标志（含 3 份历史副本）<br>当前目录 4 文件** | Jessica Mariana Aisen；版权 NPGameDev | [作者及品牌声明](../addons/godot_mcp_toolkit/ATTRIBUTIONS.md)；现位置 `third_party_assets/all_rights_reserved/files/godot_mcp_toolkit/icon.svg`；[受限分类及三个历史副本](../third_party_assets/all_rights_reserved/assets.md)。 | 保留所有权利；明确不包含在源码 MIT 内，未许可作为其他项目美术复用。 |

## 字体与烘焙字形

| 资产名称 | 作者 | 来源 | 许可协议 |
| --- | --- | --- | --- |
| **F01 · Noto Sans CJK / Noto Sans CJK SC（含重命名的 Interface.ttf、ui_font.ttf）<br>当前目录 12 文件；原型副本 6 文件** | Adobe、Google、Noto CJK 贡献者 | [上游](https://github.com/notofonts/noto-cjk)；[本地许可](../core/ui/components/assets/FONT-LICENSE.txt)；各副本目录保留 Noto／FONT_LICENSE。已读取字体 name 表确认，`ui_font.ttf` 实际为 TTC 集合。 | SIL OFL 1.1；字体不改记为 GPT。 |
| **F02 · Noto Sans CJK SC 字形子集（Sea Interface、Ridgeline Interface、AtelierSans）<br>当前目录 4 文件；原型副本 3 文件** | Adobe、Google、Noto CJK 贡献者；子集加工：GPT（代码生成） | [上游](https://github.com/notofonts/noto-cjk)；[Sea Interface 来源](../games/minigame/gp_battleship/prototype/assets/SOURCES.md)；山脊竞速 `assets/fonts/`、海战棋正式／prototype `assets/fonts/`、记忆拼图 `assets/AtelierSans.otf`。 | SIL OFL 1.1；各包 FONT-LICENSE.txt／LICENSE.txt。AtelierSans 的内部 family 仍为 Noto Sans CJK SC。 |
| **F03 · Moonveil Serif（Noto Serif CJK SC 子集）<br>当前目录 1 文件** | Adobe、Google、Noto CJK 贡献者；子集加工：GPT（代码生成） | [上游](https://github.com/notofonts/noto-cjk)；[来源说明](../games/minigame/gp_avalon/assets/fonts/SOURCES.md)；`games/minigame/gp_avalon/assets/fonts/MoonveilSerif.otf` | SIL OFL 1.1；同目录 LICENSE.txt。 |
| **F04 · Source Han Sans CN Regular（思源黑体）<br>当前目录 1 文件** | Adobe / Source Han Sans 贡献者 | [上游](https://github.com/adobe-fonts/source-han-sans)；[本地许可](../core/ui/ambient_reveal/fonts/SOURCE-HAN-SANS-LICENSE.txt)；`core/ui/ambient_reveal/fonts/SourceHanSansCN-Regular.otf` | SIL OFL 1.1。 |
| **F05 · Source Han Serif SC Regular（思源宋体）<br>当前目录 1 文件** | Adobe / Source Han Serif 贡献者 | [上游](https://github.com/adobe-fonts/source-han-serif)；[本地许可](../games/assets/godot_party_default_ui/fonts/SOURCE-HAN-SERIF-LICENSE.txt)；`games/assets/godot_party_default_ui/fonts/SourceHanSerifSC-Regular.otf` | SIL OFL 1.1。 |
| **F06 · Ma Shan Zheng / Xiangqi Inscription（象棋刻字子集）<br>当前目录 1 文件** | Ma ShanZheng / The Ma Shan Zheng Project Authors | [上游](https://github.com/googlefonts/mashanzheng)；[子集来源](../games/minigame/gp_3d_chess/doc/credits.md)；`games/minigame/gp_3d_chess/assets/fonts/xiangqi_inscription.ttf` | SIL OFL 1.1；同目录 OFL.txt。 |
| **F07 · DejaVu Sans / Sans Bold（Display.ttf、ui.ttf、ui_bold.ttf）<br>当前目录 4 文件；原型副本 4 文件** | Bitstream、DejaVu 贡献者；版权元数据亦列 Tavmjong Bah | [上游](https://dejavu-fonts.github.io/)；[完整本地许可](../games/minigame/gp_fruit_samurai/third_party/DejaVu-LICENSE.txt)；水果武士／音游 `assets/Display.ttf`、炮火争锋 `prototype/assets/ui*.ttf`。 | Bitstream Vera 字体许可；DejaVu 修改部分为公有领域。不是 OFL 或统一 CC0。 |
| **F08 · 台球球号与 UNO 牌面中的 DejaVu Sans Bold 烘焙字形** | Bitstream、DejaVu 贡献者；排版／纹理生成：GPT（代码生成） | [台球字形记录](../games/minigame/gp_billiards/ART_SOURCES.md)；[UNO 固定字体路径](../games/minigame/gp_cards/tools/generate_uno_art.py)；纹理本体另见 G05、G08。 | 字体本体沿用 Bitstream Vera／DejaVu 许可；不据此将整张原创纹理记为第三方原图。Blackjack 的实际字体另列 U02。 |

## 第三方音效、音乐与谱面

| 资产名称 | 作者 | 来源 | 许可协议 |
| --- | --- | --- | --- |
| **S01 · JC Sounds UI Utility Pack Vol. 1（2 个 UI WAV）<br>当前目录 2 文件** | JC Sounds | [原作者发布页](https://opengameart.org/content/jc-sounds-ui-utility-pack-vol-1)；`core/ui/ambient_reveal/audio/UI_Single_Set 13_01-001.wav`、`UI_Swell Down_Set 12_02.wav`；经本地 GodotUICase 引入。 | CC BY 4.0；作者页明确要求署名 JC Sounds；当前音频目录未见单独许可文件。 |
| **S02 · Interface Sounds（阿瓦隆操作声及 3 个历史音游候选）<br>当前目录 5 文件** | Kenney | [作者页](https://kenney.nl/assets/interface-sounds)；[阿瓦隆许可](../games/minigame/gp_avalon/assets/audio/kenney_interface_license.txt)；`assets/audio/click_001.ogg`、`pluck_001.ogg`；音游 `assets/audio_candidates/interface/`。 | CC0 1.0；音游候选已停用但文件仍在。 |
| **S03 · Music Jingles（jingles_PIZZA01.ogg）<br>当前目录 1 文件** | Kenney Vleugels | [原作者发布页](https://opengameart.org/content/85-short-music-jingles)；[本地许可](../games/minigame/gp_avalon/assets/audio/kenney_jingles_license.txt)；阿瓦隆远征成功音效；`tmp/avalon_audio_sources/jingleSounds_Kenney.zip` 为原包。 | CC0 1.0。 |
| **S04 · Glass Break（glass_breaking.wav）<br>当前目录 1 文件** | Till Behrend；TinyWorlds 经授权发布 | [来源页](https://opengameart.org/content/glass-break)；[已有署名记录](../doc/credits.md)；`games/minigame/gp_avalon/assets/audio/glass_breaking.wav` | CC0；本次检索取得原发布页索引内容，列明原作者、授权上传与 CC0；直接打开被网站限制，音频旁未见独立许可文件。 |
| **S05 · Impact Sounds（3 个历史候选）<br>当前目录 3 文件** | Kenney | [作者页](https://kenney.nl/assets/impact-sounds)；`games/minigame/gp_rhythm_game/assets/audio_candidates/impact/`；同目录 LICENSE.txt。 | CC0 1.0；历史候选，仍保留文件。 |
| **S06 · UI Audio（2 个历史候选）<br>当前目录 2 文件** | Kenney | [作者页](https://kenney.nl/assets/ui-audio)；`games/minigame/gp_rhythm_game/assets/audio_candidates/ui/`；同目录 LICENSE.txt。 | CC0 1.0；历史候选，仍保留文件。 |
| **S07 · Virtuosity Drums（12 个采样，各有 FLAC 与 WAV）<br>当前目录 24 文件** | Versilian Studios、Karoryfer Samples；演奏 Austin McMahon | [官方](https://versilian-studios.com/virtuosity-drums/)；[作者源仓库](https://github.com/sfzinstruments/virtuosity_drums)；[逐采样原始路径](../games/minigame/gp_rhythm_game/assets/audio_candidates/virtuosity/sources.json)；同目录 LICENSE.txt。 | CC0 1.0；转换为 WAV 不改变采样作者。 |
| **S08 · FluidR3 GM v3.1（191 个离线渲染 WAV）<br>当前目录 191 文件** | Frank Wen 及 UPSTREAM_README 所列贡献者 | [源仓库](https://github.com/pianobooster/fluid-soundfont)；[渲染与来源说明](../games/minigame/gp_rhythm_game/assets/audio_candidates/fluid_r3/SOURCES.md)；同目录 LICENSE.txt、UPSTREAM_README.txt、samples.json。 | MIT；音色来自第三方 SoundFont，不能记作 GPT 原创。TinySoundFont 是制作工具，见 T03。 |
| **S09 · Bad Apple!! 测试音源（剪辑版、完整版）<br>当前目录 2 文件；原型副本 1 文件** | Alstroemeria Records；Masayoshi Minoshima、nomico；原曲 ZUN | [剪辑版配套音源页面](https://zenius-i-vanisher.com/v5.2/viewsimfile.php?simfileid=9526)；[完整版归档页](https://archive.org/details/bad-apple-10th-anniversary-phase1)；[剪辑版说明](../games/minigame/gp_rhythm_game/charts/bad_apple/SOURCE.md)；[完整版说明](../games/minigame/gp_rhythm_game/charts/bad_apple_full/SOURCE.md)；两目录内 OGG。 | 再发行许可未确认；已有文件说明仅用于本地原型测试。下载页不作为授权证明，转码／分轨不会产生新的歌曲授权。 |
| **S10 · Gpop 的 Bad Apple!! 原始及转换谱面** | Gpop | [原谱页面](https://zenius-i-vanisher.com/v5.2/viewsimfile.php?simfileid=9526)；`games/minigame/gp_rhythm_game/charts/bad_apple/source.sm`、`chart.json`、`normal.json`、`hard.json`、`Bad_Apple_4K_Normal.json`；各 JSON mapper 为 Gpop。 | 谱面再发行许可未确认；2K／4K 转换不改记为 GPT 原创谱。 |
| **S11 · 用户编排／编辑的 Bad Apple!! 谱面与恢复副本** | jza（以文件 mapper 字段为准） | `games/minigame/gp_rhythm_game/charts/bad_apple/baddapple_10-11节示例.json`、`baddapple_测试*.json`；`charts/bad_apple_full/Bad_Apple!!_-_jza.json`；`.editor_recovery/` 中相应副本。 | 用户原创编排贡献采用 CC0-1.0；恢复副本同样适用。配套音源、借用原谱和 MIDI 权利不因此改变；[包内声明](../games/minigame/gp_rhythm_game/ASSET_LICENSES.md)。 |
| **S12 · 空白模板中文示例配音 voice_a / voice_b<br>当前目录 2 文件** | Microsoft Huihui（Windows 离线语音合成）；示例文本来自本项目 | `games/minigame/gp_blank/examples/audio/samples/voice_a.wav`、`voice_b.wav`；[本机合成记录](../doc/credits.md)。 | 未取得该本机语音输出的可核对分发许可；待确认。不是 GPT 合成音，也不按 Windows 字体或项目代码许可推定。 |

## GPT 图像生成资产

| 资产名称 | 作者 | 来源 | 许可协议 |
| --- | --- | --- | --- |
| **I01 · 森系手帖主菜单角色（已移除）** | GPT（图像生成 / OpenAI ImageGen）；参考图由用户提供 | 已随 sage 主题从当前工程移除；[2026-10-23 生成记录](../doc/credits.md)。 | 项目所有者可授权的原创输出采用 CC0-1.0；[许可声明](../ASSET_LICENSES.md)。参考图权利链仍见 U03。 |
| **I02 · Bot 头像套装 V2 正面摆正版（6 张）<br>当前目录 6 文件** | GPT（图像生成）；用户提供角色参考与成品 | [生成方式与逐图名单](../games/protocols/godot_party_default_protocol/avatars/godot_party_default_avatars_2d/avatar_sources/bot_avatars_upright/README.md)；同目录 6 张 PNG。 | 项目所有者可授权的原创输出采用 CC0-1.0；[许可声明](../ASSET_LICENSES.md)。参考图权利链仍见 U03。 |
| **I03 · 竞拍大师写实物资图（100 张透明 PNG）<br>当前目录 100 文件** | GPT（图像生成 / 内置 ImageGen）；Pillow 后处理为代码加工 | [生成说明](../games/minigame/gp_auction_master/SOURCE.md)；[逐图提示词与文件名](../games/minigame/gp_auction_master/assets/items/realistic/generation_prompts.json)；同目录 PNG。 | 项目所有者可授权的原创输出采用 CC0-1.0；[许可声明](../ASSET_LICENSES.md)。生成／后处理代码为 MIT。 |

## GPT 代码生成的程序美术、模型与合成音效

| 资产名称 | 作者 | 来源 | 许可协议 |
| --- | --- | --- | --- |
| **G01 · 框架 UI 主题、几何图标、背景与鼠标指示（含保留旧主题）<br>当前目录 51 文件** | GPT（代码生成） | `core/ui/ambient_reveal/`、`core/ui/source/`、`core/ui/components/`、`core/ui/settings/`；来源为本项目、GodotPartyUI 与本地 GodotUICase；已将字体、官方图标、音效与 ImageGen 图片分列。 | 原创代码／着色器／场景／资源定义为 MIT；原创图像、模型、动画与合成音效（含程序输出）为 CC0-1.0；见 [许可范围](../ASSET_LICENSES.md)，第三方部分保持原许可。 |
| **G02 · 默认协议形象、Cube、颜色标记与程序音色资源** | GPT（代码生成） | `games/protocols/godot_party_default_protocol/avatars/godot_party_default_avatars_2d/`、`avatars/`、`briefing/`、`audio/audio_cue.gd`；[形象说明](../games/protocols/godot_party_default_protocol/avatars/godot_party_default_avatars/ATTRIBUTION.md)；不含 I02 与 F01/F05。 | 原创代码／着色器／场景／资源定义为 MIT；原创图像、模型、动画与合成音效（含程序输出）为 CC0-1.0；见 [许可范围](../ASSET_LICENSES.md)，第三方部分保持原许可。 |
| **G03 · 大富翁地图网格、道路组合、地块标记、老虎机与 UI<br>当前目录 1 文件** | GPT（代码生成） | `games/maingame/godot_party_default_main_game_millionaire/map_grid.gdshader`、`board_markers.gd`、`maps/`、`editor/`、`slot_machine/`；下载的城市模型另列 A01–A07/A14。 | 原创代码／着色器／场景／资源定义为 MIT；原创图像、模型、动画与合成音效（含程序输出）为 CC0-1.0；见 [许可范围](../ASSET_LICENSES.md)，第三方部分保持原许可。 |
| **G04 · 竞拍大师旧版 40 张 SVG、仓库／货架与 UI<br>当前目录 41 文件** | GPT（代码生成） | `games/minigame/gp_auction_master/assets/items/*.svg`、`warehouse_view.gd`、场景；[来源说明](../games/minigame/gp_auction_master/SOURCE.md)。SVG 为停用保留源文件。 | 原创代码／着色器／场景／资源定义为 MIT；原创图像、模型、动画与合成音效（含程序输出）为 CC0-1.0；见 [许可范围](../ASSET_LICENSES.md)，第三方部分保持原许可。 |
| **G05 · 3d桌球球号贴图（16 张）、球房／台面／球杆与合成反馈<br>当前目录 16 文件** | GPT（代码生成） | `games/minigame/gp_billiards/assets/balls/ball_00.png`–`ball_15.png`、`game.gd` 与场景；[程序资产说明](../games/minigame/gp_billiards/ART_SOURCES.md)。木材见 A16，球号字形见 F08。 | 原创代码／着色器／场景／资源定义为 MIT；原创图像、模型、动画与合成音效（含程序输出）为 CC0-1.0；见 [许可范围](../ASSET_LICENSES.md)，第三方部分保持原许可。 字形不重新授权，见 F08。 |
| **G06 · 海战棋海面、噪声图、命中／水线特效、原型图标与合成音<br>当前目录 8 文件；原型副本 5 文件** | GPT（代码生成） | `games/minigame/gp_battleship/assets/shaders/`、`textures/ocean_fields.png`、`shell_burst.gd`、`tools/generate_ocean_noise.py`；[明确 Codex 辅助制作记录](../games/minigame/gp_battleship/prototype/assets/SOURCES.md)。 | 原创代码／着色器／场景／资源定义为 MIT；原创图像、模型、动画与合成音效（含程序输出）为 CC0-1.0；见 [许可范围](../ASSET_LICENSES.md)，第三方部分保持原许可。 |
| **G07 · 海战棋原创舰队（5 舰完整／摧毁状态，10 个 GLB）<br>当前目录 10 文件** | GPT（代码生成 / Blender 程序化建模）；用户提供源工程 | `games/minigame/gp_battleship/assets/fleet/`、`assets/yamato/`；[原创来源说明](../games/minigame/gp_battleship/assets/SOURCES.md)；本地 `F:/AstraBlender/Projects/1_Blender工程/BattleshipChess_Fleet/` 已确认有对应 .blend，制作方式结合既有建模记录核对。 | CC0-1.0；覆盖项目内原创 GLB 及本行指定同源原创 Blender 模型内容，生成代码为 MIT；[声明](../ASSET_LICENSES.md)。 |
| **G08 · 纸牌会客厅原创卡面、牌背、双王、桌面与动画<br>当前目录 118 文件；原型副本 118 文件** | GPT（代码生成） | `games/minigame/gp_cards/prototype/assets/`：53 张 blackjack PNG、55 张 uno PNG、8 张基础 SVG、2 张双王 SVG；[扑克生成器](../games/minigame/gp_cards/tools/generate_blackjack_art.py)、[UNO 生成器](../games/minigame/gp_cards/tools/generate_uno_art.py)。 | 原创代码／着色器／场景／资源定义为 MIT；原创图像、模型、动画与合成音效（含程序输出）为 CC0-1.0；见 [许可范围](../ASSET_LICENSES.md)，第三方部分保持原许可。 字形不重新授权，见 F08／U02。 |
| **G09 · 阿瓦隆／狼人杀原创 SVG（16 张）、桌面、粒子与 UI<br>当前目录 16 文件** | GPT（代码生成） | [逐图来源](../games/minigame/gp_avalon/upstream_art_sources.md)；`assets/art/*.svg`、`scripts/ui/` 与场景；非官方阿瓦隆美术。 | 原创代码／着色器／场景／资源定义为 MIT；原创图像、模型、动画与合成音效（含程序输出）为 CC0-1.0；见 [许可范围](../ASSET_LICENSES.md)，第三方部分保持原许可。 |
| **G10 · 记忆拼图（11 张玩法 SVG、garden 预览、icon）<br>当前目录 13 文件；原型副本 2 文件** | GPT（代码生成） | [图画名单](../games/minigame/gp_jigsaw/README.md)；`assets/pictures/*.svg`、`assets/garden.svg`、`assets/icon.svg`，以及 3D 拼图／界面场景。 | 原创代码／着色器／场景／资源定义为 MIT；原创图像、模型、动画与合成音效（含程序输出）为 CC0-1.0；见 [许可范围](../ASSET_LICENSES.md)，第三方部分保持原许可。 |
| **G11 · 连连看（10 张水果 SVG、立体棋子、棋盘）<br>当前目录 10 文件** | GPT（代码生成） | `games/minigame/gp_matching/assets/icons/`、`board_3d.gd`、`matching_piece.gd`；[原型来源](../games/minigame/gp_matching/SOURCE.md)。 | 原创代码／着色器／场景／资源定义为 MIT；原创图像、模型、动画与合成音效（含程序输出）为 CC0-1.0；见 [许可范围](../ASSET_LICENSES.md)，第三方部分保持原许可。 |
| **G12 · 雷霆战争原创 HUD 剪影（11 张）、环境及 3 个合成 WAV<br>当前目录 17 文件；原型副本 3 文件** | GPT（代码生成） | `games/minigame/gp_tank_war/assets/ui/`、`assets/audio/`、`scripts/` 与场景；[原创声明](../games/minigame/gp_tank_war/CREDITS.md)。 | 原创代码／着色器／场景／资源定义为 MIT；原创图像、模型、动画与合成音效（含程序输出）为 CC0-1.0；见 [许可范围](../ASSET_LICENSES.md)，第三方部分保持原许可。 |
| **G13 · M1 Abrams、BMPT Terminator、M2A2 Bradley（3 个 GLB）<br>当前目录 3 文件** | GPT（代码生成 / Blender 建模）；用户提供源工程 | [原始工程说明](../games/minigame/gp_tank_war/CREDITS.md)；`assets/m1_abrams/`、`assets/bmpt/`、`assets/bradley/`；`F:/AstraBlender/Projects/1_Blender工程/MainBattleTanks/` 对应 .blend 已存在，结合既有制作记录与本次用户确认登记。 | CC0-1.0；覆盖项目内原创 GLB 及本行指定同源原创 Blender 模型内容，生成代码为 MIT；[声明](../ASSET_LICENSES.md)。 |
| **G14 · 海岸飞行飞机／地形几何与螺旋桨合成音<br>当前目录 2 文件；原型副本 1 文件** | GPT（代码生成） | `games/minigame/gp_flight/scripts/`、场景、`assets/propeller.wav`；[原始波形生成器](../games/minigame/gp_flight/tools/generate_engine_audio.py)。 | 原创代码／着色器／场景／资源定义为 MIT；原创图像、模型、动画与合成音效（含程序输出）为 CC0-1.0；见 [许可范围](../ASSET_LICENSES.md)，第三方部分保持原许可。 |
| **G15 · 水果武士切割／轨迹／调色着色器与 4 个合成 WAV<br>当前目录 10 文件；原型副本 6 文件** | GPT（代码生成） | `games/minigame/gp_fruit_samurai/assets/audio/`、`audio/*.tres`、`scripts/board.gdshader`、`fruit_palette.gdshader`、`slice_effects.gd`。下载模型及 UI 单列。 | 原创代码／着色器／场景／资源定义为 MIT；原创图像、模型、动画与合成音效（含程序输出）为 CC0-1.0；见 [许可范围](../ASSET_LICENSES.md)，第三方部分保持原许可。 |
| **G16 · 云间跃行角色／敌人、几何背景、碎片、UI 与合成音<br>原型副本 11 文件** | GPT（代码生成） | [原创部分说明](../games/minigame/gp_platformer/ASSET_SOURCES.md)；`scripts/shapes.gd`、`sound.gd`、`world11_assets.gd` 与场景；Kenney 派生物仍归 A09。 | 原创代码／着色器／场景／资源定义为 MIT；原创图像、模型、动画与合成音效（含程序输出）为 CC0-1.0；见 [许可范围](../ASSET_LICENSES.md)，第三方部分保持原许可。 |
| **G17 · 炮火争锋原型 SVG、地形 shader、战场与合成音<br>当前目录 6 文件；原型副本 6 文件** | GPT（代码生成） | `games/minigame/gp_artillery/prototype/assets/*.svg`、`prototype/shaders/terrain.gdshader`、`prototype/scripts/sound.gd`、`battlefield.gd`。 | 原创代码／着色器／场景／资源定义为 MIT；原创图像、模型、动画与合成音效（含程序输出）为 CC0-1.0；见 [许可范围](../ASSET_LICENSES.md)，第三方部分保持原许可。 |
| **G18 · 山脊竞速原创赛道／海岸／港口、车辆反馈与合成引擎音<br>当前目录 2 文件；原型副本 2 文件** | GPT（代码生成） | [原创范围说明](../games/minigame/gp_car_racing/ASSET_CREDITS.md)；`scripts/track_world.gd`、`harbor_scenery.gd`、`arcade_car.gd`；`docs/*.png` 为项目实机截图。 | 原创代码／着色器／场景／资源定义为 MIT；原创图像、模型、动画与合成音效（含程序输出）为 CC0-1.0；见 [许可范围](../ASSET_LICENSES.md)，第三方部分保持原许可。 |
| **G19 · 贪吃蛇棋盘、蛇身与合成音<br>当前目录 1 文件** | GPT（代码生成） | `games/minigame/gp_snake/board_grid.gdshader`、`board_view.gd`、`sound_bank.gd`、场景；[原型来源](../games/minigame/gp_snake/SOURCE.md)。 | 原创代码／着色器／场景／资源定义为 MIT；原创图像、模型、动画与合成音效（含程序输出）为 CC0-1.0；见 [许可范围](../ASSET_LICENSES.md)，第三方部分保持原许可。 |
| **G20 · 星潮深空／丝带 shader、弹幕与程序表现<br>当前目录 2 文件** | GPT（代码生成） | `games/minigame/gp_star_wave/assets/shaders/`、`visual.gd` 与场景；[原型来源](../games/minigame/gp_star_wave/SOURCE.md)。 | 原创代码／着色器／场景／资源定义为 MIT；原创图像、模型、动画与合成音效（含程序输出）为 CC0-1.0；见 [许可范围](../ASSET_LICENSES.md)，第三方部分保持原许可。 |
| **G21 · 极速追逐地图／几何／UI 与合成短音效<br>当前目录 5 文件** | GPT（代码生成） | `games/minigame/gp_chase/scripts/`、`audio/*.tres`；[原创声明](../games/minigame/gp_chase/README.md)。 | 原创代码／着色器／场景／资源定义为 MIT；原创图像、模型、动画与合成音效（含程序输出）为 CC0-1.0；见 [许可范围](../ASSET_LICENSES.md)，第三方部分保持原许可。 |
| **G22 · 圆角俄罗斯方块、主题及合成反馈<br>当前目录 4 文件；原型副本 4 文件** | GPT（代码生成） | `games/minigame/gp_tetris/scripts/rounded_cube.gd`、`main.gd`、场景；`assets/speed_profile.tres` 为曲线配置，`screenshots/` 为项目截图。 | 原创代码／着色器／场景／资源定义为 MIT；原创图像、模型、动画与合成音效（含程序输出）为 CC0-1.0；见 [许可范围](../ASSET_LICENSES.md)，第三方部分保持原许可。 |
| **G23 · 铁鹰防线原型图标、坦克／场地几何与合成反馈<br>当前目录 1 文件；原型副本 1 文件** | GPT（代码生成） | `games/minigame/gp_tank_battle/prototype/assets/icon.svg`、`prototype/scripts/main.gd` 与场景。 | 原创代码／着色器／场景／资源定义为 MIT；原创图像、模型、动画与合成音效（含程序输出）为 CC0-1.0；见 [许可范围](../ASSET_LICENSES.md)，第三方部分保持原许可。 |
| **G24 · 3D 国际象棋／中国象棋棋子、棋盘、木纹、封面<br>当前目录 2 文件** | GPT（代码生成） | `games/minigame/gp_3d_chess/piece_mesh.gd`、`xiangqi_mesh.gd`、`assets/cover.svg`、`assets/xiangqi_cover.svg` 及场景；[原创说明](../games/minigame/gp_3d_chess/README.md)。 | 原创代码／着色器／场景／资源定义为 MIT；原创图像、模型、动画与合成音效（含程序输出）为 CC0-1.0；见 [许可范围](../ASSET_LICENSES.md)，第三方部分保持原许可。 |
| **G25 · 方向密码、心理博弈的程序画面与 UI<br>原型副本 1 文件** | GPT（代码生成） | `games/minigame/gp_direction_code/`、`games/minigame/gp_psych_party/` 的脚本／场景；原型 `temp_game/PsychologicalPartyGame/demo/debug_theme.tres`。 | 原创代码／着色器／场景／资源定义为 MIT；原创图像、模型、动画与合成音效（含程序输出）为 CC0-1.0；见 [许可范围](../ASSET_LICENSES.md)，第三方部分保持原许可。 |
| **G26 · 蛇蛇大作战、合成大西八的程序绘制与场景** | GPT（代码生成） | `games/minigame/gp_snake_battle/arena_view.gd`；`games/minigame/gp_merge_ssibal/arena_view.gd`、`bin_view.gd`、`merge_world.gd` 及场景。 | 原创代码／着色器／场景／资源定义为 MIT；原创图像、模型、动画与合成音效（含程序输出）为 CC0-1.0；见 [许可范围](../ASSET_LICENSES.md)，第三方部分保持原许可。 |
| **G27 · 空白模板程序几何、音频资源、5 个合成示例 WAV<br>当前目录 12 文件** | GPT（代码生成） | `games/minigame/gp_blank/` 场景；`examples/audio/samples/ambience.wav`、`click.wav`、`impact.wav`、`music_a.wav`、`music_b.wav`；[合成记录](../doc/credits.md)。 | 原创代码／着色器／场景／资源定义为 MIT；原创图像、模型、动画与合成音效（含程序输出）为 CC0-1.0；见 [许可范围](../ASSET_LICENSES.md)，第三方部分保持原许可。 |
| **G28 · 霓虹节拍 UI 图标／主题／皮肤、合成敲击／节拍及长按测试音<br>当前目录 11 文件** | GPT（代码生成） | `games/minigame/gp_rhythm_game/ui/`、`skins/neon.gd`、`rhythm_audio.gd`、`charts/hold_test/hold_test.wav`；外部采样、歌曲、字体已分列。 | 原创代码／着色器／场景／资源定义为 MIT；原创图像、模型、动画与合成音效（含程序输出）为 CC0-1.0；见 [许可范围](../ASSET_LICENSES.md)，第三方部分保持原许可。 |
| **G29 · Codex 音频特征／规则／MIDI 辅助谱面** | GPT（代码生成） | `games/minigame/gp_rhythm_game/charts/bad_apple/authored*.json`、`BadApple_4K_功能测试.json`、`baddapple_MIDI规则试验.json`；`charts/bad_apple_full/BadApple_完整版_MIDI_4K*.json`；[制作说明](../games/minigame/gp_rhythm_game/authoring/README.md)；mapper 字段为 Codex。 | GPT 原创谱面贡献采用 CC0-1.0；生成工具为 MIT。配套歌曲、Gpop 原谱及来源不明 MIDI 不随之授权，整份派生谱面许可仍需补齐；[包内声明](../games/minigame/gp_rhythm_game/ASSET_LICENSES.md)。 |

## 本地试用、参考与归档资产（不等同于正式发行内容）

| 资产名称 | 作者 | 来源 | 许可协议 |
| --- | --- | --- | --- |
| **L01 · Atomic Realm · Sea Assets – Ships Demo<br>当前目录 24 文件** | Atomic Realm | [作者产品页](https://atomicrealm.itch.io/sea-assets)；`third_party_assets/custom_no_redistribution/files/atomic_realm/sea_assets_ships/`：原 ZIP、许可证图片、2 张纹理、完整／摧毁帆船与划艇的 FBX/OBJ/GLB 版本。 [逐文件登记](../third_party_assets/custom_no_redistribution/assets.md)。 | 自定义许可：允许商业／非商业项目使用和修改；禁止重新打包、转售或再分发素材。当前作者页还要求署名链接；本地 `2. License.png` 已目视核对。 |
| **L02 · ShellShock Live 事件视觉参考截图（5 张）<br>当前目录 5 文件** | kChamp Games（官方）；Steam 社区截图上传者待补 | `private_assets/shellshock_event_reference/`；[官方商店](https://store.steampowered.com/app/326460/ShellShock_Live/)、[官方更新](https://store.steampowered.com/news/posts/?appids=326460&enddate=1645653731)、[社区截图](https://steamcommunity.com/sharedfiles/filedetails/?id=2069384920)。 | 未见独立再发行许可；已有记录限定本地视觉参考。逐图来源与社区作者的对应见 U04。 |
| **L03 · 阿瓦隆历史备份 ZIP<br>当前目录 1 文件** | 原资产作者分别为 GPT（代码生成）、Kenney、Noto 字体贡献者 | `backups/avalon_before_table_animations_20261027_233728.zip`；只读查看 ZIP 目录，含旧脚本／SVG／Kenney 纹理／字体及各来源文件。 | 混合许可，沿用各资产原许可；备份本身不授予统一新许可。 |

## 第三方包、引擎与离线制作依赖

| 资产名称 | 作者 | 来源 | 许可协议 |
| --- | --- | --- | --- |
| **T01 · Godot Engine 及引擎内置第三方库** | Godot Engine 贡献者；Juan Linietsky、Ariel Manzur；内置库各自作者 | [上游](https://github.com/godotengine/godot)；[引擎许可](../core/dev/windows_release_notices/Godot-LICENSE.txt)、[完整内置组件版权／许可目录](../core/dev/windows_release_notices/Godot-COPYRIGHT.txt)。 | 引擎 MIT；内置库按 Godot-COPYRIGHT.txt 分项许可，不笼统写成全部 MIT。本次未更换引擎或验证导出二进制与通知文件的版本对应。 |
| **T02 · Godot MCP Toolkit（编辑器插件）** | NPGameDev | [上游](https://github.com/NPGameDev/godot-mcp-toolkit)；`addons/godot_mcp_toolkit/`；[本地 LICENSE](../addons/godot_mcp_toolkit/LICENSE)；plugin.cfg 版本 1.0.0。 | 源码 MIT；标志明确排除，见 A21。ATTRIBUTIONS 内其他 MCP 仓库仅为架构参考，未复制代码，不重复当作已安装包。 |
| **T03 · TinySoundFont v0.9（离线 SoundFont 渲染器）** | Bernhard Schelling；基于 Steve Folta 的 SFZero | [上游](https://github.com/schellingb/TinySoundFont)；`tmp/rhythm_instruments/tsf.h`；[本地许可](../games/minigame/gp_rhythm_game/assets/audio_candidates/fluid_r3/TinySoundFont_LICENSE.txt)；`authoring/render_instrument_sample.c` 引用。 | MIT；仅离线制作，不接入游戏运行时。 |
| **T04 · FluidR3 GM v3.1 原始 SoundFont** | Frank Wen 及贡献者 | [上游](https://github.com/pianobooster/fluid-soundfont)；`tmp/rhythm_instruments/FluidR3_GM.sf2`、`FluidR3_LICENSE.txt`、`FluidR3_README.txt`；渲染结果见 S08。 | MIT；原库保留在忽略目录。 |
| **T05 · Pillow（离线卡牌／贴图／透明边缘加工）** | Alex Clark、Pillow 贡献者；基于 Fredrik Lundh 的 PIL | [上游](https://github.com/python-pillow/Pillow)；纸牌生成器、海战噪声生成器、竞拍图 SOURCE.md 均记录依赖；本地制作环境 METADATA。 | 本地 Pillow 12.3.0 元数据为 MIT-CMU；仅开发依赖，不把库许可直接赋给生成图片。 |
| **T06 · NumPy（离线音频分析与渲染）** | NumPy Developers | [上游](https://github.com/numpy/numpy)；`gp_rhythm_game/authoring/` 中 author.py、generate_easy.py、render_instruments.py；本地制作环境包许可。 | BSD-3-Clause；二进制分发中的 OpenBLAS 等组件另有许可，以本地完整 LICENSE 为准。 |
| **T07 · SoundFile 与 libsndfile（FLAC/WAV 解码）** | Bastian Bechtold / SoundFile 贡献者；Erik de Castro Lopo / libsndfile 贡献者 | [SoundFile](https://github.com/bastibe/python-soundfile)；[libsndfile 官方许可说明](https://libsndfile.github.io/libsndfile/#licensing)；`tmp/audio_tools/libsndfile_x64.dll`、制谱脚本 import soundfile 与 Virtuosity 转码记录。 | SoundFile：BSD-3-Clause（本地元数据）；libsndfile：官方允许选择 LGPL 2.1 或 LGPL 3。独立 DLL 的准确构建版本及附带通知未记录，见 U05。 |
| **T08 · Mido（读取用户 MIDI）** | Ole Martin Bjørndalen、Mido 贡献者 | [上游](https://github.com/mido/mido)；`authoring/generate_midi_four_key.py`、本地 mido-1.3.3.dist-info。 | MIT（本地 METADATA）。MIDI 文件版权不由库许可覆盖。 |
| **T09 · Demucs / htdemucs（离线分轨）** | Facebook Research / Meta、Alexandre Défossez 及贡献者 | [上游及许可](https://github.com/facebookresearch/demucs)；`tmp/rhythm_ml/models/htdemucs.th`、`stems/htdemucs/`；模型下载脚本记录官方模型 URL。 | MIT（上游及本地包元数据）；分轨产物仍来自 S09 歌曲。仅实验。 |
| **T10 · Spotify Basic Pitch（ONNX 模型）** | Spotify / Basic Pitch 贡献者 | [上游许可](https://github.com/spotify/basic-pitch/blob/main/LICENSE)；`tmp/rhythm_ml/venv/Lib/site-packages/basic_pitch/saved_models/icassp_2022/nmp.onnx`。 | Apache-2.0（上游项目）；仅离线实验。 |
| **T11 · MERT-v1-95M（权重及自定义模型代码）** | m-a-p / Multimodal Art Projection 贡献者 | [模型卡](https://huggingface.co/m-a-p/MERT-v1-95M)；`tmp/rhythm_ml/models/MERT-v1-95M/`；modeling_MERT.py 另说明改编 Transformers 与 fairseq 代码。 | 模型卡：CC BY-NC 4.0；本地自定义代码未见独立完整许可说明，相关上游代码不能只用权重许可概括。仅实验。 |
| **T12 · osu-mania-beatmap-generator / DDPM_Beatmap_Cond_Model_01** | HibikiDad | [上游](https://github.com/HibikiDad/osu-mania-beatmap-generator)；`tmp/rhythm_ml/ddpm/`、`Models/DDPM_Beatmap_Cond_Model_01.pth`。 | 本地副本未见 LICENSE，公开仓库页面亦未确认明确许可；待确认，不因可下载就标开源授权。 |
| **T13 · Mapperatorinator 与 v32 / gamemode=3 权重** | OliBomby 及贡献者 | [代码](https://github.com/OliBomby/Mapperatorinator)；[模型卡](https://huggingface.co/OliBomby/Mapperatorinator-v32)；`tmp/rhythm_ml/mapper/`、`models/Mapperatorinator-v32/gamemode=3/`。 | MIT（本地代码 LICENSE 与模型卡分别确认）；模型输出不改变输入歌曲／谱面的权利。 |
| **T14 · GodotPartyUI、Ambient Reveal 与 GodotParty Tools** | jza10086 / 本项目贡献者；原创程序美术按本次确认记为 GPT（代码生成） | [GodotPartyUI](https://github.com/jza10086/GodotPartyUI)；`F:/GodotProjects/GodotUICase/ambient_reveal/`；本项目 `core/ui/` 与 `addons/godot_party_tools/`。 | 纳入本工程的用户／GPT 原创代码为 MIT、原创媒体为 CC0-1.0；[范围声明](../ASSET_LICENSES.md)。第三方字体、音效不重新授权；未修改工程外上游仓库的许可。 |
| **T15 · MCP 外部桥接服务（开发依赖）** | NPGameDev | 插件 README 指向 [@npgamedev/godot-mcp-server](https://github.com/NPGameDev/godot-mcp-server)；本项目 `.mcp.json` 经项目外 GodotTools 启动器调用，服务实现未随本仓库内置。 | 本次未核对外部实际安装版本／许可证，不把插件的 MIT 自动套用给外部安装。 |

## 各内容包的代码来源与许可覆盖

| 资产名称 | 作者 | 来源 | 许可协议 |
| --- | --- | --- | --- |
| **P01 · GodotPartyDefault · 竞拍大师** | jza10086 / 本包贡献者；AuctionMaster contributors | [源码仓库](https://github.com/jza10086/AuctionMaster)；`games/minigame/gp_auction_master/` | 本项目原创代码为 MIT；原创媒体为 CC0-1.0；各包已附 LICENSE、LICENSE-CC0.txt 与 ASSET_LICENSES.md。第三方及待确认部分保持各自许可状态。 |
| **P02 · GodotPartyDefault · 3d桌球** | jza10086 / 本包贡献者 | [源码仓库](https://github.com/jza10086/Billiards)；`games/minigame/gp_billiards/` | 本项目原创代码为 MIT；原创媒体为 CC0-1.0；各包已附 LICENSE、LICENSE-CC0.txt 与 ASSET_LICENSES.md。第三方及待确认部分保持各自许可状态。 |
| **P03 · GodotPartyDefault · 水果武士** | jza10086 / 本包贡献者；Fruit Samurai contributors | [源码仓库](https://github.com/jza10086/FruitSamurai)；`games/minigame/gp_fruit_samurai/` | 本项目原创代码为 MIT；原创媒体为 CC0-1.0；各包已附 LICENSE、LICENSE-CC0.txt 与 ASSET_LICENSES.md。第三方及待确认部分保持各自许可状态。 |
| **P04 · GodotPartyDefault · 阿瓦隆** | jza10086 / 本包贡献者 | [源码仓库](https://github.com/jza10086/IdentityTemplate)；`games/minigame/gp_avalon/` | 本项目原创代码为 MIT；原创媒体为 CC0-1.0；各包已附 LICENSE、LICENSE-CC0.txt 与 ASSET_LICENSES.md。第三方及待确认部分保持各自许可状态。 |
| **P05 · GodotPartyDefault · 连连看** | jza10086 / 本包贡献者 | [源码仓库](https://github.com/jza10086/MatchingGame)；`games/minigame/gp_matching/` | 本项目原创代码为 MIT；原创媒体为 CC0-1.0；各包已附 LICENSE、LICENSE-CC0.txt 与 ASSET_LICENSES.md。第三方及待确认部分保持各自许可状态。 |
| **P06 · GodotPartyDefault · 云间跃行** | jza10086 / 本包贡献者；Cloudstep contributors | [源码仓库](https://github.com/jza10086/Platformer)；`games/minigame/gp_platformer/` | 本项目原创代码为 MIT；原创媒体为 CC0-1.0；各包已附 LICENSE、LICENSE-CC0.txt 与 ASSET_LICENSES.md。第三方及待确认部分保持各自许可状态。 |
| **P07 · GodotPartyDefault · 心理博弈** | jza10086 / 本包贡献者 | [源码仓库](https://github.com/jza10086/PsychologicalPartyGame)；`games/minigame/gp_psych_party/` | 本项目原创代码为 MIT；原创媒体为 CC0-1.0；各包已附 LICENSE、LICENSE-CC0.txt 与 ASSET_LICENSES.md。第三方及待确认部分保持各自许可状态。 |
| **P08 · GodotPartyDefault · 贪吃蛇** | jza10086 / 本包贡献者；SnakeGame contributors | [源码仓库](https://github.com/jza10086/SnakeGame)；`games/minigame/gp_snake/` | 本项目原创代码为 MIT；原创媒体为 CC0-1.0；各包已附 LICENSE、LICENSE-CC0.txt 与 ASSET_LICENSES.md。第三方及待确认部分保持各自许可状态。 |
| **P09 · GodotPartyDefault · 星潮** | jza10086 / 本包贡献者 | [源码仓库](https://github.com/jza10086/StarWave)；`games/minigame/gp_star_wave/` | 本项目原创代码为 MIT；原创媒体为 CC0-1.0；各包已附 LICENSE、LICENSE-CC0.txt 与 ASSET_LICENSES.md。第三方及待确认部分保持各自许可状态。 |
| **P10 · 霓虹节拍** | jza10086 / 本包贡献者 | [源码仓库](https://github.com/jza10086/MusicGame)；`games/minigame/gp_rhythm_game/` | 本项目原创代码为 MIT；原创媒体为 CC0-1.0；各包已附 LICENSE、LICENSE-CC0.txt 与 ASSET_LICENSES.md。第三方及待确认部分保持各自许可状态。 |
| **P11 · 方向密码** | jza10086 / 本包贡献者 | [源码仓库](https://github.com/jza10086/MemoryGame)；`games/minigame/gp_direction_code/` | 本项目原创代码为 MIT；原创媒体为 CC0-1.0；各包已附 LICENSE、LICENSE-CC0.txt 与 ASSET_LICENSES.md。第三方及待确认部分保持各自许可状态。 |
| **P12 · 记忆拼图** | jza10086 / 本包贡献者 | [源码仓库](https://github.com/jza10086/JigsawPuzzle)；`games/minigame/gp_jigsaw/` | 本项目原创代码为 MIT；原创媒体为 CC0-1.0；各包已附 LICENSE、LICENSE-CC0.txt 与 ASSET_LICENSES.md。第三方及待确认部分保持各自许可状态。 |
| **P13 · 极速追逐** | jza10086 / 本包贡献者 | [源码仓库](https://github.com/jza10086/3DPlatformer)；`games/minigame/gp_chase/` | 本项目原创代码为 MIT；原创媒体为 CC0-1.0；各包已附 LICENSE、LICENSE-CC0.txt 与 ASSET_LICENSES.md。第三方及待确认部分保持各自许可状态。 |
| **P14 · 雷霆战争** | jza10086 / 本包贡献者；jza10086 | [源码仓库](https://github.com/jza10086/3DTankBattle)；`games/minigame/gp_tank_war/` | 本项目原创代码为 MIT；原创媒体为 CC0-1.0；各包已附 LICENSE、LICENSE-CC0.txt 与 ASSET_LICENSES.md。第三方及待确认部分保持各自许可状态。 |
| **P15 · 山脊竞速** | jza10086 / 本包贡献者；jza10086 | [源码仓库](https://github.com/jza10086/CarRacing)；`games/minigame/gp_car_racing/` | 本项目原创代码为 MIT；原创媒体为 CC0-1.0；各包已附 LICENSE、LICENSE-CC0.txt 与 ASSET_LICENSES.md。第三方及待确认部分保持各自许可状态。 |
| **P16 · COASTLINE · 海岸飞行** | jza10086 / 本包贡献者；FlightGame contributors | [源码仓库](https://github.com/jza10086/FlightGame)；`games/minigame/gp_flight/` | 本项目原创代码为 MIT；原创媒体为 CC0-1.0；各包已附 LICENSE、LICENSE-CC0.txt 与 ASSET_LICENSES.md。第三方及待确认部分保持各自许可状态。 |
| **P17 · 圆角俄罗斯方块** | jza10086 / 本包贡献者 | [源码仓库](https://github.com/jza10086/RussianBlock)；`games/minigame/gp_tetris/` | 本项目原创代码为 MIT；原创媒体为 CC0-1.0；各包已附 LICENSE、LICENSE-CC0.txt 与 ASSET_LICENSES.md。第三方及待确认部分保持各自许可状态。 |
| **P18 · 铁鹰防线** | jza10086 / 本包贡献者；TankBattle contributors | [源码仓库](https://github.com/jza10086/TankBattle)；`games/minigame/gp_tank_battle/`；manifest 的 playable=false 不代表目录没有资产。 | 本项目原创代码为 MIT；原创媒体为 CC0-1.0；各包已附 LICENSE、LICENSE-CC0.txt 与 ASSET_LICENSES.md。第三方及待确认部分保持各自许可状态。 |
| **P19 · 海战棋** | jza10086 / 本包贡献者；BattleshipChess contributors | [源码仓库](https://github.com/jza10086/BattleshipChess)；`games/minigame/gp_battleship/` | 本项目原创代码为 MIT；原创媒体为 CC0-1.0；各包已附 LICENSE、LICENSE-CC0.txt 与 ASSET_LICENSES.md。第三方及待确认部分保持各自许可状态。 |
| **P20 · 炮火争锋** | jza10086 / 本包贡献者；ArtilleryGame contributors | [源码仓库](https://github.com/jza10086/ArtilleryGame)；`games/minigame/gp_artillery/` | 本项目原创代码为 MIT；原创媒体为 CC0-1.0；各包已附 LICENSE、LICENSE-CC0.txt 与 ASSET_LICENSES.md。第三方及待确认部分保持各自许可状态。 |
| **P21 · 纸牌会客厅** | jza10086 / 本包贡献者 | [源码仓库](https://github.com/jza10086/GodotCardGame)；`games/minigame/gp_cards/`；manifest 的 playable=false 不代表目录没有资产。 | 本项目原创代码为 MIT；原创媒体为 CC0-1.0；各包已附 LICENSE、LICENSE-CC0.txt 与 ASSET_LICENSES.md。第三方及待确认部分保持各自许可状态。 |
| **P22 · 3D 国际象棋** | jza10086 / 本包贡献者 | [源码仓库](https://github.com/jza10086/3DChess)；`games/minigame/gp_3d_chess/` | 本项目原创代码为 MIT；原创媒体为 CC0-1.0；各包已附 LICENSE、LICENSE-CC0.txt 与 ASSET_LICENSES.md。第三方及待确认部分保持各自许可状态。 |
| **P23 · 蛇蛇大作战** | jza10086 / 本包贡献者 | [源码仓库](https://github.com/jza10086/MultiSnakeGame)；`games/minigame/gp_snake_battle/` | 本项目原创代码为 MIT；原创媒体为 CC0-1.0；各包已附 LICENSE、LICENSE-CC0.txt 与 ASSET_LICENSES.md。第三方及待确认部分保持各自许可状态。 |
| **P24 · 西部牛仔对决** | jza10086 / 本包贡献者 | [源码仓库](https://github.com/jza10086/WestShowdown)；`games/minigame/gp_west_duel/`；仅占位场景，playable=false，无独立外部美术／音效文件。 | 本项目原创代码为 MIT；原创媒体为 CC0-1.0；各包已附 LICENSE、LICENSE-CC0.txt 与 ASSET_LICENSES.md。第三方及待确认部分保持各自许可状态。 |
| **P25 · 合成大西八** | jza10086 / 本包贡献者 | [源码仓库](https://github.com/jza10086/MergeBigSsibal)；`games/minigame/gp_merge_ssibal/` | 本项目原创代码为 MIT；原创媒体为 CC0-1.0；各包已附 LICENSE、LICENSE-CC0.txt 与 ASSET_LICENSES.md。第三方及待确认部分保持各自许可状态。 |
| **P26 · 主工程、默认协议、空白模板、轮换主游戏与大富翁原型** | jza10086 / 本项目贡献者 | `core/`、`games/protocols/godot_party_default_protocol/`、`games/minigame/gp_blank/`、`games/maingame/`；原生场景／材质／程序音色也纳入 G 系列。 | 本项目原创代码为 MIT；原创媒体为 CC0-1.0；各包已附 LICENSE、LICENSE-CC0.txt 与 ASSET_LICENSES.md。第三方及待确认部分保持各自许可状态。 |

## 来源不明／来源链不完整，单独待核实登记

| 资产名称 | 作者 | 来源 | 许可协议 |
| --- | --- | --- | --- |
| **U01 · Bad Apple!! feat.nomico full.mid 及由其编排的谱面** | MIDI 编曲／制作者不明；用户提供 | 现有说明指向 `C:/Users/81010/Downloads/Bad Apple!! feat.nomico full.mid`；[输入与限制说明](../games/minigame/gp_rhythm_game/charts/bad_apple_full/SOURCE.md)；项目内保留转换／编排结果而非原 MIDI。 | 来源说明明确未标作者与再发行许可；不能登记为项目原创，需补原始发布页／授权。 |
| **U02 · Blackjack 53 张 PNG 中烘焙的点数字体** | 原始字体作者待确认；几何卡面为 GPT（代码生成） | [生成器](../games/minigame/gp_cards/tools/generate_blackjack_art.py) 可选 DejaVu Sans Bold、Arial Bold 或 --font 指定字体；未发现现存 PNG 对应的实际执行参数。 | 仅凭生成器默认候选无法确认实际字体与许可；补当时生成命令或字体来源。牌面本体仍已列 G08。 |
| **U03 · 森系角色与 Bot 头像使用的参考图／上一组头像** | 输入参考图原作者待确认；输出为 GPT（图像生成） | I01 已移除，其历史记录仅写用户提供参考图；I02 README 仅写上一组头像。本项目未附可核对的原始来源与输入授权记录。 | 输入来源／许可未确认；与输出的图像生成方式分开登记。 |
| **U04 · 5 张 ShellShock Live 截图的逐图原页及社区作者** | 官方截图权利方 kChamp Games；社区上传者未逐图对应 | L02 已有三个汇总来源 URL，但未逐一说明 `black_holes_gameplay.jpg`、`portal_gameplay.jpg` 等的原图页／作者。 | 未确认可再发行授权；仅本地参考。 |
| **U05 · 独立 libsndfile_x64.dll 的构建出处／版本** | libsndfile 项目；该二进制打包者不明 | `tmp/audio_tools/libsndfile_x64.dll`；S07 说明记录通过 libsndfile 转码，但此 DLL 目录没有来源／版本／许可旁档。 | 上游 LGPL 说明不足以证明该具体二进制的完整组件清单；本机工具，未作为游戏资产。 |

## 旧记录与实际文件的差异

- `doc/credits.md` 中的“原版 2D Godot 占位头像”是历史记录；当前头像包 ATTRIBUTION 已说明移除该占位，仍实际存在的 Godot 图标列 A20。
- 3d桌球 `ART_SOURCES.md` 仍记 `assets/audio/impactWood_light_001.ogg`、`impactSoft_medium_000.ogg` 和 `assets/fonts/NotoSansSC-Regular.otf`，本次当前包中未找到这些路径；因此不把它们计入在库资产。保留文档作为历史线索。
- 音游 8 个 Kenney 候选虽然已从选择目录移除，原始文件仍在，按 S02/S05/S06 登记；191 个 FluidR3 WAV 与 12 组 Virtuosity 采样分别记录。
- 竞拍大师旧 SVG 为 40 张，ImageGen PNG 为 100 张；没有把目录中的其他 Resource 文件混算为图片。
- `addons/millionaire_board_editor/` 当前为空目录，没有可登记的第三方包；`godot_party_tools` 为本项目工具，不是外部下载插件。
- 本工程已于 2026-11-09 从 Kenney 官方下载 Input Prompts 1.5A，导入 257 个键鼠和 99 个 Xbox SVG，许可证为 CC0 1.0；来源和原始许可证位于 core/ui/ambient_reveal/icons/kenney_input/。
- `doc/api/credits.md` 的旧 `ui/LICENSE.txt` 路径与当前布局不符；本表使用实际 `core/ui/ambient_reveal/fonts/SOURCE-HAN-SANS-LICENSE.txt`。
- 光标的 LighTech RE、LighTech Editor、Cursor Concept 3，及 BidKing、Mario Kart 等仅有视觉／玩法参考记录；未找到其原始资产文件，不将参考作品登记成已使用的下载包。实际重绘归 G 系列；ShellShock 截图和 Atomic Realm 文件因确实在库而单独登记。

## 核查依据与边界

本次逐目录列举资产文件，交叉阅读来源说明、许可证、生成提示词、生成脚本、内容 manifest 和 `.gitmodules`；读取字体 name 表确认实际字体，不仅按文件名推断。检查了本地 Atomic Realm 许可图片与阿瓦隆 ZIP 目录，在线补查 Wenrexa、MadFireOn、JC Sounds、Godot 标志、Atomic Realm、MERT、Basic Pitch、Demucs 和 Mapperatorinator 等作者页面。已检查所有表内本地证据链接存在、表格四列格式和主资产文件登记覆盖。

本次是资产来源与许可记录检查，没有运行游戏、试听或做画质验收，没有重导入资源，也没有确认某次导出包的最终打包内容。来源不明、许可未确认与历史文件情况均原样保留为待办，不以猜测补齐。

本次许可整理另核对了分类表名称排序、移动前后文件路径／数量／大小、忽略规则和各独立包许可旁档；不使用文件哈希。没有执行游戏运行或构建验收，也没有改写历史提交中的素材。

## 后续补充 小游戏 BGM 候选库

| 资产 | 作者 | 来源与位置 | 许可与范围 |
| --- | --- | --- | --- |
| 29 个 BGM 音频文件／版本及 1 个原始 ZIP | 逐曲作者见 [BGM 清单](bgm_candidates.md) | OpenGameArt 曲目发布页；`core/authoring/bgm_candidates/`；[逐曲记录](../core/authoring/bgm_candidates/catalog.json) | CC0 1.0，免费商用／修改／再分发；仅候选库，未接入小游戏。逐曲来源和许可旁档随库保留，不属于项目原创作品。 |

## 后续补充 输入提示图标

| 资产 | 作者 | 来源与位置 | 许可与范围 |
| --- | --- | --- | --- |
| Input Prompts 1.5A，257 个键鼠 SVG、99 个 Xbox SVG | Kenney | [官方页面](https://kenney.nl/assets/input-prompts)；core/ui/ambient_reveal/icons/kenney_input/ | CC0 1.0，原始 License.txt 随资源保留，属于第三方资产。 |
