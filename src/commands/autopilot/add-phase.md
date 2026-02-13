---
name: autopilot:add-phase
description: Add a new phase to the roadmap with proper numbering, directory creation, and roadmap entry
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
Add a new phase to the project roadmap. Creates a properly numbered phase with directory structure and roadmap entry. Fully native to autopilot-cc -- no external dependencies.

**Arguments:**
- Phase description: Free-form text describing the new phase (e.g., `"Native Autopilot CLI Commands"`)

**What it does:**
1. Reads ROADMAP.md to determine the next available integer phase number
2. Creates the phase directory at `.planning/phases/{N}-{slug}/`
3. Adds a phase entry to ROADMAP.md with proper formatting
4. Updates the Progress table in ROADMAP.md
5. Reports what was created
</objective>

<execution>

## On Invocation

1. **Parse the phase description** from the user's argument. If no description provided, ask: "What should this phase accomplish? Provide a short description (e.g., 'Native Autopilot CLI Commands')."

2. **Read the roadmap** to determine the next phase number:

```
Read .planning/ROADMAP.md
```

3. **Determine next phase number:**
   - Scan the roadmap for all phase entries matching the pattern `**Phase {N}:` or `### Phase {N}:`
   - Extract all integer phase numbers (ignore decimal phases like 2.1, 3.1)
   - The next phase number = highest integer phase number + 1

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

6. **Add the phase entry to ROADMAP.md:**

   Find the last phase entry in the "## Phases" section (the last line matching `- [ ] **Phase {N}:`) and add the new phase after it using Edit.

   The new entry format:
   ```
   - [ ] **Phase {N}: {Description}** - [To be planned]
   ```

7. **Add the phase detail section to ROADMAP.md:**

   Find the last `### Phase {N}:` detail section and add the new detail section after it using Edit.

   The new detail section format:
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

8. **Update the Progress table:**

   Find the Progress table in ROADMAP.md and add a new row before the last row or at the end:
   ```
   | {N}. {Description} | Not started | - |
   ```

9. **Report to user:**
   ```
   Phase {N} created: {Description}

   Directory: .planning/phases/{N}-{slug}/
   Roadmap: Updated with phase entry and detail section
   Status: Not started

   Next: Define success criteria in ROADMAP.md, then /clear and /autopilot {N}
   ```

## Error Handling

- If ROADMAP.md does not exist: "No ROADMAP.md found at .planning/ROADMAP.md. Create a roadmap first."
- If the phase directory already exists: "Directory .planning/phases/{N}-{slug}/ already exists. Choose a different description or remove the existing directory."
- If no description provided after prompting: "A phase description is required."

</execution>

<success_criteria>
- [ ] Phase number correctly determined from existing roadmap
- [ ] Phase directory created at `.planning/phases/{N}-{slug}/`
- [ ] Roadmap updated with new phase entry in Phases list
- [ ] Roadmap updated with new phase detail section
- [ ] Progress table updated with new row
- [ ] No dependency on external tools or packages
</success_criteria>
