---
name: project-memory
description: Gives any coding agent a persistent, portable, plain-markdown memory for the current project, stored in `.agent-memory/` inside the repo. Use at the START of any project work, when resuming or continuing a project, when switching to a different agent, when the user says credits are low / context is running out / asks for a handoff, or before starting a long or risky operation (big refactor, migration, bulk install). Also use whenever you need to know where a previous agent left off.
---

# project-memory

Maintain a persistent, tool-agnostic memory for this project in `.agent-memory/`
at the repo root. The memory is plain markdown, committed to git, and readable by
any agent with zero context.

You are not the only agent that will ever work on this repo. Write for the next
one. Assume it has none of your context and only your files.

**Golden rule: write continuously, never at the end.** You can be cut off at any
moment with no warning. If a step is done, the memory says so — immediately.

---

## START OF SESSION

### 1. Check for memory

```bash
ls .agent-memory/ 2>/dev/null
```

### 2a. If `.agent-memory/` EXISTS — resume

Read in this exact order:
1. `STATE.md` — read fully. This is the contract.
2. `PROJECT.md`
3. `DECISIONS.md`
4. `DEAD_ENDS.md`
5. `TODO.md`
6. `LOG.md` — only the tail (last ~20 entries)

Then, in one or two lines, tell the user where things stand: current task,
status, and the next step. Continue from the next step.

Do not redo finished work. Do not re-propose a rejected decision. Do not retry a
logged dead end. If you disagree with the memory, say so explicitly to the user
before overriding it.

### 2b. If `.agent-memory/` DOES NOT EXIST — bootstrap

1. Scan the repo: entry points, package/app manifest files, config, test setup,
   README, CI, `.env.example` (names only), `git log`.
2. Copy every file from `templates/` into a new `.agent-memory/`.
3. Fill `PROJECT.md` from what you actually found. Leave unknowns blank — do
   not guess. Mark unverified fields with `UNVERIFIED`.
4. Write an initial `STATE.md`: current task = what the user just asked for,
   status = `NOT_STARTED`, next step = the first concrete action.
5. Add pointer blocks to `AGENTS.md`, `CLAUDE.md`, and `GEMINI.md` (see
   CROSS-AGENT DISCOVERY below).
6. Append the first `LOG.md` entry.
7. Commit the scaffolding.

### 3. Verify memory against reality — always, on every session

```bash
git status
git log --oneline -15
```

If the memory disagrees with the code, **trust the code** and fix the memory
immediately. Specifically check:
- Does `STATE.md` claim work is done that `git log` does not show? Correct it.
- Does it list uncommitted files that no longer exist? Remove them.
- Does the task in `STATE.md` match what the user is now asking for?
- Was check-off in `TODO.md` claimed without a corresponding commit? Verify.

---

## DURING WORK

### After every meaningful step

A meaningful step = finished a function, fixed a bug, changed approach, wrote a
test, resolved a blocker, or decided something. Do it after each one, not in
batches.

1. Update `STATE.md`:
   - refresh `Progress So Far`
   - recompute `NEXT STEP` — always exactly one action
   - update `Status`
   - update `Last Updated`
2. Append one line to `LOG.md`.
3. If a decision was made → append to `DECISIONS.md` (see below).
4. If an approach failed → append to `DEAD_ENDS.md` immediately.
5. Check off any finished item in `TODO.md`.

### Rules for good entries

- Include file paths, function names, and exact commands.
- BAD: "worked on auth". GOOD: "Added `requireAdmin()` middleware to
  `src/api/routes/admin.ts:34`; registered in `routes/admin.ts`."
- One line per `LOG.md` entry. Keep it to what changed, not how you felt.
- Write as if the reader is a different agent with zero context.

### DECISIONS.md

Append the moment a decision is made. Every entry MUST have:
- the decision
- the reason
- the alternatives rejected, and why each was rejected

A decision without a reason will be re-litigated by the next agent. Never
rewrite old entries; supersede them with a new numbered entry.

### DEAD_ENDS.md

Append the moment an approach fails — before you move on, while you still
remember the details. If you spent more than ~10 minutes on something that did
not work, it belongs here.

### Before any long or risky operation

Before starting a big refactor, a migration, a bulk install, a dependency
upgrade, or anything that could leave the repo in a broken intermediate state:

1. Write in `STATE.md` under `Recovery Plan`:
   - what is about to happen
   - the exact command(s) you will run
   - how to detect if it was interrupted
   - the exact command to undo or recover
2. Ensure the working tree is committed first, or note exactly what is dirty.
3. When the operation completes cleanly, delete the `Recovery Plan` section.

---

## HANDOFF SAFETY

- **Never write secrets.** No API keys, tokens, passwords, connection strings,
  or `.env` values in any memory file. Record env var NAMES only.
- **Assume a cold reader.** Another agent, another tool, zero conversation
  history. Everything it needs must be in the files.
- **Keep the working tree recoverable.** Prefer small commits over one big one.
  Never leave the repo in a state you have not documented.
- When the user says credits are low, asks to switch agents, or asks for a
  handoff, do a FINAL PASS:

  1. Make `STATE.md` exactly true — status, progress, uncommitted work, blockers.
  2. Write the `NEXT STEP` as the exact next command or the exact file to open.
     Not a goal. An instruction.
  3. Append the final `LOG.md` entries.
  4. Re-read `STATE.md` once and delete anything stale.
  5. Suggest to the user:
     ```
     git add .agent-memory && git add <work files> && git commit -m "wip: <task>"
     ```
  6. Tell the user which file the next agent should read first.

---

## CROSS-AGENT DISCOVERY

Agents that do not support skills read a different instruction file each. Ensure
these exist and contain the pointer block. **Append only — never overwrite
existing content, and never add the block twice.**

`AGENTS.md` (Codex, OpenCode, and others)
`CLAUDE.md` (Claude Code)
`GEMINI.md` (Gemini-based tools / Agy)

Pointer block to append:

```markdown
## Project Memory

Before doing anything, read `.agent-memory/STATE.md` and follow the
project-memory workflow. Keep it updated as you work.
```

---

## MEMORY FILES

| File | Purpose | Update frequency |
|---|---|---|
| `STATE.md` | Current task, status, single next step, half-finished work | After every meaningful step |
| `PROJECT.md` | Stack, architecture, commands, env var names, quirks | When the project shape changes |
| `DECISIONS.md` | Decisions + reasons + rejected alternatives | At the moment of the decision |
| `LOG.md` | Append-only timestamped transcript, newest at bottom | After every meaningful step |
| `DEAD_ENDS.md` | Failed approaches and why they failed | Immediately on failure |
| `TODO.md` | Prioritized backlog, done items checked off | As items are added/finished |

Commit `.agent-memory/` with the code. It is part of the project, not a scratchpad.
