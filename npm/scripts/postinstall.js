#!/usr/bin/env node
// postinstall — downloads Bento.app from the GitHub release for this version,
// verifies SHA-256, extracts to /Applications, removes quarantine, symlinks CLI.
//
// Skips silently on non-Mac platforms so non-darwin npm installs don't fail.
//
// Env vars:
//   BENTO_SKIP_POSTINSTALL=1  — skip download entirely (CI / Docker / restricted networks)
//   BENTO_CLI_DIR=/path        — override symlink target dir (default: /usr/local/bin → ~/.local/bin)
//   HTTPS_PROXY=https://...    — proxy URL for download (also honors HTTP_PROXY)
//   NO_COLOR=1                 — suppress chalk-style color (also honored when !isTTY or CI)

const fs = require("fs");
const path = require("path");
const os = require("os");
const https = require("https");
const http = require("http");
const url = require("url");
const crypto = require("crypto");
const { spawnSync } = require("child_process");

const REPO_ISSUES = "https://github.com/RyanAlberts/bento/issues";
const REPO_INSTALL_DOCS = "https://github.com/RyanAlberts/bento#install";

if (process.platform !== "darwin") {
  console.log("Bento is macOS-only. Skipping postinstall on " + process.platform + ".");
  process.exit(0);
}

if (process.env.BENTO_SKIP_POSTINSTALL === "1") {
  console.log("Skipping Bento.app download (BENTO_SKIP_POSTINSTALL=1).");
  console.log("The bento CLI will not function until you run `bento postinstall` manually,");
  console.log("or install Bento.app via brew/DMG.");
  console.log("Docs: " + REPO_INSTALL_DOCS);
  process.exit(0);
}

const pkg = require("../package.json");
const RELEASE_TAG = pkg.bento.releaseTag;
const ZIP_NAME = pkg.bento.zipName;
const ZIP_SHA256 = pkg.bento.zipSha256;
const REPO = pkg.repository.url
  .replace(/^git\+/, "")
  .replace(/\.git$/, "")
  .replace(/^https:\/\/github\.com\//, "");

const ZIP_URL = "https://github.com/" + REPO + "/releases/download/" + RELEASE_TAG + "/" + ZIP_NAME;

// Per-postinstall isolation (Eng F7): unique temp dir per run so concurrent
// `npm install -g bento-deck` runs on the same box don't share TMP_ZIP.
const TMP_DIR = fs.mkdtempSync(path.join(os.tmpdir(), "bento-install-"));
const TMP_ZIP = path.join(TMP_DIR, ZIP_NAME);

let APP_DEST = "/Applications/Bento.app";
const HOME_APPS = path.join(os.homedir(), "Applications");
const HOME_APP_DEST = path.join(HOME_APPS, "Bento.app");

// ---------- terminal output helpers (Phase 2 D1 spec) ----------

const isTTY = process.stdout.isTTY === true;
const isCI = process.env.CI === "true" || process.env.CI === "1";
const useColor = isTTY && !isCI && !process.env.NO_COLOR;
const useUnicode = (process.env.LC_ALL || process.env.LANG || "").toLowerCase().includes("utf");

const sym = useUnicode
  ? { ok: "✓", fail: "✗", arrow: "↳", warn: "⚠", fillFull: "█", fillEmpty: "░" }
  : { ok: "[OK]", fail: "[FAIL]", arrow: "->", warn: "[WARN]", fillFull: "#", fillEmpty: "." };

const ESC = "";
const ansi = {
  reset: useColor ? ESC + "[0m" : "",
  dim:   useColor ? ESC + "[2m" : "",
  bold:  useColor ? ESC + "[1m" : "",
  green: useColor ? ESC + "[32m" : "",
  red:   useColor ? ESC + "[31m" : "",
  yellow:useColor ? ESC + "[33m" : "",
};

function dim(s)    { return ansi.dim + s + ansi.reset; }
function bold(s)   { return ansi.bold + s + ansi.reset; }
function green(s)  { return ansi.green + s + ansi.reset; }
function red(s)    { return ansi.red + s + ansi.reset; }
function yellow(s) { return ansi.yellow + s + ansi.reset; }

function step(msg) { console.log("  " + sym.arrow + " " + msg); }

// Error message contract (Phase 2 D1 + DX F3): <problem>: <cause>. <fix>. Docs: <url>.
function fail(problem, cause, fix, docsUrl) {
  console.error("");
  console.error(red(sym.fail + " " + problem));
  if (cause) console.error("  " + cause);
  console.error("");
  if (fix) console.error("  " + bold("Fix:") + " " + fix);
  if (docsUrl) console.error("  " + bold("Docs:") + " " + docsUrl);
  cleanupTmp();
  process.exit(1);
}

function cleanupTmp() {
  try { fs.rmSync(TMP_DIR, { recursive: true, force: true }); } catch {}
}

// ---------- progress indicator (Phase 2 D1 spec) ----------

function makeProgressReporter(totalBytes, label) {
  const showProgress = isTTY && !isCI;
  let lastWrite = 0;
  let bytesSeen = 0;
  const startedAt = Date.now();

  return {
    update(chunk) {
      bytesSeen += chunk.length;
      if (!showProgress) return;
      const now = Date.now();
      // ≤ 4Hz throttle, but always render the final tick
      if (now - lastWrite < 250 && (totalBytes === 0 || bytesSeen < totalBytes)) return;
      lastWrite = now;
      const ratio = totalBytes > 0 ? Math.min(1, bytesSeen / totalBytes) : 0;
      const blocks = 20;
      const filled = Math.round(ratio * blocks);
      const bar = sym.fillFull.repeat(filled) + sym.fillEmpty.repeat(blocks - filled);
      const seenMB = (bytesSeen / 1048576).toFixed(1);
      const totalMB = (totalBytes / 1048576).toFixed(1);
      const elapsed = Math.max(0.1, (now - startedAt) / 1000);
      const rate = (bytesSeen / 1048576 / elapsed).toFixed(1);
      const line = "  " + sym.arrow + " " + label.padEnd(20) + " [" + bar + "]  " + seenMB + " / " + totalMB + " MB  (" + rate + " MB/s)";
      process.stdout.write("\r" + line);
    },
    done() {
      if (showProgress) process.stdout.write("\n");
    },
  };
}

// ---------- proxy support (Eng F12 — vendored, no runtime dep) ----------

function getProxyAgent(targetUrl) {
  const proxyUrl = process.env.HTTPS_PROXY || process.env.https_proxy || process.env.HTTP_PROXY || process.env.http_proxy;
  if (!proxyUrl) return undefined;

  const target = url.parse(targetUrl);
  const proxy = url.parse(proxyUrl);

  // NO_PROXY exact-match / suffix-match honored
  const noProxy = (process.env.NO_PROXY || process.env.no_proxy || "").split(",").map(s => s.trim()).filter(Boolean);
  if (noProxy.some(host => target.hostname === host || target.hostname.endsWith("." + host))) {
    return undefined;
  }

  // Minimal CONNECT-tunnel agent: handles HTTPS-target-via-HTTP-proxy, the common
  // corporate-proxy case. Intentionally not a full proxy resolver.
  const tls = require("tls");
  const net = require("net");

  return new https.Agent({
    keepAlive: false,
    createConnection(opts, cb) {
      const proxyClient = net.connect(parseInt(proxy.port || "8080", 10), proxy.hostname, () => {
        const headers =
          "CONNECT " + opts.host + ":" + opts.port + " HTTP/1.1\r\n" +
          "Host: " + opts.host + ":" + opts.port + "\r\n" +
          (proxy.auth ? "Proxy-Authorization: Basic " + Buffer.from(proxy.auth).toString("base64") + "\r\n" : "") +
          "\r\n";
        proxyClient.write(headers);
        let buf = "";
        proxyClient.on("data", function onData(chunk) {
          buf += chunk.toString();
          if (buf.indexOf("\r\n\r\n") !== -1) {
            proxyClient.removeListener("data", onData);
            const status = buf.split(" ")[1];
            if (status !== "200") return cb(new Error("Proxy CONNECT returned HTTP " + status));
            const tlsSocket = tls.connect({ socket: proxyClient, servername: opts.host, ALPNProtocols: ["http/1.1"] }, () => cb(null, tlsSocket));
            tlsSocket.on("error", cb);
          }
        });
        proxyClient.on("error", cb);
      });
      proxyClient.on("error", cb);
    },
  });
}

// ---------- download with retry (Eng F5/F7/F9 + Phase 2 D1) ----------

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

function downloadOnce(targetUrl, destPath, label) {
  return new Promise((resolve, reject) => {
    const opts = url.parse(targetUrl);
    opts.headers = { "User-Agent": "bento-deck/" + pkg.version + " (npm postinstall; +" + REPO_INSTALL_DOCS + ")" };
    const agent = getProxyAgent(targetUrl);
    if (agent) opts.agent = agent;

    const lib = (opts.protocol === "http:" ? http : https);
    const req = lib.get(opts, (res) => {
      if (res.statusCode === 301 || res.statusCode === 302 || res.statusCode === 307 || res.statusCode === 308) {
        if (!res.headers.location) return reject(new Error("Redirect without Location header"));
        res.resume();
        downloadOnce(res.headers.location, destPath, label).then(resolve, reject);
        return;
      }
      if (res.statusCode !== 200) {
        const e = new Error("HTTP " + res.statusCode);
        e.statusCode = res.statusCode;
        res.resume();
        return reject(e);
      }
      const total = parseInt(res.headers["content-length"] || "0", 10);
      const progress = makeProgressReporter(total, label);
      const out = fs.createWriteStream(destPath);
      res.on("data", (chunk) => progress.update(chunk));
      res.pipe(out);
      out.on("finish", () => {
        progress.done();
        out.close(() => resolve());
      });
      out.on("error", (e) => {
        progress.done();
        reject(e);
      });
    });
    req.on("error", reject);
  });
}

async function downloadWithRetry(targetUrl, destPath) {
  // 3 attempts, 1s/4s/16s backoff (capped at 60s).
  // 503s get up to 5 attempts (rate-limit recovery — Eng F9).
  const baseSchedule = [1000, 4000, 16000, 60000, 60000];
  let lastErr;
  let attempts = 3;
  for (let i = 0; i < attempts; i++) {
    try {
      const label = i === 0
        ? "Downloading"
        : "Downloading (attempt " + (i + 1) + "/" + attempts + (lastErr ? ", last: " + (lastErr.code || lastErr.statusCode || lastErr.message) : "") + ")";
      // Clear any partial file from a failed attempt
      try { fs.unlinkSync(destPath); } catch {}
      await downloadOnce(targetUrl, destPath, label);
      return;
    } catch (err) {
      lastErr = err;
      if (err.statusCode === 503 && attempts < 5) attempts = 5;
      if (err.statusCode === 404) throw err; // don't retry 404
      if (i < attempts - 1) {
        await sleep(baseSchedule[Math.min(i, baseSchedule.length - 1)]);
      }
    }
  }
  throw lastErr;
}

// ---------- SHA-256 verify (C1 — security fix; Eng F5 — hash AFTER stream finish) ----------

function sha256OfFile(filePath) {
  return new Promise((resolve, reject) => {
    const h = crypto.createHash("sha256");
    const s = fs.createReadStream(filePath);
    s.on("data", (chunk) => h.update(chunk));
    s.on("end", () => resolve(h.digest("hex")));
    s.on("error", reject);
  });
}

// ---------- install steps ----------

function tryWritable(dir) {
  try { fs.accessSync(dir, fs.constants.W_OK); return true; } catch { return false; }
}

function unzipAndInstall() {
  const stage = fs.mkdtempSync(path.join(TMP_DIR, "stage-"));
  step("Extracting" + " ".repeat(8));
  // ditto -xk preserves the ad-hoc signature; the Apple-blessed unzip
  const ditto = spawnSync("/usr/bin/ditto", ["-xk", TMP_ZIP, stage], { stdio: "inherit" });
  if (ditto.status !== 0) {
    return fail(
      "Extraction failed.",
      "ditto -xk could not extract " + TMP_ZIP + ".",
      "Re-run `npm install -g bento-deck`. If it persists, file an issue at " + REPO_ISSUES + ".",
      REPO_INSTALL_DOCS
    );
  }

  const stagedApp = path.join(stage, "Bento.app");
  if (!fs.existsSync(stagedApp)) {
    return fail(
      "ZIP did not contain Bento.app.",
      "The release archive at " + ZIP_URL + " is malformed.",
      "File an issue at " + REPO_ISSUES + " with the bento-deck version (" + pkg.version + ").",
      REPO_INSTALL_DOCS
    );
  }

  // Decide install location
  if (!tryWritable("/Applications")) {
    step("/Applications not writable, using ~/Applications");
    if (!fs.existsSync(HOME_APPS)) fs.mkdirSync(HOME_APPS, { recursive: true });
    APP_DEST = HOME_APP_DEST;
  }

  if (fs.existsSync(APP_DEST)) {
    step("Removing existing " + APP_DEST);
    spawnSync("/bin/rm", ["-rf", APP_DEST]);
  }

  step("Installing to     " + APP_DEST);
  const mv = spawnSync("/bin/mv", [stagedApp, APP_DEST], { stdio: "inherit" });
  if (mv.status !== 0) {
    return fail(
      "Install failed.",
      "Could not move staged Bento.app to " + APP_DEST + ".",
      "Re-run `npm install -g bento-deck`. If on a read-only filesystem, set BENTO_CLI_DIR or build from source.",
      REPO_INSTALL_DOCS
    );
  }

  // Strip quarantine so Gatekeeper does not prompt
  spawnSync("/usr/bin/xattr", ["-dr", "com.apple.quarantine", APP_DEST]);

  return symlinkCli();
}

function symlinkCli() {
  const cliTarget = path.join(APP_DEST, "Contents/MacOS/bentocli");

  // CLI symlink path resolution (DX F10 — BENTO_CLI_DIR; Phase 2 D10 — ~/.local/bin fallback)
  let symlinkDir;
  let dirSource;
  if (process.env.BENTO_CLI_DIR) {
    symlinkDir = process.env.BENTO_CLI_DIR;
    dirSource = "BENTO_CLI_DIR";
  } else if (tryWritable("/usr/local/bin")) {
    symlinkDir = "/usr/local/bin";
    dirSource = "default";
  } else {
    symlinkDir = path.join(os.homedir(), ".local", "bin");
    dirSource = "fallback";
    if (!fs.existsSync(symlinkDir)) fs.mkdirSync(symlinkDir, { recursive: true });
  }

  const symlinkPath = path.join(symlinkDir, "bento");

  try {
    const st = fs.lstatSync(symlinkPath);
    if (st) fs.unlinkSync(symlinkPath);
  } catch {}

  try {
    fs.symlinkSync(cliTarget, symlinkPath);
    step("Linking CLI       " + symlinkPath + " " + sym.arrow + " bentocli");
  } catch (err) {
    console.log("");
    console.log(yellow(sym.warn + " Could not symlink to " + symlinkPath + " (need sudo?)."));
    console.log("  The npm shim still points at Bento.app via npm's bin/.");
    console.log("  To get a `bento` command on PATH manually:");
    console.log("");
    console.log("    " + bold("sudo ln -sf " + cliTarget + " /usr/local/bin/bento"));
    console.log("");
    return successBlock(symlinkPath, false, dirSource);
  }

  // PATH check (Phase 2 D10): warn if symlinkDir is not on PATH
  const pathDirs = (process.env.PATH || "").split(":");
  if (!pathDirs.includes(symlinkDir)) {
    console.log("");
    console.log(yellow(sym.warn + " " + symlinkDir + " is not on your PATH."));
    console.log("  Add this to your shell profile (~/.zshrc):");
    console.log("");
    console.log("    " + bold("export PATH=\"" + symlinkDir + ":$PATH\""));
    console.log("");
    console.log("  Then `source ~/.zshrc` (or open a new terminal).");
    console.log("");
  }

  return successBlock(symlinkPath, true, dirSource);
}

function successBlock(symlinkPath, cliOnPath, dirSource) {
  console.log("");
  console.log(green(sym.ok + " Bento " + pkg.version + " installed."));
  console.log("");
  console.log(bold("Next:"));
  console.log("  Open it          " + dim("open " + APP_DEST));
  console.log("  Press the hotkey " + bold("⌃⌘B") + dim("   (Control + Command + B)"));
  if (cliOnPath) {
    console.log("  Run a tile       " + dim("bento press dark"));
    console.log("  See all CLI args " + dim("bento --help"));
  }
  console.log("");
  // Per Final Approval Decision 2 (manual-only updates): no daily check, no consent prompt.
  console.log(bold("Updates") + "  Manual via Bento " + sym.arrow + " Check for Updates… (no automatic checks).");
  console.log("");
  console.log(bold("Docs") + "   " + REPO_INSTALL_DOCS);
  console.log(bold("⭐") + "      A star helps a small indie ship more.");
  console.log("");
  cleanupTmp();
  return 0;
}

// ---------- main ----------

async function main() {
  console.log("");
  console.log(bold("Bento install · v" + pkg.version));
  step("Resolving release  " + dim(ZIP_URL));

  try {
    await downloadWithRetry(ZIP_URL, TMP_ZIP);
  } catch (err) {
    if (err.statusCode === 404) {
      return fail(
        "Release artifact not found (HTTP 404).",
        "url: " + ZIP_URL,
        "The release for v" + pkg.version + " may not be published yet. Try `npm install -g bento-deck@latest`.",
        REPO_INSTALL_DOCS
      );
    }
    if (err.statusCode === 503) {
      return fail(
        "GitHub release server is rate-limited (HTTP 503).",
        "Anonymous downloads are limited to 5000/hour per IP. 5 retry attempts exhausted.",
        "Wait ~1 hour and re-run, or set up a GitHub auth token via the gh CLI.",
        REPO_INSTALL_DOCS
      );
    }
    return fail(
      "Download failed.",
      "After retries: " + (err.message || err.code || "unknown error"),
      "Check your network connection. Set HTTPS_PROXY=<url> if you're behind a proxy. Or build from source.",
      REPO_INSTALL_DOCS
    );
  }

  // C1 — SHA-256 verification (security-critical; gates extraction)
  const computed = await sha256OfFile(TMP_ZIP);
  if (computed.toLowerCase() !== ZIP_SHA256.toLowerCase()) {
    return fail(
      "SHA-256 mismatch.",
      "expected " + ZIP_SHA256 + "\n  got      " + computed + "\n\n  This usually means the release artifact was tampered or the network injected an error.",
      "Re-run `npm install -g bento-deck`. If it persists, file an issue at " + REPO_ISSUES + ".",
      REPO_INSTALL_DOCS
    );
  }
  console.log("  " + sym.arrow + " " + "Verifying SHA-256".padEnd(20) + " " + green(sym.ok) + " " + dim(computed.slice(0, 4) + "…" + computed.slice(-4)));

  return unzipAndInstall();
}

process.on("SIGINT", () => { cleanupTmp(); process.exit(130); });
process.on("uncaughtException", (err) => {
  console.error(red("Unexpected error: " + (err.stack || err.message)));
  cleanupTmp();
  process.exit(1);
});

main().catch((err) => {
  console.error(red("Unexpected error: " + (err.stack || err.message)));
  cleanupTmp();
  process.exit(1);
});
