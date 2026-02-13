# Autopilot Orchestrator Guide

You are a loop. For each phase: spawn a phase-runner, wait for its JSON return, log the result, spawn the next one. You do NOT read code, research, or plans. You do NOT make decisions about the project. You do NOT ask the user questions during execution. If a phase-runner returns "failed", log it and move to the next phase (unless it is a dependency blocker). The user already told you what to do by invoking the command.

**Session hygiene rule:** Every time you output a suggestion to run `/autopilot` (in completion messages, failure messages, resume guidance, or any other user-facing text), you MUST prefix it with `/clear`. The format is always: `/clear` then `/autopilot <args>`. This ensures the next run starts with a fresh context window. There are ZERO exceptions to this rule.

---

## 1. Invocation

When the user types `/autopilot <phases>`:

1. **Resume check**: Read `.autopilot/state.json`. If it exists and `_meta.status` != `"completed"`, resume automatically (Section 8).
2. **Parse phases**: `"3-7"` = range, `"3"` = single, `"3,5,8"` = list, `"all"` = all incomplete, `"next"` = next one, `"--complete"` = batch completion mode (Section 1.1), `"--map"` or `"--map 3-7"` = context mapping mode (Section 1.2), `"--lenient"` = lenient mode (Section 1.3), `"--force"` or `"--force 3"` = force mode (Section 1.4), `"--quality"` or `"--quality 3"` = quality mode (Section 1.5), `"--gaps"` or `"--gaps 3"` = gaps mode (Section 1.6), `"--discuss"` or `"--discuss 3"` = discuss mode (Section 1.7), `"--visual"` = visual testing mode (Section 3, visual testing config). **Set `pass_threshold`:** If `--lenient` is present, set `pass_threshold = 7`. If `--quality` is present, set `pass_threshold = 9.5`. Otherwise, `pass_threshold = 9` (default). Store in `_meta.pass_threshold` in state.json. **Flag mutual exclusivity:** `--force` and `--quality` are mutually exclusive (error if both present). `--gaps` can combine with `--quality`. `--discuss` combines with any flag (always runs first). `--force` and `--gaps` are mutually exclusive (force redoes from scratch, gaps refines what exists).
3. **Read roadmap**: Find at `.planning/ROADMAP.md` (or project root). Extract phase names/goals for the requested range.
4. **Locate frozen spec**: Read `project.spec_paths` from `.planning/config.json` and check each path in order until one exists. Default fallback order: `.planning/REQUIREMENTS.md`, `.planning/PROJECT.md`, `.planning/ROADMAP.md`. Compute hash: `sha256sum <spec> | cut -d' ' -f1`.
5. **Immediate start**: Show a 2-line status and begin the loop. No confirmation. No preview. The user invoked the command -- that is the instruction to proceed.

```
Autopilot: Phases {range} | Spec: {path} ({hash_short}) | Model: {model}
Starting phase {first}...
```

6. **On start**: Create `.autopilot/` dir, write initial `state.json`, ensure `.autopilot/` is in `.gitignore`.
7. **Reset learnings file (LRNG-03)**: If `.autopilot/learnings.md` exists, delete it. Learnings are scoped to the current run and must not accumulate across runs to prevent context pollution. Log: "Learnings file reset for new run."

---

## 1.1 Batch Completion Mode (CMPL-01, CMPL-02, CMPL-03)

When the user passes `--complete` (e.g., `/autopilot --complete`), the orchestrator enters batch completion mode. The intent is "finish the project" -- the orchestrator determines what's left and runs to completion without requiring phase selection.

### Phase Selection (CMPL-01)

1. **Read roadmap**: Parse `.planning/ROADMAP.md`. Extract all phases with their IDs, names, and "Depends on" fields.
2. **Read state**: Read `.autopilot/state.json` (if it exists). Identify phases with `status == "completed"` from the current or any prior run.
3. **Identify outstanding phases**: All phases in the roadmap that are NOT marked as completed in `state.json` are candidates.
4. **Build dependency graph**: For each phase, parse its "Depends on" field from the roadmap. The format is: `Depends on: Phase N` or `Depends on: Phase N, Phase M` or `Depends on: Phase N (description)`. Extract the phase number(s). Build a directed acyclic graph (DAG) where edges point from dependency to dependent.
5. **Topological sort**: Sort the outstanding phases in dependency order using topological sort. Phases with no dependencies come first. Phases at the same dependency level can be in roadmap order.
6. **Log the execution plan**: Log: "Batch completion: {N} outstanding phases identified. Execution order: {phase_list}."

### Skip Logging (CMPL-02)

When `--complete` encounters an already-completed phase during execution:
- Log: "Phase {N}: completed in run {run_id} at {timestamp}, skipping."
- Append a `phase_skipped` event to the event_log with reason: `"already_completed"` and the original run timestamp.
- Do NOT re-run completed phases. The phase was verified in its original run with passing status.

### Dependency-Aware Failure Handling (CMPL-03)

When `--complete` encounters a failed phase:

```
phase_failed(N):
  1. Log: "Phase {N} failed. Checking dependency impact."
  2. blocked_phases = all phases that depend on N (directly or transitively)
  3. For each blocked phase:
     - Remove from execution queue
     - Log: "Phase {B}: blocked by Phase {N} failure, skipping."
     - Append phase_skipped event with reason: "blocked_by_phase_{N}"
  4. independent_phases = remaining phases in execution queue
  5. If independent_phases is empty:
     - Log: "No executable independent phases remain. Halting."
     - Proceed to completion report.
  6. Else:
     - Log: "{M} independent phases remain. Continuing execution."
     - Continue with next independent phase.
```

The orchestrator does not halt the entire run for a single failure in `--complete` mode. It maximizes progress by continuing with all phases that are not blocked by the failure. Only when zero executable phases remain does execution stop.

### Combining --complete with Other Flags

- `--complete --sequential`: Runs all outstanding phases sequentially (already the default behavior)
- `--complete --checkpoint-every N`: Pauses for human review every N phases
- `--complete --lenient`: Runs all outstanding phases with the relaxed 7/10 quality threshold instead of the default 9/10
- `--complete --map`: Runs context mapping first on all outstanding phases, then executes (Phase 9)

---

## 1.2 Context Mapping Mode (CMAP-01, CMAP-02, CMAP-03, CMAP-05)

When the user passes `--map` (e.g., `/autopilot --map`, `/autopilot --map 3-7`), the orchestrator enters context mapping mode. The intent is "audit whether my phases are ready for autonomous execution" -- the orchestrator evaluates each target phase's input quality and gathers missing information from the user.

### Phase Selection

1. **Parse phase range**: If a range is provided (`--map 3-7`), use those phases. If no range, use all outstanding phases (same selection logic as `--complete`).
2. **Read roadmap**: Extract phase goals, requirements, success criteria, and "Depends on" fields for each target phase.
3. **Read existing artifacts**: For each target phase, check for existing PLAN.md, RESEARCH.md, and any prior context-map entries in `.autopilot/context-map.json`.

### Context Sufficiency Scoring (CMAP-01)

For each target phase, compute a context sufficiency score (1-10) based on:

| Factor | Weight | Scoring |
|--------|--------|---------|
| Success criteria specificity | High | 9-10: All criteria have verification commands. 5-6: Some vague. 1-2: No criteria or all prose-only |
| Requirement detail level | High | 9-10: Requirements are specific and actionable. 5-6: Requirements exist but underspecified. 1-2: No requirements or stub/TBD |
| Project documentation coverage | Medium | 9-10: PROJECT.md covers relevant domain. 5-6: Partial coverage. 1-2: No project docs for this domain |
| Dependency status | Low | 10: All dependencies completed. 5: Some dependencies pending. 1: Critical dependency missing |

**Scoring algorithm:**
```
score = 0
criteria_score = assess_criteria_specificity(phase)   // 0-10
requirements_score = assess_requirement_detail(phase)  // 0-10
docs_score = assess_documentation_coverage(phase)      // 0-10
dependency_score = assess_dependency_status(phase)     // 0-10

score = (criteria_score * 0.35) + (requirements_score * 0.35) + (docs_score * 0.15) + (dependency_score * 0.15)
round to nearest integer
```

**Quick heuristics for scoring (without spawning an agent):**
- **Criteria specificity**: Count verification commands (`grep`, `test -f`, command output checks) in success criteria. All have commands = 9-10, some = 5-7, none = 1-3.
- **Requirement detail**: Check if requirement IDs are mapped to the phase in the frozen spec. Mapped + specific = 9-10, mapped + vague = 5-7, unmapped or TBD = 1-3.
- **Documentation**: Check if `.planning/PROJECT.md` exists and covers the domain. Exists + relevant = 8-10, exists + partial = 5-7, missing = 1-4.
- **Dependencies**: Check `state.json` or EXECUTION-LOG.md for dependency status. All met = 10, some pending = 5, critical missing = 1.

If a phase's goal is a stub (contains "[To be planned]", "TBD", or is empty), assign score 1 immediately.

Log per phase: "Phase {N}: context sufficiency {score}/10 ({criteria_score} criteria, {requirements_score} requirements, {docs_score} docs, {dependency_score} deps)"

### Questioning Agent (CMAP-02)

For any phase scoring below 8 on context sufficiency, spawn a general-purpose subagent to generate targeted questions.

**Questioning agent prompt:**

> You are a context-gathering agent for autopilot phase {N}: {phase_name}.
>
> Phase goal: {goal}
> Requirements: {requirements_list}
> Success criteria: {success_criteria}
> Current context sufficiency score: {score}/10
> Score breakdown: criteria={criteria_score}, requirements={requirements_score}, docs={docs_score}, deps={dependency_score}
>
> <must>
> 1. Read the phase's roadmap entry, requirements from the frozen spec at {spec_path}, and any existing research/plans in the phase directory
> 2. Read PROJECT.md (if it exists) for project context
> 3. Identify the specific gaps causing the low score -- what information is missing or vague?
> 4. Generate 2-5 concrete, specific questions that, when answered, would move the phase's context sufficiency score above 8
> 5. Each question must target a specific gap (not vague "tell me more" questions)
> 6. Return structured JSON (see Return JSON below)
> </must>
>
> **Question categories:**
> - `build_config`: Missing build/compile/lint commands or project setup
> - `architecture`: Unclear system architecture or component relationships
> - `requirements`: Ambiguous or incomplete requirements
> - `criteria`: Missing or vague success criteria
> - `dependencies`: Unclear external dependencies or integrations
> - `domain`: Missing domain knowledge needed for the phase
>
> **Good questions:** "What build command does this project use?", "Which authentication method should Phase 5 implement (OAuth, JWT, session)?", "What is the expected response format for the /api/users endpoint?"
> **Bad questions:** "Tell me more about the project", "What should this phase do?", "Is everything clear?"
>
> Return JSON:
> ```json
> {
>   "phase_id": "{N}",
>   "current_score": N,
>   "questions": [
>     {
>       "question": "specific question text",
>       "category": "build_config|architecture|requirements|criteria|dependencies|domain",
>       "why_needed": "1-sentence explanation of what gap this fills"
>     }
>   ],
>   "estimated_score_after": N
> }
> ```

### Batching Questions and Recording Answers (CMAP-03)

After all questioning agents return:

1. **Batch all questions**: Collect questions from all phases into a single structured presentation:
   ```
   Context Mapping: {N} phases need additional information

   ## Phase {id}: {name} (score: {score}/10)
   1. {question_1} [{category}]
   2. {question_2} [{category}]

   ## Phase {id}: {name} (score: {score}/10)
   1. {question_1} [{category}]
   ...

   Please answer all questions above. Type your answers inline (e.g., "Phase 3, Q1: ...").
   ```

2. **Collect answers**: Present to the user and wait for responses. Parse user answers by phase and question number.

3. **Record to `.autopilot/context-map.json`**: Write (or update) the context map file. If the file already exists, merge new entries with existing ones (do not overwrite prior answers for other phases).

   Schema:
   ```json
   {
     "version": "1.0",
     "last_updated": "ISO-8601",
     "phases": {
       "{phase_id}": {
         "phase_name": "string",
         "context_score": N,
         "questions": [
           {
             "question": "string",
             "category": "string",
             "answer": "user's answer text",
             "answered_at": "ISO-8601"
           }
         ],
         "mapped_at": "ISO-8601"
       }
     }
   }
   ```

4. **Re-score**: After recording answers, re-compute context sufficiency scores. Phases with answered questions typically gain 2-4 points. Log updated scores.

5. **Summary**: Output a summary showing before/after scores for each phase.

### Combining --map with Other Flags

- `--map` alone: Audit and question only. Does NOT execute phases.
- `--map 3-7`: Audit only phases 3-7.
- `--complete --map`: Run context mapping on all outstanding phases first, then proceed with batch completion. The `--map` step runs before any phase-runner is spawned.
- `--map --lenient`: Map first, then if combined with execution, use the relaxed 7/10 threshold instead of the default 9/10.

---

## 1.3 Lenient Mode (CENF-01, CENF-04)

When the user passes `--lenient` (e.g., `/autopilot 3-7 --lenient`, `/autopilot --complete --lenient`), the orchestrator lowers the alignment pass threshold from the default 9/10 to 7/10. This is the original threshold from before Phase 10.

### Behavior

1. **Set pass_threshold:** At invocation, set `pass_threshold = 7` (stored in `_meta.pass_threshold` in state.json). Without `--lenient`, `pass_threshold = 9` (the default).
2. **Gate logic:** The gate logic in Section 5 uses `pass_threshold` instead of a hardcoded value. Phases scoring >= `pass_threshold` pass immediately.
3. **No remediation cycles:** When `--lenient` is active, phases scoring 7-8 pass immediately without entering the remediation cycle (Section 5.1). The orchestrator does NOT re-spawn phase-runners for scores between 7 and 8.
4. **Diagnostic files still generated:** Even in lenient mode, any phase completing below 9/10 still produces a diagnostic file at `.autopilot/diagnostics/phase-{N}-confidence.md` (CENF-02). The diagnostic file is generated regardless of `--lenient` status -- the flag only affects whether remediation cycles run.

### Combining --lenient with Other Flags

- `--lenient --complete`: All outstanding phases use 7/10 bar. No remediation cycles.
- `--lenient --map`: Map runs first, then execution uses 7/10 threshold.
- `--lenient --sequential`: Forces sequential execution with 7/10 threshold.
- `--lenient --checkpoint-every N`: Pauses every N phases with 7/10 threshold.

---

## 1.4 Force Mode

When the user passes `--force` (e.g., `/autopilot --force 3`, `/autopilot --force`), the orchestrator re-executes completed phases from scratch through the full pipeline (research -> plan -> execute -> verify -> judge -> rate), regardless of their current score. The intent is "redo it even if it's done."

### Phase Selection

1. **If phase number specified** (`--force 3`): Target that specific phase. It MUST have `status == "completed"` in `state.json`. If the phase is not completed, log error: "Phase {N} is not completed (status: {status}). --force only applies to completed phases." and halt.
2. **If no phase number** (`--force`): Target ALL completed phases from `state.json`. Execute them in the order they appear in the roadmap.

### Execution Behavior

1. **Preserve existing commits:** Do NOT revert or rollback previous phase work. New work layers on top of existing commits.
2. **Full pipeline:** Set `existing_plan: false`, `skip_research: false` for each target phase. The phase-runner runs the complete pipeline: research -> plan -> plan-check -> execute -> verify -> judge -> rate.
3. **Score history:** Before re-execution, record the current score in `phases.{N}.score_history` array (see Section 7). After re-execution, the new score replaces `alignment_score` and the old score is preserved in history.
4. **Standard pass_threshold:** Force mode uses the default pass_threshold (9, or 7 with `--lenient`). It does not change the quality bar -- it just re-runs the work.

### Combining --force with Other Flags

- `--force --lenient`: Re-run phases with 7/10 threshold.
- `--force --discuss`: Discussion runs first per phase, then full pipeline re-execution.
- `--force --quality`: **ERROR** -- mutually exclusive. Force redoes from scratch; quality refines what exists. Log: "Cannot combine --force (redo from scratch) with --quality (refine existing). Use one or the other."
- `--force --gaps`: **ERROR** -- mutually exclusive. Force redoes from scratch; gaps targets specific deficiencies.
- `--force --complete`: **ERROR** -- force targets completed phases, complete targets incomplete phases. Incompatible intent.

---

## 1.5 Quality Mode

When the user passes `--quality` (e.g., `/autopilot --quality 3`, `/autopilot --quality`), the orchestrator targets a 9.5/10 alignment score. For unexecuted phases, it runs the standard pipeline with the elevated 9.5 threshold. For already-completed phases below 9.5, it enters remediation loops. The intent is "don't stop until it's good enough."

### Phase Selection

1. **If phase number specified** (`--quality 3`): Target that specific phase.
   - If `status == "completed"` with `alignment_score >= 9.5`: skip. Log: "Phase {N}: already at {score}/10 (>= 9.5 target). Skipping."
   - If `status == "completed"` with `alignment_score < 9.5`: enter remediation loop (below).
   - If phase is not yet completed (no status or status != "completed"): run the standard pipeline (Section 2) with `pass_threshold = 9.5`. The elevated threshold ensures the phase is held to quality standards on its first run. If the first run scores below 9.5, enter remediation loop automatically.
2. **If no phase number** (`--quality`): Target ALL phases that need work — both completed phases with `alignment_score` below 9.5 AND incomplete phases. Run incomplete phases through the standard pipeline first (with 9.5 threshold), then remediate completed-but-below-target phases.

### Remediation Loop

Uses the existing remediation infrastructure (CENF-01, Section 5.1) but with modified parameters:

```
quality_threshold = 9.5
max_quality_cycles = 3
quality_cycle = 0
current_score = phases.{N}.alignment_score from state.json

while current_score < quality_threshold AND quality_cycle < max_quality_cycles:
  quality_cycle += 1
  log: "Phase {N}: quality remediation cycle {quality_cycle}/3. Current: {current_score}/10, target: 9.5/10."

  extract targeted_feedback from:
    - rating agent scorecard (per-criterion deductions from last run)
    - judge concerns from last run
    - diagnostic file "Path to 9.0/10" items
    - for scores already >= 9.0: identify specific 0.1-0.5 point deductions to address

  record old score in score_history array
  re-spawn phase-runner with:
    existing_plan: true
    skip_research: true
    remediation_feedback: targeted_feedback
    remediation_cycle: {quality_cycle}
    pass_threshold: 9.5

  parse new return JSON
  new_score = new alignment_score

  if new_score >= quality_threshold:
    log: "Phase {N}: quality target reached. Score: {new_score}/10."
    break
  else if new_score <= current_score:
    log: "Phase {N}: no improvement ({current_score} -> {new_score}). Stopping quality remediation."
    break
  current_score = new_score

if current_score < quality_threshold:
  log: "Phase {N}: quality remediation exhausted ({quality_cycle} cycles). Final score: {current_score}/10. Remaining gaps documented in diagnostic file."
  // Do NOT mark phase as failed. Report current score and remaining gaps.
```

### Exhaustion Behavior

When `--quality` exhausts its 3-cycle budget without reaching 9.5/10:
- Report the current score and remaining gaps
- Generate/update diagnostic file at `.autopilot/diagnostics/phase-{N}-confidence.md`
- Do NOT mark the phase as failed
- Do NOT set `force_incomplete: true` (that is for standard remediation under CENF-03)
- Set `phases.{N}.quality_exhausted: true` in state.json
- Log: "Quality target 9.5/10 not reached after {cycles} cycles. Current: {score}/10. See diagnostic file for remaining gaps."

### Combining --quality with Other Flags

- `--quality --gaps`: Quality runs first (targeting 9.5), then gaps runs on any phases that reached 9.5 but could go higher. The combined flow: quality loop to 9.5 -> if reached, gaps loop toward 10.0.
- `--quality --discuss`: Discussion runs first, then quality remediation.
- `--quality --lenient`: **No effect** -- `--quality` overrides pass_threshold to 9.5 regardless of `--lenient`.
- `--quality --force`: **ERROR** -- mutually exclusive (see Section 1.4).
- `--quality --complete`: Quality threshold applies to the batch completion run. All incomplete phases execute with `pass_threshold = 9.5`, and any that score below 9.5 enter remediation loops.

---

## 1.6 Gaps Mode

When the user passes `--gaps` (e.g., `/autopilot --gaps 3`, `/autopilot --gaps`), the orchestrator analyzes the specific deficiencies preventing a phase from reaching 10/10, then executes micro-targeted fixes working toward 9.5+/10. The intent is "close the remaining gap to perfect."

### Phase Selection

1. **If phase number specified** (`--gaps 3`): Target that specific phase. It MUST have `status == "completed"` in `state.json`.
2. **If no phase number** (`--gaps`): Target ALL completed phases with `alignment_score` below 9.5.
3. **Already near-perfect:** If a phase has `alignment_score >= 9.8`, skip it. Log: "Phase {N}: already at {score}/10 (>= 9.8). Negligible gap remaining. Skipping."

### Gap Analysis

Before executing fixes, the orchestrator performs gap analysis. Sources are tried in priority order -- the orchestrator uses the best available evidence:

1. **Primary source -- Rating scorecard:** Read `.planning/phases/{phase}/SCORECARD.md` (from rating agent, available for phases that have been rated). For each criterion scoring below 9.5 in the scorecard, create a deficiency entry.
2. **Secondary source -- Diagnostic file:** Read `.autopilot/diagnostics/phase-{N}-confidence.md` (if exists). Use the "path to 9/10" section and judge concerns to identify deficiencies.
3. **Fallback source -- Verification and judge artifacts:** When neither SCORECARD.md nor the diagnostic file exists (e.g., pre-Phase-15 phases that lack a rating agent), derive the gap analysis from:
   - The judge's `concerns` array and `verifier_missed` items from `.planning/phases/{phase}/JUDGE-REPORT.md`
   - The verifier's `criteria_results` (any criterion with status "failed" or noted concerns) from `.planning/phases/{phase}/VERIFICATION.md`
   - The phase-runner's return JSON `issues` array from `state.json`

   Log: "SCORECARD.md not available for phase {N}. Deriving gap analysis from judge concerns and verifier criteria results."

4. **Extract deficiency list:** For each identified deficiency (from whichever source was used), create a deficiency entry:
   ```json
   {
     "criterion": "criterion text",
     "current_score": 8.2,
     "target_score": 9.5,
     "deficiency": "specific description of what is missing or wrong",
     "target_file": "path/to/file",
     "expected_impact": "fixing this would address X deduction",
     "source": "scorecard|diagnostic|judge_report|verification"
   }
   ```
5. **Order by impact:** Sort deficiencies by `(target_score - current_score)` descending -- fix the biggest gaps first. When scores are not available from the source (e.g., judge concerns do not have numeric scores), estimate impact as high/medium/low and sort high first.

### Micro-Targeted Fix Loop

```
gap_threshold = 9.5
max_gap_iterations = 5
gap_iteration = 0
current_score = phases.{N}.alignment_score from state.json
remaining_deficiencies = ordered deficiency list from gap analysis

while current_score < gap_threshold AND gap_iteration < max_gap_iterations AND remaining_deficiencies is not empty:
  gap_iteration += 1
  current_deficiency = remaining_deficiencies.shift()  // take first (highest impact)

  log: "Phase {N}: gap fix iteration {gap_iteration}/5. Targeting: {current_deficiency.criterion} ({current_deficiency.current_score}/10)."

  record old score in score_history array
  re-spawn phase-runner with:
    existing_plan: true
    skip_research: true
    remediation_feedback: [current_deficiency]  // single deficiency
    remediation_cycle: {gap_iteration}
    pass_threshold: {gap_threshold}

  parse new return JSON
  new_score = new alignment_score

  if new_score >= gap_threshold:
    log: "Phase {N}: gap target reached. Score: {new_score}/10."
    break
  else if new_score <= current_score:
    log: "Phase {N}: no improvement from gap fix ({current_score} -> {new_score}). Trying next deficiency."
    // Continue to next deficiency even if this one didn't help
  current_score = new_score

if current_score < gap_threshold:
  log: "Phase {N}: gap remediation exhausted ({gap_iteration} iterations). Final score: {current_score}/10."
  // Do NOT mark phase as failed. Report current score and remaining gaps.
```

### Exhaustion Behavior

When `--gaps` exhausts its 5-iteration budget without reaching 9.5+/10:
- Report the current score, deficiencies addressed, and remaining deficiencies
- Generate/update diagnostic file
- Do NOT mark the phase as failed
- Set `phases.{N}.gaps_exhausted: true` in state.json
- Log: "Gap target 9.5+/10 not reached after {iterations} iterations. Current: {score}/10. {remaining} deficiencies remain."

### Combining --gaps with Other Flags

- `--gaps --quality`: See Section 1.5. Quality runs first to 9.5, then gaps refines further.
- `--gaps --discuss`: Discussion runs first, then gap analysis and fixes.
- `--gaps --lenient`: **No effect** -- `--gaps` targets 9.5+ regardless.
- `--gaps --force`: **ERROR** -- mutually exclusive (see Section 1.4).
- `--gaps --complete`: **ERROR** -- gaps targets completed phases, complete targets incomplete phases.

---

## 1.7 Discuss Mode

When the user passes `--discuss` (e.g., `/autopilot --discuss 3`, `/autopilot --discuss 3-7`), the orchestrator runs a conversational discussion session per target phase BEFORE any execution begins. The intent is "let's talk first so the phase-runner has richer context." The discussion follows a gray-area probing pattern: identify domain-specific ambiguities, let the user choose which areas to discuss, then deep-dive each selected area with focused questions.

### Phase Selection

1. **If phase number/range specified** (`--discuss 3`, `--discuss 3-7`): Target those phases.
2. **If no phase number** (`--discuss`): Target ALL phases in the current execution scope (phases about to be run).

### Step 1: Gray Area Analysis Agent

For each target phase, spawn a general-purpose subagent to identify discussion-worthy gray areas:

> You are a gray area analysis agent for autopilot phase {N}: {phase_name}.
>
> Phase goal: {goal}
> Requirements: {requirements_list}
> Success criteria: {success_criteria}
> Existing research: {path to RESEARCH.md if exists, "none" otherwise}
> Existing plan: {path to PLAN.md if exists, "none" otherwise}
>
> <must>
> 1. Read the phase's roadmap entry and requirements from the frozen spec at {spec_path}
> 2. Read any existing research or plan files for this phase
> 3. Determine the phase's domain by analyzing what kind of thing it builds:
>    - Something users SEE (UI) -- layout, density, interactions, visual states matter
>    - Something users CALL (API) -- interface contracts, responses, errors, auth matter
>    - Something users RUN (CLI/tool) -- output format, flags, modes, error handling matter
>    - Something users READ (docs/config) -- structure, tone, depth, flow matter
>    - Something being ORGANIZED (system/architecture) -- criteria, grouping, naming, exceptions matter
> 4. Generate 3-5 domain-specific gray areas -- concrete implementation decisions the user should weigh in on, NOT generic categories. Each gray area should represent a decision that would change the outcome.
> 5. Each gray area should include 2-3 sample questions that would be asked during the deep-dive
> 6. Return structured JSON (see Return JSON below)
> </must>
>
> **Good gray areas (domain-specific):**
> - For a "Post Feed" phase: "Layout style -- cards vs timeline vs grid? Information density?"
> - For a "CLI backup tool" phase: "Flag design -- short flags, long flags, or both? Required vs optional?"
> - For a "Plan Quality Gates" phase: "Prose-only criteria handling -- auto-convert to grep checks or reject outright?"
>
> **Bad gray areas (generic):**
> - "UI design" (too broad)
> - "Error handling" (not phase-specific)
> - "What should this phase do?" (that's the roadmap's job)
>
> **Scope guardrail:** Gray areas must clarify HOW to implement what's already scoped, never WHETHER to add new capabilities. If a gray area would expand the phase boundary, exclude it.
>
> Return JSON:
> ```json
> {
>   "phase_id": "{N}",
>   "domain": "SEE|CALL|RUN|READ|ORGANIZE",
>   "domain_description": "1-sentence description of what this phase builds",
>   "gray_areas": [
>     {
>       "area": "specific area name",
>       "description": "1-sentence description of the ambiguity",
>       "sample_questions": ["question 1", "question 2"]
>     }
>   ]
> }
> ```

### Step 2: Present Gray Areas for User Selection

After the gray area analysis agent returns, present the results to the user for selection. The user chooses which areas to discuss -- they are not forced to answer everything.

For each target phase, present:

```
Pre-Execution Discussion: Phase {N} -- {phase_name}

Domain: {domain_description}
We'll clarify HOW to implement this. (New capabilities belong in other phases.)

Which areas do you want to discuss?

1. {gray_area_1.area} -- {gray_area_1.description}
2. {gray_area_2.area} -- {gray_area_2.description}
3. {gray_area_3.area} -- {gray_area_3.description}
[4. {gray_area_4.area} -- {gray_area_4.description}]

(Enter numbers separated by commas, e.g., "1, 3" -- or "all" to discuss everything)
```

Wait for user response. Parse selected area numbers.

### Step 3: Per-Area Conversational Probing

For each selected area, conduct a focused conversational deep-dive. Present 3-4 questions per area, one area at a time.

```
for each selected_area:
  1. Announce the area:
     "Let's talk about {area.area}."

  2. Present 3-4 focused questions for this area:
     "## {area.area}
      1. {question_1}
      2. {question_2}
      3. {question_3}
      [4. {question_4}]

      Answer inline (e.g., 'Q1: ..., Q2: ...')."

  3. Record the user's answers.

  4. After answers received, offer depth control:
     "More questions about {area.area}, or move to next area?"

     If "more": Generate 2-3 follow-up questions based on the user's answers.
                 Present and record. Offer depth control again.
     If "next": Proceed to next selected area.
```

After all selected areas are discussed:
```
"That covers {list of discussed areas}. Ready to create context?"
```

### Step 4: Write Discussion Output

Write discussion output to TWO locations for backward compatibility:

**4a. Write CONTEXT.md to phase directory:**

Write to `.planning/phases/{phase}/CONTEXT.md`:

```markdown
# Phase {N}: {phase_name} - Context

**Gathered:** {date}
**Status:** Ready for planning

## Phase Boundary

{domain_description} -- the scope anchor from the roadmap.

## Implementation Decisions

### {Area 1 that was discussed}
- {Decision or preference captured from user answers}
- {Another decision if applicable}

### {Area 2 that was discussed}
- {Decision or preference captured}

### Claude's Discretion
{Areas where user said "you decide" or deferred to Claude -- note that Claude has flexibility here}

## Specific Ideas

{Any particular references, examples, or "I want it like X" moments from discussion}

{If none: "No specific requirements -- open to standard approaches"}

## Deferred Ideas

{Ideas that came up during discussion but belong in other phases. Captured so they are not lost.}

{If none: "None -- discussion stayed within phase scope"}
```

**4b. Write discuss-context.json (backward compatibility):**

Also write to `.autopilot/discuss-context.json` (same schema as before, for backward compatibility with phase-runners that read this file):

```json
{
  "version": "1.0",
  "last_updated": "ISO-8601",
  "phases": {
    "{phase_id}": {
      "phase_name": "string",
      "gray_areas_discussed": ["area 1", "area 2"],
      "questions": [
        {
          "question": "string",
          "area": "which gray area this belongs to",
          "category": "string",
          "answer": "user's answer text",
          "answered_at": "ISO-8601"
        }
      ],
      "context_md_path": ".planning/phases/{phase}/CONTEXT.md",
      "discussed_at": "ISO-8601"
    }
  }
}
```

### Step 5: Inject into Phase-Runner

When spawning the phase-runner for a discussed phase, add to the spawn prompt:

> **Discussion context:** The user participated in a pre-execution discussion for this phase. Structured decisions are at `.planning/phases/{phase}/CONTEXT.md` (primary) and `.autopilot/discuss-context.json` (supplementary Q&A). The phase-runner MUST read CONTEXT.md during research and incorporate the user's decisions into planning and execution. CONTEXT.md decisions take priority over any conflicting assumptions.

### Scope Guardrail

During the conversational probing (Step 3), if the user suggests a new capability that is outside the phase boundary:

```
"{Feature} sounds like a new capability -- that belongs in its own phase.
I'll note it in Deferred Ideas so it's not lost.

Back to {current area}: {return to current question}"
```

Track deferred ideas internally and include them in the Deferred Ideas section of CONTEXT.md.

### Standalone --discuss (No Other Execution Flags)

When `--discuss` is used WITHOUT `--force`, `--quality`, or `--gaps` (e.g., `/autopilot --discuss 3-7`), the orchestrator runs the discussion session for the specified phases and then proceeds with normal execution of those phases. The discussion context (CONTEXT.md and discuss-context.json) is injected into each phase-runner's spawn prompt. When no phase range is specified (e.g., `/autopilot --discuss`), it applies to all phases in the current execution scope (the phases about to be run, determined by the accompanying phase range argument or all outstanding phases if none given).

### Combining --discuss with Other Flags

`--discuss` ALWAYS runs first, before any other flag's behavior:

- `--discuss 3-7`: Discuss phases 3-7, then execute them normally.
- `--discuss --force 3`: Discuss phase 3, then re-execute from scratch.
- `--discuss --quality 3`: Discuss phase 3, then run quality remediation.
- `--discuss --gaps 3`: Discuss phase 3, then run gap analysis and fixes.
- `--discuss --complete`: Discuss all outstanding phases, then run batch completion.

---

## 2. The Loop

For each phase in the target range:

```
for each phase in target_phases:
  pre-spawn check (auto-skip if already verified)
  generate/refresh repo-map (Section 2.2)
  spawn phase-runner(phase) → wait for JSON return
  if return.status == "completed": log, next phase
  if return.status == "needs_human_verification": log, skip to next phase (come back later)
  if return.status == "split_request": handle scope split (Section 2.1)
  if return.status == "failed": log diagnostic (postmortem at .autopilot/diagnostics/phase-{N}-postmortem.json), continue to next phase if independent, halt if dependent
```

That is the entire loop. No gates, no extra validation, no asking.

### Scope Splitting (Section 2.1)

When a phase-runner returns `status: "split_request"`, the phase is too large for a single agent to execute within its context budget. The phase-runner has analyzed the work scope and recommends splitting into sub-phases. This is NOT a failure -- the phase-runner is doing its job correctly by detecting scope that would cause context exhaustion.

**Split handling protocol:**

```
on split_request(phase_N, split_details):
  1. Log: "Phase {N} too large ({split_details.reason}). Splitting into {split_details.total_sub_phases} sub-phases, launching in parallel..."
  2. For each sub_phase in split_details.recommended_sub_phases:
     - Create sub-phase ID: "{phase_id}{letter}" (e.g., "20a", "20b", "20c")
     - Spawn phase-runner with:
       - phase_id: sub_phase.sub_phase_id
       - phase_name: sub_phase.name
       - phase_goal: sub_phase.scope
       - remediation_feedback: sub_phase.issues
       - All other fields inherited from parent phase
     - Run in parallel (all sub-phase-runners spawned concurrently)
  3. Collect results from all sub-phase-runners
  4. Aggregate sub-phase results:
     - status: "completed" if ALL sub-phases completed, "failed" if ANY failed
     - alignment_score: arithmetic mean of sub-phase scores (decimal, x.x format)
     - commit_shas: merged from all sub-phases
     - issues: merged from all sub-phases
  5. Report sub-phases inline in completion report: "Phase {N} (split: {Na}, {Nb}, {Nc})"
  6. Update state.json with sub-phase details:
     - phases.{N}.split: true
     - phases.{N}.sub_phases: [{sub_phase_id, status, alignment_score}]
```

**Split threshold guidance (for phase-runners):** A phase-runner SHOULD return a split request when:
- Remediation feedback contains more than 3 issues AND the issues span 4+ different files
- The estimated task count exceeds 5 complex tasks
- The phase-runner detects during planning that execution would require reading 10+ files

The exact threshold is at the phase-runner's discretion. The priority order is **Quality > Time > Tokens** -- spawning many sub-agents is preferred over trying to squeeze everything into fewer agents.

**Sub-phase verification:** Each sub-phase goes through its own independent verification cycle (verify + judge + rate). Sub-phase results are NOT shared between sub-phases. This ensures each piece of work meets the quality bar independently.

### Repository Map Generation (Section 2.2)

Before spawning each phase-runner, the orchestrator generates or refreshes the semantic repository map at `.autopilot/repo-map.json`. This map provides structural codebase understanding (exports, imports, functions, classes) to all agents.

**Generation logic:**

```
before spawning phase-runner for phase N:
  if .autopilot/repo-map.json does not exist:
    spawn general-purpose agent to generate the map (see schema in autopilot-schemas.md Section 14)
    agent scans source files (excluding node_modules, dist, .git, build, coverage, .next, __pycache__, .venv, vendor)
    agent reads each file, extracts exports/imports/functions/classes, writes to .autopilot/repo-map.json
    if map exceeds 500 lines: apply size cap (see schema Section 14)
    log: "Repo-map generated: {total_files} files across {language_count} languages."
  else:
    check if any commits have been made since the map was last generated (compare repo-map generated_at with latest commit timestamp)
    if no new commits: skip regeneration. log: "Repo-map up to date, skipping refresh."
    if new commits exist:
      identify files changed since generated_at (git diff --name-only {generated_at_timestamp}..HEAD)
      spawn general-purpose agent to update ONLY the changed file entries (incremental update)
      log: "Repo-map refreshed: {changed_file_count} files updated."
```

**Cost consideration:** Map generation adds approximately 10000-30000 tokens per phase depending on project size. For projects with no source code files (protocol-only projects), the map will be minimal. The map is cached between phases (only incremental updates after the first generation), so the cost is amortized across the run.

**Passing the map to phase-runners:** The repo-map path is passed explicitly to each phase-runner via the `repo_map_path` field in the spawn template (Section 3). The phase-runner playbook instructs research and executor agents to read this file for structural codebase queries.

### Progress Streaming Protocol

During phase execution, the orchestrator and phase-runner emit structured progress messages so the user has real-time visibility into what the pipeline is doing. Without these messages, the user invokes `/autopilot` and waits 20-60 minutes with no feedback.

**Tier 1 (Orchestrator) -- user-visible progress:**

The orchestrator emits progress messages that the user sees directly in the CLI. These are the PRIMARY progress indicators.

Before spawning each phase-runner, emit:
```
--- [PHASE {N}/{total}] {phase_name} ---
```

After receiving the phase-runner's return JSON, emit:
```
  Step: PREFLIGHT ... pass
  Step: TRIAGE ... {routing_decision}
  Step: RESEARCH ... {completed|skipped}
  Step: PLAN ... {completed|skipped}
  Step: PLAN-CHECK ... {pass|fail|skipped}
  Step: EXECUTE ... {tasks_completed}/{tasks_total} tasks
  Step: VERIFY ... {pass|fail}
  Step: JUDGE ... {recommendation}
  Step: RATE ... {alignment_score}/10
--- [PHASE {N}/{total}] Complete: {alignment_score}/10 | {duration}s ---
```

The orchestrator reconstructs step-level progress from the phase-runner's return JSON `pipeline_steps` field. Each step entry has a `status` value that maps to the progress line. This does NOT require real-time streaming from the phase-runner -- the orchestrator emits all step progress lines at once after the phase-runner completes, giving the user a clear summary of what happened during the phase.

**Tier 2 (Phase-Runner) -- captured by orchestrator:**

The phase-runner emits progress messages between step agent spawns. These are captured in the phase-runner's output and visible to the orchestrator (and to the user in the orchestrator's output after the phase completes):

```
[Phase {N}] Step: RESEARCH (1/6)
[Phase {N}] Step: RESEARCH complete.
[Phase {N}] Step: PLAN (2/6)
[Phase {N}] Step: PLAN complete.
[Phase {N}] Step: EXECUTE (4/6) -- {total_tasks} tasks
[Phase {N}] Task {task_id} (1/{total}): {description}
[Phase {N}] Task {task_id}: modifying {file_path}
[Phase {N}] Task {task_id}: compile PASS
[Phase {N}] Task {task_id}: VERIFIED
[Phase {N}] Task {task_id} (2/{total}): {description}
...
[Phase {N}] Step: VERIFY (5/6)
[Phase {N}] Step: JUDGE (6/6)
[Phase {N}] Step: RATE (7/7)
```

**Tier 3 (Step Agents) -- captured by phase-runner:**

Step agents (executor, verifier, etc.) emit their own progress within their output. The phase-runner reads only the JSON summary, but the progress text provides debugging context if needed.

**Format rules:**
- All progress messages are plain text (no markdown, no emojis)
- Phase-level messages use `--- [PHASE ...] ---` delimiters
- Step-level messages use `[Phase {N}] Step: ...` prefix
- Task-level messages use `[Phase {N}] Task {task_id}: ...` prefix
- Compile/lint results use `PASS` or `FAIL` keywords for machine parseability

### Human-Defer Rate Tracking (STAT-04)

The orchestrator maintains two counters across the loop: `human_deferred_count` (phases returning `needs_human_verification`) and `total_phases_processed` (all phases that received a return, regardless of status). Both start at 0 at run start.

After each phase return:
1. Increment `total_phases_processed`.
2. If `status` is `"needs_human_verification"`, increment `human_deferred_count`.
3. Compute `defer_rate = human_deferred_count / total_phases_processed`.
4. If `defer_rate > 0.05` AND `total_phases_processed >= 2`: Log warning: "High human-defer rate ({human_deferred_count}/{total_phases_processed}). Pipeline may be avoiding autonomous completion. Target: below 5%." Append a `high_defer_rate_warning` event to the event_log.

These counters persist in `state.json` (see Section 7) so they survive resume operations.

5. If `status` is `"completed"` AND the phase had `checkpoint:human-verify` tasks in its plan AND the verifier's `autonomous_confidence >= 6`: Append an `autonomous_resolution_success` event to the event_log. Log: "Phase {N}: autonomous resolution succeeded (confidence: {autonomous_confidence}/10). Human deferral avoided."
6. Append a deferral history entry to `_meta.deferral_history`: `{phase_id, reason: "completed|deferred", autonomous_confidence, human_verdict: null, timestamp}`.
7. Update `_meta.autonomous_resolution_rate`: compute `(total_phases_processed - human_deferred_count) / total_phases_processed`.

### Deferral Threshold Auto-Adjustment

At the end of each run (during the completion protocol), the orchestrator auto-adjusts the deferral confidence threshold based on historical human verdicts from `_meta.deferral_history`:

```
deferred_phases = deferral_history entries where reason == "deferred" AND human_verdict is not null
if deferred_phases.length >= 3:
  pass_rate = count(human_verdict == "pass") / deferred_phases.length
  if pass_rate > 0.80:
    // Humans consistently pass deferred phases -- autonomous verification was being too conservative
    new_threshold = max(3, current_deferral_threshold_confidence - 0.5)
    log: "Deferral threshold auto-adjusted: confidence threshold lowered from {old} to {new}. Reason: {pass_rate*100}% of deferred phases passed human review."
    append deferral_threshold_adjusted event
  else if pass_rate < 0.70:
    // Humans consistently find issues -- autonomous verification should be more conservative
    new_threshold = min(8, current_deferral_threshold_confidence + 0.5)
    log: "Deferral threshold auto-adjusted: confidence threshold raised from {old} to {new}. Reason: only {pass_rate*100}% of deferred phases passed human review."
    append deferral_threshold_adjusted event
  store new_threshold in _meta.deferral_threshold
```

The threshold starts at 6 (autonomous_confidence >= 6 means no deferral) and adjusts based on whether human reviewers are finding real issues that autonomous verification missed.

### Deferral Statistics in Run-End Summary

At the end of each run, include deferral statistics in the completion summary:
- Total phases processed: {total_phases_processed}
- Phases deferred to human: {human_deferred_count} ({defer_rate*100}%)
- Autonomous resolutions: {total_phases_processed - human_deferred_count}
- Autonomous resolution rate: {autonomous_resolution_rate*100}%
- Current deferral confidence threshold: {deferral_threshold}

### Pre-Spawn Checks (Automatic, No User Input)

Before spawning the phase-runner for phase N:
1. Glob for `VERIFICATION.md` in this phase's directory. If it exists:
   1. Read the first 5 lines to extract the `verified:` timestamp
   2. Check if the timestamp is from the CURRENT run (compare with `_meta.started_at` in state.json)
   3. If same run AND shows all checks passing: skip. Log: "Phase {N} already verified in this run -- skipping."
   4. If different run: do NOT skip. Log: "Phase {N} has stale verification from prior run -- re-running."
2. Glob for `EXECUTION-LOG.md` in this phase's directory. If it exists, pass `prior_execution_exists: true` to the phase-runner.
3. **Context sufficiency quick check (CMAP-05):** When `--map` is NOT active, perform a lightweight context sufficiency assessment for the phase. This is NOT the full scoring algorithm from Section 1.2 -- it is a quick heuristic check:
   - Read the phase's roadmap entry. If the goal is a stub (contains "[To be planned]", "TBD", or is empty), the score is 1-2.
   - Check if the phase has requirements mapped in the frozen spec. If no requirements are mapped, the score is 3-4.
   - Check if the phase has success criteria with verification commands. If no verification commands, the score is 4-5.
   - If the quick-check score is below 5: Emit a non-blocking warning: `"Phase {N} has low context confidence ({score}/10): {reason}. Consider running /autopilot --map {N} first."`
   - This is a WARNING only. Execution continues regardless. The warning helps users catch severely underspecified phases before burning tokens.
   - If the quick-check score is 5 or above: No warning. Continue silently.
   - Do NOT spawn any agents for this check. It should be a 5-second heuristic, not a full scoring run.

### Task Type Count

If a PLAN.md exists for this phase, grep/count task types:
- Look for `<task type="auto">` and `<task type="checkpoint:human-verify">` tags
- Count occurrences of each type
- Pass the counts in the spawn prompt as the "Task type summary" line
- If no plan exists yet, pass `0 auto, 0 checkpoint:human-verify` -- the phase-runner will create the plan during its pipeline

### Cost Estimation (MTRC-02)

Before spawning the phase-runner, estimate the token cost for this phase:

1. If a PLAN.md exists for this phase, read it and count tasks by complexity attribute:
   - For each `<task ... complexity="simple">`: add 15000 tokens
   - For each `<task ... complexity="medium">`: add 30000 tokens
   - For each `<task ... complexity="complex">`: add 60000 tokens
   - Add pipeline overhead: 50000 tokens (covers research + plan + plan-check + verify + judge)
   - Apply buffer: multiply total by 1.20 (20% buffer for debug loops, re-verification)
   - Formula: `estimated_tokens = (pipeline_overhead + sum(task_tokens)) * 1.20`
2. If no PLAN.md exists (full pipeline from scratch), use default estimates by phase type:
   - protocol: 150000 tokens
   - ui: 250000 tokens
   - data: 100000 tokens
   - mixed: 200000 tokens
   - Apply buffer: multiply by 1.20
3. Compare `estimated_tokens` against `cost_cap_tokens_per_phase` (500000 from circuit breaker config). If estimated exceeds 80% of the budget cap, log warning: "Phase {N} estimated at {est} tokens ({pct}% of budget cap). Consider splitting complex tasks."
4. Log the estimate: "Phase {N} cost estimate: {est} tokens ({task_count} tasks: {simple_count} simple, {medium_count} medium, {complex_count} complex)"
5. Store `estimated_tokens` in the phase record in `state.json` so it can be aggregated into `total_estimated_tokens` during metrics collection (Section 9, step 4).
6. Pass `estimated_tokens` to the phase-runner spawn prompt as an informational field.

### Phase Execution

1. **Check for existing plan**: Glob `.planning/phases/*{phase_id}*/PLAN.md`. Pass `existing_plan: true` or `existing_plan: false`. Phases without plans run the full pipeline from step 1 (research). No need to ask -- that is what the pipeline is for.
2. **Emit phase progress header** (Progress Streaming Protocol): Output `--- [PHASE {N}/{total}] {phase_name} ---` so the user knows which phase is starting.
3. Spawn **phase-runner** (Section 3). Wait for completion (`run_in_background: false`).
4. Parse the **return JSON** from the phase-runner's response (last lines).
5. **Emit step-level progress summary** (Progress Streaming Protocol): Using the `pipeline_steps` field from the return JSON, emit one line per step showing its status. Format: `  Step: {STEP_NAME} ... {status}`. This gives the user a clear breakdown of what happened inside the phase-runner. Include task completion counts from the execute step and the alignment score from the rate step.
6. **Handle human verification**: If the phase-runner returns `status: "needs_human_verification"`, log it with `human_verify_justification` details, skip to next phase, and continue. Come back to these at the end of the run.
7. **Gate decision** (Section 5).
8. **Update state** (Section 7).
9. **Emit phase completion footer** (Progress Streaming Protocol): Output `--- [PHASE {N}/{total}] Complete: {score}/10 | {duration}s ---` so the user sees the final result.

### End-of-Run Human Verification (STAT-05)

At the end of the run, for each phase that returned `needs_human_verification`:
1. Present the `human_verify_justification` to the user.
2. Collect the user's verdict: `pass`, `fail`, or `issues_found`.
3. Record the verdict in `state.json` under `phases.{N}.human_verdict`:
   ```json
   {
     "verdict": "pass|fail|issues_found",
     "timestamp": "ISO-8601",
     "issues": ["description of issues found, if any"]
   }
   ```
4. Append a `human_verdict_recorded` event to the `event_log` with the phase ID and verdict.
5. **Append calibration entry to learnings file (LRNG-04):** After recording the verdict, append a calibration entry to `.autopilot/learnings.md`. If the file does not exist, create it with the header `# Learnings (current run)`. The entry format depends on the verdict:

   **If verdict is `pass`:**
   ```markdown
   ### Human Verdict: Phase {N} -- PASS (confidence calibration)
   Phase {N} ({phase_name}) was deferred to human review but passed without issues.
   **Calibration:** Future phases with similar characteristics ({phase_type} phase, {auto_tasks_passed}/{auto_tasks_total} auto tasks passed, alignment score {score}/10) should increase autonomous completion confidence. The system was overly cautious in deferring this phase.
   ```

   **If verdict is `fail` or `issues_found`:**
   ```markdown
   ### Human Verdict: Phase {N} -- {FAIL|ISSUES_FOUND} (confidence calibration)
   Phase {N} ({phase_name}) was deferred to human review. Human found issues: {issues_list}.
   **Calibration:** Tighten quality checks for similar phases ({phase_type} phase). Specific issues to watch for: {issues_list}. The system correctly deferred this phase -- future phases with similar patterns should maintain or increase scrutiny.
   ```

   This calibration data is consumed by subsequent executors (pre-execution priming, EXEC-06) and planners (LRNG-02) within the same run. If humans consistently pass deferred phases, the learnings file accumulates "increase confidence" signals. If humans consistently find issues, it accumulates "tighten scrutiny" signals. The executor and planner read these signals and adjust their own quality thresholds accordingly.

---

## 3. Phase-Runner Spawn Template

Spawn via **Task tool**: `subagent_type: "autopilot-phase-runner"`, `run_in_background: false`.

**CRITICAL: If the Task tool returns "Agent type 'autopilot-phase-runner' not found":**
- Do NOT fall back to `general-purpose` or any other agent type.
- HALT the run immediately. Save state with current position. Compute remaining phases and output:

```
autopilot-phase-runner agent not found. Agent types are discovered at session startup. To continue, run:
  /clear
  /autopilot {remaining_phases}
```

**Model**: Read `.planning/config.json` `model_profile` -- `"quality"` = opus, `"balanced"` = sonnet, `"speed"` = haiku. Default: sonnet. Note: Claude Code's Task tool accepts a `model` parameter (enum: sonnet, opus, haiku). Pass the resolved model name.

**Prompt** (fill `{variables}` from roadmap + state):

> You are a phase-runner for autopilot. Execute ALL pipeline steps for one phase autonomously.
>
> **Your Phase:** {phase_id} -- {phase_name}
> **Goal:** {phase_goal_from_roadmap}
> **Description:** {phase_description_from_roadmap}
> **Frozen spec:** {spec_path} (hash: {spec_hash})
> **Roadmap:** {roadmap_path}
> **Requirements for this phase:** {requirements_list || "No specific requirements mapped. Derive from phase goal and roadmap."}
> **Completed phase directories:** {list_of_dir_paths}
> **Last checkpoint SHA:** {last_checkpoint_sha}
> **Existing plan:** {true|false}
> **Prior execution exists:** {true|false}
> **Skip research:** {true|false -- from config.json workflow.research if available}
> **Task type summary:** {N} auto tasks, {M} checkpoint:human-verify tasks
> **Phase type:** {ui|protocol|data|mixed} — derived from phase content (see below)
> **Estimated cost:** {estimated_tokens} tokens (from MTRC-02 pre-spawn estimate)
> **Repo map path:** .autopilot/repo-map.json
> **ENFORCEMENT: Verify, judge, and rating agent steps MUST spawn independent subagents. Self-assessment is rejected by the orchestrator.**
> **Remediation feedback:** {remediation_feedback || "null" -- structured list of specific deficiencies from judge/verifier, provided during remediation cycles}
> **Remediation cycle:** {remediation_cycle || 0 -- current remediation cycle number, 0 = initial run, 1-2 = remediation}
> **Pass threshold:** {pass_threshold || 9 -- alignment score threshold, 9 default, 7 with --lenient}
>
> **Phase directory resolution:** Use Glob to find your phase directory (e.g., `.planning/phases/*{phase_id}*` or `.planning/phases/{phase_number}-*/`) rather than assuming a fixed path format.
>
> **Prior phase context:** If you need context from prior phases, read SUMMARY.md files from the completed phase directories listed above. The orchestrator does NOT pass summary content -- you read what you need.
>
> **Instructions:**
> 1. Read `__INSTALL_BASE__/autopilot/protocols/autopilot-playbook.md` for pipeline step details and verification methodology.
> 2. Read the frozen spec at {spec_path}.
> 3. Execute the full pipeline. Your agent definition has the structure; the playbook has step-specific prompts.
>
> **Return Contract** -- at the VERY END of your response, output the JSON defined in `__INSTALL_BASE__/autopilot/protocols/autopilot-orchestrator.md` Section 4. Key fields: `evidence` (files_checked, commands_run, git_diff_summary), `automated_checks` (compile, build, lint), `pipeline_steps` per step.

**Completed phase directories:** After each phase completes, append its directory path to a running list. Pass this list of paths (NOT content) to subsequent phase-runners. Example: `[".planning/phases/14-01-...", ".planning/phases/14-02-..."]`. The phase-runner reads SUMMARY.md files itself if it needs prior context.

### Phase Type Classification

Before spawning, classify the phase. Read `project.ui.source_dir` and `project.commands` from `.planning/config.json` to determine project-specific paths and commands.

- **ui**: Phase modifies files in the configured `project.ui.source_dir` or any frontend code. Requires: (1) compile check (`project.commands.compile`), (2) production build (`project.commands.build`), (3) autonomous verification with behavioral traces (the verifier MUST attempt full autonomous resolution before considering deferral).
- **protocol**: Phase modifies `.md` files in `protocols/`, project instructions, or agent definitions. Requires: (1) cross-reference check (no broken links between protocol files), (2) contract verification (schemas match what orchestrator expects).
- **data**: Phase modifies JSON data files or similar structured data. Requires: (1) JSON validity check, (2) schema compliance check.
- **mixed**: Combination of above. Apply ALL relevant requirements.

For **ui** phases: The orchestrator MUST add this to the spawn prompt:
> **AUTONOMOUS VERIFICATION REQUIRED: This is a UI phase. The verifier MUST attempt autonomous resolution using build checks, behavioral traces, and code analysis before considering any deferral. Deferral is only permitted when the verifier's autonomous_confidence is below 6 AND specific deferral_evidence documents what cannot be verified and why. Generic visual confirmation is NOT a valid deferral reason -- the verifier must trace handler chains, verify build output, and run all acceptance criteria autonomously. Return status as "completed" unless autonomous verification is genuinely insufficient.**

### Visual Testing Configuration

If `.planning/config.json` contains `project.visual_testing` with `enabled: true`, validate the configuration before spawning phase-runners for UI phases:

1. **Required fields check:** Verify `visual_testing.launch_command`, `visual_testing.base_url`, and `visual_testing.routes` (non-empty array, each route has `path` and `name`) are present. If any required field is missing, log warning: "Visual testing config incomplete: missing {field}. Visual testing will be skipped." and proceed without visual testing.
2. **Pass to phase-runner:** Add `visual_testing_enabled: true` to the phase-runner spawn prompt for UI and mixed phases. This tells the verifier to run Step 2.5 (Visual Testing) during verification.
3. **When `--visual` flag is used:** Set `visual_testing_enabled: true` even if `visual_testing.enabled` is false in config.json, allowing one-off visual test runs without permanent config changes. The `--visual` flag requires that `project.visual_testing` section exists in config.json (with at least `launch_command`, `base_url`, and `routes`).
4. **Visual issues in debug loop:** When the verifier reports `visual_test_results.issues_found` with severity `critical` or `major`, include these visual issues in the debug loop issue list alongside functional failures. The debugger receives the `.planning/phases/{phase}/VISUAL-BUGS.md` path as additional context. After debug fixes, re-verification includes re-running visual tests (Step 2.5) to confirm visual issue resolution.

---

## 4. Phase-Runner Return Contract

The canonical return contract is defined here. The phase-runner returns this JSON as the last lines of its response.

```json
{
  "phase": "{phase_id}",
  "status": "completed|failed|needs_human_verification|split_request",
  "alignment_score": <1.0-10.0 or null>,
  "tasks_completed": "N/M",
  "tasks_failed": "N/M",
  "commit_shas": ["sha1", "sha2"],
  "automated_checks": {
    "compile": true|false|"n/a",
    "build": true|false|"n/a",
    "lint": true|false|"n/a"
  },
  "issues": ["description"],
  "debug_attempts": 0,
  "replan_attempts": 0,
  "recommendation": "proceed|debug|rollback|halt",
  "summary": "1-2 sentences",
  "checkpoint_sha": "sha|null",
  "verification_duration_seconds": <number or null>,
  "evidence": {
    "files_checked": ["path:line evidence"],
    "commands_run": ["command -> result"],
    "git_diff_summary": "N files changed, M insertions, K deletions"
  },
  "human_verify_justification": {
    "checkpoint_task_id": "XX-YY",
    "task_description": "description of the checkpoint task requiring human verification",
    "auto_tasks_passed": N,
    "auto_tasks_total": M
  },
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
    "preflight": {"status": "pass|fail|skipped", "agent_spawned": false},
    "triage": {"status": "full_pipeline|verify_only", "agent_spawned": false, "pass_ratio": 0.0},
    "research": {"status": "completed|skipped", "agent_spawned": true|false, "skip_reason": "string|null"},
    "plan": {"status": "completed|skipped", "agent_spawned": true|false, "skip_reason": "string|null"},
    "plan_check": {"status": "pass|fail|skipped", "agent_spawned": true, "confidence": 8},
    "execute": {"status": "completed|partial|skipped", "agent_spawned": true},
    "verify": {"status": "pass|fail|skipped", "agent_spawned": true},
    "judge": {"status": "pass|fail|skipped", "agent_spawned": true},
    "rate": {"status": "pass|fail|skipped", "agent_spawned": true, "alignment_score": 8.2, "score_band": "good"}
  }
}
```

**Field notes:**
- `alignment_score` uses decimal precision (x.x format, e.g., 7.3, 8.6, 9.2). Produced by the dedicated rating agent (STEP 4.6 in playbook), NOT the verifier or judge. Integer scores are invalid -- the phase-runner rejects them before returning.
- `verification_duration_seconds` is the wall-clock time the verifier agent ran, recorded by the phase-runner. Used by Check 10 (VRFY-03) for rubber-stamp detection. Set to `null` if verification was skipped.
- `evidence` is NEW. Contains concrete proof of work. The judge uses this for independent verification. If `commit_shas` is empty (already-implemented claim), `evidence.files_checked` MUST list file:line evidence for each acceptance criterion.
- `human_verify_justification` is REQUIRED when `status` is `"needs_human_verification"`. Omit or set to `null` for other statuses. The orchestrator rejects any `needs_human_verification` return that lacks this field (see Section 5, Check 13).
- `split_details` is REQUIRED when `status` is `"split_request"`. Omit or set to `null` for other statuses. Contains the recommended sub-phases for the orchestrator to spawn. See Section 2.1 for split handling.
- `pipeline_steps` uses ONE canonical shape: `{status, agent_spawned}` plus optional `confidence` (plan_check only), `skip_reason` (research/plan only), `pass_ratio` (triage only), and `alignment_score` (rate only). No `ran` field. No alternative schemas.
- `automated_checks` includes `build` to distinguish compilation (`compile` = configured compile command) from production build (`build` = configured build command). Actual commands are read from `project.commands` in `.planning/config.json`.

Parse from the **last lines** of the phase-runner's response. If missing, spawn a small agent to extract it.

---

## 5. Gate Logic

The orchestrator's gate logic is deliberately simple. The phase-runner handles ALL internal retries (debug loops, replans). If the phase-runner returns a result, the orchestrator makes a binary decision:

| Condition | Action |
|-----------|--------|
| `status=="completed"` AND `alignment_score >= pass_threshold` (default 9.0, 7.0 with --lenient, 9.5 with --quality) AND `recommendation=="proceed"` | **PASS** -- generate diagnostic file if score < 9.0 (CENF-02), checkpoint, next phase. Note: `alignment_score` is decimal (x.x format) from the rating agent. |
| `status=="completed"` AND `alignment_score >= 7.0` AND `alignment_score < pass_threshold` AND `recommendation=="proceed"` | **REMEDIATE** -- generate diagnostic file (CENF-02), enter remediation cycle (Section 5.1 for standard, Section 1.5 for --quality, Section 1.6 for --gaps) |
| `status=="needs_human_verification"` | **SKIP** -- log human_verify_justification, continue to next phase, revisit at end of run |
| `status=="split_request"` | **SPLIT** -- handle scope split per Section 2.1, spawn sub-phase-runners in parallel, aggregate results |
| `status=="failed"` AND phase is independent (no later phases depend on it) | **LOG + CONTINUE** -- note `.autopilot/diagnostics/phase-{N}-postmortem.json` for inspection, move to next phase |
| `status=="failed"` AND later phases depend on it | **HALT** -- note `.autopilot/diagnostics/phase-{N}-postmortem.json` for inspection, notify user with restart guidance (see below) |
| `recommendation=="rollback"` | **ROLLBACK** -- `git revert` to last checkpoint, diagnostic, halt |

**Pass threshold:** The `pass_threshold` is 9.0 by default. When `--lenient` is passed, it is set to 7.0. When `--quality` is passed, it is set to 9.5. This variable is stored in `_meta.pass_threshold` in state.json and used throughout the gate logic. When `--lenient` is active, the REMEDIATE row never triggers (because `pass_threshold` equals 7.0, so any score >= 7.0 hits the PASS row). When `--quality` is active, phases must score 9.5+ to pass without remediation. Note: `alignment_score` from the rating agent uses decimal precision (x.x format), so comparisons use decimal thresholds.

**CRITICAL: The orchestrator does NOT re-spawn failed phase-runners.** The phase-runner already exhausted its internal retry budget (max 3 debug attempts, max 1 replan). If it returns `failed`, the issue requires human intervention. But if the failed phase is independent, keep running remaining phases.

**NOTE: The orchestrator DOES re-spawn for remediation cycles (Section 5.1).** This is distinct from failure re-spawning. Remediation applies to phases that PASSED (score >= 7) but did not meet the `pass_threshold` (default 9). The phase-runner is re-spawned with targeted feedback to address specific deficiencies, not to retry from scratch.

On HALT/ROLLBACK: set state `status:"failed"`, note that the phase-runner has written a structured post-mortem to `.autopilot/diagnostics/phase-{N}-postmortem.json` (OBSV-04). Compute remaining phases from the execution queue and tell the user:

```
Phase {N} failed. To continue from where you left off, run:
  /clear
  /autopilot {remaining_phases}
```

Where `{remaining_phases}` is the space-separated list of incomplete phase IDs (excluding the failed phase and any phases blocked by it). If the failed phase can be retried independently, also mention: `"To retry the failed phase: /clear then /autopilot {failed_phase_id}"`.

### Return JSON Integrity Check

Before applying gate logic, validate the phase-runner's return:

1. **Verify/Judge must have run:** If `status` is `"completed"` or `"needs_human_verification"` with auto tasks reported in `tasks_completed`:
   - `alignment_score` MUST NOT be null
   - `automated_checks` MUST have at least `compile` as true/false (not "n/a")
   - `pipeline_steps.verify` and `pipeline_steps.judge` must not be "skipped"
   - If any of these fail: REJECT the return. Log: "Phase-runner skipped verification pipeline. Re-spawning."

2. **Commit sanity:** If `tasks_completed` shows completed tasks but `commit_shas` is empty:
   - Log: "Tasks complete but no commits -- possible already-implemented scenario."
   - This is valid (proceed), but log it for the record.

3. **Duration sanity:** If the phase-runner completed in under 5 minutes for a phase with 2+ auto tasks:
   - Log warning: "Fast completion ({duration}). Checking pipeline_steps."
   - Verify `pipeline_steps` shows all expected steps ran.

4. **Verify/Judge/Rate agent enforcement:** If `tasks_completed` shows completed auto tasks (N > 0 in "N/total"):
   - `pipeline_steps.verify.agent_spawned` MUST be `true`
   - `pipeline_steps.judge.agent_spawned` MUST be `true`
   - `pipeline_steps.rate.agent_spawned` MUST be `true`
   - If ANY is `false`: REJECT the return. Log: "Self-verification/self-rating not accepted for phases with auto tasks. Re-spawning with enforcement flag."
   - Re-spawn the phase-runner with an additional line in the prompt: `**ENFORCEMENT: You MUST spawn independent verify, judge, and rating agents. Self-assessment is rejected.**`
   - Maximum 1 enforcement re-spawn per phase. If the second attempt also returns `agent_spawned: false`, mark phase as failed.

5. **Rubber-stamp detection (3-tier escalation):** Track consecutive phase completions where alignment scores are within 0.2 of each other. Also flag integer scores (no decimal). Escalation tiers:

   - **Tier 1 (3 consecutive uniform scores):** Log warning: "Uniform alignment scores detected ({min}-{max}/10 x {count} phases). Possible rubber-stamping." Append `rubber_stamp_warning` event to event_log. This is a WARNING only -- execution continues normally.

   - **Tier 2 (5 consecutive uniform scores):** Log warning: "Rubber-stamp pattern persists ({count} consecutive uniform scores). Enabling enhanced verification for next phase." Append `rubber_stamp_enhanced` event to event_log. For the NEXT phase, inject enhanced verification into the phase-runner spawn prompt:
     > **ENHANCED VERIFICATION (rubber-stamp mitigation):** Uniform alignment scores detected across {count} consecutive phases. To counter potential rubber-stamping: (1) Rating agent: start scoring from 5.0 baseline and ADD points only with explicit evidence, (2) Verifier: perform behavioral trace for ALL interactive handlers (not just UI phases), (3) Judge: identify at least 2 concerns (not just 1). These measures apply to this phase only.

   - **Tier 3 (7+ consecutive uniform scores):** Log critical warning: "CRITICAL: {count} consecutive uniform alignment scores ({min}-{max}/10). Strong rubber-stamp indicator." Append `rubber_stamp_critical` event to event_log. Additionally:
     - Include a "Rubber-Stamp Alert" section in the completion report with all affected phase IDs and their scores
     - Mark all affected phases in state.json: `phases.{N}.rubber_stamp_suspect: true`
     - Continue enhanced verification injection for all remaining phases

   - **Integer score flag (any tier):** If any alignment_score is an integer (no decimal): Log warning: "Integer alignment score detected ({score}). Rating agent MUST produce decimal scores (x.x format)."

6. **Already-implemented claims:** If `commit_shas` is empty AND `tasks_completed` shows completed tasks:
   - The phase-runner MUST have provided file:line evidence for each acceptance criterion
   - `pipeline_steps.verify.agent_spawned` MUST be `true` (independent agent confirmed the claim)
   - If verify agent was not spawned: REJECT. Log: "Already-implemented claims require independent verification. Re-spawning."

### Evidence Validation

7. **Evidence completeness (STAT-01):** If `status` is `"completed"` OR (`status` is `"needs_human_verification"` AND `tasks_completed` shows completed auto tasks, i.e. N > 0 in "N/total"):
   - `evidence.commands_run` MUST contain at least one command per phase type:
     - **ui phases:** Must include the configured compile AND build commands with result (from `project.commands` in config.json)
     - **protocol phases:** Must include a cross-reference validation command with result
     - **data phases:** Must include a JSON validity check command with result
   - `evidence.git_diff_summary` MUST be non-empty (unless already-implemented)
   - If evidence is missing or empty: REJECT. Log: "Phase completed without evidence. Re-spawning."
   - **Note:** Evidence validation applies uniformly to any phase that completed auto tasks, regardless of whether the final status is `completed` or `needs_human_verification`. The auto-task portion of a mixed plan must meet the same evidence bar as a fully autonomous phase.

8. **Already-implemented evidence bar:**
   - If `commit_shas` is empty AND `tasks_completed` shows completed tasks:
     - `evidence.files_checked` MUST have at least one entry per acceptance criterion
     - Each entry must be in format "filepath:lineN — description of what was verified"
     - `pipeline_steps.verify.agent_spawned` MUST be `true`
     - `pipeline_steps.judge.agent_spawned` MUST be `true`
     - If ANY of these fail: REJECT. Log: "Already-implemented claims lack sufficient evidence."

### Verification Pipeline Hardening Checks

9. **JUDGE-REPORT.md existence and divergence (VRFY-02):** If `pipeline_steps.judge.agent_spawned` is `true`:
   - Verify `.planning/phases/{phase}/JUDGE-REPORT.md` exists.
   - If it does not exist: REJECT. Log: "Judge did not produce JUDGE-REPORT.md artifact. Re-spawning."
   - If it exists, verify it contains a "Divergence Analysis" section.
   - If the Divergence Analysis section states zero differences from VERIFICATION.md AND the judge's `independent_evidence` field is empty or missing: REJECT. Log: "JUDGE-REPORT.md shows no independent analysis. Possible rubber-stamping."

10. **Verifier rubber-stamp detection (VRFY-03):** If `pipeline_steps.verify.agent_spawned` is `true`:
    - The phase-runner MUST record `verification_duration_seconds` from the verifier's return JSON.
    - If `verification_duration_seconds` < 120 (2 minutes): REJECT. Log: "Verifier completed in {N} seconds -- below 2-minute minimum. Possible rubber-stamp."
    - If the verifier's `commands_run` list is empty: REJECT. Log: "Verifier reported empty commands_run. Verification without command execution is not accepted."

11. **Judge rubber-stamp detection (VRFY-04):** If `pipeline_steps.judge.agent_spawned` is `true`:
    - If the judge's `verifier_agreement` is `true` AND `verifier_missed` is empty AND `independent_evidence` is empty or missing: REJECT. Log: "Judge agrees with verifier on all points without presenting independent evidence. Possible rubber-stamp."

12. **Failure classification (VRFY-05):** If the verifier or debugger returns failures:
    - Each failure MUST include a `category` from the defined taxonomy: `executor_incomplete`, `executor_wrong_approach`, `compilation_failure`, `lint_failure`, `build_failure`, `acceptance_criteria_unmet`, `scope_creep`, `context_exhaustion`, `tool_failure`, `coordination_failure`.
    - If any failure lacks a category: Log warning: "Unclassified failure detected: {failure_description}." This is a WARNING, not a rejection.

### Confidence Enforcement (CENF-01 through CENF-05)

15. **Diagnostic file generation (CENF-02, CENF-05):** After EVERY phase completion where `alignment_score < 9.0` (regardless of `--lenient` status), the orchestrator writes a diagnostic file:

    **Path:** `.autopilot/diagnostics/phase-{N}-confidence.md`

    **Content:**
    ```markdown
    # Phase {N} Confidence Diagnostic

    **Score:** {alignment_score}/10 (decimal x.x format, from rating agent)
    **Threshold:** {pass_threshold}/10 (default 9.0, lenient 7.0)
    **Status:** {passed | force_incomplete | remediated_to_{final_score}}

    ## Judge Concerns
    {Extracted from return JSON concerns[] -- one bullet per concern}

    ## Acceptance Criteria Status
    | Criterion | Status | Evidence | Gap |
    |-----------|--------|----------|-----|
    {From verifier criteria_results: criterion text | verified/failed | file:line evidence | what is missing}

    ## Automated Check Results
    | Check | Result | Details |
    |-------|--------|---------|
    | compile | {pass/fail} | {detail from automated_checks} |
    | lint | {pass/fail} | {detail} |
    | build | {pass/fail/n/a} | {detail} |

    ## Path to 9.0/10
    {For each item: specific file path, specific deficiency, expected score impact. Derived from rating agent's scorecard deductions.}
    1. **{file_path}**: {specific deficiency} -- fixing this addresses {scorecard_deduction} and would resolve {N} of {M} remaining issues
    2. **{file_path}**: {specific deficiency} -- {expected impact}
    ```

    **CENF-05 enforcement:** Every item in the "Path to 9/10" section MUST contain: (a) a specific file path, (b) the specific deficiency in that file, and (c) the expected impact on the score. Vague advice like "improve code quality" or "add more tests" is NOT acceptable. If the judge's concerns are vague, the orchestrator extracts the most specific information available from `criteria_results`, `failures`, and `independent_evidence`.

    **Generation logic:**
    ```
    if alignment_score < 9.0:
      build diagnostic content from:
        - rating agent return JSON: scorecard[] (per-criterion scores and deductions), aggregate_justification
        - judge return JSON: concerns[], independent_evidence[]
        - verifier return JSON: criteria_results[], automated_checks, failures[]
        - phase plan: acceptance criteria from PLAN.md
      construct "Path to 9.0/10" by:
        for each criterion in scorecard where score < 9.0:
          identify the target file from the criterion
          describe what is missing or wrong (from scorecard justification)
          estimate impact: "resolves {criterion_description}"
        for each judge concern not already covered:
          map to a specific file if possible
          describe what would address the concern
      write to .autopilot/diagnostics/phase-{N}-confidence.md
      append confidence_diagnostic_written event to event_log
    ```

### 5.1 Remediation Cycles

16. **Remediation cycle (CENF-01, CENF-03):** When a phase hits the REMEDIATE row in the gate table (score >= 7 but < `pass_threshold`, and `pass_threshold` > 7):

    **Remediation cycle mechanics:**
    ```
    remediation_cycle = 0
    current_score = alignment_score from initial return

    while current_score < pass_threshold AND remediation_cycle < 2:
      remediation_cycle += 1
      log: "Phase {N}: score {current_score}/10 below threshold {pass_threshold}. Remediation cycle {remediation_cycle}/2."
      append remediation_started event to event_log

      extract targeted_feedback from:
        - rating agent scorecard[] (per-criterion deductions)
        - judge concerns[]
        - verifier failures[]
        - diagnostic file "Path to 9.0/10" items

      re-spawn phase-runner with:
        existing_plan: true
        skip_research: true
        remediation_feedback: targeted_feedback (structured list of specific deficiencies)
        remediation_cycle: {remediation_cycle}
        pass_threshold: {pass_threshold}

      parse new return JSON
      new_score = new alignment_score

      append remediation_completed event with {cycle, old_score, new_score}
      generate updated diagnostic file (overwrites previous)

      if new_score >= pass_threshold:
        log: "Phase {N}: remediation successful. Score improved {current_score} -> {new_score}."
        current_score = new_score
        break
      else:
        current_score = new_score

    if current_score >= pass_threshold:
      PASS -- checkpoint, next phase
    else:
      log: "Phase {N}: remediation exhausted (2 cycles). Passing with force_incomplete."
      mark phase in state.json:
        force_incomplete: true
        diagnostic_path: ".autopilot/diagnostics/phase-{N}-confidence.md"
        remediation_cycles: {remediation_cycle}
      append force_incomplete_marked event to event_log
      PASS -- checkpoint, next phase (phase is NOT failed, progress is preserved)
    ```

    **Token cost:** Each remediation cycle costs approximately 60k tokens (targeted execute ~30k + verify ~20k + judge ~10k). Maximum additional cost per phase: ~120k tokens (2 cycles). For a 10-phase run, worst case adds up to 1.2M tokens.

    **CENF-03 behavior:** When remediation cycles exhaust without reaching `pass_threshold`, the phase is NOT failed. It passes at its current score but is marked `force_incomplete: true` in state.json with the diagnostic file path. This preserves progress while clearly documenting what could not be achieved autonomously. The user can review the diagnostic file and decide whether to address the remaining deficiencies manually.

### Status Decision Governance Checks

13. **Human-verify justification required (STAT-02):** If `status` is `"needs_human_verification"`:
    - The return MUST include a `human_verify_justification` object with a non-empty `checkpoint_task_id` field.
    - If `human_verify_justification` is missing, null, or has an empty `checkpoint_task_id`: REJECT. Log: "needs_human_verification returned without structured justification. Re-spawning."
    - The justification must identify the specific checkpoint task that triggered the human-verify status, not a generic reason like "it's a UI phase."

14. **Unnecessary deferral rejection (STAT-03, upgraded from warning):** If `status` is `"needs_human_verification"` AND `human_verify_justification.auto_tasks_passed` equals `human_verify_justification.auto_tasks_total` (all auto tasks passed) AND the `human_verify_justification.task_description` matches a generic visual confirmation pattern (contains "visual", "screenshot", "look", "appearance", "UI review", or "manual check" without specifying a concrete user workflow):
    - REJECT the deferral. Log: "Phase deferred to human with generic visual confirmation but all auto tasks passed. Rejecting deferral -- re-spawning phase-runner to return 'completed' instead."
    - Append an `unnecessary_deferral_warning` event to the event_log with the phase ID and checkpoint task description.
    - Re-spawn the phase-runner with `remediation_feedback: ["Return status as 'completed' instead of 'needs_human_verification'. All auto tasks passed. The generic visual confirmation checkpoint does not justify human deferral -- the verifier's autonomous verification (build checks, behavioral traces, code analysis) is sufficient."]` and `remediation_cycle: 1`.
    - If the task description references a specific user workflow (e.g., "verify payment flow processes a real transaction"), do NOT reject -- substantive human checkpoints with concrete workflows remain valid deferral reasons.

---

## 6. Context Management

### 6.1 Manager-Not-Worker Principle

The orchestrator is a **manager, not a worker**. It knows what is going on and where a project is in the pipeline, but it does NOT do detailed work itself. This is the PRIMARY context exhaustion prevention mechanism -- a lightweight orchestrator will never hit context limits.

**The orchestrator MUST NOT read detailed files directly.** This includes:
- Plan files (PLAN.md, RESEARCH.md)
- Source code or implementation files
- Full verification/judge reports (VERIFICATION.md, JUDGE-REPORT.md, SCORECARD.md)
- UAT reports, full test output, or build logs
- Full state.json dumps (use targeted reads for specific fields)

**All detailed analysis is delegated to sub-agents who return summaries.** If the orchestrator needs to assess UAT results, gap analysis, or any complex evaluation, it spawns a sub-agent that reads the files and returns a structured JSON summary (e.g., "phase 16: 5 issues, phase 17: 4 issues, summaries: [...]"). The orchestrator ingests ONLY the summary.

**What the orchestrator holds:** Phase names, scores, status, routing decisions, and JSON returns from phase-runners (~5-10 lines per phase). Nothing else.

### 6.2 Context Tracking (Observability Only)

There is no phase cap per session. The orchestrator's context stays minimal because it only reads JSON returns (~5-10 lines per phase).

**Context tracking is for observability only -- the orchestrator NEVER auto-stops work because of context percentage.** There is no hard context gate. If the orchestrator's context grows large, it indicates an architectural violation (the orchestrator is reading too much detail), not a budget limit that needs enforcement.

**Warning thresholds (non-blocking):**
- **70% estimated context:** Log warning: "Context at ~70%. If approaching limits, verify orchestrator is not reading detailed files directly."
- **90% estimated context:** Log warning: "Context at ~90%. Consider writing handoff file for safety. Verify manager-not-worker principle."

These warnings are advisory. Execution continues regardless. The orchestrator should self-check against the Manager-Not-Worker rules (Section 6.1) when warnings trigger.

**Handoff file (safety net, should be rare):** If the orchestrator ever needs to stop (e.g., approaching absolute limit), write `.autopilot/handoff-{timestamp}.md` with completed phases, next phase, and scores. Save state with current position. Compute the remaining (incomplete) phases from the execution queue and tell the user:

```
Context getting full. {N} phases completed so far. To continue, run:
  /clear
  /autopilot {remaining_phases}
```

Where `{remaining_phases}` is the space-separated list of incomplete phase IDs from the current run (e.g., `"7 8 9.1 10"`). This should be extremely rare if the manager-not-worker principle is followed.

### 6.3 Pre-Run Context Cost Estimation

When running `--quality` or `--force` on **multiple phases** (3+), the orchestrator estimates total context cost before beginning execution:

```
estimated_session_cost = sum(per_phase_estimated_tokens from MTRC-02) + orchestrator_overhead (10000 tokens per phase for JSON parsing and state updates)
estimated_session_budget = 180000 tokens (conservative estimate for orchestrator session)

if estimated_session_cost > 0.80 * estimated_session_budget:
  log warning: "Estimated cost ({estimated_session_cost} tokens) exceeds 80% of session budget. Consider splitting into smaller batches. If context runs out mid-session, run /clear then /autopilot {second_half}."
```

This is a WARNING only. Execution proceeds regardless. The warning helps users avoid sessions that are likely to approach context limits.

### 6.4 Compression Heuristic

When context grows (tracked via warning thresholds), compress prior phase records to single-line entries. Never artificially limit the number of phases. Compression format: `"Phase {N}: {status} ({score}/10)"` -- replacing the full JSON return stored in memory.

---

## 7. State File Updates

### 7.0 Incremental Edit Requirement (CTXE-02)

State.json updates MUST use incremental Edit() operations for targeted field changes, NOT full-file Write() rewrites. Each state update should consume fewer than 20 lines of context instead of 150+ from a full-file rewrite.

**Why:** Full-file Write() of state.json generates a diff of the ENTIRE file (often 150+ lines), which is ingested into the orchestrator's context. After just 2 state updates via Write(), the orchestrator has consumed ~300 lines of context on state management alone. Incremental Edit() targets only the changed field, producing a diff of fewer than 20 lines.

**How:** Use the Edit tool to update specific fields:
```
# Instead of: Write(state.json, full_json_content)
# Do: Edit(state.json, old_field_value, new_field_value)
#
# Example: Update phase status
Edit(state.json,
  old: '"phases": {"16": {"status": "running"',
  new: '"phases": {"16": {"status": "completed"'
)
```

**Exception:** The FIRST write of state.json (at run start) uses Write() since there is no existing content to Edit(). All subsequent updates use Edit().

After each phase, update `.autopilot/state.json`:

1. Backup `state.json` to `state.json.backup` before writing (use file copy, not re-read).
2. `phases.{N}.status` = `"completed"` or `"failed"` or `"needs_human_verification"`.
3. `phases.{N}.completed_at` = ISO timestamp.
4. Store `alignment_score` (decimal x.x format, from rating agent), `commit_shas`, `debug_attempts`, `replan_attempts`, `checkpoint_sha`, `automated_checks` from return JSON.
5. `_meta.current_phase` = next phase ID. `_meta.last_checkpoint` = now.
6. `last_checkpoint_sha` = `git rev-parse HEAD`.
7. Append `phase_completed` event to `event_log`.
8. Update `_meta.human_deferred_count` and `_meta.total_phases_processed` counters (see Section 2, Human-Defer Rate Tracking).
9. **Confidence enforcement fields (CENF-03):** If the phase was remediated or passed with `force_incomplete`:
   - `phases.{N}.force_incomplete` = `true` if remediation exhausted without reaching `pass_threshold`, `false` otherwise.
   - `phases.{N}.diagnostic_path` = `".autopilot/diagnostics/phase-{N}-confidence.md"` if a diagnostic file was generated, `null` otherwise.
   - `phases.{N}.remediation_cycles` = number of remediation cycles run (0 if none).
10. **Score history (CLI quality flags):** When any quality flag (`--force`, `--quality`, `--gaps`) causes a phase to be re-evaluated:
    - Before updating `alignment_score`, append the current score to `phases.{N}.score_history` array:
      ```json
      {
        "score": 8.2,
        "timestamp": "ISO-8601",
        "flag": "force|quality|gaps|initial",
        "cycle": 0
      }
      ```
    - The `score_history` array preserves the full scoring trajectory for trend tracking.
    - On initial phase completion (no flags), the first entry has `flag: "initial"` and `cycle: 0`.
    - After flag execution, `alignment_score` reflects the latest score; `score_history` contains all prior scores.
11. **Quality/gaps exhaustion fields:** If `--quality` or `--gaps` exhausted their remediation budget:
    - `phases.{N}.quality_exhausted` = `true` if `--quality` exhausted 3 cycles without reaching 9.5.
    - `phases.{N}.gaps_exhausted` = `true` if `--gaps` exhausted 5 iterations without reaching 9.5+.
    - These flags are informational -- they do NOT indicate failure.

---

## 8. Resume Protocol

When user types `/autopilot resume`:

1. Read `.autopilot/state.json` (fallback: `.json.backup`). No file = "No run found."
2. `"completed"` -> "Already finished. Start new with `/clear` then `/autopilot <phases>`."
3. `"failed"` -> Retry the failed phase automatically. If it fails again, skip it and continue to next.
4. `"running"` -> Interrupted. Find last completed phase, resume from next.
5. Verify spec hash. If changed, log warning and continue (spec changes mid-run are the user's responsibility).
6. **HANDOFF.md detection (CTXE-01):** Before resuming any phase, check for HANDOFF.md files in phase directories. For each phase that will be re-executed (failed or interrupted):
   - Glob for `.planning/phases/{phase}/HANDOFF.md`.
   - If found: Read the HANDOFF.md file to determine partial progress -- which tasks were completed, which remain, and what files were modified. Log: "Phase {N}: HANDOFF.md detected. Resuming from partial progress ({completed_tasks}/{total_tasks} tasks completed)."
   - Re-spawn the phase-runner with `remediation_feedback` set to ONLY the remaining tasks from the handoff file (the `tasks_remaining` list), and `existing_plan: true`, `skip_research: true`. This resumes from the handoff point rather than re-executing the entire phase from scratch.
   - If NOT found: Resume the phase normally (full re-execution for failed phases, next phase for interrupted runs).
7. Show 2-line status, then enter loop (Section 2) at resume point. No confirmation.

---

## 9. Completion Protocol

When all target phases are done:

1. **Integration check**: Spawn general-purpose agent to verify cross-phase wiring (imports, no orphaned code, E2E flows). Read pass/fail JSON.

2. **Self-audit against requirements**: After the integration check passes and before the version bump, spawn a self-audit agent to verify that the actual implementation satisfies the frozen spec requirements -- not trusting phase-runner self-reported results. This catches requirement-level gaps that per-phase verification misses (plan-level verification confirms "did the executor follow the plan?" but NOT "does the implementation satisfy the original requirements?").

   Append a `self_audit_started` event to the event_log before spawning the agent.

   **Self-audit agent spawn:** Spawn a general-purpose subagent with the following prompt:

   > You are a post-completion self-audit agent. Your job is to verify that implementation files satisfy the frozen spec requirements -- independently of what phase-runners reported.
   >
   > **Frozen spec:** {spec_path}
   > **Completed phases in this run:** {list of phase IDs with their directories}
   > **State file:** `.autopilot/state.json` (for phase status and alignment scores)
   >
   > <must>
   > 1. Read the frozen spec at {spec_path}. Extract ALL requirements with their IDs, descriptions, and phase mappings.
   > 2. For each completed phase in this run (status == "completed" in state.json), read its PLAN.md to get acceptance criteria and the files that were modified.
   > 3. For each requirement mapped to a completed phase, verify compliance by reading the actual implementation files:
   >    - Run the acceptance criteria verification commands (grep patterns, file existence checks) against the current codebase
   >    - Check for cross-file consistency (e.g., if a schema is defined in one file and referenced in another, verify both match)
   >    - Check for spec violations (e.g., PRMT-01 max 7 MUST items -- count actual MUST items in the executor prompt)
   > 4. Produce a structured audit report as JSON (see Return JSON below). For each requirement: record the requirement ID, what was expected, what was actually found (with file:line evidence), and status (pass or gap). For gaps: include a specific description of what is missing or wrong.
   > 5. Classify each gap by fix complexity:
   >    - "small": Single file edit, pattern insertion/correction, < 20 lines changed
   >    - "large": Multi-file changes, logic modifications, or cross-cutting concerns
   > </must>
   >
   > <should>
   > 1. Prioritize checking requirements that are cross-cutting (referenced by multiple phases) -- these are most likely to have inconsistencies
   > 2. Spot-check at least one requirement per completed phase by reading the actual file, not just running grep
   > 3. Check for cross-phase inconsistencies (e.g., a field added to the return contract in the orchestrator but missing from the schemas reference)
   > </should>
   >
   > Return JSON:
   > ```json
   > {
   >   "audit_results": [
   >     {
   >       "phase_id": "N",
   >       "requirements_checked": [
   >         {
   >           "requirement_id": "REQ-XX",
   >           "expected": "description of what spec requires",
   >           "actual_found": "what was found in implementation files",
   >           "file_line_evidence": "filepath:lineN -- quote or description",
   >           "status": "pass|gap",
   >           "gap_description": "what is missing or wrong (null if pass)",
   >           "fix_complexity": "small|large|null"
   >         }
   >       ]
   >     }
   >   ],
   >   "aggregate": {
   >     "total_requirements_checked": N,
   >     "passed_on_first_check": N,
   >     "gaps_found": N,
   >     "gap_details": [
   >       {
   >         "requirement_id": "REQ-XX",
   >         "phase_id": "N",
   >         "gap_description": "string",
   >         "fix_complexity": "small|large",
   >         "suggested_fix": "specific description of what to change"
   >       }
   >     ]
   >   }
   > }
   > ```

   **Gap-fix routing:** After the self-audit agent returns:

   - If `gaps_found == 0`: Log "Self-audit: all {total} requirements passed. No gaps found." Append a `self_audit_completed` event to the event_log with the aggregate counts. Proceed to step 3.
   - If `gaps_found > 0`: For each gap, append a `self_audit_gap_found` event to the event_log with the requirement_id and gap_description. Then process each gap:
     - **Small fix** (`fix_complexity == "small"`): Spawn a general-purpose agent with the gap description and suggested fix. The agent makes the edit and commits with message: `fix(audit): close {requirement_id} gap -- {1-line description}`. Log: "Self-audit: fixing small gap for {requirement_id}."
     - **Large fix** (`fix_complexity == "large"`): Spawn a targeted executor (gsd-executor) with the gap as a single-task plan. The executor follows standard compile/lint/commit protocol. Log: "Self-audit: routing large gap for {requirement_id} to executor."
   - After ALL gap fixes are applied, append a `self_audit_gap_fixed` event per fixed gap to the event_log.

   **Re-verification loop:** After gap fixes are applied, re-run the self-audit agent on ONLY the requirements that had gaps (pass the `gap_details` array as the scope). The re-audit agent uses the same prompt but with an additional instruction:

   > **RE-AUDIT SCOPE:** You are re-verifying ONLY the following requirements after gap fixes were applied: {list of requirement_ids}. Check ONLY these requirements. Confirm each gap is closed with file:line evidence.

   - If re-audit finds all gaps closed: Log "Self-audit re-verification: all {N} gaps confirmed fixed." Proceed to step 3.
   - If re-audit finds remaining gaps AND this is re-audit cycle 1: Apply fixes and re-audit once more (cycle 2).
   - If re-audit finds remaining gaps AND this is re-audit cycle 2: Log "Self-audit: {N} gaps could not be auto-fixed after 2 cycles. Reporting as remaining." Proceed to step 3 with remaining gaps noted.
   - **Maximum 2 re-audit cycles.** Do not loop beyond 2.
   - After the re-verification loop completes (whether all gaps are fixed or max cycles exhausted), append a `self_audit_completed` event to the event_log with aggregate counts (total_checked, passed, gaps_found, gaps_fixed, gaps_remaining).

   **Self-audit results for completion report:** Store the following for inclusion in the completion report (step 4):
   ```json
   {
     "self_audit": {
       "total_requirements_checked": N,
       "passed_on_first_check": N,
       "gaps_found": N,
       "gaps_fixed": N,
       "gaps_remaining": N,
       "remaining_gap_details": [{"requirement_id": "REQ-XX", "description": "string"}],
       "audit_cycles": N,
       "fix_commits": ["sha1", "sha2"]
     }
   }
   ```

3. **Version bump**: Read `CLAUDE.md` for versioning rules. Bump version in `package.json`, `VERSION`, and `CHANGELOG.md` based on the highest phase completed in this run:
   - Integer phase (e.g., 4, 5) -> minor bump (reset patch to 0)
   - Decimal phase only (e.g., 3.1, 4.1) -> patch bump
   - Commit with message: `chore: bump to vX.Y.Z after phase N`
4. **Report**: Write `.autopilot/completion-{date}.md` (phase table, integration status, self-audit results, stats). The report MUST include a "## Self-Audit Results" section containing:
   - Total requirements checked
   - Requirements passed on first check
   - Gaps found (with requirement IDs and descriptions)
   - Gaps fixed (with fix commit SHAs)
   - Gaps remaining (if any could not be auto-fixed)
   - Number of audit cycles run
5. **Metrics collection (MTRC-01)**: Aggregate run-level metrics from `state.json`:
   - `phases_attempted`: Count all phases in `phases` object that have a `started_at` timestamp
   - `phases_succeeded`: Count phases with `status == "completed"` and `alignment_score >= 7`
   - `phases_failed`: Count phases with `status == "failed"`
   - `phases_human_deferred`: Count phases with `status == "needs_human_verification"`
   - `failure_taxonomy_histogram`: Iterate the `event_log` for events with `failure_categories` data (from verifier and debugger returns). Build an object mapping each failure category to its count across all phases. Example: `{"executor_incomplete": 2, "lint_failure": 1}`
   - `avg_alignment_score`: Compute the arithmetic mean of all phase `alignment_score` values (decimal, from rating agent returns). Exclude null scores (skipped phases). Result uses decimal precision (x.x format).
   - `total_duration_minutes`: Compute `(current_timestamp - _meta.started_at)` in minutes
   - `total_estimated_tokens`: Sum `estimated_tokens` from all phase records (from MTRC-02 pre-spawn estimates)
   - `total_debug_loops`: Sum `debug_attempts` from all phase records
   - `total_replan_attempts`: Sum `replan_attempts` from all phase records
   - `success_rate`: `phases_succeeded / phases_attempted`
   - `per_phase_summary`: Array of `{phase_id, status, alignment_score, estimated_tokens, duration_minutes}` for each phase
6. **Metrics persistence (MTRC-01)**: Read `.autopilot/archive/metrics.json`. If the file does not exist, start with an empty array `[]`. Append the current run's metrics object (using the schema from autopilot-schemas.md Section 8) to the array. Write the updated array back to `.autopilot/archive/metrics.json`. Use `run_id` from `_meta.run_id` and set `timestamp` to the current ISO-8601 time.
7. **Trend comparison (MTRC-03)**: After writing metrics.json, compare the current run against historical data:
   - If metrics.json has only 1 entry (first run): Skip trend comparison. Log: "First run recorded. Trend analysis available after 2+ runs."
   - If metrics.json has >= 2 entries: Compute trend summary by comparing current run (last entry) vs previous run (second-to-last entry):
     - `success_rate_delta`: current `success_rate` minus previous `success_rate` (positive = improvement)
     - `avg_alignment_delta`: current `avg_alignment_score` minus previous `avg_alignment_score`
     - `estimated_cost_delta`: current `total_estimated_tokens` minus previous `total_estimated_tokens` (negative = cheaper)
     - `recurring_failures`: failure categories that appear in BOTH current and previous run's `failure_taxonomy_histogram`
   - Compute historical aggregates across ALL runs in the array:
     - `success_rate`: min, max, avg
     - `avg_alignment`: min, max, avg
     - `total_cost`: min, max, avg
   - Append a "## Trend Analysis" section to the completion report (`.autopilot/completion-{date}.md`) with: deltas, recurring failures, and historical min/max/avg
   - If success rate decreased from previous run, log warning: "Warning: Success rate decreased from {prev}% to {curr}%. Check failure histogram for recurring issues."
8. **Archive**: Move `state.json` to `.autopilot/archive/run-{id}.json`.
9. **Announce**: Show the user a completion summary. The announcement MUST include:

   ```
   Autopilot Complete

   Phases: {succeeded}/{attempted} succeeded | {failed} failed | {skipped} skipped
   Avg alignment: {avg_alignment}/10
   Duration: {total_duration_minutes}m
   Report: .autopilot/completion-{date}.md

   {If any phases remain incomplete or were not in this run's target range:}
   Remaining phases: {list of incomplete phase IDs}
   To continue: /clear then /autopilot {remaining_phase_range}

   {If all project phases are complete:}
   All phases complete. Project is done.
   ```

   **CRITICAL:** Any time the announcement suggests running `/autopilot`, it MUST be prefixed with `/clear` (e.g., "/clear then /autopilot 8-12"). The user needs a fresh context window for the next run. Never output a bare `/autopilot <phases>` suggestion without `/clear` before it.

   Run task completion notification if available.

### Aggregated Completion Report for --complete Mode (CMPL-04)

When the run was invoked with `--complete`, write an aggregated completion report to `.autopilot/completion-report.md` BEFORE the standard `completion-{date}.md` report (step 4 above). This report provides a project-level view of what `--complete` accomplished.

**Completion report generation:**

1. **Collect phase results** from `state.json`:
   - `phases_attempted`: All phases that were executed in this run
   - `phases_succeeded`: Phases with `status == "completed"` and `alignment_score >= 7`
   - `phases_failed`: Phases with `status == "failed"` -- include failure reason from postmortem
   - `phases_skipped`: Phases skipped for any reason -- include reason per phase:
     - `"already_completed"`: Phase was completed in a prior run
     - `"blocked_by_phase_{N}"`: Phase was blocked by a failed dependency
   - `phases_deferred`: Phases with `status == "needs_human_verification"`

2. **Identify dependency gaps**: For each failed phase, list all phases that were blocked as a result. Format as a dependency gap chain: "Phase {N} failed -> blocked: Phase {A}, Phase {B}, Phase {C}".

3. **Compute overall project completion percentage**:
   ```
   total_phases = count of all phases in roadmap
   completed_phases = count of phases with status "completed" in state.json (across all runs)
   completion_percentage = (completed_phases / total_phases) * 100
   ```

4. **Write `.autopilot/completion-report.md`** with this structure:
   ```markdown
   # Batch Completion Report

   **Run ID:** {run_id}
   **Date:** {ISO-8601}
   **Mode:** --complete
   **Project completion:** {completion_percentage}% ({completed_phases}/{total_phases} phases)

   ## Phases Attempted
   | Phase | Status | Alignment | Duration | Notes |
   |-------|--------|-----------|----------|-------|
   | {id} | {status} | {score}/10 | {min}m | {notes} |

   ## Phases Skipped
   | Phase | Reason |
   |-------|--------|
   | {id} | {reason} |

   ## Dependency Gaps
   {For each failed phase with blocked dependents:}
   - **Phase {N} failed** -> Blocked: {list of blocked phase IDs and names}

   ## Summary
   - Attempted: {N}
   - Succeeded: {N}
   - Failed: {N}
   - Skipped (already done): {N}
   - Skipped (blocked): {N}
   - Deferred to human: {N}

   ## Next Steps
   {If incomplete phases remain:}
   To continue: `/clear` then `/autopilot {remaining_phase_range}`
   {If all phases complete:}
   All phases complete. Project is done.
   ```

5. This report is written in ADDITION to the standard `completion-{date}.md` report, not as a replacement.
