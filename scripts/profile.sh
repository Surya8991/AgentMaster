#!/bin/bash
# AgentMaster Profile — show or switch the active install profile.
#
# Usage:
#   bash scripts/profile.sh            # show active + available profiles
#   bash scripts/profile.sh <name>     # switch: prune excluded skills, resync

SKILLS_DIR="$HOME/.claude/skills"
CACHE_DIR="$HOME/.claude/.agentmaster-cache"
PROFILE_FILE="$CACHE_DIR/.profile"
OWNERS_FILE="$CACHE_DIR/.skill-owners"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

profiles_files() {
  # Cached manifest preferred; repo-checkout copy as fallback; personal profiles last
  if [ -f "$CACHE_DIR/agent-master/profiles.manifest" ]; then
    echo "$CACHE_DIR/agent-master/profiles.manifest"
  elif [ -f "$SCRIPT_DIR/../profiles.manifest" ]; then
    echo "$SCRIPT_DIR/../profiles.manifest"
  fi
  [ -f "$CACHE_DIR/profiles.local" ] && echo "$CACHE_DIR/profiles.local"
}

all_lines() {
  local f
  while read -r f; do
    [ -f "$f" ] && grep -Ev '^[[:space:]]*(#|$)' "$f" || true
  done < <(profiles_files)
}

skill_in_profile() {
  # skill_in_profile <profile> <repo> <skill>
  [ "$1" = "full" ] && return 0
  [ "$3" = "agent-master" ] && return 0  # the orchestrator always stays
  local prepo pattern
  while IFS='|' read -r _ prepo pattern; do
    [ "$prepo" = "$2" ] || continue
    case "$3" in $pattern) return 0 ;; esac
  done < <(all_lines | awk -F'|' -v p="$1" '$1==p')
  return 1
}

active=$(cat "$PROFILE_FILE" 2>/dev/null || echo full)
[ -z "$active" ] && active=full

# --- Show mode ---
if [ -z "$1" ]; then
  echo "AgentMaster Profiles"
  echo "===================="
  echo ""
  echo "Active profile: $active"
  echo ""
  echo "Available profiles:"
  echo "  full — everything (no filtering)"
  for p in $(all_lines | cut -d'|' -f1 | sort -u); do
    echo "  $p:"
    all_lines | awk -F'|' -v p="$p" '$1==p {printf "    %s: %s\n", $2, $3}'
  done
  echo ""
  echo "Switch with: /agent-master profile <name>"
  exit 0
fi

# --- Switch mode ---
target="$1"
if [ "$target" != "full" ] && ! all_lines | awk -F'|' -v p="$target" '$1==p{found=1} END{exit !found}'; then
  echo "Unknown profile: $target"
  echo "Available: full $(all_lines | cut -d'|' -f1 | sort -u | tr '\n' ' ')"
  exit 1
fi

echo "Switching profile: $active -> $target"
echo "$target" > "$PROFILE_FILE"

# Prune installed skills the new profile excludes.
# Only skills with a recorded owner are ever touched — orphans/user skills stay.
pruned=0
if [ -f "$OWNERS_FILE" ]; then
  while IFS='=' read -r skill repo; do
    [ -z "$skill" ] && continue
    if ! skill_in_profile "$target" "$repo" "$skill"; then
      rm -rf "${SKILLS_DIR:?}/$skill"
      sed -i.bak "/^$skill=/d" "$OWNERS_FILE" && rm -f "$OWNERS_FILE.bak"
      echo "  - pruned: $skill ($repo)"
      pruned=$((pruned+1))
    fi
  done < <(grep '=' "$OWNERS_FILE" 2>/dev/null)
fi
echo "Pruned $pruned skills."

# Resync immediately (clear the cooldown so the update actually runs)
rm -f "$CACHE_DIR/.last-update"
echo ""
bash "$SCRIPT_DIR/update.sh"
echo ""
echo "Profile '$target' active. Restart your Claude Code session to reload skills."
