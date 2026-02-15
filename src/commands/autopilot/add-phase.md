---
name: autopilot:add-phase
description: Add new phases to the roadmap -- accepts freeform input of any complexity and auto-decomposes into multiple phases when appropriate. Use --deep for conversational context gathering before creation.
argument-hint: <freeform description> [--deep]
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

### Step 1.5: Codebase and Roadmap Awareness Scan

Before any phase creation, scan the existing roadmap and codebase to detect overlaps, understand available infrastructure, and inform dependency positioning. This step prevents duplicate phases and ensures new phases are positioned correctly relative to existing work.

**1. Read the existing roadmap and build a phase inventory:**

Read `.planning/ROADMAP.md` and extract ALL existing phases into an inventory:
- For each phase: extract the phase number, title, goal text, success criteria, completion status (marked with `[x]` = completed, `[ ]` = pending), and dependency chain
- Build two lists:
  - **Completed phases inventory:** Phases marked with `[x]` -- these represent available infrastructure and capabilities that new phases can build on
  - **Pending phases inventory:** Phases marked with `[ ]` -- these represent planned but unexecuted work

**2. Build an infrastructure inventory from completed phases:**

For completed phases, build an infrastructure inventory describing what capabilities, patterns, and systems are already available in the codebase:
- Read each completed phase's goal and success criteria to understand what was delivered
- If `.autopilot/repo-map.json` exists, use it to identify relevant existing implementations (functions, modules, patterns)
- Summarize available infrastructure as a list of capabilities (e.g., "one-question-at-a-time interactive flow (Phase 29)", "structured test specifications (Phase 18)", "per-task verification loop (Phase 20)")
- This inventory is used in Step 2.5 to generate accurate dependency analysis and reference existing capabilities in new phase specs

**3. Overlap detection -- semantic comparison against existing phases:**

For the proposed phase description (or each item in a multi-item decomposition), perform a semantic overlap comparison against every existing phase in the inventory:

- Compare the proposed phase's intent, scope, and deliverables against each existing phase's title, goal, and success criteria
- Use semantic understanding for comparison, not just string matching -- two phases can overlap even with different wording if they accomplish the same outcome
- Overlap threshold: If the proposed phase would produce >70% of the same deliverables as an existing phase (based on semantic analysis of goals and criteria), flag it as an overlap

**If overlap is detected, present a warning:**

```
Warning: This looks similar to existing Phase {N}: "{Phase Title}"

Overlap: {1-2 sentence explanation of what overlaps}

Options:
1. Create anyway (it's different enough)
2. Extend Phase {N} instead (use /autopilot:insert-phase {N}.X "{description}")
3. Cancel
```

**Handle the user's response:**
- **"Create anyway" or option 1:** Proceed with phase creation. The overlap was acknowledged.
- **"Extend" or option 2:** Instruct the user to run `/autopilot:insert-phase {N} "{description}"` to add a decimal sub-phase under the overlapping phase instead of creating a new top-level phase. Stop execution of add-phase.
- **"Cancel" or option 3:** Stop execution. No phase created.

**4. For multi-phase decompositions:**

When Step 2 detects multiple items and Step 4 presents a decomposition, the overlap check from substep 3 above runs per-item BEFORE batch creation in Step 5. Each item is individually checked against the existing phase inventory. Items with overlap are flagged individually, and the user can choose to create, extend, or skip each overlapping item independently.

**5. Pass context to subsequent steps:**

After the scan, pass the following context to Step 2 and Step 2.5:
- The completed phases inventory (for infrastructure awareness in spec generation)
- The pending phases inventory (for dependency warnings)
- Any overlap decisions (acknowledged overlaps noted in the spec)
- Deep context answers (if `--deep` was used -- from Step 1.8)

### Step 1.8: Deep Context Gathering (`--deep` flag)

**Skip condition:** If `--deep` is NOT present in the user's invocation arguments, skip Step 1.8 entirely. Proceed directly from Step 1.5 to Step 2. All existing behavior from phases 31-33 remains unchanged without this flag.

**Purpose:** When `--deep` is specified, conduct a one-question-at-a-time conversational flow that gathers targeted context about the phase before specification generation. This produces measurably richer specifications by incorporating explicit user decisions about scope, preferences, edge cases, and thresholds -- rather than relying solely on inference from the freeform input.

**1. Analyze the input to identify question-worthy areas:**

Read the user's freeform description and identify areas where targeted questions would produce better specifications. Focus on five question categories:

- **Scope Boundaries** -- What is explicitly in scope vs. out of scope? Should this replace existing behavior or be additive? What are the boundaries of this change?
- **Implementation Preferences** -- Should this be strict (error on edge cases) or flexible (graceful degradation)? What existing codebase patterns should it follow or extend? What trade-offs does the user prefer (speed vs. thoroughness, simplicity vs. flexibility)?
- **Edge Cases & Failure Modes** -- What should happen when unexpected input is received? What is the expected failure mode for the most likely error scenarios? How should errors be reported?
- **Acceptance Thresholds** -- What level of verification is needed? Should success criteria be machine-verifiable or human-checked? What "done" looks like at the detail level?
- **Integration Points** -- What existing features does this interact with? Should this be opt-in (flag-gated) or default behavior? What are the downstream consumers of this work?

For each category, generate 1-3 questions that are SPECIFIC to the user's phase description. Do NOT use generic templates -- every question must reference concrete elements from the input.

**2. Present questions one at a time using the discuss pattern:**

Present each question individually, waiting for the user's response before presenting the next:

```
Deep context: Question {N}/{total}
Topic: {category name}

{question text -- must reference specific elements from the user's input}

Options:
a) {concrete choice 1 -- a real implementation approach, not "Option A"}
b) {concrete choice 2 -- a different real approach}
c) {concrete choice 3 -- another distinct approach, if applicable}
d) You decide (Claude's discretion)

(Enter a letter, or type a custom answer)
```

**Question quality rules:**
- Questions MUST reference specific elements from the user's phase description -- not generic "tell me more" prompts
- Questions MUST NOT be generic. Bad: "How should errors be handled?" Good: "When the --deep flag receives an empty response to a question, should it (a) skip that question and move on, (b) re-ask with a simpler version, or (c) end the deep context flow?"
- Each option must be concrete and distinct -- options should represent genuinely different implementation approaches, not variations of the same answer
- The "You decide (Claude's discretion)" option is always the last option, providing a graceful escape for questions the user does not want to answer

**3. Adaptive follow-up generation:**

After each answer, generate the next question by analyzing ALL answers given so far. The follow-up question must:
- Address something not yet covered by previous questions
- Be specific to the phase description (not generic)
- Adapt based on the user's previous answers -- if the user chose "strict mode" in a previous answer, subsequent questions should explore strict-mode implications rather than asking about flexible approaches

Example adaptive logic:
- If user answers "replace existing behavior" for scope -> follow up with "What should happen for users or workflows relying on the current behavior?"
- If user answers "strict mode" for implementation -> follow up with "Should strict-mode violations produce warnings or hard errors?"
- If user answers "flexible/graceful degradation" -> follow up with "Should degraded behavior be logged/visible, or silent?"
- If user answers "machine-verifiable" for thresholds -> follow up with "What grep patterns or command outputs would confirm success?"

**4. Depth control:**

After every 4 questions, offer the user depth control:

```
4 questions answered. Continue with more questions about your phase, or move on to creation?

a) More questions (2-3 additional targeted questions)
b) Move on to phase creation with context gathered so far
```

If "more questions": generate 2-3 additional context-aware follow-up questions derived from the answers given so far. These follow-ups should drill deeper into the most complex or ambiguous areas identified by the prior answers.

If "move on": end the deep context gathering and proceed to Step 2.

**5. Compile gathered context:**

After the conversational flow completes (either by exhausting questions or user choosing to move on), compile all answers into a structured `deep_context` object:

```
deep_context:
  scope_decisions:
    - question: "{question text}"
      answer: "{user's answer or selected option}"
  preference_decisions:
    - question: "{question text}"
      answer: "{user's answer}"
  edge_case_decisions:
    - question: "{question text}"
      answer: "{user's answer}"
  threshold_decisions:
    - question: "{question text}"
      answer: "{user's answer}"
  integration_decisions:
    - question: "{question text}"
      answer: "{user's answer}"
  total_questions_asked: N
  total_questions_answered: N
```

Pass this `deep_context` to Step 2 and Step 2.5. It is consumed during specification generation to produce richer output.

**Error handling for --deep:**
- If the user provides an empty response or says "skip" to a question: record the question as unanswered, proceed to the next question. Do not re-ask.
- If the user cancels the deep context flow entirely (e.g., "cancel", "stop", "done"): proceed with whatever context has been gathered so far. Even partial deep context improves spec quality.
- If no answers are gathered at all (user skips or cancels immediately): proceed as if `--deep` was not specified. The baseline spec generation from phases 31-33 handles this gracefully.

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

**Context gathering:** Use the infrastructure inventory built in Step 1.5, supplemented by reading the existing ROADMAP.md:
- **From Step 1.5's completed phases inventory:** What infrastructure, capabilities, and patterns are already available from completed phases (marked with `[x]` in the roadmap). Use this to reference existing capabilities in the new phase's spec and to identify accurate technical dependencies.
- **From Step 1.5's pending phases inventory:** What planned work exists that the new phase might depend on or conflict with. Warn if the new phase depends on a pending (not yet completed) phase.
- What the project's conventions are for Goal sections, success criteria format, and dependency notation
- If `.autopilot/repo-map.json` exists, use it to identify relevant existing implementations (functions, modules, files) that the new phase can build on or must integrate with

**1. Generate the Goal Section (minimum 2-3 sentences):**

The Goal must describe WHAT needs to be done and WHY it matters in the context of the project. Use goal-backward framing: "When this phase completes, [observable outcome] will be true."

Rules:
- Minimum 2-3 sentences that fully describe the scope and purpose
- Use goal-backward framing to describe the end state, not just the action
- Reference existing codebase patterns, infrastructure, or conventions where relevant -- use the infrastructure inventory from Step 1.5 to identify what the new phase can leverage (e.g., "This phase builds on the one-question-at-a-time pattern established in Phase 29" or "This leverages the existing per-task verification infrastructure from Phase 20")
- Do NOT simply restate the user's input as the Goal -- add context from your understanding of the roadmap, existing phases, and the project's architecture. The infrastructure inventory provides concrete details about what already exists.
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
- Use the infrastructure inventory from Step 1.5 to identify what completed phases provide capabilities the new phase technically requires. Match the new phase's needs (infrastructure, APIs, patterns, files it would modify or depend on) against the deliverables cataloged in the inventory.
- For each dependency, explain WHY it exists in a parenthetical (e.g., "Phase 29 (reuses the one-question-at-a-time discuss infrastructure)")
- If the phase is truly independent, state "None (independent -- does not require infrastructure from other phases)" with a brief justification
- Do NOT default to "Phase {N-1} (independent)" -- actually analyze the technical relationship using the infrastructure inventory
- Dependencies should be based on actual technical need, not just sequential ordering -- a phase depends on another only if it requires infrastructure, patterns, or deliverables from that phase
- If the new phase depends on a pending phase (one not yet marked as completed with `[x]`), add a warning note: "Note: This depends on Phase {N} which has not been completed yet -- execute Phase {N} first"

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

9. **Update the Execution Order in ROADMAP.md (dependency-aware positioning):**

   Find the execution order line that lists the most recent phases. This matches the pattern `^Phases \d+\+: ` followed by a ` -> ` separated list of phase numbers.

   **Dependency-aware positioning logic:**
   - If the new phase has dependencies (from the generated dependency analysis in Step 2.5), find the LAST dependency's position in the execution order chain
   - Position the new phase AFTER its last dependency in the chain, not necessarily at the very end
   - If the last dependency is not the final phase in the chain and there are independent phases after it, insert after the last dependency by splitting the chain at that point
   - If the new phase has no dependencies or its dependencies are all at or near the end of the chain, append ` -> {N}` to the end (standard behavior)
   - If the execution order line does not exist, add one: `Phases {N}+: {N}`

   **Pending dependency warning:**
   - If the generated dependency analysis references a phase that is not yet completed (not marked with `[x]` in the roadmap), emit a note in the user report: "Note: Phase {N} depends on Phase {dep} which has not been completed yet. Execute Phase {dep} first."

   Use Edit to update the execution order line.

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
   g. Update the Execution Order using dependency-aware positioning (same mechanics as Step 3, substep 9 -- position after last dependency in the chain, not just append to end)
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
- [ ] Before creating any phase, duplicate/overlap detection scans existing roadmap phases and warns when a proposed phase overlaps >70% with an existing one
- [ ] When overlap is detected, user is offered options: create anyway, extend existing phase via /autopilot:insert-phase, or cancel
- [ ] An infrastructure inventory of completed phases is built and used to reference existing capabilities in new phase specifications
- [ ] Dependencies are set based on actual technical analysis of what infrastructure the new phase requires, not sequential numbering
- [ ] Execution order positioning places new phases after their last technical dependency, not just appended to the end
- [ ] If a new phase depends on a pending (not yet completed) phase, a warning is emitted
</success_criteria>
