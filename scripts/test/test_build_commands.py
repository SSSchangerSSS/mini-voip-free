"""Build wrapper regression tests; Flutter is a stub, no APK is validated here."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class BuildCommandsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for file in ("smi", "scripts/lib/common.sh", "scripts/build/build-android.sh",
                     "scripts/build/build-ios.sh", "scripts/deploy/server-init.sh",
                     "scripts/deploy/extension.sh"):
            target = self.root / file
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / file, target)
        (self.root / "apps/mobile/android").mkdir(parents=True)
        bindir = self.root / "tools"
        bindir.mkdir()
        flutter = bindir / "flutter"
        flutter.write_text('''#!/bin/bash
printf '%s\\n' "$PWD" "$@" >> "$BUILD_TEST_TRACE"
if [ "${BUILD_TEST_PUB_OK:-}" = 1 ] && [ "$1" = pub ]; then exit 0; fi
exit 7
''')
        flutter.chmod(0o755)
        self.trace = self.root / "trace"
        self.env = dict(os.environ, PATH=f"{bindir}:{os.environ['PATH']}",
                        BUILD_TEST_TRACE=str(self.trace))
        self.env.pop("SMI_SERVER_HOST", None)
        self.env.pop("SMI_SERVER_PORT", None)

    def run_build(self, *args):
        return subprocess.run(["bash", str(self.root / "smi"), "build", *args],
                              cwd="/tmp", env=self.env, text=True, capture_output=True)

    def test_android_resolves_repo_and_propagates_pub_failure(self):
        result = self.run_build("android", "--release", "--server-host", "192.168.1.244")
        self.assertEqual(result.returncode, 7, result.stderr)
        self.assertEqual(self.trace.read_text().splitlines(),
                         [str(self.root / "apps/mobile"), "pub", "get"])
        self.assertNotIn("PASS APK", result.stdout)

    def test_server_config_reaches_flutter_and_build_failure_is_preserved(self):
        self.env["BUILD_TEST_PUB_OK"] = "1"
        result = self.run_build("android", "--release", "--server-host", "192.168.1.244",
                                "--server-port", "8443")
        self.assertEqual(result.returncode, 7, result.stderr)
        args = self.trace.read_text().splitlines()
        self.assertIn("--dart-define=SMI_SERVER_HOST=192.168.1.244", args)
        self.assertIn("--dart-define=SMI_SERVER_PORT=8443", args)
        self.assertNotIn("PASS APK", result.stdout)

    def test_invalid_host_and_ports_fail_before_flutter(self):
        for args in [("--server-host", "https://192.168.1.244"),
                     ("--server-port", "0"), ("--server-port", "65536"),
                     ("--server-port", "text"), ("--server-host",)]:
            with self.subTest(args=args):
                result = self.run_build("android", *args)
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertFalse(self.trace.exists())

    def test_server_dispatch_consumes_subcommand_before_config(self):
        result = subprocess.run(["bash", str(self.root / "smi"), "server", "init",
                                 "--config", "/missing-site-config"],
                                env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn("config file not found", result.stderr)
        self.assertNotIn("unknown argument init", result.stderr)

    def test_server_init_cannot_report_success_when_caddy_validation_fails(self):
        for file in (ROOT / "infra/asterisk/conf").glob("*.conf"):
            target = self.root / "infra/asterisk/conf" / file.name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(file, target)
        deploy = self.root / "deploy"
        (deploy / "secrets").mkdir(parents=True)
        (deploy / "secrets/ami").write_text("fixture-only-not-a-real-credential")
        config = deploy / "site.env"
        config.write_text("SMI_DOMAIN=192.168.1.151\n")
        for name, body in [("docker", "exit 7"), ("ss", "exit 0")]:
            stub = self.root / "tools" / name
            stub.write_text("#!/bin/bash\n" + body + "\n")
            stub.chmod(0o755)
        result = subprocess.run(["bash", str(self.root / "smi"), "server", "init",
                                 "--config", str(config)],
                                env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 3, result.stderr)
        self.assertIn("BLOCKED Caddy validation failed", result.stderr)
        self.assertNotIn("PASS server init complete", result.stdout)

    def test_single_level_commands_keep_their_first_option(self):
        result = subprocess.run(["bash", str(self.root / "smi"), "backup"],
                                env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 2)
        # A harmless stub verifies forwarding without running a real backup.
        (self.root / "scripts/deploy/backup.sh").write_text('printf "%s\\n" "$@"')
        result = subprocess.run(["bash", str(self.root / "smi"), "backup",
                                 "--output", "/tmp/test-backup"],
                                env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.splitlines(), ["--output", "/tmp/test-backup"])

    def test_deployed_extension_cli_receives_private_stdin_without_temp_copy(self):
        deploy = self.root / "deploy"
        deploy.mkdir()
        (deploy / "site.env").write_text("SMI_DOMAIN=192.168.1.151\n")
        credential = self.root / "credential"
        credential.write_text("fixture-credential-only\n")
        credential.chmod(0o600)
        docker = self.root / "tools/docker"
        docker.write_text('''#!/bin/bash
if [ "$1" = image ]; then exit 0; fi
printf '%s\\n' "$@" > "$BUILD_TEST_TRACE"
IFS= read -r value
[ "$value" = fixture-credential-only ]
''')
        docker.chmod(0o755)
        result = subprocess.run(["bash", str(self.root / "smi"), "extension", "add", "101",
                                 "--credential-file", str(credential)],
                                env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        args = self.trace.read_text().splitlines()
        self.assertIn("-i", args)
        self.assertIn("/dev/stdin", args)
        self.assertNotIn("fixture-credential-only", self.trace.read_text())
        self.assertEqual(credential.stat().st_mode & 0o777, 0o600)

    @unittest.skipIf(os.uname().sysname == "Darwin", "Linux preflight test")
    def test_ios_reports_platform_blocker(self):
        result = self.run_build("ios", "--release")
        self.assertEqual(result.returncode, 3, result.stderr)
        self.assertIn("BLOCKED iOS build requires macOS/Xcode", result.stderr)


if __name__ == "__main__":
    unittest.main()
