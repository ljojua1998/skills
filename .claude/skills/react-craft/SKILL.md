---
name: react-craft
description: React-specific engineering standards — hooks discipline, render performance, state/data-fetching choices, component patterns. Loaded on top of frontend-craft when the ticket's stack is React (incl. Next.js, React Native shares much of this). Use when building React UI.
user-invocable: false
---

# React Craft

Framework-specific rules on top of `frontend-craft`. Match the project's existing
React version, router, and state/data libraries before introducing anything new.

## Hooks discipline

- **Rules of hooks are absolute**: only call hooks at the top level, never in
  conditions/loops/callbacks. Custom hooks start with `use`.
- `useEffect` is for **synchronizing with external systems**, not for deriving
  state. If a value can be computed during render, compute it — don't mirror it
  into state via an effect. No effect just to `setState` from props.
- Every effect that subscribes/opens/times must return a cleanup. List **all**
  reactive dependencies honestly; don't silence the lint rule — fix the design
  (move functions in, use refs, or `useCallback`/`useMemo` where it's real).
- Reach for `useRef` for mutable values that must not trigger re-render (timers,
  latest-value, DOM nodes). Never store render-affecting data only in a ref.

## Render performance

- Derive, don't duplicate: no state that can be computed from other state/props.
- Memoize on **measured** hot paths only: `React.memo` for expensive children
  that re-render on unrelated parent updates; `useMemo`/`useCallback` when the
  identity actually feeds a memoized child or an effect dep. Premature memoization
  is noise.
- Stable, meaningful `key`s on lists — never the array index for reorderable/
  editable lists.
- Keep context values stable (memoize the provider value); split contexts so a
  change doesn't re-render unrelated consumers.
- Lazy-load routes/heavy components with `React.lazy` + `Suspense`.

## State & data

- Local first (`useState`/`useReducer`); lift only when genuinely shared; a global
  store (Zustand/Redux/Jotai — whatever the project uses) only for truly global state.
- **Server state is not UI state**: fetch/cache with the project's data layer
  (TanStack Query, RTK Query, SWR) — don't hand-roll `useEffect` + `useState`
  fetching with no caching, dedup, or error/loading handling.
- Controlled inputs by default; a single source of truth per form field.

## Components & structure

- One component = one responsibility; extract child components and custom hooks
  before a component crosses ~150–200 lines (per frontend-craft). Logic in hooks,
  markup in components.
- Composition over configuration: prefer children/slots over a growing prop of booleans.
- Type props explicitly (TS interfaces / PropTypes); no implicit `any` on props.
- Error boundaries around risky subtrees; don't let one component crash the app.

## Next.js (if present)

- Respect the project's router (App vs Pages). Server Components by default in App
  Router; add `"use client"` only where interactivity/hooks require it — don't mark
  whole trees client.
- Data fetching on the server where possible; don't ship secrets to the client.

## Checklist additions

- [ ] No `useEffect` used to derive state that could be computed in render.
- [ ] All effects clean up; dependency arrays complete (lint rule not suppressed).
- [ ] Server data goes through a caching data layer, not raw effect-fetch.
- [ ] List keys are stable and meaningful.
