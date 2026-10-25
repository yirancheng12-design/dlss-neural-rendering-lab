# Validation and its limits

[Home](../README.md) · [Usage](usage.md)

Run from the repository root with Python 3.11+:

```console
python tools/archive.py verify --json
python tools/archive.py summary --json
python -m unittest discover -s tests -v
```

For this revision, `verify` should report `ok: true`, 188 archived files, 120 JSON files and six curated cases. Markdown counts can grow as documentation is added. A nonzero exit or any error requires investigation; do not overwrite the baseline to make it pass.

The regression suite exercises corrupt/missing/uninventoried evidence, invalid JSON, exact-case links, traversal and symlink rejection, missing recorded fields, required limitations, preservation of `UNKNOWN`/`NOT_RUN`, CLI exit codes, no file writes, and execution from another working directory. Symlink tests may be skipped on Windows if the runner cannot create them.

GitHub Actions runs on Windows and Linux with Python 3.11 and 3.14. Windows additionally parses the five historical PowerShell files with the Windows PowerShell parser, without invoking them. CI has read-only repository permissions.

Checks cover file bytes, JSON syntax, curated fields and the targets of ordinary inline Markdown links/images. They do not check remote URLs, Markdown fragment anchors, reference-style links, image content, historical external backup paths or third-party downloads. Inventory hashes are not signed attestations. The summary selects existing records rather than validating their factual truth.

No game, mod, driver or graphics configuration is changed. No fresh gameplay, FPS, latency or long-term stability result is claimed. A green badge means the archive/tooling checks passed.
