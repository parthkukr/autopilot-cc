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

---

## Section 4: Directory Structure

```
project-root/
│
├── .autopilot/                          # Autopilot runtime directory
│   ├── state.json                       # Active run state (Section 1)
│   ├── archive/                         # Completed run states
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

## Summary

This document is developer reference documentation for the autopilot orchestration system. It defines: (1) a state file schema that tracks run progress and enables crash recovery, (2) circuit breaker configuration with ten tunable thresholds, (3) twenty event types forming an append-only audit log, (4) the directory structure for runtime and phase artifacts, (5) the step agent handoff protocol with JSON return schemas for all agents, (6) trace span and post-mortem schemas for execution observability (OBSV-01 through OBSV-04), and (7) learnings file schema for cross-phase learning (LRNG-01 through LRNG-04). For the canonical return contract, see `__INSTALL_BASE__/autopilot/protocols/autopilot-orchestrator.md` Section 4. For step prompt templates, see `__INSTALL_BASE__/autopilot/protocols/autopilot-playbook.md`.
