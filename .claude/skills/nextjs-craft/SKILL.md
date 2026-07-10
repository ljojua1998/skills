---
name: nextjs-craft
description: Next.js App Router full-stack standards — server/client boundaries, the four caching layers, server-action security, route handlers, rendering/streaming, metadata, middleware limits, and Next-specific testing. Loaded on top of react-craft (and alongside backend-craft for server code) when the ticket's stack is Next.js. Use when building any Next.js route, action, or API surface.
user-invocable: false
---

# Next.js Craft

Layered on **react-craft** (don't repeat waterfall/bundle/serialization rules —
deepen them). Next.js is the **full-stack** layer here, so **backend-craft applies
to actions/handlers/DAL** too. **Version-gate first**: read the Next version from
`package.json` — caching defaults differ per major. When unsure, fetch the docs
(`nextjs.org/docs/**/*.md`, index at `/docs/llms.txt`) rather than trusting memory.

## Version deltas that break agent code

- **14**: `fetch` cached by default; GET route handlers static; `params`/`cookies()` sync.
- **15**: `fetch` **uncached** by default; GET handlers **dynamic**; **`params`,
  `searchParams`, `cookies()`, `headers()` are async — `await` them**; React 19;
  `after()`. CVE-2025-29927 fixed in 15.2.3 / 14.2.25.
- **16**: `cacheComponents: true` = PPR stable + `'use cache'`; `middleware.ts` →
  `proxy.ts` (Node runtime); Turbopack default; `updateTag()`/`refresh()`.
- **Rule**: never assume fetch caching — **state cache intent explicitly**
  (`{ cache:'force-cache' }` / `{ next:{ revalidate:N, tags:[...] } }` / `'use cache'`)
  so code is correct on any major. On 15+, always `await` the request APIs.

## CRITICAL — server/client boundary

- Server Components are the default; **`'use client'` only at interactivity leaves**
  (state/effects/handlers/browser APIs) — never on `layout.tsx`/`page.tsx` wholesale.
- `'use client'` is a **boundary, not a marker**: every module a client module
  imports becomes client code. A client component renders server components only via
  `children`/props, never by importing them.
- `import 'server-only'` in every module touching DB/secrets/non-public
  `process.env` (build fails if a client file reaches it).
- **Pass minimal DTOs to client components, never whole DB rows** (the row lands in
  the view-source RSC payload). A client prop typed as a full `User` or containing
  `token`/`passwordHash` is a review flag.

## CRITICAL — the four caching layers

| Layer | Scope | Invalidate |
|---|---|---|
| Request memoization | one render pass (same fetch / `React.cache()` fn) | automatic |
| Data Cache | persistent, **global not per-user** | `revalidateTag/Path`, time `revalidate`, `cache:'no-store'` |
| Full Route Cache | static route HTML+RSC | dynamic APIs / data-cache revalidation |
| Router Cache | client, per segment | `revalidatePath/Tag` or `cookies.set` in an action; `router.refresh()` |

- **Never cache personalized reads without the user in the key/URL** — the Data
  Cache is global (cross-user poisoning). `unstable_cache`/`'use cache'` can't read
  `cookies()`/`headers()` inside — everything read must be in the key.
- A single `cookies()` in the root layout makes **every route dynamic** — read
  cookies as deep/late as possible. Tag cached reads a mutation can invalidate.
- Stale-UI bug: client `fetch('/api/…')` mutation revalidates nothing → use a
  server action + `revalidatePath/Tag`, or `router.refresh()`. Verify caching
  against `next build && next start` — **`next dev` never caches**.

## CRITICAL — server actions are public endpoints

- Every server action is an unauthenticated POST endpoint. Body order, always:
  **(1) authenticate session → (2) authorize THIS resource (ownership, not just
  "logged in") → (3) validate all inputs with zod `safeParse`** (FormData is hostile
  input; TS types are erased at runtime). Then mutate, then `revalidatePath/Tag`.
- Actions are for **mutations only** (never data fetching). File-level `'use server'`
  exposes **every export** — no helper exports from action files.
- `redirect()` throws — call revalidate before it, never wrap it in try/catch.
  Return typed state (`{ ok, error, fieldErrors }`) for `useActionState`; never
  return internal error text. `.bind(null, arg)` args are **not** encrypted —
  re-verify them server-side.

## HIGH — data fetching & streaming

- Fetch on the server in the component that needs it — **never `useEffect`+`fetch`
  for initial page data**. `Promise.all` independent data; `preload()` +
  `React.cache()`d getters; pass a promise + `use()` + Suspense to avoid client
  waterfalls. Wrap DB/ORM reads in `React.cache()` to dedupe.
- `loading.tsx` = route Suspense; add granular `<Suspense>` around each slow
  subtree. **Pitfall (15+)**: a layout reading uncached data / `cookies()` is NOT
  covered by `loading.tsx` and blocks navigation — wrap that read in its own Suspense.

## HIGH — security

- Prefer a **Data Access Layer**: the only place importing the DB/secrets; every
  function derives the current viewer from a `React.cache()`d `getCurrentUser()`
  (reads `cookies()` fresh — never passed as a prop), authorizes before returning,
  returns minimal DTOs.
- **Middleware is NOT the auth layer** (CVE-2025-29927: spoofed header skipped it) —
  and neither is `layout.tsx` (doesn't re-run on soft nav). Real authz lives at the
  DAL/action/page, next to the data. Pin Next ≥15.2.3 / ≥14.2.25.
- `params`/`searchParams`/`[param]`/headers are **user input** — validate; never use
  them as authz signals. SSRF: allowlist user-influenced server `fetch` URLs; no
  unvalidated `redirect(searchParams.next)`.
- **Env**: `NEXT_PUBLIC_*` is inlined into the client bundle — public by definition.
  No secrets there; never rename a secret to `NEXT_PUBLIC_` to fix an
  undefined-in-client bug. Validate env at boot (zod/t3-env).

## MEDIUM — route handlers vs actions

- Server actions for your own UI's mutations. **Route handlers** (`route.ts`) for
  external/protocol contracts: webhooks (verify signature on raw body), OAuth
  callbacks, streaming/SSE (AI SDK), uploads, public REST for third parties/mobile,
  CORS. Handlers get **no automatic CSRF or auth** — do both manually; correct REST
  methods/status. Don't build `app/api/*` that only your own server components call
  (self-fetch waterfall) — call the DAL directly. GET handlers are dynamic by
  default (15+).

## MEDIUM — conventions & SEO

- Per-segment: `loading.tsx`, `error.tsx` (**must be `'use client'`**; place a level
  up to catch a layout's errors), `not-found.tsx`+`notFound()`, `global-error.tsx`,
  route groups `(x)`, parallel `@slot`/intercepting `(.)` for modals. Layouts don't
  remount on sibling nav — no per-request checks there.
- Metadata: static `export const metadata` preferred, else `generateMetadata`
  (its fetch is deduped with the page's). Set `metadataBase` + `title.template` in
  root layout only; file conventions for `opengraph-image`, `sitemap.ts`, `robots.ts`.

## MEDIUM — performance

- `next/image` for content images (`fill`+`sizes` or dims for CLS, `priority` on
  LCP, `remotePatterns`); `next/font` (self-hosted, declared in root layout);
  `next/dynamic` for heavy below-fold; `next/script` strategies for third-party;
  `after()` for post-response work.

## Testing

- Client components / sync server components / zod / utils → Vitest/Jest + RTL.
  **Async server components can't render in jsdom → E2E with Playwright** against
  `next build && next start` (real caching/streaming). Server actions: test as async
  functions (construct FormData, mock the session/DAL, assert returned state +
  that revalidate was called). Route handlers: invoke the exported `GET/POST` with a
  `Request`. E2E the money path, auth flow, and revalidation behavior.

## Checklist additions

- [ ] Fetch/caching intent explicit; no personalized data in a shared cache; verified via `next build && start`.
- [ ] Every server action: session → resource authz → zod, then revalidate; no helper exports from action files.
- [ ] Middleware/layout not used as the auth layer; authz at the DAL; Next pinned ≥15.2.3/14.2.25.
- [ ] Minimal DTOs to client components; `server-only` on DAL modules; no secret in `NEXT_PUBLIC_`.
- [ ] loading/error/not-found present; `<Suspense>` around slow subtrees (incl. layout data reads).
- [ ] Async server components tested via Playwright, not jsdom.
