# 验证与调试

使用系统 PATH 上的 godot 和正式主菜单/大厅。引擎升级由用户在编辑器中手动完成。

## 旧测试归档

2026-10-28，原 tests/ 中的全部现存文件移入 tmp/test/archive/2026-10-28/tests/。源码恢复点为 a224de0。tools/connectivity_client/check_font.gd 同样移入该归档的 tools/connectivity_client/，构建流程不再运行它。归档仅供历史查阅，不维护路径、不运行、不沿用历史 PASS。

测试专用脚本、场景、夹具、临时项目和生成的数据、日志、截图、缓存统一位于项目根目录 tmp/test/，按功能建子目录。tmp/ 保持 Git 忽略和 .gdignore；正式运行代码不得依赖测试目录。不要新建顶层 tests/。

## 定向验证

先明确当前变更需要回答的问题，再选最小验证。文档只做文本检查，局部行为只检查相关路径。涉及网络资料、配置生效或持久化时，验证成功路径与实际失败路径；不用重建旧的整套测试。

Godot CLI 验证前确认 godot --version。临时脚本可通过 --headless --path . --script res://tmp/test/<功能>/<脚本>.gd 运行，日志用 --log-file 指向同一测试目录。使用退出码和 ERROR / SCRIPT ERROR 判定结果；故意触发的负向用例必须与意外错误明确区分。

## 人工多人验收

使用编辑器多实例功能和正式主菜单/大厅，每个实例指定不同的 --party-profile=<slot>。这些开发资料位于 tmp/test/profiles/<slot>/，与原玩家资料隔离；旧 tmp/profiles/ 不自动迁移。

人工确认建房、直连、资料同步、准备、活动切换和断开。界面、输入、手感、音频设备与多人体验需要人工操作；本机 ENet 检查不能证明外网 IPv6、NAT、防火墙或 Steam 可用。
