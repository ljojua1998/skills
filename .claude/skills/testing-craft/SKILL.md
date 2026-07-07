---
name: testing-craft
description: Testing standards — what to test, at which seam, and what makes a test worth having. Use whenever writing or reviewing tests for new behavior.
user-invocable: false
---

# Testing Craft

## What a good test is

A good test **reads like a specification** of behavior and **survives refactoring**:
it exercises a public seam (API endpoint, exported function/hook, component
behavior, CLI) and asserts observable outcomes — not internals.

## Where to test (choose the cheapest seam that gives a real signal)

1. Unit: pure logic — parsers, calculations, reducers, validators.
2. Integration: endpoint/service with real (or containerized/in-memory) DB — the
   default for backend behavior.
3. Component: render + interact + assert visible result (Testing Library style) —
   the default for frontend behavior.
4. E2E: only for the few critical user journeys; keep the suite small and stable.

## Minimum coverage for new behavior

- Happy path with realistic data.
- One boundary/edge case that matters (empty, max, unicode, zero).
- Failure path: invalid input rejected with the right error; authz denied for
  another user's resource (backend); error state rendered (frontend).

## Anti-patterns (a reviewer will flag these as findings)

- **Tautological assertions** — recomputing the expected value with the same code path under test.
- **Mocking the thing under test** or mocking internals so deeply the test asserts
  the mock, not the behavior.
- Tests coupled to implementation details (private method calls, CSS class names,
  exact log strings) that break on any refactor.
- Asserting nothing (`expect(result).toBeDefined()` as the only assertion).
- Sleeping/arbitrary timeouts instead of awaiting a deterministic signal — flaky by design.
- Deleting or skipping a failing test to make the suite green.

## Discipline

- Run the **whole** relevant suite before declaring done, not only your new tests.
- Regression tests for bug fixes are written to fail on the bug first, then pass with the fix.
- Follow the project's existing test framework, helpers, and naming — don't introduce a second stack.
