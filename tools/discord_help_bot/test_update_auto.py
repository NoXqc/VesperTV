"""Exercise the deployment transaction with temporary files, never SSH or Docker."""
import base64
import contextlib
import io
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import importlib.util

spec = importlib.util.spec_from_file_location('update_auto', Path(__file__).with_name('update-auto.py'))
update_auto = importlib.util.module_from_spec(spec)
spec.loader.exec_module(update_auto)
REMOTE = update_auto.REMOTE


class UpdateTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.names = ['vespertv-discord-auto', 'vespertv-discord-help']
        self.old = {'guide.json': b'old guide', 'search.mjs': b'old search'}
        self.new = {
            'guide.json': json.dumps([{'id': str(i), 'title': 'tip', 'controls': 'OK',
                                      'answer': 'answer', 'url': 'https://vespertv.app'}
                                     for i in range(66)]).encode(),
            'search.mjs': b'export const search = true;',
        }
        self.paths = {}
        self.remote = REMOTE
        for name in self.names:
            directory = self.root / name
            directory.mkdir()
            self.paths[name] = directory
            for filename, content in self.old.items():
                (directory / filename).write_bytes(content)
            self.remote = self.remote.replace('/opt/' + name, directory.as_posix())
        self.real_run = subprocess.run
        self.calls = []
        self.fail_check = False
        self.ready = True

    def fake_run(self, args, **kwargs):
        self.calls.append(args)
        output = ''
        if args[0] == 'cp':
            shutil.copy2(args[-2], args[-1])
        elif args[:2] == ('docker', 'inspect'):
            output = 'running'
        elif args[:2] == ('docker', 'exec'):
            if self.fail_check:
                self.fail_check = False
                raise subprocess.CalledProcessError(1, args)
            directory = self.paths[args[2]].as_posix() + '/'
            command = [str(arg).replace('/app/', directory) for arg in args[3:]]
            self.real_run(command, check=True, text=True, capture_output=True)
        elif args[:2] == ('docker', 'logs'):
            if self.ready:
                output = ('VesperTV automatic help connected; one channel enabled.\n'
                          'Help channel access verified.\n')
        elif args[:2] != ('docker', 'restart'):
            raise AssertionError('Unexpected command: ' + str(args))
        return subprocess.CompletedProcess(args, 0, output, '')

    def execute(self, include_slash=True, files=None):
        payload = {'files': files or {name: base64.b64encode(data).decode()
                                     for name, data in self.new.items()},
                   'include_slash': include_slash}
        with patch('sys.stdin', io.StringIO(json.dumps(payload))), \
                patch('subprocess.run', side_effect=self.fake_run), \
                patch('time.sleep'), \
                patch('urllib.request.urlopen') as health, \
                contextlib.redirect_stdout(io.StringIO()) as output:
            health.return_value.__enter__.return_value = io.StringIO('{"ok":true,"answers":66}')
            exec(compile(self.remote, 'remote', 'exec'), {})
        return output.getvalue()

    def assert_files(self, name, expected):
        for filename, content in expected.items():
            self.assertEqual((self.paths[name] / filename).read_bytes(), content)

    def test_updates_only_auto_by_default_and_preserves_original_backup(self):
        self.assertIn('66 answers', self.execute(include_slash=False))
        self.assert_files(self.names[0], self.new)
        self.assert_files(self.names[1], self.old)
        for filename, original in self.old.items():
            backups = list(self.paths[self.names[0]].glob(filename + '.bak.*'))
            self.assertEqual(len(backups), 1)
            self.assertEqual(backups[0].read_bytes(), original)

    def test_updates_both_modes_with_explicit_flag(self):
        self.execute()
        for name in self.names:
            self.assert_files(name, self.new)
        restarts = [call[-1] for call in self.calls if call[:2] == ('docker', 'restart')]
        self.assertEqual(restarts, self.names)

    def test_syntax_failure_restores_both_modes(self):
        self.fail_check = True
        with self.assertRaisesRegex(SystemExit, 'prior bot files restored'):
            self.execute()
        for name in self.names:
            self.assert_files(name, self.old)

    def test_missing_readiness_restores_prior_files(self):
        self.ready = False
        with self.assertRaisesRegex(SystemExit, 'prior bot files restored'):
            self.execute()
        for name in self.names:
            self.assert_files(name, self.old)

    def test_actual_guide_allows_tips_with_instructions_in_controls_only(self):
        self.new['guide.json'] = Path(__file__).with_name('guide.json').read_bytes()
        guide = json.loads(self.new['guide.json'])
        self.assertTrue(any(entry['answer'] == '' for entry in guide))
        self.assertIn('66 answers', self.execute())
        for name in self.names:
            self.assert_files(name, self.new)

    def test_unexpected_file_is_rejected_before_commands_or_writes(self):
        with self.assertRaisesRegex(SystemExit, 'Unexpected files'):
            self.execute(files={'unexpected.txt': base64.b64encode(b'x').decode()})
        self.assertEqual(self.calls, [])
        for name in self.names:
            self.assert_files(name, self.old)


if __name__ == '__main__':
    unittest.main()
