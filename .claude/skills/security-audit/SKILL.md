---
name: security-audit
description: Run the security auditor agent standalone — OWASP-style review of recent changes or the whole codebase — and report findings by severity. Use when the user asks for a security check/audit outside the full /ship pipeline.
---

# /security-audit — Standalone Security Pass

1. Determine scope from `$ARGUMENTS`: a path, "full" (whole codebase), or default to
   the working-tree diff / tickets in `built`/`qa` status if a `workboard/` exists.
2. Spawn the **security-auditor** agent with the scope and project context
   (stack, auth model, how the app is exposed).
3. If workboard tickets are in scope, findings go into each ticket's
   **Security Findings** section; otherwise reported directly.
4. Present findings grouped by severity with file:line references and remediation
   suggestions. Do **not** auto-fix — suggest `/debug-findings` to fix them.
