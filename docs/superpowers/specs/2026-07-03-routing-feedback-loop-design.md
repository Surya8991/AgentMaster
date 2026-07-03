# AgentMaster Routing Feedback Loop — Design

**Date:** 2026-07-03
**Status:** Approved
**Scope:** Unrouted-skill detection, routing log, misroute capture with persistent overrides, fallback upgrade, `routes` command.

## Problem

The orchestrator's routing table (in `skills/agent-master/SKILL.md`) is static. Newly synced skills are invisible to routing, and misroutes corrected by the user teach the system nothing.

## Constraint

Routing is executed by the LLM from markdown instructions. The loop is therefore split: **detection is deterministic** (shell scripts), **learning is instruction-driven** (skill markdown) — with the learned state stored in files the scripts and the skill both read.

## Components

### 1. Unrouted-skill detection (deterministic)

After every sync, the updater checks each installed skill name against the cached routing table (`~/.claude/.agentmaster-cache/agent-master/skills/agent-master/SKILL.md`, fixed-string word match) and writes misses to `~/.claude/.agentmaster-cache/unrouted-skills.txt` as `name — description` lines. `doctor` gains a Routing section: PASS when the file is empty, NOTE listing unrouted skills otherwise. False negatives from common-word names (e.g. `do`) are acceptable; false positives are not.

### 2. Routing log (skill instruction)

After every routing decision the orchestrator appends one line to `~/.claude/.agentmaster-cache/routing-log.txt`:
`YYYY-MM-DD | task gist (<=10 words) | category | skill(s)`. Best-effort; never blocks the user's task.

### 3. Misroute capture → persistent overrides (skill instruction)

When the user corrects a route in-session, the orchestrator:
1. appends a log line ending `| corrected -> <skill>`;
2. appends a rule to `~/.claude/.agentmaster-cache/routing-overrides.md`:
   `- "<task pattern>" → <skill> (not <wrong skill>) — added YYYY-MM-DD`.

The overrides file is loaded once per session (same pattern as RULES.md) and **takes precedence over the static routing table** at classification time. This is the persistence mechanism: corrections survive sessions without editing the skill.

### 4. Fallback upgrade (skill instruction)

When no category matches, the orchestrator reads `unrouted-skills.txt` and checks whether an unrouted skill's description matches the task before asking the user.

### 5. `routes` command (deterministic)

`scripts/routes.sh` + `scripts/routes.ps1`: prints the last 15 routing-log entries, active overrides, and unrouted skills. Wired as `/agent-master routes` (relay output verbatim).

## Files touched

`scripts/update.{sh,ps1}` (generate unrouted list), `scripts/doctor.{sh,ps1}` (Routing section), new `scripts/routes.{sh,ps1}`, `skills/agent-master/SKILL.md` (overrides load, log step, misroute capture, fallback, `routes` subcommand), README.

## Testing

Syntax/parse checks on all scripts; forced sync to generate `unrouted-skills.txt`; `doctor` and `routes` live runs; seed a fake override + log entry and verify `routes` renders them.

## Out of scope

Automatic promotion of overrides into the static table (manual curation via git remains), routing analytics/scoring, profiles, rollback.
