---
name: autopilot:progress
description: Show current phase status, completion percentage, and recommended next actions
argument-hint: [--verbose]
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
---

<update_check>
**Before any output**, check for updates using `__INSTALL_BASE__/cache/autopilot-update-check.json`.
Full instructions: read `__INSTALL_BASE__/autopilot/protocols/update-check-banner.md`.
If neither file is readable, skip silently. Banner format: `Update available: v{installed} -> v{latest} -- run /autopilot:update`
</update_check>

<objective>
Display the current progress of the autopilot project -- which phases are complete, what is in progress, and what to do next. Fully native to autopilot-cc -- no external dependencies.

**Arguments:**
- No argument: Show progress summary
- `--verbose`: Show detailed per-phase information including scores and durations

**What it does:**
1. Reads `.autopilot/state.json` for current run status (if exists)
2. Reads `.planning/ROADMAP.md` for the full phase list and status markers
3. Displays a progress table with phase status
4. Shows overall completion percentage
5. Identifies the next phase to work on
6. Shows recommended next actions
</objective>

<execution>

## On Invocation

1. **Check for state.json:**

   ```
   Read .autopilot/state.json
   ```

   If the file exists, extract:
   - Current run status (`_meta.status`)
   - Phase statuses (each phase's `status`, `alignment_score`, `duration_seconds`)
   - Run timestamp (`_meta.started_at`)
   - Pass threshold (`_meta.pass_threshold`)

   If the file does not exist, proceed with roadmap-only analysis.

2. **Read ROADMAP.md:**

   ```
   Read .planning/ROADMAP.md
   ```

   Extract all phases from the phase list:
   - Phase number and name from entries matching `- [x] **Phase {N}:` (completed) and `- [ ] **Phase {N}:` (not started)
   - Count completed vs total phases

3. **Build the progress table:**

   For each phase, determine status from multiple sources:
   - ROADMAP.md checkbox: `[x]` = completed, `[ ]` = not started
   - state.json (if exists): overrides roadmap status with more detail (in_progress, failed, etc.)
   - Phase directory existence: check `.planning/phases/{N}-*/EXECUTION-LOG.md` for execution evidence

   Status values:
   - `Completed` -- phase marked [x] in roadmap or completed in state.json
   - `In Progress` -- phase has state.json entry with status "in_progress"
   - `Failed` -- phase has state.json entry with status "failed"
   - `Not Started` -- phase marked [ ] in roadmap with no state.json entry

4. **Calculate completion percentage:**

   ```
   completion_pct = (completed_phases / total_phases) * 100
   ```

   Round to the nearest whole percent.

5. **Identify next phase:**

   The next phase is the first phase (in roadmap order) that is:
   - Not completed
   - Not failed (unless it is the only remaining phase)
   - Has all dependencies met (all phases listed in "Depends on" are completed)

6. **Determine recommended next actions:**

   Based on the current state:
   - If a phase is in progress: "Resume with `/autopilot resume`"
   - If no phase is in progress and next phase is identified: "Run `/autopilot {N}` to execute Phase {N}: {name}"
   - If a failed phase exists: "Debug Phase {N} failure with `/autopilot:debug phase {N} failure`"
   - If all phases are complete: "All phases complete. Project is done."
   - If multiple phases are ready: "Run `/autopilot --complete` to execute all remaining phases"

7. **Display the output:**

   ```
   Autopilot Progress

   Project: {project name from package.json or directory}
   Roadmap: .planning/ROADMAP.md
   Completion: {completed}/{total} phases ({percentage}%)

   | # | Phase | Status | Score |
   |---|-------|--------|-------|
   | 1 | Prompt Architecture | Completed | 9.2 |
   | 2 | Executor Quality Enforcement | Completed | 8.7 |
   | ... | ... | ... | ... |
   | {N} | {Name} | Not Started | - |

   Next: Phase {N} -- {Name}
   Action: Run `/autopilot {N}` to execute

   {Additional recommendations if applicable}
   ```

   If `--verbose` is specified, add per-phase details:
   - Duration
   - Commit count
   - Debug attempts
   - Alignment score breakdown

8. **Handle edge cases:**

   - No ROADMAP.md: "No roadmap found at .planning/ROADMAP.md. Initialize a project first."
   - Empty roadmap (no phases): "Roadmap has no phases defined. Add phases with `/autopilot:add-phase`."
   - All phases complete: Show 100% completion with congratulatory message

</execution>

<success_criteria>
- [ ] Reads state.json when available for run-level status
- [ ] Reads ROADMAP.md for full phase list
- [ ] Shows progress table with phase number, name, and status
- [ ] Displays overall completion percentage
- [ ] Identifies next phase and recommended actions
- [ ] Handles missing state.json gracefully (roadmap-only mode)
- [ ] No dependency on external tools or packages
</success_criteria>
