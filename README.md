# autopilot-cc

Autonomous multi-phase execution for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Point it at a roadmap and walk away -- it runs 1-N development phases without human intervention, verifies its own work, and learns from failures along the way.

**Requires:** [get-shit-done-cc](https://www.npmjs.com/package/get-shit-done-cc) >= 1.15.0

## Install

```bash
npx autopilot-cc@latest
```

This installs the `/autopilot` command, phase-runner agent, protocol files, and a background update hook into `~/.claude/` (global) by default.

```bash
npx autopilot-cc@latest --local      # Install to ./.claude/ (project-local)
npx autopilot-cc@latest --uninstall  # Remove all autopilot files
npx autopilot-cc@latest --check-deps # Check GSD dependency without installing
```

## Usage

In any project with a `.planning/ROADMAP.md`:

```bash
/autopilot 1-14        # Run phases 1 through 14
/autopilot 3-7         # Run a subset
/autopilot 5           # Run a single phase
/autopilot --complete  # Run all outstanding phases automatically
/autopilot resume      # Resume from last checkpoint
/autopilot status      # Show current state
/autopilot update      # Check for and install updates
```

### Flags

| Flag | Description |
|------|-------------|
| `--complete` | Run all outstanding phases in dependency order; skips completed ones; continues past independent failures |
| `--map [phases]` | Audit context sufficiency before execution; asks clarifying questions for underspecified phases |
| `--lenient` | Relaxed 7/10 alignment threshold instead of the default 9/10 |
| `--sequential` | Force all phases to run sequentially |
| `--checkpoint-every N` | Pause for human review every N phases |

Flags are combinable: `--complete --map --lenient` maps context first, then runs all remaining phases with relaxed thresholds.

## What It Does

### Executes

Each phase runs through a full pipeline automatically:

```
Pre-flight → Research → Plan → Plan-Check → Execute → Verify → Judge → Gate
```

- **Pre-execution triage** skips phases that are already implemented, routing straight to verification
- **Plan quality gates** reject vague acceptance criteria -- every task needs concrete verification commands and complexity estimates
- **Compile gates** block further writes the moment a file fails to compile
- **Structured commits** are created per-task with ID references, not one big blob at the end
- **New file integration checks** verify that created files are actually imported and wired in

### Verifies

Verification is adversarial by design:

- The **verifier** never sees what the executor claims it did -- it checks the codebase blind
- The **judge** gathers its own evidence independently before seeing the verifier's report, then scores alignment
- Both verifier and judge have **rubber-stamp detection** -- if either just agrees without doing real work, they get flagged
- Default alignment threshold is **9/10**. Sub-threshold phases enter up to 2 remediation cycles (re-verify + re-judge) before failing. Use `--lenient` to accept 7/10.
- Every sub-9 completion produces a **diagnostic file** with a concrete "path to 9/10" section

### Learns

Failures feed forward into subsequent phases:

- **Auto post-mortems** on failure include root cause, timeline, evidence chain, and prevention rules
- Prevention rules are injected into the planner and executor for later phases in the same run
- **Structured JSONL traces** capture every tool invocation for debugging
- **Run-level metrics** track success rate, failure taxonomy, alignment scores, and cost estimates

### Scales

Run the whole project hands-free:

- `--complete` figures out what's left, resolves dependency order, and runs everything -- writing an aggregated completion report at the end
- `--map` audits whether each phase has enough context to succeed before burning tokens on execution; asks you targeted questions and saves answers for next time
- **Post-completion self-audit** checks the finished implementation against the original spec, finds gaps with file:line evidence, and fixes them automatically
- **Circuit breaker** with 10 tunable thresholds prevents infinite loops and runaway costs
- **Crash recovery** via idempotent state file -- `resume` picks up exactly where it left off

## Architecture

```
Tier 1: Orchestrator (/autopilot command)
  Reads roadmap, spawns phase-runners, applies gate logic
  Stays under 40% context -- only reads structured JSON returns

Tier 2: Phase Runner (autopilot-phase-runner agent)
  Runs the full pipeline for one phase
  Spawns step agents: researcher, planner, executor, verifier, judge

Tier 3: Step Agents (vanilla GSD agents)
  No modifications needed -- autopilot context injected via spawn prompts
```

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
