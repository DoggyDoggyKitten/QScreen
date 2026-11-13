"""Failure-path checks for release notarization, without credentials or network."""
import importlib.util
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location('release', Path(__file__).resolve().parents[1] / 'scripts/notarize-release.py')
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class NotarizationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.folder = Path(self.temporary.name)
        self.payload = self.folder / 'payload.zip'
        self.payload.write_bytes(b'signed payload')
        self.options = SimpleNamespace(profile='test', keychain='/unused/keychain', timeout=1)
        self.calls = []

    def runner(self, status='Accepted', issues=None, log_status=None):
        def run(*args, **kwargs):
            self.calls.append(args)
            command = args[2]
            if command == 'submit':
                return json.dumps({'id': 'submission-id'})
            if command == 'info':
                return json.dumps({'status': status})
            if command == 'log':
                args[-1].write_text(json.dumps({'status': log_status or status, 'issues': issues}))
                return None
            self.fail(f'Unexpected command: {args}')
        return run

    def test_accepted_submission_can_resume_without_reupload(self):
        with patch.object(release, 'run', side_effect=self.runner()):
            for _ in range(2):
                self.assertEqual(release.notarize(self.payload, 'app', self.folder, self.options), 'submission-id')
        self.assertEqual(sum(call[2] == 'submit' for call in self.calls), 1)

    def test_changed_payload_cannot_reuse_submission(self):
        with patch.object(release, 'run', side_effect=self.runner()):
            release.notarize(self.payload, 'app', self.folder, self.options)
            self.payload.write_bytes(b'different payload')
            with self.assertRaisesRegex(RuntimeError, 'payload changed'):
                release.notarize(self.payload, 'app', self.folder, self.options)

    def test_rejected_submission_stops_and_preserves_log(self):
        with patch.object(release, 'run', side_effect=self.runner(status='Invalid')):
            with self.assertRaisesRegex(RuntimeError, 'notarization failed'):
                release.notarize(self.payload, 'app', self.folder, self.options)
        self.assertTrue((self.folder / 'app.notary-log.json').exists())

    def test_accepted_response_requires_accepted_log(self):
        with patch.object(release, 'run', side_effect=self.runner(log_status='Invalid')):
            with self.assertRaisesRegex(RuntimeError, 'notarization failed'):
                release.notarize(self.payload, 'app', self.folder, self.options)

    def test_log_error_cannot_pass(self):
        issues = [{'severity': 'error', 'message': 'Bad signature', 'path': 'QScreen.app'}]
        with patch.object(release, 'run', side_effect=self.runner(issues=issues)):
            with self.assertRaisesRegex(RuntimeError, 'log contains an error'):
                release.notarize(self.payload, 'app', self.folder, self.options)

    def test_timeout_retains_submission_for_resume(self):
        with patch.object(release, 'run', side_effect=self.runner(status='In Progress')), \
             patch.object(release.time, 'monotonic', side_effect=[0, 2]):
            with self.assertRaises(SystemExit) as context:
                release.notarize(self.payload, 'app', self.folder, self.options)
        self.assertEqual(context.exception.code, 75)
        self.assertEqual(json.loads((self.folder / 'app.submission.json').read_text())['id'], 'submission-id')


if __name__ == '__main__':
    unittest.main()
