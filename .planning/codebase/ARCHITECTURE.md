# Architecture

**Analysis Date:** 2026-02-17

## Pattern Overview

**Overall:** Three-tier agent orchestration with hierarchical command delegation and autonomous phase execution pipeline.

**Key Characteristics:**
- Multi-tier agent spawning (Tier 1 orchestrator -> Tier 2 phase-runners -> Tier 3 step agents)
- Command/agent/protocol separation with YAML frontmatter configuration
- Stateful execution with persistent checkpointing in JSON state files
- Goal-driven quality gates with evidence-based verification and independent scoring
- Hook-based update checking that runs asynchronously at session start

## Layers

**Tier 1: Orchestrator (Command)**
- Purpose: Orchestrate phase execution autonomously, manage state, spawn phase-runner subagents, enforce quality gates
- Location: `src/commands/autopilot.md`
- Contains: Phase selection logic, dependency resolution, flag parsing (--complete, --quality, --lenient, etc.), state persistence, completion reporting
- Depends on: Phase-runner agents (via Task tool), state.json, roadmap, orchestrator protocol
- Used by: User invokes `/autopilot` command directly

**Tier 2: Phase-Runner Agents**
- Purpose: Execute all pipeline steps for a single phase, spawn step agents, return structured results
- Location: `src/agents/autopilot-phase-runner.md`
- Contains: Pipeline orchestration (PREFLIGHT -> TRIAGE -> RESEARCH -> PLAN -> EXECUTE -> VERIFY -> JUDGE -> RATE -> GATE -> RESULT), per-task mini-verification loops, context budget enforcement, progress streaming
- Depends on: Step agents (gsd-phase-researcher, gsd-planner, gsd-executor, gsd-verifier, etc.), playbook protocol, JSON return contracts
- Used by: Spawned by Tier 1 orchestrator for each phase

**Tier 3: Step Agents**
- Purpose: Specialize in individual pipeline steps (research, planning, execution, verification, judging, rating, debugging)
- Location: `src/agents/autopilot-debugger.md` (native agent); gsd-* agents from get-shit-done-cc dependency
- Contains: Domain-specific logic for research, planning, code execution, verification, scoring, debugging
- Depends on: Codebase files, test results, compilation output
- Used by: Spawned by Tier 2 phase-runners for each pipeline step

**Supporting Infrastructure: Subcommands**
- Purpose: Provide specialized entry points for mapping, debugging, progress tracking, phase management
- Location: `src/commands/autopilot/` (map.md, debug.md, progress.md, add-phase.md, insert-phase.md, remove-phase.md, help.md, update.md)
- Contains: Narrow-scoped functionality that doesn't require full phase pipeline
- Depends on: Orchestrator state, roadmap, phase directories
- Used by: User invokes `/autopilot:subcommand` directly

**Update Hook System**
- Purpose: Check for autopilot-cc updates asynchronously at session start
- Location: `src/hooks/autopilot-check-update.js`
- Contains: Background process spawning, npm version checking, cache file management
- Depends on: npm registry, cache directory
- Used by: Claude Code SessionStart hook (installed into ~/.claude/settings.json during install)

## Data Flow

**Phase Execution Flow:**

1. User invokes `/autopilot <phases>` (Orchestrator command)
2. Orchestrator parses arguments, reads roadmap, determines phase list, initializes state.json
3. For each phase (or in parallel if not --sequential):
   - Orchestrator spawns phase-runner agent with phase metadata
   - Phase-runner executes pipeline (see below)
   - Phase-runner returns structured JSON result
   - Orchestrator logs result, updates state.json, decides next action (continue, remediate, halt)
4. After all phases, orchestrator writes completion report

**Pipeline Flow (per Phase):**

```
[1] PREFLIGHT
  ├─ Verify spec hash, git state, dependencies met
  └─ Return: all_clear (true/false)

[2] TRIAGE
  ├─ Check if phase already implemented (>80% criteria pass)
  └─ Route: "full_pipeline" | "verify_only"

[3] RESEARCH (conditional)
  ├─ Spawn gsd-phase-researcher
  ├─ Analyze codebase, extract context for phase
  └─ Return: RESEARCH.md with codebase findings

[4] PLAN (conditional)
  ├─ Spawn gsd-planner
  ├─ Create structured plan with tasks
  └─ Return: PLAN.md with task list and acceptance criteria

[5] PLAN-CHECK
  ├─ Spawn gsd-plan-checker
  ├─ Validate plan quality and complexity estimate
  └─ Return: pass/fail with issues if any

[6] EXECUTE (conditional, with per-task loop)
  For each task:
    ├─ Spawn gsd-executor for single task
    ├─ Executor compiles, lints, commits
    ├─ Mini-verify task independently
    ├─ If fail: debug (max 2 attempts), retry mini-verify
    └─ Update EXECUTION-LOG.md
  Return: EXECUTION-LOG.md with all task results

[7] VERIFY
  ├─ Spawn gsd-verifier (blind verification - no executor summary)
  ├─ Verifier checks git diff against acceptance criteria
  ├─ Behavioral traces for UI phases if visual_testing enabled
  └─ Return: pass/fail with evidence

[8] JUDGE
  ├─ Spawn general-purpose judge agent
  ├─ Judge reads git diff, acceptance criteria, verifier report
  ├─ Produces recommendation and concerns (independent of verifier)
  └─ Return: recommendation with justification

[9] RATE
  ├─ Spawn general-purpose rating agent
  ├─ Rating agent computes alignment_score (only from acceptance criteria + git diff)
  ├─ Does NOT see executor confidence, verifier pass/fail, or judge recommendation
  └─ Return: alignment_score (decimal x.x format)

[10] GATE DECISION
  ├─ Compare alignment_score against pass_threshold (default 9, --lenient 7, --quality 9.5)
  ├─ If score >= threshold: PASS (return status "completed")
  ├─ If score < threshold: FAIL (return status "failed" OR route to remediation)
  └─ In --quality mode: enter remediation loop (max 3 cycles)

[11] DEBUG (conditional, max 3 attempts per phase)
  ├─ Spawn autopilot-debugger (or gsd-debugger fallback)
  ├─ Investigate specific failures from verifier/judge/rating
  ├─ Produce failure taxonomy and prevention rules
  └─ Return: root cause + fix recommendation

Return structured JSON to orchestrator with evidence, pipeline_steps, recommendation
```

**State Management:**

- `state.json`: Orchestrator-controlled. Tracks phase completion status, scores, timestamps, learnings, event log, context-map answers
- `.autopilot/context-map.json`: Stores user answers from `--map` and `--discuss` modes
- `.planning/phases/{phase}/CONTEXT.md`: Stores user decisions from `--discuss` pre-execution discussion
- `TRACE.jsonl`: Per-phase execution trace for observability (optional, SHOULD-level)
- `.autopilot/learnings.md`: Cross-phase learning rules (reset each run to prevent pollution)

**Quality Gate Routing:**

- `--complete`: Automatically determines outstanding phases, resolves dependencies, skips completed ones
- `--map`: Pre-execution context audit, gathers missing information
- `--discuss`: Interactive pre-execution discussion of domain gray areas
- `--quality`: Enters remediation loops until score >= 9.5
- `--gaps`: Micro-targeted fixes for remaining deficiencies
- `--force`: Re-executes completed phases from scratch
- `--lenient`: Relaxes pass threshold from 9 to 7

## Key Abstractions

**Phase:**
- Purpose: Unit of work with clear goal, requirements, success criteria, dependencies
- Examples: `src/commands/autopilot.md` defines phase selection logic
- Pattern: Phases are immutable after invocation (frozen roadmap via spec_hash), executed deterministically

**Task:**
- Purpose: Atomic unit of execution within a phase (1-N tasks per phase)
- Examples: PLAN.md task list structure
- Pattern: Tasks are ordered, may have dependencies, compiled/linted individually before commit

**Pipeline Step:**
- Purpose: Specialized role in phase execution
- Examples: Research (gsd-phase-researcher), Planning (gsd-planner), Execution (gsd-executor), Verification (gsd-verifier)
- Pattern: Step agents spawn with narrow context budget, return structured JSON, do not read full prior outputs

**Acceptance Criteria:**
- Purpose: Verifiable definition of "done" for a phase
- Examples: "Run `npm test` with 0 failures", "git diff shows 3 new files in src/api/"
- Pattern: Criteria are concrete (not prose), measurable, used independently by verifier and rating agent

**Remediation Cycle:**
- Purpose: Iterative fix-and-verify loop when score < pass_threshold
- Examples: Judge identifies "missing error handling", executor fixes it, verifier re-checks, rating agent re-scores
- Pattern: Max 3 cycles per phase, each cycle is independent phase-runner spawn with feedback

## Entry Points

**User-Facing Commands:**
- `/autopilot <phases>`: Primary command - runs phase pipeline(s). Location: `src/commands/autopilot.md`
- `/autopilot:help`: Shows command reference. Location: `src/commands/autopilot/help.md`
- `/autopilot:progress`: Shows completion status. Location: `src/commands/autopilot/progress.md`
- `/autopilot:debug`: Interactive debugging. Location: `src/commands/autopilot/debug.md`
- `/autopilot:map`: Context audit. Location: `src/commands/autopilot/map.md`
- `/autopilot:add-phase`: Add new phase. Location: `src/commands/autopilot/add-phase.md`
- `/autopilot:insert-phase`: Insert phase in sequence. Location: `src/commands/autopilot/insert-phase.md`
- `/autopilot:remove-phase`: Remove phase. Location: `src/commands/autopilot/remove-phase.md`
- `/autopilot:update`: Check/install updates. Location: `src/commands/autopilot/update.md`

**Installation Entry Point:**
- `bin/install.js`: npx autopilot-cc installer - copies files to ~/.claude/ or ./.claude/, registers SessionStart hook
- Triggers: When user runs `npx autopilot-cc@latest`

**Background Entry Point:**
- `autopilot-check-update.js` hook: Runs at session start, checks npm registry asynchronously, writes cache

## Error Handling

**Strategy:** Fail-safe with autonomous recovery. Pipeline halts at first unrecoverable error, but attempts debug/remediation before halting.

**Patterns:**

**Preflight Failures:** Return immediately with status "failed", recommendation "halt", issues array populated

**Step Agent Failures:** Log error, spawn debug agent (up to 3 attempts), then:
- If debug finds and fixes root cause: retry the failed step
- If debug exhausts attempts: return failed status with debug evidence in issues array

**Verification Failures:** Verifier returns pass=false. Phase-runner:
- Reads judge's concerns
- Enters remediation cycle if score < pass_threshold (and retries available)
- Logs failure reason to EXECUTION-LOG.md

**Compile/Lint Gates:** Executor refuses to commit if compilation fails. Mini-verifier detects this, triggers debug immediately before proceeding to next task.

**Context Exhaustion (CTXE-01):** If phase-runner detects context overload (tool calls failing, responses truncating):
- Write HANDOFF.md with partial progress
- Return status "failed", recommendation "halt", issues include "context_exhaustion: partial progress saved to HANDOFF.md"
- User can resume from handoff file

**Spec Hash Mismatch:** Preflight detects frozen spec changed. Return status "failed", recommendation "halt", issue "spec_hash_mismatch". Orchestrator handles user notification.

## Cross-Cutting Concerns

**Logging:** Structured progress emission at step boundaries (see `<progress_streaming>` in autopilot-phase-runner.md). No unstructured console.log; all output is either progress lines or JSON returns.

**Validation:** PLAN-CHECK step validates plan before execution. Verifier independently validates acceptance criteria before scoring.

**Authentication:** Not applicable to this system (CLI-based, no API auth needed). GSD dependency check validates installation during setup.

**Quality Assurance:** Multi-layer verification:
1. Executor self-tests (compile, lint)
2. Mini-verifier checks each task independently
3. Full verifier checks git diff against acceptance criteria
4. Judge assesses completeness
5. Rating agent scores alignment
6. No single agent's confidence determines pass/fail

---

*Architecture analysis: 2026-02-17*
