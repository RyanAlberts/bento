#!/usr/bin/env node
// postinstall — downloads Bento.app from the GitHub release for this version,
// extracts to /Applications, removes quarantine, and symlinks the CLI.
//
// Skips silently on non-Mac platforms so non-darwin npm installs don't fail.

const fs = require("fs");
const path = require("path");
const os = require("os");
const https = require("https");
const { execSync, spawnSync } = require("child_process");

if (process.platform !== "darwin") {
  console.log("Bento is macOS-only. Skipping postinstall on " + process.platform + ".");
  process.exit(0);
}

const pkg = require("../package.json");
const RELEASE_TAG = pkg.bento.releaseTag;
const ZIP_NAME = pkg.bento.zipName;
const REPO = pkg.repository.url
  .replace(/^git\+/, "")
  .replace(/\.git$/, "")
  .replace(/^https:\/\/github\.com\//, "");

const ZIP_URL = "https://github.com/" + REPO + "/releases/download/" + RELEASE_TAG + "/" + ZIP_NAME;
const TMP_ZIP = path.join(os.tmpdir(), ZIP_NAME);

let APP_DEST = "/Applications/Bento.app";
const HOME_APPS = path.join(os.homedir(), "Applications");
const HOME_APP_DEST = path.join(HOME_APPS, "Bento.app");

console.log("Downloading " + ZIP_URL);

function download(url, dest, redirectsLeft = 5, cb) {
  https.get(url, (res) => {
    if (res.statusCode === 301 || res.statusCode === 302) {
      if (redirectsLeft <= 0) return cb(new Error("Too many redirects"));
      return download(res.headers.location, dest, redirectsLeft - 1, cb);
    }
    if (res.statusCode !== 200) {
      return cb(new Error("HTTP " + res.statusCode + " — release artifact not found yet?"));
    }
    const out = fs.createWriteStream(dest);
    res.pipe(out);
    out.on("finish", () => out.close(() => cb(null)));
    out.on("error", cb);
  }).on("error", cb);
}

function tryWritable(dir) {
  try { fs.accessSync(dir, fs.constants.W_OK); return true; } catch { return false; }
}

function unzipAndInstall(callback) {
  // ditto preserves the ad-hoc signature; the ditto -xk pair is the Apple-blessed unzip
  console.log("Extracting to staging area");
  const stage = fs.mkdtempSync(path.join(os.tmpdir(), "bento-stage-"));
  const ditto = spawnSync("/usr/bin/ditto", ["-xk", TMP_ZIP, stage], { stdio: "inherit" });
  if (ditto.status !== 0) return callback(new Error("ditto -xk failed"));

  const stagedApp = path.join(stage, "Bento.app");
  if (!fs.existsSync(stagedApp)) return callback(new Error("ZIP did not contain Bento.app"));

  // Decide install location
  if (!tryWritable("/Applications")) {
    console.log("/Applications is not writable, falling back to ~/Applications");
    if (!fs.existsSync(HOME_APPS)) fs.mkdirSync(HOME_APPS, { recursive: true });
    APP_DEST = HOME_APP_DEST;
  }

  // Replace any existing install
  if (fs.existsSync(APP_DEST)) {
    console.log("Removing existing " + APP_DEST);
    spawnSync("/bin/rm", ["-rf", APP_DEST]);
  }

  console.log("Installing to " + APP_DEST);
  const mv = spawnSync("/bin/mv", [stagedApp, APP_DEST], { stdio: "inherit" });
  if (mv.status !== 0) return callback(new Error("mv into " + APP_DEST + " failed"));

  // Strip quarantine so Gatekeeper does not prompt
  spawnSync("/usr/bin/xattr", ["-dr", "com.apple.quarantine", APP_DEST]);

  // Try to symlink the CLI; non-fatal on failure
  const cliTarget = path.join(APP_DEST, "Contents/MacOS/bentocli");
  const symlinkPath = "/usr/local/bin/bento";
  try {
    if (fs.existsSync(symlinkPath)) fs.unlinkSync(symlinkPath);
    fs.symlinkSync(cliTarget, symlinkPath);
    console.log("Symlinked " + symlinkPath + " → " + cliTarget);
  } catch (err) {
    console.log("Could not write " + symlinkPath + " (need sudo). The npm shim will still work — `bento --version` should print 0.1.0.");
  }

  // Cleanup
  try { fs.rmSync(stage, { recursive: true, force: true }); } catch {}
  try { fs.unlinkSync(TMP_ZIP); } catch {}

  console.log("");
  console.log("✓ Bento installed.");
  console.log("");
  console.log("  Launch:        open " + APP_DEST);
  console.log("  Global hotkey: ⌃⌘B (Control + Command + B)");
  console.log("  CLI:           bento --help");
  console.log("");
  console.log("  Repo:          https://github.com/" + REPO);
  console.log("  ⭐ A star helps a lot if you find this useful.");
  callback(null);
}

download(ZIP_URL, TMP_ZIP, 5, (err) => {
  if (err) {
    console.error("Failed to download " + ZIP_URL + ": " + err.message);
    console.error("Falling back to: build from source. See https://github.com/" + REPO + "#install");
    process.exit(0); // don't fail the npm install — leave the shim in place pointing at user-built location
  }
  unzipAndInstall((err) => {
    if (err) {
      console.error("Install failed: " + err.message);
      process.exit(1);
    }
  });
});
