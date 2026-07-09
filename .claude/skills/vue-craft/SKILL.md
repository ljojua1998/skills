---
name: vue-craft
description: Vue-specific engineering standards — Vue 3 Composition API + <script setup> + TS, reactivity correctness, composables, Pinia, router guards, performance and testing. Loaded on top of frontend-craft when the ticket's stack is Vue (incl. Nuxt). Use when building Vue UI.
user-invocable: false
---

# Vue Craft

Framework-specific rules on top of `frontend-craft`, distilled from the
`vuejs-ai/skills` collection. **Default stack: Vue 3 + Composition API +
`<script setup lang="ts">`.** Only use the Options API if the project explicitly
does (then `defineComponent`, no arrow functions for methods/lifecycle). Match the
project's Vue version, router and store before introducing anything new. Get
behavior correct first, optimize after.

## Reactivity correctness (the #1 Vue bug source)

- **Choose the right primitive:**
  - Primitives → `shallowRef()` (cheaper than `ref()` for a plain number/string/bool).
  - Objects/arrays you **replace wholesale** → `ref()`; objects you **mutate in place** → `reactive()`.
  - External/opaque objects (SDK/class instances, huge nested data) → `shallowRef()`
    (only `.value = …` triggers; `.value.x = …` is NOT tracked). `markRaw()` for
    things that must never be reactive.
- **Never destructure a `reactive()`** — reactivity is lost. Use `toRefs(state)`.
- **Watch sources**: `watch(() => state.count, …)` (getter) or a ref — not
  `watch(state.count, …)` (passes a plain value).
- **`computed` for derived values** (cached, declarative); getters must be **pure**
  (no side effects, no `console`, no array mutation). Extract template filter/sort
  and class/style objects into computed.
- **Watchers are for side effects only.** Use `{ immediate: true }` instead of
  duplicating logic in `onMounted`. **Clean up async in watchers** with `onCleanup`
  + `AbortController` to cancel stale requests (search/filter races).

## SFC structure & template safety

- Section order `<script>` → `<template>` → `<style>`; PascalCase filenames/usage.
- **`<style scoped>`** for component CSS; global CSS only for resets/tokens. Prefer
  **class selectors over element selectors** in scoped styles. `:style` in camelCase.
- **`v-for` always has a stable primitive `:key`; never `v-if` + `v-for` on the
  same element** (`v-if` wins priority and can't see the loop alias) — filter in a
  computed or wrap the list. `v-if` for rarely-toggled, `v-show` for frequently-toggled.
- **Never `v-html` untrusted input** (script injection) — interpolate, or sanitize
  with DOMPurify. No side effects in template expressions.
- Template refs via `useTemplateRef()` (Vue 3.5+).

## Component data flow

- **Props down, events up.** Props are read-only — never mutate; emit or `v-model`.
- **`v-model`**: `defineModel()` (Vue 3.4+); earlier, `modelValue` prop +
  `update:modelValue` emit. Type props/emits with type-based `defineProps<T>()` /
  `defineEmits<T>()` (`defineEmits` must be top-level).
- **Events don't bubble** — a grandchild's event must be re-emitted by the middle child.
- Template refs only for imperative APIs (open a modal); expose intended API via
  `defineExpose`, typed.
- **provide/inject**: Symbol-based `InjectionKey` (no collisions); centralize
  mutations in the provider, expose action methods, wrap provided state in `readonly()`.

## Composables

- Extract when logic is reused, stateful, or side-effect heavy; small typed APIs.
  Compose from smaller primitives; options object with defaults (not positional args).
- **Return `readonly()` state + explicit mutation methods** — don't expose mutable state.
- Keep pure utilities (`formatDate`, `formatCurrency`) as plain functions.
- Flexible input typing: `MaybeRefOrGetter<T>` for read-only/computed-friendly
  inputs, `MaybeRef<T>` when two-way writes are needed. Normalize inside effects
  with `toValue()` (non-reactive read) / `toRef()` (for watchers).

## State management (lightest that fits)

1. Feature composables (default — local/feature state).
2. Singleton composable / VueUse `createGlobalState` (small non-SSR shared state).
3. **Pinia** for SSR/Nuxt, medium-large apps (per-request isolation, DevTools).
- **Never export mutable reactive state** — `readonly(state)` + actions.
- **Never use module-level runtime singletons in SSR** (leaks state across requests).
- **`storeToRefs(store)`** for reactive state+getters (destructuring the store
  directly breaks reactivity); destructure actions directly.
- **Setup stores must return ALL state** (every ref/computed) — omitting breaks SSR
  hydration, DevTools, persistence.

## Performance (after correctness)

- `v-once` for truly static subtrees; `v-memo="[deps]"` for large `v-for` lists
  where only a few items change (`v-memo="[]"` ≡ `v-once`) — not for genuinely
  reactive content or children with their own state/v-model.
- Keep computed-object / prop identity stable to avoid needless child updates.
- **Virtualize lists > ~50–100 complex items** (`vue-virtual-scroller`,
  `@tanstack/vue-virtual`); skip for small lists, screen-reader-all, or SEO-critical HTML.

## Async components & Suspense

- `defineAsyncComponent()` with both `delay` (~200ms) and `timeout`, plus
  `loadingComponent` and `errorComponent`. SSR lazy hydration: `hydrateOnVisible()`/
  `hydrateOnIdle()`.
- `<Suspense>` default+fallback slots each need a single root child; re-enters
  pending only when the root node changes (use `:key` to force). Wrapper order:
  `RouterView` → `Transition` → `KeepAlive` → `Suspense`.

## Vue Router 4

- **`next()` is deprecated — use return-based guards**: return nothing = proceed;
  `false` = cancel; a path string / route object = redirect; an `Error` = cancel +
  `router.onError()`. `beforeRouteEnter` has no `this` (use the callback/return
  form). Param-only changes don't re-run lifecycle — watch `route.params` /
  `onBeforeRouteUpdate`. Avoid infinite navigation loops.

## Nuxt (if present)

- Data via `useFetch`/`useAsyncData`/`$fetch` (SSR-safe, dedup + hydration) — not a
  bare `onMounted` fetch that double-runs. Server-only secrets stay in server
  routes / runtime config.

## Testing (Vitest + Vue Test Utils / Testing Library; Playwright E2E)

- **Black-box / behavior testing**: query by user-visible attributes (`data-testid`,
  roles), simulate real interactions, assert rendered output and **emitted events**
  (`wrapper.emitted('change')[0]`). Don't assert `wrapper.vm.x`, private methods, or
  internal computed; no snapshot-only tests.
- Async: `await flushPromises()`. Composables: test via a host wrapper component.
  Pinia: fresh testing pinia per test.

## Checklist additions

- [ ] `<script setup lang="ts">` + Composition API; no destructured `reactive`; props never mutated.
- [ ] Derived values are `computed` (pure); watchers only for side effects, async cleaned up.
- [ ] `v-for` has stable keys; no `v-for`+`v-if` on one node; no `v-html` of untrusted input.
- [ ] Store access via `storeToRefs`; setup stores return all state; no SSR module singletons.
- [ ] Tests assert rendered output + emitted events, not internals.
