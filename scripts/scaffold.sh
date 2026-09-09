#!/bin/bash
# AgentMaster Scaffold — detect and offer the canonical project-doc spine.
#
# The mature repos in this workspace share a 4-file spine:
#   README.md · AGENTS.md · CLAUDE.md(@AGENTS.md) · PROJECTLOG.md
# This script reports which of those the CURRENT directory is missing, and can
# create the missing ones from templates in your format.
#
# Usage:
#   bash scripts/scaffold.sh            # detect + report (no writes) — DEFAULT
#   bash scripts/scaffold.sh apply      # create missing spine files from templates
#   bash scripts/scaffold.sh apply --with-rules   # also add RULES.md
#
# Never overwrites an existing file. Accepts case/underscore variants as "present"
# (agents.md, PROJECT_LOG.md) so it won't duplicate what you already have.
set -euo pipefail

MODE="${1:-report}"
WITH_RULES=0
if [ "${2:-}" = "--with-rules" ]; then WITH_RULES=1; fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMPL_DIR="$SCRIPT_DIR/templates"
TARGET="$(pwd)"
NAME="$(basename "$TARGET")"
DATE="$(date +%F)"

# Prefer a real project name from package.json when available.
if [ -f "$TARGET/package.json" ]; then
  pj="$(grep -m1 '"name"' "$TARGET/package.json" | sed -E 's/.*"name" *: *"([^"]+)".*/\1/' || true)"
  if [ -n "$pj" ]; then NAME="$pj"; fi
fi

# present <variant...> — echoes the first found filename, or empty.
present() {
  for f in "$@"; do
    if [ -e "$TARGET/$f" ]; then echo "$f"; return; fi
  done
  echo ""
}

# detect_stack — a short human string inferred from project files, or empty.
detect_stack() {
  local s=""
  if [ -f "$TARGET/package.json" ]; then
    s="Node.js"
    if grep -q '"next"'    "$TARGET/package.json"; then s="$s / Next.js"; fi
    if grep -q '"react"'   "$TARGET/package.json"; then s="$s / React";   fi
    if grep -q '"express"' "$TARGET/package.json"; then s="$s / Express"; fi
    if grep -q '"vite"'    "$TARGET/package.json"; then s="$s / Vite";    fi
  elif [ -f "$TARGET/pyproject.toml" ] || [ -f "$TARGET/requirements.txt" ]; then s="Python"
  elif [ -f "$TARGET/go.mod" ]; then s="Go"
  elif [ -f "$TARGET/Cargo.toml" ]; then s="Rust"
  fi
  echo "$s"
}

R_README="$(present README.md readme.md)"
R_AGENTS="$(present AGENTS.md agents.md)"
R_CLAUDE="$(present CLAUDE.md)"
R_PLOG="$(present PROJECTLOG.md PROJECT_LOG.md projectlog.md)"

is_repo="no"
if [ -d "$TARGET/.git" ] || [ -f "$TARGET/package.json" ] || [ -f "$TARGET/pyproject.toml" ] || \
   [ -f "$TARGET/Cargo.toml" ] || [ -f "$TARGET/go.mod" ]; then
  is_repo="yes"
fi

row() { # label  found
  if [ -n "$2" ]; then printf "  [x] %-14s %s\n" "$1" "$2"
  else printf "  [ ] %-14s (missing)\n" "$1"; fi
}

echo "AgentMaster Scaffold — $NAME"
echo "==============================================="
echo "Directory: $TARGET   (code repo: $is_repo)"
echo
echo "Canonical doc spine:"
row "README.md"     "$R_README"
row "AGENTS.md"     "$R_AGENTS"
row "CLAUDE.md"     "$R_CLAUDE"
row "PROJECTLOG.md" "$R_PLOG"

missing=0
if [ -z "$R_README" ]; then missing=$((missing + 1)); fi
if [ -z "$R_AGENTS" ]; then missing=$((missing + 1)); fi
if [ -z "$R_CLAUDE" ]; then missing=$((missing + 1)); fi
if [ -z "$R_PLOG" ];   then missing=$((missing + 1)); fi

echo
if [ "$missing" -eq 0 ]; then
  echo "All four canonical files present. Nothing to scaffold."
  exit 0
fi

write_tmpl() { # template-basename  output-name
  local src="$TMPL_DIR/$1" dst="$TARGET/$2"
  if [ -e "$dst" ]; then echo "  skip $2 (exists)"; return; fi
  if [ ! -f "$src" ]; then echo "  ERR  template $1 not found"; return; fi
  sed -e "s/{{PROJECT_NAME}}/$NAME/g" -e "s/{{DATE}}/$DATE/g" "$src" > "$dst"
  echo "  +    $2"
}

if [ "$MODE" != "apply" ]; then
  echo "$missing file(s) missing. To create them from templates (in your format):"
  echo "    /agent-master scaffold apply"
  echo "  (adds only what's missing; never overwrites. Templates are TODO-stubbed"
  echo "   for you to fill in. Add --with-rules to also create RULES.md.)"
  exit 0
fi

echo "Creating missing files..."
if [ -z "$R_AGENTS" ]; then write_tmpl "AGENTS.md.tmpl" "AGENTS.md"; fi
if [ -z "$R_CLAUDE" ]; then write_tmpl "CLAUDE.md.tmpl" "CLAUDE.md"; fi
if [ -z "$R_PLOG" ];   then write_tmpl "PROJECTLOG.md.tmpl" "PROJECTLOG.md"; fi
if [ -z "$R_README" ]; then write_tmpl "README.md.tmpl" "README.md"; fi
if [ "$WITH_RULES" -eq 1 ]; then write_tmpl "RULES.md.tmpl" "RULES.md"; fi

# Pre-fill AGENTS.md's Stack with what we can infer, so it isn't pure TODO.
if [ -z "$R_AGENTS" ] && [ -f "$TARGET/AGENTS.md" ]; then
  stack="$(detect_stack)"
  if [ -n "$stack" ]; then
    sed -i.bak "/^## Stack$/a\\
- **Detected**: $stack  <!-- auto-detected from project files; verify & complete -->" "$TARGET/AGENTS.md"
    rm -f "$TARGET/AGENTS.md.bak"
    echo "  ~    AGENTS.md Stack pre-filled: $stack"
  fi
fi

echo
echo "Done. Fill in the TODO sections — start with AGENTS.md (Overview + Stack)"
echo "and PROJECTLOG.md (S1 Current plan · REFERENCE 1-2)."
