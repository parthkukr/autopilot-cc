# Architecture Research

**Domain:** Autonomous coding agent systems -- code execution, test running, and visual verification
**Researched:** 2026-02-17
**Confidence:** HIGH (architecture patterns derived from existing codebase analysis + verified industry patterns)

## System Overview: Existing 3-Tier Architecture + New Capabilities

```
                         EXISTING (preserved)                    NEW (to integrate)
                    ===========================          ============================

                    ┌───────────────────────┐
                    │   ORCHESTRATOR (T1)   │
                    │  Lean loop: spawn,    │
                    │  wait, log, advance   │
Tier 1              │  Owns: state.json,    │─────── Reads: execution evidence in
(coordinator)       │  circuit breaker,     │        return JSON (pass/fail + proof)
                    │  remediation cycles   │
                    └──────────┬────────────┘
                               │ Task tool (spawn)
                    ┌──────────▼────────────┐
                    │   PHASE-RUNNER (T2)   │
                    │  Pipeline coordinator │
                    │  Spawns step agents,  │─────── Routes evidence between steps:
Tier 2              │  reads JSON summaries │        executor build results → verifier
(pipeline)          │  Gates on evidence    │        verifier execution results → judge
                    │  Context budget: ~80L │        visual test results → debug loop
                    └──────────┬────────────┘
                               │ Task tool (spawn per step)
                    ┌──────────▼────────────┐
                    │    STEP AGENTS (T3)   │
                    │                       │
                    │  ┌─────┐ ┌─────────┐  │
                    │  │Rsrch│ │ Planner │  │─────── Planner: generates test specs
Tier 3              │  └─────┘ └─────────┘  │        + execution-based criteria
(workers)           │  ┌─────┐ ┌─────────┐  │
                    │  │Exec │ │Verifier │  │─────── Executor: runs compile/test gates
                    │  └─────┘ └─────────┘  │        Verifier: runs sandbox execution
                    │  ┌─────┐ ┌─────────┐  │          + visual testing + test specs
                    │  │Judge│ │ Rating  │  │        Judge: independent spot-checks
                    │  └─────┘ └─────────┘  │        Rating: uses execution evidence
                    │  ┌──────┐             │
                    │  │Debug │             │─────── Debug: fixes execution failures
                    │  └──────┘             │          + visual bugs
                    └───────────────────────┘
```

### What Already Exists vs. What Needs Building

The existing autopilot-cc v1.9.0 already has **protocol-level definitions** for all major capabilities. The rebuild is about making these actually work reliably. Current state:

| Capability | Protocol Status | Implementation Status | Gap |
|------------|----------------|----------------------|-----|
| Sandbox execution | Schema defined (Section 13), policy in playbook | Commands run but no enforcement of sandbox boundaries | Enforcement is advisory text, not runtime checks |
| Test spec generation | Planner generates `.sh` test files (PLAN step 7) | Test specs written but often skeletal/broken | Test specs need to actually execute and their results need to gate progression |
| Execution-based verification | Verifier Step 1.5 defined with timeout/exit code | Verifier often falls back to grep instead of running code | Execution must be mandatory when project has configured commands |
| Visual testing | Full schema (Section 16), verifier Step 2.5, visual regression loop | Defined but never reliably triggered end-to-end | Playwright screenshot capture + multimodal analysis pipeline |
| Behavioral traces | Verifier methodology defined for UI/mixed phases | Traces attempted but quality is inconsistent | Needs stronger enforcement and trace quality gates |
| Evidence-based returns | Return contracts require `evidence` field | Evidence often shallow ("file exists") not proof-based | Evidence must include execution output, not just structural claims |

## Component Responsibilities

| Component | Responsibility | Communicates With | New Integration Points |
|-----------|---------------|-------------------|----------------------|
| **Orchestrator** | Loop control, state persistence, remediation cycles, visual testing config validation | Phase-runner (spawn/read JSON return) | Validates `visual_testing` config before spawning; passes `visual_testing_enabled` flag; routes visual issues into debug loop |
| **Phase-runner** | Pipeline sequencing, context budget enforcement, evidence routing between steps | All step agents (spawn/read summary) | Routes executor build evidence to verifier; routes visual test results to debug loop; enforces execution evidence in gate decision |
| **Planner** | Task decomposition, acceptance criteria with verification commands, test spec generation | Phase-runner (returns plan summary) | Generates executable test specs (`.sh` files) with real assertions; includes execution-based criteria referencing `project.commands.*` |
| **Executor** | Code writing, compile/lint gates, atomic commits, test spec updates | Phase-runner (returns execution evidence) | Runs compile + test gates before every commit; updates test spec files with implementation-specific details; reports build output as structured evidence |
| **Verifier** | Independent blind verification, sandbox execution, visual testing, behavioral traces | Phase-runner (returns criteria results + execution results + visual results) | Runs acceptance criteria commands (Step 1.5); executes test specs (Step 1.7); launches app + captures screenshots (Step 2.5); performs behavioral traces (Step 2) |
| **Judge** | Adversarial second opinion, independent spot-checks | Phase-runner (returns recommendation + concerns) | Spot-checks execution results; verifies visual test findings independently |
| **Rating Agent** | Context-isolated scoring, per-criterion evaluation | Phase-runner (returns alignment score + scorecard) | Incorporates execution results and test spec output into scoring; visual quality deductions for UI phases |
| **Debugger** | Scientific hypothesis-driven debugging, fix application | Phase-runner (returns fix results) | Receives both functional failures AND visual bugs from `VISUAL-BUGS.md`; re-runs failing tests after fixes |

## Recommended Project Structure (New/Modified Files)

The new capabilities layer onto the existing file structure. No structural reorganization needed.

```
src/
├── protocols/
│   ├── autopilot-orchestrator.md    # MODIFY: strengthen visual testing config validation
│   ├── autopilot-playbook.md        # MODIFY: strengthen sandbox enforcement, test spec
│   │                                #   execution, visual testing reliability
│   └── autopilot-schemas.md         # MODIFY: extend Section 13 (sandbox) and 16 (visual)
│                                    #   with stricter enforcement schemas
├── agents/
│   ├── autopilot-phase-runner.md    # MODIFY: enforce execution evidence in gate decisions
│   └── autopilot-debugger.md        # MODIFY: handle visual bug reports alongside functional
└── commands/
    └── autopilot.md                 # MODIFY: ensure --visual flag handling is robust

.planning/
├── config.json                      # MODIFY: project.commands.* and project.visual_testing.*
│                                    #   become first-class required configuration
├── phases/{N}-{name}/
│   ├── tests/                       # EXISTS: test spec directory (needs quality enforcement)
│   │   └── task-{id}.sh             # EXISTS: bash test specs (need to actually work)
│   ├── VISUAL-BUGS.md               # EXISTS: visual bug report (needs reliable generation)
│   └── VERIFICATION.md              # EXISTS: includes Sandbox Execution Results section
└── screenshots/                     # EXISTS: visual testing screenshots directory
    └── baseline/                    # EXISTS: baseline screenshots for regression detection
```

### Structure Rationale

- **No new files or directories needed.** The schemas, protocols, and file locations are already defined. The gap is in enforcement and reliability, not in missing infrastructure.
- **`.planning/config.json`** is the single source of truth for project commands (compile, lint, build, test) and visual testing configuration. All agents derive their commands from this file.
- **Test specs live per-phase** in `.planning/phases/{N}/tests/` because they are phase-scoped artifacts, not project-level tests. They verify that the phase's acceptance criteria are met, not that the project's test suite passes (though they can invoke the project's test suite).

## Architectural Patterns

### Pattern 1: Evidence Chain (Execution Output as First-Class Data)

**What:** Every verification claim must be backed by structured execution evidence -- exit codes, stdout/stderr, duration. Evidence flows upward through the tiers without interpretation at each level.

**When to use:** Every verification step, every gate decision, every return JSON.

**Trade-offs:** More verbose return payloads (mitigated by context budget truncation); slower verification (mitigated by 60-second timeout); but dramatically more trustworthy results.

**How it works in the existing architecture:**
```
Executor runs: npm run build 2>&1; echo EXIT:$?
  → Records: {command: "npm run build", exit_code: 0, stdout: "Built successfully"}
  → Returns in JSON to phase-runner

Phase-runner passes to verifier (BLIND -- no executor evidence forwarded)

Verifier independently runs: npm run build 2>&1; echo EXIT:$?
  → Records: {criterion: "Build succeeds", exit_code: 0, assessment: "pass"}
  → Returns in execution_results array

Phase-runner passes to rating agent (ISOLATED -- no verifier/judge evidence)

Rating agent runs: git diff + reads codebase + runs verification commands
  → Records: per-criterion scores with execution_result objects
  → Returns authoritative alignment_score
```

The key insight: **three independent agents all run the same commands and compare results**. Agreement = high confidence. Disagreement = investigation needed.

### Pattern 2: Sandbox-Within-Claude-Code (Soft Sandbox, Not Container Isolation)

**What:** autopilot-cc does not run in a container. It runs inside Claude Code, which already provides a permission model (the user approves tool access at session start). The "sandbox" is a protocol-enforced policy, not a hardware boundary.

**When to use:** All execution-based verification commands.

**Trade-offs:** Not truly isolated (a malicious command could escape), but appropriate for the threat model (the agent is generating and running its own code in the user's project directory, not executing untrusted third-party code). The real risk is not malice but mistakes -- accidentally deleting files, running destructive commands, or modifying files outside scope.

**Policy enforcement (existing, needs strengthening):**
- Commands MUST NOT modify files outside the project directory
- No global package installs (`npm install -g` blocked)
- No unauthorized network access
- 60-second timeout per command
- Exit codes and stderr captured for every execution
- Sandbox violations classified as `scope_creep` in failure taxonomy

**What needs to change:** The current policy is advisory text in the playbook. The verifier and executor need explicit pre-execution checks: validate the command against a blocklist before running it, and post-execution checks: verify no files outside project directory were modified.

### Pattern 3: Visual Testing as Enhancement, Not Gate

**What:** Visual testing (screenshots via Playwright) provides supplementary evidence for UI phases. It does NOT block verification if infrastructure is unavailable.

**When to use:** UI and mixed phase types when `project.visual_testing` is configured in `.planning/config.json`.

**Trade-offs:** Requires Playwright installed (not always available); app must actually launch (fragile for complex apps); screenshot analysis depends on Claude's multimodal capabilities (good but not pixel-perfect). However, it catches the class of bugs that are invisible to code analysis: layout breaks, rendering failures, blank screens, missing images -- the bugs that a human would catch in 5 seconds of looking at the screen.

**How it integrates with existing tiers:**
```
Orchestrator (T1):
  - Validates visual_testing config before spawning phase-runner
  - Passes visual_testing_enabled: true to phase-runner spawn prompt
  - Routes visual issues (severity critical/major) into debug loop

Phase-runner (T2):
  - Passes visual_testing_enabled flag to verifier spawn prompt
  - After verifier returns: checks visual_test_results.issues_found
  - If critical/major issues: feeds VISUAL-BUGS.md to debugger alongside functional failures

Verifier (T3):
  - Step 2.5: Launches app, captures screenshots, analyzes with Read tool (multimodal)
  - Records issues in VERIFICATION.md "Visual Testing Results" section
  - Generates VISUAL-BUGS.md if issues found
  - Returns visual_test_results in JSON

Debugger (T3):
  - Receives VISUAL-BUGS.md as additional context
  - Applies fixes, then re-verification includes re-running Step 2.5
  - Resolution tracked in VISUAL-BUGS.md resolution table
```

### Pattern 4: Test Spec as Ground Truth

**What:** The planner generates bash test scripts (`.planning/phases/{N}/tests/task-{id}.sh`) that contain executable assertions for each acceptance criterion. Test spec results are PRIMARY evidence -- they override grep-based verification when results disagree.

**When to use:** Every phase, every task. Test specs are generated at planning time and may be updated by the executor during implementation.

**Trade-offs:** Test specs add planning overhead (mitigated by being part of the existing plan step); test specs can be wrong (mitigated by mini-verification after each task); but they provide the closest thing to a real test suite that's specific to the phase's acceptance criteria.

**Lifecycle:**
```
1. PLAN step:    Planner generates test spec skeleton with assertions based on criteria
2. EXECUTE step: Executor may update test spec with implementation-specific details
3. VERIFY step:  Verifier runs each test spec (Step 1.7), captures PASS/FAIL output
4. RATE step:    Rating agent uses test spec output as primary scoring evidence
5. DEBUG step:   Debugger can re-run specific test specs to confirm fixes
```

## Data Flow

### Execution Evidence Flow (Critical Path)

```
                    config.json
                    (project.commands.*)
                         │
                         ▼
┌────────────────────────────────────────────────────────┐
│                    PLAN STEP                           │
│  Reads project.commands → generates criteria with      │
│  execution commands: "{project.commands.test} 2>&1;    │
│  echo EXIT:$?" and test spec files                     │
└────────────────────┬───────────────────────────────────┘
                     │ PLAN.md + tests/*.sh
                     ▼
┌────────────────────────────────────────────────────────┐
│                   EXECUTE STEP                         │
│  Per-task: write code → run compile → run lint →       │
│  commit. Compile gate: MUST fix before next file.      │
│  Returns: {files_modified, compile_result, evidence}   │
└────────────────────┬───────────────────────────────────┘
                     │ execution evidence JSON
                     ▼
┌────────────────────────────────────────────────────────┐
│                 MINI-VERIFY (per task)                 │
│  Runs task's test spec + checks acceptance criteria    │
│  Returns: {pass: true/false, failures: [...]}          │
│  If fail → DEBUG → re-verify (max 2 attempts)         │
└────────────────────┬───────────────────────────────────┘
                     │ per-task pass/fail
                     ▼
┌────────────────────────────────────────────────────────┐
│                  VERIFY STEP (blind)                   │
│  Step 1:   Compile + lint check                        │
│  Step 1.5: Execution-based verification (sandbox)      │
│  Step 1.7: Test spec execution (PRIMARY evidence)      │
│  Step 2:   Phase-type-specific checks + behavioral     │
│  Step 2.5: Visual testing (if UI + configured)         │
│  Returns: {criteria_results, execution_results,        │
│            visual_test_results}                         │
└────────────────────┬───────────────────────────────────┘
                     │ verification evidence
                     ▼
┌──────────────────────────────────────────┐   ┌────────────────────────┐
│              JUDGE (independent)          │   │   RATING (isolated)    │
│  Runs own git diff, spot-checks criteria │   │  Runs own commands     │
│  Checks execution evidence independently │   │  Scores per-criterion  │
│  Returns: {recommendation, concerns}     │   │  Uses execution output │
└──────────────────────┬───────────────────┘   │  Returns: score + card │
                       │                       └────────────┬───────────┘
                       ▼                                    ▼
              ┌──────────────────────────────────────────────────┐
              │              PHASE-RUNNER GATE                   │
              │  Combines: verifier pass/fail + judge concerns    │
              │    + rating score against pass_threshold          │
              │  Evidence field: populated with execution proof   │
              │  Returns: structured JSON to orchestrator         │
              └──────────────────────────────────────────────────┘
```

### Visual Testing Data Flow

```
config.json (visual_testing.*)
       │
       ▼
┌──────────────────────────────────────┐
│  ORCHESTRATOR validates config       │
│  Passes visual_testing_enabled: true │
└──────────────┬───────────────────────┘
               │
               ▼
┌──────────────────────────────────────┐
│  VERIFIER Step 2.5:                  │
│  1. Launch app (launch_command)      │
│  2. Wait for ready (curl base_url)   │
│  3. For each route:                  │
│     - Navigate to base_url + path    │
│     - Wait (route.wait_ms)           │
│     - npx playwright screenshot      │
│  4. Read screenshots (multimodal)    │
│  5. Analyze: layout, rendering,      │
│     regression, accessibility        │
│  6. Kill app server                  │
└──────────────┬───────────────────────┘
               │
       ┌───────┴────────┐
       ▼                ▼
  No issues         Issues found
  (record PASS)     ▼
               ┌─────────────────────────┐
               │  Write VISUAL-BUGS.md   │
               │  Record in VERIFICATION │
               │  Include in return JSON │
               └──────────┬──────────────┘
                          │
                          ▼
               ┌─────────────────────────┐
               │  PHASE-RUNNER routes    │
               │  visual bugs to DEBUG   │
               │  alongside functional   │
               │  failures               │
               └──────────┬──────────────┘
                          │
                          ▼
               ┌─────────────────────────┐
               │  DEBUGGER fixes         │
               │  Re-verify (Step 2.5    │
               │  re-runs screenshots)   │
               │  Max 3 debug attempts   │
               └─────────────────────────┘
```

### Key Data Flows Summary

1. **Execution evidence flow:** config.json commands → planner criteria → executor compile gates → verifier sandbox execution → rating agent scoring. Three independent agents run the same commands for triangulation.

2. **Test spec flow:** planner generates test specs → executor updates with implementation details → verifier runs as primary evidence → rating agent uses output for scoring → debugger re-runs to confirm fixes.

3. **Visual testing flow:** config.json visual config → orchestrator validates → verifier launches app + captures + analyzes → visual bugs routed to debug loop → re-captured after fixes.

4. **Evidence chain flow:** Every step produces structured evidence (exit codes, stdout, screenshots, file:line references) → phase-runner routes evidence between steps without reading code → orchestrator reads only the final JSON summary.

## Anti-Patterns

### Anti-Pattern 1: Grep-Only Verification (the Core Problem Being Solved)

**What people do:** Verify acceptance criteria by grepping for patterns in source code instead of running the code.

**Why it's wrong:** `grep 'onClick' Button.tsx` confirms the string exists, not that the button works. The user's calendar bug survived 4 phases because the verifier confirmed the code pattern existed without ever rendering the calendar. Code that pattern-matches correctly can still crash, render incorrectly, or produce wrong output.

**Do this instead:** Execution-based verification is MANDATORY when project commands are configured. Grep remains valid for structural checks (file existence, import presence, config values) but MUST be supplemented with execution for behavioral claims. Test spec execution is the primary evidence source.

### Anti-Pattern 2: Self-Reported Evidence (Executor Tells Verifier "It Works")

**What people do:** Pass the executor's self-assessment or test results to the verifier, who then rubber-stamps them.

**Why it's wrong:** This is the fox guarding the henhouse. The executor has motivation (completing the task) to report success. The verifier's independence is destroyed if it receives the executor's conclusions before forming its own.

**Do this instead:** BLIND VERIFICATION (VRFY-01) is already defined: the verifier receives acceptance criteria and a git diff command, NOT executor evidence. The judge is similarly independent. The rating agent is context-isolated. All three must run their own checks. This is the most important architectural invariant in the system.

### Anti-Pattern 3: Visual Verification as a Gate Blocker

**What people do:** Make visual testing a hard requirement that blocks all UI phases, even when Playwright is not installed or the app fails to launch.

**Why it's wrong:** Visual testing infrastructure is fragile -- apps may not launch cleanly in headless mode, Playwright may not be installed, ports may be in use. Making it a hard gate would cause false failures on infrastructure issues, not code quality issues.

**Do this instead:** Visual testing is an ENHANCEMENT, not a gate. `infrastructure_available: false` is logged, verification continues without visual tests. However, when visual testing IS available, issues with severity `critical` or `major` DO enter the debug loop. The distinction: infrastructure failure = skip gracefully; visual bug = fix.

### Anti-Pattern 4: Unbounded Test Execution

**What people do:** Run the full project test suite on every mini-verification, consuming minutes of execution time per task.

**Why it's wrong:** A project with 500 tests takes 2+ minutes to run. With 5 tasks per phase and mini-verification after each, that is 10+ minutes of test execution per phase -- and the tests may be flaky or unrelated to the current task.

**Do this instead:** Mini-verification runs ONLY the task-specific test spec (`.planning/phases/{N}/tests/task-{id}.sh`), which contains focused assertions for that task's acceptance criteria. The full project test suite (`project.commands.test`) runs once during the VERIFY step (Step 1.5), not per-task. This keeps mini-verification fast (seconds) while full verification remains comprehensive.

## Integration Points

### External Dependencies

| Dependency | Integration Pattern | Notes |
|-----------|---------------------|-------|
| **Playwright** | `npx playwright screenshot` (CLI, no library import) | Must be installed in project. Graceful degradation if missing. Used for visual testing Step 2.5. |
| **Node.js** | Runtime for `npm run *` commands | Already required by Claude Code. Used for compile, build, test, lint commands. |
| **Project test framework** | Invoked via `project.commands.test` from config.json | Framework-agnostic: Jest, Vitest, Mocha, or any test runner. autopilot invokes it as a black box. |
| **Project build tools** | Invoked via `project.commands.compile`, `project.commands.build` | Framework-agnostic: tsc, webpack, vite, esbuild, etc. |
| **Project linter** | Invoked via `project.commands.lint` | ESLint, Biome, or any linter. Invoked as a black box. |
| **GSD step agents** | Spawned via Claude Code Task tool | Unmodified GSD agents. All autopilot context is inlined into spawn prompts. No GSD modifications needed. |

### Internal Boundaries

| Boundary | Communication | Key Constraint |
|----------|---------------|----------------|
| Orchestrator to Phase-runner | Task tool spawn + JSON return parsing | Orchestrator reads ONLY the return JSON. Never reads phase artifacts directly. |
| Phase-runner to Step agents | Task tool spawn + JSON/summary reading | Phase-runner reads at most `max_summary_lines` per agent. Context budget is enforced. |
| Executor to Mini-verifier | Phase-runner spawns mini-verifier after executor returns | Mini-verifier does NOT receive executor's self-test results. Gets only task criteria + files modified. |
| Verifier to Judge | Both spawned independently by phase-runner | Judge does NOT receive verifier's pass/fail conclusion. Forms independent opinion. |
| Verifier to Rating Agent | Both spawned independently by phase-runner | Rating agent receives NOTHING from verifier, judge, or executor. Complete context isolation. |
| Phase-runner to Debugger | Spawned when verification or mini-verification fails | Debugger receives failure details + VISUAL-BUGS.md (if visual issues). Re-verification runs after fix. |

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| Small project (1-5 phases, <20 files) | Default configuration works. Visual testing optional. Test specs are fast. Full test suite runs in seconds. |
| Medium project (5-15 phases, 20-100 files) | Enable visual testing for UI phases. Test spec execution still fast. Full test suite may take 30-60s. Context budget management is critical to avoid exhaustion. |
| Large project (15+ phases, 100+ files) | Scope-split awareness (CTXE-01) becomes essential. Full test suite may exceed 60s timeout -- consider running subset. Repo-map staleness more frequent. Visual testing routes should be prioritized (not all routes every time). |

### First Bottleneck: Context Window Exhaustion

**What breaks:** Phase-runner runs out of context when handling too many tasks, debug iterations, and verification rounds.

**Fix:** Already addressed by context budget table, scope-split awareness, and max debug attempts. The new execution evidence adds ~5-10 lines per verification command -- within budget if commands are bounded.

### Second Bottleneck: Test Execution Time

**What breaks:** Full test suite takes too long (>60s timeout), causing timeout failures in verification.

**Fix:** Mini-verification runs task-specific test specs (fast). Full suite runs once in VERIFY step. If full suite exceeds timeout, the verifier should run it with an extended timeout or run a subset of relevant tests (needs implementation).

## Build Order (Suggested Phase Dependencies)

Based on the architecture analysis, here is the recommended build order for the rebuild milestone. Each capability depends on the ones above it.

### Foundation Layer (must come first)

1. **Strengthen `config.json` project commands** -- All execution depends on `project.commands.compile`, `project.commands.test`, `project.commands.lint`, `project.commands.build` being reliably configured. This is the prerequisite for everything else.

2. **Executor compile/lint gates** -- The executor MUST compile and lint before every commit. This is already defined but needs enforcement strengthening. Without this, broken code enters the codebase and every subsequent step fails.

### Execution Layer (depends on foundation)

3. **Sandbox execution enforcement** -- Strengthen the verifier's Step 1.5 from advisory to mandatory (when commands configured). Add pre-execution command validation and post-execution scope checks. This enables trusted execution results.

4. **Test spec quality enforcement** -- Strengthen the planner's test spec generation (Step 7) and the verifier's test spec execution (Step 1.7). Test specs must actually run, produce structured output, and their results must gate progression.

### Verification Layer (depends on execution)

5. **Evidence-based gate decisions** -- Phase-runner gate decision must require execution evidence (not just grep results) when project commands are configured. The `evidence` field in return JSON must contain execution output.

6. **Rating agent execution integration** -- Rating agent must run verification commands independently and use execution output for scoring. Test spec results are primary scoring evidence.

### Visual Layer (depends on verification, but can partially parallel)

7. **Visual testing pipeline** -- End-to-end: config validation → app launch → screenshot capture → multimodal analysis → VISUAL-BUGS.md generation → debug loop integration. Can be built in parallel with items 5-6 since it's a separate verification dimension.

### Polish Layer (depends on all above)

8. **Honest verification enforcement** -- Cross-cutting: add anti-rubber-stamping checks to judge, ensure verifier `commands_run` list is non-empty, enforce behavioral traces for UI phases, reject evidence-free completions at orchestrator level.

```
Build dependency graph:

[1: config.json commands] ──→ [2: Executor compile gates]
         │                              │
         ▼                              ▼
[3: Sandbox enforcement] ←──── [4: Test spec quality]
         │                              │
         ▼                              ▼
[5: Evidence-based gates] ←─── [6: Rating execution]
         │                              │
         │    [7: Visual testing] ──────┤ (partial parallel)
         ▼                              ▼
         └──────────→ [8: Honest verification enforcement]
```

## Sources

- Existing codebase analysis: `src/protocols/autopilot-orchestrator.md`, `src/protocols/autopilot-playbook.md`, `src/protocols/autopilot-schemas.md`, `src/agents/autopilot-phase-runner.md`, `.planning/PROJECT.md` [HIGH confidence -- primary source]
- [The Complete Guide to Agentic Coding in 2026](https://www.teamday.ai/blog/complete-guide-agentic-coding-2026) [MEDIUM confidence -- industry patterns]
- [5 Code Sandboxes for Your AI Agents](https://www.kdnuggets.com/5-code-sandbox-for-your-ai-agents) [MEDIUM confidence -- sandbox architecture patterns]
- [What's the best code execution sandbox for AI agents in 2026?](https://northflank.com/blog/best-code-execution-sandbox-for-ai-agents) [MEDIUM confidence -- sandbox isolation approaches]
- [I sandboxed my coding agents. You should too.](https://www.innoq.com/en/blog/2025/12/dev-sandbox/) [MEDIUM confidence -- real-world sandbox experience]
- [Playwright Agents Documentation](https://playwright.dev/docs/test-agents) [HIGH confidence -- official docs]
- [How Claude Code Works](https://code.claude.com/docs/en/how-claude-code-works) [HIGH confidence -- official documentation]
- [Claude Code Testing: How to Make AI Verify (and Fix) Its Own Work](https://www.nathanonn.com/claude-code-testing-ralph-loop-verification/) [MEDIUM confidence -- practitioner guide]
- [Claude Code: Behind-the-scenes of the master agent loop](https://blog.promptlayer.com/claude-code-behind-the-scenes-of-the-master-agent-loop/) [MEDIUM confidence -- architecture analysis]
- [Building AI Agents to Automate Software Test Case Creation (NVIDIA)](https://developer.nvidia.com/blog/building-ai-agents-to-automate-software-test-case-creation/) [MEDIUM confidence -- enterprise pattern]
- [2026 Agentic Coding Trends Report (Anthropic)](https://resources.anthropic.com/hubfs/2026%20Agentic%20Coding%20Trends%20Report.pdf?hsLang=en) [HIGH confidence -- Anthropic official]

---
*Architecture research for: autonomous coding agent code execution, testing, and visual verification*
*Researched: 2026-02-17*
