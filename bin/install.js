#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');
const crypto = require('crypto');

// ─── Configuration ──────────────────────────────────────────────────────────

const PACKAGE_NAME = 'autopilot-cc';
const GSD_PACKAGE_NAME = 'get-shit-done-cc';
const MIN_GSD_VERSION = '1.15.0';

const homeDir = os.homedir();
const packageRoot = path.resolve(__dirname, '..');

// File mapping: package source → install destination (relative to target)
const FILE_MAP = [
  { src: 'src/commands/autopilot.md',               dest: 'commands/autopilot.md' },
  { src: 'src/commands/autopilot/debug.md',        dest: 'commands/autopilot/debug.md' },
  { src: 'src/commands/autopilot/add-phase.md',   dest: 'commands/autopilot/add-phase.md' },
  { src: 'src/commands/autopilot/map.md',          dest: 'commands/autopilot/map.md' },
  { src: 'src/commands/autopilot/progress.md',    dest: 'commands/autopilot/progress.md' },
  { src: 'src/commands/autopilot/help.md',         dest: 'commands/autopilot/help.md' },
  { src: 'src/commands/autopilot/update.md',       dest: 'commands/autopilot/update.md' },
  { src: 'src/agents/autopilot-phase-runner.md',  dest: 'agents/autopilot-phase-runner.md' },
  { src: 'src/agents/autopilot-debugger.md',      dest: 'agents/autopilot-debugger.md' },
  { src: 'src/protocols/autopilot-orchestrator.md', dest: 'autopilot/protocols/autopilot-orchestrator.md' },
  { src: 'src/protocols/autopilot-playbook.md',   dest: 'autopilot/protocols/autopilot-playbook.md' },
  { src: 'src/protocols/autopilot-schemas.md',    dest: 'autopilot/protocols/autopilot-schemas.md' },
  { src: 'src/hooks/autopilot-check-update.js',   dest: 'hooks/autopilot-check-update.js' },
];

const VERSION_MAP = { src: 'VERSION', dest: 'autopilot/VERSION' };

// ─── Argument Parsing ───────────────────────────────────────────────────────

const args = process.argv.slice(2);
const isLocal = args.includes('--local');
const isUninstall = args.includes('--uninstall');
const isCheckDeps = args.includes('--check-deps');
const isHelp = args.includes('--help') || args.includes('-h');

if (isHelp) {
  console.log(`
${PACKAGE_NAME} - Autonomous multi-phase execution for Claude Code

Usage:
  npx ${PACKAGE_NAME}@latest [options]

Options:
  --global       Install to ~/.claude/ (default)
  --local        Install to ./.claude/ (project-local)
  --uninstall    Remove all autopilot files
  --check-deps   Check GSD dependency without installing
  --help, -h     Show this help message
`);
  process.exit(0);
}

// ─── Target Resolution ──────────────────────────────────────────────────────

const target = isLocal
  ? path.join(process.cwd(), '.claude')
  : path.join(homeDir, '.claude');

const manifestPath = path.join(target, 'autopilot-file-manifest.json');

// ─── Utility Functions ──────────────────────────────────────────────────────

function sha256(content) {
  return crypto.createHash('sha256').update(content).digest('hex');
}

function ensureDir(dirPath) {
  if (!fs.existsSync(dirPath)) {
    fs.mkdirSync(dirPath, { recursive: true });
  }
}

function compareVersions(a, b) {
  const pa = a.split('.').map(Number);
  const pb = b.split('.').map(Number);
  for (let i = 0; i < 3; i++) {
    if ((pa[i] || 0) > (pb[i] || 0)) return 1;
    if ((pa[i] || 0) < (pb[i] || 0)) return -1;
  }
  return 0;
}

function readJSON(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch {
    return null;
  }
}

function writeJSON(filePath, data) {
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2) + '\n');
}

// ─── GSD Dependency Check ───────────────────────────────────────────────────

function checkGSD() {
  const gsdVersionFile = path.join(target, 'get-shit-done', 'VERSION');
  if (!fs.existsSync(gsdVersionFile)) {
    console.warn(`\n⚠  GSD (${GSD_PACKAGE_NAME}) not found at ${target}/get-shit-done/`);
    console.warn(`   Autopilot requires GSD >= ${MIN_GSD_VERSION}`);
    console.warn(`   Install it first: npx ${GSD_PACKAGE_NAME}@latest\n`);
    return false;
  }

  const gsdVersion = fs.readFileSync(gsdVersionFile, 'utf8').trim();
  if (compareVersions(gsdVersion, MIN_GSD_VERSION) < 0) {
    console.warn(`\n⚠  GSD version ${gsdVersion} found, but >= ${MIN_GSD_VERSION} required`);
    console.warn(`   Update: npx ${GSD_PACKAGE_NAME}@latest\n`);
    return false;
  }

  console.log(`✓ GSD ${gsdVersion} found (>= ${MIN_GSD_VERSION} required)`);
  return true;
}

// ─── Uninstall ──────────────────────────────────────────────────────────────

function uninstall() {
  console.log(`\nUninstalling ${PACKAGE_NAME} from ${target}...\n`);

  // Read manifest to know what to delete
  const manifest = readJSON(manifestPath);
  const filesToDelete = [];

  if (manifest && manifest.files) {
    for (const entry of manifest.files) {
      const fullPath = path.join(target, entry.dest);
      if (fs.existsSync(fullPath)) {
        filesToDelete.push(fullPath);
      }
    }
  }

  // Also delete VERSION and manifest itself
  const versionPath = path.join(target, VERSION_MAP.dest);
  if (fs.existsSync(versionPath)) filesToDelete.push(versionPath);
  if (fs.existsSync(manifestPath)) filesToDelete.push(manifestPath);

  // Delete files (deduplicate paths)
  const uniqueFiles = [...new Set(filesToDelete)];
  for (const f of uniqueFiles) {
    if (fs.existsSync(f)) {
      fs.unlinkSync(f);
      console.log(`  Deleted: ${f}`);
    }
  }

  // Clean up empty directories
  const dirsToCheck = [
    path.join(target, 'commands', 'autopilot'),
    path.join(target, 'autopilot', 'protocols'),
    path.join(target, 'autopilot'),
  ];
  for (const dir of dirsToCheck) {
    try {
      if (fs.existsSync(dir) && fs.readdirSync(dir).length === 0) {
        fs.rmdirSync(dir);
        console.log(`  Removed empty dir: ${dir}`);
      }
    } catch {}
  }

  // Remove hook from settings.json
  removeHookFromSettings();

  console.log(`\n✓ ${PACKAGE_NAME} uninstalled successfully.\n`);
}

// ─── Hook Management ────────────────────────────────────────────────────────

function addHookToSettings() {
  const settingsPath = path.join(target, 'settings.json');
  let settings = readJSON(settingsPath) || {};

  if (!settings.hooks) settings.hooks = {};
  if (!settings.hooks.SessionStart) settings.hooks.SessionStart = [];

  const hookCommand = `node "${path.join(target, 'hooks', 'autopilot-check-update.js')}"`;

  // Check if hook already exists
  const exists = settings.hooks.SessionStart.some(entry =>
    entry.hooks && entry.hooks.some(h => h.command && h.command.includes('autopilot-check-update'))
  );

  if (!exists) {
    settings.hooks.SessionStart.push({
      hooks: [{ type: 'command', command: hookCommand }]
    });
  }

  writeJSON(settingsPath, settings);
}

function removeHookFromSettings() {
  const settingsPath = path.join(target, 'settings.json');
  let settings = readJSON(settingsPath);
  if (!settings || !settings.hooks || !settings.hooks.SessionStart) return;

  settings.hooks.SessionStart = settings.hooks.SessionStart.filter(entry =>
    !(entry.hooks && entry.hooks.some(h => h.command && h.command.includes('autopilot-check-update')))
  );

  // Clean up empty arrays
  if (settings.hooks.SessionStart.length === 0) {
    delete settings.hooks.SessionStart;
  }
  if (Object.keys(settings.hooks).length === 0) {
    delete settings.hooks;
  }

  writeJSON(settingsPath, settings);
  console.log('  Removed autopilot hook from settings.json');
}

// ─── Install ────────────────────────────────────────────────────────────────

function install() {
  const version = fs.readFileSync(path.join(packageRoot, 'VERSION'), 'utf8').trim();

  console.log(`\nInstalling ${PACKAGE_NAME} v${version} to ${target}...\n`);

  // Check GSD dependency
  const gsdOk = checkGSD();
  if (!gsdOk) {
    console.log('  Continuing install anyway (GSD can be installed later).\n');
  }

  // Ensure target directories exist
  ensureDir(path.join(target, 'commands'));
  ensureDir(path.join(target, 'commands', 'autopilot'));
  ensureDir(path.join(target, 'agents'));
  ensureDir(path.join(target, 'autopilot', 'protocols'));
  ensureDir(path.join(target, 'hooks'));
  ensureDir(path.join(target, 'cache'));

  const manifest = { version, installed_at: new Date().toISOString(), target, files: [] };

  // Copy and transform files
  for (const mapping of FILE_MAP) {
    const srcPath = path.join(packageRoot, mapping.src);
    const destPath = path.join(target, mapping.dest);

    let content = fs.readFileSync(srcPath, 'utf8');

    // Resolve __INSTALL_BASE__ placeholder
    content = content.replace(/__INSTALL_BASE__/g, target);

    ensureDir(path.dirname(destPath));
    fs.writeFileSync(destPath, content);

    const hash = sha256(content);
    manifest.files.push({ dest: mapping.dest, hash });
    console.log(`  ✓ ${mapping.dest}`);
  }

  // Copy VERSION file
  const versionSrc = path.join(packageRoot, VERSION_MAP.src);
  const versionDest = path.join(target, VERSION_MAP.dest);
  ensureDir(path.dirname(versionDest));
  fs.copyFileSync(versionSrc, versionDest);
  manifest.files.push({ dest: VERSION_MAP.dest, hash: sha256(fs.readFileSync(versionSrc)) });
  console.log(`  ✓ ${VERSION_MAP.dest}`);

  // Write manifest
  writeJSON(manifestPath, manifest);
  console.log(`  ✓ autopilot-file-manifest.json`);

  // Inject SessionStart hook
  addHookToSettings();
  console.log(`  ✓ SessionStart hook added to settings.json`);

  console.log(`
✓ ${PACKAGE_NAME} v${version} installed successfully!

Files installed to: ${target}
  - /autopilot command (primary phase runner)
  - /autopilot:debug, /autopilot:add-phase, /autopilot:map, /autopilot:progress
  - /autopilot:help (command reference)
  - autopilot-phase-runner + autopilot-debugger agents
  - 3 protocol files
  - SessionStart update hook

⚠  IMPORTANT: You must restart Claude Code before using /autopilot.
   Agent types are discovered at session startup. If you run /autopilot
   in an existing session, the phase-runner agent will not be found.

Usage: Start Claude Code and run /autopilot <phases>
Help:  /autopilot:help
Update: /autopilot update
Uninstall: npx ${PACKAGE_NAME}@latest --uninstall
`);
}

// ─── Main ───────────────────────────────────────────────────────────────────

if (isCheckDeps) {
  checkGSD();
} else if (isUninstall) {
  uninstall();
} else {
  install();
}
