# AgentMaster Skill Rollback — Design

**Date:** 2026-07-03
**Status:** Approved
**Scope:** Automatic pre-sync snapshots, local pins, `rollback` command, self-rollback support.

## Problem

A sync can bring a broken (or malicious) upstream skill version. There is no way back: caches are depth-1 clones (no history), and even a manual restore would be re-clobbered by the next auto-sync within 6 hours.

## Design

Rollback = **restore + pin**, atomically. Restoring without pinning is useless.

### 1. Pre-sync snapshots (updaters)

Before overwriting a repo's skills — only when the commit actually changed — the updater copies the currently installed skills owned by that repo (per `.skill-owners`) to `~/.claude/.agentmaster-cache/backups/<repo>/`, with a `.meta` file: previous **full** commit SHA, timestamp, skill count. One generation per repo (the version before the last change). Covers the dependency repos and agent-master's custom skills. First installs (nothing previous) produce no backup. File copies, not git checkouts: depth-1 clones have no history, and copies survive upstream force-pushes.

### 2. `pins.local`

`~/.claude/.agentmaster-cache/pins.local`, same `name=sha` format as `repos.pins`. Updaters resolve pins as **pins.local first, then repos.pins**. Machine-local, immediate, survives self-updates. Doubles as a general local pinning mechanism.

### 3. `rollback` command

`scripts/rollback.sh` + `scripts/rollback.ps1`:

- No args: list available backups (repo, restore SHA, date, skill count) and active local pins.
- With a repo name: (a) remove that repo's currently installed skills (owned ones only), (b) restore the snapshot and update ownership, (c) check the cache out at the previous SHA (best effort — fetch the SHA if needed), (d) write `repo=sha` to `pins.local` (replacing any prior line). Prints how to undo: delete the line from `pins.local`; the next sync returns to upstream HEAD. The backup is kept after restore.

### 4. Self-rollback

The self-update step honors a `agent-master` pin from `pins.local`/`repos.pins`: fetch + checkout that SHA instead of pulling. A bad AgentMaster release can therefore be rolled back and stay rolled back.

### 5. Wiring

`doctor` validates `pins.local` entries (40-hex SHA; name in manifest or `agent-master`) and NOTEs active local pins. `agent-master` SKILL.md gains the `rollback` subcommand. README updated.

## Testing

Syntax/parse checks. Live: force a sync where a repo updates (verify snapshot + .meta); `rollback` list mode; roll a repo back (verify skills restored, cache checked out, pin written); run a sync and verify the pin holds; remove the pin and verify the repo returns to upstream.

## Out of scope

Multiple backup generations, diffing backup vs current, rollback of individual skills (whole-repo granularity only).
