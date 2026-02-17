# Coding Conventions

**Analysis Date:** 2026-02-17

## Project Type & Language

**Primary Language:** JavaScript (Node.js)
**Additional formats:** Markdown (agent definitions, protocols, documentation)
**Runtime:** Node.js >= 16.0.0
**Package Manager:** npm
**Total Source Files:** 16 (2 executable JS files + 14 markdown protocol/agent files)

The codebase is a CLI package that installs autonomous phase-runner agents and protocols into Claude Code. Most code is Node.js scripts (`bin/install.js`, `src/hooks/autopilot-check-update.js`) with extensive Markdown documentation for agent behaviors and orchestration protocols.

---

## Naming Patterns

**File Names:**
- Kebab-case for executable scripts: `autopilot-check-update.js`, `install.js`
- Kebab-case for agent definitions: `autopilot-phase-runner.md`, `autopilot-debugger.md`
- Kebab-case for command definitions: `autopilot.md`, `add-phase.md`, `debug.md`
- Kebab-case for protocol files: `autopilot-orchestrator.md`, `autopilot-playbook.md`, `autopilot-schemas.md`
- Snake_case or kebab-case for state/cache files: `autopilot-file-manifest.json`, `autopilot-update-check.json`, `repo-map.json`

**Variable Names:**
- Camel case for JavaScript variables: `packageRoot`, `homeDir`, `cacheDir`, `manifestPath`, `isLocal`, `isUninstall`, `targetVersion`
- Uppercase for constants: `PACKAGE_NAME`, `GSD_PACKAGE_NAME`, `MIN_GSD_VERSION`, `FILE_MAP`, `VERSION_MAP`
- Descriptive names with clear intent: `filesToDelete`, `dirsToCheck`, `gsdVersionFile`, `settingsPath`, `versionDest`, `uniqueFiles`

**Function Names:**
- Camel case with clear action verbs: `sha256()`, `ensureDir()`, `compareVersions()`, `readJSON()`, `writeJSON()`, `checkGSD()`, `uninstall()`, `install()`
- Compound names for related operations: `addHookToSettings()`, `removeHookFromSettings()`

**Agent/Command Names:**
- Kebab-case for published names: `autopilot`, `autopilot-phase-runner`, `autopilot-debugger`
- Internal agent type references use kebab-case: `gsd-phase-researcher`, `gsd-planner`, `gsd-plan-checker`, `gsd-executor`, `gsd-verifier`, `general-purpose`, `gsd-debugger`

---

## Code Style

**Formatting:**
- **Line length:** Code maintains readable width (longest lines ~100-120 chars in `bin/install.js`)
- **Indentation:** 2 spaces (seen in JSON output via `JSON.stringify(data, null, 2)`)
- **Semicolons:** Explicit; all statements end with semicolons
- **Quotes:** Single quotes for string literals in code, double quotes for JSON embedded in strings
- **Trailing newlines:** All files end with newline (EOF)
- **Spacing:** No blank lines in require/const blocks; single line between logical sections

**Linting:**
- No eslint or prettier config detected (no `.eslintrc*`, `.prettierrc*`, `eslint.config.*`, `biome.json`)
- Code follows Node.js best practices informally but is not formally linted
- Uses Node.js strict mode: `'use strict';` in executable scripts

**Comments:**
- ASCII art section headers with dashes: `// ─── Configuration ──────────────────────────────────────────────────────────`
- Inline comments explain non-obvious logic only
- Function-level JSDoc-style comments rare; code readability is primary
- Error handling comments explain intent: `// Check if hook already exists`, `// Clean up empty arrays`

---

## Import & Require Organization

**Node.js require() pattern:**
1. Shebang if executable: `#!/usr/bin/env node`
2. Strict mode: `'use strict';`
3. Built-in modules (alphabetically): `const fs = require('fs');`, `const path = require('path');`, `const os = require('os');`, `const crypto = require('crypto');`
4. Destructured imports from built-ins: `const { spawn } = require('child_process');`, `const { execSync } = require('child_process');`
5. No third-party dependencies (lightweight package strategy)

**Example from `bin/install.js` (lines 1-8):**
```javascript
#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');
const crypto = require('crypto');
```

**Example from `src/hooks/autopilot-check-update.js` (lines 1-8):**
```javascript
#!/usr/bin/env node
// Check for autopilot-cc updates in background, write result to cache

const fs = require('fs');
const path = require('path');
const os = require('os');
const { spawn } = require('child_process');
```

---

## Error Handling

**Pattern 1: Try-Catch with Null Return**
```javascript
function readJSON(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch {
    return null;
  }
}
```
- Silent fallback to null for missing/invalid files
- Caller determines action (used in manifest/settings validation)
- Location: `bin/install.js:93-99`

**Pattern 2: Silent Filesystem Errors**
```javascript
for (const dir of dirsToCheck) {
  try {
    if (fs.existsSync(dir) && fs.readdirSync(dir).length === 0) {
      fs.rmdirSync(dir);
      console.log(`  Removed empty dir: ${dir}`);
    }
  } catch {}
}
```
- Empty catch block allows continuation on error (directory in use, permissions)
- User is informed via console log if deletion succeeds
- Location: `bin/install.js:160-172`

**Pattern 3: Conditional Flow on Error State**
```javascript
const gsdOk = checkGSD();
if (!gsdOk) {
  console.log('  Continuing install anyway (GSD can be installed later).\n');
}
```
- Functions return boolean; caller decides halt vs. continue
- Non-blocking dependency checks (GSD not required to install)
- Location: `bin/install.js:233-237`

**Pattern 4: Version Validation**
```javascript
function compareVersions(a, b) {
  const pa = a.split('.').map(Number);
  const pb = b.split('.').map(Number);
  for (let i = 0; i < 3; i++) {
    if ((pa[i] || 0) > (pb[i] || 0)) return 1;
    if ((pa[i] || 0) < (pb[i] || 0)) return -1;
  }
  return 0;
}
```
- Validates semantic versioning before comparison
- Returns numeric status (-1, 0, 1) for semver-like comparisons
- Handles missing patch versions gracefully: `(pa[i] || 0)`
- Location: `bin/install.js:83-91`

**Pattern 5: Graceful Error Suppression in Subprocesses**
```javascript
try {
  latest = execSync('npm view autopilot-cc version', {
    encoding: 'utf8',
    timeout: 10000,
    windowsHide: true
  }).trim();
} catch (e) {}
```
- External command failures don't halt process
- Used for npm version checks, network-dependent operations
- Location: `src/hooks/autopilot-check-update.js:44-46`

---

## Logging & Output

**Framework:** `console.log()` and `console.warn()` (no logging library)
- Direct console output for CLI feedback
- No structured logging (this is a CLI, not an application)

**Logging Levels:**
- `console.log()` — progress updates, success messages
- `console.warn()` — warnings to user (e.g., missing dependencies)

**Success Pattern:**
```javascript
console.log(`  ✓ ${mapping.dest}`);
```
- Checkmark symbol (✓) for successful operations
- Indented with 2 spaces for visual hierarchy
- Location: `bin/install.js:264`

**Warning Pattern:**
```javascript
console.warn(`\n⚠  GSD (${GSD_PACKAGE_NAME}) not found at ${target}/get-shit-done/`);
console.warn(`   Autopilot requires GSD >= ${MIN_GSD_VERSION}`);
```
- Warning triangle symbol (⚠) for cautionary messages
- Multi-line warnings with blank line prefix/suffix for visibility
- Continuation lines indented
- Location: `bin/install.js:110-112`

**Symbols Used:**
- `✓` (checkmark U+2713) — success
- `⚠` (warning triangle U+26A0) — warning
- No error symbol defined (errors typically cause exit)

**Installation Progress Example:**
```javascript
console.log(`
Installing ${PACKAGE_NAME} v${version} to ${target}...
`);
// ... progress items ...
console.log(`✓ ${PACKAGE_NAME} v${version} installed successfully!`);
```
- Template strings with clear section separators
- Location: `bin/install.js:230-284`

---

## JSON Data Structures

**Manifest Schema (installed files tracking):**
```javascript
const manifest = {
  version: '1.9.0',
  installed_at: '2026-02-17T14:30:00Z',
  target: '/home/user/.claude',
  files: [
    { dest: 'commands/autopilot.md', hash: 'sha256:a1b2c3...' },
    { dest: 'agents/autopilot-phase-runner.md', hash: 'sha256:d4e5f6...' }
  ]
};
```
- Flat structure with minimal nesting
- ISO 8601 timestamps for consistency
- Each file entry: `dest` (relative path) + `hash` (SHA256)
- Location: `bin/install.js:247`

**Settings Schema (hooks injection):**
```javascript
{
  hooks: {
    SessionStart: [
      {
        hooks: [
          { type: 'command', command: 'node /path/to/autopilot-check-update.js' }
        ]
      }
    ]
  }
}
```
- Nested array structure for hook management
- `type` + `command` pattern for extensibility
- Hooks are appended to existing array
- Location: `bin/install.js:184-200`

**Update Cache Schema (version check results):**
```javascript
{
  update_available: true,
  installed: '1.8.0',
  latest: '1.9.0',
  checked: 1708161000,
  expires: '2026-02-18T14:30:00Z'
}
```
- Simple boolean flag for UI display
- Unix timestamp (seconds) for check time
- ISO datetime for expiration
- Location: `src/hooks/autopilot-check-update.js:50-56`

---

## Control Flow

**Argument Parsing Pattern:**
```javascript
const args = process.argv.slice(2);
const isLocal = args.includes('--local');
const isUninstall = args.includes('--uninstall');
const isCheckDeps = args.includes('--check-deps');
const isHelp = args.includes('--help') || args.includes('-h');
```
- Early extraction of boolean flags via `includes()`
- No argument validation library; simple string matching
- Flags stored as booleans for routing logic
- Location: `bin/install.js:40-44`

**Help Output Pattern:**
```javascript
if (isHelp) {
  console.log(`
${PACKAGE_NAME} - Autonomous multi-phase execution

Usage:
  npx ${PACKAGE_NAME}@latest [options]

Options:
  --global       Install to ~/.claude/ (default)
  --local        Install to ./.claude/ (project-local)
  --uninstall    Remove all autopilot files
`);
  process.exit(0);
}
```
- Early exit on help flag
- Consistent format: Usage, Options sections
- Exit code 0 for success
- Location: `bin/install.js:46-61`

**Main Entry Point Pattern:**
```javascript
if (isCheckDeps) {
  checkGSD();
} else if (isUninstall) {
  uninstall();
} else {
  install();
}
```
- Flat if-else chain based on flags
- Default action is install if no flags present
- No nested conditionals; simple routing
- Location: `bin/install.js:307-313`

**Directory Traversal Pattern:**
```javascript
const dirsToCheck = [
  path.join(target, 'commands', 'autopilot'),
  path.join(target, 'autopilot', 'protocols'),
  path.join(target, 'autopilot'),
];
for (const dir of dirsToCheck) {
  try {
    if (fs.existsSync(dir) && fs.readdirSync(dir).length === 0) {
      fs.rmdirSync(dir);
    }
  } catch {}
}
```
- Pre-constructed array of paths to process
- Order matters (child dirs before parent)
- Simplifies cleanup/reversal operations
- Location: `bin/install.js:160-172`

---

## File System Operations

**Path Construction:**
- Always use `path.join()` for cross-platform safety
- Resolve relative paths via `path.resolve()` before operations
- Home directory: `os.homedir()` (never hardcode `~`)

**Example:**
```javascript
const homeDir = os.homedir();
const target = isLocal
  ? path.join(process.cwd(), '.claude')
  : path.join(homeDir, '.claude');
```
- Location: `bin/install.js:15, 65-67`

**Directory Existence:**
- Use `fs.existsSync()` to check before operations
- Use `fs.mkdirSync(dirPath, { recursive: true })` to create
- Location: `bin/install.js:77-81`

**File Operations:**
- `fs.readFileSync()` for read (sync, blocking)
- `fs.writeFileSync()` for write (sync, blocking)
- `fs.copyFileSync()` for copy
- Location: `bin/install.js:250-273`

---

## Markdown Protocol Structure

**Agent Definition Format (frontmatter + content):**
```markdown
---
name: autopilot-phase-runner
description: Runs the complete pipeline for a single autopilot phase
tools: Read, Write, Edit, Bash, Task, Glob, Grep
color: blue
---

<role>
You are an autopilot phase-runner...
</role>

<pipeline>
Execute these steps in order...
</pipeline>

<context_rules>
These rules prevent context overload...
</context_rules>
```
- YAML frontmatter with metadata (name, description, tools, color)
- XML-style tags for major sections (`<role>`, `<pipeline>`, `<context_rules>`, etc.)
- Markdown formatting within tags
- Location: `src/agents/autopilot-phase-runner.md`

**Protocol Document Structure:**
- Hierarchical sections with numbered headings (Section 1, Section 2, etc.)
- Code examples in triple-backtick blocks with language tags
- Tables for schema reference and input/output specifications
- JSON examples showing exact shape expected
- Location: `src/protocols/autopilot-schemas.md`

**Command Definition Format:**
```markdown
---
name: autopilot
description: Autonomous multi-phase execution
argument-hint: <phases|resume|status>
allowed-tools:
  - Read
  - Write
  - Edit
---

<update_check>
Check for updates before output...
</update_check>

<objective>
Run phases autonomously...
</objective>

<execution>
## On Invocation
1. Parse argument
2. Verify agent availability
</execution>
```
- Location: `src/commands/autopilot.md`

---

## Placeholder & Configuration Patterns

**Placeholder Substitution:**
- `__INSTALL_BASE__` marker in protocol files replaced at install time
- Substitution happens during file copy in `bin/install.js`
- Enables relative path references in agent definitions

**Example:**
```javascript
content = content.replace(/__INSTALL_BASE__/g, target);
```
- Location: `bin/install.js:257`
- Usage in protocols: `read __INSTALL_BASE__/autopilot/protocols/autopilot-playbook.md`

**Installation Targets:**
- Global default: `~/.claude/` (resolved via `path.join(homeDir, '.claude')`)
- Local override: `./.claude/` (resolved via `path.join(process.cwd(), '.claude')`)
- Target determined by `--local` flag
- Location: `bin/install.js:65-67`

---

## Cross-Cutting Patterns

**Deduplication:**
```javascript
const uniqueFiles = [...new Set(filesToDelete)];
for (const f of uniqueFiles) {
  // delete f
}
```
- Set for removing duplicates before iteration
- Prevents double-deletion errors
- Location: `bin/install.js:151`

**Silent Cleanup:**
```javascript
try {
  if (fs.existsSync(f)) {
    fs.unlinkSync(f);
    console.log(`  Deleted: ${f}`);
  }
} catch {}
```
- Try-catch without explicit error logging
- Silent skip on any error (file already gone, permissions, etc.)
- User informed via console log on success
- Location: `bin/install.js:152-157`

**Background Process Spawning:**
```javascript
const child = spawn(process.execPath, ['-e', `...`], {
  stdio: 'ignore',
  windowsHide: true,
  detached: true  // Required on Windows
});
child.unref();
```
- Spawned process runs independently; parent does not wait
- `detached: true` critical for Windows compatibility
- `stdio: 'ignore'` prevents output capture
- `child.unref()` allows parent to exit
- Location: `src/hooks/autopilot-check-update.js:25-65`

**Semantic Versioning Assumption:**
- All version strings assumed to be X.Y.Z format
- Comparison returns -1 (a < b), 0 (a == b), 1 (a > b)
- Missing components default to 0: `(pa[i] || 0)`
- Pre-release versions (alpha, beta) not handled
- Location: `bin/install.js:83-91`

---

## Special Conventions

**Manifest Hashing:**
- SHA-256 used for file integrity
- Hash stored with each file entry for future verification
- Used in uninstall to validate files before deletion

**Example:**
```javascript
function sha256(content) {
  return crypto.createHash('sha256').update(content).digest('hex');
}

const hash = sha256(content);
manifest.files.push({ dest: mapping.dest, hash });
```
- Location: `bin/install.js:73-75, 262-263`

**Process Execution Timeouts:**
- npm commands given 10-second timeout
- Prevents hanging on network issues

**Example:**
```javascript
const latest = execSync('npm view autopilot-cc version', {
  encoding: 'utf8',
  timeout: 10000
}).trim();
```
- Location: `src/hooks/autopilot-check-update.js:45`

---

*Convention analysis: 2026-02-17*
