#!/usr/bin/env bash
# selftest.sh — end-to-end proof that the project-memory workflow survives
# an agent being cut off mid-task and resumed by a different agent.
#
# Scenarios exercised:
#   1. Fresh project, zero memory  -> bootstrap from scratch
#   2. Agent A starts a task and is INTERRUPTED mid-step (no warning)
#   3. Agent B (a different agent) resumes from the memory files ONLY
#   4. Memory accuracy is verified against git reality
#   5. Handoff safety: no secrets leaked into memory files
#   6. Bootstrap is idempotent; pointers are never duplicated
#
# Usage:  bash tests/selftest.sh
# Exit code 0 = all scenarios passed.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0

ok()   { echo "  PASS  $1"; PASS=$((PASS + 1)); }
bad()  { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }
check() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected '$3', got '$2')"; fi; }
contains() { if grep -qF -- "$2" "$3" 2>/dev/null; then ok "$1"; else bad "$1 — '$2' not found in $3"; fi; }
notcontains() { if grep -qF -- "$2" "$3" 2>/dev/null; then bad "$1 — '$2' leaked into $3"; else ok "$1"; fi; }

section() { echo; echo "=== $1 ==="; }

DEMO="$WORK/demo"

# ---------------------------------------------------------------------------
section "0. Build a fresh demo project (no memory, no .git)"
# ---------------------------------------------------------------------------
mkdir -p "$DEMO"

cat > "$DEMO/todo.py" <<'PY'
"""Tiny in-memory task tracker. No dependencies."""

TASKS = []


def add_task(title):
    """Append a task and return its index."""
    TASKS.append({"title": title, "done": False})
    return len(TASKS) - 1


def complete_task(index):
    """Mark the task at `index` complete. Return True if it existed."""
    raise NotImplementedError("not implemented yet")
PY

cat > "$DEMO/test_todo.py" <<'PY'
import unittest

import todo


class TestTodo(unittest.TestCase):
    def setUp(self):
        del todo.TASKS[:]

    def test_add_returns_index(self):
        self.assertEqual(todo.add_task("buy milk"), 0)
        self.assertEqual(todo.add_task("walk dog"), 1)

    def test_complete_existing(self):
        todo.add_task("buy milk")
        self.assertTrue(todo.complete_task(0))
        self.assertTrue(todo.TASKS[0]["done"])

    def test_complete_missing_returns_false(self):
        self.assertFalse(todo.complete_task(7))

    def test_complete_is_idempotent(self):
        todo.add_task("buy milk")
        todo.complete_task(0)
        self.assertTrue(todo.complete_task(0))


if __name__ == "__main__":
    unittest.main()
PY

cat > "$DEMO/README.md" <<'MD'
# demo

A tiny in-memory task tracker. Python 3, stdlib only.

## Run tests

    python3 -m unittest -v
MD

cat > "$DEMO/.env.example" <<'ENV'
# names only — never commit real values
DEMO_DB_HOST=localhost
DEMO_API_KEY=replace-me
DEMO_LOG_LEVEL=debug
ENV

(cd "$DEMO" && git init -q && git add -A \
  && git -c user.name=agent-a -c user.email=a@x.dev commit -q -m "initial demo project")

[ -f "$DEMO/.agent-memory/STATE.md" ] && bad "fresh project should have no memory" \
                                        || ok "fresh project has no .agent-memory yet"
[ -f "$DEMO/AGENTS.md" ] && bad "fresh project should have no AGENTS.md" \
                           || ok "fresh project has no instruction pointers yet"

# ---------------------------------------------------------------------------
section "1. AGENT A — bootstrap from zero"
# ---------------------------------------------------------------------------
bash "$ROOT/scripts/bootstrap.sh" "$DEMO" > "$WORK/bootstrap.log" 2>&1

for f in STATE.md PROJECT.md DECISIONS.md LOG.md DEAD_ENDS.md TODO.md; do
  [ -f "$DEMO/.agent-memory/$f" ] && ok "created .agent-memory/$f" \
                                  || bad "missing .agent-memory/$f"
done
for f in AGENTS.md CLAUDE.md GEMINI.md; do
  contains "pointer written to $f" 'read `.agent-memory/STATE.md`' "$DEMO/$f"
done

# Agent A scans the repo and fills PROJECT.md from what it actually finds.
cat > "$DEMO/.agent-memory/PROJECT.md" <<'MD'
# PROJECT

## What This Is
A tiny in-memory task tracker library used as a demo project.

## Stack
- Python 3 (stdlib only, no third-party packages)

## Architecture
Single module `todo.py` holds a module-level `TASKS` list. Each task is a
dict with `title` and `done` keys. `test_todo.py` covers the public API.

## Commands
| Action | Command |
|---|---|
| Install deps | (none — stdlib only) |
| Test | `python3 -m unittest -v` |
| Build | n/a |

## Environment Variables (names only, never values)
| Name | Purpose |
|---|---|
| DEMO_DB_HOST | demo database host |
| DEMO_API_KEY | demo API credential |
| DEMO_LOG_LEVEL | verbosity |

## Known Quirks
- `TASKS` is module-level state. `test_todo.py` clears it in `setUp()`.
- `python3 -m unittest` must be run from the repo root so `import todo` resolves.
MD

cat > "$DEMO/.agent-memory/STATE.md" <<'MD'
# STATE

## Current Task
Implement `complete_task(index)` in `todo.py` so the test suite passes.

## Status
IN_PROGRESS

## Progress So Far
- Scaffolded the demo project and committed it (`initial demo project`).
- Read `test_todo.py`; there are 4 tests, 3 of them cover `complete_task`.

## NEXT STEP (do this first)
Implement `complete_task(index)` in `demo/todo.py`, then run
`python3 -m unittest -v` from the repo root.

## Uncommitted / Half-Finished Work
None. Last commit is `initial demo project`.

## Blockers
None.
MD

printf -- '- %s | agent: agent-a | Bootstrapped .agent-memory/ from project-memory templates; filled PROJECT.md by scanning the repo.\n' \
  "2026-10-14 09:00" >> "$DEMO/.agent-memory/LOG.md"
printf -- '- %s | agent: agent-a | Started task: implement complete_task(index). STATE.md set to IN_PROGRESS.\n' \
  "2026-10-14 09:04" >> "$DEMO/.agent-memory/LOG.md"

contains "STATE.md records the next step" 'Implement `complete_task(index)` in `demo/todo.py`' "$DEMO/.agent-memory/STATE.md"

# ---------------------------------------------------------------------------
section "2. AGENT A works — and is INTERRUPTED mid-task"
# ---------------------------------------------------------------------------
# Agent A gets partway through the implementation, updates memory, then the
# session is killed with no warning. Crucially the code is NOT finished and
# NOT committed.

cat > "$DEMO/todo.py" <<'PY'
"""Tiny in-memory task tracker. No dependencies."""

TASKS = []


def add_task(title):
    """Append a task and return its index."""
    TASKS.append({"title": title, "done": False})
    return len(TASKS) - 1


def complete_task(index):
    """Mark the task at `index` complete. Return True if it existed."""
    # IN PROGRESS — agent-a ran out of credits here. Do not assume this works.
    existing = [t for t in TASKS if TASKS.index(t) == index]
    if not existing:
        return False
    existing[0]["done"] = True
    return True
PY

# Agent A's last act before dying: make STATE.md exactly true.
cat > "$DEMO/.agent-memory/STATE.md" <<'MD'
# STATE

## Current Task
Implement `complete_task(index)` in `todo.py` so the test suite passes.

## Status
IN_PROGRESS — INTERRUPTED

## Progress So Far
- Scaffolded demo, committed `initial demo project`.
- Read `test_todo.py`: 4 tests, 3 cover `complete_task`.
- Wrote a first cut of `complete_task()` in `todo.py:10` using a filtered
  list comprehension. It is WRONG: `TASKS.index(t)` compares by value, so
  duplicate task titles resolve to the wrong entry. Do not trust it.

## NEXT STEP (do this first)
Rewrite the body of `complete_task()` in `demo/todo.py` to a direct index
check — `if 0 <= index < len(TASKS): TASKS[index]["done"] = True; return True`
then `return False` — then run `python3 -m unittest -v` from the repo root.
This is the only thing blocking task completion.

## Uncommitted / Half-Finished Work
- `todo.py` — `complete_task()` is edited and BUGGY but UNCOMMITTED.
  `git status` shows ` M todo.py`. Discard it freely with
  `git checkout -- todo.py` and rewrite from scratch.
- `.agent-memory/` — updated, UNCOMMITTED.

## Blockers
None. The fix is a two-line rewrite.

## Last Updated
2026-10-14 09:31 by agent-a (interrupted)
MD

printf -- '- %s | agent: agent-a | INTERRUPTED: wrote buggy complete_task() using TASKS.index(t); fails on duplicate titles. Uncommitted.\n' \
  "2026-10-14 09:31" >> "$DEMO/.agent-memory/LOG.md"

cat >> "$DEMO/.agent-memory/DEAD_ENDS.md" <<'MD'

## DE-002
- Date: 2026-10-14
- Tried: locating the task with `[t for t in TASKS if TASKS.index(t) == index]`
- Where: todo.py, `complete_task()`
- Result: returns the wrong entry when two tasks share a title
- Why it failed: `list.index()` compares by value, not position
- Do NOT retry because: index-based access is simpler and correct
- Logged by: agent-a
MD

# --- the cut. no warning, no chance to clean up. ---------------------------
cd "$WORK"          # agent B will start somewhere else entirely
DEMO_STATE_AT_CRASH="$(cd "$DEMO" && git status --porcelain | tr '\n' ' ')"

echo "  (repo at crash: git status = '${DEMO_STATE_AT_CRASH}')"
contains "memory records the interrupted state" 'IN_PROGRESS — INTERRUPTED' "$DEMO/.agent-memory/STATE.md"
contains "memory records the bug"              'TASKS.index(t)'          "$DEMO/.agent-memory/STATE.md"
contains "memory records the uncommitted file" ' M todo.py'              "$DEMO/.agent-memory/STATE.md"
contains "dead end was logged"                 'list.index()'           "$DEMO/.agent-memory/DEAD_ENDS.md"

# ---------------------------------------------------------------------------
section "3. AGENT B — cold resume, memory files ONLY"
# ---------------------------------------------------------------------------
# Build the resume context the way a real second agent would get it: the
# contents of .agent-memory/ and nothing else. No prior conversation.

RESUME_CONTEXT="$WORK/resume-context.txt"
{
  echo "### .agent-memory/STATE.md"
  cat "$DEMO/.agent-memory/STATE.md"
  echo
  echo "### .agent-memory/PROJECT.md"
  cat "$DEMO/.agent-memory/PROJECT.md"
  echo
  echo "### .agent-memory/DECISIONS.md (tail)"
  tail -n 20 "$DEMO/.agent-memory/DECISIONS.md"
  echo
  echo "### .agent-memory/DEAD_ENDS.md (tail)"
  tail -n 25 "$DEMO/.agent-memory/DEAD_ENDS.md"
  echo
  echo "### .agent-memory/TODO.md"
  cat "$DEMO/.agent-memory/TODO.md"
  echo
  echo "### .agent-memory/LOG.md (tail)"
  tail -n 20 "$DEMO/.agent-memory/LOG.md"
} > "$RESUME_CONTEXT"

# The resume prompt must be self-sufficient. Assert it carries every fact a
# cold agent needs before we let it touch any code.
contains "resume prompt names the file"        'todo.py'              "$RESUME_CONTEXT"
contains "resume prompt names the command"     'python3 -m unittest'  "$RESUME_CONTEXT"
contains "resume prompt names the function"    'complete_task'        "$RESUME_CONTEXT"
contains "resume prompt describes the fix"     '0 <= index < len'     "$RESUME_CONTEXT"
contains "resume prompt warns of the bug"      'TASKS.index(t)'       "$RESUME_CONTEXT"

# Agent B executes exactly what the memory told it to.
cd "$DEMO"

cat > "$DEMO/todo.py" <<'PY'
"""Tiny in-memory task tracker. No dependencies."""

TASKS = []


def add_task(title):
    """Append a task and return its index."""
    TASKS.append({"title": title, "done": False})
    return len(TASKS) - 1


def complete_task(index):
    """Mark the task at `index` complete. Return True if it existed."""
    if 0 <= index < len(TASKS):
        TASKS[index]["done"] = True
        return True
    return False
PY

if python3 -m unittest -v > "$WORK/tests.log" 2>&1; then
  ok "agent B's resumed work passes the test suite"
  check "all 4 tests ran and passed" "$(grep -c ' ok$' "$WORK/tests.log")" "4"
else
  bad "agent B's resumed work fails"
  cat "$WORK/tests.log"
fi

# Agent B updates memory before doing anything else.
cat > "$DEMO/.agent-memory/STATE.md" <<'MD'
# STATE

## Current Task
Implement `complete_task(index)` in `todo.py` so the test suite passes.

## Status
DONE

## Progress So Far
- Scaffolded demo, committed `initial demo project`.
- Rewrote `complete_task()` at `todo.py:10` as a direct bounds check
  (`0 <= index < len(TASKS)`), replacing agent-a's buggy `TASKS.index()`
  approach.
- `python3 -m unittest -v` — 4 tests, all passing.

## NEXT STEP (do this first)
Commit the work: `git add todo.py .agent-memory && git commit -m "feat:
implement complete_task(index)"`. Then pick the top item in TODO.md.

## Uncommitted / Half-Finished Work
None. `todo.py` and `.agent-memory/` are clean and ready to commit.

## Blockers
None.

## Last Updated
2026-10-14 09:47 by agent-b (resumed)
MD

printf -- '- %s | agent: agent-b | RESUMED from STATE.md. Rewrote complete_task() as a bounds check; fixed the duplicate-title bug from DE-002.\n' \
  "2026-10-14 09:45" >> "$DEMO/.agent-memory/LOG.md"
printf -- '- %s | agent: agent-b | Ran python3 -m unittest -v — 4 passed, 0 failed.\n' \
  "2026-10-14 09:46" >> "$DEMO/.agent-memory/LOG.md"

cat > "$DEMO/.agent-memory/TODO.md" <<'MD'
# TODO

## Priority 1 — blocking / current

- [ ] Commit the finished `complete_task()` work.

## Priority 2 — important

- [ ] Add a `delete_task(index)` function plus tests.

## Priority 3 — nice to have

- [ ] Persist `TASKS` to disk.

## Someday / Maybe

- [ ]

## Done

- [x] 2026-10-14 Implement `complete_task(index)` and make the suite pass.
MD

(cd "$DEMO" && git add -A \
  && git -c user.name=agent-b -c user.email=b@x.dev commit -q -m "feat: implement complete_task(index)")

# ---------------------------------------------------------------------------
section "4. Verify memory against reality (what a 3rd agent would do)"
# ---------------------------------------------------------------------------
REAL_STATUS="$(cd "$DEMO" && git status --porcelain | wc -l | tr -d ' ')"
check "STATE.md says DONE matches a clean tree" "$REAL_STATUS" "0"
contains "STATE.md now says DONE" '## Status
DONE' "$DEMO/.agent-memory/STATE.md"
contains "log records the resume"  'RESUMED from STATE.md'    "$DEMO/.agent-memory/LOG.md"
contains "log names agent-b"       'agent: agent-b'          "$DEMO/.agent-memory/LOG.md"
contains "todo item checked off"   '- [x] 2026-10-14 Implement' "$DEMO/.agent-memory/TODO.md"
LAST_COMMIT="$(cd "$DEMO" && git log --oneline -1)"
case "$LAST_COMMIT" in
  *complete_task*) ok "agent B's finished work is committed" ;;
  *) bad "work was not committed (last commit: $LAST_COMMIT)" ;;
esac
COMMITTED_FILES="$(cd "$DEMO" && git show --name-only --format= HEAD)"
case "$COMMITTED_FILES" in
  *todo.py*)        ok "todo.py is in the final commit" ;;
  *)                bad "todo.py missing from the final commit" ;;
esac
case "$COMMITTED_FILES" in
  *.agent-memory/*) ok "memory travels with the code in git" ;;
  *)                bad "memory was not committed with the code" ;;
esac
contains "STATE.md gives an exact next command" 'git add todo.py .agent-memory' "$DEMO/.agent-memory/STATE.md"

# The dead end must still be there — agent B must not re-attempt it.
contains "DEAD_ENDS.md preserved across handoff" 'list.index()' "$DEMO/.agent-memory/DEAD_ENDS.md"
n_dead="$(grep -c '^## DE-' "$DEMO/.agent-memory/DEAD_ENDS.md")"
[ "$n_dead" -ge 2 ] && ok "dead ends accumulate across agents ($n_dead entries)" \
                     || bad "dead ends were lost ($n_dead entries)"

# ---------------------------------------------------------------------------
section "5. Handoff safety — no secrets"
# ---------------------------------------------------------------------------
# The demo project deliberately has a .env.example containing a fake key.
SECRET_SCAN="$WORK/secrets.txt"
for pattern in 'DEMO_API_KEY=' 'sk-' 'gho_' 'BEGIN.*PRIVATE KEY' 'password *=' 'api_key="'; do
  if grep -rqEi "$pattern" "$DEMO/.agent-memory/" 2>/dev/null; then
    echo "$pattern" >> "$SECRET_SCAN"
  fi
done
touch "$SECRET_SCAN"
check "no secret values in memory files" "$(wc -c < "$SECRET_SCAN" | tr -d ' ')" "0"
contains "env var NAMES are recorded (values not)" 'DEMO_API_KEY' "$DEMO/.agent-memory/PROJECT.md"
notcontains "the fake secret VALUE was not copied" 'replace-me' "$DEMO/.agent-memory/PROJECT.md"

# ---------------------------------------------------------------------------
section "6. Idempotency — re-bootstrap never clobbers"
# ---------------------------------------------------------------------------
cp "$DEMO/.agent-memory/STATE.md" "$WORK/state-before.md"
cp "$DEMO/AGENTS.md" "$WORK/agents-before.md"

bash "$ROOT/scripts/bootstrap.sh" "$DEMO" > "$WORK/bootstrap2.log" 2>&1

if diff -q "$WORK/state-before.md" "$DEMO/.agent-memory/STATE.md" > /dev/null; then
  ok "re-bootstrap preserved an edited STATE.md"
else
  bad "re-bootstrap overwrote STATE.md"
fi
if diff -q "$WORK/agents-before.md" "$DEMO/AGENTS.md" > /dev/null; then
  ok "re-bootstrap did not duplicate the AGENTS.md pointer"
else
  bad "re-bootstrap duplicated the AGENTS.md pointer"
fi

# Existing content must be preserved when a file already exists.
cat > "$WORK/existing" <<'MD'
# AGENTS.md

You are coding assistant X. Prefer tabs.
MD
mkdir -p "$WORK/preexisting" && cp "$WORK/existing" "$WORK/preexisting/AGENTS.md"
bash "$ROOT/scripts/bootstrap.sh" "$WORK/preexisting" > /dev/null 2>&1
contains "pre-existing AGENTS.md content kept" 'Prefer tabs.' "$WORK/preexisting/AGENTS.md"
contains "pointer appended after existing content" 'read `.agent-memory/STATE.md`' "$WORK/preexisting/AGENTS.md"

# ---------------------------------------------------------------------------
section "RESULT"
# ---------------------------------------------------------------------------
echo "  passed: $PASS"
echo "  failed: $FAIL"
echo
if [ "$FAIL" -eq 0 ]; then
  echo "ALL SCENARIOS PASSED — a cold agent can resume from memory alone."
  exit 0
fi
echo "SELFTEST FAILED"
exit 1
