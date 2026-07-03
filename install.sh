#!/bin/bash
# AgentMaster Installer
# Clones dependency repos (from repos.manifest) into the auto-update cache
# and copies skills to ~/.claude/skills/

set -e

SKILLS_DIR="$HOME/.claude/skills"
CACHE_DIR="$HOME/.claude/.agentmaster-cache"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MANIFEST="$SCRIPT_DIR/repos.manifest"
OWNERS_FILE="$CACHE_DIR/.skill-owners"

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  echo "Usage: bash install.sh [--profile <name>]"
  echo "Installs AgentMaster skills + dependency repos (repos.manifest) to ~/.claude/skills/"
  echo "  --profile <name>   Install a subset (see profiles.manifest: dev, business, minimal)."
  echo "                     Default: full (everything)."
  exit 0
fi

PROFILES_MANIFEST="$SCRIPT_DIR/profiles.manifest"

profile_lines() {
  # "profile|repo|glob" lines for the active profile (manifest + profiles.local)
  local f
  for f in "$PROFILES_MANIFEST" "$CACHE_DIR/profiles.local"; do
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

echo "AgentMaster Installer v1.3"
echo "=========================="
echo ""

mkdir -p "$SKILLS_DIR" "$CACHE_DIR"
touch "$OWNERS_FILE"

# Resolve the install profile: --profile flag wins, else any previously
# persisted choice, else full. Explicit flag with an unknown name fails loudly.
ACTIVE_PROFILE=$(cat "$CACHE_DIR/.profile" 2>/dev/null || echo full)
[ -z "$ACTIVE_PROFILE" ] && ACTIVE_PROFILE=full
if [ "$1" = "--profile" ]; then
  if [ -z "$2" ]; then
    echo "error: --profile requires a name (see profiles.manifest)"
    exit 1
  fi
  ACTIVE_PROFILE="$2"
  if [ "$ACTIVE_PROFILE" != "full" ] && ! profile_lines | grep -q .; then
    echo "error: unknown profile '$ACTIVE_PROFILE'"
    echo "Available: full $(grep -Ev '^[[:space:]]*(#|$)' "$PROFILES_MANIFEST" 2>/dev/null | cut -d'|' -f1 | sort -u | tr '\n' ' ')"
    exit 1
  fi
  echo "$ACTIVE_PROFILE" > "$CACHE_DIR/.profile"
fi
[ "$ACTIVE_PROFILE" != "full" ] && echo "Profile: $ACTIVE_PROFILE"

clone_repo() {
  # clone_repo <url> <dest> — depth-1 clone with an explicit failure message
  if ! git clone --depth 1 --quiet "$1" "$2" 2>/dev/null; then
    echo "  ! clone failed: $1"
    return 1
  fi
}

record_owner() {
  # record_owner <skill> <repo> — track which repo installed each skill
  local prev
  prev=$(grep -E "^$1=" "$OWNERS_FILE" 2>/dev/null | head -1 | cut -d= -f2 || true)
  if [ -z "$prev" ]; then
    echo "$1=$2" >> "$OWNERS_FILE"
  elif [ "$prev" != "$2" ]; then
    echo "  ! collision: skill '$1' was owned by $prev, overwritten by $2"
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

install_from_cache() {
  # install_from_cache <name> <url> <skill_source>
  # Clone into the auto-update cache (if needed) and copy skills from there, so the
  # installer and updater share one clone per repo and the first update is instant.
  local name="$1" url="$2" skill_source="$3"
  local cache_path="$CACHE_DIR/$name"

  if [ ! -d "$cache_path/.git" ]; then
    rm -rf "$cache_path"
    clone_repo "$url" "$cache_path" || return 0
  fi

  local src="$cache_path/$skill_source"
  if [ ! -d "$src" ]; then
    echo "  ! skill source missing: $src"
    return 0
  fi
  local count=0
  for skill_dir in "$src"/*/; do
    [ ! -d "$skill_dir" ] && continue
    local skill_name
    skill_name=$(basename "$skill_dir")
    if [ -f "$skill_dir/SKILL.md" ] || [ "$skill_source" = "skills" ]; then
      skill_in_profile "$name" "$skill_name" || continue
      cp -r "$skill_dir" "$SKILLS_DIR/$skill_name"
      record_owner "$skill_name" "$name"
      count=$((count + 1))
    fi
  done
  echo "  + $name: $count skills"
}

# 1. Install custom skills (agent-master, codereview, devops, security-audit, repomix-pack)
echo "[1/4] Installing custom skills..."
for skill_dir in "$SCRIPT_DIR/skills/"*/; do
  skill_name=$(basename "$skill_dir")
  if [ -f "$skill_dir/SKILL.md" ]; then
    skill_in_profile "agent-master" "$skill_name" || continue
    cp -r "$skill_dir" "$SKILLS_DIR/$skill_name"
    record_owner "$skill_name" "agent-master"
    echo "  + $skill_name"
  fi
done

# 2. Install dependency repos from the manifest
echo ""
echo "[2/4] Installing dependency repos (repos.manifest)..."
while IFS='|' read -r name url source; do
  [ -z "$name" ] && continue
  if ! repo_in_profile "$name"; then
    echo "  ~ $name: skipped (profile: $ACTIVE_PROFILE)"
    continue
  fi
  install_from_cache "$name" "$url" "$source"
done < <(read_manifest)

# 3. Repomix CLI (for repomix-pack skill)
echo ""
echo "[3/4] Installing repomix CLI..."
if command -v repomix >/dev/null 2>&1; then
  echo "  ~ repomix already installed"
elif command -v npm >/dev/null 2>&1; then
  npm install -g repomix >/dev/null 2>&1 && echo "  + repomix installed globally" || echo "  ! repomix install failed — run manually: npm install -g repomix"
else
  echo "  ! npm not found — install Node.js then run: npm install -g repomix"
fi

# 4. Set up self-update cache (agent-master itself; dependency repos were cached in step 2)
echo ""
echo "[4/4] Setting up auto-update cache..."
AM_CACHE="$CACHE_DIR/agent-master"
if [ -d "$AM_CACHE/.git" ]; then
  echo "  ~ cache already exists"
else
  rm -rf "$AM_CACHE"
  if clone_repo "https://github.com/Surya8991/AgentMaster.git" "$AM_CACHE"; then
    echo "  + auto-update cache initialized"
  elif [ -d "$SCRIPT_DIR/.git" ]; then
    # Offline fallback: copy the local clone (including .git so the updater can pull)
    cp -r "$SCRIPT_DIR" "$AM_CACHE"
    echo "  + auto-update cache copied from local clone"
  else
    echo "  ! could not initialize cache; the auto-updater will retry"
  fi
fi

# Done
echo ""
echo "=========================="
echo "AgentMaster installed!"
echo ""
echo "Skills installed to: $SKILLS_DIR"
echo "Total skills: $(ls -d "$SKILLS_DIR/"*/ 2>/dev/null | wc -l)"
echo ""
echo "Usage:"
echo "  /agent-master              - invoke orchestrator"
echo "  /agent-master route <task> - dry-run routing"
echo "  /agent-master status       - show current state + last sync"
echo "  /agent-master update       - force update all repos"
echo "  /agent-master doctor       - health-check installed skills"
echo "  /agent-master list         - list skills grouped by source repo"
echo "  /codereview                - blunt code review"
echo "  /caveman                   - enable token compression"
echo ""
echo "Auto-update: skills sync from repos every 6 hours on first invoke."
echo "Add repos via repos.manifest (or ~/.claude/.agentmaster-cache/repos.local)."
echo "Pin repos to exact commits via repos.pins."
echo "Start a new Claude Code session to load all skills."
