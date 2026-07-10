---
name: nestjs-craft
description: NestJS engineering standards — feature-module architecture, DI discipline, DTO validation, the guard/interceptor/pipe/filter split, config, TypeORM/Prisma, and testing. Loaded on top of backend-craft when the ticket's stack is NestJS. Use when building NestJS APIs.
user-invocable: false
---

# NestJS Craft

Framework-specific rules on top of `backend-craft`. Each rule is an
**Anti-pattern → Pattern** pair, ordered by impact. Match the project's existing
module layout, ORM and auth before introducing anything new.

## The highest-leverage snippet: global setup in `main.ts`

Wire these three once, globally — not per route:
```ts
app.useGlobalPipes(new ValidationPipe({
  whitelist: true, forbidNonWhitelisted: true, transform: true,
  transformOptions: { enableImplicitConversion: true },
}));
app.useGlobalInterceptors(new ClassSerializerInterceptor(app.get(Reflector)));
app.useGlobalFilters(new HttpExceptionFilter());
app.enableShutdownHooks();
```

## Module architecture — CRITICAL

- **Organize by feature, not by technical layer.** Each feature module owns its
  controller, service, entities, DTOs, tests in one folder (`src/modules/users/…`).
  Cross-cutting code in `common/` (filters/guards/interceptors/pipes), `config/`.
  Anti: top-level `controllers/`+`services/` with everything in `AppModule`.
- **One module per shared service; `exports` it, `imports` to consume.** Listing a
  provider in every module creates multiple singleton instances (state divergence).
- `@Global()` only for config/logging/DB — never business logic.
- **No circular dependencies** (top cause of runtime crashes). If you reach for
  `forwardRef()`, restructure: extract shared logic to a third module or decouple
  via `EventEmitter2`. Lazy-load rarely-used modules (`LazyModuleLoader`).

## Providers & DI — CRITICAL

- **Constructor injection only** (`private readonly`). Never `new Service()`
  (bypasses the container) or property `@Inject()` on fields (hides deps).
- No service-locator (`moduleRef.get(X)` inside methods) except legitimate dynamic
  factories.
- **Inject interfaces via a token** (interfaces vanish at compile time):
  `const PAYMENT = Symbol('PAYMENT'); @Inject(PAYMENT) private gw: PaymentGateway`.
- **Scopes**: DEFAULT singleton for stateless services (the norm). REQUEST scope
  bubbles up the whole dep tree (perf cost); a singleton holding per-request
  mutable state is a data-leak bug — use `nestjs-cls` for request context, pass
  request data as method params.
- Async init goes in `onModuleInit`/`onApplicationBootstrap` (return the promise) —
  never fire-and-forget in a constructor.

## Controllers thin / services own logic — CRITICAL

- **Controllers are HTTP adapters**: parse input → call one service method →
  return. No conditionals, mapping, DB, or orchestration; never inject repositories
  directly.
- Logic in `@Injectable()` services; a service name with "And" signals a split
  (single responsibility). Layer controller → service → repository.

## DTOs + validation — HIGH

- **DTO per request body with `class-validator` decorators** — never
  `@Body() body: any` or raw `req.body`. `@IsEmail()`, `@Length()`, `@IsEnum()`,
  `@IsOptional()`. The global `ValidationPipe` (above) with
  `whitelist`+`forbidNonWhitelisted`+`transform` enforces it.
- Parse path params with built-in pipes: `@Param('id', ParseUUIDPipe)`,
  `ParseIntPipe`. Sanitize stored HTML (`@Transform`, `sanitize-html`).

## The four constructs — keep each role pure (HIGH)

Pipeline: **Middleware → Guards → Interceptors(pre) → Pipes → Handler →
Interceptors(post) → Exception Filters.**
- **Guards** = authN/authZ only (`JwtAuthGuard` + `RolesGuard` via `APP_GUARD`;
  `@Public()`, `@Roles('admin')`). Coarse access in guards, resource-level authz in
  services. Guards must not transform data.
- **Interceptors** = pure cross-cutting: logging, timing, caching, response
  transform (`ClassSerializerInterceptor`) via `APP_INTERCEPTOR`. No business logic.
- **Pipes** = validation/parsing only. **Exception filters** = error-shape only.
- Anti: diffusing logic across all four (guard transforming, pipe cleaning arrays,
  interceptor mutating state).

## Configuration — HIGH

- `ConfigModule.forRoot({ isGlobal: true, cache: true, validationSchema })` — validate
  the **entire env with Joi/Zod and fail fast at boot**; never boot on invalid config.
- **No scattered `process.env`** — access via `ConfigService` or typed
  `registerAs('db', () => ({...}))` namespaces. No hardcoded secrets, no
  `if (env==='prod')` branching in feature code.

## Error handling — HIGH

- **Services throw typed HTTP exceptions** (`NotFoundException`, `ConflictException`)
  — not `return { error }`. One **global exception filter** for a consistent
  envelope `{ statusCode, path, timestamp, error }`; never `try/catch` +
  `res.json()` in controllers.
- Don't use exceptions as control flow (pollutes error metrics) — model expected
  outcomes as return types. Handle async errors (`.catch` on fire-and-forget,
  try/catch in scheduled tasks, global `unhandledRejection`).

## Database (TypeORM / Prisma) — MEDIUM-HIGH

- **Repository pattern**; services depend on repositories, not raw query builders.
- **Never leak entities to responses** — return response DTOs; `@Exclude()`
  sensitive fields (`password`, tokens) + `ClassSerializerInterceptor`.
- **Migrations always** (version-controlled, run on deploy); **no `synchronize: true`
  in prod**, no manual schema edits. Multi-step writes in transactions
  (`QueryRunner`/`$transaction`). Kill N+1 (eager `relations`/`leftJoin`/DataLoader);
  `select` only needed columns; `@Index` hot columns; paginate. App-wide connection
  pool via `forRoot()`, never per request.

## Security & performance — HIGH

- JWT secret from `ConfigModule`; ~15-min access + ~7-day refresh; payload =
  `sub/email/roles` only (no password/PII); validate expiry + user existence.
- **`@nestjs/throttler` rate limiting from day one** (strict on auth, e.g. 5/min;
  Redis backend when distributed; skip health checks).
- No sync crypto on hot paths (`await bcrypt.hash`, not `hashSync`); offload CPU/long
  work to **queues (Bull/RabbitMQ)** with retry + backoff, respond immediately.
- Structured JSON logging with correlation ids (middleware), sensitive fields
  filtered. Health checks via `@nestjs/terminus`. Graceful shutdown
  (`enableShutdownHooks` + `onApplicationShutdown`). API versioning for breaking changes.

## Testing — MEDIUM-HIGH

- Unit: **`Test.createTestingModule`** overriding providers with mocks
  (`{ provide: getRepositoryToken(User), useValue: mockRepo }`) — never
  `new Service(realDep)`; test behavior.
- **E2E with Supertest over `AppModule`** exercising the full stack (guards/pipes/
  interceptors/serialization), auth via `.set()`, clean DB between tests, reuse the
  production global pipes/filters. Mock all external services (honor the full contract).

## Checklist additions

- [ ] main.ts has the global ValidationPipe (whitelist+forbidNonWhitelisted+transform), ClassSerializerInterceptor, global exception filter, shutdown hooks.
- [ ] Feature-module layout; constructor DI only; no circular deps / forwardRef hacks.
- [ ] Controllers thin (no repos, no logic); services throw typed exceptions.
- [ ] Env validated at boot; no scattered process.env; no hardcoded secrets.
- [ ] Entities never returned raw (DTOs + @Exclude); migrations, no synchronize:true; no N+1.
- [ ] Throttler on; CPU/long work queued; E2E Supertest over the full stack.
