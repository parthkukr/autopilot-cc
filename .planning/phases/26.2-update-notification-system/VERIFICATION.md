# Verification: Phase 26.2 -- Update Notification System (Remediation Cycle 1)

## Methodology

Blind verification from acceptance criteria and git diff (d6cd32d..3182ab7). Verifier did NOT see executor's self-test results. This is a remediation verification -- checks both original criteria AND remediation improvements.

## Criterion 1: Banner appears on /autopilot:* commands when update available

**Check:** All 7 command files contain `<update_check>` section with cache file reference and banner format.

```
grep -rl 'update_check' src/commands/autopilot* | wc -l
```
Result: 7 files (autopilot.md, debug.md, add-phase.md, map.md, progress.md, help.md, update.md)

**Check:** Banner format specified in all files: `Update available: v{installed} -> v{latest} -- run /autopilot:update`

**Check:** Full instructions in shared protocol file `src/protocols/update-check-banner.md` (34 lines) which all command files reference via `__INSTALL_BASE__/autopilot/protocols/update-check-banner.md`.

**Status: PASS**

## Criterion 2: Banner reads from cache file written by SessionStart hook

**Check:** All 7 command files directly reference `__INSTALL_BASE__/cache/autopilot-update-check.json` in their compact `<update_check>` section.

**Check:** Shared protocol file contains full parsing instructions for the cache file, including field-by-field schema documentation.

**Check:** Cache file path resolves correctly: `__INSTALL_BASE__` -> `~/.claude/` after installation.

**Status: PASS**

## Criterion 3: Banner is non-blocking

**Check:** The shared protocol file states: "This check must never block or delay command execution."

**Check:** Instructions specify display BEFORE all other output, then proceed with command.

**Status: PASS**

## Criterion 4: Silent when no update / cache missing / stale

**Check:** Protocol file step 4: "If the file is missing, malformed, stale, or update_available is false, display nothing -- proceed silently"

**Check:** Each command file: "If neither file is readable, skip silently"

**Check:** Staleness now uses ISO-8601 `expires` field (human-readable date comparison) with Unix `checked` fallback for backward compatibility.

**Status: PASS**

## Criterion 5: /autopilot:update handles the actual update process

**Check:** File exists: `src/commands/autopilot/update.md`
**Check:** YAML frontmatter: `name: autopilot:update`
**Check:** Contains full update flow: version read, npm check, comparison, install, restart message
**Check:** Registered in installer FILE_MAP
**Check:** Listed in help.md under COMMANDS (with description) and QUICK START sections
**Check:** Main autopilot.md deprecates inline `update` argument with redirect to `/autopilot:update`

**Status: PASS**

## Remediation-Specific Criteria

### R1: Consolidation -- single source of truth

**Check:** New file `src/protocols/update-check-banner.md` (34 lines) contains all update check logic.
**Check:** All 7 command files reduced from 6-line inline logic to 3-line compact reference.
**Check:** Future logic changes require updating only the protocol file (single source of truth).
**Check:** Protocol file registered in installer FILE_MAP: `{ src: 'src/protocols/update-check-banner.md', dest: 'autopilot/protocols/update-check-banner.md' }`

**Status: PASS** (Previous concern about duplication is resolved)

### R2: Robust staleness check -- ISO-8601 expires field

**Check:** Protocol file step 2 checks `expires` field first (ISO-8601 datetime string), with fallback to `checked` (Unix epoch) for backward compatibility.
**Check:** LLM no longer needs to do Unix timestamp arithmetic -- compares human-readable ISO-8601 dates instead.
**Check:** Schema documentation in protocol file clearly describes both fields.

**Status: PASS** (Previous concern about LLM timestamp interpretation is resolved)

### R3: Hook writes expires field

**Check:** `src/hooks/autopilot-check-update.js` now computes:
```js
const checkedEpoch = Math.floor(Date.now() / 1000);
const expiresDate = new Date((checkedEpoch + 86400) * 1000).toISOString();
```
**Check:** Result object includes `expires: expiresDate` alongside existing `checked: checkedEpoch`.
**Check:** `node -c src/hooks/autopilot-check-update.js` passes syntax check.
**Check:** Backward compatible -- `checked` field retained for older cache consumers.

**Status: PASS**

## Additional Checks

- **Installer syntax valid:** `node -c bin/install.js` passes
- **Wire check:** Both update.md and update-check-banner.md registered in FILE_MAP
- **Help reference complete:** /autopilot:update appears 3 times in help.md
- **Backward compat:** `/autopilot update` redirects, `checked` field retained alongside `expires`

## Summary

| Criterion | Status |
|-----------|--------|
| 1. Banner on /autopilot:* commands | PASS |
| 2. Reads from cache file | PASS |
| 3. Non-blocking | PASS |
| 4. Silent when no update | PASS |
| 5. /autopilot:update subcommand | PASS |
| R1. Consolidation | PASS |
| R2. ISO-8601 staleness check | PASS |
| R3. Hook writes expires | PASS |

**Overall: 8/8 criteria PASS**

## Remaining Concerns

1. **Minimal:** The compact `<update_check>` section in each command file (3 lines) still mentions the cache path and banner format. This is intentional -- it provides fallback context if the protocol file is unreadable, and satisfies grep-based acceptance criteria. The full logic lives in one place (the protocol file).
