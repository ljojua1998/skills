---
name: debugging-craft
description: Systematic debugging method — feedback loop first, reproduce and minimize, ranked falsifiable hypotheses, targeted instrumentation, regression-test-before-fix. Use whenever diagnosing a bug or a failing finding.
user-invocable: false
---

# Debugging Craft

Six phases, in order. The discipline is the value — skipping phase 1 is how
debugging turns into guessing.

## 1. Build a feedback loop (most important)

Before theorizing, get a **deterministic, fast pass/fail signal that goes red on
this bug**. Ranked options: a failing test at the nearest seam → HTTP script
against the dev server → CLI run with fixture input → headless browser drive →
minimal repro harness. If you have this loop, you will find the cause; if you
don't, you're guessing.

## 2. Reproduce and minimize

Shrink to the smallest failing case — remove one element at a time (data fields,
config, middleware, steps) until removing anything makes it pass. The remainder
points at the cause.

## 3. Hypothesize

Write 3–5 falsifiable hypotheses ranked by likelihood, each with a testable
prediction ("if H1, then adding X will show Y"). Test the cheapest-to-check first.
Never fix on an untested hypothesis.

## 4. Instrument

Probes mapped to specific predictions — not scattergun logging. Prefer a debugger
or targeted assertions over log spam. Tag every temporary probe (e.g. `// DEBUG:`)
so cleanup is mechanical.

## 5. Fix and regression-test

Write the regression test **before** the fix — watch it fail on the bug, then pass
with the fix. Fix the root cause minimally; check whether the same root cause
exists elsewhere in the codebase and fix all instances. Run the surrounding suite
for regressions.

## 6. Clean up and capture

Remove all probes and debug artifacts. Record in the ticket/log: symptom → root
cause → fix → verification, plus (when it's structural) what would prevent this
class of bug.

## Honesty rules

- Cannot reproduce → report exactly what you tried; never "fix" blind.
- Finding is actually intended behavior → dispute it with reasoning; don't change code.
- A fix without a re-run red→green signal is not a fix — don't report it as one.
