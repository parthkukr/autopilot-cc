---
name: autopilot
description: Autonomous multi-phase execution — runs development phases without human intervention
argument-hint: <phases|resume|status|update|--complete|--map|--lenient|--force|--quality|--gaps|--discuss>
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Task
  - Glob
  - Grep
---

<objective>
Run 1-N development phases autonomously using the 3-tier orchestrator pattern. You (the orchestrator) spawn phase-runner subagents and NEVER do heavy work yourself. You are a manager, not a worker — delegate all detailed analysis to sub-agents.
**Quality bar:** Phases are verified with evidence. Compilation, lint, and build checks are mandatory. Scores of 9/10 on every phase are a red flag, not a success signal.

**Arguments:**
- Phase range: `1-14`, `3-7`, `5` — runs those phases
- `resume` — resume from last checkpoint in `.autopilot/state.json`
- `status` — show current state without executing
- `update` — check for and install autopilot-cc updates

**Options (append after phases or standalone):**
- `--complete` — run all outstanding (incomplete) phases in dependency order without specifying a phase range; the orchestrator determines what's left, skips what's done, resolves dependency ordering, and runs to project completion with aggregated reporting
- `--map [phases]` — audit context sufficiency for target phases (or all outstanding if no range given) before execution; spawns questioning agent for underspecified phases; answers recorded to `.autopilot/context-map.json`
- `--lenient` — use relaxed 7/10 alignment threshold instead of the default 9/10; phases scoring 7-8 pass immediately without remediation cycles
- `--force [phase]` — re-execute a completed phase from scratch through the full pipeline (research, plan, execute, verify, judge, rate), regardless of its current score; existing commits are preserved, new work layers on top; targets specific phase (`--force 3`) or all completed phases (`--force`); cannot combine with `--quality`, `--gaps`, or `--complete` (force targets completed phases, complete targets incomplete phases)
- `--quality [phase]` — keep working on a completed phase with remediation loops until it achieves 9.5/10 alignment; each loop extracts deficiencies, executes targeted fixes, re-verifies and re-rates; max 3 remediation cycles; targets specific phase or all completed phases below 9.5; cannot combine with `--force`
- `--gaps [phase]` — analyze and resolve the specific deficiencies preventing a completed phase from reaching 10/10; produces ordered list of remaining issues, then executes micro-targeted fixes one deficiency at a time, working toward 9.5+/10; max 5 gap-fix iterations; can combine with `--quality` (quality runs first to 9.5, then gaps pushes higher)
- `--discuss [phases]` — run an interactive discussion session per phase before execution begins; the orchestrator asks targeted, phase-specific questions about expected results, edge cases, and preferences; answers are recorded and injected into the phase-runner's context; combines with any other flag (always runs first)
- `--sequential` — force all phases sequential
- `--checkpoint-every N` — pause for human review every N phases
</objective>

<reference>
**CRITICAL:** This command operates using the 3-tier architecture. Do NOT improvise.

**Architecture:**
```
Tier 1: You (Primary Orchestrator) — reads __INSTALL_BASE__/autopilot/protocols/autopilot-orchestrator.md
Tier 2: Phase Runner subagents (agent type: autopilot-phase-runner) — reads __INSTALL_BASE__/autopilot/protocols/autopilot-playbook.md
Tier 3: Step Agents — spawned by phase-runners (researcher, planner, executor, etc.)
```

**Protocol files:**
1. `__INSTALL_BASE__/autopilot/protocols/autopilot-orchestrator.md` — **START HERE.** Your step-by-step instructions as the orchestrator.
2. `__INSTALL_BASE__/autopilot/protocols/autopilot-playbook.md` — Phase-runner instructions (phase-runners read this, NOT you).

**Pipeline per phase (executed by phase-runner, not you):**
```
[0] Pre-flight → [1] Research → [2] Plan → [2.5] Plan-Check →
[3] Execute → [4] Verify → [4.5] Judge → [5] Gate Decision →
[5a] Debug (if needed) → [6] Checkpoint → Return JSON to you
```

**Context preservation rules (quick reminders):**
- NEVER read full RESEARCH.md, PLAN.md, or code files
- ONLY read structured JSON returns from phase-runner subagents
- State file is your only large direct read
- Context tracking is observability-only — warn at 70%/90% but NEVER auto-stop
</reference>

<execution>

## On Invocation

1. **Parse argument** — determine target phases, or if `resume`/`status`/`update`
2. **Agent availability check** — Before doing anything else, verify the `autopilot-phase-runner` agent type is available by checking the Task tool's available agent types. If `autopilot-phase-runner` is NOT in the list:
   - **HALT immediately.** Do NOT fall back to `general-purpose`. Do NOT attempt to run phases.
   - Output this exact message:
   ```
   ✗ autopilot-phase-runner agent type not found.

   Claude Code discovers agent types at session startup. This means you
   installed or updated autopilot-cc after this session started.

   Fix: Exit Claude Code and start a new session, then re-run /autopilot.
   ```
   - Stop execution. Do not proceed to step 3.
3. **Read the orchestrator guide** — `__INSTALL_BASE__/autopilot/protocols/autopilot-orchestrator.md`
4. **Follow it exactly** — the guide has step-by-step instructions for every scenario

### If `status`:
- Read `.autopilot/state.json`
- Display progress table (phase, status, score, duration)
- Do NOT execute anything

### If `update`:
1. Read installed version from `__INSTALL_BASE__/autopilot/VERSION`
2. Check npm: run `npm view autopilot-cc version`
3. If same version, say "Already up to date (vX.Y.Z)" and stop
4. If update available: show "Update available: vX.Y.Z -> vA.B.C. Installing..."
5. Run `npx autopilot-cc@latest` (preserving --global/--local based on current install location)
6. Show "Restart Claude Code to activate the update"

### If `--complete`:
- Follow orchestrator guide Section 1.1 (Batch Completion Mode)
- Reads roadmap, identifies all incomplete phases, resolves dependency order
- Skips already-completed phases with logged reasons
- On failure: skips blocked dependent phases, continues with remaining independent phases
- At end: writes aggregated completion report to `.autopilot/completion-report.md`
- Combinable with `--sequential`, `--checkpoint-every N`, `--lenient`, `--map`

### If `--lenient`:
- Sets the alignment pass threshold to 7/10 instead of the default 9/10
- Phases scoring 7-8 pass immediately without entering remediation cycles
- Sub-9 phases still produce diagnostic files at `.autopilot/diagnostics/phase-{N}-confidence.md`
- Combinable with all other flags: `--complete --lenient`, `--map --lenient`, etc.
- Follow orchestrator guide Section 1.3 (Lenient Mode)

### If `--force`:
- Follow orchestrator guide Section 1.4 (Force Mode)
- Re-executes completed phases through the full pipeline from scratch (research, plan, execute, verify, judge, rate)
- Existing commits preserved, new work layers on top
- Targets specific phase (`--force 3`) or all completed phases (`--force`)
- Cannot combine with `--quality` or `--gaps` (mutually exclusive -- force redoes from scratch, quality/gaps refine what exists)
- Can combine with `--discuss` (discussion runs first) and `--lenient`

### If `--quality`:
- Follow orchestrator guide Section 1.5 (Quality Mode)
- Enters remediation loops targeting 9.5/10 alignment score
- Each loop: extract deficiencies from rating scorecard, re-spawn phase-runner with targeted fixes, re-verify, re-rate
- Max 3 remediation cycles per phase
- When exhausted without reaching 9.5: reports current score + remaining gaps (does NOT fail the phase)
- Cannot combine with `--force`; can combine with `--gaps` (quality first to 9.5, then gaps pushes higher)

### If `--gaps`:
- Follow orchestrator guide Section 1.6 (Gaps Mode)
- Analyzes delta between current score and 10/10, produces ordered deficiency list
- Executes micro-targeted fixes: one deficiency per iteration, verified independently, scored incrementally
- Max 5 gap-fix iterations per phase
- When exhausted: reports current score + remaining deficiencies (does NOT fail the phase)
- Cannot combine with `--force`; can combine with `--quality`

### If `--discuss`:
- Follow orchestrator guide Section 1.7 (Discuss Mode)
- Spawns discussion agent per target phase that generates 3-5 phase-specific questions
- Questions cover: expected behavior, edge cases, implementation preferences, scope boundaries
- User answers are recorded to `.autopilot/discuss-context.json` and injected into phase-runner context
- Combines with any other flag -- always runs first before execution/quality/gaps/force
- Questions are specific to each phase's content (not generic)

### If `--map`:
- Follow orchestrator guide Section 1.2 (Context Mapping Mode)
- Reads roadmap and requirements for each target phase (or all outstanding if no range given)
- Computes context sufficiency score (1-10) per phase based on: success criteria specificity, requirement detail, project documentation coverage, dependency status
- For phases scoring below 8: spawns a questioning agent that generates 2-5 specific questions targeting missing information
- Batches all questions across all underspecified phases and presents them to the user in one interactive session
- Records answers to `.autopilot/context-map.json` (persists across runs)
- Combinable with `--complete` (map runs first, then execution), `--lenient`

### If `resume`:
- Follow orchestrator guide Section 8 (Resume Protocol)
- Read state file, find resume point, verify spec hash, continue

### If phase range (e.g., `3-7`):
- Follow orchestrator guide Section 1 (Invocation) for setup
- Create `.autopilot/` if first run
- Show a 3-line status (phase count, spec hash, model) and immediately begin. Do NOT ask for confirmation.
- If a phase has no existing plan, pass `existing_plan: false` to the phase-runner and let IT handle research+planning. Do NOT refuse to run planless phases.

## Core Loop

There is NO session cap — ALL phases can run in one session. The orchestrator stays lean because it only reads structured JSON returns from phase-runner subagents, never full research/plan/code files.

For each phase, spawn a phase-runner subagent per orchestrator guide Section 3. Read its JSON return. Apply gate logic per Section 5:
- **PASS:** `recommendation=="proceed"` AND `alignment >= pass_threshold` (default 9/10, 7/10 with `--lenient`, 9.5/10 with `--quality`) — checkpoint, next phase
- **REMEDIATE:** `recommendation=="proceed"` AND `alignment >= 7` but `< pass_threshold` — enter remediation cycle (Section 5.1)
- **FAIL:** anything else — HALT with diagnostic

Do NOT retry failed phases. The phase-runner handles all internal retries (debug loops, replans). If it returns `failed`, the run stops.

## On Failure

Per orchestrator guide Section 5:
- Write diagnostic to `.autopilot/diagnostics/`
- Show user summary
- Preserve state for resume

## On Completion

Per orchestrator guide Section 9:
- Run final integration check
- Generate completion report
- Archive state file
- Announce completion

</execution>
