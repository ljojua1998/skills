---
name: devflow-update
description: Update the DevFlow agent system to the latest version from the source repo (github.com/ljojua1998/skills) and reinstall it here. Use when the user asks to update/upgrade DevFlow or sync the agent system.
---

# /devflow-update — Pull Latest & Reinstall

1. **Detect install scope.** If this skill's own directory (`${CLAUDE_SKILL_DIR}`)
   is under the user's home `.claude` folder → scope is **global**; otherwise →
   **project** (target = this project's root).
2. **Get the latest source** into the cache directory `~/.devflow-src`:
   - If it exists: `git -C ~/.devflow-src pull --ff-only`
   - Else: `git clone --depth 1 https://github.com/ljojua1998/skills.git ~/.devflow-src`
   Note the old→new commit range.
3. **Reinstall with force** from the cache:
   - Windows: `powershell -ExecutionPolicy Bypass -File ~/.devflow-src/install.ps1 -Force`
     plus `-Global` (global scope) or `-Target "<project root>"` (project scope).
   - macOS/Linux: `~/.devflow-src/install.sh --force` plus `--global` or the project path.
4. **Report**: `git -C ~/.devflow-src log --oneline <old>..<new>` as the changelog,
   list of updated files from the installer output, and remind the user to restart
   the Claude Code session so updated agents/skills load.

If the local source repo (the DevFlow development folder) is this very project
(it contains `install.ps1` **and** `.claude/agents/planner.md` in git), don't
self-update — tell the user this is the source repo itself.
