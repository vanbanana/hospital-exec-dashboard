"""Failure boundaries of operations; no Docker or production database is required."""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('edss_ops', Path(__file__).resolve().parents[1] / 'scripts/ops.py')
ops = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ops)


class OperationsSafety(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.environment = patch.dict(os.environ, {'EDSS_BACKUP_DIR': str(self.directory), 'EDSS_BACKUP_KEEP': '2'})
        self.environment.start()
        self.addCleanup(self.environment.stop)

    def archive(self, path, completed='2020-01-01T00:00:00+00:00'):
        path.write_bytes(b'complete archive fixture')
        meta = {'format_version': 1, 'database': 'hospital_edss', 'file': path.name,
                'bytes': path.stat().st_size, 'sha256': ops.digest(path),
                'completed_at': completed, 'duration_s': 1}
        Path(str(path)+'.json').write_text(json.dumps(meta))
        return meta

    def test_backup_never_overwrites(self):
        target = self.directory / 'existing.dump'
        target.write_bytes(b'valuable backup')
        with patch.object(ops, 'source_database', return_value='hospital_edss'), patch.object(ops, 'execute') as execute:
            with self.assertRaises(ops.OpsError):
                ops.backup(target)
            execute.assert_not_called()
        self.assertEqual(target.read_bytes(), b'valuable backup')

    def test_tamper_rejected_before_container_operation(self):
        target = self.directory / 'tampered.dump'
        self.archive(target)
        target.write_bytes(b'changed archive fixture!')
        with patch.object(ops, 'execute') as execute:
            with self.assertRaises(ops.OpsError):
                ops.validate_archive(target)
            execute.assert_not_called()

    def test_source_database_cannot_be_restore_target(self):
        with patch.object(ops, 'validate_archive', return_value={'database': 'hospital_edss'}), \
                patch.object(ops, 'source_database', return_value='hospital_edss'), patch.object(ops, 'execute') as execute:
            with self.assertRaises(ops.OpsError):
                ops.restore(self.directory / 'archive.dump', 'hospital_edss')
            execute.assert_not_called()

    def test_retention_preserves_new_backup_even_when_filename_sorts_earlier(self):
        # Same-second random suffixes do not represent completion order.
        newest_old = self.directory / 'edss-20990101T000000Z-ffffffffffff.dump'
        older = self.directory / 'edss-20990101T000000Z-eeeeeeeeeeee.dump'
        self.archive(newest_old, '2020-02-01T00:00:00+00:00')
        self.archive(older, '2020-01-01T00:00:00+00:00')
        manual = self.directory / 'manual.dump'
        self.archive(manual)
        with patch.object(ops, 'backup', side_effect=self.archive), contextlib.redirect_stdout(io.StringIO()):
            ops.backup_cycle()
        state = ops.read_json(self.directory / 'backup-status.json')
        self.assertTrue((self.directory / state['backup']).is_file())
        self.assertTrue(newest_old.is_file())
        self.assertFalse(older.exists())
        self.assertTrue(manual.is_file())

    def test_failed_backup_retains_last_success_and_existing_archives(self):
        old = self.directory / 'previous.dump'
        self.archive(old)
        status = {'last_success': '2020-01-01T00:00:00+00:00', 'backup': old.name, 'bytes': old.stat().st_size}
        ops.atomic_json(self.directory / 'backup-status.json', status)
        with patch.object(ops, 'backup', side_effect=ops.OpsError('Disk pressure')), \
                contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaises(ops.OpsError):
                ops.backup_cycle()
        state = ops.read_json(self.directory / 'backup-status.json')
        self.assertEqual(state['state'], 'failed')
        self.assertEqual(state['last_success'], status['last_success'])
        self.assertTrue(old.is_file())

    def test_two_operations_cannot_hold_same_lock(self):
        with ops.exclusive_lock(self.directory, '.lock'):
            with self.assertRaises(ops.OpsError):
                with ops.exclusive_lock(self.directory, '.lock'):
                    self.fail('Both acquired exclusive lock')
        with ops.exclusive_lock(self.directory, '.lock'):
            pass

    def test_scheduler_continues_when_state_disk_is_full(self):
        class StopAfterTwoPolls:
            polls = 0
            def is_set(self): return self.polls >= 2
            def set(self): self.polls = 2
            def wait(self, _): self.polls += 1

        class CompletedProcess:
            returncode = 0
            def poll(self): return 0
            def wait(self, **_): return 0

        output = io.StringIO()
        with patch.object(ops.threading, 'Event', return_value=StopAfterTwoPolls()), \
                patch.object(ops.subprocess, 'Popen', return_value=CompletedProcess()) as spawn, \
                patch.object(ops, 'atomic_json', side_effect=OSError('No space')), \
                contextlib.redirect_stdout(output):
            ops.run()
        events = [json.loads(line) for line in output.getvalue().splitlines()]
        self.assertEqual(spawn.call_count, 3)
        self.assertEqual(sum(e['event'] == 'scheduled_job_complete' for e in events), 3)
        self.assertTrue(any(e['event'] == 'scheduler_state_unavailable' for e in events))
        self.assertEqual(events[-1]['event'], 'scheduler_stopped')
        with ops.exclusive_lock(self.directory, '.scheduler.lock'):
            pass


if __name__ == '__main__':
    unittest.main()
