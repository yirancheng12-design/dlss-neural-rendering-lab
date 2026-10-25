"""Offline, read-only inspection of the archived evidence (Python 3.11+)."""

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import sys
from urllib.parse import unquote, urlsplit

DEFAULT_ROOT = Path(__file__).resolve().parents[1]
SKIP = {'.git', '.venv', '__pycache__'}


def local_path(root, value):
    """Require exact-case, ordinary repository paths without link traversal."""
    if not isinstance(value, str) or not value or '\\' in value or ':' in value:
        raise ValueError(f'Unsafe path: {value!r}')
    path = PurePosixPath(value)
    if path.is_absolute() or any(p in {'', '.', '..'} for p in value.split('/')):
        raise ValueError(f'Unsafe path: {value!r}')
    target = root
    for part in path.parts:
        if not target.is_dir() or part not in {p.name for p in target.iterdir()}:
            raise ValueError(f'Missing local target (check letter case): {value}')
        target = target / part
        if target.is_symlink():
            raise ValueError(f'Unsafe path (symlink): {value}')
    if not target.resolve().is_relative_to(root.resolve()):
        raise ValueError(f'Unsafe path: {value}')
    return target


def read_json(root, name):
    return json.loads(local_path(root, name).read_text(encoding='utf-8-sig'))


def repo_files(root):
    for directory, dirs, names in os.walk(root, followlinks=False):
        dirs[:] = sorted(d for d in dirs if d not in SKIP)
        for name in sorted(names):
            yield (Path(directory) / name).relative_to(root).as_posix()
        for name in dirs[:]:
            candidate = Path(directory) / name
            if candidate.is_symlink() or not candidate.resolve().is_relative_to(root.resolve()):
                dirs.remove(name)
                yield candidate.relative_to(root).as_posix()


def cases(root):
    data = read_json(root, 'evidence/cases.json')
    if not isinstance(data, dict) or data.get('schema_version') != 1:
        raise ValueError('Invalid cases schema_version')
    entries = data.get('cases')
    if not isinstance(entries, list) or not entries:
        raise ValueError('Cases must be a nonempty list')
    result, ids = [], set()
    for entry in entries:
        if not isinstance(entry, dict) or not isinstance(entry.get('id'), str):
            raise ValueError('Each case needs an id')
        if entry['id'] in ids:
            raise ValueError(f'Duplicate case id: {entry["id"]}')
        ids.add(entry['id'])
        fields = entry.get('fields')
        if not isinstance(fields, list) or not fields or not all(isinstance(f, str) for f in fields):
            raise ValueError(f'Invalid fields: {entry["id"]}')
        if not isinstance(entry.get('limitations'), str) or not entry['limitations'].strip():
            raise ValueError(f'Missing limitations: {entry["id"]}')
        source = entry.get('source')
        record = read_json(root, source)
        if not isinstance(record, dict) or any(f not in record for f in fields):
            raise ValueError(f'Missing recorded field: {source}')
        result.append({'id': entry['id'], 'source': source,
                       'recorded': {f: record[f] for f in fields},
                       'limitations': entry['limitations']})
    return result


def markdown_targets(root, name):
    text = local_path(root, name).read_text(encoding='utf-8-sig')
    text = re.sub(r'```.*?```', '', text, flags=re.S)
    for match in re.finditer(r'!?\[[^\]\n]*\]\(([^\s)]+)\)', text):
        raw = match.group(1)
        parsed = urlsplit(raw)
        if parsed.scheme or parsed.netloc or not parsed.path:
            continue
        relative = unquote(parsed.path)
        if relative.startswith('/') or '\\' in relative or ':' in relative:
            raise ValueError(f'Unsafe path in {name}: {raw}')
        # Markdown allows ../ for a parent within the repository.
        combined = os.path.normpath(str(PurePosixPath(name).parent / relative)).replace('\\', '/')
        yield local_path(root, combined)


def verify(root):
    errors, counts = [], {'archived_files': 0, 'json_files': 0, 'markdown_files': 0}
    try:
        manifest = read_json(root, 'evidence/manifest.json')
        if not isinstance(manifest, dict) or manifest.get('schema_version') != 1:
            raise ValueError('Invalid manifest schema_version')
        entries, roots = manifest.get('files'), manifest.get('archive_roots')
        if not isinstance(entries, list) or not entries or not isinstance(roots, list) or not roots:
            raise ValueError('Manifest requires nonempty files and archive_roots')
        for name in roots:
            if not local_path(root, name).is_dir():
                raise ValueError(f'Archive root is not a directory: {name}')
        expected = set()
        for entry in entries:
            if not isinstance(entry, dict) or not isinstance(entry.get('path'), str):
                raise ValueError('Invalid manifest file entry')
            name, digest = entry['path'], entry.get('sha256')
            if name in expected:
                raise ValueError(f'Duplicate manifest entry: {name}')
            expected.add(name)
            if not re.fullmatch('[0-9a-f]{64}', str(digest)):
                raise ValueError(f'Invalid SHA-256: {name}')
            if type(entry.get('size')) is not int or entry['size'] < 0:
                raise ValueError(f'Invalid size: {name}')
            if not re.fullmatch('[0-9a-f]{40}', str(entry.get('source_commit'))):
                raise ValueError(f'Invalid source commit: {name}')
            try:
                target = local_path(root, name)
                data = target.read_bytes()
                if len(data) != entry['size'] or hashlib.sha256(data).hexdigest() != digest:
                    errors.append(f'Hash/size mismatch: {name}')
                counts['archived_files'] += 1
            except (OSError, ValueError) as exc:
                errors.append(str(exc))
        actual = {name for name in repo_files(root)
                  if any(name.startswith(r + '/') for r in roots) and not name.endswith('/README.md')}
        for name in sorted(actual - expected):
            errors.append(f'Uninventoried archive file: {name}')
    except (OSError, ValueError, TypeError) as exc:
        errors.append(f'Manifest: {exc}')
    for name in repo_files(root):
        try:
            target = local_path(root, name)
            if target.suffix == '.json':
                read_json(root, name)
                counts['json_files'] += 1
            elif target.suffix == '.md':
                list(markdown_targets(root, name))
                counts['markdown_files'] += 1
        except (OSError, ValueError) as exc:
            errors.append(f'{name}: {exc}')
    try:
        counts['cases'] = len(cases(root))
    except (OSError, ValueError, TypeError) as exc:
        errors.append(f'Cases: {exc}')
    return {'ok': not errors, 'counts': counts, 'errors': errors}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['verify', 'summary'])
    parser.add_argument('--root', type=Path, default=DEFAULT_ROOT)
    parser.add_argument('--json', action='store_true', dest='as_json')
    args = parser.parse_args(argv)
    root = args.root.resolve()
    try:
        if not root.is_dir():
            raise ValueError(f'Repository root is missing: {args.root}')
        output = verify(root) if args.command == 'verify' else {'ok': True, 'cases': cases(root)}
    except (OSError, ValueError, TypeError) as exc:
        output = {'ok': False, 'errors': [str(exc)]}
    if args.as_json:
        print(json.dumps(output, ensure_ascii=True, indent=2))
    elif args.command == 'verify' or not output['ok']:
        print('PASS' if output['ok'] else 'FAIL')
        for key, value in output.get('counts', {}).items():
            print(f'  {key}: {value}')
        for error in output.get('errors', []):
            print(f'  {error}')
    else:
        for entry in output['cases']:
            print(f'{entry["id"]} ({entry["source"]})')
            print(json.dumps(entry['recorded'], ensure_ascii=True))
            print(f'Limit: {entry["limitations"]}\n')
    return 0 if output['ok'] else 1


if __name__ == '__main__':
    sys.exit(main())
