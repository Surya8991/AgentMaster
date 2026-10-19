#!/bin/bash
# AgentMaster Platform Installer
# Detects or accepts target platform and installs skills to the right location.
#
# Usage:
#   bash scripts/install-platform.sh                    # auto-detect
#   bash scripts/install-platform.sh --platform cursor   # specific platform
#   bash scripts/install-platform.sh --platform all      # install to all detected platforms
# Note: aider and copilot use aggregate files — run: bash scripts/convert.sh --tool aider|copilot

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SKILLS_DIR="$REPO_DIR/skills"

# Shared frontmatter extraction + per-platform renderers (also used by convert.sh).
# shellcheck source=lib/skill-render.sh
. "$SCRIPT_DIR/lib/skill-render.sh"

PLATFORM="${1#--platform=}"
PLATFORM="${PLATFORM#--platform }"
[ "$1" = "--platform" ] && PLATFORM="$2"

# Platform detection
detect_platforms() {
  local found=()
  [ -d "$HOME/.claude" ] && found+=("claude-code")
  if [ -d "$HOME/.cursor" ] || [ -d ".cursor" ]; then found+=("cursor"); fi
  if [ -d "$HOME/.windsurf" ] || [ -d ".windsurf" ]; then found+=("windsurf"); fi
  if [ -d "$HOME/.cline" ] || [ -d ".clinerules" ]; then found+=("cline"); fi
  [ -d "$HOME/.codex" ] && found+=("codex")
  [ -d "$HOME/.gemini" ] && found+=("gemini")
  [ -d "$HOME/.antigravity" ] && found+=("antigravity")
  [ -d "$HOME/.opencode" ] && found+=("opencode")
  [ -d "$HOME/.augment" ] && found+=("augment")
  echo "${found[@]}"
}

install_skills() {
  local platform="$1"
  local target_dir=""
  local format="copy" # copy = direct copy, convert = needs frontmatter change

  case "$platform" in
    claude-code)
      target_dir="$HOME/.claude/skills"
      format="copy"
      ;;
    codex)
      target_dir="$HOME/.codex/skills"
      format="copy"
      ;;
    gemini)
      target_dir="$HOME/.gemini/skills"
      format="copy"
      ;;
    antigravity)
      target_dir="$HOME/.antigravity/skills"
      format="antigravity"
      ;;
    opencode)
      target_dir="$HOME/.opencode/skills"
      format="opencode"
      ;;
    cursor)
      target_dir=".cursor/rules"
      format="cursor"
      ;;
    windsurf)
      target_dir=".windsurf/skills"
      format="windsurf"
      ;;
    cline)
      target_dir=".clinerules"
      format="cline"
      ;;
    augment)
      target_dir=".augment/rules"
      format="augment"
      ;;
    aider|copilot)
      echo "  ! '$platform' uses aggregate files, not platform dirs."
      echo "    Use: bash scripts/convert.sh --tool $platform"
      return 1
      ;;
    *)
      echo "  ! Unknown platform: $platform"
      return 1
      ;;
  esac

  mkdir -p "$target_dir"

  for skill_dir in "$SKILLS_DIR"/*/; do
    [ ! -f "$skill_dir/SKILL.md" ] && continue
    skill_name=$(basename "$skill_dir")
    local sf="$skill_dir/SKILL.md" name desc body
    name=$(skill_field "$sf" name)
    desc=$(skill_field "$sf" description)
    body=$(skill_body "$sf")

    case "$format" in
      copy)
        mkdir -p "$target_dir/$skill_name"
        cp "$sf" "$target_dir/$skill_name/SKILL.md"
        ;;
      cursor)
        render_cursor "$desc" "$body" > "$target_dir/${skill_name}.mdc"
        ;;
      windsurf)
        mkdir -p "$target_dir/$skill_name"
        render_windsurf "$name" "$desc" "$body" > "$target_dir/$skill_name/SKILL.md"
        ;;
      cline)
        render_cline "$body" > "$target_dir/${skill_name}.md"
        ;;
      antigravity)
        mkdir -p "$target_dir/$skill_name"
        render_antigravity "$name" "$desc" "$body" > "$target_dir/$skill_name/SKILL.md"
        ;;
      opencode)
        mkdir -p "$target_dir/$skill_name"
        render_opencode "$name" "$desc" "$body" > "$target_dir/$skill_name/SKILL.md"
        ;;
      augment)
        render_augment "$desc" "$body" > "$target_dir/${skill_name}.md"
        ;;
    esac

    echo "  + $skill_name → $target_dir"
  done
}

# Main
echo "AgentMaster Platform Installer"
echo "=============================="
echo ""

if [ -z "$PLATFORM" ]; then
  echo "Detecting platforms..."
  DETECTED=$(detect_platforms)
  if [ -z "$DETECTED" ]; then
    echo "No supported platforms detected. Use --platform <name> to specify."
    echo "Supported: claude-code, cursor, windsurf, cline, codex, gemini, antigravity, opencode, augment"
    exit 1
  fi
  echo "Found: $DETECTED"
  echo ""
  for p in $DETECTED; do
    echo "[$p]"
    install_skills "$p"
    echo ""
  done
elif [ "$PLATFORM" = "all" ]; then
  for p in claude-code cursor windsurf cline codex gemini antigravity opencode augment; do
    echo "[$p]"
    install_skills "$p"
    echo ""
  done
else
  echo "[$PLATFORM]"
  install_skills "$PLATFORM"
fi

echo "=============================="
echo "Done! Restart your IDE/agent to load skills."
