#!/bin/bash
# AgentMaster Auto-Updater
# Pulls latest from all dependency repos and syncs skills
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
QUIET="${1:-}"

log() { [ "$QUIET" != "--quiet" ] && echo "$@" || true; }

mkdir -p "$CACHE_DIR"

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
        log "  $name: pinned to ${pin:0:7}"
      else
        log "  $name: pin $pin not found, keeping current"
      fi
    else
      local before
      before=$(git -C "$cache_path" rev-parse HEAD 2>/dev/null || echo "none")
      if ! git -C "$cache_path" pull --ff-only --quiet 2>/dev/null; then
        log "  $name: pull failed, keeping current"
        return 0
      fi
      local after
      after=$(git -C "$cache_path" rev-parse HEAD 2>/dev/null || echo "none")
      if [ "$before" = "$after" ]; then
        log "  $name: up to date"
        return 0
      fi
      log "  $name: updated ($before -> $after)"
    fi
  else
    # Fresh clone (git refuses to clone into a non-empty dir, so reset first)
    log "  $name: cloning..."
    rm -rf "$cache_path"
    if ! git clone --depth 1 --quiet "$repo_url" "$cache_path" 2>/dev/null; then
      log "  $name: clone failed, skipping"
      return 0
    fi
    if [ -n "$pin" ]; then
      git -C "$cache_path" fetch --depth 1 --quiet origin "$pin" 2>/dev/null || true
      git -C "$cache_path" checkout --quiet "$pin" 2>/dev/null || true
    fi
  fi

  # Sync skills
  local src="$cache_path/$skill_source"
  if [ -d "$src" ]; then
    for skill_dir in "$src"/*/; do
      [ ! -d "$skill_dir" ] && continue
      local skill_name
      skill_name=$(basename "$skill_dir")
      # Only copy if SKILL.md exists (for claude-skills repo) or always (for others)
      if [ -f "$skill_dir/SKILL.md" ] || [ "$skill_source" = "skills" ]; then
        cp -r "$skill_dir" "$SKILLS_DIR/$skill_name" 2>/dev/null || true
      fi
    done
  fi

  return 0
}

mkdir -p "$SKILLS_DIR"

# Update AgentMaster itself first so a freshly pushed repos.pins takes effect this run
AM_CACHE="$CACHE_DIR/agent-master"
if [ -d "$AM_CACHE/.git" ]; then
  if git -C "$AM_CACHE" pull --ff-only --quiet 2>/dev/null; then
    log "  agent-master: synced"
  else
    log "  agent-master: pull failed, keeping current"
  fi
else
  # A cache dir without .git (e.g. from an old zip-based install) can't be
  # pulled — and git refuses to clone into a non-empty dir — so reset it.
  rm -rf "$AM_CACHE"
  if git clone --depth 1 --quiet "https://github.com/Surya8991/AgentMaster.git" "$AM_CACHE" 2>/dev/null; then
    log "  agent-master: installed from remote"
  else
    log "  agent-master: clone failed, skipping self-update"
  fi
fi
if [ -d "$AM_CACHE/skills" ]; then
  cp -r "$AM_CACHE/skills/"* "$SKILLS_DIR/" 2>/dev/null || true
fi

# Update each dependency repo
update_repo "caveman" \
  "https://github.com/JuliusBrussee/caveman.git" \
  "skills"

update_repo "superpowers" \
  "https://github.com/obra/superpowers.git" \
  "skills"

update_repo "claude-skills" \
  "https://github.com/alirezarezvani/claude-skills.git" \
  "."

update_repo "claude-mem" \
  "https://github.com/thedotmack/claude-mem.git" \
  "plugin/skills"

# Record update timestamp
date +%s > "$LAST_UPDATE_FILE"

log ""
log "All skills synced. Total: $(ls -d "$SKILLS_DIR/"*/ 2>/dev/null | wc -l) skills"
