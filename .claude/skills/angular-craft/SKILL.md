---
name: angular-craft
description: Angular-specific engineering standards — modern v17-v21 conventions (signals, standalone, built-in control flow, inject(), resource(), Signal Forms), RxJS interop, change detection, and the ng-build verification loop. Loaded on top of frontend-craft when the ticket's stack is Angular. Use when building Angular UI.
user-invocable: false
---

# Angular Craft

Framework-specific rules on top of `frontend-craft`, aligned with the official
Angular team's agent skill (modern Angular, v17–v21). **Detect the project's
Angular version first** — features differ by version; don't apply v21 APIs to a
v16 project. Match the codebase's existing style before introducing anything new.

## The verification loop (non-negotiable)

After generating or changing Angular code, **run `ng build`** (the project's build).
If it errors, fix before proceeding — don't report done on code that doesn't
compile. This is in addition to the DevFlow stop-gate; Angular's own type/template
checking catches template-binding and signal mistakes the linter won't.

## Ban the legacy quartet (for new code on a modern project)

Agents habitually emit outdated Angular. On v17+ projects, do NOT write:
- **NgModules** — standalone is the default (v19+); don't even write `standalone: true` (redundant).
- **`@Input()` / `@Output()` decorators** — use `input()` / `output()` / `model()`.
- **`*ngIf` / `*ngFor` / `*ngSwitch`** — use built-in `@if` / `@for` / `@switch`.
- **Constructor injection** — use `inject()` in field initializers.

For a legacy codebase, don't hand-rewrite — offer the automated schematics:
`ng g @angular/core:control-flow`, `:inject`, `:signal-input-migration`,
`:output-migration`, `:standalone`, `:self-closing-tag` (each gated on a green `ng build`).

## Components & templates

- Scaffold with the CLI (`ng g component ...`) for consistency; standalone, with
  explicit `imports`. Self-closing tags for componentless content (`<app-profile />`).
- **Control flow**: `@if (user(); as u) { } @else { }`; `@for (x of items(); track x.id) { } @empty { }`
  — **`track` is required**; `@switch` uses strict equality (no fallthrough).
- Follow the project's naming; modern style guide drops the `Component` suffix.

## Signals (state) — the core of modern Angular

- `signal()` (read `x()`, write `.set()`/`.update()`); expose service state as
  **readonly** with `.asReadonly()`.
- `computed()` for derived values — lazy, memoized, auto-tracks only signals read.
- **`linkedSignal()`** for derived-but-user-overridable state (e.g. default
  selection that survives option changes). Decision: strictly derived → `computed`;
  derived + overridable → `linkedSignal`; "sync state via effect" → **anti-pattern**.
- **Async reactivity rule**: reactive contexts are synchronous. **Read every signal
  BEFORE any `await`** — reads after `await` don't register a dependency and
  silently break reactivity.

## effect() — narrow, and never for state propagation

- `effect()` is for side effects only: logging/analytics, syncing to
  localStorage, driving a canvas/3rd-party chart.
- **Hard prohibition**: never call `.set()`/`.update()` inside an `effect` to
  propagate one signal into another — causes `ExpressionChangedAfterItHasBeenChecked`
  / loops. Use `computed`/`linkedSignal`.
- DOM read/write in reaction to signals → `afterRenderEffect` (phases: earlyRead →
  write → mixedReadWrite → read, to avoid layout thrash; client-only, not in SSR).

## Inputs / outputs (signal-based)

- `readonly name = input('Guest');` · `readonly id = input.required<number>();` ·
  `input(false, { transform: booleanAttribute })`.
- Two-way: `model()` + template `[(value)]="sig"`.
- `readonly changed = output<T>()` + `.emit(v)` — camelCase, don't prefix with
  `on`, don't reuse native DOM event names (custom outputs don't bubble).

## Dependency injection

- `inject()` in field initializers (preferred), constructor bodies, guards/
  resolvers, factory functions. Outside a context: `runInInjectionContext`.
- Services `providedIn: 'root'` are the sharing mechanism; components stay thin.
- Providers: `useClass`/`useValue`/`useFactory` + `InjectionToken`; modifiers
  `optional`/`skipSelf`; `providers` vs `viewProviders` deliberately.

## Async data & RxJS interop

- Prefer **`resource({ params, loader })`** / **`httpResource()`** for async reads:
  `params` re-triggers on signal change; **always forward the `abortSignal`** for
  auto-cancellation. Status via `value()`/`hasValue()`/`isLoading()`/`error()`/`status()`.
- Where RxJS remains: never leak a subscription — prefer the `async` pipe, else
  `takeUntilDestroyed()`. Compose with `switchMap`/`mergeMap` (no nested subscribes);
  side effects in `tap`, not `map`. Bridge to signals with `toSignal()`/`httpResource()`.

## Change detection & performance

- Default `ChangeDetectionStrategy.OnPush`; drive updates via signals / immutable
  inputs / `async` pipe — not mutation. (Zoneless projects rely on signals entirely.)
- No allocating work or new references in template expressions/getters (runs each
  CD cycle) — precompute; `@for` always has `track`.

## Forms

- **New code on v21+: Signal Forms** (`form(this.model)`, model-driven, type-safe).
  Never use `null`/`undefined` as initial values (use `''`/`0`/`[]`). Reach field
  state by CALLING the field: `f.cat.name().touched()`; root flags `form().invalid()`;
  array length is structural `form.items.length` (no call). Validators from
  `@angular/forms/signals` in the schema callback; `submit(form, async () => {...})`.
- Existing apps: keep their approach — reactive forms for complex, template-driven
  for simple; handle errors and surface messages accessibly.

## Accessibility

- For headless a11y primitives (Accordion, Listbox, Combobox, Menu, Tabs, Tree,
  Grid) prefer **Angular Aria** over hand-rolled ARIA where the project uses it.

## Testing (Vitest, zoneless, async-first)

- **Act → Wait → Assert**: change state/inputs/click → `await fixture.whenStable()`
  → assert DOM. **Do NOT call `fixture.detectChanges()`** manually (changes are
  scheduled async under zoneless). Use Component Harnesses and `RouterTestingHarness`.

## Checklist additions

- [ ] `ng build` is green (ran it, not assumed).
- [ ] No NgModules / `@Input()`/`@Output()` decorators / `*ngIf`/`*ngFor` / constructor injection in new code.
- [ ] Every `@for` has `track`; components are OnPush.
- [ ] No `.set()`/`.update()` inside an `effect`; signals read before `await`.
- [ ] No unmanaged `.subscribe()` — `async` pipe or `takeUntilDestroyed`.
