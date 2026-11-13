# 本地化

主菜单右上角手动选择简体中文或 English，首次默认 `zh_Hans`，不读取系统语言，不提供 auto。选择保存到框架 `core/config/settings.json` 的 `localization.locale` 后刷新主菜单；保存失败保留原语言和配置。偏好只属于本机，不进入房间规则、网络消息或兼容性判断。

## 每包语言文件

内容语言固定从 `i18n/<locale>.po` 自动发现，无 manifest 语言声明。当前界面提供 `zh_Hans` 和 `en`，回退语言为 `zh_Hans`；PO 的 Language 头必须与文件名一致。框架自身仍用 `core/i18n/localization.json`。资源按首次使用加载，不做启动全包翻译预审。

每个包根据原始本机偏好独立选择，不继承框架、协议或主游戏已回退的语言。缺少英文条目时使用本包中文条目。缺失资源、无效声明、错误资源类型、语言不符、命名占位符不一致和缺少中文条目明确失败；缺少中文不是正常回退。

## 作者接口

PartyAPI.i18n 随作用域注入，PartyRoomAPI.i18n 默认绑定主游戏：

```gdscript
var text: String = api.i18n.text(&"round.time", {"seconds": seconds})
var shared_text: String = api.i18n.text(&"briefing.ready", {}, api.protocol_id)
var language: String = api.i18n.effective_locale()
```

`text(key: StringName, parameters: Dictionary = {}, package_id: String = "") -> String` 默认查当前包，显式包 ID 可查协议或 core。键按包隔离；先翻译完整句子，再用 `{name}` 格式化。新增动态文案优先使用稳定键。未知键报告错误并显示 `[MISSING 包/键]`。

目前只在主菜单提供切换入口，游戏入场时读取当前语言，不实现游戏内语言设置页。重建主游戏或小游戏界面时使用最新偏好。网络应传递业务事件/消息码及参数，在客户端展示时翻译，不广播已翻译文案。

## 清单与设置

清单 name 和玩法界面文案及 Schema 的 title、description、placeholder、suffix、disabled_reason、labels 直接作为 PO 消息键。可以用中文源文作为键，也可以填写稳定键并在中文 PO 提供译文。首次显示时加载所用语言并缓存；实际读取时报告缺失翻译。

翻译不修改 default、values、enabled_when、字段 ID、动作名或保存值。选择控件用 labels 提供可译标签，多选开关用 items.labels，与 items.values 一一对应。继承的协议设置仍使用协议语言。昵称、聊天、预设名称及用户输入的文本偏好原样显示。

游戏脚本/场景文本通过 api.i18n 赋给控件；仅增加 PO 文件不会翻译尚未接入的硬编码文本。已翻译控件不应再依赖全局自动翻译。

## 初版范围与发布

英语覆盖主菜单首页、加入页面、创建/直连/资料/退出弹窗、键鼠提示，以及 空白小游戏（gp_blank）的名称、简介、设置样例及结束按钮提示。系统设置、连接诊断详情、协议、大游戏、其他小游戏及框架设置控件通用操作提示仍使用中文。用户填写的中文内容不自动翻译。

PO 与所属包一起发布。现有源码 ZIP/PCK 导出递归收集包内资源，无中央翻译索引；新增语言时提供对应 PO 并接入显示位置。

本次回归脚本、场景、日志、截图、PCK 及配置夹具均位于忽略目录 tmp/test/localization/，不进入生产依赖。自动检查覆盖独立回退、同名键隔离、错误声明、占位符、配置值不变、选择持久化、实际菜单/小游戏/表单和导出资源收集。人工多人及干净导出安装验收另外进行。
