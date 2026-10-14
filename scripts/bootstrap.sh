#!/usr/bin/env bash
# bootstrap.sh — create .agent-memory/ from the project-memory skill templates.
#
# The templates live at skills/project-memory/templates/, the canonical
# location for the Agent Skills spec. This script is a convenience wrapper
# so an agent can bootstrap without knowing the layout.
#
# Idempotent: safe to run repeatedly. Existing memory files are never
# overwritten. Pointer blocks are appended to AGENTS.md / CLAUDE.md / GEMINI.md
# only if they are not already present.
#
# Usage:
#   scripts/bootstrap.sh [TARGET_DIR]
#   scripts/bootstrap.sh bootstrap [TARGET_DIR]
#   npx project-memory bootstrap [TARGET_DIR]
#
# Requires: bash 3.2+, cp, grep. Nothing else.

set -euo pipefail

# Accept an optional leading "bootstrap" subcommand so the CLI reads naturally:
#   bootstrap.sh .
#   bootstrap.sh bootstrap .
#   npx project-memory bootstrap .
if [ "${1:-}" = "bootstrap" ]; then
  shift
fi

TARGET="${1:-.}"

if [ ! -d "$TARGET" ]; then
  echo "error: target directory does not exist: $TARGET" >&2
  echo "usage: bootstrap.sh [bootstrap] [TARGET_DIR]" >&2
  exit 1
fi

TARGET="$(cd "$TARGET" && pwd)"

# Resolve the real location of this script, following symlinks.
# Needed because npm installs bins as symlinks in node_modules/.bin/, and
# bash does not follow them for us in BASH_SOURCE.
SELF="${BASH_SOURCE[0]}"
while [ -L "$SELF" ]; do
  SELF_DIR="$(cd "$(dirname "$SELF")" && pwd)"
  LINK="$(readlink "$SELF")"
  case "$LINK" in
    /*) SELF="$LINK" ;;
    *)  SELF="$SELF_DIR/$LINK" ;;
  esac
done
SCRIPT_DIR="$(cd "$(dirname "$SELF")" && pwd)"

# Pre-computed directory, overridable for exotic installs.
if [ -n "${PROJECT_MEMORY_TEMPLATES:-}" ] && [ -d "${PROJECT_MEMORY_TEMPLATES}" ]; then
  TEMPLATES="${PROJECT_MEMORY_TEMPLATES}"
else
  for CANDIDATE in \
    "$SCRIPT_DIR/../skills/project-memory/templates" \
    "$SCRIPT_DIR/../templates"
  do
    if [ -d "$CANDIDATE" ]; then
      TEMPLATES="$(cd "$CANDIDATE" && pwd)"
      break
    fi
  done
fi

if [ -z "${TEMPLATES:-}" ] || [ ! -d "$TEMPLATES" ]; then
  echo "error: cannot locate the project-memory templates directory" >&2
  echo "  set PROJECT_MEMORY_TEMPLATES=/path/to/skills/project-memory/templates" >&2
  exit 1
fi

MEMORY_FILES=(STATE.md PROJECT.md DECISIONS.md LOG.md DEAD_ENDS.md TODO.md)
POINTER_FILES=(AGENTS.md CLAUDE.md GEMINI.md)

POINTER_BLOCK='## Project Memory

Before doing anything, read `.agent-memory/STATE.md` and follow the
project-memory workflow. Keep it updated as you work.'

MARKER='Before doing anything, read `.agent-memory/STATE.md`'

created=0
skipped=0

mkdir -p "$TARGET/.agent-memory"

for f in "${MEMORY_FILES[@]}"; do
  if [ -e "$TARGET/.agent-memory/$f" ]; then
    skipped=$((skipped + 1))
  else
    cp "$TEMPLATES/$f" "$TARGET/.agent-memory/$f"
    created=$((created + 1))
  fi
done

pointers_added=0
for f in "${POINTER_FILES[@]}"; do
  target_file="$TARGET/$f"
  if [ -f "$target_file" ]; then
    if grep -qF "$MARKER" "$target_file"; then
      continue
    fi
    # File exists but has no pointer: append, preserving existing content.
    printf '\n%s\n' "$POINTER_BLOCK" >> "$target_file"
  else
    # No file at all: create it with just the pointer block.
    printf '# %s\n\n%s\n' "$f" "$POINTER_BLOCK" > "$target_file"
  fi
  pointers_added=$((pointers_added + 1))
done

echo "project-memory bootstrap -> $TARGET"
echo "  memory files created: $created"
echo "  memory files already present (kept): $skipped"
echo "  pointer blocks added: $pointers_added"
echo ""
echo "Next: read $TARGET/.agent-memory/STATE.md and fill it in."
