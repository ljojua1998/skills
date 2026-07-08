---
name: patrol
description: Report-only maintenance sweep — dependency audit, test-suite health, security quick-scan, workboard grooming. Never changes code; produces a findings report and proposed backlog tickets. Use for recurring maintenance ("check the project's health") or schedule it with /loop.
argument-hint: "[deps | tests | security | board | all]"
---

# /patrol — Report-Only Maintenance Sweep

**L1 autonomy: read and report, never fix.** Safe to run on a schedule
(`/loop 1d /patrol`) or in CI — it cannot break anything.

1. **Scope** from `$ARGUMENTS` (default `all`). Run the relevant checks — spawn
   one agent per area, in parallel, each explicitly instructed READ-ONLY:
   - `deps` — ecosystem audit (`npm audit` / `pip-audit` / `cargo audit`):
     exploitable vulns relevant to actual usage, plus major-version drift on
     direct dependencies.
   - `tests` — run the full suite 2× and report: failures, flakes (pass/fail
     flicker), runtime trend, coverage holes on recently changed files.
   - `security` — spawn **security-auditor** scoped to changes since the last
     patrol (or last 20 commits) — quick pass, CRITICAL/HIGH only.
   - `board` — workboard grooming report: stale `in_progress`/`blocked` tickets,
     unfixed MEDIUM/LOW findings aging in ticket sections, epics stuck in
     `verifying`, drift between BOARD.md and ticket frontmatter.
2. **Report** one compact digest: per-area verdict (✅ / ⚠️ / 🔴), findings by
   severity, and a **proposed actions** list.
3. **Propose, don't do.** For each action worth taking, offer to create a backlog
   ticket (`/board add` style — batch, one confirmation). Fixing happens later
   via `/ship` or `/debug-findings`, initiated by the user.
4. Append a one-line entry to `workboard/BOARD.md`'s activity log:
   `patrol: <date> — <verdicts summary>` so patrol history is visible.

If the project has no workboard, run the checks anyway and just report.
