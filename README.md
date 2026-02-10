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
/autopilot resume      # Resume from last checkpoint
/autopilot status      # Show current state
/autopilot update      # Check for and install updates
```

### Options

```
--sequential           Force all phases sequential
--checkpoint-every N   Pause for human review every N phases
```

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

## How It Works

1. Orchestrator reads roadmap, locks spec hash, enters phase loop
2. For each phase: spawns a phase-runner subagent
3. Phase-runner executes pipeline: preflight -> research -> plan -> plan-check -> execute -> verify -> judge -> gate
4. Phase-runner returns structured JSON result
5. Orchestrator applies gate logic (pass/fail/skip) and advances

Key design decisions:
- **No modified GSD agents** -- autopilot context is inlined into spawn prompts
- **Adversarial verification** -- judge gathers evidence before seeing verifier report
- **Circuit breaker** -- prevents infinite loops and runaway costs
- **Crash recovery** -- idempotent state file enables resume from any point

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
