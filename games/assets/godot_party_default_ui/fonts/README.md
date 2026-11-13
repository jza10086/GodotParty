# 原版 UI 公共字体

字体由 `godot_party_default_ui` 资产包提供。使用者声明精确包版本依赖，通过资源路径直接引用，无需资源键或系统字体安装。

- `NotoSansSC-UI.otf`：Noto Sans 简体中文 UI 字体，保留 NOTO-SANS-LICENSE.txt。
- `SourceHanSerifSC-Regular.otf`：思源宋体简体中文 Regular 2.003，保留 SOURCE-HAN-SERIF-LICENSE.txt。
- 来源：https://github.com/adobe-fonts/source-han-serif/tree/2.003R

```gdscript
var font: Font = preload("res://games/assets/godot_party_default_ui/fonts/SourceHanSerifSC-Regular.otf")
```

修改共享 Theme 前先复制；框架字体仍由框架自行提供。
