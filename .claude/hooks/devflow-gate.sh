#!/usr/bin/env bash
# DevFlow stop-gate: runs as a Stop hook on developer/debugger agents.
# Blocks the agent from finishing while the project's checks fail.
# Exit 0 = pass (or nothing to check), exit 2 = block; stderr is fed back to the agent.

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0

fail() {
  echo "DevFlow gate: '$1' failed — you cannot finish until it passes. Output:" >&2
  echo "$2" | tail -40 >&2
  exit 2
}

run() {
  local out
  out=$(CI=1 "$@" 2>&1) || fail "$*" "$out"
}

if [ -f package.json ]; then
  pm=npm
  [ -f pnpm-lock.yaml ] && pm=pnpm
  [ -f yarn.lock ] && pm=yarn
  [ -f bun.lockb ] && pm=bun
  for s in typecheck lint test; do
    if node -e "process.exit((require('./package.json').scripts||{})['$s']?0:1)" 2>/dev/null; then
      run "$pm" run -s "$s"
    fi
  done
elif [ -f Cargo.toml ]; then
  run cargo check --quiet
  run cargo test --quiet
elif [ -f go.mod ]; then
  run go build ./...
  run go test ./...
elif [ -f pyproject.toml ] || [ -f requirements.txt ]; then
  command -v ruff >/dev/null 2>&1 && run ruff check .
  { [ -d tests ] || [ -d test ]; } && command -v pytest >/dev/null 2>&1 && run pytest -q
fi

exit 0
