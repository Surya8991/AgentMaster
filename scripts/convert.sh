#!/bin/bash
# AgentMaster Multi-Platform Converter
# Converts SKILL.md files to platform-specific formats
#
# Usage:
#   bash scripts/convert.sh --tool cursor|windsurf|cline|codex|gemini|antigravity|augment|opencode|aider|copilot|all

set -e

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  echo "Usage: bash scripts/convert.sh --tool <platform|all>"
  echo "Converts skills/ to platform-specific formats."
  echo "Platforms: cursor, windsurf, cline, codex, gemini, antigravity, opencode, augment, aider, copilot, all"
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SKILLS_DIR="$REPO_DIR/skills"

# Shared per-platform renderers (also used by install-platform.sh).
# shellcheck source=lib/skill-render.sh
. "$SCRIPT_DIR/lib/skill-render.sh"

# Parse arguments
TOOL="${1#--tool=}"
TOOL="${TOOL#--tool }"
[ "$1" = "--tool" ] && TOOL="$2"
[ "$1" = "--all" ] && TOOL="all"
[ -z "$TOOL" ] && TOOL="all"

# Validate --tool value
case "$TOOL" in
  cursor|windsurf|cline|codex|gemini|antigravity|opencode|augment|aider|copilot|all) ;;
  *)
    echo "Error: unknown --tool value: '$TOOL'" >&2
    echo "Valid: cursor windsurf cline codex gemini antigravity opencode augment aider copilot all" >&2
    exit 1
    ;;
esac

# Frontmatter extraction + per-platform renderers now live in lib/skill-render.sh
# (skill_field / skill_body / render_*), shared with install-platform.sh.

# Initialize aggregate format files (always regenerate — prevents stale content)
if [ "$TOOL" = "aider" ] || [ "$TOOL" = "all" ]; then
  : > "$REPO_DIR/CONVENTIONS.md"
fi
if [ "$TOOL" = "copilot" ] || [ "$TOOL" = "all" ]; then
  mkdir -p "$REPO_DIR/.github"
  : > "$REPO_DIR/.github/copilot-instructions.md"
fi

# Process each skill
for skill_dir in "$SKILLS_DIR"/*/; do
  [ ! -f "$skill_dir/SKILL.md" ] && continue
  skill_name=$(basename "$skill_dir")
  skill_file="$skill_dir/SKILL.md"

  name=$(skill_field "$skill_file" "name")
  desc=$(skill_field "$skill_file" "description")
  body=$(skill_body "$skill_file")

  echo "Converting: $skill_name"

  # ---- Claude Code (source format, already correct) ----

  # ---- Cursor (.mdc rules) ----
  if [ "$TOOL" = "cursor" ] || [ "$TOOL" = "all" ]; then
    mkdir -p "$REPO_DIR/.cursor/rules"
    render_cursor "$desc" "$body" > "$REPO_DIR/.cursor/rules/${skill_name}.mdc"
    echo "  + .cursor/rules/${skill_name}.mdc"
  fi

  # ---- Windsurf ----
  if [ "$TOOL" = "windsurf" ] || [ "$TOOL" = "all" ]; then
    mkdir -p "$REPO_DIR/.windsurf/skills/${skill_name}"
    render_windsurf "$name" "$desc" "$body" > "$REPO_DIR/.windsurf/skills/${skill_name}/SKILL.md"
    echo "  + .windsurf/skills/${skill_name}/SKILL.md"
  fi

  # ---- Cline (.clinerules) ----
  if [ "$TOOL" = "cline" ] || [ "$TOOL" = "all" ]; then
    mkdir -p "$REPO_DIR/.clinerules"
    render_cline "$body" > "$REPO_DIR/.clinerules/${skill_name}.md"
    echo "  + .clinerules/${skill_name}.md"
  fi

  # ---- Codex (OpenAI) ----
  if [ "$TOOL" = "codex" ] || [ "$TOOL" = "all" ]; then
    mkdir -p "$REPO_DIR/.codex/skills/${skill_name}"
    cp "$skill_file" "$REPO_DIR/.codex/skills/${skill_name}/SKILL.md"
    echo "  + .codex/skills/${skill_name}/SKILL.md"
  fi

  # ---- Gemini CLI ----
  if [ "$TOOL" = "gemini" ] || [ "$TOOL" = "all" ]; then
    mkdir -p "$REPO_DIR/.gemini/skills/${skill_name}"
    cp "$skill_file" "$REPO_DIR/.gemini/skills/${skill_name}/SKILL.md"
    echo "  + .gemini/skills/${skill_name}/SKILL.md"
  fi

  # ---- Antigravity ----
  if [ "$TOOL" = "antigravity" ] || [ "$TOOL" = "all" ]; then
    mkdir -p "$REPO_DIR/.antigravity/skills/${skill_name}"
    render_antigravity "$name" "$desc" "$body" > "$REPO_DIR/.antigravity/skills/${skill_name}/SKILL.md"
    echo "  + .antigravity/skills/${skill_name}/SKILL.md"
  fi

  # ---- OpenCode ----
  if [ "$TOOL" = "opencode" ] || [ "$TOOL" = "all" ]; then
    mkdir -p "$REPO_DIR/.opencode/skills/${skill_name}"
    render_opencode "$name" "$desc" "$body" > "$REPO_DIR/.opencode/skills/${skill_name}/SKILL.md"
    echo "  + .opencode/skills/${skill_name}/SKILL.md"
  fi

  # ---- Augment ----
  if [ "$TOOL" = "augment" ] || [ "$TOOL" = "all" ]; then
    mkdir -p "$REPO_DIR/.augment/rules"
    render_augment "$desc" "$body" > "$REPO_DIR/.augment/rules/${skill_name}.md"
    echo "  + .augment/rules/${skill_name}.md"
  fi

  # ---- Aider (appends to CONVENTIONS.md) ----
  if [ "$TOOL" = "aider" ] || [ "$TOOL" = "all" ]; then
    render_aider "$name" "$desc" "$body" >> "$REPO_DIR/CONVENTIONS.md"
    echo "  + CONVENTIONS.md (appended ${skill_name})"
  fi

  # ---- GitHub Copilot (appends to copilot-instructions.md) ----
  if [ "$TOOL" = "copilot" ] || [ "$TOOL" = "all" ]; then
    render_copilot "$name" "$desc" "$body" >> "$REPO_DIR/.github/copilot-instructions.md"
    echo "  + .github/copilot-instructions.md (appended ${skill_name})"
  fi

done

echo ""
echo "Conversion complete for: $TOOL"
echo "Platform files generated in repo root."
