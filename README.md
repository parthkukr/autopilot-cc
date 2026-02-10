# autopilot-cc

Autonomous multi-phase execution for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Runs 1-N development phases without human intervention using a 3-tier orchestrator pattern.

**Requires:** [get-shit-done-cc](https://www.npmjs.com/package/get-shit-done-cc) >= 1.15.0

## Install

```bash
npx autopilot-cc@latest
```

This installs the `/autopilot` command, phase-runner agent, protocol files, and a background update hook into `~/.claude/` (global) by default.

### Options

```bash
npx autopilot-cc@latest --local     # Install to ./.claude/ (project-local)
npx autopilot-cc@latest --uninstall # Remove all autopilot files
npx autopilot-cc@latest --check-deps # Check GSD dependency without installing
```

## Usage

In any project with a `.planning/ROADMAP.md`:

```bash
/autopilot 1-14        # Run phases 1-14
/autopilot 3-7         # Run phases 3-7
/autopilot 5           # Run single phase
/autopilot --complete  # Run all outstanding phases automatically
/autopilot resume      # Resume from last checkpoint
/autopilot status      # Show current state
/autopilot update      # Check for and install updates
```

### Flags

| Flag | Description |
|------|-------------|
| `--complete` | Run all outstanding phases in dependency order, skip completed ones, continue past independent failures |
| `--map [phases]` | Audit context sufficiency before execution; asks clarifying questions for underspecified phases |
| `--lenient` | Use relaxed 7/10 alignment threshold instead of the default 9/10 |
| `--sequential` | Force all phases to run sequentially |
| `--checkpoint-every N` | Pause for human review every N phases |

Flags are combinable: `--complete --map --lenient` maps context, then runs all remaining phases with relaxed thresholds.

## Features

### Pipeline Quality (Phases 1-4)

- **Structured prompts** -- MUST/SHOULD/MAY delimiter system across all agent types with enforced context budgets and JSON handoff protocol
- **Executor compile gates** -- per-file compilation checks block further writes on failure; per-task self-testing against acceptance criteria; structured commits with task ID references
- **Plan quality gates** -- plan-checker rejects acceptance criteria lacking concrete verification commands; prose-only criteria are blocked; complexity estimation required per task
- **Integration checks** -- executor auto-verifies new files are imported/wired into the codebase; verifier independently checks for orphaned files
- **Pre-execution triage** -- fast codebase scan detects already-implemented phases and routes to verify-only path, saving full pipeline cost
- **Blind verification** -- verifier never sees executor claims; judge produces independent divergence analysis; rubber-stamp detection on both verifier and judge
- **Status decision governance** -- evidence validation on all status decisions; structured human-defer justification with unnecessary deferral warnings; human-defer rate tracking

### Observability (Phases 5-7)

- **Execution tracing** -- structured JSONL tracing with per-tool-invocation spans, phase-level trace aggregation into `TRACE.jsonl`
- **Auto post-mortems** -- generated on failure with root cause, timeline, evidence chain, and prevention rules
- **Cross-phase learning** -- prevention rules from failures prime planner and executor in subsequent phases; learnings scoped to current run
- **Metrics and cost tracking** -- run-level `metrics.json` with success rate, failure taxonomy histogram, alignment scores; pre-execution cost estimation with budget warnings; cross-run trend comparison

### Automation (Phases 8-13)

- **Batch completion** (`--complete`) -- runs all outstanding phases in dependency order, skips completed phases, continues past independent failures, writes aggregated completion report
- **Context mapping** (`--map`) -- scores phase context sufficiency (1-10), spawns questioning agent for underspecified phases, batches questions in a single interactive session, persists answers across runs
- **Confidence enforcement** -- default 9/10 alignment threshold with remediation loops (up to 2 extra verify+judge cycles) for sub-threshold phases; `--lenient` reverts to 7/10; diagnostic files for every sub-9 completion
- **Post-completion self-audit** -- orchestrator audits implementation against frozen spec after phases complete, produces gap reports with file:line evidence, routes fixes by complexity, re-verifies in bounded loop
- **Silent auto-update** -- `/autopilot update` installs updates immediately without confirmation prompt

## Architecture

```
Tier 1: Primary Orchestrator (you / the /autopilot command)
  reads: protocols/autopilot-orchestrator.md
  spawns: phase-runner subagents

Tier 2: Phase Runner (autopilot-phase-runner agent)
  reads: protocols/autopilot-playbook.md
  spawns: step agents (researcher, planner, executor, verifier, judge)

Tier 3: Step Agents (vanilla GSD agents)
  researcher, planner, executor, verifier, debugger
  No modifications needed -- autopilot context injected via spawn prompts
```

### Pipeline per Phase

```
[0] Pre-flight → [1] Research → [2] Plan → [2.5] Plan-Check →
[3] Execute → [4] Verify → [4.5] Judge → [5] Gate Decision →
[5a] Debug (if needed) → [6] Checkpoint → Return JSON
```

### Key Design Decisions

- **No modified GSD agents** -- autopilot context is inlined into spawn prompts
- **Adversarial verification** -- judge gathers evidence before seeing verifier report
- **Circuit breaker** -- 10 tunable thresholds prevent infinite loops and runaway costs
- **Crash recovery** -- idempotent state file enables `resume` from any point
- **10-category failure taxonomy** -- structured classification for every failure
- **Context budget** -- orchestrator stays under 40% context; only reads structured JSON returns

## Update

```bash
/autopilot update
```

Or reinstall:

```bash
npx autopilot-cc@latest
```

## Uninstall

```bash
npx autopilot-cc@latest --uninstall
```

## License

MIT
