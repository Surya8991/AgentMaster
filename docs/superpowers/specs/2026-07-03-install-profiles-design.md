# AgentMaster Install Profiles — Design

**Date:** 2026-07-03
**Status:** Approved
**Scope:** Named install subsets (profiles) with a manifest, persistent selection, prune-and-resync switching, installer flag, and orchestrator wiring.

## Problem

Install and sync are all-or-nothing: every repo, every skill (44+). Users who only want the dev workflow — or only business/marketing skills — carry the rest as noise.

## Design

### 1. `profiles.manifest` (repo root)

Pipe format consistent with `repos.manifest`: `profile|repo|skill_glob`, multiple lines per profile. Shipped profiles:

- `dev` — caveman, superpowers, claude-mem, all custom skills
- `business` — caveman, claude-skills, plus `agent-master` + `repomix-pack` from custom skills
- `minimal` — caveman + the orchestrator only
- `full` — implicit default: no filtering, current behavior; needs no manifest lines

Skill globs (`*`, `marketing*`, exact names) let a profile take part of a repo. Shipped profiles filter mostly at repo level for robustness against upstream renames. Personal profiles: `~/.claude/.agentmaster-cache/profiles.local`, merged after the manifest, survives self-updates.

### 2. Active profile + updater filtering

Active profile persists in `~/.claude/.agentmaster-cache/.profile` (absent = `full`). Updaters filter:

- repos with no lines in the active profile are skipped and reported as `skipped (profile: <name>)`;
- during skill sync, each skill name must match one of the profile's globs for its repo.

**Safety rails:**
- Unknown profile name → warn and behave as `full` (a typo must never mass-uninstall).
- The `agent-master` orchestrator skill is always installed regardless of profile.

### 3. `profile` command

`scripts/profile.sh` + `scripts/profile.ps1`:

- No args: show active profile and available profiles with their repo/skill rules.
- With a name: validate against known profiles (or `full`), persist to `.profile`, **prune** installed skills excluded by the new profile — only skills with a recorded owner in `.skill-owners`; orphans/user skills are never touched — then clear the update cooldown and run a foreground sync.

### 4. Installer flag

`bash install.sh --profile <name>` / `.\install.ps1 -Profile <name>` writes `.profile` before installing and applies the same filtering. No flag = `full`.

### 5. Wiring

`doctor` reports the active profile. `agent-master` SKILL.md gains the `profile` subcommand (relay script output). README updated.

## Testing

Syntax/parse checks; live: switch to `minimal` (verify prune + resync + report), `profile` with no args, doctor line, switch back to `full` (verify everything reinstalls), unknown-profile fallback.

## Out of scope

Per-skill pruning inside `full`, profile composition/inheritance, rollback (next phase).
