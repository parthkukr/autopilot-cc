---
name: autopilot:insert-phase
description: Insert a new decimal phase after an existing phase (e.g., 26.1 after 26)
argument-hint: <after-phase-number> <description>
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
Insert a new decimal phase after an existing phase in the project roadmap. Decimal phases are urgent insertions that appear between their surrounding integers (e.g., 26.1 after Phase 26, 26.2 after 26.1). Uses deterministic regex-based parsing. Fully native to autopilot-cc -- no external dependencies.

**Arguments:**
- After phase number: The integer or decimal phase number to insert after (e.g., `26` to create 26.1, or `26.1` to create 26.2)
- Phase description: Free-form text describing the new phase (e.g., `"Bug Fix Rollup"`)

**Usage examples:**
- `/autopilot:insert-phase 26 "Bug Fix Rollup"` -- creates Phase 26.1
- `/autopilot:insert-phase 26.2 "Hotfix"` -- creates Phase 26.3
- `/autopilot:insert-phase 3 "Urgent Patch"` -- creates Phase 3.1

**What it does:**
1. Reads ROADMAP.md and deterministically extracts all phase numbers using regex patterns
2. Validates the parent phase exists
3. Computes the next available decimal phase number after the specified parent (N.M where M is the next unused decimal)
4. Creates the phase directory at `.planning/phases/{N.M}-{slug}/`
5. Adds a phase entry to the ROADMAP.md Phases list in correct position with *(INSERTED)* marker
6. Adds a fully scaffolded phase detail section (Goal, Requirements, Success Criteria, Plans)
7. Updates the ROADMAP.md Progress table with a new row in correct position
8. Updates the ROADMAP.md Execution Order line, inserting the decimal phase after its parent
9. Updates STATE.md "By Phase" table with a new row in correct position
10. Reports what was created
</objective>

<execution>

## On Invocation

1. **Parse arguments:** Extract the after-phase-number and description from the user's input.
   - If the after-phase-number is missing: "Usage: `/autopilot:insert-phase <after-phase-number> <description>`. Example: `/autopilot:insert-phase 26 \"Bug Fix Rollup\"`"
   - If the description is missing: "What should this inserted phase accomplish? Provide a short description."

2. **Read the roadmap** for deterministic phase number extraction:

```
Read .planning/ROADMAP.md
```

3. **Validate the parent phase exists:**
   - Extract all phase numbers from the roadmap using the regex pattern `\*\*Phase (\d+(?:\.\d+)?):` from lines in the Phases list
   - If the specified after-phase-number does not exist in the extracted list, report error: "Phase {after-phase-number} not found in ROADMAP.md. Cannot insert after a non-existent phase."

4. **Deterministic decimal phase number computation:**
   - Determine the base integer: if after-phase-number is an integer N, base = N. If after-phase-number is a decimal N.M, base = N.
   - Extract all existing decimal phases under the same base integer: filter for phases matching `{base}.\d+`
   - If no decimal phases exist under this base: new phase number = `{base}.1`
   - If decimal phases exist: find the highest decimal component M, new phase number = `{base}.{M+1}`
   - Example: if 26.1 and 26.2 exist, next is 26.3. If none exist, next is 26.1.

   **Parsing rules:**
   - Phase entries in the Phases list match: `- \[[ x]\] \*\*Phase (\d+(?:\.\d+)?):`
   - Decimal extraction regex: `(\d+)\.(\d+)` to split base and decimal parts

5. **Generate the slug** from the description:
   - Convert to lowercase
   - Replace spaces and special characters with hyphens
   - Remove consecutive hyphens
   - Trim to max 40 characters

6. **Create the phase directory:**

```bash
mkdir -p .planning/phases/{N.M}-{slug}
```

7. **Add the phase entry to ROADMAP.md Phases list (in correct position):**

   Find the line for the parent phase (the after-phase-number) in the Phases list. If inserting after an integer phase, also check for existing decimal phases after it -- find the LAST decimal phase of that base integer (e.g., if inserting after 26 and 26.1, 26.2 already exist, insert after 26.2). Add the new entry AFTER that line using Edit.

   New entry format:
   ```
   - [ ] **Phase {N.M}: {Description}** *(INSERTED)* - [To be planned]
   ```

8. **Add the phase detail section to ROADMAP.md (in correct position):**

   Find the detail section for the parent phase or the last decimal sibling. Locate the end of that section (before the next `### Phase` heading). Add the new detail section there using Edit.

   New detail section format (with full scaffolding):
   ```markdown
   ### Phase {N.M}: {Description} *(INSERTED)*
   **Goal**: [To be planned]
   **Depends on**: Phase {base_integer} (parent phase)
   **Requirements**: TBD (to be defined during planning)
   **Success Criteria** (what must be TRUE):
     1. [To be defined]

   Plans:
   - [ ] TBD (run /clear then /autopilot {N.M} to execute)
   ```

9. **Update the Progress table in ROADMAP.md (in correct position):**

   Find the Progress table. Locate the row for the parent phase (or the last decimal sibling row). Add the new row AFTER that row using Edit.

   New row format:
   ```
   | {N.M}. {Description} | Not started | - |
   ```

10. **Update the Execution Order in ROADMAP.md:**

   Find the execution order line (matching `^Phases \d+\+: `). This is a ` -> ` separated list of phase numbers.

   Insert the new decimal phase number in the correct position:
   - Find the parent phase number (after-phase-number) in the execution order list
   - If inserting after an integer and decimal siblings exist, find the last decimal sibling in the list
   - Insert the new phase number AFTER the parent (or last sibling) in the ` -> ` chain

   Use Edit to update the line.

11. **Update STATE.md "By Phase" table (in correct position):**

   Read `.planning/STATE.md`. Find the "By Phase" table. Locate the row for the parent phase (or last decimal sibling). Add the new row AFTER it using Edit.

   New row format:
   ```
   | {N.M} | {Description} | Not Started | - |
   ```

   If STATE.md does not exist, skip and log: "STATE.md not found -- skipping state update."

12. **Report to user:**
   ```
   Phase {N.M} inserted: {Description} (INSERTED after Phase {after-phase-number})

   Directory: .planning/phases/{N.M}-{slug}/
   Roadmap: Updated (Phases list, detail section, Progress table, Execution Order)
   State: Updated (STATE.md "By Phase" table)
   Status: Not started

   Next: Define success criteria in ROADMAP.md, then /clear and /autopilot {N.M}
   ```

## Error Handling

- If ROADMAP.md does not exist: "No ROADMAP.md found at .planning/ROADMAP.md. Create a roadmap first."
- If the parent phase does not exist: "Phase {after-phase-number} not found in ROADMAP.md. Cannot insert after a non-existent phase."
- If the phase directory already exists: "Directory .planning/phases/{N.M}-{slug}/ already exists. Choose a different description or remove the existing directory."
- If no description provided after prompting: "A phase description is required."
- If the Progress table cannot be found: Log warning "Progress table not found in ROADMAP.md -- skipping progress table update." Continue with other updates.
- If the Execution Order line cannot be found: Log warning "Execution Order line not found in ROADMAP.md -- skipping execution order update." Continue with other updates.

</execution>

<success_criteria>
- [ ] Decimal phase number correctly computed from existing roadmap using deterministic regex parsing
- [ ] Parent phase validated before insertion
- [ ] Phase directory created at `.planning/phases/{N.M}-{slug}/`
- [ ] Roadmap updated with new phase entry in correct position with *(INSERTED)* marker
- [ ] Roadmap updated with fully scaffolded phase detail section (Goal, Requirements, Success Criteria, Plans)
- [ ] Progress table updated with new row in correct position
- [ ] Execution Order line updated with new phase number in correct position
- [ ] STATE.md "By Phase" table updated with new row in correct position
- [ ] No dependency on external tools or packages
</success_criteria>
