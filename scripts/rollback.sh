#!/bin/bash
# AgentMaster Rollback — restore a repo's skills to the version before its
# last sync, and pin the repo locally so auto-updates hold the rollback.
#
# Usage:
#   bash scripts/rollback.sh           # list available backups + active local pins
#   bash scripts/rollback.sh <repo>    # roll <repo> back (restore + pin)
#
# Undo: remove the repo's line from ~/.claude/.agentmaster-cache/pins.local —
# the next sync returns to tracking upstream HEAD.

SKILLS_DIR="$HOME/.claude/skills"
CACHE_DIR="$HOME/.claude/.agentmaster-cache"
OWNERS_FILE="$CACHE_DIR/.skill-owners"
BACKUPS_DIR="$CACHE_DIR/backups"
PINS_LOCAL="$CACHE_DIR/pins.local"

meta_get() { grep -m1 "^$2=" "$1/.meta" 2>/dev/null | cut -d= -f2; }

# --- List mode ---
if [ -z "$1" ]; then
  echo "AgentMaster Rollback"
  echo "===================="
  echo ""
  echo "Available backups (the version before each repo's last change):"
  found=0
  for bdir in "$BACKUPS_DIR"/*/; do
    [ -f "$bdir/.meta" ] || continue
    repo=$(basename "$bdir")
    sha=$(meta_get "$bdir" sha)
    when=$(meta_get "$bdir" date)
    count=$(meta_get "$bdir" skills)
    echo "  $repo — restores to ${sha:0:7} ($count skills, backed up $when)"
    found=1
  done
  [ "$found" -eq 0 ] && echo "  (none yet — backups are taken automatically when a sync changes a repo)"
  echo ""
  echo "Active local pins (rollbacks / manual pins):"
  if [ -s "$PINS_LOCAL" ] && grep -qEv '^[[:space:]]*(#|$)' "$PINS_LOCAL"; then
    grep -Ev '^[[:space:]]*(#|$)' "$PINS_LOCAL" | sed 's/^/  /'
  else
    echo "  (none — repos track upstream HEAD)"
  fi
  echo ""
  echo "Roll back with: /agent-master rollback <repo>"
  exit 0
fi

# --- Rollback mode ---
repo="$1"
bdir="$BACKUPS_DIR/$repo"
if [ ! -f "$bdir/.meta" ]; then
  echo "No backup available for '$repo'."
  echo "Backups exist for: $(ls "$BACKUPS_DIR" 2>/dev/null | tr '\n' ' ')"
  exit 1
fi

sha=$(meta_get "$bdir" sha)
when=$(meta_get "$bdir" date)
echo "Rolling back '$repo' to ${sha:0:7} (backed up $when)..."

# 1. Remove the repo's currently installed skills (owned ones only)
removed=0
if [ -f "$OWNERS_FILE" ]; then
  while IFS='=' read -r skill owner; do
    [ "$owner" = "$repo" ] || continue
    rm -rf "${SKILLS_DIR:?}/$skill"
    sed -i.bak "/^$skill=/d" "$OWNERS_FILE" && rm -f "$OWNERS_FILE.bak"
    removed=$((removed+1))
  done < <(grep '=' "$OWNERS_FILE" 2>/dev/null)
fi

# 2. Restore the backed-up versions and re-record ownership
restored=0
for skill_dir in "$bdir"/*/; do
  [ ! -d "$skill_dir" ] && continue
  skill=$(basename "$skill_dir")
  cp -r "$skill_dir" "$SKILLS_DIR/$skill"
  echo "$skill=$repo" >> "$OWNERS_FILE"
  restored=$((restored+1))
done
echo "  restored $restored skills (removed $removed current)"

# 3. Check the cache out at the rolled-back commit (best effort)
cache_path="$CACHE_DIR/$repo"
if [ -d "$cache_path/.git" ]; then
  git -C "$cache_path" fetch --depth 1 --quiet origin "$sha" 2>/dev/null || true
  if git -C "$cache_path" checkout --quiet "$sha" 2>/dev/null; then
    echo "  cache checked out at ${sha:0:7}"
  else
    echo "  ! could not check out $sha in the cache (skills restored anyway)"
  fi
fi

# 4. Pin locally so the next auto-sync holds this version
touch "$PINS_LOCAL"
sed -i.bak "/^$repo=/d" "$PINS_LOCAL" && rm -f "$PINS_LOCAL.bak"
echo "$repo=$sha" >> "$PINS_LOCAL"
echo "  pinned in pins.local"

echo ""
echo "Done. '$repo' is rolled back to ${sha:0:7} and will stay there."
echo "To resume tracking upstream: remove the '$repo=' line from $PINS_LOCAL"
echo "Restart your Claude Code session to reload skills."
