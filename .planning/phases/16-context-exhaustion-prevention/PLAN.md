# Phase 16 Plan: Context Exhaustion Prevention

## Overview
Prevent orchestrator and phase-runner agents from hitting context limits by: (1) replacing the 40% hard context gate with observability-only tracking, (2) adding scope-splitting infrastructure so phase-runners can request work be split into sub-phases, (3) adding handoff-on-failure so agents that hit context limits preserve partial progress, and (4) mandating incremental state.json updates.

## Traceability

| Requirement (from discussion context) | Task |
|---------------------------------------|------|
| Remove 40% hard gate, replace with observability warnings | 16-01 |
| Orchestrator as manager (lightweight, no detailed file reads) | 16-01 |
| Scope splitting (phase-runner initiated, split_request return) | 16-02 |
| Sub-phases run in parallel with independent verification | 16-02 |
| Split UX (brief notification, auto-proceed) | 16-02 |
| Handoff-on-failure for context exhaustion | 16-03 |
| State.json incremental Edit() | 16-03 |
| Pre-run context cost estimation enhancement | 16-01 |

## Tasks

<task id="16-01" type="auto" complexity="complex">
### Task 16-01: Rewrite Orchestrator Context Management and Add Manager-Not-Worker Enforcement

**Files:**
- `src/protocols/autopilot-orchestrator.md` (Section 6 rewrite, Section 1 additions)

**Action:**
1. Rewrite Section 6 (Context Management) to:
   - Remove the 40% hard gate and its "stop and write handoff" behavior
   - Replace with observability-only context tracking: track context % in progress status, warn at 70% and 90% thresholds, but NEVER auto-stop
   - Add "Manager-Not-Worker" enforcement rules: the orchestrator MUST NOT read detailed files (plans, source code, UAT reports, full state dumps). All detailed analysis delegated to sub-agents who return summaries
   - Add pre-run context estimation enhancement: when running --quality or --force on multiple phases, estimate total context cost and warn if it exceeds 80% of estimated session budget
2. Update Section 1 (Invocation) to add a note about the manager-not-worker principle

**Verify:**
Each acceptance criterion has a verification command.

**Acceptance Criteria:**
1. Section 6 no longer contains "40%" as a hard stop threshold -- verified by: `grep -c "exceeds 40%" src/protocols/autopilot-orchestrator.md` (returns 0)
2. Section 6 contains observability-only context tracking with warn-at-70% and warn-at-90% thresholds -- verified by: `grep -c "warn.*70%" src/protocols/autopilot-orchestrator.md` (returns at least 1)
3. Section 6 contains "Manager-Not-Worker" or equivalent enforcement language prohibiting orchestrator from reading detailed files -- verified by: `grep -c "MUST NOT read detailed files" src/protocols/autopilot-orchestrator.md` (returns at least 1)
4. The orchestrator is instructed to delegate all detailed analysis to sub-agents -- verified by: `grep -c "delegate.*sub-agent" src/protocols/autopilot-orchestrator.md` (returns at least 1)
5. Pre-run context estimation warning exists for multi-phase --quality/--force runs -- verified by: `grep -c "estimate.*context.*cost\|context.*estimation" src/protocols/autopilot-orchestrator.md` (returns at least 1)

**Done:** All acceptance criteria pass.
</task>

<task id="16-02" type="auto" complexity="complex">
### Task 16-02: Add Scope-Splitting Infrastructure to Orchestrator and Playbook

**Files:**
- `src/protocols/autopilot-orchestrator.md` (Section 2 loop, Section 4 return contract, new Section 2.1 or subsection)
- `src/protocols/autopilot-playbook.md` (new section for scope-split detection)

**Action:**
1. Add `split_request` as a valid return status in the orchestrator Section 4 (Return Contract):
   - New status: `"split_request"` alongside existing `completed|failed|needs_human_verification`
   - Add `split_details` field to the return contract for split requests
2. Add scope-split handling to orchestrator Section 2 (The Loop):
   - When phase-runner returns `status: "split_request"`, orchestrator reads the split details
   - Spawns N sub-phase-runners in parallel (one per sub-phase)
   - Each sub-phase gets independent verification
   - Completion report shows sub-phases inline: "Phase 20a, 20b, 20c"
   - Brief notification UX: "Phase {N} too large ({reason}). Splitting into {M} sub-phases, launching in parallel..."
3. Add scope-split detection logic to playbook:
   - Add a new subsection in Section 2 (after STEP 3: EXECUTE or as part of pre-execution) describing when and how a phase-runner should detect that scope is too large
   - Split threshold: if remediation feedback contains more than 3 issues AND estimated context exceeds 60% of budget, recommend split
   - Define the split_request return JSON schema

**Verify:**
Each acceptance criterion has a verification command.

**Acceptance Criteria:**
1. The return contract (Section 4) includes `split_request` as a valid status -- verified by: `grep -c "split_request" src/protocols/autopilot-orchestrator.md` (returns at least 1)
2. The return contract includes a `split_details` field definition -- verified by: `grep -c "split_details" src/protocols/autopilot-orchestrator.md` (returns at least 1)
3. The orchestrator loop (Section 2) handles split_request status by spawning sub-phase-runners -- verified by: `grep -c "sub-phase" src/protocols/autopilot-orchestrator.md` (returns at least 1)
4. The playbook contains scope-split detection logic with threshold criteria -- verified by: `grep -ic "scope.split\|split.*detection\|split.*threshold" src/protocols/autopilot-playbook.md` (returns at least 1)
5. The split_request return schema is defined with recommended sub-phases -- verified by: `grep -c "recommended_sub_phases\|sub_phases" src/protocols/autopilot-orchestrator.md` (returns at least 1)
6. Sub-phase notification UX text is defined -- verified by: `grep -c "Splitting into.*sub-phases" src/protocols/autopilot-orchestrator.md` (returns at least 1)

**Done:** All acceptance criteria pass.
</task>

<task id="16-03" type="auto" complexity="medium">
### Task 16-03: Add Handoff-on-Failure and Incremental State Updates

**Files:**
- `src/protocols/autopilot-playbook.md` (Section 3 Error Handling additions)
- `src/protocols/autopilot-orchestrator.md` (Section 7 State File Updates)

**Action:**
1. Add handoff-on-failure protocol to playbook Section 3 (Error Handling):
   - When a phase-runner detects context exhaustion (approaching limit), it writes a HANDOFF.md file to the phase directory
   - HANDOFF.md format: tasks completed, tasks remaining, files modified, partial progress state
   - The existing `context_exhaustion` failure category in the taxonomy already exists -- reference it
   - The orchestrator can resume from HANDOFF.md state on next run
2. Add incremental state update instructions to orchestrator Section 7:
   - Replace full-file Write() instructions with incremental Edit() instructions
   - Each state update should consume <20 lines of context instead of 150+
   - Show example of Edit() usage for updating a single phase status field

**Verify:**
Each acceptance criterion has a verification command.

**Acceptance Criteria:**
1. The playbook error handling section contains handoff-on-failure protocol for context exhaustion -- verified by: `grep -c "HANDOFF.md\|handoff-on-failure\|context exhaustion.*handoff" src/protocols/autopilot-playbook.md` (returns at least 1)
2. HANDOFF.md file format is defined with tasks completed, remaining, and files modified -- verified by: `grep -c "tasks.*completed.*tasks.*remaining\|tasks_completed.*tasks_remaining" src/protocols/autopilot-playbook.md` (returns at least 1)
3. Orchestrator Section 7 contains incremental Edit() instructions -- verified by: `grep -c "incremental.*Edit\|Edit().*targeted\|targeted.*Edit" src/protocols/autopilot-orchestrator.md` (returns at least 1)
4. Section 7 states each update should consume fewer than 20 lines -- verified by: `grep -c "<20 lines\|fewer than 20" src/protocols/autopilot-orchestrator.md` (returns at least 1)

**Done:** All acceptance criteria pass.
</task>

<task id="16-04" type="auto" complexity="simple">
### Task 16-04: Update Agent Definition and Add Context Exhaustion Recovery

**Files:**
- `src/agents/autopilot-phase-runner.md`

**Action:**
1. Update the `<error_handling>` section to add context exhaustion recovery:
   - When approaching context limit: write HANDOFF.md, return with status "failed" and recommendation "halt"
   - Include partial progress in return JSON
2. Update the `<context_rules>` section to reference the new scope-split capability
3. Add a note about the manager-not-worker principle in the phase-runner's understanding of the orchestrator

**Verify:**
Each acceptance criterion has a verification command.

**Acceptance Criteria:**
1. The error_handling section mentions context exhaustion recovery with HANDOFF.md -- verified by: `grep -c "context.*exhaustion\|HANDOFF" src/agents/autopilot-phase-runner.md` (returns at least 1)
2. The agent definition references scope-split capability -- verified by: `grep -c "split_request\|scope.split" src/agents/autopilot-phase-runner.md` (returns at least 1)
3. The context_rules section references the scope-split detection -- verified by: `grep -c "scope.*too large\|split" src/agents/autopilot-phase-runner.md` (returns at least 1)

**Done:** All acceptance criteria pass.
</task>
