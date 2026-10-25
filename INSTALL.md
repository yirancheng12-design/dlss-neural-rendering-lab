# Installation and recovery / 安装与恢复

[English home](README.md) · [中文首页](README.zh-CN.md)

## Requirements checklist / 安装前提

| Requirement | What you need |
| --- | --- |
| Python | Python 3.11+ with the standard `venv` module; enable `py` or `python` on PATH. Python is not automatically installed |
| Files and permissions | Extract/clone the complete repository into a writable folder; run outside the ZIP. Administrator access is not required |
| Platform | `.cmd` entry points require Windows. Linux/macOS users run `python3 tools/install.py` for the core tools |
| Network and dependencies | After downloading the complete repository and installing Python, setup uses only the standard library; no pip packages or internet connection are required |
| Hardware and scope | No NVIDIA GPU, installed game or administrator access is required. This installs an analysis/archive environment, not a GPU driver, tuning profile or game Mod |

Successful setup ends with `Installation and verification passed` and `.setup-state.json` containing `ok: true`. If it fails, read `.setup.log`, fix the cause and rerun the installer; do not treat a created `.venv` alone as success.

| 项目 | 具体要求 |
| --- | --- |
| Python | 预先安装 Python 3.11+，包含标准 `venv` 模块，并让 `py` 或 `python` 命令可用；安装入口不会自动安装 Python |
| 文件与权限 | 完整解压或克隆到可写目录，在 ZIP 外运行；不要求管理员权限 |
| 系统 | 双击 `.cmd` 适用于 Windows；Linux/macOS 使用 `python3 tools/install.py` 安装核心工具 |
| 网络与依赖 | 完整下载仓库并安装 Python 后，初始化只使用标准库，无需 pip 依赖包或网络连接 |
| 硬件与用途 | 不要求 NVIDIA 显卡、已安装游戏或管理员权限；安装的是分析/归档运行环境，不是显卡驱动、调校方案或游戏 Mod |

只有显示 `Installation and verification passed` 且 `.setup-state.json` 中 `ok: true` 才表示安装检查通过。失败请查看 `.setup.log`，修复后重试；不能仅凭 `.venv` 已创建就认为成功。

After `Install.cmd` passes, use `Run.cmd` to read the recorded-data summary. Archive integrity checks do not establish current hardware health, actual game compatibility or rendering performance.

`Install.cmd` 检查通过后，双击 `Run.cmd` 查看已有记录摘要。归档完整性检查不等于本机硬件健康、游戏兼容性或渲染性能验证。

## Windows

1. Install Python 3.11+ from [python.org](https://www.python.org/downloads/), including the Python launcher or PATH entry. Python itself is a prerequisite, not bundled by this project.
2. Download/extract the complete repository or clone it. Do not run inside a ZIP. Keep this folder in a writable location; paths containing spaces are supported.
3. Double-click `Install.cmd`. It creates or reuses this checkout's `.venv`, runs the project's checks, and leaves the terminal open so the result is visible.
4. Use the project's launch command below after success.

No activation, administrator elevation or PowerShell execution-policy changes are needed. The wrapper tries `py -3`, then `python`, and requires Python 3.11+. For a custom interpreter, set `SETUP_PYTHON` to its executable path. Set `SETUP_NO_PAUSE=1` only for terminal/CI runs.

## What gets installed

Creates `.venv` without pip (the analysis tools use only the Python standard library), then runs archive verification and the summary. No package download or game/driver change is performed. Start with `Run.cmd`, or `.venv/bin/python tools/archive.py summary` on Linux/macOS. The installer never invokes scripts inside historical evidence packages.

## Terminal and other operating systems

From the repository root:

```console
python tools/install.py
python tools/install.py --dry-run
```

Use `python3` where needed. `--dry-run` prints the command plan as JSON without creating files or downloading anything. The real installer locates the checkout from its own file, so it also works when invoked from another directory. Core Python tools work on Windows/Linux/macOS; Windows desktop control is Windows-only.

## Results and retries

The installer saves stdout/stderr from verification/dependency steps to `.setup.log` and a machine-readable result to `.setup-state.json`. Both are local and ignored by Git. Exit 0 and `ok: true` mean every selected step passed; failure returns 1 and keeps `ok: false`. The last failed command/output is in the log. An old success is reset before a new attempt.

Rerunning reuses the environment and preserves project data. Guarded's package installation may refresh selected dependencies; archive projects require no pip/package download. A failed download can be retried after fixing the connection. No existing environment is deleted automatically. A folder named `.venv` that is not an environment, or a linked/redirected environment, is refused. If the checkout moved, create a fresh environment after preserving any data you put there; Python environments are not portable between locations.

Archive checks validate preserved bytes/references, not game compatibility or GPU stability. Guarded diagnostics validate setup, not model quality or arbitrary desktop actions. Test coverage includes repeat installation, failure-state handling, non-environment protection, paths with spaces, dry runs and Windows wrapper exit codes. CI additionally performs a real core installation in a fresh `.venv`; it does not download model weights or run game/controller scripts.

## 中文说明

首次需要 Python 3.11+，它不随仓库提供。解压完整仓库后双击 `Install.cmd`；程序会创建或复用仓库内的 `.venv` 并运行检查。失败请查看 `.setup.log`，修复后可重新运行，不会自动删除环境或用户数据。`.setup-state.json` 的 `ok` 只有在所有步骤通过后才为 `true`。模型、驱动、游戏 Mod 和账号凭据不会由核心安装自动配置。

Sources: [Python virtual environments](https://docs.python.org/3/library/venv.html), [installing packages in a virtual environment](https://packaging.python.org/en/latest/guides/installing-using-pip-and-virtual-environments/).
