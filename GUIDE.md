# DevFlow — Usage Guide

Everything you need to use DevFlow correctly, start to finish.

---

## 1. What it is

DevFlow is a team of AI agents you install into a project. You give **one command**
with a plain-English request; it plans the work into Jira-like tickets, builds each
one with a specialist agent, checks the result (QA, security, code, design, tests),
fixes what's broken, and hands you a git branch. You stay in one terminal.

You don't call the agents directly — you use **slash commands** (skills). The main
one is `/ship`.

---

## 2. Install (once)

Pick one:

**A. Plugin marketplace (easiest, inside Claude Code):**
```
/plugin marketplace add ljojua1998/skills
```
then `/plugin` → **devflow** → Install.

**B. npx (any terminal):**
```
npx devflow-cc init            # into current project
npx devflow-cc init --global   # for every project on this machine
```

**C. Git clone + installer:**
```
git clone https://github.com/ljojua1998/skills.git
cd skills
.\install.ps1 -Target "C:\path\to\project"    # Windows  (add -Global for all projects)
./install.sh /path/to/project                 # macOS/Linux (add --global)
```

After installing, **restart Claude Code** so the agents load. Verify: type `/` and
you should see `ship`, `board`, `qa`, `security-audit`, `retro`.

Requirements: Claude Code, git, and (Windows) Git Bash on PATH for the quality gate.

---

## 3. The main command: `/ship`

```
/ship "describe what you want built"
```

That's the whole thing. But the flags decide how much machinery runs — **match the
flag to the task size**, this is the single most important habit.

### Modes (how much pipeline runs)

| Flag | When to use | What runs |
|---|---|---|
| `/ship --quick "..."` | tiny change: one endpoint, a component, a bug fix | 1 developer + QA only |
| `/ship "..."` (default) | normal feature, 2–4 tickets | planner + devs + QA + security |
| `/ship --full "..."` | big feature, greenfield project, production-critical | everything, all reviewers |

### Modifier flags (combine with any mode)

| Flag | Effect |
|---|---|
| `--review` | Pause after planning — you approve the plan (and the stack choice) before any code is written. **Use this on anything non-trivial.** |
| `--loop` | Keep cycling until the Definition of Done is fully met (with safety guards). For hands-off runs you trust. |
| `--budget` | Cheaper run — worker agents use a smaller model; planner/debugger stay full. |
| `--discover` | Force the 3–5 question interview before planning (auto-triggers on vague ideas). |
| `--dry-run` | Plan only — tickets land on the board, nothing gets built. Resume later. |
| `--stack <name>` | Pin the greenfield stack (e.g. `--stack nextjs --stack supabase`). Existing projects are auto-detected. |

### Resume

```
/ship resume
```
Continues an interrupted run exactly where the board says it stopped — even in a
brand-new session. Nothing is lost; all state is on disk.

---

## 4. A full worked example

You want a new app. In an empty folder (or existing repo):

```
/ship --review "Build a personal expense tracker: add/edit/delete expenses with
categories, a monthly summary chart, Next.js + Supabase, clean responsive UI"
```

What happens:

1. **Discovery** (because it's greenfield + a bit open): a few sharp questions —
   who uses it, the core flows, what's out of scope. Answer them.
2. **Plan**: the planner writes an epic + tickets to `workboard/`, picks the stack
   (Next.js + Supabase), and — because of `--review` — **stops and shows you the
   plan**. You approve, request changes, or cancel.
3. **Build**: specialist agents build each ticket in parallel where possible. After
   each one, a quality-gate hook runs typecheck/lint/tests — if red, the agent is
   sent back automatically. Each finished ticket = one git commit.
4. **Verify**: QA runs the app, security audits it, code + design reviewers check
   it. Findings are written into the tickets.
5. **Skeptic + debug**: a verifier confirms each finding is real (kills false
   alarms), then the debugger root-causes and fixes the confirmed ones, and
   re-checks.
6. **Close**: you get a final report, a `devflow/epic-001-*` branch, an offer to
   open a PR, and `/retro` saves the lessons for next time.

You review the branch and merge it yourself. DevFlow never merges or pushes without
your yes.

---

## 5. All commands

| Command | What it does |
|---|---|
| `/ship "<task>"` | The full pipeline (see modes/flags above) |
| `/ship resume` | Continue an interrupted run |
| `/board` | Live status: epics, tickets, findings, blockers |
| `/board add "<idea>"` | Add a backlog ticket without building it |
| `/qa [scope]` | Standalone functional QA pass |
| `/security-audit [scope\|full]` | Standalone OWASP/DAST security review |
| `/tests [coverage\|e2e "<flow>"\|flaky]` | Strengthen the test suite |
| `/debug-findings` | Fix findings from any review |
| `/patrol [deps\|tests\|security\|board]` | Report-only health sweep (safe to schedule) |
| `/retro [EPIC-NNN]` | Distill an epic's lessons into steering docs |
| `/devflow-update` | Pull the latest DevFlow and reinstall |

Use `/ship` for building; use the standalone ones when you want just one thing
without the whole pipeline.

---

## 6. The workboard (what gets created)

On the first `/ship`, a `workboard/` folder appears at the project root:

```
workboard/
├── BOARD.md              # the Jira board: status table + a live "Now" line + activity log
├── steering/             # the project's "constitution": tech.md, conventions.md, product.md
├── epics/EPIC-001-*.md   # goal, architecture decision, definition of done, final report
├── tickets/DEV-001-*.md  # each ticket: description, acceptance criteria, findings, debug log
└── runs/EPIC-001.md      # append-only trace of the run (phases, agents, decisions)
```

This is the single source of truth. Any new session resumes from it. You can read
these files anytime to see exactly what happened and why.

---

## 7. During a run

- **`/board`** (in another terminal or after a pause) — see live status.
- **Esc** — safely pause; state is on disk. Then `/ship resume`.
- **`/cost`** — exact token spend so far.
- DevFlow prints a short status pulse after each step (done / running / problems /
  what's next), so you're never wondering what it's doing.
- If something blocks (missing API key, ambiguous decision), it tells you
  immediately with what it needs — it doesn't hide it until the end.

---

## 8. After a run

- Work is on a `devflow/epic-NNN-*` branch — review it, then merge yourself:
  ```
  git checkout main && git merge devflow/epic-001-expense-tracker
  ```
- DevFlow offers to push + open a PR (via `gh`) — only if you say yes.
- `/retro` runs automatically on standard/full ships: it writes what it learned
  into `steering/`, so the **next** run in this project is smarter and cheaper.

---

## 9. Per-project config (optional)

Drop `.claude/devflow.json` into a project to set defaults (flags still override):

```jsonc
{
  "mode": "standard",        // quick | standard | full
  "persistence": "ask",      // ask | capped | loop
  "budget": false,           // true = worker agents on a cheaper model
  "review": false,           // true = always pause for plan approval
  "discovery": "auto",       // auto | always | never
  "stack": null,             // pin greenfield stack, e.g. "nextjs"
  "pr": "ask",               // ask | never
  "language": "en",          // report language (e.g. "ka") — board stays English
  "limits": { "maxDebugCycles": 10, "maxAgentsPerRun": 40 },
  "escalate": ["src/payments/**"]   // paths that always pause and ask you
}
```

Example: production repo → `{ "review": true, "mode": "full" }`; playground →
`{ "mode": "quick", "budget": true }`.

---

## 10. Stacks it knows

Each has a dedicated craft skill the developer agents load automatically from the
ticket's stack:

- **Frontend**: React, Vue 3, Angular
- **Full-stack**: Next.js (App Router)
- **Backend**: Express, NestJS, Python (FastAPI / Django / Flask)
- **Databases**: PostgreSQL, MySQL, MongoDB, Supabase, Firebase/Firestore
- **Mobile**: React Native, Expo, Flutter
- **3D**: Three.js, React Three Fiber
- **Infra**: Docker, CI/CD
- **QA tooling**: Postman/Newman, OWASP ZAP, nuclei, k6, JMeter

Existing projects are auto-detected; greenfield is chosen by the planner (you
confirm with `--review`).

---

## 11. Spending fewer tokens — the habits that matter

In order of impact:

1. **Match the mode to the task.** `--quick` for small work, `--full` only for big
   or critical work. This is the biggest lever by far.
2. **Add `--budget`** when you don't need top-tier quality (worker agents drop to a
   cheaper model; planner/debugger stay full).
3. **Don't force `--loop`** where a capped run finishes.
4. **Let `/retro` run** — the second run in a project reuses learned context instead
   of re-exploring.
5. Use the standalone commands (`/qa`, `/debug-findings`) instead of a full `/ship`
   when you only need one thing.

---

## 12. Troubleshooting

| Symptom | Fix |
|---|---|
| Commands don't appear (`/ship` missing) | Restart Claude Code; check `.claude/skills/` exists (or `~/.claude/` for global) |
| "quality gate DID NOT RUN" warning | Install Git Bash and add it to PATH (Windows) |
| A run seems stuck | Esc, ask "status: what's done, what's stuck?", then `/ship resume` |
| Want to see cost | `/cost` |
| Update to latest DevFlow | `/devflow-update` |

---

**One-line summary:** install once → `/ship --review "what you want"` → approve the
plan → watch `/board` → review the branch → merge. Match the flag to the task size
and let it run.
