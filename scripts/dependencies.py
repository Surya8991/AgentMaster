#!/usr/bin/env python3
"""Review upstream revisions in temporary clones; validate reproducible installs.

Python 3 + Git are required only for these opt-in dependency controls.
Preview never changes caches, installed skills, ownership or cooldown state.
"""
import argparse
import fnmatch
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import tempfile


def git(*args, cwd=None):
    result = subprocess.run(["git", *map(str, args)], cwd=cwd, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode:
        raise ValueError(f"git {args[0]} failed: {result.stderr.strip()}")
    return result.stdout.strip()


def lines(path):
    if not path or not Path(path).exists():
        return []
    return [line.strip() for line in Path(path).read_text(encoding="utf-8-sig").splitlines()
            if line.strip() and not line.lstrip().startswith("#")]


def config(args):
    if not Path(args.manifest).is_file():
        raise ValueError("Manifest does not exist")
    rows = []
    urls = {}
    for line in lines(args.manifest) + lines(args.repos_local):
        fields = [part.strip() for part in line.split("|")]
        if len(fields) not in (3, 4):
            raise ValueError(f"Invalid manifest entry: {line}")
        name, url, source = fields[:3]
        if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", name) or name in (".", "..", "agent-master"):
            raise ValueError(f"Invalid dependency name: {name}")
        if not url or url.startswith("-"):
            raise ValueError(f"Invalid URL for {name}")
        if PurePosixPath(source).is_absolute() or ".." in PurePosixPath(source).parts or "\\" in source or ":" in source:
            raise ValueError(f"Unsafe source path for {name}")
        if name in urls and urls[name] != url:
            raise ValueError(f"Conflicting URLs for {name}")
        urls[name] = url
        rows.append([name, url, source, fields[3] if len(fields) == 4 else ""])
    profiles = []
    for line in lines(args.profiles) + lines(args.profiles_local):
        parts = [part.strip() for part in line.split("|")]
        if len(parts) != 3:
            raise ValueError(f"Invalid profile entry: {line}")
        if parts[0] == args.profile:
            profiles.append(parts)
    if args.profile != "full" and not profiles:
        raise ValueError(f"Unknown profile: {args.profile}")
    collisions = lines(args.collisions)
    seen = set()
    for line in collisions:
        if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*=[A-Za-z0-9][A-Za-z0-9._-]*", line):
            raise ValueError(f"Invalid collision override: {line}")
        skill = line.split("=", 1)[0]
        if skill in seen:
            raise ValueError(f"Duplicate collision override: {skill}")
        seen.add(skill)
    return {"manifest": rows, "profile": args.profile, "rules": profiles,
            "collisions": collisions}


def selected(cfg, repo, skill=None):
    if cfg["profile"] == "full" or (repo == "agent-master" and skill == "agent-master"):
        return True
    return any(r == repo and (skill is None or fnmatch.fnmatchcase(skill, pattern))
               for _, r, pattern in cfg["rules"])


def load_lock(path):
    lock = json.loads(Path(path).read_text(encoding="utf-8"))
    if lock.get("version") != 1 or not isinstance(lock.get("repos"), dict):
        raise ValueError("Unsupported dependency lock")
    for name, entry in lock["repos"].items():
        if not isinstance(entry, dict) or not re.fullmatch(r"[0-9a-f]{40}", entry.get("commit", "")):
            raise ValueError(f"Invalid locked commit for {name}")
    return lock


def validate(args):
    lock = load_lock(args.lock)
    cfg = config(args)
    if lock.get("config") != cfg:
        raise ValueError("Lock differs from manifest/profile configuration; generate and review a new lock")
    expected = {name: url for name, url, _, _ in cfg["manifest"] if selected(cfg, name)}
    if set(lock["repos"]) != set(expected) | {"agent-master"}:
        raise ValueError("Lock must cover exactly the selected repositories plus agent-master")
    for name, url in expected.items():
        if lock["repos"][name].get("url") != url:
            raise ValueError(f"Locked URL mismatch for {name}")
    print("PASS: dependency lock matches configuration")


def tree_hash(path):
    if not path.is_dir():
        return None
    digest = hashlib.sha256()
    for item in sorted(path.rglob("*")):
        if item.is_symlink():
            digest.update((item.relative_to(path).as_posix() + "->" + str(item.readlink())).encode())
        elif item.is_file():
            digest.update(item.relative_to(path).as_posix().encode())
            digest.update(item.read_bytes())
    return digest.hexdigest()


def source_dirty(root):
    return (git("diff", "--name-only", "HEAD", cwd=root)
            or git("ls-files", "--others", "--", "skills", "scripts", cwd=root))


def preview(args):
    cache = Path(args.cache_dir).expanduser()
    args.repos_local = args.repos_local or str(cache / "repos.local")
    args.profiles_local = args.profiles_local or str(cache / "profiles.local")
    args.collisions = args.collisions or str(cache / "collisions.local")
    cfg = config(args)
    root = Path(args.manifest).resolve().parent
    skills = Path(args.skills_dir).expanduser()
    owners = dict(line.split("=", 1) for line in lines(cache / ".skill-owners") if "=" in line)
    overrides = dict(line.split("=", 1) for line in lines(cache / "collisions.local") if "=" in line)
    repos = {name: url for name, url, _, _ in cfg["manifest"] if selected(cfg, name)}
    # Pin this invocation's own source. An uncommitted manifest cannot be reproduced.
    own_sha = git("rev-parse", "HEAD", cwd=root)
    own_url = git("remote", "get-url", "origin", cwd=root)
    if source_dirty(root):
        raise ValueError("Commit source changes (including untracked skills/scripts) before generating a reproducible preview")
    lock = {"version": 1, "config": cfg, "repos": {"agent-master": {"url": own_url, "commit": own_sha}}}
    proposed = {}
    observed = set()
    with tempfile.TemporaryDirectory(prefix="agentmaster-preview-") as tmp:
        sources = {"agent-master": root}
        for name, url in repos.items():
            checkout = Path(tmp) / name
            git("clone", "--quiet", "--filter=blob:none", "--no-checkout", "--", url, checkout)
            sha = git("rev-parse", "HEAD", cwd=checkout)
            git("checkout", "--quiet", "--detach", sha, cwd=checkout)
            lock["repos"][name] = {"url": url, "commit": sha}
            sources[name] = checkout
            before = None
            if (cache / name / ".git").exists():
                before = git("rev-parse", "HEAD", cwd=cache / name)
            print(f"REPO {name}: {before or 'not installed'} -> {sha}")
            if before and before != sha:
                try:
                    print(git("log", "--oneline", "--max-count=20", f"{before}..{sha}", cwd=checkout))
                    print(git("diff", "--stat", before, sha, cwd=checkout))
                except ValueError:
                    print("  Previous revision unavailable upstream; compare the reported commits manually")
        rows = [["agent-master", own_url, "skills", ""]] + cfg["manifest"]
        for name, _, source, exclude in rows:
            if name not in sources:
                print(f"EXCLUDED REPO {name}: profile {cfg['profile']}")
                continue
            directory = sources[name] / source
            if not directory.is_dir():
                raise ValueError(f"Missing skill source for {name}: {source}")
            for skill in sorted(directory.iterdir()):
                if not skill.is_dir() or not any((skill / n).is_file() for n in ("SKILL.md", "skill.md")):
                    continue
                observed.add((name, skill.name))
                if any(fnmatch.fnmatchcase(skill.name, pattern) for pattern in exclude.split()) or not selected(cfg, name, skill.name):
                    print(f"EXCLUDED {name}/{skill.name}")
                    continue
                previous = proposed.get(skill.name, owners.get(skill.name))
                destination = skills / skill.name
                conflict = (previous and previous != name) or (destination.exists() and previous is None)
                if conflict and overrides.get(skill.name) != name:
                    print(f"BLOCKED COLLISION {skill.name}: {previous or 'unowned'} -> {name}")
                    continue
                proposed[skill.name] = name
                action = "ADD" if not destination.exists() else "UNCHANGED" if tree_hash(skill) == tree_hash(destination) else "REPLACE"
                print(f"{action} {name}/{skill.name}")
        for skill, owner in owners.items():
            if owner in sources and (owner, skill) not in observed:
                print(f"REMOVAL CANDIDATE {owner}/{skill}: review with update --prune (modified/unprovenanced skills are preserved)")
    if args.write_lock:
        target = Path(args.write_lock)
        # Do not silently replace a previously reviewed lock.
        with target.open("x", encoding="utf-8", newline="\n") as out:
            json.dump(lock, out, indent=2, sort_keys=True)
            out.write("\n")
        print(f"LOCK WRITTEN {target}; review it before using apply --lock")


def apply(args):
    """Validate all input before launching a mutating installer/updater."""
    lock = load_lock(args.lock)
    root = Path(args.repo_root).resolve()
    cache = Path.home() / ".claude" / ".agentmaster-cache"
    cfg_args = argparse.Namespace(lock=args.lock, manifest=str(root / "repos.manifest"),
                                  profiles=str(root / "profiles.manifest"),
                                  profile=lock["config"]["profile"],
                                  repos_local=str(cache / "repos.local"),
                                  profiles_local=str(cache / "profiles.local"),
                                  collisions=str(cache / "collisions.local"))
    validate(cfg_args)
    own = lock["repos"]["agent-master"]
    if git("rev-parse", "HEAD", cwd=root) != own["commit"] or git("remote", "get-url", "origin", cwd=root) != own["url"]:
        raise ValueError("Run apply from the exact AgentMaster repository revision recorded in the lock")
    if source_dirty(root):
        raise ValueError("Source changes or untracked skills/scripts prevent a reproducible install")
    if args.mode == "update":
        installed_profile = lines(cache / ".profile") or ["full"]
        if installed_profile[0] != cfg_args.profile:
            raise ValueError("Installed profile differs from lock; use apply --mode install to select the locked profile")
    env = os.environ.copy()
    env["AGENTMASTER_LOCKED"] = "1"
    env["AGENTMASTER_LOCK_PINS"] = "\n".join(f"{name}={entry['commit']}" for name, entry in lock["repos"].items())
    entry = root / ("install" if args.mode == "install" else "scripts/update")
    if os.name == "nt":
        command = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(entry.with_suffix(".ps1"))]
        if args.mode == "install":
            command += ["-Profile", cfg_args.profile]
    else:
        command = ["bash", str(entry.with_suffix(".sh"))]
        if args.mode == "install":
            command += ["--profile", cfg_args.profile]
    result = subprocess.run(command, cwd=root, env=env)
    if result.returncode:
        raise ValueError(f"Locked {args.mode} failed (exit {result.returncode}); inspect its sync report")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    for command in ("preview", "validate"):
        p = sub.add_parser(command)
        p.add_argument("--manifest", default=str(Path(__file__).resolve().parents[1] / "repos.manifest"))
        p.add_argument("--profiles", default=str(Path(__file__).resolve().parents[1] / "profiles.manifest"))
        p.add_argument("--profile", default="full")
        p.add_argument("--repos-local")
        p.add_argument("--profiles-local")
        p.add_argument("--collisions")
        if command == "validate":
            p.add_argument("--lock", required=True)
        else:
            p.add_argument("--cache-dir", default="~/.claude/.agentmaster-cache")
            p.add_argument("--skills-dir", default="~/.claude/skills")
            p.add_argument("--write-lock")
    p = sub.add_parser("pin")
    p.add_argument("--lock", required=True)
    p.add_argument("--repo", required=True)
    p = sub.add_parser("apply", help="Install/update exact reviewed revisions (opt-in; changes installed skills)")
    p.add_argument("--lock", required=True)
    p.add_argument("--mode", choices=("install", "update"), default="install")
    p.add_argument("--repo-root", default=str(Path(__file__).resolve().parents[1]))
    args = parser.parse_args()
    try:
        if args.command == "preview":
            preview(args)
        elif args.command == "validate":
            validate(args)
        elif args.command == "apply":
            apply(args)
        else:
            lock = load_lock(args.lock)
            if args.repo not in lock["repos"]:
                raise ValueError(f"Repository absent from lock: {args.repo}")
            print(lock["repos"][args.repo]["commit"])
    except (ValueError, OSError, KeyError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
