#!/usr/bin/env bash
# DevFlow stop-gate: runs as a Stop hook on developer/debugger agents.
# Blocks the agent from finishing while the project's checks fail.
# Exit 0 = pass (or nothing to check), exit 2 = block; stderr is fed back to the agent.

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0

RAN=0

fail() {
  echo "DevFlow gate: '$1' failed — you cannot finish until it passes. Output:" >&2
  echo "$2" | tail -40 >&2
  exit 2
}

run() {
  RAN=1
  local out
  out=$(CI=1 "$@" 2>&1) || fail "$*" "$out"
}

have() { command -v "$1" >/dev/null 2>&1; }

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
elif [ -f pubspec.yaml ]; then
  if have flutter; then
    run flutter analyze --no-pub
    [ -d test ] && run flutter test
  elif have dart; then
    run dart analyze
    [ -d test ] && run dart test
  fi
elif [ -f Cargo.toml ]; then
  have cargo && { run cargo check --quiet; run cargo test --quiet; }
elif [ -f go.mod ]; then
  have go && { run go build ./...; run go test ./...; }
elif [ -x ./gradlew ] || [ -f gradlew ]; then
  run sh ./gradlew --quiet build
elif [ -f pom.xml ]; then
  if [ -x ./mvnw ] || [ -f mvnw ]; then run sh ./mvnw -q test
  elif have mvn; then run mvn -q test; fi
elif ls ./*.sln >/dev/null 2>&1 || ls ./*.csproj >/dev/null 2>&1 || ls ./*/*.csproj >/dev/null 2>&1; then
  have dotnet && { run dotnet build --nologo -v q; run dotnet test --nologo -v q; }
elif [ -f composer.json ]; then
  [ -x vendor/bin/phpunit ] && run vendor/bin/phpunit
elif [ -f Gemfile ]; then
  have bundle && { [ -d spec ] && run bundle exec rspec; [ -d test ] && run bundle exec rake test; }
elif [ -f pyproject.toml ] || [ -f requirements.txt ]; then
  have ruff && run ruff check .
  { [ -d tests ] || [ -d test ]; } && have pytest && run pytest -q
fi

if [ "$RAN" = "0" ]; then
  # Fail LOUD, not silent: the agent (and transcript) must know the gate didn't cover this stack.
  echo "DevFlow gate: no supported checks ran for this stack — the quality gate did NOT verify this work. Run the project's own build/tests manually before reporting done." >&2
fi

exit 0
