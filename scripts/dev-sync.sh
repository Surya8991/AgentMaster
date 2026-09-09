#!/bin/bash
# AgentMaster Dev Sync — push the LOCAL working tree straight to the live install,
# bypassing git. Use this while iterating on skills/scripts so you don't have to
# commit + push + wait for the auto-updater to see your changes.
#
# It (1) copies skills/ into ~/.claude/skills, (2) copies this repo's skills+scripts+
# manifests into the self-update cache, and (3) writes a .dev marker so update.sh
# will NOT overwrite your local edits with the remote on the next session.
#
# Usage:
#   bash scripts/dev-sync.sh          # sync working tree -> live, enable dev mode
#   bash scripts/dev-sync.sh --off    # remove the .dev marker (resume auto-update)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SKILLS_DIR="$HOME/.claude/skills"
CACHE_DIR="$HOME/.claude/.agentmaster-cache"
AM_CACHE="$CACHE_DIR/agent-master"
DEV_MARKER="$CACHE_DIR/.dev"

if [ "${1:-}" = "--off" ]; then
  rm -f "$DEV_MARKER"
  echo "Dev mode OFF — the auto-updater will resume pulling remote on the next session."
  echo "Run 'bash scripts/update.sh' to pull the committed remote now."
  exit 0
fi

mkdir -p "$SKILLS_DIR" "$AM_CACHE"

# 1. Local AgentMaster skills -> live install dir
count=0
for skill_dir in "$REPO_DIR/skills/"*/; do
  [ -f "$skill_dir/SKILL.md" ] || continue
  name="$(basename "$skill_dir")"
  rm -rf "${SKILLS_DIR:?}/$name"
  cp -r "$skill_dir" "$SKILLS_DIR/$name"
  count=$((count + 1))
done
echo "Synced $count AgentMaster skill(s) -> $SKILLS_DIR"

# 2. Local repo -> self-update cache (the scripts the /agent-master subcommands run
#    from). Preserve the cache's .git so 'dev-sync --off' + update can restore remote.
for item in skills scripts repos.manifest profiles.manifest repos.pins agents.md; do
  [ -e "$REPO_DIR/$item" ] || continue
  rm -rf "$AM_CACHE/${item:?}"
  cp -r "$REPO_DIR/$item" "$AM_CACHE/$item"
done
chmod +x "$AM_CACHE"/scripts/*.sh 2>/dev/null || true
echo "Synced working tree -> $AM_CACHE"

# 3. Enable dev mode so the auto-updater leaves the local cache alone
date +%s > "$DEV_MARKER"
echo "Dev mode ON (.dev marker written) — the auto-updater will NOT overwrite local edits."
echo "Run 'bash scripts/dev-sync.sh --off' to resume normal auto-update."
