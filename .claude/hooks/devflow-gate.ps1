# DevFlow stop-gate — PowerShell twin of devflow-gate.sh for environments
# without Git Bash (manual runs, Windows CI). Same contract:
# exit 0 = pass / nothing to check, exit 2 = block with reasons on stderr.

$ErrorActionPreference = "Continue"
if ($env:CLAUDE_PROJECT_DIR) { Set-Location $env:CLAUDE_PROJECT_DIR }

$script:Ran = $false

function Invoke-Check([string]$Label, [scriptblock]$Cmd) {
    $script:Ran = $true
    $env:CI = "1"
    $out = & $Cmd 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        [Console]::Error.WriteLine("DevFlow gate: '$Label' failed - you cannot finish until it passes. Output:")
        [Console]::Error.WriteLine(($out -split "`n" | Select-Object -Last 40) -join "`n")
        exit 2
    }
}

function Test-Cmd([string]$Name) { $null -ne (Get-Command $Name -ErrorAction SilentlyContinue) }

if (Test-Path package.json) {
    $pm = "npm"
    if (Test-Path pnpm-lock.yaml) { $pm = "pnpm" }
    if (Test-Path yarn.lock)      { $pm = "yarn" }
    if (Test-Path bun.lockb)      { $pm = "bun" }
    $scripts = (Get-Content package.json -Raw | ConvertFrom-Json).scripts
    foreach ($s in @("typecheck", "lint", "test")) {
        if ($scripts -and $scripts.PSObject.Properties[$s]) {
            Invoke-Check "$pm run $s" { & $pm run -s $s }
        }
    }
}
elseif (Test-Path pubspec.yaml) {
    if (Test-Cmd flutter) {
        Invoke-Check "flutter analyze" { flutter analyze --no-pub }
        if (Test-Path test) { Invoke-Check "flutter test" { flutter test } }
    }
}
elseif (Test-Path Cargo.toml) {
    if (Test-Cmd cargo) {
        Invoke-Check "cargo check" { cargo check --quiet }
        Invoke-Check "cargo test"  { cargo test --quiet }
    }
}
elseif (Test-Path go.mod) {
    if (Test-Cmd go) {
        Invoke-Check "go build" { go build ./... }
        Invoke-Check "go test"  { go test ./... }
    }
}
elseif ((Test-Path gradlew) -or (Test-Path gradlew.bat)) {
    Invoke-Check "gradlew build" { .\gradlew.bat --quiet build }
}
elseif (Test-Path pom.xml) {
    if (Test-Path mvnw.cmd) { Invoke-Check "mvnw test" { .\mvnw.cmd -q test } }
    elseif (Test-Cmd mvn)   { Invoke-Check "mvn test"  { mvn -q test } }
}
elseif ((Get-ChildItem -Filter *.sln -ErrorAction SilentlyContinue) -or (Get-ChildItem -Recurse -Depth 1 -Filter *.csproj -ErrorAction SilentlyContinue)) {
    if (Test-Cmd dotnet) {
        Invoke-Check "dotnet build" { dotnet build --nologo -v q }
        Invoke-Check "dotnet test"  { dotnet test --nologo -v q }
    }
}
elseif ((Test-Path pyproject.toml) -or (Test-Path requirements.txt)) {
    if (Test-Cmd ruff) { Invoke-Check "ruff check" { ruff check . } }
    if (((Test-Path tests) -or (Test-Path test)) -and (Test-Cmd pytest)) { Invoke-Check "pytest" { pytest -q } }
}

if (-not $script:Ran) {
    [Console]::Error.WriteLine("DevFlow gate: no supported checks ran for this stack - the quality gate did NOT verify this work. Run the project's own build/tests manually before reporting done.")
}

exit 0
