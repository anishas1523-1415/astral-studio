#!/usr/bin/env node
// Publish an app's APK to Astral Studio.
//
//   node release.mjs --app aurasynq --name AuraSynq --version 1.0.1 --apk path/to/app.apk \
//     --notes "What changed" [--tagline "One line about the app"] [--icon path/to/icon.png]
//
// 1. Uploads the APK to a GitHub Release (tag <app>-v<version>) in anishas1523-1415/astral-studio
// 2. Adds the version to public/apps.json (newest first) and points /get/<app> at it
// 3. Deploys the site (astral-studio.web.app) and commits the change
import { execFileSync } from "node:child_process";
import { copyFileSync, existsSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { basename, dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const REPO = "anishas1523-1415/astral-studio";
const SITE = "astral-studio";
const FIREBASE_PROJECT = "aurasynq";
const root = dirname(fileURLToPath(import.meta.url));
// Only the Firebase CLI needs a shell on Windows (it is a .cmd); arguments to the others stay intact
const run = (cmd, args, opts = {}) => execFileSync(cmd, args, { cwd: root, stdio: "inherit", shell: cmd === "firebase" && process.platform === "win32", ...opts });

const args = {};
for (let i = 2; i < process.argv.length; i += 2) args[process.argv[i].replace(/^--/, "")] = process.argv[i + 1];
for (const key of ["app", "version", "apk"]) {
  if (!args[key]) { console.error(`Missing --${key}`); process.exit(1); }
}
if (!/^[a-z0-9-]+$/.test(args.app)) { console.error("--app must be lowercase letters, digits or dashes"); process.exit(1); }
if (!existsSync(args.apk)) { console.error(`APK not found: ${args.apk}`); process.exit(1); }

const appsPath = join(root, "public", "apps.json");
const catalog = JSON.parse(readFileSync(appsPath, "utf8"));
let app = catalog.apps.find((a) => a.id === args.app);
if (!app) {
  app = { id: args.app, name: args.name || args.app, tagline: args.tagline || "", icon: `/icons/${args.app}.png`, versions: [] };
  catalog.apps.push(app);
}
if (args.name) app.name = args.name;
if (args.tagline) app.tagline = args.tagline;
if (args.icon) copyFileSync(args.icon, join(root, "public", "icons", `${args.app}.png`));
if (app.versions.some((v) => v.version === args.version)) { console.error(`${app.name} v${args.version} is already published`); process.exit(1); }

// 1. Upload
const tag = `${args.app}-v${args.version}`;
const fileName = `${app.name.replace(/\s+/g, "")}-${args.version}.apk`;
const staged = join(root, fileName);
copyFileSync(args.apk, staged);
const notes = args.notes || `${app.name} ${args.version}`;
try {
  run("gh", ["release", "create", tag, staged, "--repo", REPO, "--title", `${app.name} ${args.version}`, "--notes", notes]);
} finally {
  try { execFileSync(process.platform === "win32" ? "cmd" : "rm", process.platform === "win32" ? ["/c", "del", staged] : [staged]); } catch {}
}
const url = `https://github.com/${REPO}/releases/download/${tag}/${fileName}`;

// 2. Catalogue + short link
const sizeMb = (statSync(args.apk).size / (1024 * 1024)).toFixed(1);
app.versions.unshift({ version: args.version, date: new Date().toISOString().slice(0, 10), size: `${sizeMb} MB`, notes, url });
writeFileSync(appsPath, `${JSON.stringify(catalog, null, 2)}\n`);

const firebase = {
  hosting: {
    site: SITE,
    public: "public",
    cleanUrls: true,
    headers: [{ source: "/apps.json", headers: [{ key: "Cache-Control", value: "no-cache" }, { key: "Access-Control-Allow-Origin", value: "*" }] }],
    redirects: catalog.apps.map((a) => ({ source: `/get/${a.id}`, destination: a.versions[0].url, type: 302 })),
  },
};
writeFileSync(join(root, "firebase.json"), `${JSON.stringify(firebase, null, 2)}\n`);

// 3. Deploy + commit
run("firebase", ["deploy", "--only", `hosting:${SITE}`, "--project", FIREBASE_PROJECT, "--non-interactive"]);
run("git", ["add", "-A"]);
run("git", ["commit", "-m", `release: ${app.name} ${args.version}`]);
run("git", ["push", "origin", "main"]);
console.log(`\nPublished ${app.name} ${args.version}\n  Page:     https://${SITE}.web.app/app.html?id=${args.app}\n  Download: https://${SITE}.web.app/get/${args.app}\n  (${basename(url)})`);
