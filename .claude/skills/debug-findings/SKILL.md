---
name: debug-findings
description: Run the debugger agent over open findings (from /qa, /security-audit, the workboard, or a pasted bug report) — root-cause, fix, verify, and re-check. Use when the user asks to fix reported bugs/findings.
---

# /debug-findings — Fix Open Findings

1. Collect findings:
   - From `$ARGUMENTS` if the user pasted/described them.
   - Else from `workboard/tickets/*` — all unresolved entries in QA/Security/Audit
     findings sections (a finding is resolved when the Debug Log references it).
   - Else from the last QA/security report in this conversation.
2. Group findings by area/file. Spawn the **debugger** agent per independent group
   (in parallel) with: the findings, relevant ticket paths, and how to run tests.
3. Each debugger must: reproduce → root-cause → fix → verify (run tests / reproduce
   again) → append `finding → root cause → fix → verification` to the ticket's
   **Debug Log** (or report it directly if no workboard).
4. After fixes, re-run the relevant reviewer agent scoped to the fixed areas to
   confirm resolution (one re-check round; report anything still open honestly).
