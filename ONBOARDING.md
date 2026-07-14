# AgentMaster — Onboarding Guide

AgentMaster is a skill installer and meta-orchestrator for Claude Code. It installs ~125 skills from eight repos into `~/.claude/skills/`, keeps them synced, and routes tasks to the right skill combination via `/agent-master`.

## Install

```bash
# Everything (default)
bash install.sh                    # Windows: .\install.ps1

# A subset — see "Profiles" below
bash install.sh --profile dev      # Windows: .\install.ps1 -Profile dev
```

Then start a new Claude Code session so the skills load. Skills auto-update every 6 hours on first `/agent-master` invoke (background, non-blocking).

## Commands

| Command | What it does |
|---------|--------------|
| `/agent-master` | Classify the current task and route to the right skill(s) |
| `/agent-master route <task>` | Dry run — show the routing plan without executing |
| `/agent-master status` | Session state + the last sync report |
| `/agent-master update` | Force-sync all repos now (skips the 6-hour cooldown) |
| `/agent-master doctor` | Health check: skill frontmatter, caches, pins, ownership, routing coverage, sync freshness. PASS/WARN/FAIL, exit 1 on any FAIL |
| `/agent-master list` | All installed skills grouped by source repo, with descriptions |
| `/agent-master routes` | Routing log, learned overrides, and unrouted skills |
| `/agent-master profile [name]` | Show or switch install profiles (prunes + resyncs on switch) |
| `/agent-master rollback [repo]` | List backups, or restore a repo's pre-sync skill versions and pin them |
| `/agent-master repomix ...` | Forward to the repomix-pack skill (`refresh`, `include src/**`) |
| `/codereview` | Blunt, factual code review |
| `/caveman` | Token-compressed output mode (~75% savings) |

Every command has a script backing it in `scripts/` (`.sh` and `.ps1` variants) — you can run them directly without the orchestrator.

## Configuration files

| File | Location | Purpose |
|------|----------|---------|
| `repos.manifest` | repo root | Dependency repos, one per line: `name\|url\|skill_source` |
| `profiles.manifest` | repo root | Install profiles: `profile\|repo\|skill_glob` (shipped: dev, business, minimal) |
| `repos.pins` | repo root | Commit pins (`name=sha`) — supply-chain guard, committed and shared |
| `repos.local` | `~/.claude/.agentmaster-cache/` | Your extra repos — survives self-updates |
| `profiles.local` | `~/.claude/.agentmaster-cache/` | Your custom profiles |
| `pins.local` | `~/.claude/.agentmaster-cache/` | Machine-local pins; **wins over repos.pins**; written by rollback |

## Key behaviors worth knowing

- **Sync reports**: every update writes `~/.claude/.agentmaster-cache/last-sync-report.txt` — per-repo before→after commits, skill counts, failures, and cross-repo skill-name collisions. `/agent-master status` shows it.
- **Ownership tracking**: `.skill-owners` records which repo installed each skill. Collisions (two repos shipping the same skill name) are last-writer-wins but always reported.
- **Routing learns**: correct a misroute in-session ("no, use X") and the rule persists in `routing-overrides.md`, which loads every session and beats the static routing table. Newly synced skills not yet in the routing table are consulted as a fallback before AgentMaster asks you.
- **Profiles are safe**: switching prunes only skills AgentMaster installed (per ownership records) — your own skills are never touched. An unknown profile name falls back to `full` rather than uninstalling anything. The orchestrator skill itself always installs.
- **Rollback = restore + pin**: syncs that change a repo back up the outgoing versions first (`backups/<repo>/`, one generation). `rollback <repo>` restores them and pins the repo in `pins.local` so the next auto-sync holds the rollback. Undo by deleting the repo's line from `pins.local`. Works for `agent-master` itself.
- **Caches are disposable mirrors**: `~/.claude/.agentmaster-cache/<repo>/` clones are hard-reset before every pull. Never edit them — put local changes in the `*.local` files instead.

## Uninstall

```bash
bash uninstall.sh        # Windows: .\uninstall.ps1
```

Removes only AgentMaster's custom skills (agent-master, codereview, devops, security-audit, repomix-pack); third-party skills stay.

## Troubleshooting

1. `/agent-master doctor` — start here; it checks everything and tells you the fix.
2. Sync looks stale? `/agent-master update` forces it; the report shows exactly what happened per repo.
3. A skill broke after an update? `/agent-master rollback` lists what can be restored.
4. Design docs for every subsystem live in `docs/superpowers/specs/`.
