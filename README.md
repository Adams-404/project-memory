# project-memory

A reusable agent skill that gives any coding agent a **persistent, portable memory** for your project.

When one agent runs out of credits, a different agent — Agy, OpenCode, Codex, Claude Code, Gemini — opens the same repo and continues **exactly where the last one stopped.**

Everything is plain markdown committed to your repo. No databases, no tool-specific formats, no dependencies.

---

## Why

Coding agents have two problems:

1. **They forget between sessions.** Context windows reset, and nothing carries over.
2. **They die mid-task.** Credits run out, sessions get cut, and the work in progress is undocumented.

`.agent-memory/` fixes both. It lives inside the project, committed to git, so it travels with the code. Any agent with any tool can read it and continue.

---

## What's in the memory

```
.agent-memory/
├── STATE.md        # The contract. Current task, status, the ONE next step,
│                   # and any uncommitted/half-finished work.
│                   # A cold agent reads only this and knows what to do.
├── PROJECT.md      # Stack, architecture, folder layout, run/build/test/deploy
│                   # commands, env var NAMES (never values), known quirks.
├── DECISIONS.md    # Each decision + the reason + alternatives rejected.
├── LOG.md          # Append-only timestamped transcript. Newest at the bottom.
├── DEAD_ENDS.md    # What was tried and failed, and why. Don't repeat it.
└── TODO.md         # Prioritized backlog. Done items checked off, not deleted.
```

**`STATE.md` is the important one.** It must always be true, and it must name exactly one next action.

---

## Install

### Any project (bootstrap from zero)

Run this from inside the target project:

```bash
bash /path/to/project-memory/scripts/bootstrap.sh .
```

This is idempotent. It creates `.agent-memory/` from the templates, never overwriting anything already there, and appends pointer blocks to `AGENTS.md`, `CLAUDE.md`, and `GEMINI.md` — only if they're not already present.

---

### OpenCode

Two options — do both for best coverage.

**As a skill (auto-triggered):**

```bash
# copy, clone, or symlink this folder into your global skills directory
cp -r project-memory ~/.config/opencode/skills/
```

Or keep it in one place and symlink:

```bash
ln -s ~/Projects/project-memory ~/.config/opencode/skills/project-memory
```

The skill now triggers automatically at the start of any project work.

**As an always-on instruction (belt and braces):**

Add the pointer block to `~/.config/opencode/AGENTS.md`, or keep the per-project `AGENTS.md` the bootstrap script creates.

---

### Claude Code

Claude Code doesn't load external skills, so use the pointer file:

```bash
bash /path/to/project-memory/scripts/bootstrap.sh /path/to/your-project
```

This creates `.agent-memory/` and writes the pointer into `CLAUDE.md`. Claude reads `CLAUDE.md` at the start of every session, so it will find the memory automatically.

Global fallback — append the block below to `~/.claude/CLAUDE.md`.

---

### Codex

```bash
bash /path/to/project-memory/scripts/bootstrap.sh /path/to/your-project
```

Codex reads `AGENTS.md`, which now contains the pointer.

---

### Agy / Gemini-based tools

```bash
bash /path/to/project-memory/scripts/bootstrap.sh /path/to/your-project
```

These read `GEMINI.md`, which now contains the pointer.

---

### Any other agent

Same command. Pointers are written to all three files, and the bootstrap always produces `.agent-memory/`. If your agent reads none of them, tell it once:

> Read `.agent-memory/STATE.md` and follow the project-memory workflow. Keep it updated as you work.

---

## Usage

### Starting a session

The agent checks whether `.agent-memory/` exists.

**If it exists** — it reads `STATE.md` first, then `PROJECT.md`, `DECISIONS.md`, `DEAD_ENDS.md`, `TODO.md`, and the tail of `LOG.md`. Then it tells you where things stand and continues from the next step. It does not redo finished work.

**If it doesn't** — it scans the repo, bootstraps `.agent-memory/`, fills `PROJECT.md` from what it finds, and sets an initial `STATE.md`.

Either way it then checks `git status` and recent commits. **If the notes disagree with the code, it trusts the code and fixes the notes.**

### During work

After every meaningful step — a finished function, a fixed bug, a changed approach — the agent:

- updates `STATE.md` (never in batches, never at the end)
- appends a one-line entry to `LOG.md`
- records decisions in `DECISIONS.md` the moment they're made
- records failed approaches in `DEAD_ENDS.md` immediately
- checks off finished items in `TODO.md`

Before any long or risky operation (big refactor, migration, bulk install), it writes a **Recovery Plan** into `STATE.md`: what's about to happen and how to undo it if interrupted.

### When credits run low / handing off

Say *"credits are low"* or *"hand off"*. The agent does a final pass:

1. makes `STATE.md` exactly true — status, progress, uncommitted work, blockers
2. writes the next step as the exact next command or file to open, not a goal
3. suggests committing the work plus the memory folder

```bash
git add .agent-memory && git add <your work files> && git commit -m "wip: <task>"
```

Then the next agent reads `.agent-memory/STATE.md` and picks it up.

---

## Rules baked into the skill

- **Never store secrets.** Env var *names* only — never values, keys, or tokens.
- **Write for a cold reader.** A different agent with zero context.
- **Be specific.** File paths, function names, exact commands. `"Add requireAdmin() to src/api/routes/admin.ts:34"`, never `"worked on auth"`.
- **One next step in STATE.md.** Not a goal. An instruction.
- **Never overwrite an existing pointer file.** Append only.
- **Commit `.agent-memory/` with the code.** It is part of the project, not a scratchpad.

---

## Self-test

Proof that a cold agent can resume from the memory alone:

```bash
bash tests/selftest.sh
```

It builds a throwaway project with no memory, walks the full lifecycle — bootstrap, mid-task interruption with a buggy uncommitted change, resume from nothing but the memory files, verify against git, secrets scan, idempotency — and runs 41 assertions. Exits 0 on success.

---

## Layout

```
project-memory/
├── SKILL.md                      # The skill: agent-facing, imperative
├── README.md
├── LICENSE                       # MIT
├── scripts/
│   └── bootstrap.sh              # Idempotent setup + pointer injection
├── templates/
│   ├── STATE.md
│   ├── PROJECT.md
│   ├── DECISIONS.md
│   ├── LOG.md
│   ├── DEAD_ENDS.md
│   ├── TODO.md
│   └── AGENTS.md  CLAUDE.md  GEMINI.md   # pointer blocks
└── tests/
    └── selftest.sh
```

---

## License

MIT. Copy it, fork it, put it in every project you have.
