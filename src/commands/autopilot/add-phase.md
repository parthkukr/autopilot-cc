---
name: autopilot:add-phase
description: Add a new phase to the roadmap with deterministic parsing, directory creation, and full roadmap/STATE.md updates
argument-hint: <phase description>
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
Add a new integer phase to the project roadmap. Uses deterministic regex-based parsing to extract phase numbers and update all roadmap sections atomically. Fully native to autopilot-cc -- no external dependencies.

**Arguments:**
- Phase description: Free-form text describing the new phase (e.g., `"Native Autopilot CLI Commands"`)

**What it does:**
1. Reads ROADMAP.md and deterministically extracts all phase numbers using regex patterns
2. Computes the next available integer phase number
3. Creates the phase directory at `.planning/phases/{N}-{slug}/`
4. Adds a phase entry to the ROADMAP.md Phases list
5. Adds a fully scaffolded phase detail section (Goal, Requirements, Success Criteria, Plans)
6. Updates the ROADMAP.md Progress table with a new row
7. Updates the ROADMAP.md Execution Order line
8. Updates STATE.md "By Phase" table with a new row
9. Reports what was created
</objective>

<execution>

## On Invocation

1. **Parse the phase description** from the user's argument. If no description provided, ask: "What should this phase accomplish? Provide a short description (e.g., 'Native Autopilot CLI Commands')."

2. **Read the roadmap** for deterministic phase number extraction:

```
Read .planning/ROADMAP.md
```

3. **Deterministic phase number extraction using regex patterns:**
   - Extract all phase numbers from lines matching the pattern `\*\*Phase (\d+(?:\.\d+)?):` (captures both integer and decimal phases)
   - Filter to integer-only phase numbers (those without a decimal point)
   - Sort numerically and take the highest integer phase number
   - The next phase number = highest integer phase number + 1
   - If no phases exist, start at Phase 1

   **Parsing rules:**
   - Phase entries in the Phases list match: `- \[[ x]\] \*\*Phase (\d+):`
   - Phase detail sections match: `### Phase (\d+(?:\.\d+)?):`
   - Progress table rows match: `\| (\d+(?:\.\d+)?)\. `
   - Execution order lines match: `Phases \d+\+: (.+)` where the content is a ` -> ` separated list of phase numbers

4. **Generate the slug** from the description:
   - Convert to lowercase
   - Replace spaces and special characters with hyphens
   - Remove consecutive hyphens
   - Trim to max 40 characters
   - Example: "Native Autopilot CLI Commands" -> "native-autopilot-cli-commands"

5. **Create the phase directory:**

```bash
mkdir -p .planning/phases/{N}-{slug}
```

6. **Add the phase entry to the ROADMAP.md Phases list:**

   Find the last phase entry in the "## Phases" section. The last entry is the last line matching the regex `^- \[[ x]\] \*\*Phase \d+`. Add the new phase entry AFTER that line using Edit.

   New entry format:
   ```
   - [ ] **Phase {N}: {Description}** - [To be planned]
   ```

7. **Add the phase detail section to ROADMAP.md:**

   Find the last `### Phase` detail section in the file. Locate the end of that section (the line before the next section starting with `## ` or `### Phase`, or the end of file). Add the new detail section there using Edit.

   New detail section format (with full scaffolding):
   ```markdown
   ### Phase {N}: {Description}
   **Goal**: [To be planned]
   **Depends on**: Phase {N-1} (independent)
   **Requirements**: TBD (to be defined during planning)
   **Success Criteria** (what must be TRUE):
     1. [To be defined]

   Plans:
   - [ ] TBD (run /clear then /autopilot {N} to execute)
   ```

8. **Update the Progress table in ROADMAP.md:**

   Find the Progress table (the markdown table under `## Progress` or after `**Execution Order:**`). Locate the last data row (the last line matching `\| \d+`). Add the new row AFTER it using Edit.

   New row format:
   ```
   | {N}. {Description} | Not started | - |
   ```

9. **Update the Execution Order in ROADMAP.md:**

   Find the execution order line that lists the most recent phases. This matches the pattern `^Phases \d+\+: ` followed by a ` -> ` separated list of phase numbers (e.g., `Phases 17+: 17 -> 18 -> 19 -> ... -> 26.4`).

   Append ` -> {N}` to the end of that line using Edit.

   If the execution order line does not exist, add one:
   ```
   Phases {N}+: {N}
   ```

10. **Update STATE.md "By Phase" table:**

   Read `.planning/STATE.md`. Find the "By Phase" table (lines matching `\| \d+`). Locate the last data row and add the new row AFTER it using Edit.

   New row format:
   ```
   | {N} | {Description} | Not Started | - |
   ```

   If STATE.md does not exist, skip this step and log: "STATE.md not found -- skipping state update."

11. **Report to user:**
   ```
   Phase {N} created: {Description}

   Directory: .planning/phases/{N}-{slug}/
   Roadmap: Updated (Phases list, detail section, Progress table, Execution Order)
   State: Updated (STATE.md "By Phase" table)
   Status: Not started

   Next: Define success criteria in ROADMAP.md, then /clear and /autopilot {N}
   ```

## Error Handling

- If ROADMAP.md does not exist: "No ROADMAP.md found at .planning/ROADMAP.md. Create a roadmap first."
- If the phase directory already exists: "Directory .planning/phases/{N}-{slug}/ already exists. Choose a different description or remove the existing directory."
- If no description provided after prompting: "A phase description is required."
- If the Progress table cannot be found: Log warning "Progress table not found in ROADMAP.md -- skipping progress table update." Continue with other updates.
- If the Execution Order line cannot be found: Log warning "Execution Order line not found in ROADMAP.md -- skipping execution order update." Continue with other updates.

</execution>

<success_criteria>
- [ ] Phase number correctly determined using deterministic regex-based parsing
- [ ] Phase directory created at `.planning/phases/{N}-{slug}/`
- [ ] Roadmap updated with new phase entry in Phases list
- [ ] Roadmap updated with fully scaffolded phase detail section (Goal, Requirements, Success Criteria, Plans)
- [ ] Progress table updated with new row
- [ ] Execution Order line updated with new phase number
- [ ] STATE.md "By Phase" table updated with new row
- [ ] No dependency on external tools or packages
</success_criteria>
