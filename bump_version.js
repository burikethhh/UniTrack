const fs = require("fs");
const path = require("path");
const versionFile = path.join(__dirname, "web", "version.json");
let current;
try { current = JSON.parse(fs.readFileSync(versionFile, "utf8")); } catch (e) { current = { build: 0 }; }
const newBuild = (current.build || 0) + 1;
const now = new Date();
const dateStr = now.toISOString().slice(0, 10).replace(/-/g, "");
const timestamp = now.toISOString().replace(/\.\d{3}Z$/, "Z");
const updated = { version: "__BUILD_" + dateStr + "_" + newBuild + "__", build: newBuild, timestamp: timestamp };
fs.writeFileSync(versionFile, JSON.stringify(updated), "utf8");
console.log("Version bumped: build " + (current.build || 0) + " to " + newBuild);
console.log("version.json: " + JSON.stringify(updated));
