---
name: autopilot:add-phase
description: Add new phases to the roadmap -- accepts freeform input of any complexity and auto-decomposes into multiple phases when appropriate
argument-hint: <freeform description>
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
Intelligently add one or more phases to the project roadmap from freeform input of any complexity. Accepts anything from a one-liner to a stream-of-consciousness brain dump mixing multiple features, bugs, and improvements. Automatically determines whether the input maps to one phase or should be decomposed into multiple phases. When decomposition is needed, presents the breakdown to the user for approval before creating anything.

**Arguments:**
- Freeform description: Any text describing what needs to be done -- from a short phrase to a detailed multi-paragraph description mixing multiple concerns. The full text is used for semantic analysis; nothing is truncated or lost.

**What it does:**
1. Accepts freeform input of any length without truncation
2. Semantically analyzes the input to determine if it describes one coherent unit of work or multiple distinct items
3. For single-item inputs: creates one phase instantly via the fast path (no overhead)
4. For multi-item inputs: presents a numbered decomposition for user approval, then batch-creates all approved phases with proper numbering and dependency chains
5. Each created phase gets: directory, ROADMAP.md entry (Phases list + detail section + Progress table + Execution Order), and STATE.md entry
</objective>

<execution>

## On Invocation

### Step 1: Accept Freeform Input

Accept the user's argument as freeform text of any length. Do NOT truncate or summarize the input -- preserve every detail for analysis.

If no description provided, ask: "What should this phase accomplish? Describe what you need -- from a one-liner to a detailed brain dump mixing features, bugs, and improvements."

If no description provided after prompting: "A phase description is required."

### Step 2: Semantic Analysis -- Single vs. Multi-Phase Decision

Analyze the freeform input to determine how many distinct units of work are described. This uses semantic understanding, not keyword matching or length-based heuristics.

**Decision criteria -- the "single coherent unit" test:**
Ask: "Could this entire description be delivered and verified independently as one phase?" If yes, it is one phase. If the description contains items that could each be independently delivered and verified, it is multiple phases.

**Analysis guidelines:**
- Look for distinct features, bugs, or improvements that could be independently delivered and verified
- Mixing of concerns (UI + backend + infrastructure) does NOT automatically mean multiple phases -- it is multiple phases only if the items are independently deliverable
- Length alone does not determine decomposition -- a long detailed description of one feature is still one phase
- Structured lists (bullet points, numbered items) that each describe a separate deliverable ARE likely multiple phases
- When in doubt, treat as a single phase (do not over-decompose)
- A description that focuses on one goal but mentions implementation details, edge cases, or subtasks is still one phase

**For each detected item, determine:**
- A concise title (2-6 words)
- A one-sentence description
- Complexity category: small fix, feature, infrastructure, or research
- Whether it depends on any of the other detected items

**Decision routing:**
- **1 coherent unit of work detected:** Proceed to Step 3 (Single-Phase Fast Path)
- **2+ distinct items detected:** Proceed to Step 4 (Decomposition Presentation)

### Step 3: Single-Phase Fast Path (One Coherent Unit)

When the input describes one coherent unit of work, create the phase immediately with zero additional overhead compared to the direct creation path.

1. **Derive the phase title:** From the freeform input, extract or generate a concise title (2-6 words) that captures the essence. Use the original input if it is already short enough.

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

4. **Generate the slug** from the title:
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
   - [ ] **Phase {N}: {Title}** - {One-sentence description from input}
   ```

7. **Add the phase detail section to ROADMAP.md:**

   Find the last `### Phase` detail section in the file. Locate the end of that section (the line before the next section starting with `## ` or `### Phase`, or the end of file). Add the new detail section there using Edit.

   New detail section format (with full scaffolding):
   ```markdown
   ### Phase {N}: {Title}
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
   | {N}. {Title} | Not started | - |
   ```

9. **Update the Execution Order in ROADMAP.md:**

   Find the execution order line that lists the most recent phases. This matches the pattern `^Phases \d+\+: ` followed by a ` -> ` separated list of phase numbers.

   Append ` -> {N}` to the end of that line using Edit.

   If the execution order line does not exist, add one:
   ```
   Phases {N}+: {N}
   ```

10. **Update STATE.md "By Phase" table:**

    Read `.planning/STATE.md`. Find the "By Phase" table (lines matching `\| \d+`). Locate the last data row and add the new row AFTER it using Edit.

    New row format:
    ```
    | {N} | {Title} | Not Started | - |
    ```

    If STATE.md does not exist, skip this step and log: "STATE.md not found -- skipping state update."

11. **Report to user (single phase creation):**
    ```
    Phase {N} created: {Title}

    Directory: .planning/phases/{N}-{slug}/
    Roadmap: Updated (Phases list, detail section, Progress table, Execution Order)
    State: Updated (STATE.md "By Phase" table)
    Status: Not started

    Next: Define success criteria in ROADMAP.md, then /clear and /autopilot {N}
    ```

### Step 4: Decomposition Presentation (Multiple Distinct Items)

When 2+ distinct items are detected in the input, present a numbered breakdown to the user before creating anything.

**Presentation format:**
```
I see {N} distinct items in your description:

1. {Title 1} -- {One-sentence description}
2. {Title 2} -- {One-sentence description}
3. {Title 3} -- {One-sentence description}
...

These would be better as separate phases so each can be independently delivered and verified.

Approve this breakdown? (approve / adjust / single phase)
```

**User response handling:**

- **"approve" or "yes":** Proceed to Step 5 (Batch Phase Creation) with the presented decomposition.

- **"adjust":** Ask the user what to change. Accept freeform adjustments such as:
  - "merge 1 and 2" -- combine items into one phase
  - "rename 3 to X" -- change a title
  - "remove 2" -- drop an item
  - "add: {new item}" -- add a new item
  - "split 1 into two: A and B" -- further decompose
  Apply the changes to the breakdown and re-present the updated numbered list for approval. Repeat until the user approves.

- **"single phase" or "single":** Override the decomposition. Derive a single encompassing title from the full input and proceed to Step 3 (Single-Phase Fast Path) to create one phase.

### Step 5: Batch Phase Creation (Approved Decomposition)

After the user approves a decomposition, create all phases sequentially with proper numbering and dependency chains.

1. **Read the roadmap** for deterministic phase number extraction (same as Step 3, substep 2-3).

2. **Determine the starting phase number:** next available integer (same logic as Step 3).

3. **Analyze dependencies between the approved items:**
   - If items are logically independent: each depends only on the last existing phase before the batch
   - If items have a natural ordering where later items build on earlier ones: chain them sequentially so each depends on the previous
   - The dependency chain is derived from the semantic relationship between items

4. **For each approved item in order**, perform the creation steps:
   a. Compute the phase number: `starting_number + item_index` (0-based)
   b. Generate the slug from the item title
   c. Create the phase directory: `mkdir -p .planning/phases/{N}-{slug}`
   d. Add the phase entry to the ROADMAP.md Phases list (same mechanics as Step 3, substep 6)
   e. Add the phase detail section to ROADMAP.md (same mechanics as Step 3, substep 7)
      - For the first item: `**Depends on**: Phase {last_existing} (independent)`
      - For subsequent items with dependencies: `**Depends on**: Phase {previous_in_chain} (dependency chain from decomposition)`
      - For independent items: `**Depends on**: Phase {last_existing} (independent)`
   f. Update the Progress table (same mechanics as Step 3, substep 8)
   g. Update the Execution Order (same mechanics as Step 3, substep 9)
   h. Update STATE.md (same mechanics as Step 3, substep 10)

   **Important:** After each phase is added, re-read the relevant anchor positions for the next phase insertion, since the ROADMAP.md content has shifted.

5. **Report to user (batch creation summary):**
   ```
   Created {N} phases:

   Phase {X}: {Title 1}
     Directory: .planning/phases/{X}-{slug1}/

   Phase {X+1}: {Title 2}
     Directory: .planning/phases/{X+1}-{slug2}/

   ...

   Dependency chain: {X} -> {X+1} -> ... -> {X+N-1}

   Roadmap: Updated (Phases list, detail sections, Progress table, Execution Order)
   State: Updated (STATE.md "By Phase" table)

   Next: Define success criteria in ROADMAP.md, then /clear and /autopilot {X}
   ```

## Error Handling

- If ROADMAP.md does not exist: "No ROADMAP.md found at .planning/ROADMAP.md. Create a roadmap first."
- If a phase directory already exists during batch creation: Skip that phase and warn: "Directory .planning/phases/{N}-{slug}/ already exists -- skipping. Choose a different description or remove the existing directory."
- If no description provided after prompting: "A phase description is required."
- If the Progress table cannot be found: Log warning "Progress table not found in ROADMAP.md -- skipping progress table update." Continue with other updates.
- If the Execution Order line cannot be found: Log warning "Execution Order line not found in ROADMAP.md -- skipping execution order update." Continue with other updates.

</execution>

<success_criteria>
- [ ] Freeform input of any length accepted without truncation or loss
- [ ] Semantic analysis determines single vs. multi-phase using understanding, not keyword matching or length
- [ ] Single-phase inputs create one phase instantly via fast path with no decomposition overhead
- [ ] Multi-phase inputs present a numbered decomposition for user approval before creating anything
- [ ] User can approve, adjust (edit/merge/rename/remove items), or force single phase from decomposition
- [ ] Approved decomposition batch-creates all phases with proper sequential numbering
- [ ] Dependency chains between decomposed phases are set based on semantic analysis
- [ ] Each created phase has: directory, ROADMAP.md entry, detail section, Progress row, Execution Order entry, STATE.md row
- [ ] Phase number correctly determined using deterministic regex-based parsing
- [ ] No dependency on external tools or packages
</success_criteria>
