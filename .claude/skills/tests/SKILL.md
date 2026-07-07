---
name: tests
description: Strengthen the automated test suite standalone — codify untested behavior, fill coverage gaps on recent changes, add E2E for a critical flow, or stabilize flaky tests. Use when the user asks to add/improve/fix tests outside the full /ship pipeline.
argument-hint: "[coverage | e2e \"<flow>\" | flaky | <scope>]"
---

# /tests — Strengthen the Safety Net

1. **Determine the mission** from `$ARGUMENTS`:
   - `coverage` (or empty) — find and fill test gaps on the working-tree diff, or
     the whole project if the diff is empty.
   - `e2e "<flow>"` — build an end-to-end test for the named user journey.
   - `flaky` — hunt tests that flicker (run the suite 3×, diff results) and
     stabilize them at the root cause.
   - anything else — treat as a scope (path/feature) to cover with tests.
2. **Spawn the `test-engineer` agent** with the mission, the relevant paths, and
   how to run the project/tests (from CLAUDE.md or `workboard/steering/tech.md`).
3. Report: tests added (by type and file), behavior now covered, anything that
   couldn't be covered and why, and the suite result (command + counts).

Do not spawn reviewers or debuggers here — if the new tests expose real bugs,
list them and suggest `/debug-findings`.
