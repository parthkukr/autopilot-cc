---
phase_id: "26.2"
phase_name: "Update Notification System"
task_count: 3
estimated_complexity: low
checkpoint_tasks: []
---

# Plan: Phase 26.2 -- Update Notification System

## Overview

Wire the existing SessionStart hook cache (`~/.claude/cache/autopilot-update-check.json`) into a passive update banner shown on every `/autopilot:*` command invocation, and create an `/autopilot:update` subcommand.

## Tasks

### Task 1: Add update banner instructions to all `/autopilot:*` command files

**Type:** auto
**Complexity:** low
**Files to modify:**
- `src/commands/autopilot.md`
- `src/commands/autopilot/debug.md`
- `src/commands/autopilot/add-phase.md`
- `src/commands/autopilot/map.md`
- `src/commands/autopilot/progress.md`
- `src/commands/autopilot/help.md`

**Description:** Add an `<update_check>` section to each command file that instructs the LLM agent to:
1. Read `__INSTALL_BASE__/cache/autopilot-update-check.json` silently (no error if missing)
2. If the file exists and `update_available` is `true` and `checked` is within the last 86400 seconds (24h), display a single banner line BEFORE any other output: `Update available: v{installed} -> v{latest} -- run /autopilot:update`
3. If the file is missing, malformed, stale (>24h), or `update_available` is false, display nothing

This section goes right after the YAML frontmatter (before `<objective>`) so it's the first instruction the agent processes.

**Acceptance Criteria:**
- `grep -c 'update_check' src/commands/autopilot.md` returns >= 1
- `grep -c 'update_check' src/commands/autopilot/debug.md` returns >= 1
- `grep -c 'update_check' src/commands/autopilot/add-phase.md` returns >= 1
- `grep -c 'update_check' src/commands/autopilot/map.md` returns >= 1
- `grep -c 'update_check' src/commands/autopilot/progress.md` returns >= 1
- `grep -c 'update_check' src/commands/autopilot/help.md` returns >= 1
- `grep -c 'autopilot-update-check.json' src/commands/autopilot.md` returns >= 1
- `grep 'autopilot:update' src/commands/autopilot/debug.md` matches (banner text references the update command)

### Task 2: Create `/autopilot:update` subcommand

**Type:** auto
**Complexity:** low
**Files to create:**
- `src/commands/autopilot/update.md`

**Description:** Create the `/autopilot:update` command file using the same colon-syntax pattern as other subcommands. Extract the update logic currently inline in `autopilot.md` (the `### If update:` section) into a dedicated command file. The command should:
1. Read installed version from `__INSTALL_BASE__/autopilot/VERSION`
2. Check npm: run `npm view autopilot-cc version`
3. If same version, say "Already up to date (vX.Y.Z)" and stop
4. If update available: show "Update available: vX.Y.Z -> vA.B.C. Installing..."
5. Run `npx autopilot-cc@latest` (preserving --global/--local based on current install location)
6. Show "Restart Claude Code to activate the update"

Also include the same `<update_check>` banner section (for consistency, though it will typically show the banner then immediately handle the update).

**Acceptance Criteria:**
- `test -f src/commands/autopilot/update.md` succeeds
- `grep 'name: autopilot:update' src/commands/autopilot/update.md` matches
- `grep 'npm view autopilot-cc version' src/commands/autopilot/update.md` matches
- `grep 'npx autopilot-cc@latest' src/commands/autopilot/update.md` matches
- `grep '__INSTALL_BASE__/autopilot/VERSION' src/commands/autopilot/update.md` matches

### Task 3: Register update.md in installer FILE_MAP and update help reference

**Type:** auto
**Complexity:** low
**Files to modify:**
- `bin/install.js`
- `src/commands/autopilot/help.md`
- `src/commands/autopilot.md`

**Description:**
1. Add `{ src: 'src/commands/autopilot/update.md', dest: 'commands/autopilot/update.md' }` to the FILE_MAP in `bin/install.js`
2. Add `/autopilot:update` to the help reference in `help.md` under COMMANDS
3. Update the main `autopilot.md` to reference `/autopilot:update` instead of handling update inline (keep backward compat: if user runs `/autopilot update`, tell them to use `/autopilot:update` instead)

**Acceptance Criteria:**
- `grep "autopilot/update.md" bin/install.js` matches (FILE_MAP entry)
- `grep 'autopilot:update' src/commands/autopilot/help.md` matches
- `grep -c 'autopilot:update' src/commands/autopilot/help.md` returns >= 2 (in COMMANDS and QUICK START sections)
