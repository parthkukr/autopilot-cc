# Autopilot Orchestrator Guide

You are a loop. For each phase: spawn a phase-runner, wait for its JSON return, log the result, spawn the next one. You do NOT read code, research, or plans. You do NOT make decisions about the project. You do NOT ask the user questions during execution. If a phase-runner returns "failed", log it and move to the next phase (unless it is a dependency blocker). The user already told you what to do by invoking the command.

---

## 1. Invocation

When the user types `/autopilot <phases>`:

1. **Resume check**: Read `.autopilot/state.json`. If it exists and `_meta.status` != `"completed"`, resume automatically (Section 8).
2. **Parse phases**: `"3-7"` = range, `"3"` = single, `"3,5,8"` = list, `"all"` = all incomplete, `"next"` = next one.
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

## 2. The Loop

For each phase in the target range:

```
for each phase in target_phases:
  pre-spawn check (auto-skip if already verified)
  spawn phase-runner(phase) → wait for JSON return
  if return.status == "completed": log, next phase
  if return.status == "needs_human_verification": log, skip to next phase (come back later)
  if return.status == "failed": log diagnostic (postmortem at .autopilot/diagnostics/phase-{N}-postmortem.json), continue to next phase if independent, halt if dependent
```

That is the entire loop. No gates, no extra validation, no asking.

### Human-Defer Rate Tracking (STAT-04)

The orchestrator maintains two counters across the loop: `human_deferred_count` (phases returning `needs_human_verification`) and `total_phases_processed` (all phases that received a return, regardless of status). Both start at 0 at run start.

After each phase return:
1. Increment `total_phases_processed`.
2. If `status` is `"needs_human_verification"`, increment `human_deferred_count`.
3. Compute `defer_rate = human_deferred_count / total_phases_processed`.
4. If `defer_rate > 0.50` AND `total_phases_processed >= 2`: Log warning: "High human-defer rate ({human_deferred_count}/{total_phases_processed}). Pipeline may be avoiding autonomous completion." Append a `high_defer_rate_warning` event to the event_log.

These counters persist in `state.json` (see Section 7) so they survive resume operations.

### Pre-Spawn Checks (Automatic, No User Input)

Before spawning the phase-runner for phase N:
1. Glob for `VERIFICATION.md` in this phase's directory. If it exists:
   1. Read the first 5 lines to extract the `verified:` timestamp
   2. Check if the timestamp is from the CURRENT run (compare with `_meta.started_at` in state.json)
   3. If same run AND shows all checks passing: skip. Log: "Phase {N} already verified in this run -- skipping."
   4. If different run: do NOT skip. Log: "Phase {N} has stale verification from prior run -- re-running."
2. Glob for `EXECUTION-LOG.md` in this phase's directory. If it exists, pass `prior_execution_exists: true` to the phase-runner.

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
2. Spawn **phase-runner** (Section 3). Wait for completion (`run_in_background: false`).
3. Parse the **return JSON** from the phase-runner's response (last lines).
4. **Handle human verification**: If the phase-runner returns `status: "needs_human_verification"`, log it with `human_verify_justification` details, skip to next phase, and continue. Come back to these at the end of the run.
5. **Gate decision** (Section 5).
6. **Update state** (Section 7).
7. Log: `Phase {N} complete. Alignment: {score}/10. Progress: {done}/{total}.`

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
- HALT the run immediately and output: "autopilot-phase-runner agent not found. Restart Claude Code (agent types are discovered at session startup)."
- Save state so the user can `/autopilot resume` after restarting.

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
> **ENFORCEMENT: Verify and judge steps MUST spawn independent subagents. Self-assessment is rejected by the orchestrator.**
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

- **ui**: Phase modifies files in the configured `project.ui.source_dir` or any frontend code. Requires: (1) compile check (`project.commands.compile`), (2) production build (`project.commands.build`), (3) mandatory human-verify checkpoint if not already in plan.
- **protocol**: Phase modifies `.md` files in `protocols/`, project instructions, or agent definitions. Requires: (1) cross-reference check (no broken links between protocol files), (2) contract verification (schemas match what orchestrator expects).
- **data**: Phase modifies JSON data files or similar structured data. Requires: (1) JSON validity check, (2) schema compliance check.
- **mixed**: Combination of above. Apply ALL relevant requirements.

For **ui** phases: If the plan has 0 `checkpoint:human-verify` tasks, the orchestrator MUST add this to the spawn prompt:
> **INJECTED REQUIREMENT: This is a UI phase. You MUST include a checkpoint:human-verify task at the end of your plan for visual confirmation. Return status as "needs_human_verification" after completing auto tasks.**

---

## 4. Phase-Runner Return Contract

The canonical return contract is defined here. The phase-runner returns this JSON as the last lines of its response.

```json
{
  "phase": "{phase_id}",
  "status": "completed|failed|needs_human_verification",
  "alignment_score": <1-10 or null>,
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
  "pipeline_steps": {
    "preflight": {"status": "pass|fail|skipped", "agent_spawned": false},
    "triage": {"status": "full_pipeline|verify_only", "agent_spawned": false, "pass_ratio": 0.0},
    "research": {"status": "completed|skipped", "agent_spawned": true|false, "skip_reason": "string|null"},
    "plan": {"status": "completed|skipped", "agent_spawned": true|false, "skip_reason": "string|null"},
    "plan_check": {"status": "pass|fail|skipped", "agent_spawned": true, "confidence": 8},
    "execute": {"status": "completed|partial|skipped", "agent_spawned": true},
    "verify": {"status": "pass|fail|skipped", "agent_spawned": true},
    "judge": {"status": "pass|fail|skipped", "agent_spawned": true}
  }
}
```

**Field notes:**
- `verification_duration_seconds` is the wall-clock time the verifier agent ran, recorded by the phase-runner. Used by Check 10 (VRFY-03) for rubber-stamp detection. Set to `null` if verification was skipped.
- `evidence` is NEW. Contains concrete proof of work. The judge uses this for independent verification. If `commit_shas` is empty (already-implemented claim), `evidence.files_checked` MUST list file:line evidence for each acceptance criterion.
- `human_verify_justification` is REQUIRED when `status` is `"needs_human_verification"`. Omit or set to `null` for other statuses. The orchestrator rejects any `needs_human_verification` return that lacks this field (see Section 5, Check 13).
- `pipeline_steps` uses ONE canonical shape: `{status, agent_spawned}` plus optional `confidence` (plan_check only), `skip_reason` (research/plan only), and `pass_ratio` (triage only). No `ran` field. No alternative schemas.
- `automated_checks` includes `build` to distinguish compilation (`compile` = configured compile command) from production build (`build` = configured build command). Actual commands are read from `project.commands` in `.planning/config.json`.

Parse from the **last lines** of the phase-runner's response. If missing, spawn a small agent to extract it.

---

## 5. Gate Logic

The orchestrator's gate logic is deliberately simple. The phase-runner handles ALL internal retries (debug loops, replans). If the phase-runner returns a result, the orchestrator makes a binary decision:

| Condition | Action |
|-----------|--------|
| `status=="completed"` AND `alignment_score>=7` (this is the JUDGE's score) AND `recommendation=="proceed"` | **PASS** -- checkpoint, next phase |
| `status=="needs_human_verification"` | **SKIP** -- log human_verify_justification, continue to next phase, revisit at end of run |
| `status=="failed"` AND phase is independent (no later phases depend on it) | **LOG + CONTINUE** -- note `.autopilot/diagnostics/phase-{N}-postmortem.json` for inspection, move to next phase |
| `status=="failed"` AND later phases depend on it | **HALT** -- note `.autopilot/diagnostics/phase-{N}-postmortem.json` for inspection, notify user, suggest `/autopilot resume` |
| `recommendation=="rollback"` | **ROLLBACK** -- `git revert` to last checkpoint, diagnostic, halt |

**CRITICAL: The orchestrator does NOT re-spawn failed phase-runners.** The phase-runner already exhausted its internal retry budget (max 3 debug attempts, max 1 replan). If it returns `failed`, the issue requires human intervention. But if the failed phase is independent, keep running remaining phases.

On HALT/ROLLBACK: set state `status:"failed"`, note that the phase-runner has written a structured post-mortem to `.autopilot/diagnostics/phase-{N}-postmortem.json` (OBSV-04), tell user `/autopilot resume`.

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

4. **Verify/Judge agent enforcement:** If `tasks_completed` shows completed auto tasks (N > 0 in "N/total"):
   - `pipeline_steps.verify.agent_spawned` MUST be `true`
   - `pipeline_steps.judge.agent_spawned` MUST be `true`
   - If EITHER is `false`: REJECT the return. Log: "Self-verification not accepted for phases with auto tasks. Re-spawning with enforcement flag."
   - Re-spawn the phase-runner with an additional line in the prompt: `**ENFORCEMENT: You MUST spawn independent verify and judge agents. Self-assessment will be rejected.**`
   - Maximum 1 enforcement re-spawn per phase. If the second attempt also returns `agent_spawned: false`, mark phase as failed.

5. **Rubber-stamp detection:** After every 3rd consecutive phase completion, check if all alignment scores are identical (e.g., all 9/10):
   - If 3+ consecutive phases have the SAME alignment_score: Log warning: "Uniform alignment scores detected ({score}/10 x {count} phases). Possible rubber-stamping."
   - This is a WARNING, not a rejection — but it should be logged in the event_log and shown to the user at the end.

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

### Status Decision Governance Checks

13. **Human-verify justification required (STAT-02):** If `status` is `"needs_human_verification"`:
    - The return MUST include a `human_verify_justification` object with a non-empty `checkpoint_task_id` field.
    - If `human_verify_justification` is missing, null, or has an empty `checkpoint_task_id`: REJECT. Log: "needs_human_verification returned without structured justification. Re-spawning."
    - The justification must identify the specific checkpoint task that triggered the human-verify status, not a generic reason like "it's a UI phase."

14. **Unnecessary deferral warning (STAT-03):** If `status` is `"needs_human_verification"` AND `human_verify_justification.auto_tasks_passed` equals `human_verify_justification.auto_tasks_total` (all auto tasks passed) AND the `human_verify_justification.task_description` matches a generic visual confirmation pattern (contains "visual", "screenshot", "look", "appearance", "UI review", or "manual check" without specifying a concrete user workflow):
    - Log warning: "Phase deferred to human with no auto-task failures -- consider if human verification is necessary."
    - Append an `unnecessary_deferral_warning` event to the event_log with the phase ID and checkpoint task description.
    - This is a WARNING, not a rejection -- the phase still proceeds as `needs_human_verification`. The warning is surfaced in the completion report to help users identify phases that could be made fully autonomous.
    - If the task description references a specific user workflow (e.g., "verify payment flow processes a real transaction"), do NOT warn -- substantive human checkpoints are valid.

---

## 6. Context Management

There is no phase cap per session. The orchestrator's context stays minimal because it only reads JSON returns (~5-10 lines per phase). Monitor actual context usage -- if it exceeds 40%, compress prior phase records to single-line entries. Never artificially limit the number of phases.

When stopping for context (40% threshold hit):
1. Write `.autopilot/handoff-{timestamp}.md` (completed phases, next phase, scores).
2. Save state with current position.
3. Tell user: `"Context threshold reached. {N} done. Run /autopilot resume for Phase {next}."`

---

## 7. State File Updates

After each phase, update `.autopilot/state.json`:

1. Backup `state.json` to `state.json.backup` before writing.
2. `phases.{N}.status` = `"completed"` or `"failed"` or `"needs_human_verification"`.
3. `phases.{N}.completed_at` = ISO timestamp.
4. Store `alignment_score`, `commit_shas`, `debug_attempts`, `replan_attempts`, `checkpoint_sha`, `automated_checks` from return JSON.
5. `_meta.current_phase` = next phase ID. `_meta.last_checkpoint` = now.
6. `last_checkpoint_sha` = `git rev-parse HEAD`.
7. Append `phase_completed` event to `event_log`.
8. Update `_meta.human_deferred_count` and `_meta.total_phases_processed` counters (see Section 2, Human-Defer Rate Tracking).

---

## 8. Resume Protocol

When user types `/autopilot resume`:

1. Read `.autopilot/state.json` (fallback: `.json.backup`). No file = "No run found."
2. `"completed"` -> "Already finished. Start new with `/autopilot <phases>`."
3. `"failed"` -> Retry the failed phase automatically. If it fails again, skip it and continue to next.
4. `"running"` -> Interrupted. Find last completed phase, resume from next.
5. Verify spec hash. If changed, log warning and continue (spec changes mid-run are the user's responsibility).
6. Show 2-line status, then enter loop (Section 2) at resume point. No confirmation.

---

## 9. Completion Protocol

When all target phases are done:

1. **Integration check**: Spawn general-purpose agent to verify cross-phase wiring (imports, no orphaned code, E2E flows). Read pass/fail JSON.

2. **Self-audit against requirements**: After the integration check passes and before the version bump, spawn a self-audit agent to verify that the actual implementation satisfies the frozen spec requirements -- not trusting phase-runner self-reported results. This catches requirement-level gaps that per-phase verification misses (plan-level verification confirms "did the executor follow the plan?" but NOT "does the implementation satisfy the original requirements?").

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

   - If `gaps_found == 0`: Log "Self-audit: all {total} requirements passed. No gaps found." Proceed to step 3.
   - If `gaps_found > 0`: Process each gap:
     - **Small fix** (`fix_complexity == "small"`): Spawn a general-purpose agent with the gap description and suggested fix. The agent makes the edit and commits with message: `fix(audit): close {requirement_id} gap -- {1-line description}`. Log: "Self-audit: fixing small gap for {requirement_id}."
     - **Large fix** (`fix_complexity == "large"`): Spawn a targeted executor (gsd-executor) with the gap as a single-task plan. The executor follows standard compile/lint/commit protocol. Log: "Self-audit: routing large gap for {requirement_id} to executor."
   - After ALL gap fixes are applied, append a `self_audit_gaps_fixed` event to the event_log.

   **Re-verification loop:** After gap fixes are applied, re-run the self-audit agent on ONLY the requirements that had gaps (pass the `gap_details` array as the scope). The re-audit agent uses the same prompt but with an additional instruction:

   > **RE-AUDIT SCOPE:** You are re-verifying ONLY the following requirements after gap fixes were applied: {list of requirement_ids}. Check ONLY these requirements. Confirm each gap is closed with file:line evidence.

   - If re-audit finds all gaps closed: Log "Self-audit re-verification: all {N} gaps confirmed fixed." Proceed to step 3.
   - If re-audit finds remaining gaps AND this is re-audit cycle 1: Apply fixes and re-audit once more (cycle 2).
   - If re-audit finds remaining gaps AND this is re-audit cycle 2: Log "Self-audit: {N} gaps could not be auto-fixed after 2 cycles. Reporting as remaining." Proceed to step 3 with remaining gaps noted.
   - **Maximum 2 re-audit cycles.** Do not loop beyond 2.

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
   - `avg_alignment_score`: Compute the arithmetic mean of all phase `alignment_score` values (from judge returns). Exclude null scores (skipped phases).
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
9. **Announce**: Show summary. Run task completion notification if available.
