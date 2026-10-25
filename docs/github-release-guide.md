# What the DLSS Neural Rendering records actually support

[Home](../README.md) · [Evidence timeline](findings.md) · [Installation](../INSTALL.md)

This archive keeps both failure and later retest evidence. Cyberpunk 2077 records include removal after repeated crashes, later selected-profile retests, a 19.4-minute observation at 67% scale/one pass/native 2× FG, and a separate 100%/three-pass photo session. The photo session is not long gameplay validation. The Wuthering Waves 85% edit says `RuntimeTest: NOT_RUN`.

The historical benchmark averages, 116.3 FPS OFF and 99.47 FPS ON, belong to a different 3×-FG profile and are single observations. They do not support an FPS-gain or general compatibility claim. See the source-linked timeline before drawing conclusions.

## Inspect the archive

Download/extract the complete [release](https://github.com/yirancheng12-design/dlss-neural-rendering-lab/releases/latest), with Python 3.11+ installed. Double-click `Install.cmd`, then `Run.cmd`, or run `python tools/archive.py verify` and `python tools/archive.py summary`. No game, NVIDIA GPU, runtime DLL, administrator access or package download is needed for these offline tools.

Contribute a specific correction or a new dated record with exact versions, settings, runtime evidence, observation duration and unknowns. Keep unsuccessful trials. Do not upload game binaries, private saves, tokens or personal identifiers. This is an independent community archive, not an official installer.

中文：发布内容突出证据边界：失败和后续复测都保留，短时通过不等于长期稳定，配置已保存不等于实际运行通过。欢迎按时间与版本补充记录。
