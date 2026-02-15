# Plan: Phase 32 -- Rich Phase Specification Generation

## Overview

Replace stub placeholders in the add-phase command with intelligent spec generation. The command will generate detailed Goal sections, machine-verifiable success criteria, dependency analysis with rationale, and preliminary task breakdowns for every created phase.

## Traceability

| Criterion | Task |
|-----------|------|
| Detailed Goal section (2-3 sentences) | 32-01 |
| At least 3 verifiable success criteria | 32-01 |
| Depends on analysis with WHY | 32-01 |
| Uses understanding, not parroting | 32-01, 32-02 |
| Matches quality of best existing phases | 32-01, 32-02 |

## Tasks

<task id="32-01" type="auto" complexity="complex">

### Task 32-01: Add Spec Generation Methodology and Replace Stub Template in Single-Phase Path

**Description:** Add a new "Step 2.5: Generate Rich Specification" section to add-phase.md that defines the spec generation methodology, and replace the stub template in Step 3 substep 7 with instructions that use the generated spec content.

**Files:**
- `src/commands/autopilot/add-phase.md` (modify)

**Action:**
1. Add a new section "Step 2.5: Generate Rich Phase Specification" between the current Step 2 (Semantic Analysis) and Step 3 (Single-Phase Fast Path). This section defines the spec generation methodology:
   - **Read the existing roadmap** for context: existing phase goals, patterns, infrastructure
   - **Generate the Goal section** (minimum 2-3 sentences):
     - Describe WHAT needs to be done and WHY it matters
     - Use goal-backward framing: "When this phase completes, [observable outcome] will be true"
     - Reference existing codebase patterns where relevant
     - Must go beyond parroting the user's input -- add context from roadmap understanding
   - **Generate 3-5 Success Criteria**:
     - Each criterion must be specific and testable
     - Use the pattern: "[Observable outcome] -- [how to verify]"
     - Criteria describe user/system-observable outcomes, not implementation tasks
     - At least one criterion should reference a machine-verifiable check (grep pattern, file existence, command output)
     - Reject vague criteria like "should work correctly" -- push for specificity
   - **Generate Dependency Analysis**:
     - Read all existing phases in the roadmap
     - Identify which phases provide infrastructure the new phase needs
     - Explain WHY each dependency exists with a parenthetical rationale
     - If truly independent, state "None (independent)" with brief justification
   - **Generate Preliminary Task Breakdown**:
     - 2-5 high-level tasks that decompose the goal
     - Each task is a verb-phrase describing a deliverable
     - Tasks ordered by natural execution sequence

2. Replace the stub template in Step 3 substep 7 (lines 122-133 of current add-phase.md) with a template that uses the generated spec:
   ```markdown
   ### Phase {N}: {Title}
   **Goal**: {generated_goal}
   **Depends on**: {generated_dependency_analysis}
   **Requirements**: TBD (to be mapped during planning)
   **Success Criteria** (what must be TRUE):
     1. {generated_criterion_1}
     2. {generated_criterion_2}
     3. {generated_criterion_3}
     {additional criteria if generated}

   Plans:
   - [ ] {generated_task_1}
   - [ ] {generated_task_2}
   - [ ] {generated_task_3}
   {additional tasks if generated}
   ```

3. Update the user report in Step 3 substep 11 to remove "Next: Define success criteria" since criteria are now auto-generated.

**Acceptance Criteria:**
- The add-phase.md contains a "Generate Rich Phase Specification" section with goal generation instructions -- verified by: `grep -c 'Generate Rich Phase Specification' src/commands/autopilot/add-phase.md` (expect >= 1)
- The Goal generation instructions require minimum 2-3 sentences and goal-backward framing -- verified by: `grep -c 'goal-backward\|2-3 sentences\|minimum.*sentences' src/commands/autopilot/add-phase.md` (expect >= 1)
- The Success Criteria instructions require 3-5 criteria with specific/testable pattern -- verified by: `grep -c '3-5 success criteria\|specific and testable\|Observable outcome.*how to verify' src/commands/autopilot/add-phase.md` (expect >= 1)
- The Dependency Analysis instructions require reading existing phases and explaining WHY -- verified by: `grep -c 'explain WHY\|WHY each dependency\|dependency.*rationale' src/commands/autopilot/add-phase.md` (expect >= 1)
- The stub template `[To be planned]` is replaced with `{generated_goal}` placeholder -- verified by: `grep -c '\[To be planned\]' src/commands/autopilot/add-phase.md` (expect 0)
- The stub criteria `[To be defined]` is replaced with generated criteria placeholders -- verified by: `grep -c '\[To be defined\]' src/commands/autopilot/add-phase.md` (expect 0)
- Task breakdown instructions specify 2-5 high-level tasks as verb-phrases -- verified by: `grep -c '2-5.*task\|verb-phrase\|preliminary task' src/commands/autopilot/add-phase.md` (expect >= 1)
- Test specification passes -- verified by: `bash .planning/phases/32-rich-phase-specification-generation/tests/task-32-01.sh 2>&1; echo EXIT:$?` (expect EXIT:0)

**Verify:** Run test specification and grep checks.
**Done:** When the add-phase.md has complete spec generation methodology and the single-phase path uses rich specs instead of stubs.

</task>

<task id="32-02" type="auto" complexity="medium">

### Task 32-02: Update Batch Creation Path and Quality Enforcement

**Description:** Update Step 5 (Batch Phase Creation) to use the same rich spec generation for each phase in the batch, and add quality enforcement instructions that prevent vague/parroted output.

**Files:**
- `src/commands/autopilot/add-phase.md` (modify)

**Action:**
1. Update Step 5 substep 4e to reference the spec generation methodology from the new Step 2.5 instead of using stubs. The batch path should call the same generation logic for each phase in the decomposed set.

2. Update the dependency generation in Step 5 substep 4e to use the rich analysis:
   - For the first item: analyze against existing roadmap phases (not just `Phase {last_existing} (independent)`)
   - For subsequent items with dependencies: explain the dependency relationship (e.g., "Phase {X} (builds on the parsing infrastructure from Phase {X-1})")
   - For independent items: state independence with justification

3. Add a "Quality Enforcement" subsection to the spec generation methodology that includes:
   - Anti-parroting rule: "Do NOT simply restate the user's description as the Goal. Add context from your understanding of the roadmap, existing phases, and the project's patterns."
   - Vague criteria blocklist: reject criteria containing "should work correctly", "properly handles", "is implemented correctly" without a verification method
   - Downstream consumer awareness: "Generated specs should be rich enough that `autopilot {N}` (the phase-runner) can research, plan, execute, and verify the phase without additional context"
   - Quality reference: "Match the quality and format of well-specified phases in the existing roadmap (look for phases with multi-sentence Goals, specific criteria, and dependency rationale)"

4. Update the batch creation user report (Step 5 substep 5) to remove "Next: Define success criteria" guidance.

5. Update the success_criteria section at the bottom of the file to add criteria about rich spec generation.

**Acceptance Criteria:**
- The batch creation path references the spec generation methodology -- verified by: `grep -c 'spec generation\|Generate Rich Phase Specification\|generated_goal\|rich specification' src/commands/autopilot/add-phase.md` (expect >= 3)
- Quality enforcement section exists with anti-parroting rule -- verified by: `grep -c 'anti-parroting\|NOT simply restate\|Do NOT.*restate\|parroting' src/commands/autopilot/add-phase.md` (expect >= 1)
- Vague criteria blocklist exists -- verified by: `grep -c 'should work correctly\|vague criteria\|blocklist\|properly handles' src/commands/autopilot/add-phase.md` (expect >= 1)
- Downstream consumer awareness instruction exists -- verified by: `grep -c 'downstream consumer\|phase-runner.*can.*research.*plan.*execute\|rich enough.*autopilot' src/commands/autopilot/add-phase.md` (expect >= 1)
- Success criteria section updated with rich spec criteria -- verified by: `grep -c 'rich.*spec\|detailed Goal\|verifiable success criteria\|dependency.*rationale' src/commands/autopilot/add-phase.md` (expect >= 2)
- No remaining "Define success criteria" guidance in user reports -- verified by: `grep -c 'Define success criteria in ROADMAP' src/commands/autopilot/add-phase.md` (expect 0)
- Test specification passes -- verified by: `bash .planning/phases/32-rich-phase-specification-generation/tests/task-32-02.sh 2>&1; echo EXIT:$?` (expect EXIT:0)

**Verify:** Run test specification and grep checks.
**Done:** When batch creation uses rich specs and quality enforcement prevents vague/parroted output.

</task>
