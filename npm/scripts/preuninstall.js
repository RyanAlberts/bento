#!/usr/bin/env node
// preuninstall — removes the symlink and the installed Bento.app so
// `npm uninstall -g bento` leaves the system in a clean state.

const fs = require("fs");
const path = require("path");
const os = require("os");
const { spawnSync } = require("child_process");

if (process.platform !== "darwin") {
  process.exit(0);
}

const symlinkPath = "/usr/local/bin/bento";
try {
  if (fs.lstatSync(symlinkPath).isSymbolicLink()) {
    fs.unlinkSync(symlinkPath);
    console.log("Removed " + symlinkPath);
  }
} catch {}

for (const dest of ["/Applications/Bento.app", path.join(os.homedir(), "Applications/Bento.app")]) {
  if (fs.existsSync(dest)) {
    spawnSync("/bin/rm", ["-rf", dest]);
    console.log("Removed " + dest);
  }
}
