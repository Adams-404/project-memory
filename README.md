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

### Option 1 — the skills CLI (recommended)

Every npm-based agent skill installer discovers skills at
`skills/<name>/SKILL.md`, which is exactly the layout this repo uses.

**Install from GitHub, globally, for OpenCode:**

```bash
npx skills add Adams-404/project-memory -a opencode -g -y
```

Land at `~/.agents/skills/project-memory/` — an OpenCode global discovery path.
The `templates/` directory ships inside the skill, so the installed copy is
self-contained and can bootstrap a project with no source repo present.

**Install for several agents at once:**

```bash
npx skills add Adams-404/project-memory -a opencode -a claude-code -a codex -g -y
```

**Project-local instead of global** (drop `-g`, gets committed with your repo):

```bash
npx skills add Adams-404/project-memory -a opencode -y
```

**Alternative installer** — `agent-install` works the same way and accepts a
local path, so you can also install straight from a clone:

```bash
npx agent-install@latest skill add Adams-404/project-memory --agent opencode --global -y
# or from a local checkout:
npx agent-install@latest skill add /path/to/project-memory --agent opencode --global -y
```

It symlinks or copies into each agent's skills directory (`copy` mode by
default; `--copy` forces a copy).

**Useful flags on both:**

| Flag | Meaning |
|---|---|
| `-a, --agent <id>` | Target agent: `opencode`, `claude-code`, `codex`, `cursor`, `gemini-cli`, … |
| `-g, --global` | Install to the user-level directory instead of the project |
| `-s, --skill <name>` | Install specific skills from a multi-skill repo |
| `-l, --list` | List what's available without installing |
| `--copy` | Copy files instead of symlinking |
| `-y, --yes` | Skip prompts (CI-friendly) |

Run `npx skills --help` for the full list of supported agents.

---

### Option 2 — npm package

The package is published under the scoped name, and ships the skills under
the conventional `skills/` directory so `skillpm` / `npm-skills` / `skills-npm`
pick it up automatically:

```bash
npm install -g @adams-404/project-memory
```

Or one-shot without installing:

```bash
npx @adams-404/project-memory bootstrap /path/to/your-project
```

`skillpm install @adams-404/project-memory` and
`npm-skills extract @adams-404/project-memory` both work too — they scan
`node_modules` for `skills/*/SKILL.md`.

---

### Option 3 — manual (no npm, no network)

```bash
# global, OpenCode
cp -r skills/project-memory ~/.config/opencode/skills/

# or symlink so edits to this repo apply everywhere
ln -s ~/Projects/project-memory/skills/project-memory ~/.config/opencode/skills/project-memory

# Claude Code
cp -r skills/project-memory ~/.claude/skills/

# universal (.agents/skills is read by most agents)
cp -r skills/project-memory ~/.agents/skills/
```

---

### Bootstrap a project (all agents)

Once the skill is installed, an agent can self-bootstrap. Or you can do it by
hand from inside the target project:

```bash
bash /path/to/project-memory/scripts/bootstrap.sh .
# or, if the npm package is installed:
npx @adams-404/project-memory bootstrap .
```

This is idempotent. It creates `.agent-memory/` from the templates, never
overwriting anything already there, and appends pointer blocks to
`AGENTS.md`, `CLAUDE.md`, and `GEMINI.md` — only if they're not already
present.

### Pointer files (the part that makes it work without skills)

Not every agent can load a skill. Every agent reads *some* instruction file,
so `bootstrap.sh` writes the pointer block into all three:

```markdown
## Project Memory

Before doing anything, read `.agent-memory/STATE.md` and follow the
project-memory workflow. Keep it updated as you work.
```

Nothing is ever overwritten — pointers are only appended when missing.

---

### Claude Code

Claude Code reads `CLAUDE.md`. The bootstrap script writes the pointer there,
so Claude finds the memory at session start. Optionally also install the skill
itself:

```bash
npx skills add Adams-404/project-memory -a claude-code -g -y
```

Global fallback — append the pointer block to `~/.claude/CLAUDE.md`.

---

### Codex

Codex reads `AGENTS.md`, which the bootstrap script updates.

```bash
npx skills add Adams-404/project-memory -a codex -g -y
```

---

### Agy / Gemini-based tools

These read `GEMINI.md`, which the bootstrap script updates.

```bash
npx skills add Adams-404/project-memory -a gemini-cli -g -y
```

---

### Any other agent

Same bootstrap command. Pointers go to all three instruction files, and
`.agent-memory/` is always created. If your agent reads none of them, tell it
once:

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
├── README.md
├── LICENSE                             # MIT
├── package.json                       # npm distribution (skills/ convention)
├── skills/
│   └── project-memory/                # the skill — self-contained
│       ├── SKILL.md                    # Agent Skills frontmatter + workflow
│       └── templates/                  # memory file starters
│           ├── STATE.md
│           ├── PROJECT.md
│           ├── DECISIONS.md
│           ├── LOG.md
│           ├── DEAD_ENDS.md
│           ├── TODO.md
│           └── AGENTS.md  CLAUDE.md  GEMINI.md   # pointer blocks
├── scripts/
│   └── bootstrap.sh                   # Idempotent setup + pointer injection
└── tests/
    └── selftest.sh
```

`skills/project-memory/` is the canonical skill directory and what gets
installed by `npx skills` / `agent-install` / `skillpm`. It carries its own
`templates/`, so an installed copy can bootstrap a project on its own.

---

## License

MIT. Copy it, fork it, put it in every project you have.
