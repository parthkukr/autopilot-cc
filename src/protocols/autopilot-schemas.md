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
10. [Batch Completion Report Schema](#section-10-batch-completion-report-schema)
11. [Context Mapping Schemas](#section-11-context-mapping-schemas)
12. [Confidence Enforcement Schemas](#section-12-confidence-enforcement-schemas)
13. [Sandbox Execution Schemas](#section-13-sandbox-execution-schemas)
14. [Repository Map Schema](#section-14-repository-map-schema)
15. [Debug Session Schema](#section-15-debug-session-schema)
16. [Visual Testing Schemas](#section-16-visual-testing-schemas)

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
    "total_phases_processed": 0,      // STAT-04: total phases processed (for defer-rate calc)
    "pass_threshold": 9,              // CENF-01: alignment pass threshold (9 default, 7 with --lenient)
    "autonomous_resolution_rate": 0.0, // Computed: phases autonomously resolved / total phases attempted
    "deferral_threshold": 0.05,       // Target deferral rate (5% default, auto-adjusted based on history)
    "deferral_history": []            // Array of {phase_id, reason, autonomous_confidence, human_verdict, timestamp}
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
          "scope_creep": []
        },
        "judge": { "recommendation": "proceed", "concerns": ["minor style inconsistency"] },
        "rate": { "status": "pass", "alignment_score": 8.2, "score_band": "good" }
      },
      "debug_attempts": 0,
      "replan_attempts": 0,
      "tokens_used": 85000,
      "estimated_tokens": 110000,           // Pre-spawn cost estimate from MTRC-02
      "human_verify_justification": null,   // Populated when status is "needs_human_verification" (STAT-02)
      "human_verdict": null,                // Populated after user provides verdict on needs_human_verification phase (STAT-05)
      // human_verdict shape: { "verdict": "pass|fail|issues_found", "timestamp": "ISO-8601", "issues": ["string"] }
      "force_incomplete": false,            // CENF-03: true when remediation cycles exhaust without reaching pass_threshold
      "diagnostic_path": null,              // CENF-02: path to confidence diagnostic file (e.g., ".autopilot/diagnostics/phase-6.1-confidence.md")
      "remediation_cycles": 0              // CENF-01: number of remediation cycles run (0 = none, 1-2 = remediated)
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
| `high_defer_rate_warning` | Run | More than 5% of processed phases deferred to human |
| `autonomous_resolution_success` | Phase | Phase with checkpoint:human-verify tasks was resolved autonomously (autonomous_confidence >= 6) |
| `deferral_threshold_adjusted` | Run | Deferral confidence threshold auto-adjusted based on historical human verdicts |
| `self_audit_started` | Run | Self-audit agent spawned during completion protocol |
| `self_audit_completed` | Run | Self-audit finished (includes aggregate pass/gap counts) |
| `self_audit_gap_found` | Run | Self-audit identified a requirement gap (one event per gap) |
| `self_audit_gap_fixed` | Run | A gap identified by self-audit was fixed and re-verified |
| `phase_skipped` | Phase | Phase skipped during --complete mode (already completed or blocked by failed dependency) |
| `batch_completion_report` | Run | Aggregated completion report written at end of --complete run |
| `context_mapping_started` | Run | Context mapping mode (`--map`) initiated; lists target phases |
| `context_mapping_completed` | Run | Context mapping finished; includes per-phase scores and question counts |
| `remediation_started` | Phase | Orchestrator enters remediation cycle for a phase scoring below pass_threshold (CENF-01) |
| `remediation_completed` | Phase | Remediation cycle finishes; includes cycle number, old score, new score (CENF-01) |
| `confidence_diagnostic_written` | Phase | Diagnostic file generated for a sub-9 phase completion (CENF-02) |
| `force_incomplete_marked` | Phase | Phase passes with force_incomplete flag after remediation exhausts (CENF-03) |

---

## Section 4: Directory Structure

```
project-root/
│
├── .autopilot/                          # Autopilot runtime directory
│   ├── state.json                       # Active run state (Section 1)
│   ├── repo-map.json                    # Structural codebase map (Section 14)
│   ├── codebase-analysis.md             # Codebase analysis summary
│   ├── archive/                         # Completed run states
│   │   ├── metrics.json                 # Cross-run metrics array (MTRC-01)
│   │   └── run-YYYY-MM-DD-HHMMSS.json
│   ├── context-map.json                 # User-provided context answers (CMAP-03, persists across runs)
│   └── diagnostics/                     # Failure reports
│       ├── diagnostic-YYYY-MM-DDTHHMMSS.md
│       ├── phase-{N}-postmortem.json    # Structured post-mortem (OBSV-04)
│       └── phase-{N}-confidence.md      # Confidence diagnostic for sub-9.0 phases (CENF-02)
│
├── .planning/                           # Phase artifacts directory
│   ├── phases/                          # One subdirectory per phase
│   │   ├── {N}/
│   │   │   ├── RESEARCH.md
│   │   │   ├── PLAN.md
│   │   │   ├── EXECUTION-LOG.md
│   │   │   ├── VERIFICATION.md
│   │   │   ├── JUDGE-REPORT.md
│   │   │   ├── SCORECARD.md             # Rating agent's per-criterion evaluation
│   │   │   ├── TRIAGE.json
│   │   │   ├── CONTEXT.md               # Discussion decisions from --discuss mode
│   │   │   ├── VISUAL-BUGS.md           # Visual testing bug report (Section 16)
│   │   │   ├── TRACE.jsonl              # Aggregated step traces (OBSV-02)
│   │   │   ├── research-trace.jsonl     # Step-level trace (OBSV-01)
│   │   │   ├── plan-trace.jsonl
│   │   │   ├── execute-trace.jsonl
│   │   │   ├── verify-trace.jsonl
│   │   │   └── tests/                   # Phase-specific test artifacts
│   │   └── ...
│   ├── debug/                           # Debug session files (Section 15)
│   │   ├── active/                      # Active debug sessions
│   │   └── resolved/                    # Resolved/archived debug sessions
│   └── screenshots/                     # Visual testing screenshots (Section 16)
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

### Mini-Verifier Return Schema (PVRF-01)

The mini-verifier is spawned after each task execution as part of the per-task verification loop. It independently verifies a single task's acceptance criteria. The final phase-level verification (STEP 4) still runs after all tasks pass mini-verification -- this is a belt-and-suspenders approach where per-task verification catches issues early and phase-level verification provides the final safety net.

```jsonc
{
  "task_id": "XX-YY",                    // Task identifier being verified
  "pass": true,                          // Overall pass/fail for this task
  "criteria_results": [                  // Per-criterion verification
    {
      "criterion": "criterion text",     // The acceptance criterion being checked
      "status": "pass|fail",             // Individual criterion result
      "evidence": "file:line -- output", // Concrete evidence
      "command": "the verification command run",
      "command_output": "first 200 chars of command output"
    }
  ],
  "concerns": ["string"],               // Concerns even if passing
  "commands_run": ["command -> result"]  // All commands executed (MUST NOT be empty)
}
```

### EXECUTION-LOG.md Mini-Verification Extension (PVRF-01)

Each task entry in EXECUTION-LOG.md includes a `mini_verification` section after the executor's self-reported results. This captures the independent verification result per task.

```markdown
### Task {id}: {description}
- **Status:** COMPLETED|FAILED|NEEDS_REVIEW
- **Commit SHA:** {sha}
- **Files modified:** {list}
- **Evidence:** {executor's self-test results}
- **Confidence:** {1-10}
- **Mini-Verification:**
  - **Result:** PASS|FAIL
  - **Criteria checked:** {N}
  - **Criteria passed:** {N}
  - **Failures:** {list of failed criteria, or "None"}
  - **Debug attempts:** {0-2}
```

**Note:** The phase-level verification still runs after all tasks pass mini-verification. Per-task verification catches failures early (at minute 5 instead of minute 30); phase-level verification provides the comprehensive safety net.

### Existing Step Agent Return Schemas

The following agents already used JSON returns before this handoff protocol was formalized. Their schemas are defined in the playbook prompt templates:

- **Preflight**: `all_clear`, `spec_hash_match`, `working_tree_clean`, `dependencies_met`, `unresolved_debug`, `issues`
- **Plan-checker**: `pass`, `issues`, `confidence`, `blocker_count`, `warning_count`
- **Mini-Verifier** (PVRF-01): `task_id`, `pass`, `criteria_results` (array), `concerns`, `commands_run`
- **Verifier**: `pass`, `automated_checks`, `criteria_results`, `verification_duration_seconds`, `commands_run`, `failures`, `failure_categories`, `scope_creep`
- **Judge**: `recommendation`, `concerns`, `independent_evidence`, `verifier_agreement`, `verifier_missed`, `scope_creep`, `missing_requirements`, `notes`
- **Rating Agent**: `alignment_score` (decimal x.x format), `scorecard` (array of per-criterion entries), `aggregate_justification`, `side_effects`, `commands_run`, `score_band`
- **Debugger**: `fixed`, `changes`, `commits`, `remaining_issues`, `failure_categories`

### Rating Agent Return Schema

The rating agent is a dedicated, context-isolated agent that produces the authoritative alignment score. It receives ONLY acceptance criteria and git diff -- no verifier report, judge recommendation, or executor confidence.

```jsonc
{
  "alignment_score": 7.3,                    // Decimal x.x format REQUIRED. Integer scores rejected.
  "scorecard": [                             // Per-criterion detailed evaluation
    {
      "criterion": "criterion text from plan",
      "score": 8.2,                          // Decimal score for this criterion (0.0-10.0)
      "max_score": 10.0,
      "verification_command": "grep -c 'pattern' file.md",
      "command_output": "first 200 chars of command output",
      "evidence": "file:line -- what was found",
      "justification": "Why this score: what earned points, what lost points"
    }
  ],
  "aggregate_justification": "Explanation of weighted aggregate computation and deductions from 10.0",
  "side_effects": ["description of any side effects found"],
  "commands_run": ["command -> result"],      // MUST NOT be empty
  "score_band": "excellence|good|acceptable|significant_gaps|major_failures|not_implemented"
}
```

**Score bands:**
| Band | Range | Meaning |
|------|-------|---------|
| excellence | 9.5-10.0 | All criteria fully met with evidence, zero concerns |
| good | 8.0-9.4 | All criteria met, minor concerns |
| acceptable | 7.0-7.9 | Most criteria met, real deficiencies |
| significant_gaps | 5.0-6.9 | Multiple criteria partially unmet |
| major_failures | 3.0-4.9 | Multiple criteria unmet |
| not_implemented | 0.0-2.9 | Work does not address phase goal |

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
    "avg_alignment_score": 7.8,                  // Mean of all phase alignment_score values (decimal, from rating agent)
    "total_duration_minutes": 135,               // Wall-clock minutes from _meta.started_at to completion
    "total_estimated_tokens": 425000,            // Sum of per-phase estimated_tokens (from MTRC-02)
    "total_debug_loops": 2,                      // Sum of debug_attempts across all phases
    "total_replan_attempts": 0,                  // Sum of replan_attempts across all phases
    "success_rate": 0.80,                        // phases_succeeded / phases_attempted
    "per_phase_summary": [                       // Lightweight per-phase breakdown
      {
        "phase_id": "7",
        "status": "completed",
        "alignment_score": 8.2,
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

## Section 11: Context Mapping Schemas (CMAP-01 through CMAP-05)

### context-map.json Schema (CMAP-03)

**File:** `.autopilot/context-map.json`
**Created by:** Orchestrator during `--map` mode
**Updated by:** Orchestrator when user provides answers to context mapping questions
**Read by:** Phase-runner research step (CMAP-04), orchestrator on subsequent `--map` runs
**Persistence:** Persists across runs (NOT deleted at run start, unlike learnings.md)

The context map file stores user-provided answers to questions generated during context mapping. It is keyed by phase ID so answers for different phases do not interfere.

```jsonc
{
  "version": "1.0",
  "last_updated": "2026-02-10T14:30:00Z",       // ISO-8601 timestamp of last update
  "phases": {
    "9": {                                         // Phase ID as key
      "phase_name": "Pre-Execution Context Mapping",
      "context_score": 6,                          // Score at time of mapping (before answers)
      "score_after": 8,                            // Updated score after answers incorporated
      "questions": [
        {
          "question": "What build command does this project use?",
          "category": "build_config",              // One of: build_config, architecture, requirements, criteria, dependencies, domain
          "why_needed": "No build command configured in .planning/config.json",
          "answer": "npm run build",               // User's answer (null if unanswered)
          "answered_at": "2026-02-10T14:35:00Z"   // ISO-8601 when answered (null if unanswered)
        }
      ],
      "mapped_at": "2026-02-10T14:30:00Z"        // ISO-8601 when this phase was mapped
    }
  }
}
```

**Merge semantics:** When the orchestrator writes to context-map.json:
- If the file does not exist, create it with the new entries.
- If the file exists, read it first. For each phase being mapped:
  - If the phase already has entries, merge: keep existing answered questions, add new questions, update scores.
  - If the phase has no entries, add the new phase block.
- Never delete entries for phases not currently being mapped.

### Questioning Agent Return Schema (CMAP-02)

The questioning agent is spawned by the orchestrator during `--map` mode for each phase scoring below 8 on context sufficiency. It returns structured questions targeting specific information gaps.

```jsonc
{
  "phase_id": "5",                                  // Phase being analyzed
  "current_score": 4,                               // Current context sufficiency score
  "questions": [
    {
      "question": "Which authentication method should Phase 5 implement (OAuth, JWT, session)?",
      "category": "requirements",                   // build_config|architecture|requirements|criteria|dependencies|domain
      "why_needed": "Phase 5 goal says 'add authentication' but doesn't specify the method"
    },
    {
      "question": "What is the expected session duration for authenticated users?",
      "category": "requirements",
      "why_needed": "Session management approach depends on expected session duration"
    }
  ],
  "estimated_score_after": 8                        // Expected score if all questions are answered
}
```

**Question categories:**

| Category | Description | Example question |
|----------|-------------|-----------------|
| `build_config` | Missing build/compile/lint commands or project setup | "What build command does this project use?" |
| `architecture` | Unclear system architecture or component relationships | "Is the API server and frontend in the same repo or separate?" |
| `requirements` | Ambiguous or incomplete requirements | "Which auth method should Phase 5 use?" |
| `criteria` | Missing or vague success criteria | "What specific metric defines 'improved performance'?" |
| `dependencies` | Unclear external dependencies or integrations | "Which database is used -- PostgreSQL, MySQL, or SQLite?" |
| `domain` | Missing domain knowledge needed for the phase | "What units should the fitness calculations use (metric or imperial)?" |

### Context Sufficiency Scoring Constants (CMAP-01)

The orchestrator uses these weights and heuristics to compute context sufficiency scores during `--map` mode.

```jsonc
{
  "context_sufficiency": {
    // Factor weights (must sum to 1.0)
    "weights": {
      "criteria_specificity": 0.35,     // Do success criteria have verification commands?
      "requirement_detail": 0.35,       // Are requirements specific and actionable?
      "documentation_coverage": 0.15,   // Does project docs cover the relevant domain?
      "dependency_status": 0.15         // Are phase dependencies met?
    },

    // Quick-check threshold for non-blocking warning (CMAP-05)
    "warning_threshold": 5,            // Score below this triggers pre-spawn warning

    // Questioning agent threshold (CMAP-02)
    "questioning_threshold": 8,        // Score below this triggers questioning agent

    // Stub detection patterns (auto-score 1)
    "stub_patterns": ["[To be planned]", "TBD", "[To be defined]"]
  }
}
```

### Context Mapping Event Schemas

Events appended to the `event_log` in `state.json` during context mapping:

```jsonc
// context_mapping_started -- logged when --map mode begins
{
  "timestamp": "2026-02-10T14:30:00Z",
  "event": "context_mapping_started",
  "details": {
    "target_phases": ["5", "9", "10"],         // Phase IDs being mapped
    "mode": "--map 5-10"                        // Original user command
  }
}

// context_mapping_completed -- logged when --map mode finishes
{
  "timestamp": "2026-02-10T14:45:00Z",
  "event": "context_mapping_completed",
  "details": {
    "phases_scored": 6,                         // Total phases evaluated
    "phases_below_threshold": 2,                // Phases scoring below 8
    "questions_generated": 7,                   // Total questions across all phases
    "questions_answered": 7,                    // Questions user answered
    "context_map_path": ".autopilot/context-map.json"
  }
}
```

---

## Section 12: Confidence Enforcement Schemas (CENF-01 through CENF-05)

### Confidence Diagnostic File Schema (CENF-02, CENF-05)

**File:** `.autopilot/diagnostics/phase-{N}-confidence.md`
**Created by:** Orchestrator after any phase completes with alignment_score < 9.0
**Read by:** User, remediation cycle (for targeted feedback), completion report

The confidence diagnostic file is a markdown document generated for every sub-9.0/10 phase completion. It provides a structured analysis of why the phase scored below 9.0 and what specific changes would raise the score. The alignment_score is decimal (x.x format) from the dedicated rating agent.

```markdown
# Phase {N} Confidence Diagnostic

**Score:** {alignment_score}/10 (decimal, from rating agent)
**Threshold:** {pass_threshold}/10 (default 9.0, lenient 7.0)
**Status:** {passed | force_incomplete | remediated_to_{final_score}}

## Judge Concerns
- {concern_1 from judge return JSON concerns[]}
- {concern_2}

## Acceptance Criteria Status
| Criterion | Status | Evidence | Gap |
|-----------|--------|----------|-----|
| {criterion_text} | verified | {file:line evidence} | - |
| {criterion_text} | failed | {evidence if any} | {what is missing} |

## Automated Check Results
| Check | Result | Details |
|-------|--------|---------|
| compile | {pass/fail} | {detail from automated_checks.compile} |
| lint | {pass/fail} | {detail from automated_checks.lint} |
| build | {pass/fail/n/a} | {detail from automated_checks.build} |

## Path to 9/10
1. **{specific_file_path}**: {specific_deficiency} -- fixing this addresses "{judge_concern}" and would resolve {N} of {M} remaining issues
2. **{specific_file_path}**: {specific_deficiency} -- {expected_score_impact}

## Remediation History (if remediation cycles ran)
| Cycle | Score | Changes Made | Remaining Issues |
|-------|-------|-------------|-----------------|
| 0 (initial) | {score} | - | {initial_issues} |
| 1 | {score_after_cycle_1} | {changes_description} | {remaining_issues} |
| 2 | {score_after_cycle_2} | {changes_description} | {remaining_issues} |
```

**CENF-05 rule:** Every item in the "Path to 9.0/10" section MUST contain three components (derived from rating agent's scorecard deductions):
1. A specific file path (e.g., `src/protocols/autopilot-playbook.md`)
2. The specific deficiency in that file (e.g., "Line 450: missing grep pattern for acceptance criterion 3")
3. The expected impact on the score (e.g., "resolves the 'acceptance_criteria_unmet' failure, addressing 1 of 2 judge concerns")

Items that use vague language ("improve code quality", "add better tests", "enhance documentation") violate CENF-05 and MUST be replaced with specific, actionable items.

### Remediation Cycle Event Schemas

Events appended to the `event_log` in `state.json` during confidence enforcement:

```jsonc
// remediation_started -- logged when orchestrator begins a remediation cycle
{
  "timestamp": "2026-02-10T16:00:00Z",
  "event": "remediation_started",
  "details": {
    "phase_id": "7",
    "cycle": 1,                              // 1 or 2
    "current_score": 8.2,                    // Score before remediation (decimal from rating agent)
    "pass_threshold": 9.0,                   // Target score
    "feedback_items": 2                      // Number of targeted deficiencies
  }
}

// remediation_completed -- logged when a remediation cycle finishes
{
  "timestamp": "2026-02-10T16:15:00Z",
  "event": "remediation_completed",
  "details": {
    "phase_id": "7",
    "cycle": 1,
    "old_score": 8.2,
    "new_score": 9.1,
    "improved": true,                        // new_score > old_score
    "reached_threshold": true                // new_score >= pass_threshold
  }
}

// confidence_diagnostic_written -- logged when diagnostic file is generated
{
  "timestamp": "2026-02-10T16:20:00Z",
  "event": "confidence_diagnostic_written",
  "details": {
    "phase_id": "7",
    "alignment_score": 8.2,
    "pass_threshold": 9.0,
    "diagnostic_path": ".autopilot/diagnostics/phase-7-confidence.md",
    "path_to_9_items": 3                    // Number of actionable items in "Path to 9.0/10"
  }
}

// force_incomplete_marked -- logged when phase passes with force_incomplete
{
  "timestamp": "2026-02-10T16:30:00Z",
  "event": "force_incomplete_marked",
  "details": {
    "phase_id": "7",
    "final_score": 8.2,
    "pass_threshold": 9.0,
    "remediation_cycles": 2,
    "diagnostic_path": ".autopilot/diagnostics/phase-7-confidence.md"
  }
}
```

### State Record Extension for Confidence Enforcement

Additional fields in the phase record of `state.json` (Section 1):

```jsonc
{
  // ... existing phase record fields ...
  "force_incomplete": false,            // CENF-03: true when remediation exhausted without reaching pass_threshold
  "diagnostic_path": null,              // CENF-02: ".autopilot/diagnostics/phase-{N}-confidence.md" or null
  "remediation_cycles": 0              // CENF-01: number of remediation cycles (0, 1, or 2)
}
```

### _meta Extension

Additional field in `_meta` of `state.json`:

```jsonc
{
  // ... existing _meta fields ...
  "pass_threshold": 9                  // CENF-01: 9 (default), 7 (with --lenient), or 9.5 (with --quality). Set at invocation.
}
```

---

## CLI Quality Flags Schemas

### discuss-context.json Schema

Written to `.autopilot/discuss-context.json` by the orchestrator during `--discuss` mode. Read by phase-runners during research and planning steps. This is the backward-compatible supplementary Q&A file; the primary artifact is `.planning/phases/{phase}/CONTEXT.md`.

```jsonc
{
  "version": "1.0",
  "last_updated": "ISO-8601",
  "phases": {
    "{phase_id}": {
      "phase_name": "string",
      "gray_areas_discussed": ["area 1", "area 2"],
      "questions": [
        {
          "question": "specific question text",
          "area": "which gray area this belongs to",
          "category": "edge_case|preference|threshold|trade_off|scope",
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

### CONTEXT.md Schema

**File:** `.planning/phases/{N}/CONTEXT.md`
**Created by:** Orchestrator during `--discuss` mode (Section 1.7)
**Read by:** Phase-runner during research step, planner during task design
**Purpose:** Primary artifact from `--discuss` mode. Captures structured decisions from user discussion that take priority over conflicting assumptions.

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

**Sections:**
- **Phase Boundary:** Scope anchor from the roadmap -- immutable reference for what this phase covers.
- **Implementation Decisions:** Per-area decisions captured from the conversational discussion. Includes a "Claude's Discretion" subsection for areas the user explicitly deferred.
- **Specific Ideas:** Concrete references or examples the user mentioned (e.g., "I want it like X").
- **Deferred Ideas:** Out-of-scope ideas captured during discussion for future phases.

### Score History Schema

Added to `phases.{N}` in `state.json`. Tracks alignment score changes across quality flag executions.

```jsonc
{
  // ... existing phases.{N} fields ...
  "score_history": [
    {
      "score": 8.2,                    // decimal x.x format
      "timestamp": "ISO-8601",
      "flag": "initial|force|quality|gaps",  // which flag triggered the re-evaluation
      "cycle": 0                       // remediation cycle number (0 for initial)
    }
  ],
  "quality_exhausted": false,          // true when --quality exhausts 3 cycles without reaching 9.5
  "gaps_exhausted": false              // true when --gaps exhausts 5 iterations without reaching 9.5+
}
```

### Gap Deficiency Schema

Used internally by the orchestrator during `--gaps` mode gap analysis. Not persisted to a file -- used in memory during gap-fix iterations.

```jsonc
{
  "deficiencies": [
    {
      "criterion": "criterion text from plan",
      "current_score": 8.2,            // per-criterion score from rating agent scorecard
      "target_score": 9.5,
      "deficiency": "specific description of what is missing or wrong",
      "target_file": "path/to/file",
      "expected_impact": "fixing this would address X deduction"
    }
  ]
}
```

### CLI Quality Flag Events

Additional event types for the event_log in state.json:

| Event | Level | Description |
|-------|-------|-------------|
| `force_reexecution_started` | Phase | Phase re-execution initiated by --force |
| `quality_remediation_started` | Phase | Quality remediation cycle started for --quality |
| `quality_remediation_completed` | Phase | Quality remediation cycle completed with score change |
| `quality_exhausted` | Phase | Quality remediation exhausted without reaching 9.5/10 |
| `gaps_iteration_started` | Phase | Gap-fix iteration started for --gaps |
| `gaps_iteration_completed` | Phase | Gap-fix iteration completed with score change |
| `gaps_exhausted` | Phase | Gap iterations exhausted without reaching 9.5+/10 |
| `discuss_session_started` | Run | Discussion session initiated by --discuss |
| `discuss_answers_recorded` | Phase | User answers recorded for a discussed phase |
| `flag_mutual_exclusivity_error` | Run | Mutually exclusive flags detected and rejected |

### Event Examples

```jsonc
// force_reexecution_started
{
  "timestamp": "ISO-8601",
  "event": "force_reexecution_started",
  "phase_id": "3",
  "previous_score": 8.4,
  "previous_status": "completed"
}

// quality_remediation_completed
{
  "timestamp": "ISO-8601",
  "event": "quality_remediation_completed",
  "phase_id": "3",
  "cycle": 2,
  "old_score": 8.7,
  "new_score": 9.2,
  "target": 9.5
}

// gaps_iteration_completed
{
  "timestamp": "ISO-8601",
  "event": "gaps_iteration_completed",
  "phase_id": "3",
  "iteration": 1,
  "deficiency_addressed": "criterion text",
  "old_score": 9.0,
  "new_score": 9.3,
  "remaining_deficiencies": 2
}

// discuss_answers_recorded
{
  "timestamp": "ISO-8601",
  "event": "discuss_answers_recorded",
  "phase_id": "3",
  "questions_asked": 4,
  "questions_answered": 4
}
```

---

## Section 13: Sandbox Execution Schemas

**Added by:** Phase 17 (Sandboxed Code Execution)
**Purpose:** Define schemas for execution-based verification results captured by the verifier and rating agent when running code (build, test, lint, scripts) instead of just grepping.

### Execution Result Schema

Each execution-based verification produces a result entry:

```jsonc
{
  "criterion": "Description of the acceptance criterion",
  "command": "the shell command that was executed",
  "exit_code": 0,                    // integer, 0 = success
  "stdout_truncated": "first 500 chars of stdout",
  "stderr_truncated": "first 500 chars of stderr",
  "duration_ms": 1234,               // wall-clock execution time
  "sandbox_violation": false,         // true if command attempted to modify files outside project dir
  "assessment": "pass|fail|timeout|violation"
}
```

**Assessment values:**
- `pass`: exit_code == 0 and output matches expected result
- `fail`: non-zero exit_code, runtime error, or output does not match expected result
- `timeout`: command exceeded 60-second timeout limit
- `violation`: command attempted to modify files outside project directory (sandbox breach)

### Verifier Execution Results (in return JSON)

The verifier includes execution results in its return JSON:

```jsonc
{
  // ... existing verifier return fields ...
  "execution_results": [
    {
      "criterion": "All tests pass",
      "command": "npm test 2>&1",
      "exit_code": 0,
      "output": "All 42 tests passed",
      "assessment": "pass"
    },
    {
      "criterion": "Build succeeds",
      "command": "npm run build 2>&1",
      "exit_code": 1,
      "output": "Error: Module not found: ./missing.ts",
      "assessment": "fail"
    }
  ]
}
```

### Rating Agent Execution Results (in scorecard)

The rating agent includes execution results per-criterion in its scorecard:

```jsonc
{
  // ... existing scorecard item fields ...
  "execution_result": {
    "command": "npm test 2>&1",
    "exit_code": 0,
    "output": "All 42 tests passed"
  }
  // null when criterion uses grep-based verification instead of execution
}
```

### Verification Report Sandbox Section

When execution-based verification is performed, VERIFICATION.md includes a "Sandbox Execution Results" section:

```markdown
## Sandbox Execution Results

| Criterion | Command | Exit Code | Output (truncated) | Assessment |
|-----------|---------|-----------|-------------------|------------|
| Tests pass | npm test 2>&1 | 0 | All 42 tests passed | VERIFIED |
| Build succeeds | npm run build 2>&1 | 1 | Error: Module not found | FAILED |
```

### Sandbox Policy Reference

The sandbox execution policy is defined in `autopilot-playbook.md` under "Sandbox Execution Policy." Key constraints:
- Commands scoped to project directory only
- No global package installs
- No unauthorized network access
- 60-second timeout per command
- Non-zero exit codes reported as verification failures
- Sandbox violations reported as scope_creep in failure taxonomy

---

## Section 14: Repository Map Schema

**File:** `.autopilot/repo-map.json`

The repository map provides structural codebase understanding to all agents. It is generated by the orchestrator before spawning phase-runners and updated incrementally by the executor after commits.

### Schema

```json
{
  "generated_at": "ISO-8601 timestamp",
  "project_root": "/absolute/path/to/project",
  "version": 1,
  "size_cap_applied": false,
  "files": [
    {
      "path": "relative/path/to/file.ts",
      "language": "typescript|javascript|python|go|rust|java|markdown|json|other",
      "exports": [
        {"name": "functionName", "type": "function|class|const|default|type|interface|enum", "line": 42}
      ],
      "imports": [
        {"source": "./other-file", "names": ["importedName", "anotherImport"], "line": 1}
      ],
      "functions": [
        {"name": "functionName", "params": ["param1: string", "param2: number"], "line": 10, "returns": "void"}
      ],
      "classes": [
        {"name": "ClassName", "extends": "BaseClass|null", "methods": ["method1", "method2"], "line": 25}
      ],
      "call_graph": [
        {"caller": "functionName", "callees": ["otherFunction", "ClassName.method1"], "line": 12}
      ]
    }
  ],
  "summary": {
    "total_files": 42,
    "languages": {"typescript": 30, "javascript": 5, "json": 7},
    "top_importers": [{"path": "src/index.ts", "import_count": 15}],
    "top_exporters": [{"path": "src/utils.ts", "export_count": 12}]
  }
}
```

### Field Notes

- `path`: Relative to project root. Excludes `node_modules/`, `dist/`, `.git/`, `build/`, `coverage/`, and other common non-source directories.
- `language`: Detected from file extension. Used for filtering queries.
- `exports`: Named exports, default exports, type exports. For non-module files (e.g., Python), includes top-level definitions.
- `imports`: Import statements with source path and imported names. For dynamic imports, `names` may be `["*"]`.
- `functions`: Top-level and exported function signatures. Does not include internal/private helper functions to keep the map concise.
- `classes`: Class declarations with inheritance chain and public method names.
- `call_graph`: Intra-file call relationships. Each entry maps a caller (function or method name) to its callees (functions or methods it invokes). Only includes calls to symbols defined within the project (excludes external library calls). Used to answer "what calls function Y?" and "what does function X call?" queries. For large files, limit to top-level and exported functions to keep the map concise.
- `summary`: Aggregated statistics for quick orientation. `top_importers` lists the 5 files with the most import statements. `top_exporters` lists the 5 files with the most export statements.

### Size Cap

If the map exceeds 500 lines when serialized as JSON, apply the size cap:
1. Set `size_cap_applied: true`
2. Remove `functions` and `classes` arrays from each file entry (keep only `exports` and `imports`)
3. If still over 500 lines, remove `imports` arrays and keep only `exports`
4. If still over 500 lines, keep only the `summary` section with file paths listed but no per-file details

### Generation Instructions

The orchestrator spawns a general-purpose agent to generate the map:

```
Scan source files in the project directory (excluding node_modules, dist, .git, build, coverage,
.next, __pycache__, .venv, vendor). For each source file:
1. Read the file
2. Extract exports (named exports, default exports, module.exports)
3. Extract imports (import statements, require calls)
4. Extract top-level function signatures (name, params, return type)
5. Extract class declarations (name, extends, method names)
6. Extract intra-file call graph (for each top-level/exported function, list project-internal functions and methods it calls)
Write the result as JSON to .autopilot/repo-map.json using the schema above.
If the resulting JSON exceeds 500 lines, apply the size cap.
```

### Incremental Update Instructions

After the executor commits changes, it updates the map incrementally:

```
For each file modified or added in the commit:
  1. Re-read the file
  2. Update its entry in .autopilot/repo-map.json (replace the existing entry for that path)
For each file deleted in the commit:
  1. Remove its entry from .autopilot/repo-map.json
Update the summary statistics.
Do NOT regenerate the entire map -- only update changed entries.
If .autopilot/repo-map.json does not exist, skip this step.
```

### Structural Query Examples

Agents can use the repo-map for structural queries:

| Query | How to Answer from Map |
|-------|----------------------|
| "Which files import X?" | Filter `files[].imports` where `names` includes "X" |
| "What calls function Y?" | Filter `files[].call_graph` where `callees` includes "Y" -- returns the calling functions. Also filter `files[].imports` where `names` includes "Y" for cross-file callers |
| "What does function X call?" | Find the file containing X, then filter its `call_graph` where `caller` == "X" -- returns the `callees` array |
| "Where is class Z defined?" | Filter `files[].classes` where `name` == "Z" -- returns file path and line |
| "Does function F already exist?" | Filter `files[].functions` where `name` == "F" OR `files[].exports` where `name` == "F" |
| "What does file P export?" | Find `files[]` where `path` == "P" -- read its `exports` array |

---

## Section 15: Debug Session Schema

**Created by:** `/autopilot debug` command and `autopilot-debugger` agent
**Location:** `.planning/debug/{slug}.md` (active), `.planning/debug/resolved/{slug}.md` (resolved)
**Purpose:** Persistent debug session state that survives context resets. The file IS the debugging brain -- it captures the full investigation state so a fresh agent can resume from any point.

### Debug Session File Format

```markdown
---
status: gathering | investigating | fixing | verifying | resolved | diagnosed
trigger: "[verbatim user input or phase failure reference]"
failure_category: "[taxonomy category -- filled when root cause identified]"
created: [ISO-8601 timestamp]
updated: [ISO-8601 timestamp]
---

## Current Focus
<!-- OVERWRITE on each update - reflects NOW -->

hypothesis: [current theory being tested]
test: [how testing it]
expecting: [what result means]
next_action: [immediate next step]

## Symptoms
<!-- Written during gathering, then IMMUTABLE -->

expected: [what should happen]
actual: [what actually happens]
errors: [error messages]
reproduction: [how to trigger]
started: [when broke / always broken]

## Eliminated
<!-- APPEND only - prevents re-investigating dead ends -->

- hypothesis: [theory that was wrong]
  evidence: [what disproved it]
  timestamp: [when eliminated]

## Evidence
<!-- APPEND only - facts discovered during investigation -->

- timestamp: [when found]
  checked: [what was examined]
  found: [what was observed]
  implication: [what this means for the investigation]

## Resolution
<!-- OVERWRITE as understanding evolves -->

root_cause: [empty until found]
failure_category: [taxonomy value from autopilot failure categories]
fix: [empty until applied]
verification: [empty until verified]
prevention_rule: [rule for learnings.md -- specific, actionable]
files_changed: []
```

### Status Transitions

```
gathering -> investigating -> fixing -> verifying -> resolved
                  ^            |           |
                  |____________|___________|
                  (if verification fails)

investigating -> diagnosed (find_root_cause_only mode)
```

| Status | Meaning |
|--------|---------|
| `gathering` | Collecting symptoms from user |
| `investigating` | Autonomous investigation in progress |
| `fixing` | Root cause confirmed, applying fix |
| `verifying` | Fix applied, testing against original symptoms |
| `resolved` | Fix verified, session archived |
| `diagnosed` | Root cause found, no fix applied (find_root_cause_only mode) |

### Section Update Rules

| Section | Rule | When |
|---------|------|------|
| Frontmatter.status | OVERWRITE | Each status transition |
| Frontmatter.updated | OVERWRITE | Every file update |
| Frontmatter.failure_category | OVERWRITE | When root cause classified |
| Current Focus | OVERWRITE | Before every investigation action |
| Symptoms | IMMUTABLE | After gathering phase complete |
| Eliminated | APPEND only | When hypothesis disproved |
| Evidence | APPEND only | After each finding |
| Resolution | OVERWRITE | As understanding evolves |

### Failure Taxonomy Categories

Debug findings are classified using the autopilot failure taxonomy (playbook Section 2.5):

| Category | Description |
|----------|-------------|
| `executor_incomplete` | Task marked complete but acceptance criteria not met |
| `executor_wrong_approach` | Wrong API, algorithm, or implementation approach |
| `compilation_failure` | Syntax error, missing import, type mismatch |
| `lint_failure` | Linting violations, formatting errors |
| `build_failure` | Production build error, missing dependency |
| `acceptance_criteria_unmet` | Specific criterion not satisfied |
| `scope_creep` | Code implemented that was not in spec |
| `context_exhaustion` | Agent ran out of context before completing |
| `tool_failure` | External tool returned unexpected error |
| `coordination_failure` | Handoff between steps lost or corrupted data |

### Learnings Integration

After a debug session resolves, the prevention rule is appended to `.autopilot/learnings.md`:

```markdown
### Debug session: {slug} -- {failure_category}
**Prevention rule:** {specific actionable rule}
**Context:** Root cause: {root_cause}. Recorded: {ISO-8601 timestamp}.
```

### Debug Session Directory Structure

```
.planning/
  debug/
    {slug-1}.md              # Active session
    {slug-2}.md              # Active session
    resolved/
      {slug-3}.md            # Resolved session (archived)
      {slug-4}.md            # Resolved session (archived)
```

---

## Section 16: Visual Testing Schemas

**Added by:** Phase 22 (Visual Testing with Screenshot Automation)
**Purpose:** Define schemas for visual testing configuration, screenshot results, and visual bug reports. Visual testing enables the verification pipeline to launch web/Electron apps, capture screenshots, and analyze them for visual regressions using Claude's multimodal capabilities.

### Visual Testing Configuration Schema

Added to `.planning/config.json` under `project.visual_testing`:

```jsonc
{
  "visual_testing": {
    "enabled": true,                        // master toggle for visual testing
    "framework": "playwright",              // screenshot capture tool (playwright recommended)
    "launch_command": "npm run dev",        // command to start the app server
    "launch_wait_ms": 5000,                 // ms to wait after launch before capturing
    "base_url": "http://localhost:3000",     // app base URL for navigation
    "screenshot_dir": ".planning/screenshots", // directory for captured screenshots
    "routes": [                             // routes/screens to test
      {
        "path": "/",                        // URL path appended to base_url
        "name": "home",                     // human-readable name (used in filenames)
        "wait_ms": 2000                     // ms to wait after navigation before capture
      },
      {
        "path": "/dashboard",
        "name": "dashboard",
        "wait_ms": 3000
      }
    ],
    "viewport": {                           // browser viewport dimensions
      "width": 1280,
      "height": 720
    },
    "headless": true                        // run browser in headless mode (CLI-compatible)
  }
}
```

**Required fields:** `enabled`, `launch_command`, `base_url`, `routes` (at least one route with `path` and `name`).
**Optional fields:** `framework` (default: "playwright"), `launch_wait_ms` (default: 5000), `screenshot_dir` (default: ".planning/screenshots"), `viewport` (default: 1280x720), `headless` (default: true), `routes[].wait_ms` (default: 2000).

### Screenshot Result Schema

Each screenshot capture and analysis produces a result entry:

```jsonc
{
  "route": "/dashboard",
  "name": "dashboard",
  "screenshot_path": ".planning/screenshots/dashboard-20260212T120000Z.png",
  "viewport": {"width": 1280, "height": 720},
  "capture_timestamp": "2026-02-12T12:00:00Z",
  "analysis": {
    "issues_found": 2,
    "issues": [
      {
        "type": "layout|rendering|regression|accessibility",
        "severity": "critical|major|minor",
        "description": "Button overlaps sidebar at 1280px width",
        "location": "top-right quadrant, approximately 200px from top",
        "suggested_fix": "Check CSS flex layout in sidebar component"
      }
    ],
    "overall_assessment": "pass|issues_found|error"
  }
}
```

**Issue types:**
- `layout`: Overlapping elements, broken grids, misaligned text, overflow/clipping
- `rendering`: Blank/white screens, missing images, broken icons, unstyled elements
- `regression`: Visual change compared to baseline screenshot (when baseline exists)
- `accessibility`: Text too small, insufficient contrast, missing visual indicators

**Severity levels:**
- `critical`: App is unusable on the tested route (blank screen, major layout collapse)
- `major`: Significant visual defect affecting user experience (overlaps, missing content)
- `minor`: Cosmetic issue not affecting functionality (slight misalignment, color inconsistency)

### Visual Bug Report Schema

Generated at `.planning/phases/{phase}/VISUAL-BUGS.md` when visual issues are detected:

```jsonc
{
  "phase_id": "22",
  "timestamp": "2026-02-12T12:00:00Z",
  "total_routes_tested": 5,
  "routes_passed": 3,
  "routes_with_issues": 2,
  "screenshots": [
    // Array of Screenshot Result objects (see schema above)
  ],
  "summary": "2 visual issues found across 5 routes",
  "regression_status": "new_issues|resolved|no_change"
}
```

**Regression status values:**
- `new_issues`: Visual issues found that were not present in baseline screenshots
- `resolved`: Previously reported issues are no longer present in current screenshots
- `no_change`: No visual changes detected compared to baseline (or no baseline exists)

### Verifier Visual Test Results (in return JSON)

The verifier includes visual test results in its return JSON when visual testing is performed:

```jsonc
{
  // ... existing verifier return fields ...
  "visual_test_results": {
    "routes_tested": 5,
    "routes_passed": 3,
    "issues_found": [
      {
        "route": "/dashboard",
        "type": "layout",
        "severity": "major",
        "description": "Button overlaps sidebar at 1280px width"
      }
    ],
    "screenshots": [".planning/screenshots/home-20260212.png", ".planning/screenshots/dashboard-20260212.png"],
    "infrastructure_available": true   // false if Playwright not installed or app failed to launch
  }
}
```

When visual testing is not configured or infrastructure is unavailable, this field is omitted from the return JSON (not set to null).

---

## Summary

This document is developer reference documentation for the autopilot orchestration system. It defines 16 sections: (1) a state file schema that tracks run progress and enables crash recovery, (2) circuit breaker configuration with ten tunable thresholds, (3) thirty event types forming an append-only audit log, (4) the directory structure for runtime and phase artifacts, (5) the step agent handoff protocol with JSON return schemas for all agents, (6) trace span and post-mortem schemas for execution observability (OBSV-01 through OBSV-04), (7) learnings file schema for cross-phase learning (LRNG-01 through LRNG-04), (8) metrics and cost schemas for run-level metrics collection, pre-execution cost estimation, and cross-run trend analysis (MTRC-01 through MTRC-03), (9) self-audit schemas for post-completion requirement verification and gap-fix tracking, (10) batch completion report schema for `--complete` mode aggregated reporting (CMPL-04), (11) context mapping schemas for `--map` mode context sufficiency scoring, questioning agent returns, and user answer persistence (CMAP-01 through CMAP-05), (12) confidence enforcement schemas for `--lenient` mode threshold configuration, remediation cycle events, diagnostic file format, and force_incomplete state tracking (CENF-01 through CENF-05) plus CLI quality flags schemas for `--force`, `--quality`, `--gaps`, and `--discuss` modes including discuss-context persistence, CONTEXT.md format, score history tracking, gap deficiency analysis, and flag-specific event types, (13) sandbox execution schemas for execution-based verification results including exit codes, stdout/stderr capture, timeout handling, and sandbox violation detection, (14) repository map schema for structured codebase understanding including exports, imports, functions, classes per file with size caps, incremental update instructions, and structural query examples, (15) debug session schemas for persistent debug state management including session file format, status transitions, failure taxonomy classification, and learnings loop integration, and (16) visual testing schemas for screenshot-based visual regression detection including visual testing configuration, screenshot result format, visual bug reports, and verifier return extensions. For the canonical return contract, see `__INSTALL_BASE__/autopilot/protocols/autopilot-orchestrator.md` Section 4. For step prompt templates, see `__INSTALL_BASE__/autopilot/protocols/autopilot-playbook.md`.
