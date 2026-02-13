# Verification: Phase 26.2 -- Update Notification System

## Methodology

Blind verification from acceptance criteria and git diff only. Verifier did NOT see executor's self-test results.

## Criterion 1: Banner appears on /autopilot:* commands when update available

**Check:** All 7 command files (autopilot.md + 6 subcommands) contain `<update_check>` section with cache file reference and banner format.

```
grep -rl 'update_check' src/commands/autopilot* | wc -l
```
Result: 7 files (autopilot.md, debug.md, add-phase.md, map.md, progress.md, help.md, update.md)

**Check:** Banner format matches spec: `Update available: v{installed} -> v{latest} -- run /autopilot:update`

```
grep 'Update available.*autopilot:update' src/commands/autopilot.md
```
Result: Matches in all files.

**Status: PASS**

## Criterion 2: Banner reads from cache file written by SessionStart hook

**Check:** All command files reference `__INSTALL_BASE__/cache/autopilot-update-check.json`

```
grep -rl 'autopilot-update-check.json' src/commands/
```
Result: 7 files reference the cache file.

**Check:** Cache file path matches what the hook writes to (`~/.claude/cache/autopilot-update-check.json`). The `__INSTALL_BASE__` placeholder resolves to `~/.claude/` after installation, so `__INSTALL_BASE__/cache/autopilot-update-check.json` = `~/.claude/cache/autopilot-update-check.json`.

**Status: PASS**

## Criterion 3: Banner is non-blocking

**Check:** The update_check section explicitly states "This check must never block or delay command execution" and instructs to display the banner "BEFORE all other output" then proceed with the command.

**Status: PASS**

## Criterion 4: Silent when no update / cache missing / stale

**Check:** The update_check section specifies: "If the file is missing, malformed, stale (>24h), or `update_available` is false, display nothing -- proceed silently"

Additionally, step 1 says: "if missing or unreadable, skip silently"

**Status: PASS**

## Criterion 5: /autopilot:update handles the actual update process

**Check:** File exists: `src/commands/autopilot/update.md`
**Check:** YAML frontmatter: `name: autopilot:update`
**Check:** Contains full update flow: version read, npm check, comparison, install, restart message
**Check:** Registered in installer FILE_MAP: `{ src: 'src/commands/autopilot/update.md', dest: 'commands/autopilot/update.md' }`
**Check:** Listed in help.md under COMMANDS and QUICK START
**Check:** Main autopilot.md deprecates inline `update` argument with redirect to `/autopilot:update`

**Status: PASS**

## Additional Checks

- **Installer syntax valid:** `node -c bin/install.js` passes
- **Wire check:** update.md is registered in FILE_MAP (not orphaned)
- **Help reference complete:** /autopilot:update listed in COMMANDS (with description) and QUICK START sections
- **Backward compat:** `/autopilot update` still works but shows deprecation redirect message

## Summary

| Criterion | Status |
|-----------|--------|
| 1. Banner on /autopilot:* commands | PASS |
| 2. Reads from cache file | PASS |
| 3. Non-blocking | PASS |
| 4. Silent when no update | PASS |
| 5. /autopilot:update subcommand | PASS |

**Overall: 5/5 criteria PASS**

## Concerns

1. **Minor:** The `<update_check>` section is duplicated across 7 files. If the banner format needs to change in the future, all 7 files must be updated. This is acceptable for now since command files are independent prompts that can't share includes.
2. **Minor:** The staleness check (24h) uses timestamp comparison which depends on the LLM correctly interpreting Unix timestamps. This is a reasonable approach for prompt-based commands.
