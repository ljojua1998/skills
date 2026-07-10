---
name: express-craft
description: Express.js (Node) engineering standards — layering, async error handling (Express 4 vs 5), boundary validation, security middleware, graceful shutdown, and testing. Loaded on top of backend-craft when the ticket's stack is Express. Use when building Express APIs.
user-invocable: false
---

# Express Craft

Framework-specific rules on top of `backend-craft`. **Detect the Express major
version first** (v4 vs v5 differ on async errors and routing). Match the project's
existing structure, validation lib and logger before introducing anything new.

## Layering (structure by feature, not by technical role)

- Root folders are domain modules (`orders/`, `users/`), each self-contained —
  not one top-level `controllers/`+`services/`+`models/` for a large app.
- Three tiers inside each module: **web** (routes + controllers, the only layer
  that sees `req`/`res`) → **service** (business logic, framework-agnostic, no
  HTTP) → **repository** (DB queries behind an interface). Web never touches the
  DB; service never imports `express`.
- Controllers stay thin: parse → call service → format response. Require modules
  at file top, never lazily inside handlers.

## Async error handling (version-critical)

- **Express 5 auto-forwards rejected promises** from `async` handlers → `next(err)`.
  No wrapper needed.
- **Express 4 does NOT** — an unhandled rejection leaves the request hanging.
  Wrap: `.catch(next)`, try/catch + `next(err)`, or `express-async-handler`.
  (`express-async-errors` throws under v5 — remove it when migrating.)
- **Callback-based async (`setTimeout`, streams) is auto-caught in NEITHER version**
  — a `throw` inside a bare callback escapes Express and crashes the process; wrap
  in try/catch and call `next(err)`. Sync throws are auto-caught in both.
- **One centralized error middleware, defined LAST, 4-arg** `(err, req, res, next)`:
  log the error, map to a status, return the project's JSON error shape, and
  **never leak `err.stack`/internals to the client** (generic message in prod;
  `NODE_ENV=production` also quiets the default handler). If `res.headersSent`,
  delegate to `next(err)`.
- Custom `ApiError extends Error` with `statusCode` + an `expose` flag; distinguish
  operational errors (respond) from programmer errors (log + crash + restart).
- `process.on('unhandledRejection'|'uncaughtException')` → log + graceful exit
  (not to keep running). Always `await` before `return` for full stack traces.

## Express 5 gotchas (when on v5)

- `req.body` is `undefined` until `express.json()`/`urlencoded()` is added
  (`urlencoded` `extended` now defaults to `false`).
- Path matching (path-to-regexp v8): `'/*'` → `'/*splat'`; inline string regex
  removed → use a path array; wildcard captures are arrays; `req.params` is
  null-prototype. `res.status()` only accepts 100–999.
- Signature fixes: `res.status(s).json(obj)` (not `res.json(obj, s)`),
  `res.redirect(status, url)`, `app.delete` (not `app.del`). Codemod:
  `npx codemod @expressjs/v5-migration-recipe`.

## Input validation at the boundary

- Validate **body, query, params AND headers** at the edge, before business logic.
- Prefer **Zod** for TS projects (infers types, no duplicate interfaces); Joi or
  express-validator are fine if the project uses them. Use a generic
  `validate(schema)` middleware factory — never inline per handler.
- **Use `.safeParse()`, not `.parse()`** (a thrown parse under v4 crashes the
  process). Reject unknown fields (`.strict()`), coerce, and replace `req` values
  with the parsed output.

## Security middleware

- `app.use(helmet())` (CSP, HSTS, no-sniff, frame options) and
  `app.disable('x-powered-by')`.
- CORS with an explicit origin allow-list — never reflect arbitrary `Origin` with
  credentials. Body size limits (`express.json({ limit: '10kb' })`).
- Rate limiting: `express-rate-limit` globally; `rate-limiter-flexible` for auth
  brute-force (by IP + username). `app.set('trust proxy', 1)` behind a proxy.
- Parameterized queries only; no `eval`/dynamic `require`; prefer `execFile` over
  shell. Passwords hashed with bcrypt/argon2. JWTs: verify signature + expiry,
  short-lived access + refresh, with a revocation/blocklist path. Sessions in Redis
  with `httpOnly`+`secure`+`sameSite` cookies (renamed off `connect.sid`).

## Performance

- **Never block the event loop** — no sync fs/crypto/large JSON on hot paths;
  offload CPU work to worker threads/queues. `compression()` (or gzip at the proxy).
- DB **connection pooling** (never a connection per request); avoid N+1 (batch into
  a map); select only needed columns. Cache-aside with Redis + TTL. Stay stateless
  (state in Redis) so you can cluster across cores.

## Graceful shutdown

- On `SIGTERM`/`SIGINT`: **flip readiness (`/readyz` → 503) first** so the LB stops
  routing, then `server.close()` to drain in-flight, close resources in reverse
  order (server → workers → cache → DB), exit. Guard against double-shutdown; add a
  `setTimeout(...).unref()` force-exit safety net.
- `server.close()` ignores idle keep-alive sockets — use
  `server.closeIdleConnections()` (Node 18.2+) or `stoppable`; set
  `server.keepAliveTimeout`. Separate **liveness** vs **readiness** health endpoints.

## Testing

- API/integration tests via **supertest** against the app export (no live port —
  use `port: 0` if you must listen). Runner: `node:test` / Jest / Vitest.
- Test error flows explicitly; mock external HTTP (nock/msw) to simulate failures.
  Per-test data setup, no shared global seeds. AAA structure.

## Checklist additions

- [ ] Async errors handled for the detected Express version; one 4-arg error middleware, no stack leak.
- [ ] Boundary validation with `.safeParse()` on body/query/params; unknown fields rejected.
- [ ] helmet + CORS allow-list + rate limit + body-size limit present.
- [ ] Connection pooling, no N+1, event loop never blocked.
- [ ] SIGTERM graceful shutdown with readiness flip; liveness/readiness endpoints.
