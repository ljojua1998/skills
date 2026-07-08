#!/usr/bin/env node
/**
 * devflow-cc — installer for DevFlow (https://github.com/ljojua1998/skills)
 *
 *   npx devflow-cc init                  install into the current project
 *   npx devflow-cc init --target <dir>   install into a specific project
 *   npx devflow-cc init --global         install for every project (~/.claude)
 *   npx devflow-cc init --force          overwrite files from a previous install
 */
const { execFileSync } = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const REPO = "https://github.com/ljojua1998/skills.git";
const PARTS = ["agents", "skills", "hooks"];

function log(msg) { process.stdout.write(msg + "\n"); }
function die(msg) { process.stderr.write("error: " + msg + "\n"); process.exit(1); }

function parseArgs(argv) {
  const args = { cmd: argv[0] || "init", global: false, force: false, target: process.cwd() };
  for (let i = 1; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--global" || a === "-g") args.global = true;
    else if (a === "--force" || a === "-f") args.force = true;
    else if (a === "--target" || a === "-t") args.target = path.resolve(argv[++i] || die("--target needs a path"));
    else die("unknown option: " + a);
  }
  return args;
}

function copyTree(from, to, force, stats) {
  for (const entry of fs.readdirSync(from, { withFileTypes: true })) {
    const src = path.join(from, entry.name);
    const dst = path.join(to, entry.name);
    if (entry.isDirectory()) {
      fs.mkdirSync(dst, { recursive: true });
      copyTree(src, dst, force, stats);
    } else {
      if (fs.existsSync(dst) && !force) { stats.skipped++; continue; }
      fs.mkdirSync(path.dirname(dst), { recursive: true });
      fs.copyFileSync(src, dst);
      stats.copied++;
    }
  }
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.cmd !== "init") die("unknown command '" + args.cmd + "' — try: npx devflow-cc init");

  try { execFileSync("git", ["--version"], { stdio: "ignore" }); }
  catch { die("git is required (https://git-scm.com)"); }

  const destRoot = args.global ? path.join(os.homedir(), ".claude") : path.join(args.target, ".claude");
  log("");
  log("  DevFlow installer");
  log("  Target : " + destRoot + (args.global ? "  (global)" : "  (project)"));

  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "devflow-"));
  log("  Fetching latest from " + REPO + " ...");
  execFileSync("git", ["clone", "--depth", "1", "--quiet", REPO, tmp], { stdio: "inherit" });

  const stats = { copied: 0, skipped: 0 };
  for (const part of PARTS) {
    const src = path.join(tmp, ".claude", part);
    if (!fs.existsSync(src)) continue;
    const dst = path.join(destRoot, part);
    fs.mkdirSync(dst, { recursive: true });
    copyTree(src, dst, args.force, stats);
  }

  try { fs.rmSync(tmp, { recursive: true, force: true, maxRetries: 3 }); } catch { /* temp dir; OS will clean */ }

  log("  Installed: " + stats.copied + " files" + (stats.skipped ? " (skipped " + stats.skipped + " existing — use --force to overwrite)" : ""));

  if (process.platform === "win32") {
    try { execFileSync("bash", ["--version"], { stdio: "ignore" }); }
    catch {
      log("");
      log("  WARNING: 'bash' is not on PATH. The quality-gate hook needs Git Bash;");
      log("  add your Git\\bin folder to PATH (e.g. C:\\Program Files\\Git\\bin),");
      log("  then restart your terminal — otherwise the stop-gate will not run.");
    }
  }

  log("");
  log("  Done. Open Claude Code in your project and run:");
  log("");
  log('    /ship "describe what you want built"');
  log("");
  log("  Docs: https://ljojua1998.github.io/skills/");
  log("");
}

main();
