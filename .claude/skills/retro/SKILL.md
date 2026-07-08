---
name: retro
description: Post-epic retrospective — analyze a finished epic (tickets, findings, debug logs) and distill durable lessons into the project's steering docs, so every next run is smarter and cheaper. Use after an epic closes, or when the user invokes /retro.
argument-hint: "[EPIC-NNN]"
---

# /retro — Learn From the Epic

1. **Pick the epic**: from `$ARGUMENTS`, or the most recently closed epic in
   `workboard/epics/`. If none is closed, say so and stop.
2. **Spawn one general-purpose agent** with the epic + its ticket paths + the run
   ledger (`workboard/runs/EPIC-NNN.md`, if present) and this contract:
   > Read the epic, every ticket (implementation logs, all findings sections,
   > debug logs) and the run ledger (cycle history, escalations, drift fixes,
   > guard stops). Extract only DURABLE lessons — things that will change how the
   > next epic in this project runs:
   > - Recurring finding classes (same mistake ≥2 times) → a concrete rule worth
   >   adding to `workboard/steering/conventions.md`.
   > - Environment/tooling facts discovered the hard way (commands, quirks,
   >   flaky areas) → `workboard/steering/tech.md`.
   > - Planning misses (tickets that were too big/small, wrong dependency order,
   >   scope that had to change mid-build) → a "planning notes" line in
   >   `workboard/steering/product.md`.
   > Apply the updates directly to the steering files — keep each file under one
   > page by pruning anything stale, and never duplicate an existing rule. Do not
   > log one-off trivia. Return: lessons applied (bullets) + files updated.
3. **Record**: append a short "Retrospective" section (the lesson bullets) to the
   epic file. Commit: `chore(EPIC-NNN): retro`.
4. Report the lessons to the user in 3–6 bullets — no filler.

If the project has no `workboard/steering/`, create it from what the retro learns.
