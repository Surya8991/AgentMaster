#!/bin/bash
# AgentMaster Auto-Updater
# Pulls latest from all dependency repos (repos.manifest) and syncs skills.
# Writes a sync report to ~/.claude/.agentmaster-cache/last-sync-report.txt
# Designed to run in background on session start
#
# Usage:
#   bash scripts/update.sh              # foreground
#   bash scripts/update.sh --quiet      # suppress output (background mode)

set -e

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  echo "Usage: bash scripts/update.sh [--quiet]"
  echo "Pulls latest from all dependency repos and syncs skills to ~/.claude/skills/"
  echo "  --quiet   Suppress output (for background mode)"
  exit 0
fi

SKILLS_DIR="$HOME/.claude/skills"
CACHE_DIR="$HOME/.claude/.agentmaster-cache"
LOCK_FILE="$CACHE_DIR/.update-lock"
LAST_UPDATE_FILE="$CACHE_DIR/.last-update"
PINS_FILE="$CACHE_DIR/agent-master/repos.pins"
MANIFEST="$CACHE_DIR/agent-master/repos.manifest"
OWNERS_FILE="$CACHE_DIR/.skill-owners"
REPORT_FILE="$CACHE_DIR/last-sync-report.txt"
QUIET="${1:-}"

REPORT=""
COLLISIONS=""

log() { [ "$QUIET" != "--quiet" ] && echo "$@" || true; }
report() { log "  $1"; REPORT="$REPORT$1
"; }

mkdir -p "$CACHE_DIR"
touch "$OWNERS_FILE"

# Clear stale locks (crashed runs), then take the lock atomically:
# noclobber makes the redirect fail if the file already exists.
if [ -f "$LOCK_FILE" ]; then
  lock_age=$(( $(date +%s) - $(date -r "$LOCK_FILE" +%s 2>/dev/null || echo 0) ))
  [ "$lock_age" -ge 300 ] && rm -f "$LOCK_FILE"
fi
if ! ( set -o noclobber; : > "$LOCK_FILE" ) 2>/dev/null; then
  log "Update already running. Skipping."
  exit 0
fi
trap 'rm -f "$LOCK_FILE"' EXIT

# Skip if updated within last 6 hours
if [ -f "$LAST_UPDATE_FILE" ]; then
  last=$(cat "$LAST_UPDATE_FILE" 2>/dev/null || echo 0)
  now=$(date +%s)
  diff=$(( now - last ))
  if [ "$diff" -lt 21600 ]; then
    log "Updated $(( diff / 3600 ))h ago. Skipping (6h cooldown)."
    exit 0
  fi
fi

log "AgentMaster: Checking for skill updates..."

# Read an optional commit pin for a repo from repos.pins (name=sha lines)
get_pin() {
  [ -f "$PINS_FILE" ] || return 0
  grep -E "^$1=" "$PINS_FILE" 2>/dev/null | head -1 | cut -d= -f2 || true
}

record_owner() {
  # record_owner <skill> <repo> — track ownership, collect collisions for the report
  local prev
  prev=$(grep -E "^$1=" "$OWNERS_FILE" 2>/dev/null | head -1 | cut -d= -f2 || true)
  if [ -z "$prev" ]; then
    echo "$1=$2" >> "$OWNERS_FILE"
  elif [ "$prev" != "$2" ]; then
    COLLISIONS="$COLLISIONS  $1: $prev -> $2
"
    sed -i.bak "s|^$1=.*|$1=$2|" "$OWNERS_FILE" && rm -f "$OWNERS_FILE.bak"
  fi
}

read_manifest() {
  # Emit "name|url|source" lines from the manifest plus personal repos.local
  local f
  for f in "$MANIFEST" "$CACHE_DIR/repos.local"; do
    [ -f "$f" ] && grep -Ev '^[[:space:]]*(#|$)' "$f" || true
  done
}

# --- Profiles: filter which repos/skills sync (see profiles.manifest) ---
ACTIVE_PROFILE=$(cat "$CACHE_DIR/.profile" 2>/dev/null || echo full)
[ -z "$ACTIVE_PROFILE" ] && ACTIVE_PROFILE=full

profile_lines() {
  # "profile|repo|glob" lines for the active profile (manifest + profiles.local)
  local f
  for f in "$CACHE_DIR/agent-master/profiles.manifest" "$CACHE_DIR/profiles.local"; do
    [ -f "$f" ] && grep -Ev '^[[:space:]]*(#|$)' "$f" || true
  done | awk -F'|' -v p="$ACTIVE_PROFILE" '$1==p'
}

repo_in_profile() {
  [ "$ACTIVE_PROFILE" = "full" ] && return 0
  profile_lines | awk -F'|' -v r="$1" '$2==r{found=1} END{exit !found}'
}

skill_in_profile() {
  # skill_in_profile <repo> <skill>
  [ "$ACTIVE_PROFILE" = "full" ] && return 0
  [ "$2" = "agent-master" ] && return 0  # the orchestrator always installs
  local prepo pattern
  while IFS='|' read -r _ prepo pattern; do
    [ "$prepo" = "$1" ] || continue
    case "$2" in $pattern) return 0 ;; esac
  done < <(profile_lines)
  return 1
}

sync_skills() {
  # sync_skills <repo_name> <src_dir> <skill_source_label>
  # Sets SYNCED_COUNT (no command substitution — a subshell would lose
  # the COLLISIONS accumulated by record_owner).
  local name="$1" src="$2" skill_source="$3" count=0
  SYNCED_COUNT=0
  [ -d "$src" ] || return 0
  for skill_dir in "$src"/*/; do
    [ ! -d "$skill_dir" ] && continue
    local skill_name
    skill_name=$(basename "$skill_dir")
    if [ -f "$skill_dir/SKILL.md" ] || [ "$skill_source" = "skills" ]; then
      skill_in_profile "$name" "$skill_name" || continue
      cp -r "$skill_dir" "$SKILLS_DIR/$skill_name" 2>/dev/null || true
      record_owner "$skill_name" "$name"
      count=$((count + 1))
    fi
  done
  SYNCED_COUNT=$count
}

update_repo() {
  local name="$1" repo_url="$2" skill_source="$3"
  local cache_path="$CACHE_DIR/$name"
  local pin
  pin=$(get_pin "$name")

  if [ -d "$cache_path/.git" ]; then
    if [ -n "$pin" ]; then
      # Pinned: fetch and check out the exact commit, never track HEAD
      git -C "$cache_path" fetch --depth 1 --quiet origin "$pin" 2>/dev/null || true
      if git -C "$cache_path" checkout --quiet "$pin" 2>/dev/null; then
        sync_skills "$name" "$cache_path/$skill_source" "$skill_source"
        report "$name: pinned to ${pin:0:7} ($SYNCED_COUNT skills)"
      else
        report "$name: pin $pin not found, keeping current"
      fi
      return 0
    else
      local before
      before=$(git -C "$cache_path" rev-parse --short HEAD 2>/dev/null || echo "none")
      # Caches are machine-managed mirrors — discard any local edits that
      # would block the pull (e.g. left behind by older installers).
      git -C "$cache_path" reset --hard --quiet 2>/dev/null || true
      git -C "$cache_path" clean -fdq 2>/dev/null || true
      if ! git -C "$cache_path" pull --ff-only --quiet 2>/dev/null; then
        report "$name: pull failed, keeping current ($before)"
        return 0
      fi
      local after
      after=$(git -C "$cache_path" rev-parse --short HEAD 2>/dev/null || echo "none")
      if [ "$before" = "$after" ]; then
        # Still sync: copies are idempotent and this keeps ownership
        # records complete even when nothing changed upstream.
        sync_skills "$name" "$cache_path/$skill_source" "$skill_source"
        report "$name: up to date ($after)"
        return 0
      fi
      sync_skills "$name" "$cache_path/$skill_source" "$skill_source"
      report "$name: updated $before -> $after ($SYNCED_COUNT skills)"
      return 0
    fi
  else
    # Fresh clone (git refuses to clone into a non-empty dir, so reset first)
    log "  $name: cloning..."
    rm -rf "$cache_path"
    if ! git clone --depth 1 --quiet "$repo_url" "$cache_path" 2>/dev/null; then
      report "$name: clone failed, skipping"
      return 0
    fi
    if [ -n "$pin" ]; then
      git -C "$cache_path" fetch --depth 1 --quiet origin "$pin" 2>/dev/null || true
      git -C "$cache_path" checkout --quiet "$pin" 2>/dev/null || true
    fi
  fi

  # Freshly cloned: sync whatever is checked out
  sync_skills "$name" "$cache_path/$skill_source" "$skill_source"
  if [ -n "$pin" ]; then
    report "$name: cloned, pinned to ${pin:0:7} ($SYNCED_COUNT skills)"
  else
    report "$name: cloned ($SYNCED_COUNT skills)"
  fi
}

mkdir -p "$SKILLS_DIR"

# Update AgentMaster itself first so a freshly pushed repos.manifest/repos.pins
# takes effect in the same run
AM_CACHE="$CACHE_DIR/agent-master"
if [ -d "$AM_CACHE/.git" ]; then
  am_before=$(git -C "$AM_CACHE" rev-parse --short HEAD 2>/dev/null || echo "none")
  # Caches are machine-managed mirrors — discard any local edits that
  # would block the pull (e.g. left behind by older installers).
  git -C "$AM_CACHE" reset --hard --quiet 2>/dev/null || true
  git -C "$AM_CACHE" clean -fdq 2>/dev/null || true
  if git -C "$AM_CACHE" pull --ff-only --quiet 2>/dev/null; then
    am_after=$(git -C "$AM_CACHE" rev-parse --short HEAD 2>/dev/null || echo "none")
    if [ "$am_before" = "$am_after" ]; then
      report "agent-master: up to date ($am_after)"
    else
      report "agent-master: updated $am_before -> $am_after"
    fi
  else
    report "agent-master: pull failed, keeping current ($am_before)"
  fi
else
  # A cache dir without .git (e.g. from an old zip-based install) can't be
  # pulled — and git refuses to clone into a non-empty dir — so reset it.
  rm -rf "$AM_CACHE"
  if git clone --depth 1 --quiet "https://github.com/Surya8991/AgentMaster.git" "$AM_CACHE" 2>/dev/null; then
    report "agent-master: installed from remote"
  else
    report "agent-master: clone failed, skipping self-update"
  fi
fi
# Unknown-profile guard AFTER self-update so a freshly pushed profiles.manifest counts.
# A typo in .profile must never mass-uninstall — fall back to full.
if [ "$ACTIVE_PROFILE" != "full" ] && ! profile_lines | grep -q .; then
  report "profile '$ACTIVE_PROFILE' not found — using full"
  ACTIVE_PROFILE=full
fi
[ "$ACTIVE_PROFILE" != "full" ] && report "profile: $ACTIVE_PROFILE"

if [ -d "$AM_CACHE/skills" ]; then
  for skill_dir in "$AM_CACHE/skills/"*/; do
    [ ! -d "$skill_dir" ] && continue
    skill_name=$(basename "$skill_dir")
    skill_in_profile "agent-master" "$skill_name" || continue
    cp -r "$skill_dir" "$SKILLS_DIR/$skill_name" 2>/dev/null || true
    record_owner "$skill_name" "agent-master"
  done
fi

# Update each dependency repo from the manifest
if [ ! -f "$MANIFEST" ]; then
  report "manifest missing: $MANIFEST — no dependency repos synced"
fi
while IFS='|' read -r name url source; do
  [ -z "$name" ] && continue
  if ! repo_in_profile "$name"; then
    report "$name: skipped (profile: $ACTIVE_PROFILE)"
    continue
  fi
  update_repo "$name" "$url" "$source"
done < <(read_manifest)

# Regenerate unrouted-skills.txt: installed skills never mentioned in the routing table
ROUTING_TABLE="$AM_CACHE/skills/agent-master/SKILL.md"
UNROUTED_FILE="$CACHE_DIR/unrouted-skills.txt"
if [ -f "$ROUTING_TABLE" ]; then
  : > "$UNROUTED_FILE"
  unrouted=0
  for skill_dir in "$SKILLS_DIR"/*/; do
    [ ! -d "$skill_dir" ] && continue
    sname=$(basename "$skill_dir")
    if ! grep -qwF "$sname" "$ROUTING_TABLE"; then
      sdesc=$(grep -m1 '^description:' "$skill_dir/SKILL.md" 2>/dev/null | sed 's/^description:[[:space:]]*//; s/^["'\'']//; s/["'\'']$//')
      case "$sdesc" in
        ">"|"|"|">-"|"|-"|">+"|"|+")
          sdesc=$(awk '/^description:/{f=1; next} f && NF {print; exit}' "$skill_dir/SKILL.md" 2>/dev/null | sed 's/^[[:space:]]*//')
          ;;
      esac
      [ ${#sdesc} -gt 100 ] && sdesc="${sdesc:0:97}..."
      echo "$sname — $sdesc" >> "$UNROUTED_FILE"
      unrouted=$((unrouted+1))
    fi
  done
  report "unrouted skills: $unrouted (not in routing table)"
fi

# Record update timestamp
date +%s > "$LAST_UPDATE_FILE"

# Write sync report
{
  echo "AgentMaster sync report — $(date '+%Y-%m-%d %H:%M:%S')"
  echo "$REPORT"
  if [ -n "$COLLISIONS" ]; then
    echo "Collisions (last writer wins):"
    printf '%s' "$COLLISIONS"
  else
    echo "Collisions: none"
  fi
} > "$REPORT_FILE"

log ""
log "All skills synced. Total: $(ls -d "$SKILLS_DIR/"*/ 2>/dev/null | wc -l) skills"
log "Report: $REPORT_FILE"
