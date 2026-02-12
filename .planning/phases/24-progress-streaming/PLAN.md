# Plan: Phase 24 -- Progress Streaming

## Overview

Add structured progress emission instructions to the three protocol tiers so that users get real-time visibility into pipeline execution. This phase modifies protocol `.md` files only.

## Traceability

| Requirement | Task(s) |
|-------------|---------|
| CLI displays current pipeline step (research/plan/execute/verify/judge/rate) | 24-01, 24-02 |
| CLI shows which task number is active and what file is being modified | 24-02, 24-03 |
| Compilation gate results (pass/fail) streamed in real-time | 24-03 |
| Progress indicators work within Claude Code's output constraints | 24-01, 24-02, 24-03 |

## Tasks

<task id="24-01" type="auto" complexity="medium">

### Task 24-01: Add Progress Emission to Orchestrator Protocol

**Goal:** Add structured progress messages to the orchestrator protocol (`src/protocols/autopilot-orchestrator.md`) so the Tier 1 orchestrator emits pipeline-step-level progress that the user sees in real-time.

**Files:**
- `src/protocols/autopilot-orchestrator.md`

**Action:**
1. In Section 2 (The Loop), add progress emission instructions around the phase-runner spawn. Before spawning, emit a phase progress header. After receiving results, emit a phase completion summary.
2. In the Phase Execution subsection (around line 738), add explicit progress emission instructions with a standard format prefix.
3. Add a new subsection "Progress Streaming Protocol" to Section 2 that defines the standard progress message format for all tiers.

**Progress message format (to be added):**
```
--- [PHASE {N}/{total}] {phase_name} ---
  Step: {step_name} ({step_number}/{total_steps})
  ...
--- [PHASE {N}/{total}] Complete: {score}/10 | {duration} ---
```

**Acceptance Criteria:**
1. The orchestrator protocol contains a "Progress Streaming Protocol" subsection in Section 2 defining the standard format -- verified by: `grep -c 'Progress Streaming Protocol' src/protocols/autopilot-orchestrator.md` (expect >= 1)
2. The orchestrator emits a phase header before spawning each phase-runner -- verified by: `grep -c 'PHASE.*phase_name' src/protocols/autopilot-orchestrator.md` (expect >= 1)
3. The orchestrator emits a step-level progress line when parsing phase-runner results -- verified by: `grep 'Step:' src/protocols/autopilot-orchestrator.md` (expect match)
4. Progress messages use a consistent format prefix that is machine-parseable -- verified by: `grep -c '\-\-\- \[PHASE' src/protocols/autopilot-orchestrator.md` (expect >= 2)

**Verify:** Run test specification: `bash .planning/phases/24-progress-streaming/tests/task-24-01.sh`

**Done:** The orchestrator protocol has explicit progress emission instructions with a consistent format.

</task>

<task id="24-02" type="auto" complexity="medium">

### Task 24-02: Add Step-Level and Task-Level Progress to Playbook

**Goal:** Add structured progress emission instructions to the phase-runner playbook (`src/protocols/autopilot-playbook.md`) so the Tier 2 phase-runner emits progress messages at step boundaries and task boundaries.

**Files:**
- `src/protocols/autopilot-playbook.md`

**Action:**
1. Add a "Progress Emission" section near the beginning of Section 2 (after the Context Budget Table) defining how the phase-runner should emit progress at each pipeline step boundary.
2. In each STEP section (0 through 5), add a progress emission instruction before and after the step executes.
3. In the per-task execution loop (STEP 3), add progress emission instructions that show which task number is active and which files are being modified.
4. Ensure the format is consistent with the orchestrator's Progress Streaming Protocol.

**Step-level progress format (to be added):**
```
[Phase {N}] Step: RESEARCH (1/6)
[Phase {N}] Step: RESEARCH complete.
[Phase {N}] Step: PLAN (2/6)
...
```

**Task-level progress format (to be added):**
```
[Phase {N}] Task {task_id} ({M}/{total}): {task_description}
[Phase {N}] Task {task_id}: modifying {file_path}
[Phase {N}] Task {task_id}: compile PASS
[Phase {N}] Task {task_id}: VERIFIED
```

**Acceptance Criteria:**
1. The playbook contains a "Progress Emission" section defining the step-level format -- verified by: `grep -c 'Progress Emission' src/protocols/autopilot-playbook.md` (expect >= 1)
2. Each major pipeline step (RESEARCH, PLAN, PLAN-CHECK, EXECUTE, VERIFY, JUDGE, RATE) has a progress emission instruction -- verified by: `grep -c '\[Phase {N}\] Step:' src/protocols/autopilot-playbook.md` (expect >= 6)
3. The per-task execution loop includes task-number progress emission -- verified by: `grep -c 'Task {task_id}' src/protocols/autopilot-playbook.md` (expect >= 3)
4. Compilation gate results are included in the task-level progress format -- verified by: `grep 'compile.*PASS\|compile.*FAIL' src/protocols/autopilot-playbook.md` (expect match)
5. File modification progress is included in the task-level format -- verified by: `grep 'modifying.*file' src/protocols/autopilot-playbook.md` (expect match)

**Verify:** Run test specification: `bash .planning/phases/24-progress-streaming/tests/task-24-02.sh`

**Done:** The playbook has explicit progress emission instructions at step and task boundaries.

</task>

<task id="24-03" type="auto" complexity="simple">

### Task 24-03: Add Progress Summary to Phase-Runner Agent Definition

**Goal:** Add progress emission instructions to the phase-runner agent definition (`src/agents/autopilot-phase-runner.md`) so it emits a progress summary and instructs the executor to report file-level and compile-gate progress.

**Files:**
- `src/agents/autopilot-phase-runner.md`

**Action:**
1. Add a `<progress_streaming>` section to the agent definition that instructs the phase-runner to emit pipeline-step progress messages.
2. Add instructions for the phase-runner to pass progress format requirements to the executor when spawning it.
3. Add instructions for the phase-runner to emit task-level and compile-gate progress after each task execution completes.

**Acceptance Criteria:**
1. The agent definition contains a `<progress_streaming>` section -- verified by: `grep -c 'progress_streaming' src/agents/autopilot-phase-runner.md` (expect >= 1)
2. The section instructs the phase-runner to emit step-level progress messages -- verified by: `grep 'emit.*progress\|Progress.*step\|pipeline step' src/agents/autopilot-phase-runner.md` (expect match)
3. The section instructs the phase-runner to pass progress format to the executor -- verified by: `grep 'executor.*progress\|progress.*executor' src/agents/autopilot-phase-runner.md` (expect match)
4. The section includes compile-gate result streaming instructions -- verified by: `grep -i 'compil.*progress\|compile.*result\|compile.*gate.*stream\|compilation.*status' src/agents/autopilot-phase-runner.md` (expect match)

**Verify:** Run test specification: `bash .planning/phases/24-progress-streaming/tests/task-24-03.sh`

**Done:** The agent definition includes progress streaming instructions.

</task>
