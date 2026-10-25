import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
SCRIPT = REPO / 'tools/archive.py'
spec = importlib.util.spec_from_file_location('archive', SCRIPT)
archive = importlib.util.module_from_spec(spec)
spec.loader.exec_module(archive)


class ArchiveTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.write('archive/run.json', {'FPS': 'UNKNOWN', 'RuntimeTest': 'NOT_RUN'})
        raw = (self.root / 'archive/run.json').read_bytes()
        self.write('evidence/manifest.json', {
            'schema_version': 1, 'archive_roots': ['archive'],
            'files': [{'path': 'archive/run.json', 'size': len(raw),
                       'sha256': hashlib.sha256(raw).hexdigest(), 'source_commit': 'a' * 40}]})
        self.write('evidence/cases.json', {'schema_version': 1, 'cases': [
            {'id': 'trial', 'source': 'archive/run.json', 'fields': ['FPS', 'RuntimeTest'],
             'limitations': 'No runtime test was performed.'}]})
        (self.root / 'README.md').write_text('[record](archive/run.json)\n', encoding='utf-8')

    def write(self, name, value):
        target = self.root / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(value), encoding='utf-8')

    def errors(self):
        report = archive.verify(self.root)
        self.assertFalse(report['ok'])
        return '\n'.join(report['errors'])

    def test_clean_fixture(self):
        self.assertTrue(archive.verify(self.root)['ok'])

    def test_modified_evidence_fails(self):
        self.write('archive/run.json', {'FPS': 120, 'RuntimeTest': 'PASS'})
        self.assertIn('Hash/size mismatch', self.errors())

    def test_missing_evidence_fails(self):
        (self.root / 'archive/run.json').unlink()
        self.assertIn('Missing local target', self.errors())

    def test_uninventoried_file_fails(self):
        (self.root / 'archive/new.txt').write_text('unreviewed')
        self.assertIn('Uninventoried archive file', self.errors())

    def test_invalid_json_fails(self):
        (self.root / 'archive/run.json').write_text('{broken')
        self.assertIn('archive/run.json', self.errors())

    def test_wrong_case_link_fails_even_on_windows(self):
        (self.root / 'README.md').write_text('[record](archive/Run.json)')
        self.assertIn('check letter case', self.errors())

    def test_missing_markdown_target_fails(self):
        (self.root / 'README.md').write_text('![image](missing.jpg)')
        self.assertIn('missing.jpg', self.errors())

    def test_parent_link_inside_repo_passes(self):
        (self.root / 'archive/README.md').write_text('[home](../README.md)')
        self.assertTrue(archive.verify(self.root)['ok'])

    def test_external_and_fragment_links_do_not_fetch(self):
        (self.root / 'README.md').write_text('[web](https://invalid.invalid/x) [section](#x)')
        self.assertTrue(archive.verify(self.root)['ok'])

    def test_unsafe_manifest_paths_fail(self):
        for path in ['../outside.json', '/outside', 'C:/outside', 'archive\\run.json']:
            with self.subTest(path=path):
                manifest = json.loads((self.root / 'evidence/manifest.json').read_text())
                manifest['files'][0]['path'] = path
                self.write('evidence/manifest.json', manifest)
                self.assertIn('Unsafe path', self.errors())

    def test_markdown_path_escape_fails(self):
        (self.root / 'README.md').write_text('[escape](%2e%2e/outside.md)')
        self.assertIn('Unsafe path', self.errors())

    def test_symlink_is_not_followed(self):
        try:
            (self.root / 'archive/link.json').symlink_to(self.root / 'archive/run.json')
        except OSError:
            self.skipTest('Platform does not allow symlink creation')
        self.assertIn('Unsafe path', self.errors())

    def test_missing_recorded_field_fails(self):
        data = json.loads((self.root / 'evidence/cases.json').read_text())
        data['cases'][0]['fields'].append('InventedFPS')
        self.write('evidence/cases.json', data)
        self.assertIn('Missing recorded field', self.errors())

    def test_limitations_required(self):
        data = json.loads((self.root / 'evidence/cases.json').read_text())
        data['cases'][0]['limitations'] = ''
        self.write('evidence/cases.json', data)
        self.assertIn('Missing limitations', self.errors())

    def test_unknowns_not_converted_to_success(self):
        result = archive.cases(self.root)[0]
        self.assertEqual(result['recorded'], {'FPS': 'UNKNOWN', 'RuntimeTest': 'NOT_RUN'})

    def test_malformed_manifest_reports_error(self):
        self.write('evidence/manifest.json', {'schema_version': 1, 'files': {}})
        self.assertIn('Manifest:', self.errors())

    def test_duplicate_manifest_entry_fails(self):
        manifest = json.loads((self.root / 'evidence/manifest.json').read_text())
        manifest['files'] *= 2
        self.write('evidence/manifest.json', manifest)
        self.assertIn('Duplicate manifest entry', self.errors())

    def test_cli_exit_codes_and_no_writes(self):
        before = {str(p.relative_to(self.root)): p.read_bytes() for p in self.root.rglob('*') if p.is_file()}
        for command in ['verify', 'summary']:
            run = subprocess.run([sys.executable, str(SCRIPT), command, '--root', '.', '--json'],
                                 cwd=self.root, capture_output=True, text=True)
            self.assertEqual(run.returncode, 0, run.stderr + run.stdout)
            self.assertTrue(json.loads(run.stdout)['ok'])
        after = {str(p.relative_to(self.root)): p.read_bytes() for p in self.root.rglob('*') if p.is_file()}
        self.assertEqual(before, after)
        (self.root / 'archive/run.json').unlink()
        run = subprocess.run([sys.executable, str(SCRIPT), 'verify', '--root', '.', '--json'],
                             cwd=self.root, capture_output=True, text=True)
        self.assertEqual(run.returncode, 1)
        self.assertFalse(json.loads(run.stdout)['ok'])

    def test_default_root_independent_of_cwd(self):
        run = subprocess.run([sys.executable, str(SCRIPT), 'summary', '--json'],
                             cwd=self.root, capture_output=True, text=True)
        self.assertEqual(run.returncode, 0, run.stderr)
        data = json.loads(run.stdout)
        trial = next(e for e in data['cases'] if e['id'] == 'wuthering-waves-85-percent')
        self.assertEqual(trial['recorded']['RuntimeTest'], 'NOT_RUN')


if __name__ == '__main__':
    unittest.main()
