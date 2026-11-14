# 内容包外部资源与作者导出规则

本文以霓虹节拍 `gp_rhythm_game` 为例。外置文件打包和路径解析已经可用；**自动扫描外部曲目、把它们加入正式选曲池、同步曲目版本及传输曲目尚未实现**，联机方案留待选择。本次只改导出过滤，不改变现有玩法的选曲行为。

## 已有的三种存放方式

| 存放方式 | 适用内容 | 加载方式 |
| --- | --- | --- |
| 普通包内资源 → PCK | 场景、脚本、Godot 导入的纹理与音频 | `load` / `ResourceLoader`，保留稳定的 `res://games/...` 路径 |
| 包内 `external/` → 安装目录中的原样文件 | JSON、运行时解码的音频、可直接读取的数据 | `api.get_external_path` + `FileAccess` / 运行时媒体加载器 |
| 本地个人资料 | 偏好、存档，以及未来支持的个人曲库 | 包的 `config/` 等个人存储；不进入正式载荷与联机内容同步 |

PCK 与外置文件可以在同一个内容包内共存。`export_ignore.txt` 只决定是否发布文件，不把被忽略资源自动变成外置文件，也不修复对它的引用。`external/` 是当前原样数据接口的约定；包安装目录名称和 PCK 名称仍可自由安排。

## 外置曲目目录和读取示例

作者源码可以这样组织（目录是示例，目前不会自动进入霓虹节拍曲目池）：

```text
games/minigame/gp_rhythm_game/
  manifest.json
  export_ignore.txt                # 可选，作者维护
  external/songs/my_song/
    chart.json
    music.ogg
```

正常导出后，`external/songs/my_song/` 保持原样，位于含 `content.pck.json` 的包安装文件夹下，与 PCK 并列。发布工具自动生成外置文件索引，作者无需逐项登记到 `manifest.json`。

在霓虹节拍自身脚本中，可使用已有读取器读取这个路径：

```gdscript
const Chart = preload("res://games/minigame/gp_rhythm_game/rhythm_chart.gd")

func read_external_chart(api: PartyAPI) -> Dictionary:
	var path: String = api.get_external_path("external/songs/my_song/chart.json")
	if path.is_empty():
		return {"ok": false, "error": "无法解析曲目目录"}
	return Chart.read_chart(path)
```

调用方必须处理返回的 `ok/error`；成功时 `audio` 是音频流，`notes/lanes/ends/subs` 是已解析的谱面。此示例只展示现有读取能力，不会注册歌曲、发起回合或替代联机准备流程。`get_external_path` 只解析当前活跃作用域所属包，不创建文件，也不能用来访问另一个资产包。

现有读取器支持 **OGG / WAV**；MP3 尚不属于霓虹节拍的谱面音源格式。外置音源与谱面在同一目录，`audio_file` 只填写文件名。最小谱面示例：

```json
{
  "format_version": 3,
  "key_count": 2,
  "note_type": "tap_hold",
  "title": "我的曲目",
  "artist": "作者",
  "difficulty": "Normal",
  "audio_file": "music.ogg",
  "notes_ms": [1000, 2000, 3000],
  "lanes": [0, 1, 0],
  "durations_ms": [0, 0, 1000],
  "subs_ms": [[], [], [3500]]
}
```

音源必须覆盖最后一个音符结束后至少 0.15 秒的判定窗口；同轨音符不能重叠。可参考现有原创样例 `games/minigame/gp_rhythm_game/charts/hold_test/`。正式玩法当前从场景的 `song` 和 `additional_songs` 读取 `RhythmSong` 资源，资源必须保存为包内 `.tres/.res`。仅复制上述目录，当前游戏不会出现新的可选歌曲。

正式 `external/` 文件会随发布更新；旧描述中退役的文件会被删除。玩家手工添加且未列入载荷的文件不会自动进入同步，但同名路径仍可能与以后发布的文件冲突。长期个人曲库宜独立于正式载荷；具体入口和位置随选定方案实现。移动端还需要文件选择与复制入口，不能假定玩家可直接操作应用私有目录。

## `export_ignore.txt`

在协议、主游戏、小游戏、形象包或资产包的根目录放置此文件。**有文件时完整使用作者规则；没有文件时使用 `core/content/default_export_ignore.txt`；空文件表示不使用默认排除项。** 子目录内的同名文件不作为嵌套规则解析，独立子包使用自己的根规则。

- 每行一个相对包根目录的模式；空行与以 `#` 开头的行忽略。
- 使用 `/`，大小写不敏感。`*` 匹配任意字符（包括 `/`），`?` 匹配一个字符；不是完整的 Git ignore 语法。
- `authoring/` 排除根目录下的 `authoring`；`*/authoring/` 排除嵌套同名目录。末尾 `/` 表示目录及其内容，匹配目录后不再向下收集。
- `*.blend` 匹配任意深度的 Blend 文件；被排除原文件的 `.import` 和 `.uid` 伴随文件也排除。
- 不支持 `!` 反选、绝对路径、`..` 和反斜杠；无效规则中止导出并报告规则文件与行号。
- 根 `export_ignore.txt` 总会保留，使暂存后的二次收集使用相同规则。排除必需的根 `manifest.json` 会直接失败。

默认文件排除各层 `authoring/`、`prototype/`、`tmp/`，隐藏项，以及名称含 `~`、以 `.tmp/.bak/.pending` 结尾的文件。作者若想保留其中某类，在自己的文件中只列需要排除的其他项。例如：

```text
# 完整替代默认规则；按本包实际内容维护
authoring/
*/authoring/
prototype/
*/prototype/
tmp/
*/tmp/
.*
*/.*
*~*
*.tmp
*.bak
*.pending
external/songs/private/
```

源码 ZIP、PCK 内容暂存、正式外置文件和各平台内容导出遵循同一规则。打包器保留必要归属边界：Git/引擎缓存、包根 `config/` 不发布，独立子包由自己导出，不接受链接路径。原样外置文件还必须满足可移植路径规则（不含隐藏路径段等）；其 `.import/.uid/.gdignore` 不作为运行数据发布。

`.gitignore` 管版本控制，`.gdignore` 管 Godot 导入，都不代替发布规则。允许某个含 `.gdignore` 的目录发布，不会使 Godot 自动导入其中资源。普通 PCK 资源保留导入参数并在隔离工程中导入；外置媒体通过文件 API 读取，不应再被场景作为普通导入资源引用。

如果要排除某首已被 `music_game.tscn` 的 `song` 引用的曲目，须先把引用改为要发布的曲目，否则会留下缺失资源。当前霓虹节拍默认场景指向本地 `charts/bad_apple/song.tres`；本轮未改此绑定，也未导出它。正式发布前应先处理该引用及素材发布范围，例如改用原创 `hold_test`。许可证与署名必须保留在发布范围内。

## 外部曲目联机方案（待选择）

| 方案 | 玩家与作者体验 | 所需改动与代价 |
| --- | --- | --- |
| 各端手动安装曲目文件夹 | 作者直接改 JSON/音频，不必重导出 PCK；玩家须提前安装同一曲目 | 扫描曲目元数据，定义稳定曲目 ID/版本/难度；房主同步选择，缺失或版本不符明确提示。修改文件不改版本无法被发现 |
| 房主临时传输原样曲目 | 客机无需提前安装；适合临时组局 | 新增按需文件传输、大小/路径检查、进度、取消、会话缓存、清理及准备屏障；首次等待受上传带宽和音频体积影响。不同于现有需重启的正式包安装 |
| 独立曲库资产包 | 一次安装多首，独立更新、分享和维护版本；适合正式曲库 | 复用资产包声明、PCK/外置数据导出和正式内容同步；当前安装更新需重启。需要约定曲库索引及霓虹节拍读取接口 |
| 正式资产包 + 个人曲目文件夹 | 正式联机内容方便分发，同时保留个人制作流程 | 需统一曲目身份、来源、重复 ID 拒绝规则和选曲列表；个人曲目仍要手动安装或另加临时传输 |

这些方案都可以只在进入霓虹节拍、打开选曲或实际选中歌曲时加载；菜单启动不需要扫描或解码所有曲目。曲库先读轻量索引，所选难度的谱面与音频再按需读取；不得为了显示歌名预载全部音频。现有随机池按完整候选 ID 集保存统计，外部曲目增删后也需要调整统计契约，不能仅追加一次目录扫描。

### 资产包可以怎样组织

```text
games/assets/rhythm_library_original/
  manifest.json                   # kind: assets，独立版本/名称/语言
  export_ignore.txt
  external/library.json           # 待定义的曲库索引，不是当前框架字段
  external/songs/hold_test/
    chart.json
    hold_test.wav
  LICENSES/
```

建议按曲库或发行批次建包，不强制每首一个包。PCK 保存包内资源，音频既可原样放在 `external/`，也可改用 Godot 原生音频资源放入 PCK；前者便于编辑，后者走原生导入加载。曲库资产包**不能依赖小游戏或其他资产包**，所以不能直接装入引用小游戏 `RhythmSong` 脚本的 `.tres`；可使用纯 JSON + 音频，由小游戏解释。

固定曲库可由小游戏声明依赖，复用已有依赖选择和版本同步；追加或移除曲库时需修改游戏依赖。若希望玩家安装任意曲库后自动可选，需要另行实现曲库发现、房间所选曲库的依赖集合，以及访问所选资产包外置目录的公开接口。当前 `get_external_path` 仅访问本包，不能把这些能力视为已有。

若以正式多人分发为主，优先考虑独立曲库资产包；若以个人制作、快速试谱为主，文件夹最省事。两者可组合，房主临时传输可后续独立增加；本轮不替用户决定或实现其中任何方案。
