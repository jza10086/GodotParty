# 原版协议公共字体

- `font_sans`：NotoSansSC-UI.otf，复制自框架当前使用的黑体，许可证 NOTO-SANS-LICENSE.txt。
- `font_serif`：SourceHanSerifSC-Regular.otf，Adobe 思源宋体简体中文 Regular，版本 2.003，许可证 SOURCE-HAN-SERIF-LICENSE.txt。
- 官方来源：https://github.com/adobe-fonts/source-han-serif/tree/2.003R

协议资料界面默认使用 font_sans；大小游戏可以独立选择，不更改框架字体。框架仍保留自身字体文件。字体随协议包发布，无需安装到操作系统。

```gdscript
var font: Font = api.load_asset({
    "package_id": "godot_party_default_protocol",
    "resource_key": "font_serif" # 黑体改为 font_sans
}) as Font
if font == null:
    api.fail(&"FONT_MISSING", "协议字体缺失")
    return
var local_theme: Theme = Theme.new()
local_theme.default_font = font
local_theme.default_font_size = 24
view_root.theme = local_theme
```

已有 Theme 时先 `duplicate()` 再设置 default_font，避免修改其他界面共享的主题。对单个 Label 可使用 `add_theme_font_override("font", font)`。
