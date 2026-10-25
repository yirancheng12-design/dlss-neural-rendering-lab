# Contributing

Open an evidence issue or small PR, in English or Chinese. Describe an observation and link evidence; a UI control's existence does not mean its setting was tested.

Record exact game/GPU/driver/mod versions and file hashes, resolution, NR scale/passes/cache/strength, FG multiplier, scene, duration, fresh runtime evidence and capture method. Retain failed runs. For performance, include repeated runs and frame-time measurement methods; keep `UNKNOWN` for unmeasured FPS, 1% low and latency. Explain rollback and remaining uncertainty. Remove personal details from new submissions.

Preserve historical files unless a correction is necessary and explained. Add dated evidence and extend curated references/inventory deliberately. Never regenerate hashes merely to conceal unexpected changes. Entries identify their source commit.

Before submitting:

```console
python tools/archive.py verify
python tools/archive.py summary --json
python -m unittest discover -s tests -v
```

CI parses PowerShell without invoking it. Green CI validates the archive/tooling, not gameplay. Do not upload proprietary DLLs, game executables, credentials, saves or unrelated data. Original code/docs contributions use MIT; third-party rights remain with their owners.
