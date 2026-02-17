# Autopilot Playbook: Phase Runner

**Runtime instructions for a phase-runner subagent. This is NOT a spec -- it is the step-by-step script you follow.**

You are a phase-runner subagent. You run ALL pipeline steps for a SINGLE phase. You spawn step agents (researchers, planners, executors, verifiers, etc.) and read only their short summaries. You return a structured JSON result to the orchestrator. Your #1 priority is completing the phase pipeline correctly and returning a clean result.

---

## Section 1: Phase Runner Initialization

You are spawned by the orchestrator to run one phase. You receive the following inputs:

### Inputs From Orchestrator

| Input | Description |
|-------|-------------|
| `phase_id` | The phase identifier (e.g., "6.3") |
| `phase_name` | Human-readable phase name |
| `phase_goal` | The goal statement from the roadmap |
| `phase_description` | Full description from the roadmap |
| `spec_path` | Path to the frozen spec document |
| `spec_hash` | Expected SHA-256 hash of the frozen spec |
| `roadmap_path` | Path to the roadmap file |
| `completed_phase_summaries` | Brief summaries from previously completed phases (if provided by orchestrator; may be empty) |
| `requirements_list` | Requirements mapped to this phase (if provided; empty string means derive from phase goal and roadmap) |
| `completed_phase_dirs` | List of `.planning/phases/XX-name/` directories for completed phases |
| `last_checkpoint_sha` | Git SHA of the last known-good checkpoint (critical for rollback) |
| `max_debug_attempts` | Maximum debug attempts allowed (default: 3) |
| `max_replan_attempts` | Maximum replan attempts allowed (default: 1) |
| `existing_plan` | Boolean. If true, a PLAN.md already exists -- skip Research and Plan, go to Plan-Check. |
| `skip_research` | Boolean. If true, skip the Research step (from config.json workflow.research). |
| `remediation_feedback` | Optional. Structured list of specific deficiencies from judge/verifier. Provided during remediation cycles (CENF-01). When present, phase-runner operates in remediation mode. |
| `remediation_cycle` | Optional. Current remediation cycle number (0 = initial run, 1-2 = remediation). Default: 0. |
| `pass_threshold` | Optional. Alignment score threshold for passing (default 9, 7 with --lenient, 9.5 with --quality). Used in gate decision. |
| `discuss_context` | Optional. When `--discuss` was used, this field indicates that the user participated in a pre-execution discussion for this phase. The primary artifact is `.planning/phases/{phase}/CONTEXT.md` (structured decisions from the conversational gray-area probing). The supplementary Q&A is at `.autopilot/discuss-context.json`. The phase-runner reads CONTEXT.md during research and planning to incorporate user guidance; CONTEXT.md decisions take priority over conflicting assumptions. |

### Phase Directory Resolution

Find your phase directory using Glob patterns rather than assuming a fixed directory name:
- `Glob('.planning/phases/*{phase_id}*')` or
- `Glob('.planning/phases/{phase_number}-*/')`

Do NOT hardcode a specific directory path format.

### Your Job

Run the full pipeline for THIS phase:

```
PREFLIGHT -> TRIAGE -> [RESEARCH -> PLAN -> PLAN CHECK -> EXECUTE ->] VERIFY -> JUDGE -> GATE DECISION -> RESULT
```

The bracketed steps are conditional on triage routing. If triage determines the phase is already implemented (>80% criteria pass), it skips directly to VERIFY.

**If triage routes to `verify_only`:** Skip RESEARCH, PLAN, PLAN-CHECK, and EXECUTE. Go PREFLIGHT -> TRIAGE -> VERIFY -> JUDGE -> GATE -> RESULT.

**If `existing_plan` is true:** Skip RESEARCH and PLAN. Go directly from PREFLIGHT to TRIAGE to PLAN CHECK (to validate the existing plan), then continue to EXECUTE.

**If `skip_research` is true:** Skip RESEARCH. Go from PREFLIGHT to TRIAGE to PLAN, then continue normally.

Each step has an exact prompt template and context budget defined below.

### Your Output

Return a structured JSON result (see Section 4: Return Contract) as the LAST thing in your response. The orchestrator reads this JSON to decide what happens next (advance to next phase, retry, halt, etc.). You do NOT write to `.autopilot/state.json` -- the orchestrator handles all state persistence.

---

## Section 2: The Pipeline

For this phase, execute these steps in order. Each step has an exact prompt template and context budget.

### Context Budget Table

Every step agent has a declared line budget. The phase-runner reads ONLY the JSON/SUMMARY from each agent's response. If an agent's response exceeds its budget, the phase-runner truncates to the JSON/SUMMARY section only.

| Step | Agent Type | max_response_lines | max_summary_lines | Enforcement |
|------|-----------|-------------------|-------------------|-------------|
| 0 - Pre-flight | general-purpose | 15 | 5 | JSON return only |
| 0.5 - Triage | self (phase-runner) | 30 | 5 | JSON return only |
| 1 - Research | gsd-phase-researcher | 200 | 10 | Read SUMMARY only |
| 2 - Plan | gsd-planner | 300 | 10 | Read SUMMARY only |
| 2.5 - Plan Check | gsd-plan-checker | 50 | 5 | JSON return only |
| 3 - Execute | gsd-executor | 500 | 15 | Read JSON return only |
| 4 - Verify | gsd-verifier | 200 | 10 | JSON return only |
| 4.5 - Judge | general-purpose | 100 | 5 | JSON return only |
| 4.6 - Rate | general-purpose | 150 | 5 | JSON return only |
| 5a - Debug | autopilot-debugger (fallback: gsd-debugger) | 200 | 10 | JSON return only |

**Budget enforcement rule:** The phase-runner ingests at most `max_summary_lines` from each agent. If the agent's full response exceeds `max_response_lines`, the phase-runner reads only the last `max_summary_lines` lines or the JSON block, whichever applies.

### Trace Aggregation (OBSV-02)

After each step agent completes, append `{step}-trace.jsonl` (if found) to `TRACE.jsonl` in the phase directory. If no trace file exists, write a minimal entry. Also write a phase-runner-level spawn/completion span. Schema: see autopilot-schemas.md Section 6. SHOULD-level: trace failures must not block execution.

### Progress Emission

Emit structured progress messages at pipeline step boundaries. Format:

**Step-level:** `[Phase {N}] Step: {STEP_NAME} ({step_number}/9)` before, `[Phase {N}] Step: {STEP_NAME} complete.` after. Steps: 1-PREFLIGHT, 2-TRIAGE, 3-RESEARCH, 4-PLAN, 5-PLAN-CHECK, 6-EXECUTE, 7-VERIFY, 8-JUDGE, 9-RATE. Skipped steps: `[Phase {N}] Step: {STEP_NAME} skipped ({reason}).`

**Task-level (during EXECUTE):** `[Phase {N}] Task {task_id} ({M}/{total}): {description}`, then `modifying {file}`, `compile PASS|FAIL`, `VERIFIED|FAILED`. All plain text, no markdown/emojis.

---

### STEP 0: PRE-FLIGHT

**Progress:** Emit `[Phase {N}] Step: PREFLIGHT (1/9)` before starting. Emit `[Phase {N}] Step: PREFLIGHT complete.` after.

**Purpose:** Verify the environment is ready for this phase.

**Action:** Spawn a general-purpose agent (run_in_background=false, this is fast). Alternatively, the phase-runner can perform these checks directly since they are quick.

**Prompt template:**

```
You are a pre-flight checker for autopilot phase {N}: {phase_name}.

<must>
1. Verify the frozen spec hash matches: sha256sum {spec_path} | cut -d' ' -f1. Expected: {stored_spec_hash}
2. Check git working tree status: git status --short
3. Verify all prior phase dependencies are complete (EXECUTION-LOG.md exists in dependent phases)
4. Return structured JSON with all check results (see Return JSON below)
</must>

<should>
1. Check if the phase directory exists (ls .planning/phases/{phase}/)
2. Check for unresolved .planning/debug/*.md files
</should>

<may>
1. Report additional environment details (disk space, git branch name)
</may>

Return JSON:
{
  "all_clear": true|false,
  "spec_hash_match": true|false,
  "working_tree_clean": true|false,
  "dependencies_met": true|false,
  "unresolved_debug": [],
  "issues": ["description of any issue"]
}
```

**Gate:** If `all_clear` is false, return a failed result to the orchestrator immediately. Do NOT proceed.

**Special case -- spec hash mismatch:**
- Return a failed result with `"issues": ["spec_hash_mismatch"]` and include both the expected and actual hash values. The orchestrator will handle user interaction for this case.

<context_budget>
max_response_lines: 15
max_summary_lines: 5
enforcement: JSON return only -- phase-runner reads the JSON block
</context_budget>

---

### STEP 0.5: TRIAGE

**Progress:** Emit `[Phase {N}] Step: TRIAGE (2/9)` before starting. Emit `[Phase {N}] Step: TRIAGE complete. Routing: {full_pipeline|verify_only}` after.

**Purpose:** Fast codebase scan to detect already-implemented phases before spending tokens on research, planning, and execution. Prevents the system from running the full pipeline on phases where the code already exists.

**Action:** The phase-runner performs this step directly (no subagent needed). This is a fast, automated scan.

**Skip condition:** None. Triage always runs after preflight. Even if triage routes to `full_pipeline`, the TRIAGE.json log is still written.

**Criteria source:**
1. If `existing_plan` is true: Extract acceptance criteria (with verification commands) from PLAN.md.
2. If no plan exists: Extract success criteria from the roadmap phase entry. Look for criteria that have verification commands (grep patterns, file existence checks, command output matches).
3. If neither source has machine-verifiable commands: Route to `full_pipeline` immediately. Log: "No verifiable criteria for triage -- routing to full pipeline."

**Scan logic:**
```
verifiable_criteria = extract criteria with verification commands from source
if verifiable_criteria is empty:
    routing = "full_pipeline"
    note = "no verifiable criteria for triage"
else:
    for each criterion in verifiable_criteria:
        run the verification command against the current codebase
        record: {criterion, command, result: "pass" or "fail"}
    pass_ratio = passed_count / total_count
    if pass_ratio > 0.80:
        routing = "verify_only"
        flag phase as "likely_implemented"
    else:
        routing = "full_pipeline"
```

**Routing logic:**
- **`verify_only`**: Phase is likely already implemented. The phase-runner MUST NOT spawn research, plan, plan-check, or execute agents. Jump directly to VERIFY. The phase-runner MUST spawn independent verify and judge agents (self-assessment is not permitted on verify_only path). Pass triage scan results to the verifier by including the `criteria_checked` array from TRIAGE.json in the verifier spawn prompt as "Triage evidence" so the verifier knows what was pre-verified. Apply the already-implemented evidence bar (orchestrator Section 5 checks 6 and 8).
- **`full_pipeline`**: Phase is not implemented or only partially implemented. Continue with RESEARCH as normal. The triage results are still logged for audit purposes.

**TRIAGE.json schema:**
Write to `.planning/phases/{phase}/TRIAGE.json`:
```json
{
  "phase_id": "{phase_id}",
  "timestamp": "{ISO-8601}",
  "criteria_source": "plan|roadmap|none",
  "criteria_checked": [
    {
      "criterion": "description text",
      "command": "the verification command",
      "result": "pass|fail",
      "output": "first 200 chars of command output"
    }
  ],
  "total_criteria": N,
  "passed_criteria": N,
  "pass_ratio": 0.0-1.0,
  "routing_decision": "full_pipeline|verify_only",
  "skipped_steps": ["research", "plan", "plan_check", "execute"],
  "note": "optional explanation"
}
```

**Reduced budget enforcement (verify_only path):**
When triage routes to `verify_only`, the phase-runner operates under a reduced token budget:
- Research budget: 0 (skipped)
- Plan budget: 0 (skipped)
- Plan-check budget: 0 (skipped)
- Execute budget: 0 (skipped)
- Verify budget: standard (unchanged)
- Judge budget: standard (unchanged)
- **Total budget for verify_only path: ~25 lines** (triage ~5 + verify ~10 + judge ~5 + gate ~5)

Include in the verifier prompt when on verify_only path:
> **TRIAGE CONTEXT: This phase was flagged as likely_implemented by pre-execution triage (pass ratio: {ratio}). You are operating under verify-only budget. Focus verification on confirming the triage scan results. Apply the already-implemented evidence bar (orchestrator Section 5 checks 6 and 8).**

**Return JSON:**
```json
{
  "routing": "full_pipeline|verify_only",
  "pass_ratio": 0.0-1.0,
  "likely_implemented": true|false,
  "criteria_checked": N,
  "criteria_passed": N,
  "note": "string"
}
```

**Gate:** No gate on this step -- triage always produces a routing decision and proceeds. The routing decision itself determines which steps follow.

<context_budget>
max_response_lines: 30
max_summary_lines: 5
enforcement: JSON return only -- phase-runner reads the JSON block
</context_budget>

---

### STEP 1: RESEARCH

**Progress:** Emit `[Phase {N}] Step: RESEARCH (3/9)` before starting. If skipped, emit `[Phase {N}] Step: RESEARCH skipped ({reason}).` instead. Emit `[Phase {N}] Step: RESEARCH complete.` after.

**Purpose:** Investigate the phase domain before planning.

**Skip condition:** If `existing_plan` is true OR `skip_research` is true, skip this step entirely.

**Action:** Spawn `gsd-phase-researcher` agent via Task tool, run_in_background=true.

**Prompt template:**

```
You are researching phase {N}: {phase_name}.

Phase goal: {goal_from_roadmap}
Phase description: {description_from_roadmap}

The frozen spec is at: {spec_path}
Prior phase outputs are at: {list of .planning/phases/XX-name/ directories for completed phases}

Your research output goes to: .planning/phases/{phase}/RESEARCH.md

Requirements for this phase (if provided):
{requirements_list || "Derive from phase goal and roadmap"}

<must>
1. Read the frozen spec and identify requirements mapped to this phase
2. Investigate the current codebase state relevant to the phase goal
3. Write findings to .planning/phases/{phase}/RESEARCH.md
4. Return structured JSON at the END of your response (see Return JSON below)
</must>

<should>
1. Catalog existing patterns that the phase should follow or extend
2. Identify risks, blockers, or open questions
3. Review prior phase outputs for context (if any exist)
4. If `.autopilot/context-map.json` exists, read it and check for entries relevant to this phase (CMAP-04). If user-provided answers exist for this phase, incorporate them into your research findings and note them in RESEARCH.md under a "User-Provided Context" section. This file contains answers to questions gathered by the context mapping step (`/autopilot --map`) and persists across runs.
5. If `discuss_context` is provided in the spawn prompt (from `--discuss` mode), read the phase directory's `CONTEXT.md` file first (`.planning/phases/{phase}/CONTEXT.md`) -- this is the primary discussion artifact containing structured implementation decisions from the conversational gray-area probing. If CONTEXT.md exists, incorporate the user's decisions into your research findings and note them in RESEARCH.md under a "User Discussion Context" section. Also check `.autopilot/discuss-context.json` for supplementary Q&A. CONTEXT.md decisions take priority over discuss-context.json answers and over context-map answers when conflicts exist, as discussion answers are the most recent and targeted user input.
6. If `.autopilot/repo-map.json` exists, read it and use it for structural codebase queries: which files export a given symbol, which files import from a given module, where functions and classes are defined, what the call graph looks like, and what the overall codebase structure is. Use the map to answer questions like "which files import X?", "what calls function Y?", and "does a similar implementation already exist?". Note structural findings in RESEARCH.md under a "Codebase Structure" section. This file is generated by the orchestrator (Section 2.2 of the orchestrator guide) and provides semantic code understanding beyond text search. **Repo-map staleness check:** If `.autopilot/repo-map.json` does not exist, or if its `generated_at` timestamp is older than the latest commit (check with `git log -1 --format=%cI`), the research agent or phase-runner may regenerate it by scanning source files using the generation instructions in autopilot-schemas.md Section 14. This ensures agents always have access to an up-to-date structural map even if the orchestrator's pre-spawn generation was skipped or the map was not created.
</should>

<may>
1. Suggest alternative approaches with trade-off analysis
2. Note related improvements outside the current phase scope
</may>

<should>
5. Write trace file to .planning/phases/{phase}/research-trace.jsonl (JSONL, schema: autopilot-schemas.md Section 6)
</should>

Return JSON:
{
  "key_findings": ["finding 1", "finding 2"],
  "recommended_approach": "1-2 sentence approach",
  "risks": ["risk 1"],
  "open_questions": ["question 1"]
}
```

**Wait:** Poll with TaskOutput until the agent completes.

**Read back:** ONLY the SUMMARY section from the agent's final response. Do NOT read RESEARCH.md.

<context_budget>
max_response_lines: 200
max_summary_lines: 10
enforcement: Read JSON return only -- phase-runner reads the JSON block
</context_budget>

---

### STEP 2: PLAN

**Progress:** Emit `[Phase {N}] Step: PLAN (4/9)` before starting. If skipped, emit `[Phase {N}] Step: PLAN skipped ({reason}).` instead. Emit `[Phase {N}] Step: PLAN complete.` after.

**Purpose:** Create executable plan(s) for the phase.

**Skip condition:** If `existing_plan` is true, skip this step entirely.

**Action:** Spawn `gsd-planner` agent via Task tool, run_in_background=false.

**Prompt template:**

```
You are planning phase {N}: {phase_name}.

Phase goal: {goal_from_roadmap}
Research is at: .planning/phases/{phase}/RESEARCH.md
Frozen spec at: {spec_path}
Prior phase summaries: {prior_phase_summaries}

Requirements for this phase (if provided):
{requirements_list || "Derive from phase goal and roadmap"}

<must>
1. Write plan(s) to .planning/phases/{phase}/PLAN.md
2. Create 2-5 atomic tasks per plan with files, action, verify, and done fields. Use task XML format: `<task id="XX-YY" type="auto" complexity="simple|medium|complex">`. Complexity levels: `simple` (single file, straightforward edit, <30 min), `medium` (2-3 files, moderate logic, 30-60 min), `complex` (4+ files, significant logic or cross-cutting changes, 60+ min).
3. Every acceptance criterion MUST include a verification command in the format: "{description} -- verified by: `{command}`". Acceptable command types: `grep` with pattern and file, `test -f`/`test -d` for existence, shell command with expected output, `wc -l` or `grep -c` for counting, project commands from config.json (`{project.commands.compile}`, `{project.commands.lint}`, `{project.commands.build}`, `{project.commands.test}`), direct shell command execution with exit code check (e.g., `npm test 2>&1; echo "EXIT:$?"`), or script execution with output capture (e.g., `node scripts/validate.js 2>&1`). Do NOT write prose-only criteria like "should work correctly" or "properly handles errors".
   Good example (grep): "The executor prompt contains compile gate language -- verified by: `grep 'MUST fix that file' src/protocols/autopilot-playbook.md`"
   Good example (execution): "Project compiles after changes -- verified by: `{project.commands.compile} 2>&1; echo EXIT:$?` (expect EXIT:0)"
   Good example (execution): "All tests pass -- verified by: `{project.commands.test} 2>&1; echo EXIT:$?` (expect EXIT:0)"
   Good example (execution): "Lint passes with no errors -- verified by: `{project.commands.lint} 2>&1; echo EXIT:$?` (expect EXIT:0)"
   Bad example: "The executor properly enforces compilation" (no verification command -- will be rejected by plan-checker)
4. **Behavioral criteria for UI/mixed phases:** For phases classified as `ui` or `mixed`, every task that modifies interactive code (event handlers, click handlers, drag handlers, form submissions, navigation logic) MUST include at least one behavioral criterion that describes the expected logic flow, not just pattern presence. A behavioral criterion traces from trigger to terminal action.
   Good example: "Click handler opens event URL via shell.openExternal -- verified by: `read EventBlock.tsx:handleClick and trace to shell.openExternal call`"
   Good example: "Drag handler updates position state and persists to store -- verified by: `read DragPanel.tsx:onDragEnd and trace through setState to persistPosition call`"
   Bad example: "Button exists -- verified by: `grep 'onClick' EventBlock.tsx`" (grep confirms presence, not behavior)
   Grep-based criteria remain valid for structural checks (file existence, import presence, config values). But each interactive task MUST also have a behavioral criterion that a verifier can trace through the code.
5. Include a traceability table mapping requirements to tasks
6. Every task MUST have a `complexity` attribute (simple, medium, or complex) for cost prediction
7. **Generate test specification files:** For each task, generate a test specification file at `.planning/phases/{phase}/tests/task-{id}.sh`. The test file is a bash script that verifies the task's acceptance criteria. Each test file MUST: (a) contain at least one assertion per acceptance criterion, (b) output structured results in the format `PASS: {criterion}` or `FAIL: {criterion}` per assertion, (c) exit with code 0 if all assertions pass, non-zero if any fail. The planner writes skeleton assertions based on the verification commands from the acceptance criteria. The executor fills in implementation-specific details during execution. Reference the test file in the task's verify section.
   Good example test file (`.planning/phases/{phase}/tests/task-01-01.sh`):
   ```bash
   #!/bin/bash
   PASS=0; FAIL=0
   # Criterion: Config file exists
   if test -f .planning/config.json; then echo "PASS: Config file exists"; ((PASS++)); else echo "FAIL: Config file exists"; ((FAIL++)); fi
   # Criterion: Compile command defined
   if grep -q 'compile' .planning/config.json; then echo "PASS: Compile command defined"; ((PASS++)); else echo "FAIL: Compile command defined"; ((FAIL++)); fi
   echo "RESULTS: $PASS passed, $FAIL failed"
   [ $FAIL -eq 0 ] && exit 0 || exit 1
   ```
8. Return structured JSON at the END of your response (see Return JSON below)
</must>

<should>
1. Each plan should complete within ~50% context budget
2. Split tasks that touch the same file into sequential waves
3. If `.autopilot/learnings.md` exists, read it and incorporate relevant prevention rules into task design (LRNG-02). For example, if a previous phase failed due to unwired files, ensure the plan includes explicit integration criteria. If a previous phase failed due to cross-file inconsistencies, add cross-reference verification criteria to relevant tasks.
4. If `discuss_context` is provided in the spawn prompt (from `--discuss` mode), read the phase directory's `CONTEXT.md` file first (`.planning/phases/{phase}/CONTEXT.md`) for structured implementation decisions, then `.autopilot/discuss-context.json` for supplementary Q&A. Use the user's decisions to inform task design: acceptance criteria specificity (tighten criteria where the user expressed strong preferences), approach selection (prefer approaches aligned with user's stated preferences), scope boundaries (respect scope limits the user explicitly set during discussion), and Claude's Discretion items (where the user deferred to Claude, the planner has flexibility).
5. Each task SHOULD include at least one execution-based verification criterion (compile, test, lint, build, or script execution) when the project has configured commands in `.planning/config.json`. Grep-based criteria remain valid for structural checks, but execution-based criteria provide stronger verification confidence.
</should>

<may>
1. Suggest task ordering optimizations
2. Note deferred decisions for later phases
</may>

<should>
6. Write trace file to .planning/phases/{phase}/plan-trace.jsonl (JSONL, schema: autopilot-schemas.md Section 6)
</should>

**AUTOPILOT CONTEXT (you are in autopilot mode):**
- Your orchestrator is the phase-runner, NOT `/gsd:plan-phase`. Do not wait for user confirmation.
- Auto-approve mode: Proceed without confirmation prompts.
- STATE.md may not exist. Use context from this prompt instead.

Return JSON:
{
  "plans_created": N,
  "waves": N,
  "total_tasks": N,
  "complexity": "simple|medium|complex",
  "dependencies": ["plan 02 depends on plan 01"],
  "concerns": ["any concerns or deferred decisions"]
}
```

**Wait:** Poll until complete.

**Read back:** ONLY the SUMMARY section.

<context_budget>
max_response_lines: 300
max_summary_lines: 10
enforcement: Read JSON return only -- phase-runner reads the JSON block
</context_budget>

---

### STEP 2.5: PLAN CHECK

**Progress:** Emit `[Phase {N}] Step: PLAN-CHECK (5/9)` before starting. Emit `[Phase {N}] Step: PLAN-CHECK complete. Confidence: {confidence}/10` after.

**Purpose:** Verify plans will achieve the phase goal before execution burns context.

**Action:** Spawn `gsd-plan-checker` agent via Task tool, run_in_background=false.

**Prompt template:**

```
You are verifying plans for phase {N}: {phase_name}.

Phase goal: {goal_from_roadmap}
Frozen spec at: {spec_path}
Plans are in: .planning/phases/{phase}/

<must>
1. Verify requirement coverage: every requirement has at least one task
2. Verify task completeness: each task has files, action, verify, and done fields
3. Verify dependency correctness: no cycles, valid references between plans/waves
4. Verify EVERY acceptance criterion contains a runnable verification command. Acceptable verification command patterns:
   - `grep` or `grep -c` with a file path and pattern (e.g., `grep "pattern" file.md`)
   - `test -f` or `test -d` for file/directory existence (e.g., `test -f path/to/file`)
   - A shell command piped to `grep` or `wc` for output matching (e.g., `cmd | grep "expected"`)
   - Any command with an explicit expected output (e.g., "returns 1", "returns at least 1")
   - Project commands from config.json (compile, lint, build, test) with exit code or output check (e.g., `{project.commands.test} 2>&1; echo EXIT:$?`)
   - Direct shell command execution with exit code check (e.g., `npm test 2>&1; echo EXIT:$?`)
   - Script execution with output capture (e.g., `node scripts/validate.js 2>&1`)
   If a criterion lacks a verification command, flag it as a **blocker** with severity "blocker".
5. Reject any acceptance criterion that uses only subjective or vague language without a verification command. Prose-only blocklist patterns: "should work", "properly handles", "is correct", "works as expected", "functions correctly", "is implemented" (without an accompanying command). Any criterion matching these patterns without a runnable verification command is a **blocker**.
6. **Behavioral criteria check for UI/mixed phases:** If the phase type is `ui` or `mixed`, check each task that modifies interactive code (event handlers, click/drag/submit handlers, navigation logic). If a task's acceptance criteria contain ONLY grep-based or file-existence verification commands (`grep`, `test -f`, `test -d`, `wc`) without any behavioral criterion (one that traces handler logic from trigger to terminal action), flag it as a **warning** (not blocker) with: `{"severity": "warning", "description": "Task {id} modifies interactive code but has only grep-based verification. Add a behavioral criterion tracing handler logic.", "fix_hint": "Add a criterion like: '{handler} calls {terminal_action} -- verified by: read {file}:{handler} and trace to {terminal_action} call'"}`. This is a warning because grep criteria are still valid for structural checks, but behavioral criteria catch logic bugs that grep cannot.
7. **Test specification requirement:** Verify that each task has at least one test specification file referenced or generated. If a task's acceptance criteria contain ONLY grep-based or file-existence verification commands (`grep`, `test -f`, `test -d`, `wc`) with no generated test specification (no reference to `.planning/phases/{phase}/tests/task-{id}.sh` in the verify section), flag it as a **blocker** with: `{"severity": "blocker", "description": "Task {id} has only grep-based criteria with no test specification. At least one executable test per task is required.", "fix_hint": "Add a test specification file for task {id} at .planning/phases/{phase}/tests/task-{id}.sh with executable assertions."}`. At least one test specification per task is required to ensure test-driven acceptance criteria.
8. Return structured JSON with pass/fail, issues, and confidence score
</must>

<should>
1. Check scope sanity (2-3 tasks per plan, within context budget)
2. Verify key links are wired (artifacts connected, not just created)
3. Verify external dependencies exist (referenced packages, APIs, services)
4. Each acceptance criterion should follow the pattern: "{description} -- verified by: `{command}`"
5. Verify every `<task>` element has a `complexity` attribute with a valid value (simple, medium, or complex). Flag missing complexity as a warning.
6. If the project config (`.planning/config.json`) has `project.commands.test` or `project.commands.compile` configured, and a task has zero execution-based criteria (all criteria use only grep/test-f/test-d/wc), flag as an info-level note: `{"severity": "info", "description": "Task {id} has no execution-based verification criteria. Consider adding a compile/test/lint verification command for stronger verification confidence.", "fix_hint": "Add a criterion like: 'Project compiles after changes -- verified by: {project.commands.compile} 2>&1; echo EXIT:$?'"}`. Note: This info-level check is supplementary to the MUST-level test specification requirement (MUST item 7). Tasks with only grep criteria and no test specification are blocked at the MUST level.
</should>

<may>
1. Suggest task reordering or consolidation for efficiency
2. Flag potential risks not covered by the plan
</may>

<should>
6. Write trace file to .planning/phases/{phase}/plan_check-trace.jsonl (JSONL, schema: autopilot-schemas.md Section 6)
</should>

Return JSON:
{
  "pass": true|false,
  "issues": [
    {"plan": "NN", "dimension": "string", "severity": "blocker|warning|info", "description": "string", "fix_hint": "string"}
  ],
  "confidence": 1-10,
  "blocker_count": 0,
  "warning_count": 0
}
```

**Gate logic:**
- If `pass` is true AND `confidence` >= 7: proceed to STEP 3.
- If `pass` is false: re-run STEP 2 with checker feedback appended to the planner prompt. Max 3 plan-check iterations.
- If 3 iterations fail: return a failed result to the orchestrator.

**Re-plan prompt addition (when checker fails):**

```
REVISION REQUIRED. The plan checker found these issues:
{issues_json}

Revise the plans to address all blockers. Warnings should be fixed if possible.
```

<context_budget>
max_response_lines: 50
max_summary_lines: 5
enforcement: JSON return only -- phase-runner reads the JSON block
</context_budget>

---

### STEP 3: EXECUTE

**Progress:** Emit `[Phase {N}] Step: EXECUTE (6/9) -- {total_tasks} tasks` before starting. For each task, emit task-level progress (see Per-Task Progress below). Emit `[Phase {N}] Step: EXECUTE complete. {completed}/{total} tasks.` after.

**Purpose:** Implement the plan -- write code, make commits that compile and pass lint. Each task is independently verified before proceeding to the next.

**Pre-launch check:** Compare file lists across all tasks in the current wave. If any file appears in multiple tasks of the same wave, split into sequential sub-waves to avoid merge conflicts.

#### Per-Task Progress

For each task in the execution loop, the phase-runner emits real-time progress:
```
[Phase {N}] Task {task_id} ({M}/{total}): {task_description}
```
When the executor reports modifying a file:
```
[Phase {N}] Task {task_id}: modifying {file_path}
```
When the executor reports compile/lint results:
```
[Phase {N}] Task {task_id}: compile PASS
[Phase {N}] Task {task_id}: compile FAIL -- {error_summary}
```
After mini-verification:
```
[Phase {N}] Task {task_id}: VERIFIED
[Phase {N}] Task {task_id}: FAILED -- {failure_reason}
```

#### Per-Task Execution Loop (PVRF-01)

Instead of spawning a single executor for all tasks, the phase-runner orchestrates per-task execution with incremental verification. This catches failures at minute 5 (after the first task) instead of minute 30+ (after all tasks complete).

**Loop structure:**
```
tasks = extract ordered task list from PLAN.md
for each task in tasks:
  1. EXECUTOR SPAWN: Spawn gsd-executor for this single task (run_in_background=true)
     - Pass: task definition, PLAN.md path, cumulative EXECUTION-LOG.md (so executor has context from prior tasks)
     - Executor completes the task, writes EXECUTION-LOG.md entry, makes atomic commit, returns JSON
  2. MINI-VERIFY: Spawn mini-verifier (general-purpose, run_in_background=false)
     - Pass: task's acceptance criteria from PLAN.md, files modified (from executor return), EXECUTION-LOG.md entry
     - Mini-verifier runs each verification command independently, returns structured JSON
  3. PROCESS RESULT:
     - If mini-verifier returns pass: log "Task {id} VERIFIED. Proceeding to next task." Continue loop.
     - If mini-verifier returns fail: spawn autopilot-debugger (or gsd-debugger as fallback) targeting the specific failures.
       - Debugger fixes issues, re-commits.
       - Re-run mini-verifier (max 2 debug attempts per task).
       - If still failing after 2 attempts: log failure, mark task as FAILED in EXECUTION-LOG.md, continue to next task (do not halt entire phase for one task failure).
  4. LOG: Update EXECUTION-LOG.md with mini_verification results (see schema below).
```

**Executor spawn for single task -- prompt additions:**

When spawning the executor for a single task, append this to the standard executor prompt:

> **INCREMENTAL EXECUTION MODE:** You are executing a SINGLE task ({task_id}: {task_description}). Complete ONLY this task. Do NOT proceed to other tasks. After completing this task, write your EXECUTION-LOG.md entry and return immediately. The phase-runner will verify this task independently before dispatching the next task.
>
> **Prior task context:** {summary of EXECUTION-LOG.md entries from previously completed tasks, or "This is the first task."}

**Mini-Verifier Prompt Template:**

```
You are a mini-verifier for task {task_id} of phase {N}: {phase_name}.

Your ONLY job is to independently verify this single task's acceptance criteria. You did NOT write this code.

Task: {task_id} -- {task_description}
Files modified: {files_from_executor_return}
Acceptance criteria from PLAN.md:
{task_acceptance_criteria_with_verification_commands}

<must>
1. For EACH acceptance criterion, run the verification command specified in the criterion.
2. Compare the command output against the expected result.
3. Record PASS or FAIL per criterion with evidence (file:line, command output).
4. Return structured JSON (see Return JSON below).
5. Do NOT trust the executor's self-reported results. Run every command yourself.
</must>

<should>
1. If a criterion passes via grep but the surrounding context looks wrong (e.g., pattern found but in a comment or dead code block), flag it as a concern.
2. Check that the executor's commit is atomic (only touches files listed in the task).
</should>

Return JSON:
{
  "task_id": "{task_id}",
  "pass": true|false,
  "criteria_results": [
    {"criterion": "text", "status": "pass|fail", "evidence": "file:line -- output", "command": "the command run", "command_output": "first 200 chars"}
  ],
  "concerns": ["any concerns even if passing"],
  "commands_run": ["command -> result"]
}
```

**Mini-verification failure handling:**

When the mini-verifier reports `pass: false`:
1. Extract the failed criteria from `criteria_results`.
2. Spawn `autopilot-debugger` (or `gsd-debugger` as fallback) with the failed criteria as the issue list.
3. After the debugger returns, re-spawn the mini-verifier to confirm the fix.
4. Max 2 debug attempts per task. If the task still fails after 2 attempts, mark it as FAILED in EXECUTION-LOG.md and proceed to the next task.
5. At the end of the per-task loop, if ANY task has status FAILED, the phase proceeds to final verification (STEP 4) but the phase-runner notes the failures in its return JSON `issues` array.

**EXECUTION-LOG.md per-task entry:** Each entry MUST include a `mini_verification` section (Result, Criteria checked/passed, Failures, Debug attempts) after the executor's self-reported results. Schema: see autopilot-schemas.md Section 5 (PVRF-01).

**Mini-verifier context budget:** max 30 response lines, 5 summary lines (JSON only), ~5 lines ingested per task. If plan has >8 tasks, fall back to batch execution (single executor spawn, mini-verify per EXECUTION-LOG.md entry after).

**Action:** Spawn `gsd-executor` agent via Task tool, run_in_background=true. When in per-task execution mode, spawn once per task. When in batch fallback mode, spawn once for all tasks.

**Prompt template:**

> Execute the plans for phase {N}: {phase_name}.
>
> **Phase goal:** {goal_from_roadmap}
> **Phase type:** {ui|protocol|data|mixed}
> **Plans are at:** .planning/phases/{phase}/PLAN.md
> **Frozen spec at:** {spec_path}
>
> <pre_execution>
> Before executing any tasks, perform context priming:
> 1. Read the PLAN.md to understand all tasks and their dependencies.
> 2. Read 3-5 key project files listed in the plan's "files" fields to understand the codebase state.
> 3. Run the configured compile command once to establish a baseline. Record: PASS (0 errors) or FAIL (N errors). If baseline fails, note which errors are pre-existing vs. your responsibility. **Note:** Project commands (`project.commands.compile`, `.test`, `.lint`, `.build`) are auto-detected from project manifests by the orchestrator during initialization (Section 1.8) and populated in `.planning/config.json`. The executor reads these values and does not need to detect them itself. If `project.commands.compile` is null (no compile command available), skip the compile baseline and log: "Compile command not configured -- compile gate skipped."
> 4. If `.autopilot/learnings.md` exists, read it and acknowledge known pitfalls. Note any learnings relevant to this phase in your first EXECUTION-LOG.md entry.
> 5. If `.autopilot/repo-map.json` exists, read it to understand the codebase structure before creating any new files. Use the map to check if functionality you are about to create already exists elsewhere (check `exports` and `functions` arrays for matching names). If an existing implementation is found via the map, extend or import it rather than creating a duplicate. The repo-map is the primary lookup mechanism for existing implementations; use grep as a fallback for symbols not covered by the map.
> 6. Report priming results in your first EXECUTION-LOG.md entry before any task work: files read, baseline compile result, repo-map status (loaded with N files or "not found"), and pitfalls acknowledged (or "no learnings file found").
> </pre_execution>
>
> <must>
> 1. Make atomic git commits per task with format: `{type}({phase}): {task_id} - {concise task description}`. Example: `feat(02): 02-01 - add compile gates to executor prompt`. Each task gets exactly one commit.
> 2. After writing or modifying any file, immediately run the compile check (from `.planning/config.json` `project.commands.compile`). If a file you wrote fails compilation, you MUST fix that file before writing any other file. Do not proceed to the next file or task until compilation passes. Run compile and lint (from `project.commands.lint`) before each commit. Fix errors before committing. If `project.commands.compile` or `project.commands.lint` are null (commands not available for this project type), skip the corresponding gate and log: "Compile/lint command not configured -- gate skipped." Do NOT error when commands are null -- null means the gate is not applicable.
> 3. Self-test EACH acceptance criterion for the current task before marking it complete. For every criterion, run the specified verification command (grep, file read, command output check) and record the result as PASS or FAIL with file:line evidence. If ANY criterion fails, you MUST fix the issue before marking the task complete. Do NOT mark a task complete based on "I wrote the code so it should work." Additionally, run the generated test specification file for the task (`bash .planning/phases/{phase}/tests/task-{id}.sh 2>&1; echo EXIT:$?`). If the test file exits with non-zero, the task is NOT complete -- fix the failing assertions before proceeding. If the test file does not exist (planner did not generate one), log a warning but do not block task completion.
> 4. **Post-creation integration check:** After creating any NEW source file (not modifying an existing one), search the codebase for imports or references to that file (e.g., `grep -r "import.*filename" . --include="*.ts" --include="*.tsx" --include="*.js" --include="*.md"`). If zero references are found, check whether the file is a known standalone type: entry points (index.*, main.*, App.*), config files (*.config.*, *.json, *.yaml, *.yml, *.toml, .eslintrc*, .prettierrc*, tsconfig*), test files (*.test.*, *.spec.*, __tests__/*), scripts (bin/*, scripts/*), type declarations (*.d.ts), or documentation (*.md). If the file is NOT a standalone type AND has zero imports/references, the task is INCOMPLETE -- you must either: (a) add the import/reference to an appropriate parent file and verify it is called/rendered, OR (b) document an explicit standalone justification in the EXECUTION-LOG.md task entry explaining why the file does not need to be imported. Silent orphaning (zero references, no justification, task marked complete) is blocked.
> 5. Record evidence per task: commands run with output, file:line references proving each criterion is met. Include the test specification output (PASS/FAIL per criterion and overall exit code) in the evidence for each task.
> 6. Write task completion status to .planning/phases/{phase}/EXECUTION-LOG.md IMMEDIATELY after completing each task -- before starting the next task. Each entry must include: task ID, status (COMPLETED/FAILED/NEEDS_REVIEW), commit SHA, files modified, evidence summary, test_results ({PASS count}/{total count} assertions passed), and a confidence score (1-10). Scoring guide: 10=all criteria verified with evidence, 7-9=criteria verified but minor concerns, 4-6=some criteria unverified or uncertain, 1-3=significant issues remain. If your confidence is below 7, set status to NEEDS_REVIEW -- the phase-runner will spawn a mini-verification agent before you proceed to the next task. Do NOT batch these writes.
> 7. Return structured JSON at the END of your response (see Return JSON below).
> </must>
>
> <should>
> 1. Run build check (from `project.commands.build`) for UI phases before committing.
> 2. Follow commit message conventions from the repository's recent git log.
> 3. If planned code already exists, verify EACH acceptance criterion with file:line evidence and report commit_sha as null.
> 4. Before creating a new file, consult `.autopilot/repo-map.json` first (if it exists) to check whether the functionality already exists -- search the `exports`, `functions`, and `classes` arrays for matching names. If the repo-map does not exist or does not cover the symbol, fall back to text search (`grep -r "function_name\|class_name" . --include="*.ts" --include="*.tsx"`). If an existing implementation is found via either method, extend or import it rather than creating a duplicate file.
> 5. After each commit, update `.autopilot/repo-map.json` incrementally if it exists: for each file modified or added in the commit, re-read the file and update its entry in the map (exports, imports, functions, classes). For deleted files, remove their entries. Update the summary statistics. Do NOT regenerate the entire map -- only update changed entries. If `.autopilot/repo-map.json` does not exist, skip this step.
> </should>
>
> <should>
> 5. Write trace file to .planning/phases/{phase}/execute-trace.jsonl (JSONL, schema: autopilot-schemas.md Section 6)
> </should>
>
> <may>
> 1. Create SUMMARY.md in the phase directory if it helps document the work.
> 2. Add inline comments in modified files explaining non-obvious changes.
> </may>
>
> **AUTOPILOT CONTEXT (you are in autopilot mode):**
> - Your orchestrator is the phase-runner, NOT `/gsd:execute-phase`. Do not look for execute-phase workflow artifacts.
> - STATE.md may not exist. Use context from this prompt instead.
>
> Return JSON:
> ```json
> {
>   "tasks_completed": "N/M",
>   "tasks_failed": "N/M",
>   "commit_shas": ["sha1", "sha2"],
>   "evidence": [
>     {
>       "task_id": "XX-YY",
>       "criteria_met": ["criterion text -- file:line -- what was found"],
>       "commands_run": ["command -> result"]
>     }
>   ],
>   "deviations": ["any departures from plan"]
> }
> ```

**Wait:** Poll until complete. This is the LONGEST step -- may take 10-30 minutes.

**Read back:** ONLY the SUMMARY section.

<context_budget>
max_response_lines: 500
max_summary_lines: 15
enforcement: Read JSON return only -- phase-runner reads the JSON block
</context_budget>

---

### STEP 4: VERIFY -- MANDATORY INDEPENDENT AGENT

**Progress:** Emit `[Phase {N}] Step: VERIFY (7/9)` before starting. Emit `[Phase {N}] Step: VERIFY complete. Result: {pass|fail}` after.

**Rules (unchanged):**
1. You MUST spawn a verifier subagent
2. You MUST NOT self-assess
3. The verifier reads the PLAN.md acceptance criteria, the actual file changes, and runs automated checks

**Action:** Spawn `gsd-verifier` agent via Task tool, run_in_background=false.

**Verifier prompt template:**

> You are an independent verifier. You did NOT write this code. Your job is to find problems.
>
> Phase: {N} -- {phase_name}
> Phase goal: {goal_from_roadmap}
> Phase type: {ui|protocol|data|mixed}
> Frozen spec at: {spec_path}
> Plans at: .planning/phases/{phase}/PLAN.md
> Changes since last checkpoint: Run `git diff {last_checkpoint_sha}..HEAD`
>
> **BLIND VERIFICATION: You do NOT receive the executor's evidence summary or self-reported results. You verify from scratch using only the acceptance criteria and the git diff. This is intentional -- independent verification requires independence from executor claims.**
>
> <must>
> 1. Run automated checks: compile and lint (read commands from `.planning/config.json` `project.commands`)
> 2. Verify EACH acceptance criterion by reading the actual files -- do NOT trust executor claims
> 3. Run phase-type-specific checks (see methodology below)
> 4. **Independent wire check for new files:** For each file ADDED in the git diff (new files, not modifications), verify it has at least one import or reference elsewhere in the codebase (`grep -r "filename" . --include="*.ts" --include="*.tsx" --include="*.js" --include="*.md"` etc.). If a new file has zero imports AND is not a known standalone type (entry point, config, test, script, type declaration, documentation) AND does not have an explicit standalone justification documented in the EXECUTION-LOG.md task entry, flag it as a verification concern: "ORPHANED FILE: {path} -- zero imports, no standalone justification." Record all wire-check results in VERIFICATION.md.
> 5. Write verification report to .planning/phases/{phase}/VERIFICATION.md
> 6. Record every command you run in a `commands_run` list (command + result) -- an empty commands_run list will be rejected as rubber-stamping. Classify every failure using the failure taxonomy (Section 2.5): executor_incomplete, executor_wrong_approach, compilation_failure, lint_failure, build_failure, acceptance_criteria_unmet, scope_creep, context_exhaustion, tool_failure, coordination_failure.
> 7. Return structured JSON with pass/fail and criteria results
> </must>
>
> <should>
> 1. Record specific file:line evidence for each verified criterion
> 2. Identify scope creep (anything built that was not in spec)
> 3. Score conservatively: 7-8 with noted concerns is more credible than 9-10 with none
> </should>
>
> <should>
> 4. Write trace file to .planning/phases/{phase}/verify-trace.jsonl (JSONL, schema: autopilot-schemas.md Section 6)
> </should>
>
> <may>
> 1. Suggest improvements to code quality or test coverage
> 2. Note potential edge cases not covered by acceptance criteria
> </may>
>
> **AUTONOMOUS RESOLUTION (all phase types -- attempt BEFORE any deferral consideration):**
>
> The verifier MUST attempt autonomous resolution of ALL acceptance criteria before considering human deferral. This applies to every phase type, including UI phases.
>
> **Autonomous Resolution Steps:**
> 1. Run all automated checks (compile, lint, build) and record results
> 2. For UI/mixed phases: Execute behavioral traces for ALL interactive handlers found in the git diff (trace from trigger to terminal action)
> 3. For each acceptance criterion: run the verification command, read the target file, confirm the criterion is met with file:line evidence
> 4. Compute `autonomous_confidence` (1-10): How confident is the verifier that ALL criteria are met based on code analysis and command execution alone?
>    - 9-10: All criteria verified with commands and code reading, no ambiguity
>    - 7-8: Most criteria verified, minor gaps that code analysis cannot resolve (e.g., visual rendering)
>    - 5-6: Significant criteria that code analysis alone cannot confirm
>    - 1-4: Multiple criteria require runtime or visual inspection
>
> **Deferral Evidence Threshold:**
> Deferral to human review is ONLY permitted when ALL of the following conditions are met:
> 1. `autonomous_confidence` is below 6 (the verifier genuinely cannot confirm criteria through code analysis)
> 2. The verifier documents specific `deferral_evidence` for each criterion it cannot verify:
>    - Which criterion cannot be verified autonomously
>    - What verification methods were attempted (commands run, files read, traces performed)
>    - Why each method was insufficient (specific reason, not "I'm not sure" or "visual confirmation needed")
> 3. The deferral reason is NOT a generic visual confirmation -- specific untraceable behavior must be identified
>
> If the verifier's `autonomous_confidence` is 6 or above, it MUST return pass/fail without deferral, even for UI phases. The behavioral trace methodology (below) combined with build verification is sufficient for autonomous UI validation in most cases.
>
> **VERIFICATION METHODOLOGY:**
>
> **Step 1: Automated checks (ALL phase types):**
> Project commands are auto-detected from manifests and populated in `.planning/config.json` by the orchestrator (Section 1.8). If a command is null, skip that check and record "n/a" (not "FAIL").
> ```bash
> # 1. Compile check (run configured compile command, skip if null)
> {project.commands.compile} 2>&1
> # Record: PASS (0 errors) or FAIL (N errors, first 3 error messages) or n/a (command is null)
>
> # 2. Lint check (run configured lint command, skip if null)
> {project.commands.lint} 2>&1 | tail -5
> # Record: PASS (0 errors) or FAIL (N errors) or n/a (command is null)
> ```
>
> **Step 1.5: Execution-Based Verification (ALL phase types):**
> For each acceptance criterion that specifies an execution command (not grep/test-f/wc -- look for commands like `{project.commands.test}`, `npm run ...`, `node ...`, or any command with `EXIT:$?`):
> 1. Run the command using the Bash tool with a 60-second timeout
> 2. Capture stdout, stderr, and exit code
> 3. Assess the result: exit code 0 with expected output = VERIFIED; non-zero exit code = FAILED with runtime error details; timeout = FAILED with timeout indication
> 4. If a command crashes, throws an unhandled exception, or times out, record it as a verification failure. Include the error output (first 500 chars of stderr) in the failure report. Classify runtime failures using the failure taxonomy: `compilation_failure`, `build_failure`, `lint_failure`, or `tool_failure` as appropriate.
> 5. Record all results in VERIFICATION.md under a "Sandbox Execution Results" section:
> ```markdown
> ## Sandbox Execution Results
>
> | Criterion | Command | Exit Code | Output (truncated) | Assessment |
> |-----------|---------|-----------|-------------------|------------|
> | Tests pass | npm test 2>&1 | 0 | All 42 tests passed | VERIFIED |
> | Build succeeds | npm run build 2>&1 | 1 | Error: Module not found | FAILED |
> ```
> 6. For criteria with execution-based verification commands, run the actual command (not just grep for the command text) and use the runtime output to assess the criterion. Execution-based verification is STRONGER than grep -- when both are available, execution takes precedence.
>
> **Step 1.7: Test Specification Execution (ALL phase types):**
> For each task in PLAN.md, check if a test specification file exists at `.planning/phases/{phase}/tests/task-{id}.sh`:
> 1. Run the test file: `bash .planning/phases/{phase}/tests/task-{id}.sh 2>&1`
> 2. Capture the full output (PASS/FAIL per criterion) and exit code
> 3. Parse the structured output to extract per-criterion pass/fail results
> 4. Record results in VERIFICATION.md under a "Test Specification Results" section:
> ```markdown
> ## Test Specification Results
>
> | Task | Test File | Assertions Passed | Assertions Failed | Exit Code | Status |
> |------|-----------|-------------------|-------------------|-----------|--------|
> | 18-01 | tests/task-18-01.sh | 5 | 0 | 0 | ALL PASS |
> | 18-02 | tests/task-18-02.sh | 3 | 1 | 1 | FAILED |
> ```
> 5. If any test specification fails, record the failing assertions as verification failures. Classify as `acceptance_criteria_unmet`.
> 6. Test specification results are PRIMARY evidence. When test results and grep results disagree, test results take precedence.
> 7. If no test specification files exist for any task, log: "No test specifications found. Falling back to grep-based verification only."
> 8. Include all test specification execution commands and their outputs in the `commands_run` list.
>
> **Step 2: Phase-type-specific checks:**
>
> **If UI phase:**
> ```bash
> # Standard automated checks
> {project.commands.build} 2>&1
> grep -r "import.*ComponentName" {project.ui.source_dir} --include="{project.ui.file_extensions}"
> ```
>
> **Behavioral Trace step (UI/mixed phases only):**
> For each interactive handler found in the git diff (`onClick`, `onDrag`, `onDragEnd`, `onSubmit`, `onChange`, `onKeyDown`, `onMouseDown`, event listeners, IPC handlers), trace the handler chain:
> 1. **Identify trigger:** Find the handler declaration in the diff (e.g., `const handleClick = ...` or `onClick={...}`)
> 2. **Trace function calls:** Follow each function call from the handler body. For each call, read the target function definition. Continue until reaching a terminal action.
> 3. **Identify terminal action:** The chain ends at one of: API call, URL navigation (`shell.openExternal`, `window.open`, `router.push`), state mutation (`setState`, store dispatch), DOM manipulation, IPC message, file system operation, or external library call.
> 4. **Verify correctness:** Compare the terminal action against the acceptance criterion. Does the handler DO what the criterion says it should do?
> 5. **Record trace:** For each handler, record a trace entry in VERIFICATION.md under a "Behavioral Traces" section:
>
> ```markdown
> ## Behavioral Traces
>
> | Handler | File:Line | Chain | Terminal Action | Criterion Match | Status |
> |---------|-----------|-------|-----------------|-----------------|--------|
> | handleJoin | EventBlock.tsx:42 | handleJoin -> openURL -> shell.openExternal | Opens event URL in default browser | "Join opens event URL" | VERIFIED |
> | onDragEnd | DragPanel.tsx:87 | onDragEnd -> updatePosition -> store.set | Persists position to electron-store | "Drag updates position" | VERIFIED |
> | handleDelete | EventCard.tsx:31 | handleDelete -> ??? (opaque library) | Could not trace past library boundary | "Delete removes event" | BEHAVIORAL_UNVERIFIABLE |
> ```
>
> 6. **Handle untraceable chains:** If a trace cannot be completed (e.g., opaque third-party library call, dynamic dispatch that cannot be statically resolved), record the handler as `BEHAVIORAL_UNVERIFIABLE` with the reason. This is NOT a failure -- it is an honest acknowledgment of verification limits. The verifier should note what percentage of handlers were fully traced vs. unverifiable.
>
> **IMPORTANT:** Behavioral traces are in ADDITION to the standard grep-based acceptance criteria checks, not a replacement. Both must pass.
>
> **Step 2.5: Visual Testing (UI/mixed phases with visual_testing config only):**
> If the phase type is `ui` or `mixed` AND `.planning/config.json` contains `project.visual_testing` with `enabled: true` (or `visual_testing_enabled: true` was passed in the spawn prompt via `--visual` flag):
>
> 1. **Launch the application:**
>    ```bash
>    # Start the app server in background
>    {project.visual_testing.launch_command} &
>    APP_PID=$!
>    # Wait for app to be ready
>    sleep $(( {project.visual_testing.launch_wait_ms} / 1000 ))
>    # Verify app is running
>    curl -s -o /dev/null -w "%{http_code}" {project.visual_testing.base_url}
>    ```
>    If the app fails to start (curl returns non-200 or connection refused), log: "Visual testing skipped: app failed to launch." and continue verification without visual tests.
>
> 2. **Capture screenshots for each route:**
>    ```bash
>    mkdir -p {project.visual_testing.screenshot_dir}
>    # For each route in project.visual_testing.routes:
>    npx playwright screenshot \
>      --viewport-size="{viewport.width},{viewport.height}" \
>      "{base_url}{route.path}" \
>      "{screenshot_dir}/{route.name}-$(date +%Y%m%dT%H%M%SZ).png"
>    # Wait route.wait_ms before capturing to allow rendering
>    ```
>    Use the Bash tool with a 60-second timeout per screenshot command.
>
> 3. **Analyze screenshots for visual issues:**
>    Read each captured screenshot using the Read tool (Claude's multimodal capability analyzes images).
>    For each screenshot, evaluate:
>    - **Layout issues:** Overlapping elements, broken grids, misaligned text, overflow/clipping
>    - **Rendering errors:** Blank/white screens, missing images, broken icons, unstyled elements
>    - **Visual regressions:** If baseline screenshots exist in `{screenshot_dir}/baseline/`, compare current screenshots against baselines for visual changes
>    - **Accessibility concerns:** Text too small, insufficient contrast, missing visual indicators
>
> 4. **Record results in VERIFICATION.md** under a "Visual Testing Results" section:
>    ```markdown
>    ## Visual Testing Results
>
>    | Route | Screenshot | Issues | Severity | Status |
>    |-------|-----------|--------|----------|--------|
>    | / (home) | screenshots/home-20260212.png | 0 | - | PASS |
>    | /dashboard | screenshots/dashboard-20260212.png | 2 | major | ISSUES_FOUND |
>    ```
>    For each issue found, record: type (layout/rendering/regression/accessibility), severity (critical/major/minor), description, approximate location in screenshot, and suggested fix.
>
> 5. **Generate visual bug report:** If any issues are found, write a structured bug report to `.planning/phases/{phase}/VISUAL-BUGS.md` containing: each issue with route, screenshot path, type, severity, description, location, and suggested fix (with target file/component). Include a Resolution Tracking table for use by the debug loop.
>
> 6. **Cleanup:** Kill the app server process after all screenshots are captured.
>    ```bash
>    kill $APP_PID 2>/dev/null || true
>    ```
>
> 7. **If visual testing infrastructure is not available** (Playwright not installed, app fails to launch, port already in use), log the issue and continue verification without visual tests. Do NOT fail the verification because visual testing infrastructure is unavailable -- it is an enhancement, not a gate. Record `infrastructure_available: false` in the return JSON `visual_test_results`.
>
> 8. **Add visual test results to return JSON:** Include `visual_test_results` in the verifier return JSON:
>    ```json
>    "visual_test_results": {
>      "routes_tested": 5,
>      "routes_passed": 3,
>      "issues_found": [{"route": "/dashboard", "type": "layout", "severity": "major", "description": "..."}],
>      "screenshots": ["path1.png", "path2.png"],
>      "infrastructure_available": true
>    }
>    ```
>
> **If PROTOCOL phase:**
> ```bash
> # Cross-reference validation: extract file path references and verify they exist
> grep -oE '`[a-zA-Z0-9_./-]+\.[a-z]+`' {modified_file}
> ls -la {each_referenced_path} 2>&1
> # Schema consistency: extract JSON blocks and verify they parse
> ```
>
> **If DATA phase:**
> ```bash
> python3 -c "import json; json.load(open('{data_file}'))" 2>&1
> ```
>
> **If MIXED phase:** Run ALL checks from applicable phase types above.
>
> **Step 3: Acceptance criteria verification:**
> For EACH criterion in PLAN.md: read the file, find evidence, record VERIFIED or FAILED. When test specification results exist for a criterion (from Step 1.7), reference the test output as the primary evidence. Grep-based evidence becomes supplementary (structural confirmation).
>
> **Step 4: New file wire check (ALL phase types):**
> For each file ADDED in the git diff (use `git diff {last_checkpoint_sha}..HEAD --name-status | grep '^A'`):
> 1. Search the codebase for imports/references to that file
> 2. If zero references found, check if file is a known standalone type (entry point, config, test, script, type declaration, documentation)
> 3. If not standalone, check EXECUTION-LOG.md for an explicit standalone justification
> 4. If no references AND not standalone AND no justification: flag as "ORPHANED FILE" verification concern
> Record results in VERIFICATION.md under a "Wire Check" section.
>
> **AUTOPILOT CONTEXT:** Do not default to 9/10. Scores of 7-8 with noted concerns are more credible.
>
> Return JSON:
> ```json
> {
>   "pass": true|false,
>   "automated_checks": {
>     "compile": {"status": true|false, "detail": "..."},
>     "lint": {"status": true|false, "detail": "..."},
>     "build": {"status": true|false|"n/a", "detail": "..."}
>   },
>   "criteria_results": [
>     {"criterion": "text", "status": "verified|failed", "evidence": "file:line -- what"}
>   ],
>   "verification_duration_seconds": N,
>   "commands_run": ["command -> result"],
>   "failures": ["description"],
>   "failure_categories": [{"failure": "description", "category": "taxonomy_value"}],
>   "scope_creep": ["anything built that was not in spec"],
>   "execution_results": [
>     {"criterion": "text", "command": "cmd", "exit_code": 0, "output": "first 200 chars", "assessment": "pass|fail|timeout"}
>   ],
>   "autonomous_resolution_attempted": true,
>   "autonomous_confidence": 8,
>   "deferral_evidence": []
> }
> ```
>
> **Autonomous resolution fields:**
> - `autonomous_resolution_attempted`: Always `true` -- the verifier MUST attempt autonomous resolution before any deferral
> - `autonomous_confidence`: 1-10 score of how confidently the verifier verified all criteria through code analysis and command execution alone. If >= 6, deferral is NOT permitted.
> - `deferral_evidence`: Empty array if no deferral needed. If populated, each entry must have: `{"criterion": "text", "methods_attempted": ["what was tried"], "why_insufficient": "specific reason"}`

**Read back:** ONLY the JSON result.

**Phase-runner timing:** Record the wall-clock time when the verifier agent is spawned and when it returns. Compute `verification_duration_seconds` = end - start. The orchestrator rejects any verification completing in under 120 seconds (2 minutes) as a rubber-stamp indicator. Pass this value through to the return contract.

**Phase-runner validation:** Check `commands_run` from the verifier return JSON. If it is empty, the verification is invalid -- the orchestrator will reject it. Log a warning and enter debug loop to re-run verification.

<context_budget>
max_response_lines: 200
max_summary_lines: 10
enforcement: JSON return only -- phase-runner reads the JSON block
</context_budget>

---

### Sandbox Execution Policy

**Sandbox boundaries:** Commands MUST NOT: (1) modify files outside the project directory, (2) install global packages, (3) access non-project network resources. Timeout: 60 seconds max per command. Error handling: record exit codes and stderr (first 500 chars), classify failures using taxonomy (compilation_failure, build_failure, lint_failure, tool_failure, scope_creep). Execution-based verification is STRONGER than grep and takes precedence when both are available. Preserves blind verification (VRFY-01): commands come from PLAN.md criteria, not executor evidence.

---

### Visual Regression Loop Protocol

**Applies to:** UI/mixed phases with `project.visual_testing.enabled` only.

**Triggered when:** Verifier Step 2.5 finds visual issues (issues_found > 0).

**Loop:** (1) Generate bug report at `.planning/phases/{phase}/VISUAL-BUGS.md` with per-issue route, screenshot, type, severity, location, suggested fix, and resolution tracking table. (2) Pass bug report to debugger (Step 5a) alongside functional issues. (3) After fix, re-run Step 2.5 and update resolution tracking. (4) Terminates when all critical/major issues resolved, or max 3 debug attempts reached. Schema: see autopilot-schemas.md Section 16.

**Baselines:** Save passing screenshots to `{screenshot_dir}/baseline/` for regression detection. Not committed to git.

---

### STEP 4.5: LLM JUDGE -- MANDATORY INDEPENDENT AGENT

**Progress:** Emit `[Phase {N}] Step: JUDGE (8/9)` before starting. Emit `[Phase {N}] Step: JUDGE complete. Recommendation: {recommendation}` after.

The judge provides an ADVERSARIAL second opinion. It does NOT read the verifier's conclusions first.

**Rules:**
1. You MUST spawn a judge subagent (subagent_type: "general-purpose")
2. The judge receives: (a) the frozen spec requirements, (b) the PLAN.md, (c) the raw git diff, (d) the executor's evidence
3. The judge does NOT receive the verifier's pass/fail conclusion (alignment scoring is handled by the dedicated rating agent in STEP 4.6)
4. The judge runs its OWN checks before reading the VERIFICATION.md
5. The judge MUST identify at least one concern (even if minor) to prove it examined the work

**Judge prompt template:**

> You are an adversarial judge. Your job is to find what the verifier MISSED.
>
> Phase: {phase_id} -- {phase_name}
> Phase type: {ui|protocol|data|mixed}
> Spec requirements for this phase: {requirements_list}
>
> <must>
> 1. Gather evidence INDEPENDENTLY before reading VERIFICATION.md (run git diff, git log, read files)
> 2. Spot-check at least one acceptance criterion by reading the actual file. **For UI/mixed phases:** Your spot-check MUST be a behavioral spot-check -- trace one handler chain from trigger (e.g., onClick, onDrag, onSubmit) to terminal action (API call, URL open, state mutation), not just grep-verify a pattern. Read the handler function, follow its calls, and confirm the terminal action matches the criterion.
> 3. Check the frozen spec at {spec_path} for any missed requirements
> 4. Write your independent findings to `.planning/phases/{phase}/JUDGE-REPORT.md` BEFORE reading VERIFICATION.md. This artifact is structural proof of independent execution -- the orchestrator verifies it exists.
> 5. After writing JUDGE-REPORT.md, read VERIFICATION.md and add a "Divergence Analysis" section to your JUDGE-REPORT.md noting: (a) points where you agree with the verifier AND have independent evidence, (b) points where you disagree, (c) points the verifier missed, (d) points you missed that the verifier found. If you agree on every point, you MUST present your independent evidence (specific file:line references, command outputs) proving you reached the same conclusion independently -- agreement without independent evidence will be rejected as rubber-stamping.
> 6. Identify at least one concern (even if minor) to prove independent examination
> 7. Return structured JSON with recommendation and concerns (the rating agent handles scoring separately)
> </must>
>
> <should>
> 1. Compare your findings against the verifier's report after independent review
> 2. Flag scope creep (code nobody asked for)
> 3. Assess independently -- the rating agent handles scoring, your job is recommendation and concerns
> </should>
>
> <should>
> 4. Write trace file to .planning/phases/{phase}/judge-trace.jsonl (JSONL, schema: autopilot-schemas.md Section 6)
> </should>
>
> <may>
> 1. Suggest process improvements for future phases
> 2. Note technical debt introduced by the changes
> </may>
>
> **YOUR EVIDENCE (gather independently before reading any reports):**
>
> 1. Read the plan at: .planning/phases/{phase}/PLAN.md
> 2. Run: `git diff {last_checkpoint_sha}..HEAD --stat`
> 3. Run: `git log --oneline {last_checkpoint_sha}..HEAD`
> 4. For each acceptance criterion in the plan, spot-check ONE by reading the actual file
> 5. **For UI/mixed phases:** Read the verifier's VERIFICATION.md and check for a "Behavioral Traces" table. Independently verify at least one entry from this table by re-tracing the handler chain yourself. If the "Behavioral Traces" section is missing entirely for a UI/mixed phase, note this as a concern: "Verifier did not perform behavioral traces for UI phase."
> 6. Read the frozen spec at {spec_path}
>
> **AFTER gathering your own evidence, read:**
> 6. .planning/phases/{phase}/VERIFICATION.md (the verifier's report)
>
> **Assessment guide (focus on concerns and recommendation, NOT scoring -- the rating agent handles scoring separately):**
> - If all criteria verified, all checks pass, no scope creep: recommend "proceed"
> - If minor issues only: recommend "proceed" with concerns noted
> - If significant failures: recommend "debug"
> - If fundamental misalignment: recommend "rollback" or "halt"
>
> Return JSON:
> ```json
> {
>   "recommendation": "proceed|debug|rollback|halt",
>   "concerns": ["at least one item"],
>   "independent_evidence": ["file:line -- what was found independently"],
>   "verifier_agreement": true|false,
>   "verifier_missed": ["items the verifier didn't catch, if any"],
>   "scope_creep": ["items"],
>   "missing_requirements": ["items"],
>   "notes": "1-2 sentence assessment"
> }
> ```

<context_budget>
max_response_lines: 100
max_summary_lines: 5
enforcement: JSON return only -- phase-runner reads the JSON block
</context_budget>

---

### STEP 4.6: RATE -- MANDATORY INDEPENDENT AGENT

**Progress:** Emit `[Phase {N}] Step: RATE (9/9)` before starting. Emit `[Phase {N}] Step: RATE complete. Score: {alignment_score}/10` after.

The rating agent is a DEDICATED, CONTEXT-ISOLATED agent that does NOTHING but evaluate work quality and produce the alignment score. It replaces the previous inline scoring that was done by the verifier and judge as a side-task.

**Rules:**
1. You MUST spawn a rating subagent (subagent_type: "general-purpose")
2. The rating agent is CONTEXT-ISOLATED: it receives ONLY (a) acceptance criteria from PLAN.md, (b) the git diff command to run, and (c) read access to the codebase
3. The rating agent does NOT receive: executor confidence scores, verifier report/pass-fail, judge recommendation/concerns, or any prior assessment
4. The rating agent's `alignment_score` is the AUTHORITATIVE score used in the return contract and gate decision
5. All scores MUST use decimal precision (x.x/10 format). Integer scores are NOT allowed

**Action:** Spawn `general-purpose` agent via Task tool, run_in_background=false.

**Rating agent prompt template:**

> You are a dedicated rating agent. Your ONLY job is to evaluate work quality and produce a calibrated alignment score. You have NO other responsibilities. You do NOT make recommendations about proceeding, debugging, or rolling back -- that is the judge's job. You ONLY score.
>
> Phase: {N} -- {phase_name}
> Phase goal: {goal_from_roadmap}
> Phase type: {ui|protocol|data|mixed}
> Plans at: .planning/phases/{phase}/PLAN.md
> Changes since last checkpoint: Run `git diff {last_checkpoint_sha}..HEAD`
>
> **CONTEXT ISOLATION: You do NOT see the executor's confidence score, the verifier's report or pass/fail conclusion, or the judge's recommendation. You evaluate from scratch using ONLY the acceptance criteria and the actual codebase state. This isolation is intentional -- it prevents anchoring bias and score inflation.**
>
> <must>
> 1. Read the acceptance criteria from PLAN.md. Extract every criterion with its verification command.
> 2. For EACH criterion, independently verify it against the codebase:
>    - Run the verification command specified in the criterion
>    - Read the actual file(s) to confirm the criterion is truly met (not just pattern-matched)
>    - Record: criterion text, verification command, command output, manual confirmation result, and any concerns
>    - **Execution-based criteria:** When a criterion specifies an execution command (compile, test, lint, build, script execution -- not grep), run the actual command using the Bash tool with a 60-second timeout and use the runtime output to evaluate the criterion. Do NOT substitute grep for an available execution command. Record command output, exit code, and runtime assessment in the scorecard. If a command crashes, throws an unhandled exception, or times out, classify it as a verification failure using the failure taxonomy (`compilation_failure`, `build_failure`, `lint_failure`, or `tool_failure`).
>    - **Test specification execution:** For each task, also run the generated test specification file (`.planning/phases/{phase}/tests/task-{id}.sh`) and use the test output as PRIMARY evidence for scoring. Test results carry more weight than grep output: a passing test gives higher confidence than a matching grep pattern. When test results and grep results disagree, test results determine the score. If no test specification file exists for a task, note it as a coverage gap in the scorecard.
> 3. **Behavioral criteria scoring (UI/mixed phases):** For criteria marked as behavioral (those requiring code tracing rather than grep), verification MUST involve reading the handler code and tracing the logic chain. Scoring rules for behavioral criteria:
>    - Score < 7.0 if the terminal behavior (the final action the handler performs) cannot be confirmed from code reading alone (e.g., handler calls an opaque function with no visible definition)
>    - Score < 5.0 if the traced logic CONTRADICTS the criterion (e.g., criterion says "opens event URL" but handler actually opens a hardcoded URL or different resource)
>    - Record the trace result (trigger -> intermediate calls -> terminal action) alongside each behavioral criterion score in the scorecard
>    - If a criterion has both a grep command AND a behavioral trace requirement, BOTH must pass for the criterion to score above 7.0
> 4. Run ALL verification commands from all criteria. An empty `commands_run` list will be rejected.
> 5. Check for side effects and regressions:
>    - Review the git diff for changes outside the scope of acceptance criteria
>    - Check for removed functionality, broken cross-references, or unintended modifications
>    - Record any side effects found
> 6. Assign a per-criterion score using DECIMAL PRECISION (x.x/10 format):
>    - 9.5-10.0: Criterion fully met with excellence, no concerns
>    - 8.0-9.4: Criterion met but with minor concerns (style, edge cases)
>    - 7.0-7.9: Criterion met with notable deficiencies
>    - 5.0-6.9: Criterion partially met, significant gaps remain
>    - 3.0-4.9: Criterion mostly unmet
>    - 0.0-2.9: Criterion not addressed or fundamentally wrong
> 7. Compute a weighted aggregate score:
>    - All criteria are weighted equally unless the plan specifies priority weights
>    - The aggregate is the arithmetic mean of per-criterion scores, rounded to one decimal place
>    - Provide explicit justification for each point deducted from 10.0
> 8. Write a detailed scorecard to `.planning/phases/{phase}/SCORECARD.md` containing:
>    - Per-criterion scores with evidence and justifications (include Test Results column showing test specification output when available)
>    - Test Coverage section showing: tasks with test specifications vs tasks total, assertions passed vs assertions total, and which tasks had only grep-based evidence
>    - Side effects analysis
>    - Aggregate score with deduction justifications
>    - Score calibration note (which band the score falls in and why)
> 9. Return structured JSON (see Return JSON below).
> </must>
>
> <should>
> 1. Record specific file:line evidence for each criterion evaluation
> 2. Note any acceptance criteria that are ambiguous or untestable
> 3. Compare the scope of changes against the plan scope -- flag both missing work and scope creep
> </should>
>
> <may>
> 1. Note potential improvements that would raise the score
> 2. Flag technical debt introduced by the changes
> </may>
>
> **CALIBRATION GUIDE (scores MUST follow this distribution):**
>
> - **9.5-10.0 (Excellence):** ALL criteria fully met with verification evidence. Zero concerns. Zero side effects. No scope creep. This score is RARE and requires evidence of exceptional quality.
> - **8.0-9.4 (Good with minor issues):** All criteria met, but with minor concerns: style issues, edge cases not covered, slight imprecision in implementation. Most well-executed phases land here.
> - **7.0-7.9 (Acceptable with real deficiencies):** Most criteria met, but real deficiencies exist that should be addressed. Something is genuinely missing or wrong, even if not critical.
> - **5.0-6.9 (Significant gaps):** Multiple criteria partially unmet. The work is incomplete or has meaningful quality issues. Not a failure, but clearly needs more work.
> - **3.0-4.9 (Major failures):** Multiple criteria unmet. The work has fundamental issues that prevent it from achieving the phase goal.
> - **0.0-2.9 (Not implemented):** The work does not address the phase goal in any meaningful way.
>
> **VISUAL QUALITY ASSESSMENT (UI phases with visual_testing config only):**
> When `project.visual_testing` is configured and the phase is a UI phase, check if visual testing screenshots exist in `{project.visual_testing.screenshot_dir}`. If they exist:
> - Read the screenshots using the Read tool (multimodal analysis)
> - Incorporate visual quality assessment into per-criterion scores
> - Visual issues reduce criterion scores by severity: minor (-0.5), major (-1.0), critical (-2.0)
> - If no screenshots exist, note "visual testing not performed" in the scorecard
> - Visual test results are supplementary evidence -- they enhance scoring precision but do not replace acceptance criteria verification
>
> **ANTI-INFLATION RULES:**
> - You MUST NOT default to 8.x or 9.x. Start from 5.0 (baseline) and ADD points based on evidence of criteria being met.
> - Every 0.5 points above 7.0 requires explicit justification in the scorecard.
> - If you cannot find file:line evidence that a criterion is met, it scores below 7.0 for that criterion.
> - Rounding is ALWAYS down (7.45 -> 7.4, not 7.5).
>
> Return JSON:
> ```json
> {
>   "alignment_score": <decimal x.x format, e.g., 7.3>,
>   "scorecard": [
>     {
>       "criterion": "criterion text",
>       "score": <decimal x.x>,
>       "max_score": 10.0,
>       "verification_command": "the command run",
>       "command_output": "first 200 chars of output",
>       "evidence": "file:line -- what was found",
>       "justification": "why this score",
>       "execution_result": {"command": "cmd", "exit_code": 0, "output": "first 200 chars"} | null
>     }
>   ],
>   "aggregate_justification": "explanation of how aggregate was computed and what deductions were made",
>   "side_effects": ["any side effects found"],
>   "commands_run": ["command -> result"],
>   "test_coverage": {"tasks_with_tests": 0, "tasks_total": 0, "assertions_passed": 0, "assertions_total": 0},
>   "score_band": "excellence|good|acceptable|significant_gaps|major_failures|not_implemented"
> }
> ```

**Read back:** ONLY the JSON result.

**Phase-runner validation:** Check the returned `alignment_score`. If it is an integer (no decimal point), reject the rating and re-spawn the rating agent with a reminder about decimal precision. Check `commands_run` -- if empty, reject as rubber-stamping.

<context_budget>
max_response_lines: 150
max_summary_lines: 5
enforcement: JSON return only -- phase-runner reads the JSON block
</context_budget>

---

### STEP 4.7: SCOPE-SPLIT DETECTION (conditional)

**Purpose:** Detect when phase scope is too large for a single agent and return a split request to the orchestrator instead of attempting execution that will exhaust context.

**When to check:** The phase-runner SHOULD evaluate scope at two points:
1. **After planning (STEP 2):** If the plan contains more than 5 complex tasks, or touches more than 10 files, consider splitting.
2. **During remediation:** If `remediation_feedback` contains more than 3 issues spanning 4+ different files, consider splitting.

**Split threshold guidance:**
- Remediation feedback > 3 issues AND issues span 4+ files: RECOMMEND split
- Plan contains > 5 complex tasks: RECOMMEND split
- Estimated file reads during execution > 10 unique files: RECOMMEND split
- The exact threshold is at the phase-runner's discretion. Priority: **Quality > Time > Tokens** -- spawning many sub-agents is preferred over context exhaustion.

**Action:** If scope exceeds threshold, the phase-runner returns immediately with `status: "split_request"` instead of proceeding to execution. The orchestrator handles spawning sub-phase-runners in parallel (see orchestrator Section 2.1).

**Split request return JSON:**
```json
{
  "phase": "{phase_id}",
  "status": "split_request",
  "alignment_score": null,
  "tasks_completed": "0/0",
  "tasks_failed": "0/0",
  "commit_shas": [],
  "automated_checks": {"compile": "n/a", "build": "n/a", "lint": "n/a"},
  "issues": [],
  "debug_attempts": 0,
  "replan_attempts": 0,
  "recommendation": "proceed",
  "summary": "Phase scope too large. Recommending split into {N} sub-phases.",
  "checkpoint_sha": null,
  "verification_duration_seconds": null,
  "evidence": {"files_checked": [], "commands_run": [], "git_diff_summary": ""},
  "split_details": {
    "reason": "why the phase needs splitting",
    "recommended_sub_phases": [
      {
        "sub_phase_id": "{phase_id}a",
        "name": "sub-phase name",
        "scope": "description of what this sub-phase covers",
        "issues": ["issue 1", "issue 2"],
        "estimated_complexity": "simple|medium|complex"
      }
    ],
    "total_sub_phases": N,
    "original_issue_count": N
  },
  "pipeline_steps": {
    "preflight": {"status": "pass", "agent_spawned": false},
    "triage": {"status": "full_pipeline", "agent_spawned": false, "pass_ratio": 0.0},
    "research": {"status": "completed|skipped", "agent_spawned": true|false},
    "plan": {"status": "completed|skipped", "agent_spawned": true|false},
    "plan_check": {"status": "skipped", "agent_spawned": false},
    "execute": {"status": "skipped", "agent_spawned": false},
    "verify": {"status": "skipped", "agent_spawned": false},
    "judge": {"status": "skipped", "agent_spawned": false},
    "rate": {"status": "skipped", "agent_spawned": false}
  }
}
```

**Note:** A split request is NOT a failure. The phase-runner is doing its job correctly by detecting scope that would cause context exhaustion. The orchestrator handles the split by spawning sub-phase-runners in parallel.

<context_budget>
max_response_lines: 20
max_summary_lines: 5
enforcement: Phase-runner performs this step directly -- no agent to budget
</context_budget>

---

### STEP 5: GATE DECISION

**Purpose:** YOU (the phase-runner) decide what happens next. This is your logic, not a subagent.

**Read:** The verify result (from STEP 4), the judge result (from STEP 4.5), and the rating result (from STEP 4.6).

**Decision tree:**

The `pass_threshold` is set by the orchestrator (default 9, 7 with `--lenient`). The phase-runner uses this threshold in its gate decision. If `pass_threshold` is not provided in the spawn prompt, default to 9.

```
IF automated_checks all pass
   AND alignment >= pass_threshold (default 9, 7 with --lenient)
   AND recommendation == "proceed":
     -> Log decision: "Phase {N} PASSED. Proceeding."
     -> Go to STEP 6 (RESULT)
     -> Return status: "completed"

IF automated_checks all pass
   AND alignment >= 7 AND alignment < pass_threshold
   AND recommendation == "proceed":
     -> Log decision: "Phase {N} completed at {alignment}/10 (threshold: {pass_threshold}). Returning to orchestrator for remediation decision."
     -> Go to STEP 6 (RESULT)
     -> Return status: "completed" (the orchestrator handles remediation cycles -- see orchestrator Section 5.1)

IF any automated_check fails OR recommendation == "debug":
     -> Log decision: "Phase {N} has failing checks. Entering debug loop."
     -> Go to STEP 5a (DEBUG)
     -> Max 3 debug attempts

IF alignment < 7 (and no automated failures):
     -> Log decision: "Phase {N} alignment too low ({score}). Re-planning."
     -> Go back to STEP 1 (RESEARCH) with tighter constraints
     -> Append to research prompt: "Previous attempt scored {alignment}/10. Issues: {issues}. Focus on: {missing}"
     -> Max 1 re-plan attempt per phase
     -> If second attempt also fails: return status "failed"

IF recommendation == "rollback":
     -> Log decision: "Phase {N} rollback recommended by judge. Reason: {reasoning}"
     -> Go to ROLLBACK (revert to last checkpoint)
     -> Return status "failed" with recommendation "rollback"

IF recommendation == "halt":
     -> Log decision: "Phase {N} HALTED by judge. Reason: {reasoning}"
     -> Go to ROLLBACK (revert to last checkpoint)
     -> Return status "failed" with recommendation "halt"

IF max retries exceeded (3 debug attempts OR 1 re-plan + 1 debug):
     -> Log decision: "Phase {N} max retries exceeded. Rolling back."
     -> Go to ROLLBACK
     -> Return status "failed" with recommendation "halt"
```

**Remediation mode:** When the phase-runner receives `remediation_feedback` and `remediation_cycle` > 0 from the orchestrator, it operates in remediation mode. In this mode:
- Skip research and planning (treat as `existing_plan: true`, `skip_research: true`)
- Read the `remediation_feedback` list of specific deficiencies
- Execute ONLY targeted tasks addressing the feedback items (not the full plan)
- Run verify and judge as normal
- The remediation mode is orchestrator-driven (Section 5.1 of orchestrator guide) -- the phase-runner's job is to fix the specific deficiencies identified, then return its result for the orchestrator to evaluate.

**ROLLBACK procedure:**

```bash
# Find the last checkpoint commit (provided by orchestrator)
LAST_GOOD_COMMIT={last_checkpoint_sha from inputs}

# Create a diagnostic branch before reverting
git branch autopilot-diagnostic-phase-{N}

# Revert to last good state (preserving history)
git revert --no-commit ${LAST_GOOD_COMMIT}..HEAD && git commit -m "rollback: revert to phase {N} checkpoint"
```

**CRITICAL: Never use `git reset --hard`. Use `git revert` to preserve history.**

<context_budget>
max_response_lines: 20
max_summary_lines: 5
enforcement: Phase-runner performs this step directly -- no agent to budget
</context_budget>

---

### STEP 5a: DEBUG (conditional)

**Purpose:** Fix failing automated checks or verification issues.

**Action:** Spawn `autopilot-debugger` agent via Task tool, run_in_background=false. The autopilot-debugger is the native debug agent for autopilot-cc, using scientific method debugging with failure taxonomy integration and learnings loop support. If `autopilot-debugger` is not available (e.g., not yet installed), fall back to `gsd-debugger` as a compatible alternative. The `/autopilot:debug` command provides standalone access to the same debugging methodology outside the pipeline.

**Prompt template:**

```
Debug phase {N}: {phase_name}.

Verification report at: .planning/phases/{phase}/VERIFICATION.md

Issues to fix:
{issues_list_from_verify_result}

Failing checks:
{automated_checks_that_failed}

<must>
1. Diagnose root cause of each failing issue
2. Fix the specific failures -- do NOT refactor unrelated code
3. Run compile and lint checks before committing any fix
4. Make atomic commits per fix
5. Return structured JSON with fix results (see Return JSON below)
</must>

<should>
1. Verify each fix resolves its target issue before moving to the next
2. Include root cause analysis in the response
3. Record file:line evidence for each fix
</should>

<may>
1. Note related issues discovered during debugging that are out of scope
</may>

<should>
4. Write trace file to .planning/phases/{phase}/debug-trace.jsonl (JSONL, schema: autopilot-schemas.md Section 6)
</should>

Mode: find_and_fix
symptoms_prefilled: true

**AUTOPILOT CONTEXT (you are in autopilot mode):**
- Your orchestrator is the phase-runner, NOT `/gsd:debug`. Do not wait for user input or checkpoints.
- STATE.md may not exist. Use context from this prompt instead.

Return JSON:
{
  "fixed": true|false,
  "changes": ["description of each fix"],
  "commits": ["sha1", "sha2"],
  "remaining_issues": ["anything still broken"],
  "failure_categories": [{"failure": "description", "category": "taxonomy_value from Section 2.5"}]
}
```

**Circuit breaker:** Track debug loop count internally. Rules:

```
debug_attempt_1: Spawn debugger with full issue list
debug_attempt_2: Spawn debugger with remaining_issues from attempt 1
debug_attempt_3: Spawn debugger with remaining_issues from attempt 2

If attempt 3 returns fixed=false OR remaining_issues is non-empty:
  -> STOP. Do NOT attempt a 4th debug.
  -> Return status "failed" with recommendation "halt"
```

**After fix:** Return to STEP 4 (VERIFY) to confirm the fix worked.

<context_budget>
max_response_lines: 200
max_summary_lines: 10
enforcement: JSON return only -- phase-runner reads the JSON block
</context_budget>

---

### STEP 6: COMPOSE RESULT

**Purpose:** Gather all data and compose the return JSON for the orchestrator.

**Actions (performed by YOU, the phase-runner -- NOT a subagent):**

1. **Record checkpoint commit:**
   ```bash
   CHECKPOINT_SHA=$(git rev-parse HEAD)
   ```

2. **Finalize TRACE.jsonl:** Ensure `TRACE.jsonl` in the phase directory is complete. Perform a final aggregation pass: check for any step trace files (`{step}-trace.jsonl`) not yet appended and add them. Write a final phase-runner span indicating phase completion:
   ```json
   {"timestamp": "ISO-8601", "phase_id": "{N}", "step": "phase_runner", "action": "decision", "input_summary": "Phase pipeline complete", "output_summary": "Status: {status}, alignment: {score}/10", "duration_ms": {total_phase_ms}, "status": "success|failure"}
   ```

3. **Gather result data:**
   - Collect commit SHAs from execution
   - Collect rating agent's alignment_score (decimal) and scorecard
   - Count debug and replan attempts
   - Summarize what was accomplished
   - **Compile evidence from executor summary and verifier results:**
     - `evidence.files_checked`: Merge executor's file:line references with verifier's criteria_results
     - `evidence.commands_run`: Merge executor's compile/lint/build results with verifier's automated checks
     - `evidence.git_diff_summary`: Run `git diff --stat {last_checkpoint_sha}..HEAD | tail -1`

4. **Compose return JSON** (see Section 4: Return Contract)

5. **Log progress:**
   ```
   Phase {N} complete. Alignment: {score}/10.
   ```

<context_budget>
max_response_lines: 20
max_summary_lines: 5
enforcement: Phase-runner performs this step directly -- no agent to budget
</context_budget>

---

## Section 2.5: Failure Taxonomy

Every failure identified by the verifier, judge, or debugger MUST be classified using one of the following categories. This taxonomy enables structured post-mortem analysis, cross-run trend detection, and targeted prevention rules.

| Category | Description | Example |
|----------|-------------|---------|
| `executor_incomplete` | Task marked complete but acceptance criteria not met | Executor wrote file but missed a required section |
| `executor_wrong_approach` | Executor took an approach that cannot satisfy requirements | Used wrong API, implemented wrong algorithm |
| `compilation_failure` | Code does not compile | Syntax error, missing import, type mismatch |
| `lint_failure` | Code fails lint checks | ESLint violations, formatting errors |
| `build_failure` | Production build fails | Webpack/Vite build error, missing dependency |
| `acceptance_criteria_unmet` | Specific acceptance criterion not satisfied (verifier-flagged) | Grep pattern not found in expected file |
| `scope_creep` | Code implemented that was not in spec or plan | Extra feature, unrequested refactoring |
| `context_exhaustion` | Agent ran out of context before completing | Task incomplete due to context window limit |
| `tool_failure` | External tool (git, npm, compiler) returned unexpected error | Git merge conflict, npm install failure |
| `coordination_failure` | Handoff between pipeline steps lost or corrupted data | Verifier received wrong file path, judge missing plan |

**Usage:** The verifier MUST include a `failure_categories` array in its return JSON when reporting failures. Each entry is `{"failure": "description", "category": "taxonomy_value"}`. The debugger MUST include `failure_categories` in its return JSON classifying what was fixed. The orchestrator warns on unclassified failures (check 12 in Section 5 of the orchestrator guide).

---

## Section 3: Error Handling

When errors occur, include them in your return JSON (using the contract from orchestrator Section 4). The orchestrator handles user-facing communication and diagnostic file creation.

### Preflight Failures

Return immediately with: `status: "failed"`, `alignment_score: null`, `recommendation: "halt"`, `issues: ["Preflight failed: {reason}"]`. All task counts zero, no commits.

### Human-Verify Checkpoint

**Autonomous resolution first (MUST):** Before returning `needs_human_verification`, the phase-runner MUST instruct the verifier to attempt autonomous resolution of checkpoint:human-verify task criteria through code analysis, build verification, and behavioral traces. The verifier reports its `autonomous_confidence` score. If `autonomous_confidence >= 6`, the phase-runner MUST return `status: "completed"` even if the plan had checkpoint:human-verify tasks -- the autonomous verification was sufficient.

**Case 1 -- Mixed plan (auto + human-verify tasks) where autonomous resolution FAILS (autonomous_confidence < 6):** Execute auto tasks, run verify/judge/rate, then return with: `status: "needs_human_verification"`, populated `alignment_score` (decimal, from rating agent), `automated_checks`, and `commit_shas` from the auto tasks. Include `human_verify_justification` describing what needs human approval AND `deferral_evidence` documenting what the verifier could not resolve autonomously.

**Case 2 -- Pure human-verify plan (zero auto tasks):** The phase-runner still attempts autonomous resolution through the verifier. If `autonomous_confidence >= 6`, return `status: "completed"`. If `autonomous_confidence < 6`, return `status: "needs_human_verification"` with `alignment_score: null`, empty `automated_checks` and `commit_shas`. Set execute pipeline_steps to `"skipped"`.

**REQUIRED when returning `needs_human_verification`:** The phase-runner MUST populate the `human_verify_justification` field in the return JSON. This field identifies the specific checkpoint task that triggered the human-verify status:
```json
"human_verify_justification": {
  "checkpoint_task_id": "XX-YY",
  "task_description": "description of the checkpoint task",
  "auto_tasks_passed": N,
  "auto_tasks_total": M
}
```
The orchestrator rejects any `needs_human_verification` return that lacks this field (see orchestrator Section 5, Check 13). Do NOT use generic justifications like "it's a UI phase" -- the justification must reference the specific task ID from the plan AND include the specific criteria the verifier could not resolve autonomously.

### Pipeline Failures

After exhausting retries, return with: `status: "failed"`, `recommendation: "halt"`, populated `debug_attempts` count, all issues listed chronologically in `issues` array (original failure + each debug attempt result). Include `diagnostic_branch` name if one was created.

**Note:** When the orchestrator receives a failed phase-runner return, it computes the remaining phases and provides the user with actionable restart guidance: `/clear` then `/autopilot {remaining_phases}`. The phase-runner does not need to output this guidance itself -- the orchestrator handles it (see orchestrator Section 5 gate logic).

### Context Exhaustion Handoff (CTXE-01)

When a phase-runner detects it is approaching context exhaustion (i.e., the agent is struggling to complete operations, responses are being truncated, or tool calls are failing due to context limits), it MUST write a partial-progress handoff file BEFORE returning. This preserves work already completed so the orchestrator can resume from this state instead of losing all progress.

**Handoff file:** Write to `.planning/phases/{phase}/HANDOFF.md`. Required fields: phase_id, tasks_completed, tasks_remaining, files_modified, last_checkpoint_sha.

```markdown
# Phase {N} Partial Progress Handoff

**Phase ID:** {phase_id}
**Reason:** Context exhaustion detected during {step_name}
**Timestamp:** {ISO-8601}
**Last Checkpoint SHA:** {last_checkpoint_sha}

## Tasks Completed
| Task ID | Status | Commit SHA | Files Modified |
|---------|--------|------------|----------------|
| {id} | COMPLETED | {sha} | {files} |

## Tasks Remaining
| Task ID | Description | Estimated Complexity |
|---------|-------------|---------------------|
| {id} | {description} | {simple|medium|complex} |

## Files Modified (partial list)
- {file_path}: {what was changed}

## Partial Progress State
- Current step: {step_name}
- Last successful operation: {description}
- Issues encountered: {list}
```

**Return JSON for context exhaustion:** Return with `status: "failed"`, `recommendation: "halt"`, and include `"issues": ["context_exhaustion: partial progress saved to HANDOFF.md"]`. The orchestrator receives this return, computes the remaining phases from the execution queue, and provides the user with actionable restart guidance:

```
Context getting full. {N} phases completed so far. To continue, run:
  /clear
  /autopilot {remaining_phases}
```

Where `{remaining_phases}` is dynamically computed from the incomplete phases in the current run. The orchestrator also detects the HANDOFF.md file on resume and uses it to scope a more targeted re-execution.

**Resume from handoff:** When the orchestrator detects a HANDOFF.md file in a phase directory during resume (Section 8), it reads the file to determine which tasks were completed and which remain. It re-spawns the phase-runner with `remediation_feedback` set to only the remaining tasks, effectively resuming from the handoff point rather than starting over.

### Post-Mortem Generation (OBSV-03, OBSV-04)

When the phase-runner is about to return `status: "failed"` (for any reason -- preflight failure, exhausted retries, rollback, or halt), it MUST generate a structured post-mortem file before returning.

**Post-mortem generation steps:**

1. **Determine root cause:** Identify the primary failure category from the failure taxonomy (Section 2.5). Use the verifier's `failure_categories` if available, otherwise classify based on the failure context:
   - Preflight failure → `tool_failure` or `coordination_failure`
   - Exhausted debug retries → use the debugger's `failure_categories` from the last attempt
   - Rollback by judge → use the judge's `concerns` to identify the category
   - If multiple categories apply, pick the one that appeared first chronologically

2. **Build timeline:** Extract events from `TRACE.jsonl` (if it exists) or reconstruct from step agent returns. Include: step start/complete events, failure detection, debug attempts, and their outcomes. Limit to 20 most relevant events.

3. **Collect evidence:** Merge `commands_run` from the verifier, `evidence` from the executor, and `changes` from the debugger into a single evidence block.

4. **Record attempted fixes:** For each debug attempt, record: attempt number, description, commit SHA (if any), what was resolved, and what remained.

5. **Write prevention rule:** A 1-2 sentence rule that, if followed by future executors or planners, would prevent this specific failure from recurring. Be specific -- not "write better code" but "when modifying protocol files, verify grep patterns match across all step agent prompts, not just the first one."

6. **Write the post-mortem file** to `.autopilot/diagnostics/phase-{N}-postmortem.json` using the schema defined in the schemas reference (Section 6). Ensure the `.autopilot/diagnostics/` directory exists before writing.

7. **Append prevention rule to learnings file (LRNG-01):** After writing the post-mortem, append the prevention rule to `.autopilot/learnings.md` so subsequent executors and planners benefit from this failure's lesson. If the file does not exist, create it with the header `# Learnings (current run)`. Append a structured entry:

   ```markdown
   ### Phase {N} failure -- {failure_category}
   **Prevention rule:** {prevention_rule_text}
   **Context:** Phase {N} ({phase_name}) failed with category `{failure_category}`. Recorded: {ISO-8601 timestamp}.
   ```

   This entry is consumed by the executor (pre-execution priming) and planner (task design) in subsequent phases within the same run. The file is pruned at run start (LRNG-03) so entries do not accumulate across runs.

**Example post-mortem path:** `.autopilot/diagnostics/phase-5-postmortem.json`

**This is a MUST-level instruction.** Every failed phase produces a post-mortem and a learnings entry. If the post-mortem or learnings write itself fails (e.g., permission error), log the error in the return JSON `issues` array and continue with the failure return.

### Rollback Reporting

If rollback was performed, add to return: `rollback_performed: true`, `rollback_from: "{sha}"`, `rollback_to: "{sha}"`. Set `recommendation: "rollback"`.

---

## Section 4: Return Contract

The return contract is defined in `__INSTALL_BASE__/autopilot/protocols/autopilot-orchestrator.md` Section 4. Return that exact JSON structure as the LAST thing in your response. Key points:

- `pipeline_steps` uses shape: `{"status": "pass|fail|completed|skipped", "agent_spawned": boolean}`
- `pipeline_steps.triage` should include `{"status": "full_pipeline|verify_only", "agent_spawned": false, "pass_ratio": 0.0-1.0}`
- `evidence` field is REQUIRED for completed phases (see orchestrator Section 4)
- `alignment_score` is the RATING AGENT's score (decimal x.x format, from STEP 4.6 -- not the verifier's or judge's)

---

## Quick Reference: Agent Spawn Table

| Step | Agent Type | Background? | Context Cost | Key Output |
|------|-----------|-------------|--------------|------------|
| 0 - Pre-flight | general-purpose | No | ~5 lines | JSON: all_clear |
| 0.5 - Triage | self (phase-runner) | No | ~5 lines | JSON: routing decision |
| 1 - Research | gsd-phase-researcher | Yes | ~10 lines | SUMMARY section |
| 2 - Plan | gsd-planner | No | ~10 lines | SUMMARY section |
| 2.5 - Plan Check | gsd-plan-checker | No | ~5 lines | JSON: pass/issues |
| 3 - Execute | gsd-executor | Yes | ~15 lines | SUMMARY section |
| 4 - Verify | gsd-verifier | No | ~10 lines | JSON: pass/alignment |
| 4.5 - Judge | general-purpose | No | ~5 lines | JSON: recommendation/concerns |
| 4.6 - Rate | general-purpose | No | ~5 lines | JSON: alignment_score (decimal)/scorecard |
| 5a - Debug | autopilot-debugger (fallback: gsd-debugger) | No | ~10 lines | JSON: fixed/remaining |

**Total per phase (happy path, full_pipeline):** ~80 lines of context consumed.
**Total per phase (happy path, verify_only):** ~30 lines of context consumed.
**Total per phase (with 1 debug):** ~95 lines.

---

## Quick Reference: Decision Gates

| Gate | Pass Condition | Fail Action |
|------|---------------|-------------|
| Pre-flight | all_clear = true | Return failed result immediately |
| Triage | Routing decision made (no failure possible) | Always produces a decision; routes to verify_only (>80% pass) or full_pipeline |
| Plan Check | pass = true, confidence >= 7 | Re-plan (max 3x), then return failed |
| Verify + Judge + Rate | checks pass, alignment (from rating agent, decimal) >= pass_threshold (default 9.0), recommendation = proceed | If alignment 7.0-8.9 and pass_threshold > 7.0: return to orchestrator for remediation (Section 5.1). If alignment < 7.0: re-plan (max 1x). Debug (max 3x) for check failures. |
| Circuit Breaker | debug attempts < 3 | Return failed, recommend halt |

---

## Summary

This playbook defines the phase-runner subagent's step-specific behavior: exact prompt templates for each pipeline step, verification methodology with concrete bash commands per phase type, re-plan and debug loop logic, rollback procedures, and error handling. The phase-runner's identity, pipeline structure, context rules, and quality mindset are in its agent definition. The return contract is defined in `__INSTALL_BASE__/autopilot/protocols/autopilot-orchestrator.md` Section 4.
