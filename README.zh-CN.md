# DLSS 神经渲染：社区实验与证据归档

[English](README.md) · [英文结论与原始证据](docs/findings.md) · [只读工具](docs/usage.md)

这里保存《赛博朋克 2077》和《鸣潮》的社区 Neural Rendering 实验：配置、崩溃分析、截图及有限时间的运行观察。**NR 指神经渲染，不是 NVIDIA Reflex。**

这是历史归档，附带离线 Python 检查工具。Windows 控制器依赖原作者电脑的路径、备份及文件哈希，不能直接当通用安装器。仓库不提供游戏二进制或 NR DLL。

## 结论和限制

| 记录 | 观察 | 限制 |
| --- | --- | --- |
| 赛博朋克 2077，10 月 16 日 | 反复崩溃后撤下，后来针对特定配置做了 10 分钟复测 | 不能忽略失败记录，不保证长期稳定 |
| 10 月 17 日控制器 v2 | 67% 精度、单层、原生 2 倍插帧，19.4 分钟无新增崩溃报告 | 该次未测平均 FPS / 1% low，不能推广到其他配置 |
| 100% / 三层截图 | 拍照模式对比及日志观察记录 | 不同渲染帧、缩放 JPEG，不能代替逐像素评测或长期实玩 |
| 鸣潮 85% 配置 | 配置变更及备份记录 | `RuntimeTest: NOT_RUN`，不能声称实机通过 |

按时间阅读[实验结论](docs/findings.md)，每项均链接原始记录。DLSS 5 的官方定义见 [NVIDIA 说明](https://www.nvidia.com/en-us/geforce/news/dlss-5-3d-guided-neural-rendering/)。社区实验不构成官方游戏支持声明。

## 一分钟检查

Python 3.11+，在仓库根目录执行：

```console
python tools/archive.py verify
python tools/archive.py summary
python -m unittest discover -s tests -v
```

不需要依赖包、游戏、GPU 或管理员权限，不联网、不修改游戏。

- `verify`：检查原始清单、SHA-256、JSON、证据引用及本地 Markdown 目标；失败退出码为 1。
- `summary`：从 JSON 读取结果，保留 `UNKNOWN` / `NOT_RUN`。
- 两条命令均支持 `--json`。

归档检查通过不代表兼容性、画质或长期稳定性验证通过。

## 导航

- [赛博朋克 2077](01_Cyberpunk2077/README.md)：报告、运行记录、截图、历史控制器。
- [鸣潮](02_WutheringWaves/README.md)：只读审查、安装和配置变更。
- [目录对应表](docs/archive-map.md)、[工具说明](docs/usage.md)、[验证方式](docs/validation.md)、[来源与隐私](docs/provenance.md)。

英文首页展示原始对比截图；中文原始报告保持原样。报告中的 Windows 路径是历史现场信息，不能照抄为安装路径。部分记录仍有用户路径等标识，不能宣称已完全匿名化。

欢迎按[贡献指南](CONTRIBUTING.md)提交可复现证据。[MIT](LICENSE)适用于原创代码及文档；第三方素材保留各自权利。
