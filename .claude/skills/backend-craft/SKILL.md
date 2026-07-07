---
name: backend-craft
description: Backend engineering standards — API design, layering, database patterns, caching, error handling, auth, background jobs, logging, and the production-readiness checklist. Use when building any server-side code (endpoints, services, models, migrations, jobs).
user-invocable: false
---

# Backend Craft

## API design

- Resource-based URLs, correct HTTP semantics (GET safe/idempotent, POST create,
  PUT/PATCH update, DELETE remove; no state-changing GET).
- Consistent response envelope and **standardized error body** across the API
  (code, message, optional details) — match the project's existing format exactly.
- Correct status codes: 201+Location on create, 400 validation, 401 unauthenticated,
  403 unauthorized, 404 not-found-or-not-yours, 409 conflict, 422 semantic errors.
- Pagination on every collection endpoint (cursor preferred for large/moving data);
  filtering/sorting via query params with an allowlist.
- Version the API the way the project already does; never break a published contract —
  additive changes only, or a new version.

## Code shape

- **Small functions**: one job per function, roughly ≤ 40 lines; if the name needs
  "and", split it. Deep nesting (>3 levels) means extract or invert with early
  returns.
- **Small modules**: one file = one cohesive concern (a resource's routes, one
  service, one model). When a file passes ~300 lines or collects unrelated
  helpers, split it along responsibility lines — never grow god-files
  (`utils.js`, `helpers.py` graveyards included).
- Follow the project's existing granularity — match how it already splits
  routes/services/models rather than inventing a new layout.

## Layering

- Boundary (routes/controllers): parse + validate input, map to/from transport. No business logic.
- Service layer: business rules, orchestration, transactions.
- Data access (repository/ORM): queries only. No HTTP concepts.
- Cross-cutting (auth, logging, rate limiting) as middleware, not copy-paste per route.
- "Choose patterns that fit the complexity level" — don't add layers a small project doesn't have; follow what exists.

## Database

- Migrations for every schema change, reversible where the tool supports it.
- Parameterized queries **only** — string-built SQL is a defect, always.
- Prevent N+1: batch/eager-load for known access patterns; select needed columns, not `*`.
- Index the columns your new queries filter/join/sort on; note the index in the ticket.
- Transactions around multi-step writes; think through concurrent execution
  (uniqueness races, lost updates) — enforce invariants in the DB, not only in code.

## Reliability & performance

- Timeouts + retry with exponential backoff (e.g. 1s/2s/4s) on outbound calls;
  retries only for idempotent operations.
- Cache-aside with explicit TTL for hot reads; name the invalidation path when you cache.
- Rate limiting in a shared store (Redis/gateway) — never per-process memory counters.
- Long work (email, media, third-party syncs) goes to background jobs, not request handlers.
- Target: sensible latency for the endpoint class (p95 < 100–300ms for CRUD); no
  unbounded queries (always LIMIT).

## Security defaults (build-time; the security-auditor will check these)

- Validate and type all input at the boundary (schema validation lib the project uses).
- AuthN on every non-public endpoint; AuthZ = ownership/role checks against the
  resource, not just "is logged in" (IDOR is the classic miss).
- Passwords: bcrypt/argon2 only. Tokens: proper expiry, verified signature/algorithm.
- Secrets from env/secret manager — never hardcoded, never logged, never committed.
- Errors to clients are generic; details go to logs.

## Observability

- Structured logs (JSON where the project does) with request ID and actor context
  for every new operation's success/failure paths; no PII/secrets in logs.

## Production-readiness checklist (run before reporting done)

- [ ] Migrations run cleanly on a fresh DB and on the existing one.
- [ ] New endpoints exercised for real (curl/httpie): happy path, auth failure, invalid input.
- [ ] Tests: new behavior covered (happy + authz failure + validation) and suite green.
- [ ] API contract documented where the project documents it (OpenAPI/README/ticket).
- [ ] Config externalized (env vars documented); no secrets in the diff.
- [ ] Error responses consistent with the project's format.
