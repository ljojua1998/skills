# devflow-cc

One-command installer for **[DevFlow](https://github.com/ljojua1998/skills)** — the agentic delivery pipeline for Claude Code.

`/ship` plans your request into Jira-like tickets, builds them with 14 specialist agents in parallel, enforces a red-tests-can't-finish quality gate, runs QA / security / design / code review with adversarial finding verification, debugs until clean, and hands you a branch.

## Install

```bash
# into the current project
npx devflow-cc init

# for every project on this machine
npx devflow-cc init --global

# a specific project / overwrite existing files
npx devflow-cc init --target ./my-app
npx devflow-cc init --force
```

This copies 14 agents, 15 skills and the quality-gate hooks into `.claude/`
(or `~/.claude/` with `--global`). It always pulls the latest from GitHub, so
you get current agents on every run.

Then open Claude Code in your project:

```text
/ship "Build a task manager with auth and a kanban board"
```

## Requirements

- [Claude Code](https://claude.com/claude-code)
- `git` on PATH
- On Windows: Git Bash on PATH for the quality-gate hook (the installer warns and shows the fix if it's missing)

## Links

- **Landing page:** https://ljojua1998.github.io/skills/
- **Source & docs:** https://github.com/ljojua1998/skills
- **License:** MIT
