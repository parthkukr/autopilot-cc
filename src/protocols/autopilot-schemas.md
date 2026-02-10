# Autopilot Schemas Reference (Developer Documentation)

> **This file is NOT read by any agent.** It is reference documentation for developers
> maintaining the autopilot system. Agents read `__INSTALL_BASE__/autopilot/protocols/autopilot-orchestrator.md` (return contract)
> and `__INSTALL_BASE__/autopilot/protocols/autopilot-playbook.md` (step prompts). Changes to contracts MUST be made in those
> files first, then mirrored here for reference.

---

## Table of Contents

1. [State File Schema](#section-1-state-file-schema)
2. [Circuit Breaker Configuration](#section-2-circuit-breaker-configuration)
3. [Event Types](#section-3-event-types)
4. [Directory Structure](#section-4-directory-structure)
5. [Step Agent Handoff Protocol](#section-5-step-agent-handoff-protocol)
6. [Trace and Post-Mortem Schemas](#section-6-trace-and-post-mortem-schemas)
7. [Learnings File Schema](#section-7-learnings-file-schema)
8. [Metrics and Cost Schemas](#section-8-metrics-and-cost-schemas)
9. [Self-Audit Schemas](#section-9-self-audit-schemas)

---

## Section 1: State File Schema

**File:** `.autopilot/state.json`
**Created by:** Orchestrator at run start
**Updated by:** Orchestrator after every step transition and checkpoint
**Read by:** Orchestrator on resume, diagnostic tools, monitoring

This is the single source of truth for a run. If the orchestrator crashes and restarts, it reads this file to determine exactly where to resume.

```jsonc
{
  // ─── Metadata ─────────────────────────────────────────────────────────
  "_meta": {
    "version": "1.0",
    "run_id": "run-2026-02-09-143052",
    "started_at": "2026-02-09T14:30:52Z",
    "last_checkpoint": "2026-02-09T16:45:12Z",
    "status": "running",
    "total_phases": 14,
    "current_phase": "6.3",
    "current_step": "execute",
    "orchestrator_context_pct": 35,
    "human_deferred_count": 0,        // STAT-04: phases returning needs_human_verification
    "total_phases_processed": 0       // STAT-04: total phases processed (for defer-rate calc)
  },

  // ─── Spec Lock ────────────────────────────────────────────────────────
  "spec": {
    "path": ".planning/ROADMAP.md",
    "hash": "sha256:a1b2c3d4e5f6...",
    "locked_at": "2026-02-09T14:30:52Z"
  },

  "roadmap_path": ".planning/ROADMAP.md",

  // ─── Phase Records ────────────────────────────────────────────────────
  "phases": {
    "phase_6.1": {
      "phase_type": "ui|protocol|data|mixed",
      "status": "completed",
      "started_at": "2026-02-09T14:31:00Z",
      "completed_at": "2026-02-09T15:12:45Z",
      "steps": {
        "preflight": { "status": "pass", "timestamp": "2026-02-09T14:31:05Z" },
        "research": { "status": "completed", "output": ".planning/phases/6.1/RESEARCH.md", "hash": "sha256:b2c3d4e5f6a1..." },
        "plan": { "status": "completed", "output": ".planning/phases/6.1/PLAN.md", "hash": "sha256:c3d4e5f6a1b2...", "validation_rounds": 1 },
        "plan_check": { "status": "pass", "confidence": 9 },
        "execute": {
          "status": "completed",
          "tasks": {
            "task_01": { "status": "completed", "commit": "abc1234", "retries": 0 },
            "task_02": { "status": "completed", "commit": "def5678", "retries": 1 }
          }
        },
        "verify": {
          "status": "pass",
          "automated": { "compile": true, "tests": true, "lint": true },
          "alignment_score": 8,
          "scope_creep": []
        },
        "judge": { "alignment": 8, "recommendation": "proceed" }
      },
      "debug_attempts": 0,
      "replan_attempts": 0,
      "tokens_used": 85000,
      "estimated_tokens": 110000,           // Pre-spawn cost estimate from MTRC-02
      "human_verify_justification": null,   // Populated when status is "needs_human_verification" (STAT-02)
      "human_verdict": null                 // Populated after user provides verdict on needs_human_verification phase (STAT-05)
      // human_verdict shape: { "verdict": "pass|fail|issues_found", "timestamp": "ISO-8601", "issues": ["string"] }
    }
  },

  // ─── Circuit Breaker State ────────────────────────────────────────────
  "circuit_breaker": {
    "state": "closed",
    "consecutive_no_progress": 0,
    "consecutive_same_error": 0,
    "last_error": null,
    "cooldown_until": null
  },

  // ─── Event Log ────────────────────────────────────────────────────────
  "event_log": [
    {
      "timestamp": "2026-02-09T14:31:00Z",
      "phase": "6.1",
      "step": "execute",
      "event": "task_completed",
      "details": { "task": "task_01", "commit": "abc1234" }
    }
  ],

  // ─── Aggregate Metrics ────────────────────────────────────────────────
  "metrics": {
    "total_tokens_used": 450000,
    "total_duration_minutes": 180,
    "phases_completed": 5,
    "phases_failed": 0,
    "debug_loops_total": 2,
    "replan_count": 0
  }
}
```

### State File Lifecycle

1. **Creation:** Orchestrator creates `.autopilot/state.json` at run start with all phases set to `not_started`, empty event log, zeroed metrics.
2. **Backup before write:** Before each write, copy current `state.json` to `state.json.backup`.
3. **Updates:** Written after every step transition. Each write is atomic (write to temp file, then rename).
4. **Checkpoints:** The `last_checkpoint` timestamp updates on every write. If `last_checkpoint` is more than 10 minutes stale during a running state, the run is presumed crashed.
5. **Completion:** When the final phase passes its gate, `_meta.status` is set to `"completed"`. The file is then moved to `.autopilot/archive/run-YYYY-MM-DD-HHMMSS.json`.
6. **Failure:** When the run halts, `_meta.status` is set to `"failed"` or `"paused"`. The file stays at `.autopilot/state.json` for human inspection and potential resume.

### Resume Protocol

1. Attempt to parse `state.json`. If it fails to parse, attempt `state.json.backup`.
2. Read `_meta.status` -- if `"completed"`, archive it and start fresh.
3. If `"running"` -- the previous orchestrator crashed. Resume from `current_phase` and `current_step`.
4. If `"paused"` -- human must have resolved the issue. Transition circuit breaker to `"half_open"` and retry.
5. If `"failed"` -- do not auto-resume. Require explicit human command.

---

## Section 2: Circuit Breaker Configuration

Default configuration values. The circuit breaker prevents infinite loops, runaway costs, and repeated failures.

```jsonc
{
  "circuit_breaker_config": {
    "no_progress_threshold": 3,
    "same_error_threshold": 5,
    "output_degradation_pct": 70,
    "max_debug_attempts_per_phase": 3,
    "max_replan_attempts_per_phase": 1,
    "max_total_retries_per_run": 10,
    "cooldown_minutes": 5,
    "cost_cap_tokens_per_phase": 500000,
    "cost_cap_tokens_total": 5000000,
    "wall_clock_timeout_minutes_per_phase": 120,
    "wall_clock_timeout_minutes_total": 1440
  }
}
```

### Threshold Quick Reference

| Threshold | Default | Trips When | Effect |
|-----------|---------|------------|--------|
| no_progress_threshold | 3 | 3 consecutive no-progress steps | Opens circuit breaker |
| same_error_threshold | 5 | 5 consecutive identical errors | Opens circuit breaker |
| output_degradation_pct | 70% | Alignment score < 7/10 | Triggers debug loop |
| max_debug_attempts_per_phase | 3 | Phase has debugged 3 times | Phase fails |
| max_replan_attempts_per_phase | 1 | Plan revised twice, still fails | Phase fails |
| max_total_retries_per_run | 10 | 10 total retries across all phases | Run halts |
| cost_cap_tokens_per_phase | 500K | Phase exceeds token budget | Phase halts, circuit opens |
| cost_cap_tokens_total | 5M | Run exceeds total token budget | Run fails immediately |
| wall_clock_timeout_minutes_per_phase | 120 | Phase runs > 2 hours | Phase halts, circuit opens |
| wall_clock_timeout_minutes_total | 1440 | Run runs > 24 hours | Run fails immediately |

---

## Section 3: Event Types

All events are appended to the `event_log` array in `state.json`. Events are the audit trail for the entire run.

### Event Type Summary

| Event | Level | Fires When |
|-------|-------|------------|
| `run_started` | Run | Orchestrator begins new run |
| `run_completed` | Run | All phases pass, run finishes |
| `run_halted` | Run | Unrecoverable error or cap exceeded |
| `run_resumed` | Run | Paused run continues |
| `phase_started` | Phase | Phase transitions to in_progress |
| `phase_completed` | Phase | Phase passes gate |
| `phase_failed` | Phase | Phase exhausts retries |
| `step_started` | Step | Step begins execution |
| `step_completed` | Step | Step finishes successfully |
| `step_failed` | Step | Step produces failure |
| `task_completed` | Task | Executor finishes a task |
| `task_failed` | Task | Executor fails a task |
| `task_retried` | Task | Failed task is retried |
| `circuit_breaker_opened` | System | Threshold exceeded, halt |
| `circuit_breaker_closed` | System | Issue resolved, resume |
| `checkpoint_written` | System | State file written to disk |
| `debug_attempt` | Recovery | Debug loop entered |
| `replan_attempt` | Recovery | Plan revision triggered |
| `rollback_initiated` | Recovery | Judge orders rollback |
| `rollback_completed` | Recovery | Rollback finishes |
| `human_verdict_recorded` | Phase | User provides pass/fail/issues_found verdict on a needs_human_verification phase |
| `unnecessary_deferral_warning` | Phase | Phase deferred to human with all auto tasks passing |
| `high_defer_rate_warning` | Run | More than 50% of processed phases deferred to human |
| `self_audit_started` | Run | Self-audit agent spawned during completion protocol |
| `self_audit_completed` | Run | Self-audit finished (includes aggregate pass/gap counts) |
| `self_audit_gap_found` | Run | Self-audit identified a requirement gap (one event per gap) |
| `self_audit_gap_fixed` | Run | A gap identified by self-audit was fixed and re-verified |
| `phase_skipped` | Phase | Phase skipped during --complete mode (already completed or blocked by failed dependency) |
| `batch_completion_report` | Run | Aggregated completion report written at end of --complete run |

---

## Section 4: Directory Structure

```
project-root/
│
├── .autopilot/                          # Autopilot runtime directory
│   ├── state.json                       # Active run state (Section 1)
│   ├── archive/                         # Completed run states
│   │   ├── metrics.json                 # Cross-run metrics array (MTRC-01)
│   │   └── run-YYYY-MM-DD-HHMMSS.json
│   └── diagnostics/                     # Failure reports
│       ├── diagnostic-YYYY-MM-DDTHHMMSS.md
│       └── phase-{N}-postmortem.json    # Structured post-mortem (OBSV-04)
│
├── .planning/                           # Phase artifacts directory
│   └── phases/                          # One subdirectory per phase
│       ├── 6.1/
│       │   ├── RESEARCH.md
│       │   ├── PLAN.md
│       │   ├── EXECUTION-LOG.md
│       │   ├── VERIFICATION.md
│       │   ├── JUDGE-REPORT.md
│       │   ├── TRIAGE.json
│       │   ├── TRACE.jsonl               # Aggregated step traces (OBSV-02)
│       │   ├── research-trace.jsonl       # Step-level trace (OBSV-01)
│       │   ├── plan-trace.jsonl
│       │   ├── execute-trace.jsonl
│       │   └── verify-trace.jsonl
│       └── ...
│
└── (project source files)
```

### Git Considerations

- `.autopilot/state.json` should be in `.gitignore` (runtime state)
- `.autopilot/archive/` should be in `.gitignore`
- `.autopilot/diagnostics/` should be in `.gitignore`
- `.planning/phases/` should be committed (documentation of what was built)

### .gitignore Additions

```
# Autopilot runtime state
.autopilot/state.json
.autopilot/archive/
.autopilot/diagnostics/
```

---

## Section 5: Step Agent Handoff Protocol

> **All step agents return structured JSON.** The phase-runner reads ONLY the JSON block from each agent's response. Prose summaries are no longer used for handoff between pipeline steps. The canonical JSON schemas are defined in the playbook prompt templates; this section mirrors them for developer reference.

### Researcher Return Schema

```jsonc
{
  "key_findings": ["string"],        // 3-5 key research findings
  "recommended_approach": "string",   // 1-2 sentence recommended approach
  "risks": ["string"],               // Identified risks or blockers
  "open_questions": ["string"]        // Unresolved questions for the planner
}
```

### Planner Return Schema

```jsonc
{
  "plans_created": 3,                // Number of plans written to PLAN.md
  "waves": 2,                        // Number of execution waves
  "total_tasks": 6,                  // Total task count across all plans
  "complexity": "simple|medium|complex",  // Estimated phase complexity
  "dependencies": ["string"],        // Inter-plan dependencies
  "concerns": ["string"]             // Deferred decisions or concerns
}
```

### Executor Return Schema

```jsonc
{
  "tasks_completed": "N/M",          // Tasks completed out of total
  "tasks_failed": "N/M",             // Tasks failed out of total
  "commit_shas": ["string"],         // Git commit SHAs (one per task)
  "evidence": [                       // Per-task evidence
    {
      "task_id": "XX-YY",            // Task identifier from PLAN.md
      "criteria_met": ["string"],     // "criterion -- file:line -- finding"
      "commands_run": ["string"]      // "command -> result"
    }
  ],
  "deviations": ["string"]           // Any departures from plan
}
```

### Existing Step Agent Return Schemas

The following agents already used JSON returns before this handoff protocol was formalized. Their schemas are defined in the playbook prompt templates:

- **Preflight**: `all_clear`, `spec_hash_match`, `working_tree_clean`, `dependencies_met`, `unresolved_debug`, `issues`
- **Plan-checker**: `pass`, `issues`, `confidence`, `blocker_count`, `warning_count`
- **Verifier**: `pass`, `automated_checks`, `criteria_results`, `alignment_score`, `verification_duration_seconds`, `commands_run`, `failures`, `failure_categories`, `scope_creep`
- **Judge**: `alignment_score`, `recommendation`, `concerns`, `independent_evidence`, `verifier_agreement`, `verifier_missed`, `scope_creep`, `missing_requirements`, `notes`
- **Debugger**: `fixed`, `changes`, `commits`, `remaining_issues`, `failure_categories`

---

## Section 6: Trace and Post-Mortem Schemas

### Trace Span Schema (OBSV-01)

Each step agent writes a JSONL trace file (`{step}-trace.jsonl`) to the phase directory. Each line is one trace span representing a significant action (tool invocation, file write, command execution).

```jsonc
// One line per span in {step}-trace.jsonl
{
  "timestamp": "2026-02-09T14:32:15Z",   // ISO-8601 when the action started
  "phase_id": "5",                         // Phase identifier
  "step": "execute",                       // Pipeline step name: research|plan|plan_check|execute|verify|judge|debug
  "action": "file_write",                  // Action type: file_read|file_write|command_run|tool_call|agent_spawn|decision
  "input_summary": "Write to src/protocols/autopilot-playbook.md",  // Truncated to 200 chars max
  "output_summary": "File written successfully (1013 lines)",       // Truncated to 200 chars max
  "duration_ms": 450,                      // Wall-clock milliseconds for this action
  "status": "success"                      // success|failure|skipped
}
```

**Action types:**
| Action | When to log |
|--------|------------|
| `file_read` | Reading a source file or artifact |
| `file_write` | Writing or editing a file |
| `command_run` | Running a shell command (compile, lint, grep, git) |
| `tool_call` | Any tool invocation not covered by the above |
| `agent_spawn` | Spawning a subagent (e.g., mini-verifier) |
| `decision` | Making a routing or gate decision |

### Aggregated TRACE.jsonl Schema (OBSV-02)

The phase-runner aggregates all step-level trace files into a single `TRACE.jsonl` file in the phase directory. The format is identical to individual trace spans -- it is a concatenation of all step trace files in execution order, with optional phase-runner-level spans interspersed.

```jsonc
// TRACE.jsonl = concatenation of all {step}-trace.jsonl files + phase-runner spans
// Each line follows the trace span schema above
// Phase-runner adds its own spans for pipeline-level actions:
{
  "timestamp": "2026-02-09T14:31:00Z",
  "phase_id": "5",
  "step": "phase_runner",                  // "phase_runner" for pipeline-level actions
  "action": "agent_spawn",
  "input_summary": "Spawning gsd-executor for phase 5",
  "output_summary": "Agent completed: 3/3 tasks, 3 commits",
  "duration_ms": 180000,
  "status": "success"
}
```

### Post-Mortem Schema (OBSV-03, OBSV-04)

On phase failure, the phase-runner generates a structured post-mortem at `.autopilot/diagnostics/phase-{N}-postmortem.json`.

```jsonc
{
  "phase_id": "5",
  "phase_name": "Execution Trace and Observability",
  "timestamp": "2026-02-09T16:45:00Z",     // When the post-mortem was generated
  "status": "failed",                        // Always "failed" (post-mortems are for failures)

  // Root cause from the failure taxonomy (Section 2.5 of playbook)
  "root_cause": {
    "category": "acceptance_criteria_unmet", // One of the 10 taxonomy categories
    "description": "Verifier found 2 of 5 acceptance criteria not met after 3 debug attempts",
    "first_observed_at": "2026-02-09T15:30:00Z",  // When the failure was first detected
    "step": "verify"                         // Pipeline step where failure was identified
  },

  // Timeline of events leading to failure (from TRACE.jsonl or step returns)
  "timeline": [
    {
      "timestamp": "2026-02-09T14:31:00Z",
      "step": "execute",
      "event": "Task 05-01 completed",
      "status": "success"
    },
    {
      "timestamp": "2026-02-09T15:30:00Z",
      "step": "verify",
      "event": "2 acceptance criteria failed",
      "status": "failure"
    },
    {
      "timestamp": "2026-02-09T15:45:00Z",
      "step": "debug",
      "event": "Debug attempt 1: fixed 1 of 2 issues",
      "status": "partial"
    }
  ],

  // Evidence chain: commands run, files checked, outputs observed
  "evidence": {
    "commands_run": [
      "grep 'pattern' file.md -> no match (FAIL)",
      "git diff d340a8a..HEAD --stat -> 3 files changed"
    ],
    "files_checked": [
      "src/protocols/autopilot-playbook.md:450 -- missing trace instruction"
    ]
  },

  // Debug attempts and their outcomes
  "attempted_fixes": [
    {
      "attempt": 1,
      "description": "Added missing trace instruction to executor prompt",
      "commit_sha": "abc1234",
      "resolved": ["criterion_1"],
      "remaining": ["criterion_2"]
    }
  ],

  // Prevention rule for the learnings file (Phase 6)
  "prevention_rule": "When adding trace instructions to step agent prompts, verify each prompt template independently rather than assuming a bulk edit covers all cases. Check grep count matches the number of step agents."
}
```

---

## Section 7: Learnings File Schema (LRNG-01 through LRNG-04)

**File:** `.autopilot/learnings.md`
**Created by:** Phase-runner (on first failure) or orchestrator (on first human verdict)
**Reset by:** Orchestrator at run start (LRNG-03)
**Read by:** Executor (pre-execution priming, EXEC-06), Planner (task design, LRNG-02)

The learnings file is a structured markdown file scoped to the current run. It accumulates prevention rules from failures and calibration data from human verdicts.

**File header:** `# Learnings (current run)`

**Entry types:**

### Failure Prevention Entry (LRNG-01)

Written by the phase-runner after post-mortem generation when a phase fails.

```markdown
### Phase {N} failure -- {failure_category}
**Prevention rule:** {1-2 sentence rule for future agents}
**Context:** Phase {N} ({phase_name}) failed with category `{failure_category}`. Recorded: {ISO-8601 timestamp}.
```

### Human Verdict Calibration Entry (LRNG-04)

Written by the orchestrator after collecting a human verdict for a `needs_human_verification` phase.

**Pass verdict:**
```markdown
### Human Verdict: Phase {N} -- PASS (confidence calibration)
Phase {N} ({phase_name}) was deferred to human review but passed without issues.
**Calibration:** Future phases with similar characteristics should increase autonomous completion confidence.
```

**Fail/issues_found verdict:**
```markdown
### Human Verdict: Phase {N} -- {FAIL|ISSUES_FOUND} (confidence calibration)
Phase {N} ({phase_name}) was deferred to human review. Human found issues: {issues_list}.
**Calibration:** Tighten quality checks for similar phases. Specific issues to watch for: {issues_list}.
```

**Lifecycle:**
1. Orchestrator deletes `learnings.md` at run start (LRNG-03)
2. Phase-runner appends failure prevention entries during the run (LRNG-01)
3. Orchestrator appends human verdict calibration entries at end of run (LRNG-04)
4. Executor reads the file during pre-execution priming (EXEC-06, LRNG-02)
5. Planner reads the file during task design (LRNG-02)

---

## Section 8: Metrics and Cost Schemas

### metrics.json Schema (MTRC-01)

**File:** `.autopilot/archive/metrics.json`
**Created by:** Orchestrator at end of first run
**Updated by:** Orchestrator at end of each subsequent run (append to array)
**Read by:** Orchestrator at end of run for trend comparison (MTRC-03)

The metrics file is a JSON array. Each element represents one completed run. The orchestrator appends a new entry at the end of each run during the completion protocol (Section 9 of the orchestrator guide).

```jsonc
[
  {
    "run_id": "run-2026-02-10-143052",         // Matches _meta.run_id from state.json
    "timestamp": "2026-02-10T16:45:00Z",        // When metrics were recorded (run completion time)
    "phases_attempted": 5,                       // Total phases that entered the pipeline
    "phases_succeeded": 4,                       // Phases with status "completed" and alignment >= 7
    "phases_failed": 1,                          // Phases with status "failed"
    "phases_human_deferred": 0,                  // Phases with status "needs_human_verification"
    "failure_taxonomy_histogram": {              // Aggregated from all verifier/debugger failure_categories
      "executor_incomplete": 1,
      "acceptance_criteria_unmet": 1
    },
    "avg_alignment_score": 7.8,                  // Mean of all phase alignment_score values (judge scores)
    "total_duration_minutes": 135,               // Wall-clock minutes from _meta.started_at to completion
    "total_estimated_tokens": 425000,            // Sum of per-phase estimated_tokens (from MTRC-02)
    "total_debug_loops": 2,                      // Sum of debug_attempts across all phases
    "total_replan_attempts": 0,                  // Sum of replan_attempts across all phases
    "success_rate": 0.80,                        // phases_succeeded / phases_attempted
    "per_phase_summary": [                       // Lightweight per-phase breakdown
      {
        "phase_id": "7",
        "status": "completed",
        "alignment_score": 8,
        "estimated_tokens": 110000,
        "duration_minutes": 25
      }
    ]
  }
]
```

### Cost Estimation Constants (MTRC-02)

The orchestrator uses these constants to estimate token cost before spawning each phase-runner. Estimates are heuristic approximations -- Claude Code does not expose actual token counts.

```jsonc
{
  "cost_estimation": {
    // Per-task token estimates by complexity (from PLAN-03 complexity attribute)
    "task_tokens": {
      "simple": 15000,     // Single file, straightforward edit
      "medium": 30000,     // 2-3 files, moderate logic
      "complex": 60000     // 4+ files, significant logic or cross-cutting changes
    },

    // Fixed pipeline overhead per phase (research + plan + plan-check + verify + judge)
    "pipeline_overhead": 50000,

    // Buffer multiplier to account for debug loops, re-verification, etc.
    "buffer_multiplier": 1.20,    // 20% buffer

    // Warning threshold: warn when estimate exceeds this percentage of cost_cap_tokens_per_phase
    "warning_threshold_pct": 80,

    // Default estimates when no plan exists yet (full pipeline from scratch)
    "default_estimates": {
      "protocol": 150000,    // Protocol phases (markdown edits, moderate complexity)
      "ui": 250000,          // UI phases (code + build + visual verification)
      "data": 100000,        // Data phases (JSON/config changes)
      "mixed": 200000        // Mixed phases
    }
  }
}
```

**Estimation formula:**
```
if plan exists:
  task_cost = sum(task_tokens[task.complexity] for each task in plan)
  estimated_tokens = (pipeline_overhead + task_cost) * buffer_multiplier
else:
  estimated_tokens = default_estimates[phase_type] * buffer_multiplier

if estimated_tokens > cost_cap_tokens_per_phase * (warning_threshold_pct / 100):
  log warning: "Phase {N} estimated at {est} tokens ({pct}% of budget cap)."
```

### Trend Comparison Schema (MTRC-03)

The orchestrator computes a trend summary when metrics.json contains >= 2 run entries. This summary is appended to the completion report.

```jsonc
{
  "trend_summary": {
    // Current vs previous run deltas
    "success_rate_delta": 0.10,          // current - previous (positive = improvement)
    "avg_alignment_delta": 0.5,          // current - previous
    "estimated_cost_delta": -25000,      // current - previous (negative = cheaper)

    // Recurring failure categories (present in both current and previous run)
    "recurring_failures": ["executor_incomplete"],

    // Historical context across all runs
    "historical": {
      "total_runs": 5,
      "success_rate": { "min": 0.60, "max": 0.90, "avg": 0.78 },
      "avg_alignment": { "min": 6.5, "max": 8.2, "avg": 7.4 },
      "total_cost": { "min": 200000, "max": 600000, "avg": 380000 }
    }
  }
}
```

---

## Section 9: Self-Audit Schemas

### Self-Audit Agent Return Schema

The self-audit agent (spawned during the completion protocol, Section 9 step 2 of the orchestrator guide) returns a structured JSON report after checking implementation files against frozen spec requirements.

```jsonc
{
  "audit_results": [
    {
      "phase_id": "5",                          // Phase that implemented this requirement
      "requirements_checked": [
        {
          "requirement_id": "OBSV-01",          // Requirement ID from frozen spec
          "expected": "Each step agent writes structured JSONL trace",  // What the spec requires
          "actual_found": "Trace instruction present in executor, verifier, judge prompts",  // What was found
          "file_line_evidence": "src/protocols/autopilot-playbook.md:517 -- 'Write a trace file to'",  // file:line proof
          "status": "pass",                     // "pass" or "gap"
          "gap_description": null,              // null if pass; specific description if gap
          "fix_complexity": null                // null if pass; "small" or "large" if gap
        },
        {
          "requirement_id": "OBSV-02",
          "expected": "Phase-runner aggregates step traces into TRACE.jsonl",
          "actual_found": "Aggregation instruction missing from phase-runner agent definition",
          "file_line_evidence": "src/agents/autopilot-phase-runner.md -- no TRACE.jsonl reference found",
          "status": "gap",
          "gap_description": "Phase-runner agent definition does not mention TRACE.jsonl aggregation. Instruction exists in playbook but not in agent spawn prompt.",
          "fix_complexity": "small"
        }
      ]
    }
  ],

  // Aggregate statistics across all phases
  "aggregate": {
    "total_requirements_checked": 15,           // Total requirement checks performed
    "passed_on_first_check": 13,                // Requirements that passed without fixes
    "gaps_found": 2,                            // Requirements with status "gap"
    "gap_details": [                            // Details for each gap (for fix routing)
      {
        "requirement_id": "OBSV-02",
        "phase_id": "5",
        "gap_description": "Phase-runner agent definition does not mention TRACE.jsonl aggregation",
        "fix_complexity": "small",
        "suggested_fix": "Add TRACE.jsonl aggregation instruction to src/agents/autopilot-phase-runner.md after each step agent returns"
      }
    ]
  }
}
```

### Self-Audit Completion Report Schema

After the self-audit loop completes (including any gap-fix cycles), the orchestrator stores this summary for inclusion in the completion report.

```jsonc
{
  "self_audit": {
    "total_requirements_checked": 15,           // Total requirements audited
    "passed_on_first_check": 13,                // Passed before any fixes
    "gaps_found": 2,                            // Gaps identified on first audit
    "gaps_fixed": 2,                            // Gaps successfully fixed and re-verified
    "gaps_remaining": 0,                        // Gaps that could not be auto-fixed
    "remaining_gap_details": [],                // Details for unfixable gaps (empty if all fixed)
    // Shape: [{"requirement_id": "REQ-XX", "description": "what could not be fixed"}]
    "audit_cycles": 1,                          // Number of re-audit cycles (0 = no gaps, 1-2 = re-verification)
    "fix_commits": ["abc1234", "def5678"]       // Git SHAs for gap-fix commits
  }
}
```

### Self-Audit Event Schemas

Events appended to the `event_log` in `state.json` during self-audit:

```jsonc
// self_audit_started -- logged before spawning the audit agent
{
  "timestamp": "2026-02-10T18:00:00Z",
  "event": "self_audit_started",
  "details": {
    "phases_to_audit": ["5", "6", "7"],         // Phase IDs being audited
    "spec_path": ".planning/REQUIREMENTS.md"
  }
}

// self_audit_gap_found -- logged per gap identified
{
  "timestamp": "2026-02-10T18:05:00Z",
  "event": "self_audit_gap_found",
  "details": {
    "requirement_id": "OBSV-02",
    "phase_id": "5",
    "gap_description": "TRACE.jsonl aggregation not in agent definition",
    "fix_complexity": "small"
  }
}

// self_audit_gap_fixed -- logged per gap fixed and re-verified
{
  "timestamp": "2026-02-10T18:10:00Z",
  "event": "self_audit_gap_fixed",
  "details": {
    "requirement_id": "OBSV-02",
    "phase_id": "5",
    "fix_commit": "abc1234",
    "re_verified": true
  }
}

// self_audit_completed -- logged when entire audit process finishes
{
  "timestamp": "2026-02-10T18:15:00Z",
  "event": "self_audit_completed",
  "details": {
    "total_requirements_checked": 15,
    "passed_on_first_check": 13,
    "gaps_found": 2,
    "gaps_fixed": 2,
    "gaps_remaining": 0,
    "audit_cycles": 1
  }
}
```

---

## Section 10: Batch Completion Report Schema (CMPL-04)

### Completion Report Schema

**File:** `.autopilot/completion-report.md`
**Created by:** Orchestrator at end of `--complete` run
**Read by:** User, trend analysis tools

The completion report is a markdown file written when `--complete` mode finishes. It provides a project-level overview of what was accomplished, what failed, and what's left.

### Completion Report Data Schema

The structured data underlying the completion report markdown:

```jsonc
{
  "run_id": "run-2026-02-10-143052",          // Matches _meta.run_id from state.json
  "timestamp": "2026-02-10T18:30:00Z",         // When the report was generated
  "mode": "--complete",                         // Always "--complete" for batch completion runs
  "total_phases_in_roadmap": 15,                // Total phases defined in ROADMAP.md
  "completed_phases_total": 12,                 // Phases with "completed" status across all runs
  "completion_percentage": 80.0,                // (completed_phases_total / total_phases_in_roadmap) * 100

  "phases_attempted": 5,                        // Phases executed in this run
  "phases_succeeded": 3,                        // Phases that passed (completed + alignment >= 7)
  "phases_failed": 1,                           // Phases that failed
  "phases_skipped": [                           // Phases not executed (with reason)
    {
      "phase_id": "9",
      "phase_name": "Pre-Execution Context Mapping",
      "reason": "already_completed",
      "original_run_timestamp": "2026-02-09T15:00:00Z"
    },
    {
      "phase_id": "11",
      "phase_name": "Competitive Analysis",
      "reason": "blocked_by_phase_10",
      "blocking_phase": "10"
    }
  ],
  "phases_deferred": 1,                        // Phases returned needs_human_verification

  "dependency_gaps": [                          // Failed phases and their blocked dependents
    {
      "failed_phase_id": "10",
      "failed_phase_name": "Confidence Enforcement",
      "failure_reason": "executor_incomplete: 2 acceptance criteria unmet",
      "blocked_phases": [
        {"phase_id": "11", "phase_name": "Competitive Analysis"}
      ]
    }
  ]
}
```

### Event Types for Batch Completion

Events appended to the `event_log` in `state.json` during `--complete` runs:

```jsonc
// phase_skipped -- logged when --complete skips a phase
{
  "timestamp": "2026-02-10T14:35:00Z",
  "event": "phase_skipped",
  "details": {
    "phase_id": "9",
    "reason": "already_completed",
    "original_run_timestamp": "2026-02-09T15:00:00Z"
  }
}

// phase_skipped (blocked) -- logged when a phase is blocked by a failed dependency
{
  "timestamp": "2026-02-10T16:00:00Z",
  "event": "phase_skipped",
  "details": {
    "phase_id": "11",
    "reason": "blocked_by_phase_10",
    "blocking_phase": "10"
  }
}

// batch_completion_report -- logged when the completion report is written
{
  "timestamp": "2026-02-10T18:30:00Z",
  "event": "batch_completion_report",
  "details": {
    "phases_attempted": 5,
    "phases_succeeded": 3,
    "phases_failed": 1,
    "phases_skipped": 2,
    "completion_percentage": 80.0,
    "report_path": ".autopilot/completion-report.md"
  }
}
```

---

## Summary

This document is developer reference documentation for the autopilot orchestration system. It defines: (1) a state file schema that tracks run progress and enables crash recovery, (2) circuit breaker configuration with ten tunable thresholds, (3) twenty-four event types forming an append-only audit log, (4) the directory structure for runtime and phase artifacts, (5) the step agent handoff protocol with JSON return schemas for all agents, (6) trace span and post-mortem schemas for execution observability (OBSV-01 through OBSV-04), (7) learnings file schema for cross-phase learning (LRNG-01 through LRNG-04), (8) metrics and cost schemas for run-level metrics collection, pre-execution cost estimation, and cross-run trend analysis (MTRC-01 through MTRC-03), (9) self-audit schemas for post-completion requirement verification and gap-fix tracking, and (10) batch completion report schema for `--complete` mode aggregated reporting (CMPL-04). For the canonical return contract, see `__INSTALL_BASE__/autopilot/protocols/autopilot-orchestrator.md` Section 4. For step prompt templates, see `__INSTALL_BASE__/autopilot/protocols/autopilot-playbook.md`.
