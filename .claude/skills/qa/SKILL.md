---
name: qa
description: Run the QA engineer agent standalone against recent changes or a given scope — functional review, test execution, edge cases — and report findings. Use when the user asks to test/QA something outside the full /ship pipeline.
---

# /qa — Standalone QA Pass

1. Determine scope from `$ARGUMENTS`; if empty, use the working-tree diff
   (`git status` / `git diff`) or, if a `workboard/` exists, all tickets in `built`/`qa` status.
2. Spawn the **qa-engineer** agent with the scope: files changed, tickets (if any),
   and how to run the app/tests (from CLAUDE.md or package scripts).
3. If workboard tickets are in scope, the agent appends findings to each ticket's
   **QA Findings** section; otherwise it reports findings directly.
4. Present findings to the user grouped by severity. Do **not** auto-fix — suggest
   `/debug-findings` to fix them.
