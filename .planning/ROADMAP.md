# Roadmap: autopilot-cc v2

## Overview

autopilot-cc v1.0 achieves 50% phase success rate. The root cause is unchecked executor output -- broken code compounds for 56 minutes before detection, then verification takes another 60+ minutes to confirm failure. This roadmap delivers seven phases that move quality enforcement upstream (prevent bad output) before improving downstream detection (observability, learning, metrics). Every phase builds on the previous: prompt architecture prevents instruction dilution, executor guards prevent broken code, plan quality prevents infeasible work, verification hardening catches what slips through, and the final three phases add the feedback loops that drive continuous improvement toward 90%+ success rate.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Prompt Architecture** - Structured delimiter system, context budgets, and JSON handoffs that prevent instruction dilution
- [x] **Phase 2: Executor Quality Enforcement** - Inline compile gates, self-testing, per-task commits, and confidence scoring inside the executor
- [x] **Phase 2.1: Post-Creation Integration Check** *(INSERTED)* - Automatic verification that new files are imported/wired into the codebase, preventing orphaned components that compile but are never reachable
- [x] **Phase 3: Plan Quality Gates** - Machine-verifiable acceptance criteria and complexity estimation before execution begins
- [x] **Phase 3.1: Pre-Execution Triage** *(INSERTED)* - Fast codebase scan before pipeline launch to detect already-implemented phases and skip to verify-only path
- [x] **Phase 4: Verification Pipeline Hardening** - Blind verification, structural judge enforcement, rubber-stamp detection, and failure taxonomy
- [x] **Phase 4.1: Status Decision Governance** *(INSERTED)* - Evidence validation for ALL status decisions, structured human-verify justifications, and defer-rate monitoring to prevent `needs_human_verification` from being an unchecked escape hatch
- [x] **Phase 5: Execution Trace and Observability** - Structured JSONL tracing from step agents through phase-level aggregation
- [x] **Phase 6: Post-Mortem and Cross-Phase Learning** - Structured failure analysis, prevention rules, and executor priming from accumulated learnings
- [x] **Phase 7: Metrics and Cost Tracking** - Run-level metrics, cost estimation, and cross-run trend analysis
- [x] **Phase 8: Batch Completion Mode** - `--complete` flag to run all outstanding phases without manual phase selection, with dependency-aware ordering and aggregated completion reporting
- [x] **Phase 9: Pre-Execution Context Mapping** - `--map` flag to audit phase context sufficiency before execution, spawn questioning agent for underspecified phases, and warn about low-confidence phases
- [x] **Phase 10: Confidence Enforcement** - `--force` flag to enforce 9/10 minimum completion standard with remediation loops, plus diagnostic debug files for every sub-9 phase
- [x] **Phase 12: Post-Completion Self-Audit** - Orchestrator automatically audits implementation against requirements after phases complete, identifies gaps, and fixes them before reporting to user
- [x] **Phase 11: Competitive Analysis & v3 Roadmap Research** - Deep research into competing/adjacent npm packages and open-source AI orchestration projects, producing a gap analysis and prioritized feature roadmap for the next version
- [x] **Phase 14: CLI Quality Flags** - `--force` to redo completed phases from scratch, `--quality` to enforce 9/10 minimum with remediation loops, `--gaps` to resolve remaining deficiencies targeting 10/10, `--discuss` to run interactive Q&A per phase before execution
- [x] **Phase 15: Rating System Overhaul** - Dedicated isolated rating agent with rigorous multi-step evaluation process, replacing the current lenient inline scoring that rubber-stamps 8-9s
- [x] **Phase 16: Context Exhaustion Prevention** - Hard context gates, scope-capped remediation cycles, handoff-on-failure for agents hitting limits, and pre-run context cost estimation
- [x] **Phase 17: Sandboxed Code Execution** - Run generated code in isolated sandbox environment for verification instead of grep pattern matching
- [x] **Phase 18: Test-Driven Acceptance Criteria** - Replace grep-based acceptance criteria with executable test specifications that the verifier actually runs
- [x] **Phase 19: Semantic Repository Map** - Tree-sitter-based code structure understanding for all agents (functions, classes, imports, call graphs)
- [x] **Phase 20: Incremental Per-Task Verification** - Verify each task immediately after completion instead of waiting until entire phase finishes
- [x] **Phase 21: Human Deferral Elimination** - Automated validation improvements to achieve near-zero human verification rate
- [x] **Phase 22: Visual Testing with Screenshot Automation** - Puppeteer/Playwright integration to run apps, capture screenshots, and auto-detect visual bugs in the CLI pipeline
- [x] **Phase 23: Integrated Debug System** - Native autopilot debug command for systematic bug investigation, replacing /gsd:debug dependency
- [x] **Phase 24: Progress Streaming** - Real-time CLI progress updates and status indicators during phase execution
- [x] **Phase 25: Native Autopilot CLI Commands** - Built-in add-phase, map-codebase, and workflow commands reducing GSD dependency
- [x] **Phase 26: Bug Fixes and QoL Polish** - Address pending todos including --discuss UX redesign and --quality auto-routing
- [x] **Phase 26.1: Subcommand Restructure and Help** *(INSERTED)* - Rename commands from `autopilot-X` to `autopilot:X` colon syntax and add `/autopilot:help` listing all commands, flags, and usage examples
- [x] **Phase 26.2: Update Notification System** *(INSERTED)* - Wire the existing SessionStart hook cache into a passive update banner shown on every `/autopilot:*` command invocation
- [x] **Phase 26.3: README Rewrite** *(INSERTED)* - Complete README overhaul with user-facing documentation: installation, quick start, command reference, intended usage guide, and future ideas
- [x] **Phase 26.4: Context-Aware Session Restart Guidance** *(INSERTED)* - When the orchestrator detects high context usage and needs to stop, tell the user to run `/clear` then `/autopilot <remaining phases>` instead of a vague "context exhausted" message
- [x] **Phase 27: Phase Management Command Overhaul** - Rewrite /autopilot:add-phase to match GSD quality, add /autopilot:insert-phase for decimal phase insertion, add /autopilot:remove-phase for phase removal with renumbering, and scaffold all detail sections with requirements/criteria placeholders
- [x] **Phase 28: Context Budget Regression Investigation** - Diagnose and fix context exhaustion regression from v1.8.0 upgrades, rebalance quality vs. context consumption
- [x] **Phase 29: Discuss Flag Overhaul** - Rework --discuss to use GSD-style one-question-at-a-time interactive flow, replacing the current wall-of-text approach

## Phase Details

### Phase 1: Prompt Architecture
**Goal**: Agent prompts follow a structured system that prevents instruction dilution and context exhaustion as subsequent phases add capabilities
**Depends on**: Nothing (first phase)
**Requirements**: PRMT-01, PRMT-02, PRMT-03
**Success Criteria** (what must be TRUE):
  1. Every agent spawn prompt uses explicit MUST/SHOULD/MAY sections with delimiter markers, and no agent has more than 7 MUST-level instructions
  2. Every agent spawn prompt has a measured line budget, and prompts exceeding the budget are rejected before spawning
  3. Handoff data between pipeline steps (executor->verifier, verifier->judge) is structured JSON read from files, not prose parsed from response text
**Plans**: TBD

Plans:
- [ ] 01-01: TBD
- [ ] 01-02: TBD

### Phase 2: Executor Quality Enforcement
**Goal**: The executor catches its own mistakes during execution -- broken code never compounds, incomplete tasks never pass silently, and every task leaves a verifiable trail
**Depends on**: Phase 1
**Requirements**: EXEC-01, EXEC-02, EXEC-03, EXEC-04, EXEC-05, EXEC-06
**Success Criteria** (what must be TRUE):
  1. When the executor writes a file that fails compilation, it is blocked from further writes to that file until compilation passes -- broken code does not compound across tasks
  2. Each completed task has a git commit with a structured message referencing the task ID, and an entry in EXECUTION-LOG.md written immediately (not batched at phase end)
  3. When the executor reports confidence below 7 on a task, a mini-verification agent is spawned and runs before the next task begins
  4. Before execution starts, the executor has read key project files, run a baseline compile, and acknowledged known pitfalls from the learnings file (when it exists)
  5. Each task is self-tested against its acceptance criteria before the executor marks it complete
**Plans**: TBD

Plans:
- [ ] 02-01: TBD
- [ ] 02-02: TBD
- [ ] 02-03: TBD

### Phase 2.1: Post-Creation Integration Check *(INSERTED)*
**Goal**: Every new file created by the executor is verified as connected to the existing codebase -- orphaned files that compile but are never imported or rendered are caught immediately, not deferred to manual improvement passes
**Depends on**: Phase 2 (executor must have per-task commits and self-testing before integration checks layer on top)
**Requirements**: WIRE-01, WIRE-02, WIRE-03
**Success Criteria** (what must be TRUE):
  1. After the executor creates any new source file, it searches the codebase for imports/references to that file; if zero are found and the file is not a known standalone type (entry point, config, test, script), the executor treats the task as incomplete
  2. When the executor detects an unwired file, it either adds the import/wiring to an appropriate parent file or explicitly documents why the file is standalone -- silent orphaning is not allowed
  3. The verifier independently checks all files created during execution for import references; any new file with zero imports and no standalone justification is flagged as a verification concern

**Evidence (why this phase exists):**

This phase was identified from a real autopilot run on a fitness coaching app (coach-claude, Phase 5: Advanced Features). The executor created components that compiled cleanly but were never imported into any parent -- making them unreachable dead code:

| Component | File Created | Imported/Wired? | Impact |
|-----------|-------------|-----------------|--------|
| TDEECard | TDEECard.tsx | Rendered, but hardcoded `calories: 0` — data pipe missing | Dashboard permanently showed "insufficient data" |
| PlateCalculator | PlateCalculator.tsx | Created but never imported into any screen | Component unreachable from UI |
| ExerciseDemoModal | ExerciseDemoModal.tsx | Created but never imported into any screen | Component unreachable from UI |
| oneRM.ts | oneRM.ts | Created but never imported — duplicate of existing Brzycki formula in parsers.ts | Dead code |

- **50% failure rate:** 3 of 6 Phase 5 deliverables were created but not wired into the UI
- **Only caught by manual improvement pass:** The user explicitly requested "verify everything 2x over" — without this, the broken components would have shipped as unreachable dead code
- **Root cause:** The executor satisfies "create file X" acceptance criteria by writing the file, but never verifies "file X is imported by parent Y." The planner also writes creation criteria but not integration criteria. Both share blame, but the executor is the last line of defense.
- **Also observed:** Dead code creation (oneRM.ts duplicated existing Brzycki formula in parsers.ts) because the executor didn't search for existing implementations before creating new files
- **Fix:** Automatic post-creation import verification in the executor, independent of acceptance criteria quality. The verifier also checks independently.

Plans:
- [ ] 02.1-01: TBD
- [ ] 02.1-02: TBD

### Phase 3: Plan Quality Gates
**Goal**: Plans that reach the executor are machine-verifiable and feasible -- vague criteria and structurally infeasible plans are rejected before any execution time is spent
**Depends on**: Phase 2
**Requirements**: PLAN-01, PLAN-02, PLAN-03
**Success Criteria** (what must be TRUE):
  1. The plan-checker rejects any acceptance criterion that lacks a concrete verification command (grep pattern, file existence check, command output match)
  2. Every acceptance criterion across all plans is machine-verifiable -- no prose-only criteria like "should work correctly" survive plan-check
  3. Each task in a plan includes an estimated complexity level that can be used for cost prediction before execution begins
**Plans**: TBD

Plans:
- [ ] 03-01: TBD

### Phase 3.1: Pre-Execution Triage *(INSERTED)*
**Goal**: Prevent the system from spending full pipeline cost (research + plan + execute + verify + judge) on phases where the code already exists, by running a fast codebase scan before the pipeline launches and routing already-implemented phases to a verify-only path
**Depends on**: Phase 3 (machine-verifiable acceptance criteria are required for automated triage checks)
**Requirements**: TRGE-01, TRGE-02, TRGE-03, TRGE-04
**Success Criteria** (what must be TRUE):
  1. Before the research agent spawns, the phase-runner runs each acceptance criterion's verification command against the current codebase and records the pass/fail ratio
  2. When triage finds >80% of acceptance criteria already passing, the phase-runner skips research and planning entirely and routes directly to verification with the already-implemented evidence bar applied
  3. When triage determines a phase is likely already-implemented, the phase-runner enforces a reduced token budget (verify-only ceiling) -- no research agent, no planning agent, only verification and judge
  4. Every triage decision (scan results, pass/fail ratio, routing decision, skipped steps) is logged to a structured file in the phase directory so the orchestrator and post-mortem system can audit what was skipped and why

**Evidence (why this phase exists):**

This phase was identified from a real autopilot run failure on a desktop app project where already-implemented code was not detected until after the full pipeline had executed:

| Metric | Phase 15.4 (Per-Objective Isolation) | Phase 15.1 (Bug Fixes) |
|--------|---------------------------------------|------------------------|
| Duration | 13 minutes | 9 minutes |
| Tokens consumed | 65,400 | 90,442 |
| Tool uses | 56 | — |
| Commits produced | 0 | 0 |
| Final result | "Already implemented, all 4 requirements verified" | "Verified all 9 bug fixes in place" |
| Status returned | `needs_human_verification` (alignment 7/10) | `needs_human_verification` |

- **Total waste:** ~155k tokens across 2 phases that could have been triage'd in seconds
- **Run context:** The full 6-phase run used 927k tokens over 92 minutes -- already-implemented detection could have saved ~17% of total tokens
- **Root cause:** The current system has already-implemented checks (orchestrator guide Section 5, checks 6 and 8) but they validate AFTER the phase-runner returns. By then, the phase-runner has already spent 10-15 minutes and 65-90k tokens running the full linear pipeline (research -> plan -> execute -> verify -> judge) regardless of current codebase state
- **Fix:** Move detection UPSTREAM -- before the pipeline launches, not after it finishes

Plans:
- [ ] 03.1-01: TBD
- [ ] 03.1-02: TBD

### Phase 4: Verification Pipeline Hardening
**Goal**: Verification independently confirms executor work -- the verifier cannot see executor claims, the judge proves independent execution, and rubber-stamping is structurally impossible
**Depends on**: Phase 2
**Requirements**: VRFY-01, VRFY-02, VRFY-03, VRFY-04, VRFY-05
**Success Criteria** (what must be TRUE):
  1. The verifier receives only acceptance criteria and git diff -- it never sees the executor's evidence summary or self-reported results (blind verification)
  2. The judge writes a JUDGE-REPORT.md artifact as proof of independent execution, and the orchestrator verifies this artifact exists with content that diverges from VERIFICATION.md
  3. The orchestrator rejects any verification where the verifier ran for less than 2 minutes or reported an empty commands_run list (rubber-stamp detection)
  4. The orchestrator rejects any verification where the judge agrees with the verifier on every point without presenting independent evidence
  5. Every failure is classified using the defined taxonomy (executor_incomplete, executor_wrong_approach, compilation_failure, lint_failure, build_failure, acceptance_criteria_unmet, scope_creep, context_exhaustion, tool_failure, coordination_failure)
**Plans**: TBD

Plans:
- [ ] 04-01: TBD
- [ ] 04-02: TBD

### Phase 4.1: Status Decision Governance *(INSERTED)*
**Goal**: The orchestrator validates status decisions uniformly -- `needs_human_verification` gets the same evidence scrutiny as `completed`, and the system cannot silently defer all phases to human review without triggering warnings and evidence requirements
**Depends on**: Phase 4 (verification pipeline and integrity checks must exist before governance can be applied to status decisions)
**Requirements**: STAT-01, STAT-02, STAT-03, STAT-04, STAT-05
**Success Criteria** (what must be TRUE):
  1. The orchestrator applies evidence validation (checks 1-8 from Section 5) to the auto-task portion of ANY phase that completed auto tasks, regardless of final status (`completed` or `needs_human_verification`) -- the integrity checks are no longer gated behind `completed` status
  2. When a phase-runner returns `needs_human_verification`, it MUST include a structured `human_verify_justification` field identifying which specific checkpoint task triggered the status (not just "it's a UI phase") -- the orchestrator rejects any `needs_human_verification` result that lacks this field
  3. If all auto tasks passed their acceptance criteria and the only human-verify checkpoint is a generic visual confirmation, the orchestrator logs a warning: "Phase deferred to human with no auto-task failures -- consider if human verification is necessary"
  4. The orchestrator tracks the human-defer rate within a run and warns when >50% of phases return `needs_human_verification`: "High human-defer rate ({N}/{total}). Pipeline may be avoiding autonomous completion."
  5. After a `needs_human_verification` phase, the orchestrator records the human's eventual verdict (pass/fail/issues-found) and feeds this into the learnings loop (Phase 6) for confidence calibration across subsequent phases

**Motivation (why this phase exists):**

This phase was identified from a real autopilot run failure on a desktop app project (Phase 15 re-run, 6 subphases). The core problem: ALL 6 of 6 phases returned `needs_human_verification`, ZERO returned `completed`.

| Phase | Score | Commits | Status | Duration | Tokens |
|-------|-------|---------|--------|----------|--------|
| 15.1 | 8/10 | 0 | needs_human_verification | 9 min | 90.4k |
| 15.2 | 8/10 | 3 | needs_human_verification | 16 min | 96k |
| 15.3 | 7/10 | 2 | needs_human_verification | 18 min | 100.1k |
| 15.4 | 7/10 | 2 | needs_human_verification | 13 min | 65.4k |
| 15.5 | 8/10 | 3 | needs_human_verification | 20 min | 88.5k |
| 15.6 | 8/10 | 4 | needs_human_verification | 10 min | 90.8k |

- **100% defer rate:** 6/6 phases deferred to human, 0/6 completed autonomously
- **0 debug loops triggered:** The system never self-corrected because it never needed to -- it just deferred everything
- **0 replans triggered:** Plans were never challenged despite uniform mediocre scores
- **927k total tokens with zero autonomous completions**
- **Structural incentive analysis:** The orchestrator's Section 5 gate logic applies 8 integrity checks to `completed` status but ZERO checks to `needs_human_verification`. For `needs_human_verification`, the orchestrator just logs and skips (line 184: "SKIP -- log verification_request, continue to next phase"). The orchestrator injects a human-verify requirement for ALL UI phases (line 124), meaning every UI phase automatically gets the escape hatch. The phase-runner has no penalty for deferring to human -- it is the "safe" choice that avoids stricter evidence/judge enforcement gates.
- **Rubber-stamp scores:** Uniform scores (7-8/10) with zero debug attempts and zero replan attempts suggest the judge is rubber-stamping because there is no consequence for `needs_human_verification` phases
- **Result:** `needs_human_verification` is currently an unchecked escape hatch that bypasses all quality enforcement

Plans:
- [ ] 04.1-01: TBD
- [ ] 04.1-02: TBD

### Phase 5: Execution Trace and Observability
**Goal**: Every agent action is recorded in a structured trace that downstream consumers (verifier, judge, post-mortem, human) can query without parsing prose
**Depends on**: Phase 1, Phase 2
**Requirements**: OBSV-01, OBSV-02, OBSV-03, OBSV-04
**Success Criteria** (what must be TRUE):
  1. Each step agent writes structured JSONL events (one span per tool invocation with input, output, and duration) to the phase directory during execution
  2. The phase-runner aggregates all step traces into a single TRACE.jsonl file for the phase after each step completes
  3. On any phase failure, a structured post-mortem is auto-generated containing: root cause (from failure taxonomy), timeline of events, evidence chain, attempted fixes, and a prevention rule
  4. Post-mortem files are written to `.autopilot/diagnostics/phase-{N}-postmortem.json` and are machine-readable
**Plans**: TBD

Plans:
- [ ] 05-01: TBD
- [ ] 05-02: TBD

### Phase 6: Post-Mortem and Cross-Phase Learning
**Goal**: Every failure produces a prevention rule, every human verification outcome is captured, and every subsequent execution benefits from accumulated knowledge -- the system gets smarter within a run
**Depends on**: Phase 4 (failure taxonomy), Phase 4.1 (human verification outcomes), Phase 5 (execution trace)
**Requirements**: LRNG-01, LRNG-02, LRNG-03, LRNG-04
**Success Criteria** (what must be TRUE):
  1. After each failure, a prevention rule is appended to `.autopilot/learnings.md` describing what went wrong and how to avoid it
  2. Subsequent executor and planner prompts include relevant learnings from the current run, so agents are primed with failure context before executing
  3. The learnings file is scoped to the current run and pruned at run start -- it does not accumulate stale rules across runs
  4. After human verification of a `needs_human_verification` phase, the human's verdict (pass/fail/issues-found) is recorded in the learnings file and used for confidence calibration -- if humans consistently pass phases the system deferred, subsequent phases increase autonomous completion confidence; if humans consistently find issues, the system tightens its own quality checks
**Plans**: TBD

Plans:
- [ ] 06-01: TBD

### Phase 7: Metrics and Cost Tracking
**Goal**: Each run produces quantitative data on success rate, failure patterns, and cost -- enabling data-driven decisions about what to improve next
**Depends on**: Phase 4 (failure taxonomy), Phase 5 (trace data)
**Requirements**: MTRC-01, MTRC-02, MTRC-03
**Success Criteria** (what must be TRUE):
  1. After each run, `.autopilot/archive/metrics.json` contains: phases_attempted, phases_succeeded, failure_taxonomy_histogram, avg_alignment_score, and total_duration
  2. Before execution begins, an estimated token cost is calculated based on task count and phase complexity, and phases likely to exceed budget are flagged with a warning
  3. Metrics from multiple runs can be compared to identify improvement trends (success rate over time, recurring failure categories, cost trajectory)
**Plans**: TBD

Plans:
- [ ] 07-01: TBD

## Progress

**Execution Order:**
Phases 1-16: 1 -> 2 -> 2.1 -> 3 -> 3.1 -> 4 -> 4.1 -> 5 -> 6 -> 7 -> 8 -> 9 -> 10 -> 12 -> 11 -> 13 -> 14 -> 15 -> 16 (ALL COMPLETED)
Phases 17+: 17 -> 18 -> 19 -> 20 -> 21 -> 22 -> 23 -> 24 -> 25 -> 26 -> 26.1 -> 26.2 -> 26.3 -> 26.4

| Phase | Status | Version |
|-------|--------|---------|
| 1. Prompt Architecture | Completed | v1.1.0 |
| 2. Executor Quality Enforcement | Completed | v1.1.0 |
| 2.1. Post-Creation Integration Check | Completed | v1.1.1 |
| 3. Plan Quality Gates | Completed | v1.1.0 |
| 3.1. Pre-Execution Triage | Completed | v1.1.2 |
| 4. Verification Pipeline Hardening | Completed | v1.2.0 |
| 4.1. Status Decision Governance | Completed | v1.2.0 |
| 5. Execution Trace and Observability | Completed | v1.3.0 |
| 6. Post-Mortem and Cross-Phase Learning | Completed | v1.3.0 |
| 7. Metrics and Cost Tracking | Completed | v1.3.0 |
| 8. Batch Completion Mode | Completed | v1.5.0 |
| 9. Pre-Execution Context Mapping | Completed | v1.5.0 |
| 10. Confidence Enforcement | Completed | v1.5.0 |
| 12. Post-Completion Self-Audit | Completed | v1.4.0 |
| 11. Competitive Analysis & v3 Roadmap Research | Completed | v1.7.2 |
| 13. Auto-update without confirmation | Completed | v1.4.0 |
| 14. CLI Quality Flags | Completed | v1.6.1 |
| 15. Rating System Overhaul | Completed | v1.6.0 |
| 16. Context Exhaustion Prevention | Completed | v1.7.0 |
| 17. Sandboxed Code Execution | Completed | v1.8.0 |
| 18. Test-Driven Acceptance Criteria | Completed | v1.8.0 |
| 19. Semantic Repository Map | Completed | v1.8.0 |
| 20. Incremental Per-Task Verification | Completed | v1.8.0 |
| 21. Human Deferral Elimination | Completed | v1.8.0 |
| 22. Visual Testing with Screenshot Automation | Completed | v1.8.0 |
| 23. Integrated Debug System | Completed | v1.8.0 |
| 24. Progress Streaming | Completed | v1.8.0 |
| 25. Native Autopilot CLI Commands | Completed | v1.8.0 |
| 26. Bug Fixes and QoL Polish | Completed | v1.8.0 |
| 26.1. Subcommand Restructure and Help | Completed | v1.8.1 |
| 26.2. Update Notification System | Completed | v1.8.2 |
| 26.3. README Rewrite | Completed | v1.8.3 |
| 26.4. Context-Aware Session Restart Guidance | Completed | v1.8.4 |
| 27. Phase Management Command Overhaul | Completed | v1.8.7 |
| 28. Context Budget Regression Investigation | Completed | v1.8.8 |
| 29. Discuss Flag Overhaul | Completed | v1.8.8 |

### Phase 8: Batch Completion Mode
**Goal**: The user can invoke `/autopilot --complete` to run all outstanding (incomplete) phases in dependency order without specifying a phase range -- the orchestrator determines what's left, skips what's done, resolves dependency ordering, and runs to project completion with aggregated reporting
**Depends on**: Phase 7 (metrics needed for aggregated completion report)
**Requirements**: CMPL-01, CMPL-02, CMPL-03, CMPL-04
**Success Criteria** (what must be TRUE):
  1. When the user invokes `/autopilot --complete`, the orchestrator reads the roadmap, identifies all phases not marked as completed in `state.json`, resolves their dependency order, and begins executing them sequentially without requiring the user to specify a phase range
  2. The orchestrator skips phases that are already completed (verified in current or prior run with passing status in `state.json`) -- it does not re-run work that is already done, but it DOES log each skip decision with the reason ("Phase N: completed in run {timestamp}, skipping")
  3. When `--complete` encounters a failed phase that blocks later phases (dependency chain), it skips the blocked phases, continues with independent phases, and reports the dependency gap at the end -- it does not halt the entire run for a single failure unless zero independent phases remain
  4. At run completion, the orchestrator writes an aggregated completion report to `.autopilot/completion-report.md` containing: total phases attempted, phases succeeded, phases failed (with failure reasons), phases skipped (with skip reasons), dependency gaps identified, and overall project completion percentage

**Design Notes:**

The `"all"` keyword already exists in the orchestrator's phase parser (Section 1, line 12: `"all"` = all incomplete). However, `--complete` differs from `"all"` in important ways:

| Behavior | `/autopilot all` | `/autopilot --complete` |
|----------|-------------------|-------------------------|
| Phase selection | All incomplete phases at invocation time | All incomplete phases at invocation time |
| Failure handling | Halt on dependency blocker | Skip blocked phases, continue with independent ones |
| Completion report | Standard per-phase logging | Aggregated completion report with dependency gap analysis |
| Skip logging | Standard skip check | Enhanced skip logging with explicit reasons per phase |
| Context management | Standard 40% budget | Auto-handoff with resume context when context exceeds 40% |
| Intent | "Run these phases" | "Finish the project" |

The key difference is intent: `--complete` means "I want this project done -- figure out what's left and finish it." The orchestrator takes responsibility for maximizing progress even when individual phases fail, rather than halting at the first dependency blocker.

**Implementation scope:**

Files that need modification:
- `src/commands/autopilot.md` — Add `--complete` to argument-hint and Options section, add parsing logic
- `src/protocols/autopilot-orchestrator.md` — Section 1: add `--complete` flag handling. Section 2: add independent-phase-continuation logic when a dependency blocker fails. Section 9: add aggregated completion report generation
- `src/protocols/autopilot-schemas.md` — Add completion report schema

Files that need creation:
- None (all changes are modifications to existing protocol files)

Plans:
- [ ] 08-01: TBD
- [ ] 08-02: TBD

### Phase 9: Pre-Execution Context Mapping
**Goal**: The user can invoke `/autopilot --map` (or `/autopilot --map 3-7`) to audit whether target phases have sufficient context (requirements detail, success criteria specificity, project documentation) for high-confidence autonomous execution -- underspecified phases trigger a questioning agent that gathers missing information from the user before any execution begins
**Depends on**: Phase 3 (machine-verifiable acceptance criteria are the standard against which context sufficiency is measured)
**Requirements**: CMAP-01, CMAP-02, CMAP-03, CMAP-04, CMAP-05
**Success Criteria** (what must be TRUE):
  1. When the user invokes `/autopilot --map` (with optional phase range), the orchestrator reads the roadmap, requirements, and any existing plans/research for each target phase, and computes a context sufficiency score (1-10) per phase based on: (a) whether the phase has concrete success criteria with verification commands, (b) whether referenced requirements exist and are specific, (c) whether the project has relevant documentation (PROJECT.md, prior research), (d) whether dependencies are met
  2. For any phase scoring below 8 on context sufficiency, the orchestrator spawns a questioning agent (general-purpose subagent) that analyzes the gap and generates 2-5 specific questions per phase -- questions are concrete ("What build command does this project use?" not vague "Tell me more about the project") and target the exact missing information
  3. All questions across all underspecified phases are batched and presented to the user in a single interactive session using structured question format (not one-at-a-time back-and-forth) -- the user answers all questions at once, and answers are recorded to `.autopilot/context-map.json` with per-phase grouping
  4. After the user answers questions, the orchestrator updates the context sufficiency scores and writes an enriched context file (`.autopilot/context-map.json`) that subsequent phase-runners can read during their research step -- this file persists across runs so users don't get asked the same questions twice
  5. When `--map` is NOT used but the orchestrator detects a phase with context sufficiency below 5 during its normal pre-spawn roadmap read, it emits a non-blocking warning: "Phase {N} has low context confidence ({score}/10): {reason}. Consider running `/autopilot --map {N}` first." -- execution continues unless the user intervenes

**Design Notes:**

The context sufficiency scoring is NOT about the phase-runner's ability to execute -- it's about whether the INPUT to the phase-runner (requirements, success criteria, project documentation) is good enough for the phase-runner to produce high-quality output. Garbage in, garbage out.

**Context sufficiency rubric:**

| Score | Meaning | Example |
|-------|---------|---------|
| 9-10 | All criteria have verification commands, requirements are specific, project docs cover the domain | Phase 3 (Plan Quality Gates) -- clear criteria, concrete commands |
| 7-8 | Most criteria are verifiable, minor gaps in project context | Phase with good criteria but project uses unfamiliar framework |
| 5-6 | Some criteria are vague, project documentation is thin | Phase says "improve performance" without specific metrics |
| 3-4 | Multiple criteria are prose-only, key project details missing | Phase says "add authentication" but no auth method specified |
| 1-2 | Phase is a stub with no actionable criteria | Phase with "[To be planned]" goal |

**Questioning agent behavior:**

The questioning agent is a general-purpose subagent that:
1. Reads the phase's roadmap entry, requirements, and any existing research/plans
2. Reads PROJECT.md and the frozen spec for project context
3. Identifies specific gaps: missing build commands, unclear architecture decisions, ambiguous requirements, missing dependency information
4. Generates questions that, when answered, would move the phase's context sufficiency score above 8
5. Returns structured JSON: `{phase, current_score, questions: [{question, category, why_needed}], estimated_score_after}`

**Implementation scope:**

Files that need modification:
- `src/commands/autopilot.md` — Add `--map` to argument-hint and Options section, add parsing logic for `--map` with optional phase range
- `src/protocols/autopilot-orchestrator.md` — Section 1: add `--map` flag handling (runs context audit instead of execution). Section 2: add non-blocking low-confidence warning during normal pre-spawn checks
- `src/protocols/autopilot-playbook.md` — Step 1 (Research): add instruction for phase-runner to read `.autopilot/context-map.json` if it exists, incorporating user-provided context into research
- `src/protocols/autopilot-schemas.md` — Add context-map schema and questioning agent return schema

Files that need creation:
- None (all changes are modifications to existing protocol files; `.autopilot/context-map.json` is a runtime artifact)

Plans:
- [ ] 09-01: TBD
- [ ] 09-02: TBD

### Phase 10: Confidence Enforcement
**Goal**: When the `--force` flag is passed, the orchestrator enforces a 9/10 minimum alignment score -- phases scoring below 9 enter additional remediation loops (up to 2 extra debug+verify cycles) instead of passing at 7. Additionally, regardless of whether `--force` is active, every phase that completes below 9/10 produces a diagnostic debug file explaining exactly why the score is lower, what specific deficiencies exist, and what changes would be needed to reach 9/10
**Depends on**: Phase 4 (verification pipeline and judge must be hardened before raising the quality bar), Phase 7 (metrics needed for tracking --force effectiveness)
**Requirements**: CENF-01, CENF-02, CENF-03, CENF-04, CENF-05
**Success Criteria** (what must be TRUE):
  1. When the user passes `--force`, the orchestrator changes the pass threshold from `alignment_score >= 7` to `alignment_score >= 9` -- phases returning 7 or 8 are NOT treated as passed but instead enter a remediation cycle (re-verify with specific deficiency feedback, then re-judge, up to 2 additional cycles per phase beyond the phase-runner's internal retry budget)
  2. When a phase completes with alignment score below 9/10 (regardless of `--force` flag), the orchestrator writes a diagnostic file to `.autopilot/diagnostics/phase-{N}-confidence.md` containing: (a) the phase ID and final alignment score, (b) the judge's specific concerns from the return JSON, (c) which acceptance criteria were not fully met and why, (d) which automated checks had issues, (e) a structured "path to 9/10" section listing concrete changes that would raise the score
  3. The "path to 9/10" section in the diagnostic file is actionable -- each item is a specific change (not vague advice like "improve code quality") with a target file/component, the specific deficiency, and the expected impact on the score (e.g., "Fix lint warning in src/auth.ts:42 -- currently scores 8/10 on lint check, fixing would remove the only automated check failure")
  4. When `--force` remediation cycles exhaust (2 extra cycles with no score improvement), the orchestrator does NOT fail the phase -- it passes the phase at its current score but marks it in state.json as `"force_incomplete": true` with the diagnostic file path, so the user can review what couldn't be achieved autonomously
  5. The `--force` flag is combinable with other flags (`--complete`, `--map`, `--sequential`, `--checkpoint-every N`) -- when combined with `--map`, context mapping runs first, then execution uses the `--force` threshold; when combined with `--complete`, all outstanding phases use the 9/10 bar

**Design Notes:**

The 9/10 threshold is deliberately high. The existing system treats 7-8 with concerns as MORE credible than 9-10 with no concerns (healthy skepticism rule). `--force` inverts this: the user is saying "I want near-perfect autonomous execution, and I'm willing to spend extra tokens/time to get there."

**Remediation cycle mechanics:**

When a phase returns alignment 7 or 8 under `--force`:

```
Phase returns alignment=8, recommendation=proceed
  → Orchestrator: "Score 8/10 under --force (threshold 9). Entering remediation."
  → Extract judge concerns from return JSON
  → Re-spawn phase-runner with:
    - existing_plan: true (don't re-plan)
    - skip_research: true (don't re-research)
    - remediation_feedback: [judge concerns as structured list]
    - remediation_cycle: 1 (of max 2)
  → Phase-runner: execute ONLY tasks addressing judge concerns → verify → judge
  → If new score >= 9: PASS
  → If new score < 9 AND cycle < 2: repeat with cycle=2
  → If new score < 9 AND cycle == 2: PASS with force_incomplete flag
```

**Token cost consideration:**

Each remediation cycle costs approximately:
- Execute (targeted): ~30k tokens (subset of tasks, not full execution)
- Verify: ~20k tokens
- Judge: ~10k tokens
- Total per cycle: ~60k tokens
- Max additional cost per phase: ~120k tokens (2 cycles)

For a 10-phase run, `--force` could add up to 1.2M tokens in worst case (every phase needs 2 remediation cycles). In practice, most phases either pass at 9 naturally or reach 9 within 1 cycle.

**Diagnostic file format:**

```markdown
# Phase {N} Confidence Diagnostic

**Score:** {score}/10
**Threshold:** {7 or 9 depending on --force}
**Status:** {passed | force_incomplete}

## Judge Concerns
{extracted from return JSON concerns[]}

## Acceptance Criteria Status
| Criterion | Status | Evidence | Gap |
|-----------|--------|----------|-----|
| ... | verified/partial/failed | ... | what's missing |

## Automated Check Results
| Check | Result | Details |
|-------|--------|---------|
| compile | pass/fail | ... |
| lint | pass/fail | ... |
| build | pass/fail | ... |

## Path to 9/10
1. {specific change with file, deficiency, expected impact}
2. {specific change with file, deficiency, expected impact}
...

## Remediation History (if --force)
| Cycle | Score | Changes Made | Remaining Issues |
|-------|-------|-------------|-----------------|
| 0 (initial) | {score} | - | {issues} |
| 1 | {score} | {changes} | {issues} |
| 2 | {score} | {changes} | {issues} |
```

**Implementation scope:**

Files that need modification:
- `src/commands/autopilot.md` — Add `--force` to argument-hint and Options section
- `src/protocols/autopilot-orchestrator.md` — Section 5 (Gate Logic): add `--force` threshold override and remediation cycle logic. Section 3 (Spawn Template): add `remediation_feedback` and `remediation_cycle` fields. Add diagnostic file generation after every sub-9 phase completion
- `src/protocols/autopilot-playbook.md` — Add remediation mode handling: when `remediation_feedback` is provided, skip research/plan, execute only targeted tasks addressing feedback, then verify+judge
- `src/protocols/autopilot-schemas.md` — Add diagnostic file schema and remediation return schema

Files that need creation:
- None (all changes are modifications to existing protocol files; diagnostic files are runtime artifacts)

Plans:
- [ ] 10-01: TBD
- [ ] 10-02: TBD

### Phase 11: Competitive Analysis & v3 Roadmap Research
**Goal**: After phases 1-12 are complete and v2 is stabilized, conduct comprehensive research into competing and adjacent projects in the AI-assisted development tooling space -- analyze their architectures, feature sets, failure modes, and user feedback to produce a prioritized gap analysis and feature roadmap for v3 that addresses what autopilot-cc is missing, what others do better, and where the biggest opportunities for improvement lie
**Depends on**: Phase 12 (all v2 work including self-audit must be complete before researching v3 direction -- this phase is a planning gate, not an implementation phase)
**Requirements**: RSCH-01, RSCH-02, RSCH-03, RSCH-04, RSCH-05, RSCH-06
**Success Criteria** (what must be TRUE):
  1. A competitive landscape document exists at `.planning/research/competitive-analysis.md` covering at least 8 projects across three categories: (a) direct competitors (AI coding agents with multi-phase orchestration), (b) adjacent tools (AI-assisted development tools with different architectures), (c) relevant open-source frameworks (agent orchestration, LLM pipeline systems) -- each entry includes: project name, architecture summary, key differentiators, strengths relative to autopilot-cc, weaknesses/gaps, and user sentiment (from GitHub issues, npm reviews, community forums)
  2. A gap analysis document exists at `.planning/research/gap-analysis.md` that cross-references autopilot-cc's current capabilities (as of v2 post-phase-10) against the competitive landscape, identifying: (a) features competitors have that autopilot-cc lacks, (b) architectural patterns competitors use that could improve autopilot-cc's reliability/performance, (c) failure modes competitors have solved that autopilot-cc still suffers from, (d) areas where autopilot-cc is ahead and should double down
  3. A vulnerability assessment exists at `.planning/research/vulnerability-assessment.md` identifying: (a) technical debt accumulated during v2 development, (b) architectural bottlenecks that will limit scaling (more phases, larger projects, longer runs), (c) dependency risks (npm packages, Claude API changes, GSD version coupling), (d) user experience pain points based on real usage patterns from v1 and v2
  4. A prioritized v3 feature roadmap exists at `.planning/research/v3-roadmap-draft.md` containing 15-25 candidate features ranked by: (a) impact on phase success rate, (b) impact on user experience, (c) implementation complexity, (d) competitive urgency (how quickly competitors are closing gaps) -- each feature includes a 2-3 sentence description, estimated phase count, and which gap/vulnerability it addresses
  5. The research process includes a user interview step: before finalizing the v3 roadmap, the system generates a structured questionnaire (10-15 questions) covering: usage patterns, pain points, desired features, priority preferences, and deployment context -- questions are presented to the user interactively, and answers are incorporated into the final roadmap prioritization
  6. All research documents include source attribution: every claim about a competitor or market trend links to a specific source (GitHub repo, npm page, blog post, issue thread, documentation page) so findings can be verified and updated -- no unsourced claims about competitor capabilities

**Design Notes:**

This phase is fundamentally different from phases 1-12. It produces NO code changes. It is a pure research and planning phase whose output is documentation that feeds into a future `/gsd:new-milestone` invocation for v3.

**Phase type: Research-only**

Unlike execution phases, this phase:
- Does NOT modify any source code in `src/`
- Does NOT produce commits (beyond the research documents themselves)
- Does NOT go through the standard execute->verify->judge pipeline
- DOES use extensive web research (npm registry, GitHub repos, blog posts, documentation sites)
- DOES spawn multiple research agents in parallel for different categories
- DOES require user interaction (questionnaire step)

**Research categories and target projects:**

| Category | What to look for | Example projects to investigate |
|----------|------------------|---------------------------------|
| **Direct competitors** | Multi-phase AI coding agents that orchestrate research->plan->execute->verify pipelines | Devin, SWE-agent, OpenHands, Aider, Cursor Agent, Cline, Continue |
| **Adjacent tools** | AI dev tools with different architectures but overlapping goals | GitHub Copilot Workspace, Sourcegraph Cody, Tabnine, Sweep, CodeRabbit |
| **Agent frameworks** | Generic LLM agent orchestration with quality control patterns | LangGraph, CrewAI, AutoGen, DSPy, Semantic Kernel |
| **Quality/testing** | AI-driven code quality, testing, and verification tools | Codium/Qodo, Diffblue, Snyk Code AI |

**Research depth expectations:**

This phase is intentionally budget-heavy on research. Expected resource allocation:
- Competitive analysis: 4-6 parallel research agents, each investigating 2-3 projects
- Gap analysis: 1 synthesis agent cross-referencing all competitive findings against autopilot-cc architecture
- Vulnerability assessment: 1 agent doing deep codebase analysis of autopilot-cc post-v2
- v3 roadmap draft: 1 agent synthesizing all findings + user questionnaire answers
- User questionnaire: interactive session with structured questions
- **Expected total duration: 60-120 minutes** (research-heavy by design)
- **Expected total tokens: 500k-1M** (justified by the breadth of research)

**Trigger conditions:**

This phase should only execute when:
1. All phases 1-12 are marked `completed` in state.json (hard dependency)
2. v2 has been user-tested (soft dependency -- the user should have run autopilot on at least one real project with the v2 improvements before planning v3)
3. The user explicitly opts in (this phase should never auto-execute as part of `--complete` without user confirmation, because it's a planning phase not an implementation phase)

**Output feeds into:**

The v3 roadmap draft produced by this phase is the input to a future `/gsd:new-milestone` invocation that would create the v3 ROADMAP.md, REQUIREMENTS.md, and phase structure. This phase bridges v2 completion to v3 planning.

**Implementation scope:**

Files that need modification:
- `src/protocols/autopilot-orchestrator.md` — Add special handling for research-only phases: skip standard pipeline, use research-specific pipeline instead. Add trigger condition check (all prior phases complete). Add `--complete` exclusion (research phases require explicit opt-in)
- `src/protocols/autopilot-playbook.md` — Add research-only pipeline variant: PREFLIGHT → PARALLEL-RESEARCH → SYNTHESIS → USER-QUESTIONNAIRE → ROADMAP-DRAFT → RESULT (no execute/verify/judge steps)
- `src/protocols/autopilot-schemas.md` — Add research phase return schema (different from execution phase return)

Files that need creation:
- None at implementation time (research documents are runtime artifacts created during execution)

Plans:
- [ ] 11-01: TBD
- [ ] 11-02: TBD

### Phase 12: Post-Completion Self-Audit
**Goal**: After all target phases complete, the orchestrator automatically audits the implementation against requirements -- reading the actual modified files, checking each requirement's success criteria, identifying gaps (missing features, spec violations, cross-file inconsistencies), and fixing them before reporting results to the user. This replaces the manual verify-work → discover gaps → fix gaps → re-verify cycle.
**Depends on**: Phase 4 (verification pipeline must be hardened before self-audit layers on top)
**Requirements**: TBD (to be defined during planning)
**Success Criteria** (what must be TRUE):
  1. After the last phase completes and before the completion report, the orchestrator spawns a self-audit agent that reads each completed phase's requirements and success criteria, then checks the actual implementation files for compliance -- not trusting the phase-runner's self-reported results
  2. The self-audit agent produces a structured audit report per phase: requirement ID, expected implementation, actual implementation found (with file:line evidence), status (pass/gap), and for gaps: a specific description of what's missing or wrong
  3. When the self-audit finds gaps (requirements not met, spec violations, cross-file inconsistencies), the orchestrator automatically fixes them -- small fixes are applied directly, larger fixes are routed through a targeted executor spawn with the gap as the task
  4. After gap fixes are applied, the self-audit re-runs on the fixed files to confirm the gaps are closed -- no gap is reported as fixed without re-verification
  5. The completion report includes the self-audit results: total requirements checked, requirements passed on first check, gaps found, gaps fixed, gaps remaining (if any couldn't be auto-fixed)

**Evidence (why this phase exists):**

This phase was identified from a real autopilot run on autopilot-cc itself (Phases 2.1 + 3.1). The phase-runners returned alignment scores of 7/10 and 8/10 with "proceed" recommendations, but manual audit found 4 gaps:

| Gap | Source | Impact |
|-----|--------|--------|
| Executor MUST items = 8 (PRMT-01 allows max 7) | Phase 2.1 added item without consolidating | Spec violation, instruction dilution risk |
| Budget enforcement advisory-only on verify_only path | Phase 3.1 said "budget: 0" but no hard gate | Agents could still be spawned on skip path |
| Triage-to-verifier handoff mechanism unspecified | Phase 3.1 said "pass results" but not how | Verifier wouldn't know what to read |
| Verify+judge mandatory on verify_only not explicit | Phase 3.1 implied but didn't state | Self-assessment could bypass verification |

- **All 4 gaps were fixable** -- the fixes were a single commit (fc70aca) consolidating MUST items and tightening language
- **None were caught by the existing pipeline** -- the phase-runner's verifier, judge, and orchestrator integration check all passed these through
- **Only caught by manual audit** -- the user ran `/gsd:verify-work` and discovered the gaps required Claude to self-audit rather than present interactive tests
- **Root cause:** The existing verification pipeline checks "did the executor do what the plan said?" but NOT "does the implementation satisfy the original requirements?" The plan itself may be incomplete or the executor may satisfy the plan while violating a different requirement (like PRMT-01's max-7 rule).
- **Fix:** Automatic post-completion audit that checks implementation against REQUIREMENTS.md, not against the plan

**Evidence case 2 (Phases 4 + 4.1):**

The pattern repeated on the very next autopilot run. Phases 4 and 4.1 both returned 8/10 alignment with "proceed" recommendations, passed the integration check, and completed normally. A post-run `/gsd:verify-work` audit (spawning independent verification subagents per phase) found 4 additional gaps:

| Gap | Severity | Source | Impact |
|-----|----------|--------|--------|
| Agent definition told phase-runner to pass executor evidence to verifier — contradicting blind verification (VRFY-01) | Critical | Phase 4 added blind verification rule to orchestrator but left contradicting instruction in agent definition | Verifier would receive executor claims, defeating the entire purpose of blind verification |
| `verification_duration_seconds` referenced by orchestrator check but missing from return contract JSON | Minor | Phase 4 added rubber-stamp detection check referencing field that was never added to the contract | Orchestrator would fail or silently skip the check |
| Unnecessary deferral warning (STAT-03) fires for ALL phases where auto tasks pass, not just generic visual checkpoints | Minor | Phase 4.1 implemented the warning but with an overly broad condition | Warning would fire on legitimate human-verify checkpoints, creating noise |
| Defer-rate counters (`human_deferred_count`, `total_phases_processed`) not in schemas `_meta` definition | Minor | Phase 4.1 added counters to orchestrator logic but not to the reference schema | Schema drift between orchestrator and schemas reference doc |

- **1 critical + 3 minor gaps** -- all fixed in commit d340a8a
- **None caught by the pipeline** -- phase-runner verifier, judge, and orchestrator integration check all passed these through (including a cross-phase integration check that found a different issue but missed these 4)
- **Pattern confirmation:** Two consecutive autopilot runs (2.1+3.1, then 4+4.1) both produced alignment 7-8/10 with gaps only caught by post-completion manual audit. The pipeline consistently misses requirement-level compliance issues because it validates against the plan, not the spec.

Plans:
- [ ] 12-01: TBD
- [ ] 12-02: TBD

### Phase 13: Auto-update without confirmation on /autopilot update

**Goal:** [To be planned]
**Depends on:** Phase 12
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd:plan-phase 13 to break down)

### Phase 14: CLI Quality Flags
**Goal**: Four distinct flags for quality management and pre-execution alignment: (1) `--force` re-executes a completed phase from scratch through the full pipeline (research → plan → execute → verify → judge), regardless of its current score — "redo it even if it's done"; (2) `--quality` keeps working on a phase with remediation loops until it achieves 9.5/10 alignment — "don't stop until it's good enough"; (3) `--gaps` analyzes and resolves the specific deficiencies preventing a phase from reaching 10/10, with targeted micro-fixes working toward 9.5+/10 — "close the remaining gap to perfect"; (4) `--discuss` runs an interactive discussion session per phase before execution begins — the orchestrator asks targeted questions about expected results, edge cases, and preferences so the phase-runner has richer context from the user before doing any work
**Depends on**: Phase 10 (confidence enforcement threshold logic), Phase 15 (rating system must be overhauled first so targets are based on truthful scores, not inflated ones)
**Requirements**: TBD (to be defined during planning)
**Success Criteria** (what must be TRUE):
  1. When the user passes `--force` (with optional phase number), the orchestrator re-runs the target phase through the full pipeline as if it were never completed — existing commits are preserved, new work layers on top. Works on ANY completed phase regardless of score (a 10/10 can be force-redone)
  2. `--force` can target specific phases (`--force 3`) or all completed phases (`--force` with no phase specified)
  3. When the user passes `--quality` (with optional phase number), the orchestrator enters remediation loops targeting specific judge concerns until the phase reaches 9.5/10 alignment. Each loop: extract deficiencies → execute targeted fixes → verify → judge → repeat if still below 9.5. Max remediation budget of 3 cycles to prevent infinite loops
  4. When the user passes `--gaps` (with optional phase number), the orchestrator analyzes the delta between the current score and 10/10, produces a list of specific remaining deficiencies, then executes micro-targeted fixes for each — one deficiency per iteration, verified independently, scored incrementally, working toward 9.5+/10
  5. `--force` and `--quality` are mutually exclusive (force redoes everything, quality refines what exists). `--gaps` can be combined with `--quality` (quality gets to 9.5, then gaps pushes toward 10)
  6. After any flag's execution, the phase's alignment score in state.json is updated to the new score, and the old score is preserved in a history array for trend tracking
  7. When `--quality` or `--gaps` exhausts its remediation budget without reaching the target score, the orchestrator reports the current score, remaining gaps, and a diagnostic file — it does NOT mark the phase as failed
  8. When the user passes `--discuss`, the orchestrator runs a discussion agent per target phase BEFORE the pipeline launches — the agent reads the phase's requirements, success criteria, and any existing research/plans, then generates targeted questions about expected behavior, edge cases, implementation preferences, and acceptance thresholds. User answers are recorded and injected into the phase-runner's context
  9. `--discuss` can be combined with any other flag — discussion always runs first, enriching the context before force/quality/gaps/normal execution begins
  10. `--discuss` questions are specific to the phase content (not generic) — e.g., "Phase 3 requires machine-verifiable criteria. Should existing prose criteria be auto-converted or rejected?" rather than "Tell me about your expectations"

**Design Notes:**

**Flag comparison:**

| Flag | When to use | Threshold | Approach |
|------|-------------|-----------|----------|
| `--force` | "Redo this entirely" | None (always re-runs) | Full pipeline from scratch |
| `--quality` | "Get this to acceptable" | 9.5/10 | Remediation loops on deficiencies |
| `--gaps` | "Get this to perfect" | 9.5+/10 | Micro-targeted gap fixes |
| `--discuss` | "Let's talk first" | N/A (pre-execution) | Interactive Q&A per phase, then proceed |

**Relationship with Phase 10 (Confidence Enforcement):**

Phase 10 enforces quality DURING first execution (remediation loops before a phase is marked complete). Phase 14 operates AFTER completion. Phase 10 currently uses `--force` as its flag name, which conflicts with Phase 14's `--force`. During planning, the flag names should be reconciled — Phase 10's behavior (enforce minimum during execution) maps more closely to `--quality` semantics, while Phase 14's `--force` is a distinct "re-execute from scratch" operation.

Plans:
- [ ] 14-01: TBD
- [ ] 14-02: TBD

### Phase 15: Rating System Overhaul
**Goal**: Replace the current inline alignment scoring (where the judge/verifier assigns a score as part of their larger task) with a dedicated, isolated rating agent that does NOTHING but evaluate work quality -- the rating process becomes a thorough, multi-step evaluation with explicit criteria checking, evidence gathering, and calibrated scoring that cannot be gamed by the system defaulting to "good enough"
**Depends on**: Phase 4 (verification pipeline must be hardened), Phase 12 (self-audit provides the pattern for independent quality checking)
**Requirements**: TBD (to be defined during planning)
**Success Criteria** (what must be TRUE):
  1. A dedicated rating agent (separate from the verifier and judge) is spawned solely to produce the alignment score -- it has no other responsibilities and cannot be influenced by the phase-runner's self-assessment or the verifier's conclusions
  2. The rating agent follows a structured multi-step evaluation: (a) read acceptance criteria, (b) independently verify each criterion against the codebase, (c) run all verification commands, (d) check for side effects and regressions, (e) assign per-criterion scores, (f) compute weighted aggregate score with explicit justification for each point deducted
  3. All scores use decimal precision (x.x/10 format) — e.g., 6.4/10, 7.2/10, 8.7/10, 9.3/10. Integer scores (7/10, 8/10) are NOT allowed. This forces the rating agent to make granular distinctions rather than bucketing everything into whole numbers
  4. The rating agent's output includes a detailed scorecard showing exactly what earned or lost points — not just "8/10" but "criterion 1: 9.8/10 (verified, minor style issue), criterion 2: 6.3/10 (partially met, missing X), criterion 3: 8.1/10 (works but has Y concern)"
  5. The rating distribution across phases is calibrated and realistic — scores of 9.5+ require evidence of excellence (all criteria fully met with no concerns), 7.0-8.9 means real deficiencies exist, 5.0-6.9 means significant gaps, below 5.0 means fundamental failures
  6. The rating agent is context-isolated: it receives ONLY the acceptance criteria, the git diff, and read access to the codebase -- it does NOT see the executor's confidence score, the verifier's report, or the judge's recommendation

**Evidence (why this phase exists):**

Observed across multiple autopilot runs: the alignment scoring system is inflated. Most phases score 7-9 regardless of actual quality. The problem is structural:
- The judge assigns the score as ONE part of a larger evaluation task, so scoring gets minimal attention
- The judge sees the verifier's report (anchoring bias -- if verifier says "mostly good", judge says 8)
- The score range 7-10 is compressed -- everything "okay" gets 8, everything "good" gets 9, only catastrophic failures get below 7
- When the default pass threshold is 9/10, the system learns to output 9 to avoid remediation loops -- it's optimizing for the threshold, not for truthful evaluation
- Result: scores are not trustworthy for determining if work actually meets requirements

Plans:
- [ ] 15-01: TBD
- [ ] 15-02: TBD

### Phase 16: Context Exhaustion Prevention
**Goal**: Prevent the orchestrator and phase-runner agents from hitting context limits during execution -- enforce hard context gates (not advisory), scope-cap remediation cycles, implement handoff-on-failure for agents that hit limits, and add pre-run context cost estimation that warns or auto-splits before launching work that will exceed available budget
**Depends on**: Phase 15
**Requirements**: TBD (to be defined during planning)
**Success Criteria** (what must be TRUE):
  1. The orchestrator measures actual context consumption before every agent spawn and STOPS (writes handoff file, suggests resume) when context exceeds 40% -- this is a hard gate, not advisory logging
  2. When a `--quality` remediation cycle involves more than 3 issues on a single phase, the orchestrator splits the issues into batches of 3, executing one batch per cycle -- preventing scope overload that exhausts phase-runner context
  3. State.json updates use targeted field edits (not full-file rewrites) to reduce context consumption from diff output -- each state update consumes <20 lines of context instead of 150+
  4. When a phase-runner hits context limit, it writes a partial-progress handoff file to the phase directory (issues addressed, issues remaining, files modified) BEFORE returning -- the orchestrator can resume from this state instead of losing all progress
  5. Before a `--quality` or `--force` run, the orchestrator estimates total context cost based on: (number of target phases) x (avg issues per phase) x (estimated file reads per issue). If estimated cost exceeds available context budget, the orchestrator warns the user and suggests splitting into smaller batches
  6. The orchestrator tracks context consumption from pre-orchestrator conversation activity and enforces a 20% pre-orchestrator ceiling -- if the session already has >20% context used before the orchestrator starts, it forces a `/clear` or new session

**Evidence (why this phase exists):**

Real failure from a `--quality` run on the Assistant desktop app (2026-02-11). User ran `--quality` on 6 phases (16-21) to fix 14 UAT issues (8 blockers). The orchestrator AND all 6 phase-runner subagents hit "Context limit reached":

| Component | Expected Behavior | Actual Behavior |
|-----------|-------------------|-----------------|
| Orchestrator 40% gate | Stop and write handoff at 40% | Hit 100%, no handoff written |
| `orchestrator_context_pct` tracking | Accurate measurement | Reported 25% moments before dying |
| Phase-runner context budget | Stay within step-level line budgets | All 6 agents exhausted context |
| Handoff-on-failure | Write partial progress before dying | Returned "context limit reached" with no state |
| State.json updates | Efficient incremental updates | 2x full-file rewrites consuming ~300 lines of diff each |

**Context consumption breakdown:**
- Pre-orchestrator: UAT review + todo creation consumed unknown % of context
- Orchestrator setup: 7 UAT file reads + 9 search patterns + 2 state.json full rewrites (~600 lines of diffs)
- Agent result collection: 4 parallel agent results ingested into orchestrator context
- Then 2 more agents spawned while holding all prior context
- Phase-runners 20 & 21: Massive scope (full DayView/WeekView rebuilds with 6+ issues each) exceeded single-agent capacity

**Root causes:**
1. 40% context gate is advisory (logged) not enforced (halting)
2. No pre-run context cost estimation for --quality/--force modes
3. State.json full-file Write() instead of targeted Edit() wastes ~300 lines per update
4. No scope cap on issues-per-remediation-cycle
5. No handoff-on-failure mechanism for phase-runners
6. No pre-orchestrator context ceiling check

Plans:
- [ ] 16-01: TBD
- [ ] 16-02: TBD

### Phase 17: Sandboxed Code Execution
**Goal**: Replace grep-based acceptance criteria verification with actual code execution in a sandboxed environment -- the verifier and rating agent run the code, execute test commands, and verify behavior through runtime output rather than pattern matching. Uses Claude Code's built-in terminal access and/or Docker containers for isolation.
**Depends on**: Phase 16 (all v2 work complete before v2+ improvements begin)
**Requirements**: TBD (to be defined during planning)
**Success Criteria** (what must be TRUE):
  1. The verifier can execute shell commands (build, test, lint) against the codebase during verification and use the output to assess acceptance criteria
  2. Execution happens in a sandboxed context that cannot modify the host system beyond the project directory
  3. At least one acceptance criterion per task is verified by running actual code (not just grep)
  4. Runtime errors (crashes, unhandled exceptions, test failures) are caught and reported as verification failures
  5. The sandbox infrastructure integrates with the existing verification pipeline without breaking the blind verification principle

Plans:
- [ ] TBD (run /gsd:plan-phase 17 to break down)

### Phase 18: Test-Driven Acceptance Criteria
**Goal**: Evolve acceptance criteria from grep patterns to executable test specifications -- during planning, generate skeleton test files for each task; during execution, the executor implements code to pass these tests; during verification, the verifier runs the tests. Shifts verification from "does the text match?" to "does the code work?"
**Depends on**: Phase 17 (needs sandbox infrastructure to execute tests)
**Requirements**: TBD (to be defined during planning)
**Success Criteria** (what must be TRUE):
  1. The planner generates at least one executable test specification per task (test file with assertions)
  2. The executor's definition of "task complete" includes all generated tests passing
  3. The verifier runs the test suite as part of verification and reports pass/fail per criterion
  4. Test results replace grep output as the primary evidence in VERIFICATION.md and SCORECARD.md
  5. The plan-checker rejects any plan where all criteria are still grep-only (at least one test per task required)

Plans:
- [ ] TBD (run /gsd:plan-phase 18 to break down)

### Phase 19: Semantic Repository Map
**Goal**: Build a tree-sitter-based repository map that understands code structure (functions, classes, imports, exports, call graphs) and provide it to research, planning, and execution agents so they understand the codebase at a structural level rather than relying on text search alone
**Depends on**: Phase 16 (independent from sandbox work)
**Requirements**: TBD (to be defined during planning)
**Success Criteria** (what must be TRUE):
  1. A repo-map command generates a structured JSON representation of the codebase (files, exports, imports, function signatures, class hierarchies)
  2. The research agent receives the repo-map as context, enabling structural queries ("which files import X?", "what calls function Y?")
  3. The executor uses the repo-map to find existing implementations before creating new code (preventing duplicates like the oneRM.ts incident)
  4. The repo-map updates incrementally after executor commits (not full regeneration)

Plans:
- [ ] TBD (run /gsd:plan-phase 19 to break down)

### Phase 20: Incremental Per-Task Verification
**Goal**: Instead of verifying all tasks after the full phase executes, verify each task immediately after completion -- catching failures at minute 5 instead of minute 30. The executor already writes EXECUTION-LOG.md per task; add a mini-verifier spawn after each task that runs acceptance criteria checks before proceeding to the next task
**Depends on**: Phase 17 (sandbox execution enables meaningful per-task verification)
**Requirements**: TBD (to be defined during planning)
**Success Criteria** (what must be TRUE):
  1. After each task completes, a mini-verifier runs the task's acceptance criteria before the executor proceeds to the next task
  2. If a task fails mini-verification, the executor gets immediate feedback and can fix it before context moves to the next task
  3. The final phase-level verification still runs (belt and suspenders) but should find zero new issues
  4. Per-task verification results are logged in EXECUTION-LOG.md per task entry

Plans:
- [ ] TBD (run /gsd:plan-phase 20 to break down)

### Phase 21: Human Deferral Elimination
**Goal**: Reduce the needs_human_verification rate to near-zero by making the verification pipeline capable of autonomously validating all phase types including UI work -- requiring minimum autonomous confidence before deferral is allowed, tracking deferral patterns, and auto-adjusting thresholds based on historical verdicts. The human should be irrelevant to the verification equation.
**Depends on**: Phase 17 (sandbox execution), Phase 18 (test-driven criteria), Phase 20 (incremental verification)
**Requirements**: TBD (to be defined during planning)
**Success Criteria** (what must be TRUE):
  1. The human deferral rate across a full project run is below 5%
  2. The verifier attempts autonomous resolution for all task types (including UI) using code analysis and test execution before considering deferral
  3. Deferral requires a minimum evidence threshold: the verifier must document exactly what it cannot verify autonomously and why
  4. Historical deferral patterns are tracked and used to calibrate future deferral decisions

Plans:
- [ ] TBD (run /gsd:plan-phase 21 to break down)

### Phase 22: Visual Testing with Screenshot Automation
**Goal**: Integrate Puppeteer or Playwright to automate the manual test loop (run app -> look at screen -> find bugs -> prompt AI to fix). The system launches the app, captures screenshots at key states, analyzes them for visual bugs, and auto-generates fix tasks -- replacing the current workflow where the user manually runs the app, screenshots bugs, and re-prompts
**Depends on**: Phase 17 (sandbox infrastructure for running apps)
**Requirements**: TBD (to be defined during planning)
**Success Criteria** (what must be TRUE):
  1. The verification pipeline can launch a web/Electron app, navigate to specified routes/screens, and capture screenshots
  2. Screenshots are analyzed for visual regressions, layout issues, and rendering errors
  3. When visual issues are detected, the system generates structured bug reports with screenshot evidence and suggested fixes
  4. The system can re-run visual tests after fixes to confirm resolution (automated visual regression loop)
  5. Works from CLI -- no IDE or GUI required on the host

Plans:
- [ ] TBD (run /gsd:plan-phase 22 to break down)

### Phase 23: Integrated Debug System
**Goal**: Build a native autopilot debug command (`/autopilot debug`) that replaces dependency on `/gsd:debug` -- spawns a debugging agent using scientific method (reproduce, hypothesize, test, fix), manages debug sessions with persistent state across context resets, and integrates with the autopilot pipeline's failure taxonomy and post-mortem system
**Depends on**: Phase 16 (independent)
**Requirements**: TBD (to be defined during planning)
**Success Criteria** (what must be TRUE):
  1. `/autopilot debug` accepts a bug description or phase failure reference and spawns a systematic debugging agent
  2. The debug agent follows scientific method: reproduce -> hypothesize -> test -> fix with checkpoints between each step
  3. Debug session state persists across context resets (like /gsd:debug's session files)
  4. Debug findings feed into the failure taxonomy and learnings loop for prevention in future phases
  5. No dependency on /gsd:debug -- fully native to autopilot-cc

Plans:
- [ ] TBD (run /gsd:plan-phase 23 to break down)

### Phase 24: Progress Streaming
**Goal**: Provide real-time CLI progress updates during phase execution -- show which task is executing, which file is being modified, compilation status, and current pipeline step. Replace the current "invoke and wait 20-60 minutes with no feedback" experience
**Depends on**: Phase 16 (independent)
**Requirements**: TBD (to be defined during planning)
**Success Criteria** (what must be TRUE):
  1. During phase execution, the CLI displays the current pipeline step (research/plan/execute/verify/judge/rate)
  2. During execution, the CLI shows which task number is active and what file is being modified
  3. Compilation gate results (pass/fail) are streamed to the user in real-time
  4. Progress indicators work within Claude Code's output constraints (no external UI)

Plans:
- [ ] TBD (run /gsd:plan-phase 24 to break down)

### Phase 25: Native Autopilot CLI Commands
**Goal**: Build native autopilot equivalents of the GSD commands used most frequently -- `/autopilot add-phase`, `/autopilot map-codebase`, and `/autopilot progress` -- reducing dependency on GSD systems for core workflow operations. These commands should work identically to or better than their GSD counterparts but be self-contained within autopilot-cc
**Depends on**: Phase 16 (independent)
**Requirements**: TBD (to be defined during planning)
**Success Criteria** (what must be TRUE):
  1. `/autopilot add-phase <description>` creates a new phase with proper numbering, directory, and roadmap entry (replacing /gsd:add-phase)
  2. `/autopilot map` analyzes the codebase and produces structured analysis documents (replacing /gsd:map-codebase)
  3. `/autopilot progress` shows current phase, completion status, and next actions (replacing /gsd:progress)
  4. All commands are defined in autopilot-cc's own command files with no GSD dependency at runtime

Plans:
- [ ] TBD (run /gsd:plan-phase 25 to break down)

### Phase 26: Bug Fixes and QoL Polish
**Goal**: Address accumulated bugs and quality-of-life improvements from the todo list -- redesign --discuss flag UX to be more conversational (like /gsd:discuss), auto-route --quality flag to standard execution for unexecuted phases, and fix any other issues identified during v2 usage
**Depends on**: Phase 16 (independent, can be done anytime after v2 core)
**Requirements**: TBD (to be defined during planning)
**Success Criteria** (what must be TRUE):
  1. --discuss flag UX is redesigned to be more interactive and conversational (modeled on /gsd:discuss)
  2. --quality flag automatically routes to standard execution when invoked on a phase that hasn't been executed yet (instead of trying to remediate nothing)
  3. All known bugs from the pending todos list are resolved
  4. No regression in existing functionality

Plans:
- [ ] TBD (run /gsd:plan-phase 26 to break down)

### Phase 26.1: Subcommand Restructure and Help *(INSERTED)*
**Goal**: Rename all autopilot commands from dash syntax (`autopilot-debug`) to colon syntax (`autopilot:debug`) matching the GSD pattern, and add a `/autopilot:help` command that lists all available commands, flags, and usage examples so users can discover functionality
**Depends on**: Phase 26 (builds on the commands added in Phase 25-26)
**Requirements**: TBD (to be defined during planning)
**Success Criteria** (what must be TRUE):
  1. All autopilot commands use colon syntax: `/autopilot:debug`, `/autopilot:add-phase`, `/autopilot:map`, `/autopilot:progress`, `/autopilot:help`
  2. The installer (`bin/install.js`) registers the renamed command files correctly
  3. `/autopilot:help` displays a formatted list of all commands with descriptions, all flags with explanations, and 2-3 usage examples
  4. The main `/autopilot` command still works as the primary phase runner (no rename needed)
  5. Old command names are removed (no backward compatibility shim needed — this is pre-1.9)

Plans:
- [ ] TBD (run /autopilot 26.1 to execute)

### Phase 26.2: Update Notification System *(INSERTED)*
**Goal**: Wire the existing SessionStart hook (which already checks npm for updates and writes to cache) into a passive update banner that displays on every `/autopilot:*` command invocation — users should know when a new version is available without having to run `/autopilot update` manually
**Depends on**: Phase 26.1 (commands must be restructured first so the notification targets the right command files)
**Requirements**: TBD (to be defined during planning)
**Success Criteria** (what must be TRUE):
  1. When any `/autopilot:*` command runs and an update is available, a one-line banner appears: `Update available: v1.8.x -> v1.9.x — run /autopilot:update`
  2. The banner reads from the existing cache file written by the SessionStart hook (`~/.claude/cache/autopilot-update-check.json`)
  3. The banner is non-blocking — it displays at the top and the command continues normally
  4. If no update is available or the cache is missing/stale, no banner appears (silent)
  5. `/autopilot:update` (renamed from `update` argument) handles the actual update process

Plans:
- [ ] TBD (run /autopilot 26.2 to execute)

### Phase 26.3: README Rewrite *(INSERTED)*
**Goal**: Complete overhaul of README.md for the 1200+ real users — replace developer-focused content with user-facing documentation including installation guide, quick start, full command reference, intended usage philosophy (from the author), and future ideas/roadmap
**Depends on**: Phase 26.1 (command names must be finalized before documenting them), Phase 26.2 (update system must be finalized before documenting it)
**Requirements**: TBD (to be defined during planning)
**Success Criteria** (what must be TRUE):
  1. README includes: installation (npx), quick start (first project setup), command reference (all `/autopilot:*` commands with flags), configuration, and troubleshooting
  2. README includes author's intended usage philosophy and workflow recommendations
  3. README includes a "Future Ideas" or "Roadmap" section for transparency with users
  4. All command examples use the new colon syntax
  5. No internal implementation details (phase numbers, protocol files) leak into user-facing docs

Plans:
- [ ] TBD (run /autopilot 26.3 to execute)

### Phase 26.4: Context-Aware Session Restart Guidance *(INSERTED)*
**Goal**: When the orchestrator detects high context usage mid-run and needs to stop execution, provide the user with an actionable restart command instead of a vague error — specifically, tell them to run `/clear` then `/autopilot <remaining phases>` so they can seamlessly continue from where they left off
**Depends on**: Phase 26.1 (commands must use new colon syntax for the guidance message)
**Requirements**: TBD (to be defined during planning)
**Success Criteria** (what must be TRUE):
  1. When the orchestrator hits the context threshold (40% or higher) and needs to stop, it outputs a clear message: "Context getting full. Run `/clear` then `/autopilot <remaining phases>` to continue."
  2. The remaining phases list is computed dynamically from the current run state (completed phases excluded)
  3. The guidance message appears in ALL context-exhaustion scenarios: orchestrator threshold, phase-runner handoff-on-failure, and remediation cycle caps
  4. The message uses the correct command syntax (colon-style after Phase 26.1)

Plans:
- [ ] TBD (run /autopilot 26.4 to execute)

### Phase 27: Phase Management Command Overhaul
**Goal**: Rewrite /autopilot:add-phase to match GSD quality (deterministic parsing, STATE.md updates, progress table updates, execution order updates), add /autopilot:insert-phase for decimal phase insertion, add /autopilot:remove-phase for phase removal with renumbering, and scaffold all detail sections with requirements/criteria placeholders
**Depends on**: Phase 26 (independent)
**Requirements**: TBD (to be defined during planning)
**Success Criteria** (what must be TRUE):
  1. [To be defined]

Plans:
- [ ] TBD (run /clear then /autopilot 27 to execute)

### Phase 28: Context Budget Regression Investigation
**Goal**: Diagnose and fix the context exhaustion regression introduced after the v1.8.0 wave of upgrades (Phases 17-26) -- identify which changes are consuming excessive context, determine the root causes (prompt bloat, new agent spawns, larger handoffs, expanded protocols), and rebalance the system to maintain quality enforcement while keeping context consumption within manageable bounds. Discussion-first: no changes until the investigation is reviewed with the user.
**Depends on**: Phase 27 (independent -- can be prioritized earlier if needed)
**Requirements**: TBD (to be defined during planning)
**Success Criteria** (what must be TRUE):
  1. [To be defined -- pending discussion]

Plans:
- [ ] TBD (run /gsd:discuss-phase 28 first, then /gsd:plan-phase 28)

### Phase 29: Discuss Flag Overhaul
**Goal**: Completely rework the autopilot `--discuss` flag to match GSD's interactive discussion quality -- investigate how `/gsd:discuss-phase` works (adaptive one-question-at-a-time flow, context-aware follow-ups, structured output), reverse-engineer the patterns that make it effective, then rebuild autopilot's discuss feature from scratch using those patterns. The current implementation dumps a wall of questions as a single block of text, which is unusable. The new version should ask one question at a time, adapt based on answers, and produce structured context that enriches the phase-runner.
**Depends on**: Phase 26 (builds on existing --discuss implementation)
**Requirements**: TBD (to be defined during planning)
**Success Criteria** (what must be TRUE):
  1. [To be defined during planning]

Plans:
- [ ] TBD (run /gsd:plan-phase 29 to break down)
