# Inspect without touching a game installation

[Home](../README.md)

Use Python 3.11+ on any operating system. No packages are needed. From the repository root:

```console
python tools/archive.py verify
python tools/archive.py summary --json
```

Use `python3` if that is your Python command. Both commands are offline and read repository files only. They do not execute archived scripts, inspect games, install packages or write files. Redirect stdout yourself if you need a saved report.

The default root comes from the inspector's location, so another working directory also works. To inspect a separate copy, use `--root` with its path relative to your current directory:

```console
python tools/archive.py verify --root . --json
```

Exit codes: `0` for success, `1` for validation/data errors, `2` for invalid command arguments. JSON errors contain actionable messages. Missing, modified and uninventoried archival files are failures.

## Historical controllers

Cyberpunk `.ps1`/`.bat` files are preserved snapshots. Their config refers to an E: drive, exact EXE/DLL hashes and an external backup containing `baseline.json`. The backup and DLLs are not bundled. Changing a drive letter cannot establish compatibility or create a backup.

Controllers can write settings, move mod files during restoration and launch a game; some require desktop UI. Do not use them to validate this repository. CI parses syntax without executing scripts. No supported cross-machine installer is provided.

## Troubleshooting

| Error | Next step |
| --- | --- |
| Hash mismatch / missing evidence | Inspect your diff or use a clean checkout |
| Uninventoried archive file | Review its origin, then deliberately add an inventory entry |
| Invalid JSON | Fix new data; document any intended historical correction |
| Missing local target | Correct the Markdown path and letter case |
| Unsafe path | Use an ordinary in-repository file without symlink/path escape |

See [validation limits](validation.md).
