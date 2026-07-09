---
name: vue-craft
description: Vue-specific engineering standards — Composition API, reactivity correctness, computed vs watch, component patterns. Loaded on top of frontend-craft when the ticket's stack is Vue (incl. Nuxt). Use when building Vue UI.
user-invocable: false
---

# Vue Craft

Framework-specific rules on top of `frontend-craft`. Match the project's Vue
version (2 vs 3), API style (Options vs Composition), router and store before
introducing anything new. For new Vue 3 code, prefer `<script setup>` + Composition API.

## Reactivity correctness

- `ref` for primitives and when you need reassignment; `reactive` for objects you
  mutate in place — don't destructure a `reactive` object (it loses reactivity;
  use `toRefs`).
- Never reassign a `reactive` target wholesale (`state = {...}` breaks it); mutate
  properties or use a `ref`.
- Access `.value` in script for refs; templates auto-unwrap top-level refs.
- Props are read-only — never mutate a prop; emit an event or use a local copy.

## computed vs watch

- **`computed` for derived values** — cached, declarative, the default. Reach for
  it before `watch`.
- `watch`/`watchEffect` only for **side effects** (fetch on id change, sync to
  storage). Don't use a watcher to compute a value you could `computed`.
- Set `{ deep: true }` deliberately (cost); prefer watching a specific getter over
  a whole object. Clean up in `watch`'s `onCleanup` / `onUnmounted`.

## Components & structure

- One `.vue` file = one component, one responsibility; extract child components and
  composables (`useXxx`) before it grows past ~150–200 lines (per frontend-craft).
- Reusable stateful logic goes into **composables**, not mixins.
- `v-for` always with a stable `:key` (not index for dynamic lists); never combine
  `v-for` and `v-if` on the same element — filter in a `computed` instead.
- Type props with `defineProps<T>()` (TS) or typed prop objects; type emits with
  `defineEmits`.
- Scoped styles (`<style scoped>`) by default; avoid leaking global CSS.

## State & data

- Local component state first; **Pinia** (or the project's store) for shared/global
  state — one store per domain, actions for mutations.
- Server state through the project's data layer (`@tanstack/vue-query`, Nuxt
  `useFetch`/`useAsyncData`) with caching and loading/error states — not a bare
  `onMounted` fetch into a `ref`.
- `v-model` for two-way form binding; one source of truth per field.

## Nuxt (if present)

- Use `useFetch`/`useAsyncData` for SSR-safe data (dedup + hydration); don't fetch
  in a way that double-runs on server and client.
- Server-only secrets stay in server routes / runtime config, never exposed to client.

## Checklist additions

- [ ] No destructured `reactive` losing reactivity; props never mutated.
- [ ] Derived values are `computed`, not `watch`-assigned.
- [ ] `v-for` has stable keys; no `v-for`+`v-if` on the same node.
- [ ] Server data via a caching layer / Nuxt data composables, not bare onMounted fetch.
