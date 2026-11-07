# 游戏音频组件

`audio/game_audio.tscn` 是原版协议提供的可复用节点，资源键为 `game_audio`。每个游戏在自己的场景中实例化它；无需 Autoload，也不修改框架菜单音频、玩家语音聊天或 Master 总线。空白模板右上角的“音频测试”是完整示例，3D 展台和 2D 航道均可使用。测试面板和固定播放器池均保存在 `.tscn` 中。

## 接入场景与生命周期

1. 在游戏场景实例化 `game_audio.tscn`，命名 `GameAudio`，启用唯一名称。
2. 在 Inspector 新建 `PartyAudioCue` 资源并指定 AudioStream；把音效资源通过 `@export` 暴露给游戏脚本。示例资源位于空白模板的 `examples/audio/`。
3. 正式游戏 `party_setup` 在入树前调用 `prepare_scope()`，通过以下方法暴露挂点。协议设置 runtime 会在视图入树后绑定该作用域的音频总线，因此正式播放从游戏开始阶段发起。

```gdscript
@export var background_music: PartyAudioCue
@export var hit_sound: PartyAudioCue
@export var announcement: PartyAudioCue

func party_setup(api: PartyAPI, request: Dictionary) -> void:
    # 此处保留游戏已有的 API、请求和信号初始化。
    $GameAudio.prepare_scope()

func godot_party_audio_target() -> PartyGameAudio:
    return $GameAudio

func party_start() -> void:
    %GameAudio.play_music(background_music, 0.6)

func party_stop(reason: StringName) -> void:
    %GameAudio.close_scope()
```

F6 未调用 `prepare_scope()` 时，组件自动建立临时预览总线，退出时移除。不写用户配置。正式运行由协议 runtime 拥有总线，离开作用域先停止声音，再移除对应总线。主游戏与前台小游戏的总线彼此独立；主游戏隐藏视图时按自身玩法决定暂停或停止。

## 播放、切换与等待

```gdscript
%GameAudio.play_music(background_music)           # 相同资源不重新开始
%GameAudio.play_music(other_music, 0.8)           # 双播放器交叉淡化，快速切换以最新请求为准
%GameAudio.play_music(background_music, 0.5, true) # 强制重播
%GameAudio.pause_music()
%GameAudio.resume_music()
%GameAudio.stop_music(0.5)

var impact: PartyAudioHandle = %GameAudio.play_sfx(hit_sound)
var wind: PartyAudioHandle = %GameAudio.play_ambience(wind_loop)
wind.stop(0.4)                                   # 只停止这次播放
%GameAudio.play_ui(button_sound)                 # 游戏音频暂停时仍可播放

%GameAudio.play_dialogue(announcement)           # REPLACE：中断当前配音并清空旧队列
%GameAudio.play_dialogue(next_line, PartyGameAudio.DialogueMode.QUEUE)
%GameAudio.play_dialogue(hint_line, PartyGameAudio.DialogueMode.IGNORE_IF_BUSY)
%GameAudio.skip_dialogue()                       # 跳过当前，继续队列
%GameAudio.clear_dialogue_queue()                # 只清空等待项
%GameAudio.stop_dialogue()                       # 停止当前并清空队列

%GameAudio.set_gameplay_paused(true)             # 暂停音乐、音效、配音、环境；UI 继续
%GameAudio.set_gameplay_paused(false)
%GameAudio.stop_category(PartyGameAudio.Category.AMBIENCE, 0.4)
%GameAudio.stop_all()

var reason: PartyAudioHandle.EndReason = await impact.wait_end()
if reason == PartyAudioHandle.EndReason.COMPLETED:
    print("自然播完")
```

`wait_end()` 在已经结束时也立即返回，避免错过信号。自然完成、手动停止、替换、抢占、丢弃、作用域关闭和无效资源都有独立结束原因；无效资源或作用域未就绪还会通过 `handle.error` 返回错误。停止旧句柄不会影响已复用的播放器。`ended`、`playback_ended` 和 `subtitle_changed` 延迟通知，允许完成回调发起下一次播放而不重入播放器池的修改过程。

配音期间背景音乐默认降低 8 dB；进入和退出时间、衰减量和队列容量可在组件 Inspector 调整。配音通过 `subtitle_changed(key)` 输出 `PartyAudioCue.subtitle_key`，游戏使用自己的 `api.i18n.text(key)` 更新已有字幕 Label；空键表示清除。配音播放的是预录素材，与 `api.voice` 的玩家语音聊天无关。

## 音效资源与并发规则

`PartyAudioCue` 包含 stream、volume_db、pitch_scale、loop_mode、priority、max_instances、cooldown、subtitle_key。loop_mode 可保留资源设置、强制循环或禁止循环；循环覆盖支持 WAV、Ogg Vorbis 和 MP3，并复制流后修改，不污染其他引用。

场景预置 2 个音乐播放器、1 个配音播放器、12 个普通音效播放器、4 个环境播放器、4 个 UI 播放器。可在各容器下编辑池容量。普通音效、环境和 UI 按资源对象统计并发与冷却；同一音效应复用同一 `.tres`。达到资源上限或冷却期时直接丢弃；池满时仅允许抢占优先级不高于新请求的声音，先低优先级、再最旧。不会排队补播迟到的音效。配音队列默认最多等待 8 条。

固定空间声源继续在场景中使用原生 `AudioStreamPlayer2D/3D`：

```gdscript
%GameAudio.route_spatial(%EngineSound, PartyGameAudio.Category.SFX)
%EngineSound.play()
```

绑定后使用该作用域的分类总线，参与暂停、分类停止和退出清理；其空间衰减、循环和播放由原生节点控制，不进入二维音效池，不返回播放句柄。不要让空间声源先 autoplay，再绑定总线。

## 音量与示例素材

`audio.master/music/sfx/dialogue/ambience/ui` 是协议的本地可覆盖配置，范围 0–1，默认 1；0 会静音该总线。游戏分类音量发送到作用域 GameRoot，再发送 Master；不会改变全局 Master。正式面板调整后点“应用本游戏音量”才调用现有 `PartyConfig.set_common_override()` 保存，“恢复继承”调用 `clear_common_override()`。F6 的滑块通过 `set_preview_volume(channel, linear)` 即时试听，退出不保存。游戏音量偏好不通过网络同步。

空白模板包含两段 4 秒循环旋律、短提示、撞击、环境循环以及两段中文预录配音。旋律和音效为本次程序合成的示例；配音由本机 Windows Microsoft Huihui 朗读本项目示例文本生成，不需要运行时 TTS、联网或额外插件。英文界面提供英文字幕，示例音轨仍为中文。替换 `PartyAudioCue.stream` 即可使用正式素材。
