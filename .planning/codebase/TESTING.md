# Testing Patterns

**Analysis Date:** 2026-02-17

## Test Framework

**Current Status:** No automated test suite present.

**Test Framework:** Not used
- No `jest.config.*`, `vitest.config.*`, `mocha.config.*` files
- No test files found (`*.test.js`, `*.spec.js`)
- No testing dependencies in `package.json`
- No CI configuration (`.github/workflows/`, `.gitlab-ci.yml`, etc.)

**Test Runner Commands:** Not applicable (no test framework)

---

## Codebase Characteristics Impacting Testing Strategy

This codebase is a lightweight CLI package with characteristics that affect testing decisions:

1. **Small scope:** ~378 total lines across 2 executable JS files
   - `bin/install.js` — 313 lines (primary logic)
   - `src/hooks/autopilot-check-update.js` — 65 lines (background process)

2. **Narrow responsibility:**
   - File installation and management
   - Hook injection into settings.json
   - GSD dependency checking
   - Version comparison and validation
   - Background update checking

3. **Heavy filesystem operations:** Most code performs direct I/O
   - Read/write JSON files
   - Copy files to user directories
   - Create/remove directories
   - Modify settings.json in-place

4. **External process dependencies:**
   - Spawns npm to check versions
   - Relies on git, npm in environment
   - Filesystem state is external dependency

5. **Installation-time execution:** Code runs once per developer during setup
   - Not part of application runtime
   - Installation success critical; runtime performance secondary
   - User manually runs `npx autopilot-cc@latest`

---

## Testable Functions (Pure/Isolated)

These functions are amenable to unit testing without heavy mocking:

**`compareVersions(a, b)` (lines 83-91)**
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
- Pure function; no side effects
- Deterministic output
- Easy to test all branches

**Test cases for `compareVersions`:**
```javascript
// If tests were added (Jest example):
describe('compareVersions', () => {
  it('returns 1 when a > b', () => {
    expect(compareVersions('2.0.0', '1.0.0')).toBe(1);
  });

  it('returns -1 when a < b', () => {
    expect(compareVersions('1.0.0', '2.0.0')).toBe(-1);
  });

  it('returns 0 when versions are equal', () => {
    expect(compareVersions('1.5.0', '1.5.0')).toBe(0);
  });

  it('handles missing patch versions', () => {
    expect(compareVersions('1.5', '1.5.0')).toBe(0);
  });

  it('compares major versions correctly', () => {
    expect(compareVersions('2.0.0', '1.9.9')).toBe(1);
  });

  it('compares minor versions when major equal', () => {
    expect(compareVersions('1.5.0', '1.4.0')).toBe(1);
  });

  it('compares patch versions when major/minor equal', () => {
    expect(compareVersions('1.0.5', '1.0.3')).toBe(1);
  });
});
```

**`sha256(content)` (lines 73-75)**
```javascript
function sha256(content) {
  return crypto.createHash('sha256').update(content).digest('hex');
}
```
- Pure function; deterministic hash output
- No side effects
- Can verify against known hashes

**Test cases for `sha256`:**
```javascript
describe('sha256', () => {
  it('produces consistent hash for same input', () => {
    const content = 'test content';
    const hash1 = sha256(content);
    const hash2 = sha256(content);
    expect(hash1).toBe(hash2);
  });

  it('produces different hash for different input', () => {
    const hash1 = sha256('content1');
    const hash2 = sha256('content2');
    expect(hash1).not.toBe(hash2);
  });

  it('returns valid hex string', () => {
    const hash = sha256('test');
    expect(/^[a-f0-9]{64}$/.test(hash)).toBe(true); // SHA256 is 256 bits = 64 hex chars
  });
});
```

---

## Hard-to-Test Functions (I/O-Heavy)

These functions require heavy mocking and are better tested via integration:

**`readJSON(filePath)` (lines 93-99)**
- Reads file system; would need fs mocking
- Graceful error handling makes unit testing less valuable
- Better tested via integration test

**`writeJSON(filePath, data)` (lines 101-103)**
- Writes file system; would need fs mocking
- Integration test more useful

**`ensureDir(dirPath)` (lines 77-81)**
- Creates directories; filesystem-dependent
- Would need temp directory setup/teardown

**`checkGSD()` (lines 107-125)**
- Reads GSD version file
- Spawns npm process
- Would require process mocking
- Integration test approach better

**`install()` (lines 228-303)**
- Copies 15+ files
- Modifies settings.json
- Creates manifest
- Runs hook management
- Requires temp directory + file setup
- Heavy I/O coupling

**`uninstall()` (lines 129-178)**
- Reads manifest
- Deletes multiple files
- Removes hook from settings.json
- Requires pre-existing installation state
- Filesystem-dependent cleanup logic fragile

**`addHookToSettings()` (lines 182-203)**
- Modifies JSON structure in-place
- Fragile idempotency check
- Would need fs mocking + JSON comparison

**`removeHookFromSettings()` (lines 205-224)**
- Modifies JSON structure
- Must not break other hooks
- Would need pre-existing settings structure

---

## Integration Testing Approach

Integration testing is more valuable for this codebase than unit testing.

**Test Scope:** Full install/uninstall lifecycle with temporary directories

```javascript
// If integration tests were added (Jest example):
describe('autopilot-cc installation lifecycle', () => {
  let testDir;

  beforeEach(() => {
    // Create temp directory for each test
    testDir = fs.mkdtempSync(path.join(os.tmpdir(), 'autopilot-test-'));
  });

  afterEach(() => {
    // Clean up temp directory
    fs.rmSync(testDir, { recursive: true, force: true });
  });

  it('installs all files to target directory', () => {
    // Setup: call install(testDir)
    // Assert: verify all files from FILE_MAP exist at correct paths
    // Assert: manifest.json created with correct entries
    // Assert: hooks added to settings.json
  });

  it('creates installation manifest with correct hashes', () => {
    // Setup: call install(testDir)
    // Assert: manifest.json contains all files
    // Assert: each file hash matches actual file hash
  });

  it('uninstall removes all installed files', () => {
    // Setup: call install(testDir)
    // Setup: call uninstall(testDir)
    // Assert: all files removed
    // Assert: empty directories cleaned up
    // Assert: hooks removed from settings.json
  });

  it('preserves other hooks when uninstalling', () => {
    // Setup: create settings.json with other hooks
    // Setup: call install(testDir)
    // Setup: call uninstall(testDir)
    // Assert: autopilot hook removed, other hooks preserved
  });

  it('detects GSD dependency correctly', () => {
    // Setup: create valid GSD installation structure
    // Assert: checkGSD(testDir) returns true
  });

  it('warns when GSD version is too old', () => {
    // Setup: create GSD with version < MIN_GSD_VERSION
    // Assert: checkGSD(testDir) returns false with warning
  });

  it('placeholder substitution works correctly', () => {
    // Setup: call install(testDir)
    // Assert: __INSTALL_BASE__ replaced in protocol files
    // Assert: path references correct in agent definitions
  });
});
```

---

## Current Code Coverage

**Lines and status by function:**

| Component | Location | Lines | Type | Testability |
|-----------|----------|-------|------|-------------|
| Argument parsing | 40-44 | 5 | Pure | Good (no side effects) |
| Help output | 46-61 | 16 | I/O | Fair (stdout capture needed) |
| `compareVersions()` | 83-91 | 9 | Pure | Excellent |
| `sha256()` | 73-75 | 3 | Pure | Excellent |
| `readJSON()` | 93-99 | 7 | I/O | Poor (fs dependency) |
| `writeJSON()` | 101-103 | 3 | I/O | Poor (fs dependency) |
| `ensureDir()` | 77-81 | 5 | I/O | Poor (fs dependency) |
| `checkGSD()` | 107-125 | 19 | I/O | Poor (fs + process spawn) |
| `uninstall()` | 129-178 | 50 | I/O | Poor (fs operations) |
| `removeHookFromSettings()` | 205-224 | 20 | I/O | Poor (JSON mutation) |
| `addHookToSettings()` | 182-203 | 22 | I/O | Poor (JSON mutation) |
| `install()` | 228-303 | 76 | I/O | Poor (heavy I/O coupling) |
| Background update hook | src/hooks/ | 65 | I/O | Poor (process spawn) |

**Manual testing performed (documented but not automated):**
- Installation to global `~/.claude/` directory
- Installation to local `./.claude/` directory
- File verification post-install
- Uninstall with file cleanup
- GSD dependency detection
- Hook addition/removal from settings.json
- Update check background execution
- Cross-platform path handling (Windows/macOS/Linux)

---

## Testing Debt & Fragile Areas

**Critical gaps where silent failures are possible:**

**1. File path construction** (`bin/install.js:19-34`)
- FILE_MAP paths must match source files in npm package
- Typos in paths cause silent installation failures (files missing, not copied)
- No validation that source files exist before copying
- **Risk:** User installs package but files missing; `/autopilot` command not found
- **Fix approach:** Add source file existence checks before copy loop

**2. Hook idempotency** (`bin/install.js:182-203`)
- `addHookToSettings()` checks for hook existence using string `includes()`
- If hook command format changes, old hooks won't be recognized
- Potential for duplicate hooks if command string differs slightly
- **Risk:** Session start runs multiple hook instances; version check runs multiple times
- **Fix approach:** Use structured hook ID/key instead of command string matching

**3. Manifest integrity** (`bin/install.js:266-267`)
- Manifest hashes written but never validated on later runs
- Uninstall relies on manifest; if manifest corrupts, uninstall fails
- No recovery mechanism if manifest is lost
- **Risk:** Corrupted manifest = incomplete uninstall; orphaned files remain
- **Fix approach:** Validate manifest hashes on read; provide cleanup command for orphaned files

**4. Platform differences** (`src/hooks/autopilot-check-update.js:57-59`)
- Windows-specific code: `detached: true`, `windowsHide: true`
- Unix/Linux behavior not tested on those platforms
- Child process spawning may behave differently on different Node versions
- **Risk:** Update check hook fails silently on some platforms
- **Fix approach:** Test on Windows/macOS/Linux; add platform-specific process options

**5. GSD version comparison** (`bin/install.js:83-91`)
- `compareVersions()` assumes semantic versioning (X.Y.Z)
- Pre-release versions (1.0.0-alpha, 1.0.0-beta.1) would fail comparison
- Alpha/beta/RC versions not handled
- **Risk:** Pre-release GSD installed but incorrectly reported as incompatible
- **Fix approach:** Parse pre-release suffixes; compare base version only

**6. Empty directory cleanup** (`bin/install.js:160-172`)
- `fs.rmdirSync(dir)` only removes empty directories
- If cleanup order is wrong, parent directories remain non-empty
- No validation that cleanup actually succeeded
- **Risk:** Uninstall leaves empty directory structure behind
- **Fix approach:** Use `fs.rmSync(dir, { recursive: true, force: true })` for safe cleanup

**7. Placeholder validation** (`bin/install.js:256-257`)
- `__INSTALL_BASE__` substitution happens blindly
- No validation that placeholder replacement succeeded
- If file doesn't contain placeholder, substitution silently does nothing
- **Risk:** Protocol files installed with unresolved `__INSTALL_BASE__` references
- **Fix approach:** Verify placeholder replaced; log warning if not found

---

## Testing Recommendations for Future

**Priority 1: Unit tests for pure functions**
- Add tests for `compareVersions()` — 7 test cases covering all branches
- Add tests for `sha256()` — 3 test cases for consistency and format
- These are low-effort, high-value tests
- No mocking required; can run in CI immediately

**Priority 2: Integration test framework**
- Set up Jest or Vitest with temp directory fixtures
- Test full install/uninstall lifecycle
- Test hook management with pre-existing settings
- Test placeholder substitution in protocol files
- Test GSD dependency detection with mock installations

**Priority 3: Filesystem safety improvements**
- Add explicit path validation before file operations
- Add manifest integrity check on uninstall
- Add file existence verification before copying
- Implement idempotent hook management (structured IDs)

**Priority 4: Cross-platform validation**
- Test on Windows, macOS, Linux (in CI)
- Verify child process behavior on each platform
- Test npm availability check with network conditions
- Test path construction with mixed separators

---

## Suggested Test Framework

**Recommendation:** Jest or Vitest

**Rationale:**
- Node.js native; no external runtime needed
- Built-in filesystem mocking (`jest.mock('fs')`)
- Process mocking support (`jest.mock('child_process')`)
- Snapshot testing for JSON structure validation
- Fast parallel test execution
- Works with TypeScript if needed later
- Large ecosystem; many examples

**Configuration template (if tests were added):**

```javascript
// jest.config.js (hypothetical)
module.exports = {
  testEnvironment: 'node',
  testMatch: [
    '**/__tests__/**/*.test.js',
    '**/*.test.js'
  ],
  coveragePathIgnorePatterns: [
    '/node_modules/',
    '/dist/'
  ],
  collectCoverageFrom: [
    'bin/**/*.js',
    'src/**/*.js',
    '!src/**/*.md'
  ],
  coverageThreshold: {
    global: {
      branches: 50,      // Non-critical for install script
      functions: 70,     // Pure functions well-covered
      lines: 70,         // Core logic covered
      statements: 70
    }
  }
};
```

**Script additions (to hypothetical `package.json`):**
```json
{
  "scripts": {
    "test": "jest",
    "test:watch": "jest --watch",
    "test:coverage": "jest --coverage"
  }
}
```

---

## Manual Testing Checklist

Since automated tests are not currently implemented, manual verification should cover these areas:

**Installation Flow:**
- [ ] `npx autopilot-cc@latest` installs to `~/.claude/`
- [ ] `npx autopilot-cc@latest --local` installs to `./.claude/`
- [ ] All files in FILE_MAP copied correctly to destination
- [ ] VERSION file copied to correct location
- [ ] Manifest file created with all entries
- [ ] Hook registered in `settings.json`
- [ ] __INSTALL_BASE__ placeholder replaced in protocol files
- [ ] No errors on first install

**Reinstall (Idempotency):**
- [ ] Running install twice doesn't create duplicate hooks
- [ ] Second install doesn't error on existing files
- [ ] Manifest updated with new hash values if files changed

**Uninstall Flow:**
- [ ] `npx autopilot-cc@latest --uninstall` removes all installed files
- [ ] Empty directories cleaned up
- [ ] Hook removed from `settings.json`
- [ ] Other hooks in `settings.json` preserved
- [ ] Manifest file removed

**GSD Dependency Check:**
- [ ] `npx autopilot-cc@latest --check-deps` detects installed GSD >= MIN_GSD_VERSION
- [ ] Warns if GSD not found at `~/.claude/get-shit-done/`
- [ ] Warns if GSD version too old
- [ ] Installation continues even if GSD not found

**Update Check Hook:**
- [ ] Hook runs at session start (background, no blocking)
- [ ] Cache file created at `~/.claude/cache/autopilot-update-check.json`
- [ ] `update_available` flag set correctly
- [ ] `checked` timestamp in Unix seconds
- [ ] `expires` timestamp in ISO 8601 format
- [ ] Hook runs silently (no console output in session)

**Platform-Specific (Windows):**
- [ ] Child process detaches properly (no orphaned console window)
- [ ] File paths work with backslashes in settings.json
- [ ] Hook command paths properly quoted
- [ ] `detached: true` flag working

**Platform-Specific (macOS/Linux):**
- [ ] File paths work with forward slashes
- [ ] Hook runs without elevated permissions
- [ ] Process spawning doesn't hang

**Error Scenarios:**
- [ ] Installation with read-only target directory
- [ ] Uninstall with missing manifest file
- [ ] GSD check with missing GSD directory
- [ ] npm timeout gracefully (update check doesn't block)

---

## Areas Needing Test Coverage

**By criticality:**

| Area | Location | Why Important | Test Type |
|------|----------|---------------|-----------|
| Version comparison logic | `bin/install.js:83-91` | Incorrect comparison blocks installation | Unit |
| File copying correctness | `bin/install.js:250-273` | Silent copy failures break command | Integration |
| Hook idempotency | `bin/install.js:182-203` | Duplicate hooks cause issues | Integration |
| Manifest generation | `bin/install.js:247-277` | Uninstall depends on accuracy | Integration |
| Path construction | `bin/install.js:15-67` | Platform compatibility issues | Integration |
| GSD detection | `bin/install.js:107-125` | Wrong version info misleads user | Integration |
| Settings.json handling | `bin/install.js:174-224` | Can corrupt user settings | Integration |

---

*Testing analysis: 2026-02-17*
