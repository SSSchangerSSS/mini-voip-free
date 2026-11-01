#!/usr/bin/env python3
"""Exercise daemon FD inheritance with real flock, without Android/root."""
import fcntl
import os
from pathlib import Path
import re
import signal
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]

class LauncherLockTests(unittest.TestCase):
    def probe(self, launcher, bounded, fixed):
        source = (ROOT / launcher).read_text()
        functions = '\n'.join(re.findall(r'^(?:adb|timeout)\(\) \{.*\}$', source, re.M)) if fixed else ''
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            adb = root / 'adb'
            adb.write_text('#!/bin/bash\nsleep 30 &\necho $! > "$QA_CHILD_PID"\n')
            adb.chmod(0o700)
            env = dict(os.environ, PATH=f'{root}:{os.environ["PATH"]}',
                       QA_CHILD_PID=str(root / 'pid'), QA_LOCK=str(root / 'lock'))
            command = 'timeout 5 adb' if bounded else 'adb'
            script = functions + '\nexec 9> "$QA_LOCK"\nflock 9\n' + command
            child = None
            try:
                subprocess.run(['bash', '-c', script], env=env, check=True,
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
                child = int((root / 'pid').read_text())
                with (root / 'lock').open('w') as lock:
                    held = False
                    try:
                        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    except BlockingIOError:
                        held = True
                self.assertEqual(held, not fixed,
                                 'daemon must not retain startup lock after frontend exit')
            finally:
                if child:
                    try:
                        os.kill(child, signal.SIGTERM)
                    except ProcessLookupError:
                        pass

    def check_launcher(self, launcher, bounded):
        self.probe(launcher, bounded, fixed=False)  # Reproduce the original leak.
        self.probe(launcher, bounded, fixed=True)

    def test_sdk_direct_adb(self):
        self.check_launcher('scripts/qa/launch-emulator.sh', False)

    def test_sdk_bounded_adb(self):
        self.check_launcher('scripts/qa/launch-emulator.sh', True)

    def test_native_direct_adb(self):
        self.check_launcher('scripts/qa/start-android15-container.sh', False)

    def test_native_bounded_adb(self):
        self.check_launcher('scripts/qa/start-android15-container.sh', True)

if __name__ == '__main__':
    unittest.main()
