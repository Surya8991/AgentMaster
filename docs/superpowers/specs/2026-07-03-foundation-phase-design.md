# AgentMaster Foundation Phase — Design

**Date:** 2026-07-03
**Status:** Approved
**Scope:** Manifest-driven repos, sync reporting with ownership tracking, `doctor` and `list` commands, orchestrator wiring.

## Goals

AgentMaster syncs 44+ skills from 5 repos silently. Four gaps identified: trust & visibility (no sync reports, no health checks), extensibility (repos hardcoded in 4 scripts), routing quality, and discovery & control. This phase delivers the foundation: the first two gaps plus discovery basics. Routing feedback, profiles, and rollback are later phases.

**Approach:** deterministic shell scripts (bash + PowerShell, matching the repo's zero-dependency pattern); the `agent-master` skill only routes to them and relays output.

## 1. Manifest-driven repos — `repos.manifest`

New file at repo root, one line per dependency repo, pipe-delimited (`name|url|skill_source`):

```
caveman|https://github.com/JuliusBrussee/caveman.git|skills
superpowers|https://github.com/obra/superpowers.git|skills
claude-skills|https://github.com/alirezarezvani/claude-skills.git|.
claude-mem|https://github.com/thedotmack/claude-mem.git|plugin/skills
```

- Installer and updaters loop over this instead of hardcoded blocks. Adding a repo = one line.
- Personal repos: `~/.claude/.agentmaster-cache/repos.local` (same format), merged after the manifest — survives self-updates because it lives outside the repo.
- `repos.pins` keys match manifest names.
- Updaters read the manifest from the self-update cache (`~/.claude/.agentmaster-cache/agent-master/repos.manifest`); the installer reads it from the repo checkout.
- Comment lines (`#`) and blank lines ignored.

## 2. Ownership tracking + sync report

- Every skill copy records `skill=repo` into `~/.claude/.agentmaster-cache/.skill-owners` (installer and updaters both).
- Custom skills copied from this repo are owned by `agent-master`.
- **Collision** = a repo copies a skill already owned by a different repo. Behavior stays last-writer-wins (unchanged), but the collision is recorded in the sync report and the owners file is updated to the new owner.
- Every update run writes `~/.claude/.agentmaster-cache/last-sync-report.txt`: timestamp, per-repo result (before→after commit and skill count, or "up to date" / failure reason), and collisions.

## 3. `doctor` — health check

`scripts/doctor.sh` + `scripts/doctor.ps1`. Checks, each emitting `PASS`/`WARN`/`FAIL` (plus non-scored `NOTE` lines):

| Check | Severity on problem |
|---|---|
| Skills directory exists | FAIL |
| Each skill has `SKILL.md` | FAIL |
| Frontmatter has `name:` and it matches the directory name | WARN |
| Frontmatter has `description:` | WARN |
| Each manifest repo is cached as a real git clone | WARN ("run update") |
| `repos.pins` entries reference manifest names | WARN |
| `repos.pins` SHAs are 40-char hex | WARN |
| Orphan skills (no recorded owner) | NOTE (likely user's own) |
| repomix on PATH | WARN |
| Last sync age > 7 days | WARN (updates may be failing silently) |

Exit code 0 if no FAILs, 1 otherwise. Missing files degrade to WARN — doctor never crashes.

## 4. `list` — skill discovery

`scripts/list.sh` + `scripts/list.ps1`: all installed skills grouped by owner repo (from `.skill-owners`; unrecorded skills grouped under `(unmanaged)`), each with its directory name and first line of its frontmatter description truncated to ~80 chars. No flags.

## 5. Orchestrator + docs wiring

- `agent-master` SKILL.md argument parsing gains `doctor` and `list` subcommands (run the script, relay output verbatim).
- Status mode (`/agent-master status`) additionally shows the last-sync-report summary.
- README usage table updated.

## Error handling

Scripts follow the hardening pattern already in place: every `git` call checks its exit code; failures are reported per-repo and never abort the whole run; lock and cooldown behavior in the updaters is unchanged.

## Testing

- `bash -n` on all bash scripts; PowerShell `Parser::ParseFile` on all ps1 scripts.
- Live: run `list` and `doctor` against the real skills dir; force an update run (delete `.last-update`) and verify `last-sync-report.txt` and `.skill-owners` are produced and collisions are reported.

## Out of scope (later phases)

Routing feedback loop / auto-registration of new skills in routing tables, install profiles, skill rollback, remote health (checking upstream repos for deletions).
