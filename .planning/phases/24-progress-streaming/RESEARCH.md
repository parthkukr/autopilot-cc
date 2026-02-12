# Research: Phase 24 -- Progress Streaming

## Key Findings

### 1. Current Progress Feedback Architecture

The autopilot system currently provides progress feedback at two levels:

**Orchestrator level (Tier 1):**
- `autopilot-orchestrator.md` line 17-20: Shows a 2-line startup status: `Autopilot: Phases {range} | Spec: {path} ({hash_short}) | Model: {model}` and `Starting phase {first}...`
- Line 747: Logs after completion: `Phase {N} complete. Alignment: {score}/10. Progress: {done}/{total}.`
- Various `Log:` statements for skip/failure decisions throughout Sections 1.1-2

**Phase-runner level (Tier 2):**
- `autopilot-playbook.md` line 1384-1418: Gate decision logs like `Phase {N} PASSED. Proceeding.` and `Phase {N} has failing checks. Entering debug loop.`
- Per-task mini-verification logs: `Task {id} VERIFIED. Proceeding to next task.`
- Various status messages throughout pipeline steps

**Step agent level (Tier 3):**
- Agents write results to files (EXECUTION-LOG.md, VERIFICATION.md, etc.) but do NOT emit real-time progress

### 2. Claude Code Output Constraints

Claude Code agents communicate through text output. The user sees agent output in real-time as it streams. There is no external UI, no progress bars, no terminal control sequences. Progress must be communicated through **structured text messages** that the user can see while the agent is working.

Key constraint: The orchestrator spawns phase-runners via `Task tool` with `run_in_background: false`. This means the orchestrator WAITS for the phase-runner to complete before seeing any output. The phase-runner's output (including progress messages) is captured and returned AFTER completion. The user sees only the orchestrator's output in real-time.

**Critical insight:** Progress messages emitted by Tier 2 (phase-runner) and Tier 3 (step agents) are NOT visible to the user during execution. They are visible only to the agent that spawned them. The only messages the user sees in real-time are those emitted by the Tier 1 orchestrator.

### 3. Where Progress Streaming Can Work

Given the constraints above, progress streaming has THREE viable emission points:

**Point A -- Orchestrator (Tier 1):** Between phase-runner spawns. Can show which phase is starting, which completed. Already does this.

**Point B -- Phase-Runner (Tier 2):** Between step agent spawns. The phase-runner can emit progress text between step agent completions. These messages are captured by the orchestrator and visible to it, but NOT directly to the user during execution.

**Point C -- Step Agents (Tier 3):** During execution, step agents can emit progress text. These are captured by the phase-runner and visible to it, but NOT to the user.

### 4. Recommended Approach

Since the orchestrator is the only tier visible to the user, progress streaming requires the **orchestrator to emit structured progress messages**. However, the orchestrator cannot see phase-runner internals during execution (it waits for the JSON return).

The solution is to use **protocol-level progress markers** in the protocol files that instruct agents at every tier to emit structured progress messages. Even though Tier 2 and Tier 3 messages aren't directly visible to the user during a single phase execution, they ARE visible in the following ways:

1. **Phase-runner text output** IS visible to the orchestrator when the phase-runner completes. But more importantly, the phase-runner's own text output includes its progress messages as it runs through steps.
2. **Orchestrator wrapper messages** can bracket each phase with clear progress indicators.
3. **EXECUTION-LOG.md** already captures per-task progress -- but the key is to add structured progress output to the phase-runner and orchestrator protocol files.

The practical solution: Add structured progress emission instructions to:
- `autopilot-orchestrator.md` -- emit progress before/after each phase spawn
- `autopilot-playbook.md` -- emit progress before/after each pipeline step and each task execution
- `autopilot-phase-runner.md` -- emit progress summary for the phase

### 5. Existing Patterns to Follow

- Log messages use a consistent pattern: `"Phase {N}: ..."` or `"Log: ..."`
- Status messages are plain text, not markdown
- The system uses structured JSON for data handoff, but plain text for status messages

### 6. Risk Assessment

- **Low risk:** This phase modifies only protocol `.md` files (instructions). No runtime code.
- **No regression risk:** Adding progress text instructions to existing protocols does not break existing functionality.
- **Constraint:** Cannot provide true "real-time" streaming from Tier 2/3 to the user. Progress is visible at step boundaries, not continuously.

## Requirements Mapping

Phase 24 has no formal requirements mapped in REQUIREMENTS.md. The roadmap success criteria are:
1. CLI displays current pipeline step (research/plan/execute/verify/judge/rate)
2. CLI shows which task number is active and what file is being modified
3. Compilation gate results (pass/fail) are streamed in real-time
4. Progress indicators work within Claude Code's output constraints

## Open Questions

1. Should progress messages use a specific prefix (e.g., `[PROGRESS]`) to be machine-parseable?
2. Should the orchestrator log estimated remaining time per phase?
