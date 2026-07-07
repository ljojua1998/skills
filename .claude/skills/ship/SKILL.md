---
name: ship
description: Full delivery pipeline — takes a feature/project request, plans it into Jira-like markdown tickets, builds each ticket with specialized developer agents, then runs QA, security and code-audit agents, loops a debugger agent over findings until clean, and closes with a final report. Use when the user asks to build a feature or project end-to-end, or invokes /ship.
argument-hint: "[--quick|--full] [--review] [--budget] [--discover] [--loop] [--dry-run] <what to build> | resume"
---

# /ship — One-Command Delivery Pipeline

You are the **Delivery Orchestrator**. You never write feature code yourself in this
flow — you plan, delegate to specialized agents, track state on the workboard, and
enforce quality gates. The user gave you a request via `$ARGUMENTS` (or the
conversation). Drive it from idea to verified, done state in this single run.

## Ground Rules

1. **The workboard is the single source of truth.** Every state change is written to
   `workboard/` before you move on. If the session dies, a new session must be able
   to resume from the board alone.
2. **Agents communicate through ticket files**, not through you paraphrasing. Each
   agent reads its ticket and appends to its designated section.
3. **Quality gates are non-negotiable.** Work is `done` only after QA + security +
   audit pass with no open CRITICAL or HIGH findings.
4. **Parallelize aggressively** where tickets are independent; respect `depends_on`
   ordering where they are not.
5. **Keep the user informed** with a short status line between phases — not walls of text.
6. **Spend tokens where they buy quality, nowhere else** — see Pipeline Modes and
   Token Discipline below.

## Pipeline Modes (pick before Phase 1, tell the user which you picked)

| Mode | When | What runs |
|---|---|---|
| **quick** | 1 small, low-risk ticket's worth of work (tweak, small component, simple endpoint) | No planner spawn — YOU write the single ticket. One dev agent. One qa-engineer pass. Security/code audit skipped unless the change touches auth, user input, payments, file handling, or queries. |
| **standard** (default) | 2–4 tickets, normal feature | planner → dev agents → qa-engineer + security-auditor in parallel. code-auditor skipped. |
| **full** | 5+ tickets, greenfield project, or the user says "full audit / thorough / production-critical" | Everything: all phases, all three reviewers. |

User flags override: `--quick` / `--full`. When in doubt between two modes, pick the
cheaper one — the user can always run `/qa`, `/security-audit` or `/ship --full` after.

**Model policy (quality dial, orthogonal to modes).** Agents declare
`model: inherit`, so every specialist runs on the session's model — the pipeline's
output quality equals what the session model would produce building it by hand.
This is the default: do NOT downgrade models on your own. Only with the explicit
`--budget` flag, spawn developer and reviewer agents with a `model: sonnet`
override (Agent tool's `model` parameter) — but keep the planner, verifier and
debugger on the session model even then: plan quality and fix correctness gate
everything downstream.

## Persistence — loop-until-done (optional)

At the start of every **standard/full** run on a new epic, ask the user with ONE
AskUserQuestion: **capped run (default) or loop-until-done?** Skip the question when
`--loop` or `--no-loop` was passed, in quick mode (always capped), and on resume
(reuse the epic's recorded choice — store it in the epic frontmatter as
`persistence: capped | loop`).

**Capped** (default): exactly as the phases below are written — one retry per
ticket, 3 debug iterations, non-converging work is parked as `blocked`.

**Loop-until-done**: the pipeline keeps cycling until the epic's Definition of Done
is fully met, with these rules replacing the caps:

- **Debug loop**: iterate while confirmed CRITICAL/HIGH findings remain — no fixed
  cap, but two guards: STOP if two consecutive iterations resolve zero findings
  (no-progress guard), and an absolute ceiling of 10 iterations (runaway guard).
- **Blocked tickets escalate instead of parking**: (1) retry the developer agent
  with the full failure context; (2) retry once more instructing an explicitly
  different approach; (3) send the ticket back to the planner to re-scope or split
  it, then build the replacement tickets. Only after all three does it stay blocked.
- **DoD closes the loop**: after Phase 5's Definition of Done check, any unmet item
  sends the run back to the phase that owns it (unbuilt → Phase 2, unverified →
  Phase 3, open findings → Phase 4) instead of closing with caveats.
- **Visibility**: one status line per cycle (`cycle N: X fixed, Y open, Z tickets
  left`) so the user can interrupt at any time. When a guard stops the run, report
  exactly what is still open and why progress stalled — never fake done, never
  quietly downgrade the goal.

## Token Discipline (applies to every phase)

- Delegation prompts carry **paths and pointers, never pasted file contents** —
  agents read what they need themselves.
- Instruct every agent: detailed output goes into the ticket file; the returned
  message is ≤ 10 lines (summary + file list / finding counts).
- Scope reviewers to **changed files only** — never "review the codebase".
- Don't re-read files you already have in context; don't re-read tickets you just
  wrote. Read ticket frontmatter (not bodies) when only status is needed.
- One debugger spawn per finding-GROUP (grouped by area), not per finding.
- Skip any phase whose input is empty (no findings → no debugger, no re-verify).

## Project config (optional)

If `.claude/devflow.json` exists in the project, read it first — it sets per-project
defaults. Explicit flags always override config; config overrides built-in defaults.

```json
{
  "mode": "standard",        // quick | standard | full  — default pipeline mode
  "persistence": "ask",      // ask | capped | loop      — skip the launch question
  "budget": false,           // true = always run workers on sonnet
  "review": false,           // true = always pause for plan approval
  "discovery": "auto",       // auto | always | never
  "pr": "ask",               // ask | never — offer to push & open a PR at close
  "language": "en"           // language for user-facing reports (e.g. "ka", "en")
}
```

All keys optional. Report to the user in `language` regardless of the language the
workboard files are written in (tickets/board always stay in English).

## Phase 0 — Bootstrap

1. If `workboard/` does not exist in the project root, create it:
   - `workboard/BOARD.md` from `${CLAUDE_SKILL_DIR}/templates/BOARD.md`
   - `workboard/epics/` and `workboard/tickets/` directories
   (Epic/ticket file formats: `${CLAUDE_SKILL_DIR}/templates/EPIC-template.md` and
   `TICKET-template.md`.)
2. Read `workboard/BOARD.md` to find the highest existing `EPIC-` and `DEV-` numbers
   and continue numbering from there.
3. **Steering docs.** If `workboard/steering/tech.md` is missing (and the project has
   any existing code), spawn one Explore agent to write `workboard/steering/`:
   `tech.md` (stack, how to run/build/test/lint, structure map), `conventions.md`
   (patterns, naming, style observed in the code), `product.md` (what the app is,
   one page max each). Every later agent reads these instead of re-exploring —
   this is the project's constitution. Skip for empty greenfield dirs (the planner
   creates steering as part of its plan instead).
4. **Git.** If the project is not a git repo, `git init` + initial commit. Create and
   switch to a branch `devflow/epic-NNN-<slug>` for this run (skip if the user says
   to work on the current branch). All pipeline commits land on this branch.
5. Read `CLAUDE.md` and the steering docs so you can give the planner real context.

## Phase 1 — Plan

**Discovery first, when warranted.** If the request is a vague or greenfield
product idea (target users unclear, MVP scope open, one-sentence "build me an X"),
ask 3–5 sharp questions in ONE AskUserQuestion call before planning: who uses it,
the 2–3 core MVP flows, what's explicitly out of scope, constraints/stack
preferences, what success looks like. Distill the answers into a mini-PRD that goes
into the epic's Goal section and the planner's context. Skip discovery entirely for
clear, scoped tasks — never interrogate the user about a button fix. The
`--discover` flag forces it; `--quick` forbids it.

Spawn the **planner** agent (subagent_type: `planner`) with:
- The user's request verbatim.
- Project context: stack, structure, existing conventions, the next free EPIC/DEV numbers.
- Instruction to return a structured plan: epic summary, architecture decision, and a
  ticket list where each ticket has: id, title, type (frontend/backend/fullstack/mobile/infra),
  assignee agent, priority, depends_on, description, scope, acceptance criteria, technical notes.

When the plan returns:
1. Write `workboard/epics/EPIC-NNN-<slug>.md` (use `templates/EPIC-template.md` format).
2. Write one `workboard/tickets/DEV-NNN-<slug>.md` per ticket (use `templates/TICKET-template.md` format), status `backlog`.
3. Update `BOARD.md` (epics list, tickets table, activity log).
4. Show the user a compact plan summary (ticket table). **Do not wait for approval** —
   proceed unless the user interrupts. If the request was ambiguous on a decision that
   changes the architecture (e.g. which database, native vs cross-platform), use
   AskUserQuestion BEFORE spawning the planner, never after building has started.
5. **Exception — `--review` flag**: present the plan and STOP with AskUserQuestion
   (approve / request changes / cancel). On "request changes", re-run the planner
   with the feedback; on approve, commit the workboard (`chore(EPIC-NNN): plan`)
   and continue.
6. **Exception — `--dry-run` flag**: write the epic + tickets to the workboard
   (status `backlog`), commit `chore(EPIC-NNN): plan`, show the plan summary, and
   STOP entirely — no building. The user continues later with `/ship resume`.

## Phase 2 — Build

Process tickets in dependency order (topological). Tickets with no unmet dependencies
run **in parallel** — spawn their developer agents in a single message — but ONLY if
their owned file sets (from Technical Notes) are disjoint; otherwise serialize them.
Subagents don't see the conversation: each delegation prompt must be self-contained
(ticket path + how to run the project + anything else it needs).

For each ticket, spawn the agent named in `assignee` (`frontend-developer`,
`backend-developer`, `fullstack-developer`, `mobile-developer`, or
`devops-engineer`) with this contract:

> Read your ticket at `workboard/tickets/<file>`. Implement it fully in this codebase,
> following the project's existing conventions and your craft standards. Then:
> 1. Verify your work compiles/builds and passes existing tests (run them).
> 2. Append to the ticket's **Implementation Log**: files changed, key decisions,
>    how you verified, anything the reviewers should scrutinize.
> 3. Check off the acceptance criteria you satisfied.
> Return a one-paragraph summary plus the list of changed files.

Per ticket: set status `in_progress` before spawning, `built` when the agent returns
successfully — then **commit** that ticket's owned files plus its workboard files:
`feat(DEV-NNN): <title>` (use `fix:`/`chore:` when the ticket type fits better).
One ticket = one commit; never `git add -A` while parallel agents are running. If an agent fails or returns incomplete work, retry once with the failure
context; if it fails again, set status `blocked`, log it, and continue with other
tickets — report blocked tickets in the final summary. (In loop mode, blocked
tickets instead climb the escalation ladder from the Persistence section.)

Update `BOARD.md` activity log after each ticket transition.

## Phase 3 — Verify (quality gates)

When all buildable tickets are `built`, set them to `qa` and spawn the reviewers
**your mode calls for** in parallel, in one message:

1. **qa-engineer** — functional review + test execution across all built tickets (all modes).
2. **security-auditor** — security review of the changed surface (standard/full, or
   quick when the change touches a sensitive surface).
3. **code-auditor** — code quality, architecture and consistency audit (full only).
4. **design-reviewer** — screenshot-based visual review of the changed UI
   (standard/full, only when the epic contains frontend/mobile/fullstack tickets).
5. **test-engineer** — codifies the epic's acceptance criteria into durable
   automated tests (integration + E2E for critical journeys), fills coverage gaps
   on changed code (standard/full). Its tests run in the quality gate from then on
   — the regression net grows with every epic. If it exposes real bugs while
   testing, those are findings like any other.

Each receives: the list of built tickets (paths), list of changed files, and instruction to:
- Append findings to each ticket's respective findings section as
  `[CRITICAL|HIGH|MEDIUM|LOW] description — file:line — how to reproduce/why it matters`.
- Return a machine-readable summary: counts per severity + list of findings.

## Phase 4 — Debug Loop

Collect all CRITICAL and HIGH findings (MEDIUM/LOW are fixed too if cheap, otherwise
logged as new backlog tickets — do not gold-plate).

**Verification filter (standard/full modes):** before any debugging, spawn the
**verifier** agent (one per finding group, in parallel) to adversarially confirm or
refute each CRITICAL/HIGH finding. REFUTED findings are marked disputed in the
ticket and dropped; CONFIRMED and UNCERTAIN proceed. Skip the filter in quick mode
and for self-evident findings (broken build, failing test).

While open confirmed CRITICAL/HIGH findings exist (max **3 iterations** in capped
mode; per the Persistence rules in loop mode):
1. Set affected tickets to `debugging`.
2. Group findings by area/file and spawn the **debugger** agent (one per independent
   group, in parallel) with: the findings, the ticket paths, and instruction to
   root-cause, fix, verify the fix (run tests / reproduce), and append to the ticket's
   **Debug Log**: `finding → root cause → fix → verification`.
3. Commit the fixes per area: `fix(DEV-NNN): <finding summary>`.
4. Re-verify: re-spawn only the reviewer(s) whose findings were fixed, scoped to the
   fixed areas, to confirm resolution and catch regressions.
5. If findings remain after 3 iterations, stop, mark tickets `blocked`, and report
   honestly what is still open.

## Phase 5 — Close

1. Set clean tickets to `done`, check the epic's Definition of Done, set the epic
   status, and write its **Final Report** section: what was built, files touched,
   verification results, open items.
2. **Docs.** Update the project docs this epic affected: a `CHANGELOG.md` entry,
   README sections that became wrong or incomplete, and CLAUDE.md (new commands,
   structure, conventions). Small inline edits by you — no agent spawn needed.
3. Update `BOARD.md` (statuses + activity log entry) and update
   `workboard/steering/` docs if this epic changed the stack/structure/conventions.
   Final commit: `chore(EPIC-NNN): close epic`.
4. **Retro** (standard/full modes): run the `/retro` flow for this epic — its
   analyst distills recurring findings and hard-won facts into the steering docs.
5. **PR (optional).** If the repo has a remote, ask the user (AskUserQuestion):
   push the `devflow/epic-NNN-*` branch and open a PR? On yes: push, then
   `gh pr create` with a body built from the epic's Final Report (what/why, finding
   stats, ticket list). Without `gh`, push and give the compare URL. Never push
   without the explicit yes.
6. Report to the user: what was built, how it was verified (QA/security/audit/design
   results with finding counts), retro lessons (one line each), the branch/PR link
   (merging is the user's call — never merge yourself), anything blocked or
   deferred, and how to run/see the result.

## Resuming

If invoked while a board already has non-`done` tickets and the user says
`/ship resume` (or the request clearly refers to the existing epic), do not re-plan:
read the board, determine the current phase from ticket statuses, and continue from there.
