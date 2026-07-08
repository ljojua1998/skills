<#
.SYNOPSIS
  Installs the DevFlow agent system into a project (or globally for all projects).

.USAGE
  # Install into a specific project:
  .\install.ps1 -Target "C:\path\to\your\project"

  # Install into the current directory:
  .\install.ps1

  # Install globally (available in every project on this machine):
  .\install.ps1 -Global

  # Overwrite existing files:
  .\install.ps1 -Target "C:\path\to\project" -Force
#>
param(
    [string]$Target = (Get-Location).Path,
    [switch]$Global,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$Source = $PSScriptRoot

if ($Global) {
    $Target = Join-Path $env:USERPROFILE ".claude"
    $AgentsDest = Join-Path $Target "agents"
    $SkillsDest = Join-Path $Target "skills"
    $HooksDest  = Join-Path $Target "hooks"
} else {
    $ClaudeDir  = Join-Path $Target ".claude"
    $AgentsDest = Join-Path $ClaudeDir "agents"
    $SkillsDest = Join-Path $ClaudeDir "skills"
    $HooksDest  = Join-Path $ClaudeDir "hooks"
}

Write-Host ""
Write-Host "  DevFlow Agent System Installer" -ForegroundColor Cyan
Write-Host "  Source : $Source"
Write-Host "  Target : $Target $(if ($Global) {'(global)'} else {'(project)'})"
Write-Host ""

foreach ($dir in @($AgentsDest, $SkillsDest, $HooksDest)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}

function Copy-Tree($from, $to) {
    Get-ChildItem -Path $from -Recurse -File | ForEach-Object {
        $rel  = $_.FullName.Substring($from.Length).TrimStart('\')
        $dest = Join-Path $to $rel
        $destDir = Split-Path $dest -Parent
        New-Item -ItemType Directory -Force -Path $destDir | Out-Null
        if ((Test-Path $dest) -and -not $Force) {
            Write-Host "  skip (exists): $rel" -ForegroundColor DarkGray
        } else {
            Copy-Item $_.FullName $dest -Force
            Write-Host "  installed    : $rel" -ForegroundColor Green
        }
    }
}

Write-Host "Agents:" -ForegroundColor Yellow
Copy-Tree (Join-Path $Source ".claude\agents") $AgentsDest

Write-Host "Skills:" -ForegroundColor Yellow
Copy-Tree (Join-Path $Source ".claude\skills") $SkillsDest

Write-Host "Hooks:" -ForegroundColor Yellow
Copy-Tree (Join-Path $Source ".claude\hooks") $HooksDest

if (-not (Get-Command bash -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "  WARNING: 'bash' was not found on PATH." -ForegroundColor Yellow
    Write-Host "  The quality-gate hook runs via Git Bash - without it the stop-gate" -ForegroundColor Yellow
    Write-Host "  will NOT enforce checks. Install Git for Windows: https://git-scm.com" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  Done. Open Claude Code in your project and run:" -ForegroundColor Cyan
Write-Host ""
Write-Host '    /ship "describe what you want built"' -ForegroundColor White
Write-Host ""
Write-Host "  Other commands: /board (view progress), /qa, /security-audit, /debug-findings" -ForegroundColor DarkGray
Write-Host ""
