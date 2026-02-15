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
- **1 coherent unit of work detected:** Proceed to Step 2.5 (Generate Rich Phase Specification) then Step 3 (Single-Phase Fast Path)
- **2+ distinct items detected:** Proceed to Step 4 (Decomposition Presentation), then Step 2.5 for each approved item during Step 5

### Step 2.5: Generate Rich Phase Specification

For each phase being created (whether from the single-phase fast path or from batch creation), generate a detailed specification instead of stub placeholders. This step defines the methodology; Steps 3 and 5 reference it when constructing the ROADMAP.md detail section.

**Context gathering:** Before generating the specification, read the existing ROADMAP.md to understand:
- What phases already exist and what they accomplish
- What patterns, infrastructure, and capabilities the project has
- What the project's conventions are for Goal sections, success criteria format, and dependency notation
- Which phases are completed vs. pending, so you can reference existing capabilities accurately

**1. Generate the Goal Section (minimum 2-3 sentences):**

The Goal must describe WHAT needs to be done and WHY it matters in the context of the project. Use goal-backward framing: "When this phase completes, [observable outcome] will be true."

Rules:
- Minimum 2-3 sentences that fully describe the scope and purpose
- Use goal-backward framing to describe the end state, not just the action
- Reference existing codebase patterns, infrastructure, or conventions where relevant
- Do NOT simply restate the user's input as the Goal -- add context from your understanding of the roadmap, existing phases, and the project's architecture
- The Goal should be specific enough that someone reading it understands exactly what "done" looks like

Example of a good Goal (from an existing phase):
> Every new file created by the executor is verified as connected to the existing codebase -- orphaned files that compile but are never imported or rendered are caught immediately, not deferred to manual improvement passes

Example of a bad Goal (stub):
> [To be planned]

**2. Generate 3-5 Success Criteria (specific and testable):**

Each criterion describes a user/system-observable outcome, not an implementation task. Use the pattern: "[Observable outcome that must be true when this phase completes]".

Rules:
- Generate 3-5 criteria, each specific and testable
- Use the pattern: "[Observable outcome] -- [how to verify]" where possible
- Criteria describe outcomes (what is true after completion), not tasks (what to do)
- At least one criterion should be machine-verifiable (references a grep pattern, file existence check, or command output that could confirm the criterion)
- Reject vague criteria internally -- do not generate criteria like "should work correctly", "properly handles errors", or "is implemented correctly" without a concrete verification method
- Each criterion should be independently verifiable -- verifying one criterion should not require verifying another

Example of good criteria (from existing phases):
> 1. After the executor creates any new source file, it searches the codebase for imports/references to that file; if zero are found and the file is not a known standalone type, the executor treats the task as incomplete
> 2. When the executor detects an unwired file, it either adds the import/wiring to an appropriate parent file or explicitly documents why the file is standalone -- silent orphaning is not allowed

Example of bad criteria (stubs):
> 1. [To be defined during planning]

**3. Generate Dependency Analysis (with rationale):**

Analyze the existing roadmap phases to determine what the new phase depends on and WHY.

Rules:
- Read all existing phases in the roadmap to identify infrastructure the new phase needs
- For each dependency, explain WHY it exists in a parenthetical (e.g., "Phase 29 (reuses the one-question-at-a-time discuss infrastructure)")
- If the phase is truly independent, state "None (independent -- does not require infrastructure from other phases)" with a brief justification
- Do NOT default to "Phase {N-1} (independent)" -- actually analyze the technical relationship
- Dependencies should be based on technical need, not just sequential ordering

Example of a good dependency:
> Phase 2 (executor must have per-task commits and self-testing before integration checks layer on top)

Example of a bad dependency (stub):
> Phase {N-1} (independent)

**4. Generate Preliminary Task Breakdown:**

Create 2-5 high-level tasks that decompose the Goal into deliverables.

Rules:
- Each task is a verb-phrase describing a concrete deliverable (e.g., "Add compile gate to executor prompt", "Create verification command parser")
- Tasks should be ordered by natural execution sequence
- 2-5 tasks is the target range -- enough to decompose the goal, not so many as to micromanage
- Each task should be independently verifiable as a unit of work

**Quality Enforcement:**

- **Anti-parroting:** Do NOT simply restate the user's description as the Goal or criteria. Add context from your understanding of the roadmap, existing phases, and the project's patterns. The generated spec should demonstrate understanding of the request, not just echo it.
- **Vague criteria blocklist:** Never generate criteria containing only these phrases without a concrete verification method: "should work correctly", "properly handles", "is implemented correctly", "functions as expected", "works as intended". If you catch yourself writing a vague criterion, make it specific.
- **Downstream consumer awareness:** Generated specs must be rich enough that `autopilot {N}` (the phase-runner) can research the domain effectively, plan executable tasks, execute and verify without additional user input, and determine what "done" looks like without re-deriving the phase scope.
- **Quality reference:** Match the quality and format of well-specified phases in the existing roadmap. Look for phases with multi-sentence Goals, specific criteria, and dependency rationale as models.

**Post-Generation Quality Gate:**

After generating the specification and BEFORE writing it to ROADMAP.md, validate the output against these minimum requirements. If any check fails, regenerate the failing component with more explicit instructions.

Validation checks:
1. **Goal length check:** Count the sentences in the generated Goal. A sentence ends with a period, exclamation mark, or question mark followed by a space or end of text. The Goal must contain at least 2 complete sentences. If it contains fewer than 2 sentences, regenerate the Goal with the instruction: "The Goal must be at least 2-3 sentences. Expand to describe both WHAT needs to be done and WHY it matters, using goal-backward framing."
2. **Criteria count check:** Count the number of generated success criteria. There must be at least 3. If fewer than 3 criteria were generated, regenerate the criteria with the instruction: "Generate at least 3 success criteria. Each must describe a specific, testable, observable outcome."
3. **Criteria specificity check:** For each generated criterion, verify it does NOT consist solely of vague phrases from the blocklist ("should work correctly", "properly handles", "is implemented correctly", "functions as expected", "works as intended") without a concrete verification method. If any criterion fails this check, regenerate that criterion with the instruction: "This criterion is too vague. Rewrite it to describe a specific observable outcome with a verification method."
4. **Dependency rationale check:** Verify the "Depends on" field includes a WHY explanation -- it must contain a parenthetical rationale (text in parentheses explaining the reason) or the explicit phrase "independent" with a justification. A bare phase number without rationale (e.g., just "Phase 5" with no explanation) fails this check. If it fails, regenerate the dependency analysis with the instruction: "Explain WHY each dependency exists in a parenthetical, or state why the phase is independent."
5. **Anti-parroting check:** Compare the generated Goal text against the user's original input. If the Goal is more than 80% identical to the user's input (same words in the same order with only minor additions), regenerate with the instruction: "The Goal too closely mirrors the user's input. Add context from the roadmap, existing phase patterns, and project architecture to demonstrate understanding beyond what the user stated."

If regeneration is needed, apply it to the specific failing component only (do not regenerate components that passed). After regeneration, re-validate. If a component fails validation twice, proceed with the best version available and log a warning: "Quality gate: {component} did not fully pass after regeneration. Proceeding with best available version."

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

7. **Generate the rich specification using Step 2.5 methodology**, then **add the phase detail section to ROADMAP.md:**

   First, apply the spec generation methodology from Step 2.5 using the user's input description and the existing roadmap context. Generate: the Goal (2-3+ sentences), Success Criteria (3-5 specific items), Dependency Analysis (with rationale), and Preliminary Task Breakdown (2-5 tasks). Then run the Post-Generation Quality Gate from Step 2.5 to validate the output before writing. If any check fails, regenerate the failing component as described in the gate procedure.

   Then find the last `### Phase` detail section in the file. Locate the end of that section (the line before the next section starting with `## ` or `### Phase`, or the end of file). Add the new detail section there using Edit.

   New detail section format (using generated rich specification):
   ```markdown
   ### Phase {N}: {Title}
   **Goal**: {generated_goal -- minimum 2-3 sentences, goal-backward framing, not a stub}
   **Depends on**: {generated_dependency_analysis -- with WHY rationale, not "Phase N-1 (independent)"}
   **Requirements**: TBD (to be mapped during planning)
   **Success Criteria** (what must be TRUE):
     1. {generated_criterion_1 -- specific, testable, observable outcome}
     2. {generated_criterion_2}
     3. {generated_criterion_3}
     {additional criteria if 4-5 were generated}

   Plans:
   - [ ] {generated_task_1 -- verb-phrase deliverable}
   - [ ] {generated_task_2}
   - [ ] {generated_task_3}
   {additional tasks if generated}
   ```

   **Important:** Every field above uses the rich specification generated in Step 2.5. No field should contain placeholder text like "[To be planned]", "[To be defined]", or "TBD" (except Requirements which is mapped during the planning step, not at creation time).

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
    Roadmap: Updated (Phases list, detail section with rich specification, Progress table, Execution Order)
    State: Updated (STATE.md "By Phase" table)
    Status: Not started

    Goal: {first sentence of generated goal}
    Success Criteria: {count} criteria generated
    Dependencies: {generated dependency summary}

    Next: /clear then /autopilot {N} to execute
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
   e. **Generate a rich specification for this item using Step 2.5 methodology**, then run the Post-Generation Quality Gate to validate the output, then add the phase detail section to ROADMAP.md (same mechanics as Step 3, substep 7 -- which now uses the validated spec). The rich specification includes:
      - A detailed Goal (2-3+ sentences, goal-backward framing)
      - 3-5 specific, testable success criteria
      - Dependency analysis with rationale:
        - For the first item: analyze against existing roadmap phases (do NOT default to "Phase {last_existing} (independent)" -- determine the real technical dependency)
        - For subsequent items that build on earlier items in the batch: explain the chain relationship (e.g., "Phase {X} (builds on the parsing infrastructure established in Phase {X-1})")
        - For independent items: state "None (independent)" or reference the actual dependency with rationale
      - 2-5 preliminary tasks as verb-phrase deliverables
   f. Update the Progress table (same mechanics as Step 3, substep 8)
   g. Update the Execution Order (same mechanics as Step 3, substep 9)
   h. Update STATE.md (same mechanics as Step 3, substep 10)

   **Important:** After each phase is added, re-read the relevant anchor positions for the next phase insertion, since the ROADMAP.md content has shifted.

5. **Report to user (batch creation summary):**
   ```
   Created {N} phases (each with rich specification):

   Phase {X}: {Title 1}
     Directory: .planning/phases/{X}-{slug1}/
     Goal: {first sentence of generated goal}
     Criteria: {count} success criteria generated

   Phase {X+1}: {Title 2}
     Directory: .planning/phases/{X+1}-{slug2}/
     Goal: {first sentence of generated goal}
     Criteria: {count} success criteria generated

   ...

   Dependency chain: {X} -> {X+1} -> ... -> {X+N-1}

   Roadmap: Updated (Phases list, detail sections with rich specifications, Progress table, Execution Order)
   State: Updated (STATE.md "By Phase" table)

   Next: /clear then /autopilot {X} to execute
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
- [ ] Every created phase has a detailed Goal section (minimum 2-3 sentences) with goal-backward framing, not a stub placeholder
- [ ] Every created phase has 3-5 verifiable success criteria that are specific and testable, not "[To be defined]" stubs
- [ ] Every created phase has a dependency rationale explaining WHY dependencies exist, not just listing phase numbers
- [ ] Generated specifications use understanding of the request and roadmap context, not just parroting the user's input
- [ ] Generated specifications are rich enough for the phase-runner to execute without additional context gathering
- [ ] A post-generation quality gate validates specs before writing to ROADMAP.md -- Goal has >= 2 sentences, >= 3 criteria exist, criteria are specific (not vague), dependency includes WHY rationale, Goal is not a parrot of user input
</success_criteria>
