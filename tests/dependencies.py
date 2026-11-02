"""No-network tests of preview isolation and reviewed lock validation."""
import json
import argparse
from pathlib import Path
import runpy
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/dependencies.py"


def git(root, *args):
    result = subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True)
    if result.returncode:
        raise AssertionError(result.stderr)
    return result.stdout.strip()


class DependenciesTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="agentmaster-deps-test-")
        self.base = Path(self.temp.name)
        self.root = self.base / "project"
        self.upstream = self.base / "upstream"
        for repo in (self.root, self.upstream):
            repo.mkdir()
            git(repo, "init", "-q")
            git(repo, "config", "user.name", "Fixture")
            git(repo, "config", "user.email", "fixture@example.invalid")
        skill = self.upstream / "skills/example"
        skill.mkdir(parents=True)
        (skill / "SKILL.md").write_text("---\nname: example\ndescription: Test\n---\nBody\n")
        git(self.upstream, "add", ".")
        git(self.upstream, "commit", "-qm", "fixture")
        (self.root / "skills/agent-master").mkdir(parents=True)
        (self.root / "skills/agent-master/SKILL.md").write_text("---\nname: agent-master\n---\n")
        (self.root / "repos.manifest").write_text(f"fixture|{self.upstream.as_posix()}|skills\n")
        (self.root / "profiles.manifest").write_text("minimal|fixture|*\n")
        git(self.root, "add", ".")
        git(self.root, "commit", "-qm", "fixture")
        git(self.root, "remote", "add", "origin", self.root.as_posix())
        self.cache = self.base / "cache"
        self.skills = self.base / "installed"
        self.cache.mkdir()
        self.skills.mkdir()
        self.lock = self.base / "reviewed.json"

    def tearDown(self):
        self.temp.cleanup()

    def run_cli(self, command, *extra):
        return subprocess.run([sys.executable, str(SCRIPT), command, *extra], capture_output=True, text=True)

    def config_args(self):
        return ["--manifest", str(self.root / "repos.manifest"), "--profiles", str(self.root / "profiles.manifest")]

    def preview(self):
        return self.run_cli("preview", *self.config_args(), "--cache-dir", str(self.cache),
                            "--skills-dir", str(self.skills), "--write-lock", str(self.lock))

    def test_preview_and_lock_are_isolated(self):
        result = self.preview()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("ADD fixture/example", result.stdout)
        self.assertEqual(list(self.cache.iterdir()), [])
        self.assertEqual(list(self.skills.iterdir()), [])
        lock = json.loads(self.lock.read_text())
        self.assertEqual(lock["repos"]["fixture"]["commit"], git(self.upstream, "rev-parse", "HEAD"))
        result = self.run_cli("validate", *self.config_args(), "--lock", str(self.lock))
        self.assertEqual(result.returncode, 0, result.stderr)
        result = self.run_cli("pin", "--lock", str(self.lock), "--repo", "missing")
        self.assertNotEqual(result.returncode, 0)

    def test_changed_manifest_is_rejected(self):
        self.assertEqual(self.preview().returncode, 0)
        with (self.root / "repos.manifest").open("a") as out:
            out.write(f"other|{self.upstream.as_posix()}|skills\n")
        result = self.run_cli("validate", *self.config_args(), "--lock", str(self.lock))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("differs", result.stderr)

    def test_collision_and_removed_skill_preview(self):
        (self.skills / "example").mkdir()
        (self.skills / "example/SKILL.md").write_text("personal skill")
        (self.cache / ".skill-owners").write_text("gone=fixture\n")
        before = (self.skills / "example/SKILL.md").read_bytes()
        result = self.preview()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("BLOCKED COLLISION example: unowned", result.stdout)
        self.assertIn("REMOVAL CANDIDATE fixture/gone", result.stdout)
        self.assertEqual((self.skills / "example/SKILL.md").read_bytes(), before)

    def test_invalid_sha_and_dirty_source_are_rejected(self):
        self.assertEqual(self.preview().returncode, 0)
        lock = json.loads(self.lock.read_text())
        lock["repos"]["fixture"]["commit"] = "main"
        self.lock.write_text(json.dumps(lock))
        result = self.run_cli("validate", *self.config_args(), "--lock", str(self.lock))
        self.assertNotEqual(result.returncode, 0)
        (self.root / "profiles.manifest").write_text("changed\n")
        result = self.preview()
        self.assertNotEqual(result.returncode, 0)

    def test_apply_passes_reviewed_pins_without_running_live_installer(self):
        self.assertEqual(self.preview().returncode, 0)
        module = runpy.run_path(str(SCRIPT))
        real_run = subprocess.run
        launches = []

        def capture(command, **kwargs):
            if command[0] == "git":
                return real_run(command, **kwargs)
            launches.append((command, kwargs))
            return subprocess.CompletedProcess(command, 0)

        args = argparse.Namespace(lock=str(self.lock), repo_root=str(self.root), mode="install")
        with mock.patch.object(Path, "home", return_value=self.base / "isolated-user"), mock.patch.object(subprocess, "run", side_effect=capture):
            module["apply"](args)
        self.assertEqual(len(launches), 1)
        command, kwargs = launches[0]
        self.assertIn("full", command)
        self.assertEqual(kwargs["env"]["AGENTMASTER_LOCKED"], "1")
        self.assertIn("fixture=" + git(self.upstream, "rev-parse", "HEAD"), kwargs["env"]["AGENTMASTER_LOCK_PINS"])
        self.assertEqual(list(self.skills.iterdir()), [])

    def test_untracked_skill_cannot_enter_reviewed_source(self):
        extra = self.root / "skills/untracked"
        extra.mkdir()
        (extra / "SKILL.md").write_text("unreviewed")
        result = self.preview()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("untracked", result.stderr)


if __name__ == "__main__":
    unittest.main()
