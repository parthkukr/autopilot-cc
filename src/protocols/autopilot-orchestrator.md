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

---

## 2. The Loop

For each phase in the target range:

```
for each phase in target_phases:
  pre-spawn check (auto-skip if already verified)
  spawn phase-runner(phase) → wait for JSON return
  if return.status == "completed": log, next phase
  if return.status == "needs_human_verification": log, skip to next phase (come back later)
  if return.status == "failed": log diagnostic, continue to next phase if independent, halt if dependent
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
5. Feed the verdict into the learnings loop (Phase 6, LRNG-04) for confidence calibration: if humans consistently pass phases the system deferred, subsequent runs should increase autonomous completion confidence. If humans consistently find issues, the system should tighten its own quality checks. The actual calibration logic is implemented in Phase 6 -- this step only records the verdict data.

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
| `status=="failed"` AND phase is independent (no later phases depend on it) | **LOG + CONTINUE** -- write diagnostic, move to next phase |
| `status=="failed"` AND later phases depend on it | **HALT** -- write diagnostic to `.autopilot/diagnostics/`, notify user, suggest `/autopilot resume` |
| `recommendation=="rollback"` | **ROLLBACK** -- `git revert` to last checkpoint, diagnostic, halt |

**CRITICAL: The orchestrator does NOT re-spawn failed phase-runners.** The phase-runner already exhausted its internal retry budget (max 3 debug attempts, max 1 replan). If it returns `failed`, the issue requires human intervention. But if the failed phase is independent, keep running remaining phases.

On HALT/ROLLBACK: set state `status:"failed"`, write diagnostic, tell user `/autopilot resume`.

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
2. **Version bump**: Read `CLAUDE.md` for versioning rules. Bump version in `package.json`, `VERSION`, and `CHANGELOG.md` based on the highest phase completed in this run:
   - Integer phase (e.g., 4, 5) → minor bump (reset patch to 0)
   - Decimal phase only (e.g., 3.1, 4.1) → patch bump
   - Commit with message: `chore: bump to vX.Y.Z after phase N`
3. **Report**: Write `.autopilot/completion-{date}.md` (phase table, integration status, stats).
4. **Archive**: Move `state.json` to `.autopilot/archive/run-{id}.json`.
5. **Announce**: Show summary. Run task completion notification if available.
