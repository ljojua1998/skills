---
name: react-craft
description: React-specific engineering standards — impact-prioritized performance rules (waterfalls, bundle, re-renders), hooks discipline, RSC/server data, TypeScript-with-React, forms, and AI-feature patterns. Loaded on top of frontend-craft when the ticket's stack is React (incl. Next.js; React Native shares much of this). Use when building React UI.
user-invocable: false
---

# React Craft

Framework-specific rules on top of `frontend-craft`, distilled from Vercel's
`react-best-practices`. Match the project's React version, router and data
libraries first. Rules are ordered by **impact** — fix the CRITICAL classes before
the micro-optimizations.

## CRITICAL — eliminate waterfalls (2–10× wins)

- **Parallelize independent async work**: `await Promise.all([a(), b(), c()])`, not
  three sequential `await`s. Start promises early, await late.
- Check cheap sync conditions **before** awaiting; move `await` into the branch
  that actually uses the value.
- Stream with **Suspense** boundaries instead of blocking a whole route on the
  slowest fetch.

## CRITICAL — bundle size

- **No barrel-file imports.** Import the exact path (`lodash/debounce`,
  `@mui/material/Button`), not the package index — barrels can pull thousands of
  modules and add hundreds of ms to cold start (measured: `lucide-react` ~1,583
  modules, `@mui/material` ~2,225). In Next.js add heavy libs to
  `experimental.optimizePackageImports`.
- Dynamic-import heavy/below-the-fold components (`next/dynamic`, `React.lazy`).
- Defer third-party (analytics/logging) until after hydration; preload on
  hover/focus for perceived speed.

## HIGH — server-side (RSC / Next.js App Router)

- Server Components by default; add `"use client"` only where interactivity/hooks
  require it — don't mark whole trees client.
- Dedupe per-request reads with `React.cache()`; cross-request with an LRU cache.
- **Minimize data serialized to client components** — pass only the fields used,
  no whole DB rows. No module-level mutable request state in RSC/SSR.
- Parallelize fetches (restructure so independent data loads together; nested
  per-item fetches go inside `Promise.all`). Non-blocking work via `after()`.
- Authenticate server actions exactly like API routes; never trust the client.

## MEDIUM — re-render optimization

- **Derive during render; don't mirror props/state into an effect + `setState`.**
- Don't subscribe to state you only read inside a callback (use a ref); subscribe
  to a derived boolean, not the raw fast-changing value.
- Functional `setState` (`setX(c => ...)`) for stable callbacks with empty deps.
- Lazy state init: `useState(() => expensiveParse())` — the initializer runs once.
- **Never define a component inside another component** (new type every render →
  full remount). Hoist static JSX and non-primitive default props out.
- `React.memo`/`useMemo`/`useCallback` only where the identity actually feeds a
  memoized child or an effect dep — don't memo simple primitives.
- `startTransition` / `useDeferredValue` to keep input responsive during expensive
  renders; stable, meaningful list `key`s (never index for reorderable lists).

## MEDIUM — rendering & JS

- Conditional render with a ternary, not `&&`: `{count > 0 ? <Badge/> : null}` —
  `{count && ...}` renders a literal `0`.
- `content-visibility` CSS for long lists; animate a wrapper `div`, not the SVG.
- `Map`/`Set` for repeated lookups (O(1)); single-pass `flatMap`/combined loops;
  hoist `RegExp` out of loops; `toSorted()` for immutable sorts.

## Hooks & effects discipline

- Rules of hooks are absolute (top level only). `useEffect` is for **synchronizing
  with external systems**, not deriving state. Every subscribing/timing effect
  returns cleanup; list all deps honestly (fix the design, don't silence the lint).
- Put interaction logic in event handlers, not effects. `useRef` for transient
  values that must not re-render.

## State & data

- Local first; global store (project's choice) only for truly global state.
- **Server state ≠ UI state**: use the project's data layer (TanStack Query /
  SWR / RTK Query) with dedup, caching, loading/error — not raw `useEffect`+`fetch`.
- Controlled inputs, one source of truth per field.

## TypeScript with React

- No `any`; type all props and API responses. Discriminated unions for
  variant/state; branded types for IDs (`UserId` ≠ `PostId`); `Pick`/`Omit`/
  `Partial` to keep types DRY. **Validate external input at the boundary with Zod**
  (or the project's validator) — types don't exist at runtime.

## Forms & AI features

- Forms: React Hook Form (or the project's lib) + schema validation; server
  actions for submission where the app uses them; readable errors, no double-submit.
- AI features: use the **Vercel AI SDK** (`useChat`, streaming, tool calls) rather
  than hand-rolling stream parsing, when the project builds LLM UIs.

## Checklist additions

- [ ] No sequential awaits for independent data; Suspense used for streaming.
- [ ] No barrel imports of heavy libraries; heavy components dynamically imported.
- [ ] No state derived via effect+setState; no component defined inside a component.
- [ ] Server components pass minimal serialized data; server actions authenticated.
- [ ] Server data via a caching layer; list keys stable; `{x > 0 ? … : null}` not `{x && …}`.
