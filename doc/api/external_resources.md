# 曲库资产包、按需加载与导出排除

霓虹节拍统一从独立资产包发现曲目。个人制作和正式分发使用同一种格式：编辑器读取源码，发布版读取 PCK。原生制谱工具保留在小游戏的 authoring/；曲库只保存音乐、曲目资源、谱面和相关许可。

## 目录规范

推荐按以下结构制作；这是作者约定，不是导出器或运行时的硬性目录检查：

```text
games/assets/my_rhythm_library/
  manifest.json
  export_ignore.txt
  music/
    my_song.ogg
  charts/
    my_song/
      song.tres
      easy.tres
      easy.json
      hard.tres
      hard.json
  authoring/
  LICENSES/
```

music/ 放音乐资源；charts/ 内按曲目建立子文件夹。song.tres 绑定一个音源和各难度谱面资源；谱面 .tres 再引用音符 JSON。扫描时以声明中的类型和曲目列表为准，不通过文件夹名称猜测曲目，也不递归加载全部 .tres。

## 声明

```json
{
  "name": "我的曲库",
  "kind": "assets",
  "package_version": "0.0.1",
  "framework_version": "0.0.1",
  "remark": "",
  "supported_languages": ["zh-CN"],
  "special_type": "rhythm_library",
  "songs": [
    "charts/my_song/song.tres"
  ]
}
```

special_type 是特殊类型标识；霓虹节拍识别 rhythm_library。songs 是非空、无重复的包内相对资源路径列表，支持 .tres/.res。ID 来自包目录，曲目 ID 为“包 ID/曲目资源路径”，曲目名称使用 Resource.resource_name。修改资源路径会改变曲目身份，因此建议改显示名称时保持路径稳定。

普通资产包无需添加这两项。曲库仍不能依赖小游戏或其他资产包，公共数据类型位于框架公开 API：

| 类型 | 文件 | 内容 |
| --- | --- | --- |
| PartyMusicSong | core/api/music/party_music_song.gd | music: AudioStream；charts: Array[PartyMusicChart] |
| PartyMusicChart | core/api/music/party_music_chart.gd | difficulty；chart_path；base_score（默认 1,000,000） |

这些类型仅保存数据，谱面校验、判定和计分由霓虹节拍解释。曲库不引用小游戏脚本。

## 编辑器制作流程

1. 创建资产包目录与 manifest.json，填写上述类型标识。
2. 把音乐放入 music/，等待 Godot 正常导入。当前谱面工具支持 OGG / WAV。
3. 在 charts/ 下建立曲目子目录。制作或复制谱面 JSON，用霓虹节拍 authoring/chart_editor.tscn 编辑；工具会扫描标记为 rhythm_library 的资产包的 music/ 与 charts/。
4. 为每个难度创建 PartyMusicChart，保存为 .tres；设置 difficulty、chart_path（通过 Inspector 选择 res:// JSON 路径）和 base_score。
5. 创建 PartyMusicSong，填写 resource_name，绑定 music，并把各难度 .tres 拖入 charts。只有绑定的谱面会参与正式玩法。
6. 将曲目资源路径加入声明 songs。原生工具保存/另存谱面 JSON 后，新增难度和新曲目的 .tres 绑定及声明仍由作者在 Inspector 中维护，不自动改写。
7. 编辑器重新运行即可发现新曲库，不需要构建 PCK。正式分发时，在导出工具中同时选择小游戏与要发布的曲库；曲库可独立导出、更新。导出小游戏不会隐式发布电脑上的全部个人曲库。

已有谱面保存时保留文件路径，修改工程显示名不会破坏 .tres 绑定；另存为生成新的 JSON。原生工具导入音频时放入当前打开谱面所属包的 music/，新谱面保存到该包 charts/<音源文件名>/。这只是工具默认放置方式，作者可自行组织并维护引用。

JSON 音符格式仍为 format_version 3，保留 notes_ms、lanes、durations_ms、subs_ms 等字段。audio_file 可填写 res:// 音源路径，使制作工具能访问 music/ 中的文件，也支持谱面同目录的音源文件名。正式玩法以 PartyMusicSong.music 为准，不会按 JSON 字段改换音源；difficulty 与 base_score 以绑定的 PartyMusicChart 为准。

示例：games/assets/gp_rhythm_original/charts/hold_test/song.tres。本地 Bad Apple 短版和完整版位于 games/assets/gp_rhythm_bad_apple/，整包被主仓库 .gitignore 排除，仍可在 Godot 中发现；本轮未发布。旧本地原始曲目和编辑恢复记录保留，小游戏的 export_ignore.txt 排除原 charts/，避免重复打入小游戏 PCK。

## 发现、加载和联机

主菜单只读取声明/发布描述，不读取曲目资源和音频。霓虹节拍的轻量 definition.gd 声明 asset_types: ["rhythm_library"]；房主把该小游戏加入房间池时，框架发现匹配类型的可用资产包，将它们作为本局随机曲目池的候选依赖。

- 加入房间阶段仍只要求协议、主游戏和形象依赖。
- 开始前将房主的候选曲库纳入现有版本/build_id 检查与内容同步。随机池可能选中任何候选曲库，所以此阶段要求整个候选集合；这不是只传输当轮单首曲目的机制。
- 客机只使用房主房间依赖集合中的曲库；额外安装的本地曲库不增加候选歌曲。
- 创建霓虹节拍回合后，读取候选 songs 路径列表，房主按最少游玩次数抽取稳定曲目 ID 并广播。
- 各端仅对选中曲目调用 await api.load_asset_async(ref)，首次使用时挂载所属 PCK，并后台加载该曲目的音源和绑定谱面资源。随后读取选中歌曲各难度的谱面，建立难度选项和计分上限，完成技术准备。
- 安装/更新正式包仍需重启；编辑器内部联机不自动构建或传输，需自行同步源码。没有整包 Hash 校验。
- 曲库增删会保留已有曲目统计，新曲目从零开始；退役曲目的统计保留但不参与抽取。损坏的统计文件明确报错。

公共接口：

```gdscript
# 仅返回当前房间候选集合的元数据，不加载资源。
var libraries: Array[Dictionary] = api.get_asset_libraries("rhythm_library")
# ref 来自选中曲库的声明：package_id + resource_path。
var resource: Resource = await api.load_asset_async(ref)
```

API 关闭后异步结果不会交还旧回合。单包 PCK 挂载不等于一次性把包内所有音频解码到内存；仅所选曲目及其原生资源依赖被加载。

## export_ignore.txt：Git ignore 语法

每个包根目录可放一个文件。存在时完整替代 core/content/default_export_ignore.txt；空文件表示没有作者排除规则；不存在时采用默认文件。不读取嵌套 export_ignore.txt、仓库 .gitignore 或用户全局 Git 配置。

- 空行、# 注释；支持反斜杠转义、转义后的尾空格。普通尾空格忽略。
- * 和 ? 不跨目录；** 支持跨多层目录；支持 [abc]、[!abc]、范围及常见 POSIX 字符组。
- 无路径分隔符的名称匹配任意层；开头 / 锚定包根；末尾 / 只匹配目录。
- ! 重新包含，最后一条匹配规则优先。已排除父目录后，子文件反选不能恢复它，须先恢复父目录。
- 匹配固定区分大小写，各平台一致。非法正则字符范围等无效模式明确报告文件与行号。

```gitignore
authoring/
tmp/
/drafts/
*.blend
!/examples/editable.blend
.*
*.tmp
*.bak
*.pending
```

默认排除 authoring/、prototype/、tmp/、隐藏项、名称含 ~ 以及 .tmp/.bak/.pending。源码 ZIP、PCK 暂存和外置数据遵循同一规则。引擎/Git 缓存、包根 config/ 和独立子包仍有各自技术归属；链接路径不可发布。根 export_ignore.txt 保留以确保多阶段规则相同，不能排除必需 manifest.json。原文件被排除时其 .import/.uid 也排除，重新包含原文件后伴随文件按自身规则处理。

.gitignore 只控制 Git；export_ignore.txt 控制打包；.gdignore 只控制 Godot 导入。排除文件不会修复引用，不能把仍被场景或曲目资源引用的音频/谱面排除。发布所需许可证和署名应保留。

Git 模式参考：[官方说明](https://git-scm.com/docs/gitignore/)。本实现采用包根单文件与固定大小写规则，不提供 Git 的多来源配置和索引语义。

## 其他原样外置资源

普通 Godot 音乐资源可直接进入曲库 PCK，无需另建个人文件夹机制。其他内容如确需原样数据，仍可使用包内 external/；api.get_external_path("external/maps/map.json") 返回当前作用域所属包的源码/安装绝对路径，配合 FileAccess 或运行时媒体加载器读取。

外置文件按导出规则自动登记，正式更新会替换及删除退役载荷；个人 config/ 不参与。get_external_path 不能代替跨资产包资源接口，也不会自动创建文件。PCK 名称与安装文件夹布局仍可自由安排，安装识别依赖 content.pck.json。
