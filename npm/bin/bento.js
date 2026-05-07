#!/usr/bin/env node
// Tiny shim that hands off to the bentocli binary inside Bento.app.
// The actual CLI is /Applications/Bento.app/Contents/MacOS/bentocli; this shim
// exists so `npm install -g bento-deck` can put a `bento` command on your PATH.
//
// Drift warning behavior (per Phase 2 D5 spec):
//   - One-line dim-grey stderr warning when bento-deck npm version != Bento.app version
//   - Suppressed by BENTO_SUPPRESS_VERSION_CHECK=1
//   - Cached for 24h in ~/Library/Caches/bento/version-check.json
//   - Once per terminal session (tracked via tty fingerprint)
//   - Prefix `bento:` makes it grep-able and visually subordinate to tile output

const { spawnSync } = require("child_process");
const fs = require("fs");
const path = require("path");
const os = require("os");

const candidates = [
  "/Applications/Bento.app/Contents/MacOS/bentocli",
  path.join(os.homedir(), "Applications/Bento.app/Contents/MacOS/bentocli"),
];

const exe = candidates.find(fs.existsSync);
if (!exe) {
  process.stderr.write("Bento.app not found. Run `npm install -g bento-deck` to install, or build from source and run scripts/install-cli.sh.\n");
  process.exit(1);
}

// ---------- version-drift warning (DX C6 + Phase 2 D5) ----------

(function maybeWarnVersionDrift() {
  if (process.env.BENTO_SUPPRESS_VERSION_CHECK === "1") return;

  const pkg = require("../package.json");
  const NPM_VERSION = pkg.version;

  const cacheDir = path.join(os.homedir(), "Library", "Caches", "bento");
  const cachePath = path.join(cacheDir, "version-check.json");
  const ttyId = process.stderr.isTTY ? (process.env.SSH_TTY || process.env.TERM_SESSION_ID || "tty-" + process.ppid) : "non-tty";

  let cache = {};
  try {
    cache = JSON.parse(fs.readFileSync(cachePath, "utf8"));
  } catch {}

  const now = Date.now();
  const last = cache.last_shown_at ? new Date(cache.last_shown_at).getTime() : 0;
  const hours = (now - last) / 3600000;

  // Suppression check: respect manual suppress, OR within the 24h cache window for the same tty session
  if (cache.suppressed_until && new Date(cache.suppressed_until).getTime() > now) return;
  if (hours < 24 && cache.last_shown_tty === ttyId) return;

  // Read installed app's CFBundleShortVersionString via PlistBuddy
  const appPath = exe.replace(/\/Contents\/MacOS\/bentocli$/, "");
  const infoPlist = path.join(appPath, "Contents", "Info.plist");
  if (!fs.existsSync(infoPlist)) return;

  const r = spawnSync("/usr/libexec/PlistBuddy", ["-c", "Print :CFBundleShortVersionString", infoPlist], { encoding: "utf8" });
  if (r.status !== 0) return;
  const APP_VERSION = (r.stdout || "").trim();

  if (!APP_VERSION || APP_VERSION === NPM_VERSION) {
    // No drift; refresh the cache so we don't reread on every invocation today
    try {
      fs.mkdirSync(cacheDir, { recursive: true });
      fs.writeFileSync(cachePath, JSON.stringify({ last_shown_at: new Date().toISOString(), last_shown_tty: ttyId, last_check_result: "match" }));
    } catch {}
    return;
  }

  // Drift detected — emit one-line warning to stderr, dim grey if TTY
  const useColor = process.stderr.isTTY === true && !process.env.NO_COLOR;
  const ESC = "";
  const dim = useColor ? ESC + "[2m" : "";
  const reset = useColor ? ESC + "[0m" : "";

  const msg = "bento: bento-deck " + NPM_VERSION + " (npm) but Bento.app is " + APP_VERSION + ". Run `npm update -g bento-deck` or set BENTO_SUPPRESS_VERSION_CHECK=1.\n";
  process.stderr.write(dim + msg + reset);

  try {
    fs.mkdirSync(cacheDir, { recursive: true });
    fs.writeFileSync(cachePath, JSON.stringify({ last_shown_at: new Date().toISOString(), last_shown_tty: ttyId, last_check_result: "drift", npm: NPM_VERSION, app: APP_VERSION }));
  } catch {}
})();

// ---------- handoff to native CLI ----------

const result = spawnSync(exe, process.argv.slice(2), { stdio: "inherit" });
process.exit(result.status != null ? result.status : 1);
