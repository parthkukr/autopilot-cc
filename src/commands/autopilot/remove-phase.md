---
name: autopilot:remove-phase
description: Remove a phase from the roadmap (preserves phase directory for manual cleanup)
argument-hint: <phase-number>
allowed-tools:
  - Read
  - Write
  - Edit
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
Remove a phase from the project roadmap. Removes the phase entry, detail section, progress table row, execution order reference, and STATE.md row. The phase directory is preserved for manual cleanup -- it is NOT deleted automatically. Does NOT renumber other phases (to preserve external references). Fully native to autopilot-cc -- no external dependencies.

**Arguments:**
- Phase number: The phase to remove (integer or decimal, e.g., `27` or `26.3`)

**What it does:**
1. Validates the phase exists in ROADMAP.md
2. Confirms removal with the user before proceeding
3. Removes the phase entry from the ROADMAP.md Phases list
4. Removes the phase detail section from ROADMAP.md
5. Removes the phase row from the ROADMAP.md Progress table
6. Removes the phase number from the ROADMAP.md Execution Order line
7. Removes the phase row from STATE.md "By Phase" table
8. Reports what was removed (phase directory is preserved)
</objective>

<execution>

## On Invocation

1. **Parse the phase number** from the user's argument. If no phase number provided: "Usage: `/autopilot:remove-phase <phase-number>`. Example: `/autopilot:remove-phase 27`"

2. **Read the roadmap** to validate the phase:

```
Read .planning/ROADMAP.md
```

3. **Validate the phase exists:**
   - Extract all phase numbers using the deterministic regex pattern `\*\*Phase (\d+(?:\.\d+)?):` from lines in the Phases list
   - If the specified phase number is not found: "Phase {N} not found in ROADMAP.md. Nothing to remove."
   - Extract the phase description from the matching line for use in confirmation

4. **Check if the phase is completed:**
   - Look at the phase entry checkbox: `[x]` = completed, `[ ]` = not completed
   - If completed, warn: "Warning: Phase {N} is marked as completed. Removing a completed phase may leave gaps in the project history."

5. **Confirm with the user before proceeding:**
   ```
   Remove Phase {N}: {Description}?

   This will remove:
   - Phase entry from the Phases list
   - Phase detail section (Goal, Requirements, Success Criteria, Plans)
   - Progress table row
   - Execution Order reference

   Phase directory at .planning/phases/{N}-{slug}/ will be preserved.
   Delete it manually if no longer needed.

   Proceed? (yes/no)
   ```

   If the user responds "no" or anything other than "yes": "Removal cancelled. No changes made."

6. **Remove the phase entry from the Phases list:**

   Find the line matching `- \[[ x]\] \*\*Phase {N}:` in the Phases list. Remove that entire line using Edit (replace the line with empty string, or use Edit to remove it cleanly).

7. **Remove the phase detail section:**

   Find the detail section starting with `### Phase {N}:`. Identify the end of that section:
   - The section ends at the next line starting with `### Phase ` (the start of the next phase's detail section)
   - Or at the next `## ` heading
   - Or at the end of file

   Remove everything from `### Phase {N}:` up to (but not including) the next section boundary. Use Edit to remove the block.

   **Important:** Include any blank lines between the section and the next heading in the removal.

8. **Remove the Progress table row:**

   Find the row in the Progress table matching `\| {N}\. ` (e.g., `| 27. ` or `| 26.3. `). Remove that entire row using Edit.

9. **Remove from the Execution Order line:**

   Find the execution order line matching `^Phases \d+\+: `.

   Remove the phase number from the ` -> ` separated list:
   - If the phase is at the start: remove `{N} -> ` from the beginning
   - If the phase is in the middle: remove ` -> {N}` or `{N} -> ` preserving the chain
   - If the phase is at the end: remove ` -> {N}` from the end
   - If the phase is the only entry: remove the entire execution order line

   Use Edit to update the line.

10. **Remove from STATE.md "By Phase" table:**

   Read `.planning/STATE.md`. Find the row matching `\| {N} \|` or `\| {N} ` in the "By Phase" table. Remove that row using Edit.

   If STATE.md does not exist, skip and log: "STATE.md not found -- skipping state update."

11. **Report to user:**
   ```
   Phase {N} removed: {Description}

   Removed from:
   - ROADMAP.md Phases list
   - ROADMAP.md detail section
   - ROADMAP.md Progress table
   - ROADMAP.md Execution Order
   - STATE.md "By Phase" table

   Phase directory preserved at: .planning/phases/{N}-{slug}/
   Delete it manually if no longer needed: rm -rf .planning/phases/{N}-{slug}/

   Note: Other phase numbers were NOT renumbered to preserve external references.
   ```

## Error Handling

- If ROADMAP.md does not exist: "No ROADMAP.md found at .planning/ROADMAP.md. Nothing to remove."
- If the phase does not exist: "Phase {N} not found in ROADMAP.md. Nothing to remove."
- If no phase number provided: "Usage: `/autopilot:remove-phase <phase-number>`. Example: `/autopilot:remove-phase 27`"
- If a section cannot be found for removal (e.g., detail section missing): Log warning "Detail section for Phase {N} not found -- skipping." Continue with other removals.
- If Phase directory does not exist: Note in report "No phase directory found for Phase {N}."

</execution>

<success_criteria>
- [ ] Phase validated as existing before removal
- [ ] User confirmation obtained before any changes
- [ ] Phase entry removed from ROADMAP.md Phases list
- [ ] Phase detail section removed from ROADMAP.md
- [ ] Progress table row removed from ROADMAP.md
- [ ] Execution Order reference removed from ROADMAP.md
- [ ] STATE.md "By Phase" table row removed
- [ ] Phase directory preserved (not deleted) with manual cleanup instructions
- [ ] Other phase numbers NOT renumbered
- [ ] No dependency on external tools or packages
</success_criteria>
