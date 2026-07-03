#!/bin/bash
# AgentMaster Installer
# Clones dependency repos into the auto-update cache and copies skills to ~/.claude/skills/

set -e

SKILLS_DIR="$HOME/.claude/skills"
CACHE_DIR="$HOME/.claude/.agentmaster-cache"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  echo "Usage: bash install.sh"
  echo "Installs AgentMaster skills + 5 dependency repos to ~/.claude/skills/"
  exit 0
fi

echo "AgentMaster Installer v1.2"
echo "=========================="
echo ""

mkdir -p "$SKILLS_DIR" "$CACHE_DIR"

clone_repo() {
  # clone_repo <url> <dest> — depth-1 clone with an explicit failure message
  if ! git clone --depth 1 --quiet "$1" "$2" 2>/dev/null; then
    echo "  ! clone failed: $1"
    return 1
  fi
}

install_from_cache() {
  # install_from_cache <name> <url> <skill_source> <summary>
  # Clone into the auto-update cache (if needed) and copy skills from there, so the
  # installer and updater share one clone per repo and the first update is instant.
  local name="$1" url="$2" skill_source="$3" summary="$4"
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
  for skill_dir in "$src"/*/; do
    [ ! -d "$skill_dir" ] && continue
    local skill_name
    skill_name=$(basename "$skill_dir")
    if [ -f "$skill_dir/SKILL.md" ] || [ "$skill_source" = "skills" ]; then
      cp -r "$skill_dir" "$SKILLS_DIR/$skill_name"
    fi
  done
  echo "  + $summary"
}

# 1. Install custom skills (agent-master, codereview, devops, security-audit, repomix-pack)
echo "[1/7] Installing custom skills..."
for skill_dir in "$SCRIPT_DIR/skills/"*/; do
  skill_name=$(basename "$skill_dir")
  if [ -f "$skill_dir/SKILL.md" ]; then
    cp -r "$skill_dir" "$SKILLS_DIR/$skill_name"
    echo "  + $skill_name"
  fi
done

# 2. Caveman (token compression)
echo ""
echo "[2/7] Installing caveman (token compression)..."
install_from_cache "caveman" "https://github.com/JuliusBrussee/caveman.git" "skills" \
  "caveman, caveman-commit, caveman-review, caveman-help, compress"

# 3. Superpowers (dev workflow)
echo ""
echo "[3/7] Installing superpowers (dev workflow)..."
install_from_cache "superpowers" "https://github.com/obra/superpowers.git" "skills" \
  "brainstorming, writing-plans, test-driven-development, systematic-debugging, ..."

# 4. Claude-skills (domain expertise)
echo ""
echo "[4/7] Installing claude-skills (domain expertise)..."
install_from_cache "claude-skills" "https://github.com/alirezarezvani/claude-skills.git" "." \
  "engineering-team, marketing-skill, product-team, c-level-advisor, ..."

# 5. Claude-mem (session memory) - skills only
echo ""
echo "[5/7] Installing claude-mem skills (session memory)..."
install_from_cache "claude-mem" "https://github.com/thedotmack/claude-mem.git" "plugin/skills" \
  "mem-search, smart-explore, knowledge-agent, make-plan, do, timeline-report, version-bump"

# 6. Repomix CLI (for repomix-pack skill)
echo ""
echo "[6/7] Installing repomix CLI..."
if command -v repomix >/dev/null 2>&1; then
  echo "  ~ repomix already installed"
elif command -v npm >/dev/null 2>&1; then
  npm install -g repomix >/dev/null 2>&1 && echo "  + repomix installed globally" || echo "  ! repomix install failed — run manually: npm install -g repomix"
else
  echo "  ! npm not found — install Node.js then run: npm install -g repomix"
fi

# 7. Set up self-update cache (agent-master itself; dependency repos were cached in steps 2-5)
echo ""
echo "[7/7] Setting up auto-update cache..."
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
echo "  /agent-master status       - show current state"
echo "  /agent-master update       - force update all repos"
echo "  /codereview                - blunt code review"
echo "  /caveman                   - enable token compression"
echo ""
echo "Auto-update: skills sync from repos every 6 hours on first invoke."
echo "Pin dependency repos to exact commits via repos.pins (see repo root)."
echo "Start a new Claude Code session to load all skills."
