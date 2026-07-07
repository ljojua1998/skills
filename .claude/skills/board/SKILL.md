---
name: board
description: Show the current DevFlow workboard status — epics, tickets, statuses, open findings — and optionally manage tickets (add, reprioritize, block, close). Use when the user asks "what's the status", "show the board", or invokes /board.
---

# /board — Workboard Status & Management

Read the project's `workboard/` directory and give the user a Jira-style status view.

## Default behavior (no arguments)

1. Read `workboard/BOARD.md` and every file in `workboard/epics/` and `workboard/tickets/`
   (frontmatter is enough for most; read bodies only for non-`done` tickets).
2. Render a compact report:
   - The **Now** line from BOARD.md first — if a run is active, this is what the
     user most wants to see.
   - Epic(s): title, status, progress (`done`/total tickets).
   - Ticket table: ID, title, type, assignee, priority, status.
   - **Open findings**: any unfixed CRITICAL/HIGH from QA/Security/Audit sections.
   - Blocked tickets with the blocking reason.
3. If `BOARD.md` disagrees with ticket frontmatter, trust the tickets and fix `BOARD.md`.

## With arguments

- `/board add <description>` — create a new backlog ticket (next free `DEV-` number,
  ticket template format), update `BOARD.md`. Do NOT start building it.
- `/board close DEV-NNN` / `/board block DEV-NNN <reason>` / `/board priority DEV-NNN P1`
  — update the ticket frontmatter + board, log to the activity log.
- `/board resume` — hand off to the `/ship` flow's resume behavior (invoke the ship skill).

If `workboard/` does not exist, say so and suggest running `/ship "<task>"` to start.
