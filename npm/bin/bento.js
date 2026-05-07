#!/usr/bin/env node
// Tiny shim that hands off to the bentocli binary inside Bento.app.
// The actual CLI is /Applications/Bento.app/Contents/MacOS/bentocli; this shim
// exists so `npm install -g bento` can put a `bento` command on your PATH.

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
  console.error("Bento.app not found. Run `npm install -g bento` to install, or build from source and run scripts/install-cli.sh.");
  process.exit(1);
}

const result = spawnSync(exe, process.argv.slice(2), { stdio: "inherit" });
process.exit(result.status ?? 1);
