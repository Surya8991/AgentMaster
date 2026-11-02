# AgentMaster: Project Log

> Single source of truth for this project. Lists what's built, what's planned,
> and how the system fits together. Update this file with every meaningful change.

**Last updated:** 2026-11-02. Reliability maintenance: updater copy-failure
reporting and process-owned locks, shared PowerShell rendering, staged installs,
reviewed dependency locks, collision/provenance controls, safe cleanup, routing
diagnostics, and Windows PowerShell regression coverage.

## Table of contents
- **STATUS** — S1 Current plan · S2 Ongoing · S3 Pending · S4 Blocked · S5 Done · S6 Decisions log · S7 Verification status
- **REFERENCE** — 1 What this is · 2 Tech stack · 3 State & data files · 4 The core loop · 5 Environment · 6 Operational commands · 7 Conventions & things that bit us

---

# STATUS

## S1. Current plan
- Reliability maintenance complete locally. Remote CI status has not been checked in this session.

## S2. Ongoing
- (none)

## S3. Pending
- Optional: wire more wshobson subsets or vet net-new external skill repos (collision-check first).
- Optional: package a native Claude Code plugin/marketplace form as an additional distribution channel (installer stays for multi-platform). Deferred — kept as-is for now.

## S4. Blocked / needs a decision
- (none)

## S5. Done
Newest first.
- **2026-11-02 follow-up** - Added staged validated skill replacement with rollback, explicit collision overrides, per-skill revision/content provenance, and opt-in cleanup for unchanged removed skills. Added temporary-clone previews and reviewed-lock apply mode with exact commit verification. Added 43 offline routing cases spanning 27 categories, captured-prediction scoring, and availability diagnostics. Fixed Windows PowerShell 5.1 encoding/parser issues and added isolated scaffold/dev-sync execution tests plus Windows CI.
- **2026-11-02** - Fixed sync accounting for failed copies and replaced age-only lock expiry with owner checks. Unified PowerShell rendering, removed date-dependent output, added output-parity and updater regression checks, and included Antigravity in drift detection. Reconciled documentation with 27 routing categories and 12 active dependency repositories; added a count consistency check.
- **2026-10-19** - `9c34232`: shared Bash platform renderers and installer/updater parity fixes. `7552b73`: reverse-engineering routing, niche dependency integrations, optional science/social-simulation repositories, and multi-pattern manifest exclusions.
- **2026-09-09 §1** —
  - **CI line endings** — 3 edited scripts (`doctor.sh`, `routes.sh`, `update.sh`) had CRLF blobs that failed shellcheck (SC1017) and `bash -n` on the Linux runner. Added `.gitattributes` (`* text=auto eol=lf`, `*.sh eol=lf`, `*.ps1 eol=crlf`) + `git add --renormalize`. Bumped `actions/checkout` v4 → v5 in both workflows. CI green.
  - **Docs sync** — updated every doc to 15 wshobson subsets / 96 skills / ~195 total (README, ONBOARDING, agents.md survey + unwired list, SKILL.md).
  - **RULES.md** — added Skill Development, Dependency Wiring, and push-auth rules; upgraded the doc-spine rule; fixed stale `D:/Coding` → `C:/Users/Surya/Desktop/Coding` paths.
  - **Wired 9 wshobson subsets (+50 skills)** — javascript-typescript, frontend-mobile-development, ui-design, cloud-infrastructure, observability-monitoring, incident-response, developer-essentials, data-engineering, documentation-generation. All collision-free.
  - **Tier 1–3 improvements** — `dev-sync.sh`/`.ps1` + `.dev` marker (honored by `update.sh`); `convert.ps1` + `install-platform.ps1` (full Windows parity); `tests/smoke.sh` + `.github/workflows/ci.yml`; `doctor.sh` gained dev-mode / scaffold / staleness / installed-vs-cache checks; `routes analyze`; fixed unrouted false-match for short names; installer now requires a `SKILL.md` (removed the stray `generated/` FAIL); scaffold hardened (`set -euo pipefail`) with stack auto-detection.
  - **Project scaffolding** — `/agent-master scaffold` + templates (`AGENTS.md`, `CLAUDE.md`, `PROJECTLOG.md`, `README.md`, `RULES.md`) + once-per-session suggestion.
  - **Routing** — Extended Skill Clusters table (86 → 32 unrouted); reconciled category count 25 → 26.
  - **Context files** — backfilled `CLAUDE.md` (`@AGENTS.md`) into AgentMaster, Content-Wiz, Email-Automator, cybersecurity-academy; created global `~/.claude/CLAUDE.md`; seeded project memory.

## S6. Decisions log
- 2026-09-09 — `CLAUDE.md` is a one-line `@AGENTS.md` import, never real content (matches Marketing-Academy). Keeps it from drifting from `AGENTS.md`.
- 2026-09-09 — Canonical project spine = `README.md` + `AGENTS.md` + `CLAUDE.md` + `PROJECTLOG.md`; `PROJECTLOG.md` is the canonical name (over `PROJECT_LOG.md`).
- 2026-09-09 — Kept the aggregator/installer model; did **not** convert to a plugin (multi-platform breadth is the differentiator; no native paid marketplace to earn from).
- 2026-09-09 — Wired only collision-free wshobson subsets; avoid davila7's big categories and `document-processing` (last-writer-wins collisions).
- 2026-09-09 — Force LF for shell/text via `.gitattributes`; PowerShell stays CRLF.
- 2026-09-09 — Push auth: repos owned by Surya8991 require `gh auth switch --user Surya8991` (default-active `edstellarmarketing` 403s); switch back after.

## S7. Verification status
- Passed: full Bash smoke suite, Bash/PowerShell byte parity across 58 generated files, repeat rendering and project-local installer parity, updater regression tests in both shells, and documentation count checks.
- Follow-up passed: 6 dependency preview/lock tests, 18 locked/ordinary pin integration cases, staged lifecycle/rollback/pruning suites in both shells, 43 routing baseline cases and captured-prediction scoring, and Windows PowerShell 5.1 parsing of 19 source scripts plus isolated scaffold/dev-sync execution. No live dependency installation or pruning was run.
- Changed PowerShell files parse under Windows PowerShell. ShellCheck and PSScriptAnalyzer are unavailable locally; CI runs those linters. The follow-up fixes Windows PowerShell 5.1 encoding-related parse errors in `dev-sync.ps1` and `scaffold.ps1` and adds execution coverage.
- Historical September verification: CI and smoke passed at `7c2c5ab`; installed inventory was 203 directories with 32 unrouted skills. These are historical measurements, not current guarantees.

---

# REFERENCE

## 1. What this project is
A meta-orchestrator + multi-platform skill installer for AI coding agents. One skill
(`/agent-master`) classifies a task and routes it to the right combination of installed
skills across 27 categories + Extended Skill Clusters. Its full profile draws from 12
dependency repositories (installed skill counts vary with upstream revisions), generates per-platform files for 11 agents, and keeps everything synced.

## 2. Tech stack
- **Language**: Bash (scripts) + PowerShell (`.ps1` parity), Node.js (Tool-Stack-Reference generators).
- **Format**: `SKILL.md` (YAML frontmatter + markdown body); `AGENTS.md`/`CLAUDE.md` context.
- **CI**: GitHub Actions — `ci.yml` (shellcheck error-severity + smoke), `check-git-identity.yml`.
- **Platforms**: Claude Code, Cursor, Windsurf, Cline, Codex, Gemini CLI, Antigravity, OpenCode, Augment, Aider, GitHub Copilot.

## 3. State & data files (no database)
- `~/.claude/skills/` — installed skills (runtime).
- `~/.claude/.agentmaster-cache/` — cloned dependency repos + `agent-master` self-update clone; `.skill-owners`, `repos.pins`/`pins.local`, `.profile`, `.last-update`, `.dev` marker, `last-sync-report.txt`, `unrouted-skills.txt`, `routing-log.txt`, `routing-overrides.md`.
- Repo config: `repos.manifest` (+ `repos.local`), `profiles.manifest` (+ `profiles.local`).

## 4. The core loop
`/agent-master` → (once/session) background self-update + repomix snapshot + RULES load +
scaffold check → classify task (Step 1 table / clusters / overrides) → announce + invoke
entry skill → tactical skills auto-surface by description → log the route; misroutes are
captured into `routing-overrides.md`.

## 5. Environment
- No `.env`. Repo at `C:/Users/Surya/Desktop/Coding/AgentMaster`. GitHub: `Surya8991/AgentMaster`.
- Push requires the `Surya8991` gh account (see Decisions log).

## 6. Operational commands
```bash
# edit a skill (source of truth), then regenerate all platform files
vim skills/<name>/SKILL.md && bash scripts/convert.sh --all

# fast local loop (bypass commit+push+update); turn off when done
bash scripts/dev-sync.sh        # ...iterate...    bash scripts/dev-sync.sh --off

# test, sync deps, health check, scaffold a new project's docs
bash tests/smoke.sh
bash scripts/update.sh
/agent-master doctor            # or: bash scripts/doctor.sh
/agent-master scaffold apply
```

## 7. Conventions and things that bit us
- Edit skills in `skills/` only; never hand-edit generated platform files (`convert.sh` overwrites them). `convert.sh` does NOT manage `AGENTS.md`/`CLAUDE.md`/`agents.md`.
- Shell scripts must be LF (`.gitattributes` enforces it) — CRLF fails Linux CI with SC1017.
- The runtime loads from `~/.claude/skills` and subcommands run from the cache; local edits aren't live until `dev-sync.sh` or a commit+push+update. Turn `.dev` off before relying on remote.
- Wiring blocks cross-owner/unowned collisions unless explicitly overridden — always collision-check (`comm -12`) before adding a subset.
- Every skill needs a `SKILL.md`, or the installer skips it (previously it dragged in caveman's `generated/`).
- `agents.md` and `AGENTS.md` are the same file on this case-insensitive filesystem.
