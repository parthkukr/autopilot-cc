---
name: autopilot
description: Autonomous multi-phase execution — runs development phases without human intervention
argument-hint: <phases|resume|status|update|--complete|--map|--lenient>
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
Run 1-N development phases autonomously using the 3-tier orchestrator pattern. You (the orchestrator) spawn phase-runner subagents and NEVER do heavy work yourself. Your context stays under 40%.
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
- If context > 40%: write handoff file, suggest `/autopilot resume`
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
- **PASS:** `recommendation=="proceed"` AND `alignment >= pass_threshold` (default 9/10, 7/10 with `--lenient`) — checkpoint, next phase
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
