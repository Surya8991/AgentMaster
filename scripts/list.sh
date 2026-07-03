#!/bin/bash
# AgentMaster List — installed skills grouped by source repo.
#
# Usage: bash scripts/list.sh

SKILLS_DIR="$HOME/.claude/skills"
CACHE_DIR="$HOME/.claude/.agentmaster-cache"
OWNERS_FILE="$CACHE_DIR/.skill-owners"

if [ ! -d "$SKILLS_DIR" ]; then
  echo "No skills directory at $SKILLS_DIR — run install first."
  exit 1
fi

get_owner() {
  [ -f "$OWNERS_FILE" ] || { echo "(unmanaged)"; return; }
  local o
  o=$(grep -E "^$1=" "$OWNERS_FILE" 2>/dev/null | head -1 | cut -d= -f2)
  echo "${o:-(unmanaged)}"
}

get_desc() {
  # First line of the frontmatter description, truncated to 80 chars
  local d
  d=$(grep -m1 '^description:' "$1/SKILL.md" 2>/dev/null | sed 's/^description:[[:space:]]*//; s/^["'\'']//; s/["'\'']$//')
  if [ ${#d} -gt 80 ]; then d="${d:0:77}..."; fi
  echo "$d"
}

# Collect "owner|skill|desc" then print grouped by owner
rows=$(for skill_dir in "$SKILLS_DIR"/*/; do
  [ ! -d "$skill_dir" ] && continue
  name=$(basename "$skill_dir")
  echo "$(get_owner "$name")|$name|$(get_desc "$skill_dir")"
done | sort)

echo "Installed skills ($(echo "$rows" | grep -c '|'))"
echo "======================================"

current=""
while IFS='|' read -r owner skill desc; do
  [ -z "$skill" ] && continue
  if [ "$owner" != "$current" ]; then
    current="$owner"
    echo ""
    echo "[$owner]"
  fi
  if [ -n "$desc" ]; then
    printf '  %-32s %s\n' "$skill" "$desc"
  else
    printf '  %s\n' "$skill"
  fi
done <<< "$rows"
