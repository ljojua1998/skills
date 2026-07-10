---
name: qa-tooling-craft
description: Headless QA tooling for driving real test tools from the CLI — Postman/Newman (functional + contract), OWASP ZAP + nuclei (security/DAST, the agent-drivable substitute for Burp), and k6/JMeter/autocannon (load). Use when running a comprehensive QA/security/load sweep against a running app.
user-invocable: false
---

# QA Tooling Craft

How to test a running app with real tools **headlessly** — an agent runs commands
and parses machine output, it can't click a GUI. Only run these when there's a
live URL/server to hit; for pure logic, unit/integration tests (testing-craft)
are enough.

## The one rule: gate on exit code, triage from JSON

Every tool here emits an **exit code** (the pass/fail gate) and a
**JSON/XML report** (parse to list *which* things failed, with severity). Never
scrape stdout text for pass/fail. Configure each tool so its exit code already
reflects the gate policy; softer findings go to the report + backlog, not the gate.

## Functional + contract — Postman/Newman

```bash
npm i -g newman
# spec → contract collection (no hand-written assertions):
npx @apideck/portman -l openapi.yaml --output collection.json
newman run collection.json -e env.json -r cli,json,junit \
  --reporter-json-export out/newman.json --timeout-request 30000
```
- Author `pm.test` assertions: status, `jsonSchema` (contract), `responseTime`,
  headers, body fields; chain vars for multi-step flows (auth → create → read → delete).
- **Gate**: Newman exits non-zero on any assertion/request failure — reliable, wire
  straight to pass/fail. Triage `out/newman.json` → `run.failures[]`.

## Security / DAST — OWASP ZAP + nuclei (not Burp)

**Burp is not agent-drivable** (GUI/licensed; Enterprise "DAST" is paid and can't
reset state or emit reports headlessly). Use ZAP + nuclei — same coverage, scriptable.

```bash
# Baseline (passive, prod-safe, every build) — image from GHCR (dockerhub image is deprecated):
docker run --rm -v "$PWD":/zap/wrk/:rw ghcr.io/zaproxy/zaproxy:stable \
  zap-baseline.py -t "$URL" -c zap.conf -J out/zap.json -r out/zap.html
# Full active scan (sends attack payloads — STAGING ONLY):
#   ... zap-full-scan.py -t "$STAGING" -J out/zap.json
nuclei -u "$URL" -severity critical,high,medium -jsonl -o out/nuclei.jsonl
```
- ZAP catches: missing/weak security headers (CSP/HSTS/X-Frame), cookie flags,
  reflected/DOM XSS surface, SQLi surface (active), CORS misconfig, info disclosure,
  TLS issues. Alerts carry risk High/Med/Low/Info.
- **ZAP exit codes**: 0 clean · 1 ≥1 FAIL · 2 ≥1 WARN · 3 error. By default *every*
  alert is WARN (→ exit 2). In `zap.conf`, promote High/Medium rule ids to `FAIL`
  and `IGNORE` the noise (timestamp/version disclosure) so exit 1 = a real gate.
- **nuclei**: don't trust its exit code — **gate on the presence of critical/high
  lines** in `out/nuclei.jsonl` (`info.severity`, `template-id`, `matched-at`).
- **Gate**: High (and recommended Medium) ZAP alerts, any nuclei critical/high →
  FAIL. Low/Info → report only. Active scans staging-only, never prod.

## Load / performance — k6 (preferred), JMeter, autocannon

**k6 is the cleanest for an agent** (thresholds are first-class and set the exit code):
```bash
BASE_URL="$URL" k6 run load.js --summary-export=out/k6.json
```
```js
export const options = {
  stages: [{duration:'30s',target:50},{duration:'1m',target:50},{duration:'30s',target:0}],
  thresholds: {
    http_req_duration: ['p(95)<500'],   // p95 latency SLA
    http_req_failed:   ['rate<0.01'],   // <1% errors
    checks:            ['rate>0.99'],    // checks alone DON'T gate — wrap in a threshold
  },
};
```
- **k6 gate**: a breached **threshold** → non-zero exit → FAIL. `check()`s record
  pass/fail but do NOT affect exit — always back them with a `checks` threshold.
- **JMeter** (when the team already has `.jmx` / needs JDBC/JMS/distributed):
  `jmeter -n -t plan.jmx -l out/results.jtl -e -o out/report/ -Jthreads=100 -Jrampup=60`.
  **JMeter's exit code does NOT reflect SLA/assertion failures** — post-process
  `out/report/statistics.json` (`errorPct`, `pct2ResTime`=p95) and exit non-zero yourself.
- **autocannon** for a 20s smoke: `npx autocannon -c 50 -d 20 -j "$URL" > out/ac.json`
  (no built-in gating — read `.latency.p99`/`.non2xx`).
- **Gate**: error rate > 1%, p95 > SLA, p99 > 2× SLA → FAIL. Throughput trends → report.
  Load-test staging/isolated env, never prod.

## The comprehensive sweep (order by cost/risk)

1. **Functional/contract first** (fast, deterministic) — no point scanning a broken API.
2. **Security** — baseline (passive) always; full active scan staging-only.
3. **Load last** — needs an isolated env for meaningful numbers.

Aggregate all `out/*.json` into one severity-ranked finding list. Build FAILS if:
Newman≠0 OR ZAP==1 OR nuclei has crit/high OR k6≠0. Everything softer → report + backlog.

## Availability

If a tool isn't installed and can't be installed in this environment, say so
explicitly and fall back to what's available (e.g. curl-driven functional checks,
code-level security review) — never report a tool's result you didn't actually run.
