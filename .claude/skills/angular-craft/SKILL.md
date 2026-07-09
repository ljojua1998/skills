---
name: angular-craft
description: Angular-specific engineering standards — RxJS/subscription hygiene, change detection, DI, standalone components, signals. Loaded on top of frontend-craft when the ticket's stack is Angular. Use when building Angular UI.
user-invocable: false
---

# Angular Craft

Framework-specific rules on top of `frontend-craft`. Match the project's Angular
version, module vs standalone style, and state approach before introducing
anything new. For modern Angular, prefer standalone components and signals where
the version supports them.

## RxJS & subscription hygiene (the #1 Angular bug source)

- **Never leak a subscription.** Prefer the `async` pipe in templates (it
  subscribes and unsubscribes for you). When you must subscribe in code, tear down
  with `takeUntilDestroyed()` (or a `destroy$` Subject + `takeUntil`) — an
  unmanaged `.subscribe()` in a component is a defect.
- Don't nest subscribes — compose with `switchMap`/`mergeMap`/`concatMap` (pick by
  cancellation semantics; `switchMap` for "latest wins" like typeahead).
- Don't manually `.subscribe()` just to reassign a field the template could bind
  via `async`. No side effects inside `map` — use `tap`.

## Change detection & performance

- Default to `ChangeDetectionStrategy.OnPush` for components; drive updates via
  immutable inputs, observables (`async` pipe), or signals — not mutation.
- Never do heavy work or create new references in template expressions/getters
  (runs every CD cycle). Precompute; use `trackBy` on `*ngFor` (or the new
  `@for` `track`).
- Avoid `function` calls in templates that allocate; memoize or bind fields.

## DI & structure

- Services are the home for logic and state; components stay thin (presentation +
  wiring). Provide services at the right scope (`root` vs component) deliberately.
- Use `inject()` or constructor DI consistently with the project; don't `new` a
  service that should be injected.
- One responsibility per component; extract child components and services before a
  component grows past ~150–200 lines (per frontend-craft). Smart/container vs
  presentational split where it clarifies.
- Strict typing on — no implicit `any`; type inputs/outputs; use typed reactive forms.

## State & data

- Local component state (signals/fields) first; a store (NgRx / signal store /
  the project's choice) only for genuinely shared/global state — don't add NgRx
  ceremony to a small app.
- HTTP through `HttpClient` in services returning observables; handle errors with
  `catchError`; show loading/error in the view. Don't swallow HTTP errors.
- Reactive forms over template-driven for non-trivial forms; validate and surface
  messages accessibly.

## Checklist additions

- [ ] No unmanaged `.subscribe()` — `async` pipe or `takeUntilDestroyed`/`takeUntil`.
- [ ] Components use OnPush; `*ngFor`/`@for` has trackBy/track; no allocating template calls.
- [ ] Logic lives in services, not components; DI scopes are deliberate.
- [ ] HTTP errors handled with catchError and surfaced, not swallowed.
