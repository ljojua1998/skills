---
name: python-craft
description: Python backend engineering standards — FastAPI (primary), Django, Flask; async correctness, Pydantic v2, SQLAlchemy 2.0, DI, config, and modern tooling (ruff/mypy/uv). Loaded on top of backend-craft when the ticket's stack is Python. Use when building Python APIs.
user-invocable: false
---

# Python Craft

Framework-specific rules on top of `backend-craft`, distilled from
`zhanymkanov/fastapi-best-practices` and modern Python 3.11+ standards. **Read
`pyproject.toml` first** — python-version, line length, ruff rules, type checker
and layout there are the source of truth; if `ruff` passes, the style is accepted.
Detect the framework (FastAPI / Django / Flask) and match the project. Tags below:
**[FA]** FastAPI · **[DJ]** Django · **[FL]** Flask · **[PY]** universal.

## Structure & layering

- **[PY] `src/` layout** — code in `src/<package>/`, tests in `tests/`, config in
  `pyproject.toml`; never code at repo root.
- **[FA] Organize by domain**, not by file type: each domain package has
  `router.py`, `schemas.py`, `models.py`, `service.py`, `dependencies.py`,
  `exceptions.py`. Layer router → service → repository → model; schemas (DTOs) are
  separate from ORM models. No deep cross-domain imports.
- **[DJ]** Thin views → serializers (I/O) → services (writes) → selectors (reads);
  logic out of fat views/models. **[FL]** App-factory (`create_app(config)`) +
  blueprints; extensions at module level, bound via `init_app`.

## Async correctness (highest-value FastAPI category)

- **[FA] Never block the event loop in `async def`** — one blocking call
  (`time.sleep`, sync `requests`, sync ORM) freezes the whole loop for every
  request. Decision matrix:
  - async I/O libs available → `async def`
  - only blocking calls, no async equivalent → **`def`** (FastAPI runs it in the threadpool)
  - mostly async + one blocking call → `async def` + `await run_in_threadpool(fn, ...)`
  - CPU-heavy (>~50ms) → offload to a worker queue (Celery/Arq/RQ), not threads (GIL)
- No sync ORM in async context — use SQLAlchemy 2.0 async. Starlette's threadpool
  is ~40 threads; saturating it degrades all sync routes.
- **[FA] `BackgroundTasks`** only for <1s, in-process, droppable work (email, log);
  anything needing retries/durability → a real queue.

## Pydantic v2 (request/response models)

- **[FA] Never return ORM models directly — declare `response_model`** (+ `status_code`,
  `responses={}`) on every route. Don't add your own serialization on top (FastAPI
  already validates against `response_model`).
- Use built-in validators/fields: `EmailStr`, `AnyUrl`, `StrEnum`,
  `Field(min_length=, ge=, le=, pattern=)`. Never combine a constraint with a
  conflicting default (`Field(ge=18, default=None)` — pick required or optional).
- v2 API: `@field_validator`/`@model_validator` (not `@validator`),
  `@field_serializer` (not deprecated `json_encoders`), `model_config =
  ConfigDict(from_attributes=True)` (not `orm_mode`/inner `Config`). Raising
  `ValueError` in a validator → FastAPI returns a 422.

## Dependency injection [FA]

- Modern form: **`Annotated[T, Depends(...)]`** (not legacy default-arg `= Depends()`).
- Use dependencies for validation too (exists/owned checks), and **chain** small
  deps — FastAPI caches a dep's result within one request. Prefer `async` deps.
- **DB session per request via a `yield` dependency** (below).

## Database (SQLAlchemy 2.0 async + Alembic)

- **[FA] Async engine + `async_sessionmaker` created ONCE at startup** (`lifespan`),
  reused — never per request (connection exhaustion). `expire_on_commit=False`.
  Session per request:
  `async def get_db(): async with async_session_maker() as s: yield s`.
- Configure the pool (`pool_size`, `max_overflow`, `pool_recycle`). Eager-load with
  `selectinload()`/`joinedload()` — never lazy-load in a loop.
- **[DJ] DRF does NOT auto-optimize** — use `select_related()` (FK/1-1) and
  `prefetch_related()` (M2M/reverse) in `get_queryset()`; nested serializers without
  prefetch are classic N+1.
- Migrations: Alembic (static, reversible); snake_case singular table names;
  explicit constraint naming convention so autogenerate is stable.

## Auth & security

- **[FA] JWT with `PyJWT` (`import jwt`), NOT the unmaintained `python-jose`.**
  OAuth2 password flow (`OAuth2PasswordBearer`), short-lived access + refresh,
  verify signature + `exp` every request via a dependency.
- **[PY] Password hashing: argon2id preferred** (`pwdlib`/`argon2-cffi`); bcrypt
  truncates at 72 bytes. Never store plaintext, never log passwords/tokens.
  **[DJ]** use `django.contrib.auth` hashers + SimpleJWT.
- **[FA] CORS: explicit origins — never `allow_origins=["*"]` in prod.** Rate limit
  (slowapi) with a Redis backend for multi-instance. Hide docs outside safe envs
  (`openapi_url=None`). No `eval`/`exec` on untrusted input; `pathlib` not `os.path`.

## Config [FA/PY]

- **`pydantic-settings` `BaseSettings`** — type-safe, no scattered `os.getenv`.
  Split settings by domain (not one monolith); typed DSNs (`PostgresDsn`,
  `RedisDsn`). No hardcoded secrets, never commit `.env`. **[DJ]** split settings
  module + `django-environ`, `DEBUG=False` in prod, `manage.py check --deploy`.

## Error handling

- **[FA] Raise `HTTPException`/domain exceptions + register global handlers** for a
  consistent envelope (error, code, timestamp, path, details + correlation id).
  Override `RequestValidationError` to control the 422 shape. Per-domain exception
  classes mapped to status. **[PY] No bare `except:`, no silent swallow, no overly
  broad `except`.**

## Logging

- **[PY] Structured JSON logs** (structlog): one event per request (method, path,
  status, latency), enriched with trace/correlation id echoed in error responses.
  Never log secrets/PII. Config via logging setup, not scattered `print`.

## Testing

- **[FA] `httpx.AsyncClient` + `ASGITransport(app=app)`**, `@pytest.mark.asyncio`
  (avoid unmaintained `async_asgi_testclient`; `TestClient` ok for sync routes).
  Override deps (`app.dependency_overrides[dep] = fake`), don't monkeypatch internals.
- **Integration tests hit a real (test-container/rollback) DB — don't mock the DB.**
  pytest fixtures/parametrize; ≥80% coverage; test the seam, not internals.

## Tooling & type hints [PY]

- **Ruff** (replaces black/isort/flake8): `ruff check --fix && ruff format`.
  Type-check with mypy (or `ty`); type hints on all functions.
- **Modern syntax (mandatory):** `X | None` (not `Optional`); lowercase generics
  `list[str]`/`dict[str,int]`; ABCs from `collections.abc`. **Forbidden:** importing
  `List/Dict/Optional/Union` from `typing`. `uv` or Poetry; single `pyproject.toml`.
- No mutable default args.

## Checklist additions

- [ ] No blocking call in `async def`; sync SDKs wrapped in `run_in_threadpool`; heavy work queued.
- [ ] `response_model` on every route; ORM models never returned raw; Pydantic v2 API.
- [ ] `Annotated[..., Depends()]`; DB engine created once, session-per-request via yield.
- [ ] PyJWT (not python-jose); argon2id hashing; CORS not `*`; secrets from pydantic-settings.
- [ ] Global exception handlers with a consistent envelope; no bare/broad except.
- [ ] ruff + mypy clean; modern type-hint syntax; async httpx tests against a real DB.
