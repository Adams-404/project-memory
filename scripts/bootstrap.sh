#!/usr/bin/env bash
# bootstrap.sh — create .agent-memory/ from the project-memory templates.
#
# Idempotent: safe to run repeatedly. Existing memory files are never
# overwritten. Pointer blocks are appended to AGENTS.md / CLAUDE.md / GEMINI.md
# only if they are not already present.
#
# Usage:
#   scripts/bootstrap.sh [TARGET_DIR]
#   scripts/bootstrap.sh /path/to/project
#
# Requires: bash 3.2+, cp, grep. Nothing else.

set -euo pipefail

TARGET="${1:-.}"
TARGET="$(cd "$TARGET" && pwd)"

SKILL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATES="$SKILL_ROOT/templates"

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
