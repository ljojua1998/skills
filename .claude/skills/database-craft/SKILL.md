---
name: database-craft
description: Database engineering standards for PostgreSQL, MySQL, MongoDB, Supabase and Firebase/Firestore — schema/index design, security, and the per-engine gotchas an agent gets wrong. Loaded on top of backend-craft when a ticket touches the database. Use when designing schema, queries, migrations or data-access.
user-invocable: false
---

# Database Craft

Standards for the five supported databases. **Use the engine the project already
uses; for greenfield, pick per the decision matrix and record it.** Read only the
section for the engine in play, plus Universal.

## Decision matrix

| Need | Pick |
|---|---|
| Relational integrity, transactions, complex queries, JSON+relational | **PostgreSQL** |
| Existing MySQL ecosystem / managed read-heavy web app | **MySQL** |
| Flexible docs, access-pattern-shaped aggregates, horizontal scale | **MongoDB** |
| Postgres + auth/realtime/storage, client-direct, fast MVP | **Supabase** |
| Mobile/web realtime + offline, minimal ops, client-direct | **Firestore** |

## Universal (every engine)

- **Parameterized queries only** — never concatenate user input (SQL *or* NoSQL
  operator injection). This is the #1 injection defense.
- **Migrations in version control** — every schema change is a checked-in,
  reviewable, forward-only file; never mutate prod schema by hand. Expand → migrate
  → contract for zero-downtime (never drop/rename a column in the same deploy that
  stops using it).
- **No secrets in code**; **least-privilege runtime role** (DML only, separate from
  the DDL/migration role); **connection pooling** (never a connection per request;
  serverless → external transaction-mode pooler).
- **Index every column you filter/join/sort on**; **no `SELECT *`**; avoid N+1
  (JOIN / `IN (...)` batch / eager-load, never query-in-a-loop); statement +
  pool-acquire timeouts; automated backups with a *tested* restore.

## PostgreSQL

- Types are constraints: money → `numeric(12,2)` (never float); time → `timestamptz`
  (UTC); ids → `bigint GENERATED ALWAYS AS IDENTITY` for internal, **UUIDv7** (not
  v4 — v4 destroys B-tree locality) for public/distributed. Never `serial`.
- **Index FK columns — Postgres does NOT auto-index them** (unindexed FK = slow
  joins + heavy locks on parent delete). Push integrity into the DB: FK with
  explicit `ON DELETE`, `UNIQUE` (partial for soft-delete: `... WHERE deleted_at IS NULL`),
  `CHECK`, `NOT NULL`.
- Indexes: composite order = (equality cols, then range/sort); `INCLUDE` for
  covering/index-only; partial for subsets; **GIN** for JSONB/`@>`/full-text/trigram
  (`ILIKE '%x%'` can't use btree); expression index must match the query's function.
  Build with `CREATE INDEX CONCURRENTLY` on live tables.
- Pool small (5–10/instance); serverless → pgbouncer/Supavisor **transaction mode**
  (prepared statements need pgbouncer ≥1.21 / Supavisor 1.0, else disable them in
  the driver). `EXPLAIN (ANALYZE, BUFFERS)` — watch for Seq Scan on big tables,
  estimate/actual divergence (→ `ANALYZE`), disk sorts. Short transactions; prevent
  lost updates with `FOR UPDATE` or a version column; retry `40001` on SERIALIZABLE.

## MySQL (8.x, InnoDB)

- **InnoDB always**; **`utf8mb4`** charset+collation at DB/table/connection (plain
  `utf8` is a 3-byte trap that corrupts emoji). Verify **strict `sql_mode`** (else
  silent truncation).
- InnoDB clusters rows on the PK → PK must be **small + monotonic**
  (`BIGINT UNSIGNED AUTO_INCREMENT`; if UUID, ordered/v7 as `BINARY(16)` not
  `CHAR(36)`); every secondary index carries the PK.
- **Respect what MySQL lacks vs Postgres**: no partial indexes, no `INCLUDE`, no
  `RETURNING` (use `LAST_INSERT_ID()`), no `ILIKE`, CHECK only 8.0.16+, DDL is
  **non-transactional** (a failed migration can leave partial state — keep them
  small; use online DDL / gh-ost for big tables). **Can't index a JSON column
  directly** — add a generated column and index that.

## MongoDB

- **Model around query/access patterns, not entities.** Embed when read-together,
  owned, and **bounded**; reference when shared, large, or unbounded. **Never embed
  an unbounded array** (16MB doc cap) — use referencing/bucket pattern. Avoid deep
  nesting.
- **Compound index = ESR order (Equality, Sort, Range).** Verify with
  `explain("executionStats")`: want `IXSCAN`, no `SORT` stage. TTL indexes for
  expiry; partial/unique where needed.
- Aggregation: `$match`/`$project` first (before `$group`/`$lookup`/`$sort`); use
  `$lookup` sparingly and index the foreign field. Enable collection-level
  `$jsonSchema` validation (Mongoose validation alone is bypassable); `.lean()` for
  read-only. Cache the client in serverless (never connect per request); avoid N+1
  `.populate()` in loops. Transactions need a replica set — prefer single-document
  atomicity.
- **Security**: enable auth (never expose an unauthenticated instance — classic
  breach); reject `$`/`.` in user-supplied field names (NoSQL injection); TLS;
  private network.

## Supabase (Postgres + Auth/Realtime/Storage) — read §PostgreSQL too

The client talks to the DB **directly from the browser**; **Row Level Security is
the only thing protecting your data**. RLS misconfig is the #1 Supabase failure.

- **RULE 0: enable RLS on EVERY table in an exposed schema.** RLS off = the table is
  world-readable/writable via the auto REST API. RLS on with no policy = deny-all
  (safe); then add policies. Verify with the Security Advisor.
- **Keys**: publishable/anon key → client (RLS enforced); **secret/service_role key
  → server ONLY, bypasses ALL RLS** — never in client code, a `NEXT_PUBLIC_`/
  `VITE_`/`EXPO_PUBLIC_` var, or a repo. Do privileged work in edge functions.
- **Policies**: one per operation (SELECT/INSERT/UPDATE/DELETE); `USING` filters
  existing rows, `WITH CHECK` validates written rows (INSERT needs WITH CHECK;
  UPDATE needs both — or users reassign ownership). Wrap as **`(select auth.uid())`**
  (cached once/query, not per row) and **index the policy columns** (`user_id`).
  Role/team checks via a `SECURITY DEFINER` helper (avoids recursive-RLS errors).
- Migrations via the Supabase CLI (`supabase/migrations/`, checked in);
  `supabase gen types typescript` on every schema change (commit it). Storage buckets
  have their own policies — default private + signed URLs. Realtime respects RLS —
  confirm the table's policies actually restrict rows before publishing changes.

## Firebase / Firestore

- **Security Rules are the authorization layer — deny by default, grant narrowly.**
  Validate auth + shape + immutability (`request.auth.uid`, `.diff().affectedKeys()`,
  custom claims for roles — never a client-writable role field). **Rules are not
  filters**: a broad query that returns docs the rules forbid *fails*, so constrain
  queries to match rules. `get()`/`exists()` in rules cost billed reads — minimize.
- **Model for reads; denormalize** (no joins — fan-out writes to keep copies
  consistent). Subcollections keep parent docs small; cross-parent needs a
  collection-group query + composite index. Avoid >1MB docs, unbounded arrays, and
  monotonic-ID write hotspots (use random IDs; distributed counters for hot counts).
- **Cost is per operation, not per byte** — always `limit()`. **No `offset()`
  pagination** (it reads+bills skipped docs) — use cursor `startAfter(lastDoc)`.
  Use aggregation `count()/sum()/avg()` instead of reading all docs. Composite
  queries need a committed composite index (`firestore.indexes.json`).
- **Admin SDK bypasses all rules → server-only**; never ship service-account creds
  to a client/repo. App Check to block non-app clients. Default to Firestore over
  RTDB (RTDB only for presence/high-frequency ephemeral state).

## Checklist additions

- [ ] Parameterized queries; least-privilege role; pooling; migrations in VC; indexes on filter/join/sort cols; no SELECT *; N+1 checked.
- [ ] PG: FK columns indexed; correct types (timestamptz/numeric); UUIDv7 not v4.
- [ ] MySQL: utf8mb4 + strict mode; no assumption of partial-index/INCLUDE/RETURNING; JSON via generated column.
- [ ] Mongo: no unbounded embedded arrays; ESR index order; auth on; NoSQL-injection-safe.
- [ ] Supabase: RLS enabled on every exposed table with per-op policies (USING+WITH CHECK), (select auth.uid()) + indexed; service_role never client-side; Advisor checked.
- [ ] Firestore: deny-by-default rules validating auth+shape; cursor (not offset) pagination; limit() everywhere; Admin SDK server-only.
