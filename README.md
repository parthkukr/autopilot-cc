# autopilot-cc

Autonomous multi-phase execution for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Point it at a roadmap and walk away -- it runs your development phases without human intervention, verifies its own work, and learns from failures along the way.

**Requires:** [get-shit-done-cc](https://www.npmjs.com/package/get-shit-done-cc) >= 1.15.0

---

## Installation

```bash
npx autopilot-cc@latest
```

This installs the `/autopilot` command and supporting files into `~/.claude/` (global) by default.

```bash
npx autopilot-cc@latest --local      # Install to ./.claude/ (project-local)
npx autopilot-cc@latest --uninstall  # Remove all autopilot files
npx autopilot-cc@latest --check-deps # Check dependency without installing
```

After installing, **restart Claude Code** so it discovers the new command.

---

## Quick Start

### 1. Set up your project

Create a `.planning/` directory in your project root with two files:

**`.planning/ROADMAP.md`** -- describes the work you want done, broken into phases:

```markdown
# Roadmap

## Phases

- [ ] **Phase 1: User Authentication** - Add login/signup with JWT tokens
- [ ] **Phase 2: Dashboard** - Build the main dashboard with charts and stats
- [ ] **Phase 3: API Integration** - Connect to the payment provider API

## Phase Details

### Phase 1: User Authentication
**Goal**: Users can sign up, log in, and stay authenticated across sessions
**Success Criteria**:
  1. Signup endpoint creates a user and returns a JWT
  2. Login endpoint validates credentials and returns a JWT
  3. Protected routes reject unauthenticated requests with 401
```

**`.planning/REQUIREMENTS.md`** -- the spec or requirements document for your project. Can be as detailed or as brief as you like. autopilot uses this as the frozen reference for verification.

### 2. Run autopilot

Open Claude Code in your project and run:

```
/autopilot 1-3
```

That's it. autopilot reads your roadmap, researches your codebase, plans the work, executes it, and verifies the results -- all autonomously.

### 3. Monitor progress

```
/autopilot:progress
```

Shows completion percentage, scores, and recommended next actions.

---

## Commands

| Command | Description |
|---------|-------------|
| `/autopilot <phases>` | Run one or more development phases (e.g., `1-3`, `5`, `--complete`) |
| `/autopilot:help` | Show the complete command and flag reference |
| `/autopilot:progress [--verbose]` | Show current status, completion percentage, and next steps |
| `/autopilot:update` | Check for and install updates from npm |
| `/autopilot:debug [issue]` | Investigate bugs using systematic debugging with persistent state |
| `/autopilot:add-phase <description>` | Add a new phase to the roadmap with auto-numbering |
| `/autopilot:map [scope]` | Analyze the codebase and produce a structured analysis document |

### Main command arguments

```
/autopilot 1-7            Run phases 1 through 7
/autopilot 5              Run a single phase
/autopilot --complete     Run all outstanding phases automatically
/autopilot resume         Resume from last checkpoint
/autopilot status         Show current state without executing
```

---

## Flags

All flags apply to the main `/autopilot` command.

| Flag | Description |
|------|-------------|
| `--complete` | Run all outstanding phases in dependency order. Skips completed ones automatically. |
| `--lenient` | Use relaxed 7/10 alignment threshold instead of the default 9/10. |
| `--force [phase]` | Re-execute a completed phase from scratch, regardless of current score. |
| `--quality [phase]` | Execute with elevated 9.5/10 threshold. Enters remediation loops (max 3 cycles) if needed. |
| `--gaps [phase]` | Analyze and resolve specific deficiencies preventing a phase from reaching its target score. |
| `--discuss [phases]` | Run an interactive Q&A session per phase before execution. Identifies ambiguities for you to weigh in on. |
| `--visual [phases]` | Enable visual testing (screenshot comparison) during verification for UI phases. |
| `--map [phases]` | Audit context sufficiency before execution. Asks you targeted questions for underspecified phases. |
| `--sequential` | Force all phases to run sequentially (no parallelization). |
| `--checkpoint-every N` | Pause for human review every N phases. |

**Combining flags:** Flags compose naturally. `--complete --map --lenient` maps context first, then runs all remaining phases with a relaxed threshold. `--discuss` always runs first when combined with other flags. `--gaps` can combine with `--quality`. `--force` and `--quality` are mutually exclusive.

---

## How It Works

autopilot runs each unit of work through a pipeline that researches your codebase, plans the changes, executes them, and then independently verifies the results.

- **Triage** skips work that's already done, routing straight to verification
- **Quality gates** reject vague plans -- every task needs concrete verification criteria and complexity estimates
- **Compile gates** block further changes the moment code fails to compile, preventing broken code from compounding
- **Independent verification** -- the verifier checks the codebase blind without seeing what the executor claims it did
- **Independent scoring** -- a separate scorer evaluates alignment using only the acceptance criteria and the actual code changes, never the executor's self-reported confidence
- **Automatic debugging** -- when something breaks, autopilot runs a structured debug cycle and retries before giving up
- **Cross-phase learning** -- failures produce post-mortems with prevention rules that carry forward to subsequent work
- **Crash recovery** -- state is checkpointed continuously, so `resume` picks up exactly where it left off

---

## Configuration

autopilot looks for optional configuration at `.planning/config.json`. If the file does not exist, sensible defaults are used.

```jsonc
{
  "project": {
    "spec_paths": [".planning/REQUIREMENTS.md"],  // Spec files to check (in order)
    "commands": {
      "compile": "npm run build",      // Compile/build command for quality gates
      "lint": "npm run lint",          // Lint command
      "test": "npm test"              // Test command
    },
    "visual_testing": {               // For UI projects using --visual
      "enabled": true,
      "launch_command": "npm run dev",
      "base_url": "http://localhost:3000",
      "routes": [
        { "path": "/", "name": "home" },
        { "path": "/dashboard", "name": "dashboard" }
      ]
    }
  },
  "workflow": {
    "research": true                  // Set to false to skip the research step
  }
}
```

**Key options:**
- **`project.commands`** -- Tell autopilot how to compile, lint, and test your project. These are used for quality gates during execution and verification.
- **`project.visual_testing`** -- Configure screenshot-based visual testing for UI projects. Requires `launch_command`, `base_url`, and at least one route.
- **`workflow.research`** -- Disable the research step if your roadmap already has sufficient detail.

---

## Intended Usage

autopilot works best when you treat it as a capable junior developer who needs clear direction but handles the tedious work autonomously.

**Write a good roadmap.** The single biggest factor in autopilot's success is the quality of your roadmap. Each phase should have a clear goal, concrete success criteria, and enough context for someone unfamiliar with the codebase to understand what "done" looks like. You don't need to specify implementation details -- autopilot will research the codebase and figure those out -- but the *what* and *why* should be unambiguous.

**Start with `--discuss`.** For complex or ambiguous phases, run `--discuss` first. autopilot will identify gray areas in your spec and ask you targeted questions. Your answers get saved and used during execution, which dramatically improves first-pass success rates.

**Use `--map` before big runs.** Before kicking off a long run with `--complete`, use `--map` to audit whether each phase has enough context. autopilot will flag underspecified phases and ask clarifying questions. This prevents wasted tokens on phases that are likely to fail due to ambiguity.

**Let it iterate.** autopilot's default 9/10 alignment threshold means most phases pass on the first attempt. When they don't, it enters remediation automatically. You can push harder with `--quality` (9.5/10 threshold) or use `--gaps` to fix specific remaining deficiencies.

**Review the output.** autopilot verifies its own work, but you should still review the final result. Check `/autopilot:progress --verbose` for per-phase scores and look at the git log for what changed. The tool is designed to get you 90%+ of the way there, not to replace your judgment entirely.

---

## Troubleshooting

**"agent not found" error after installing**
Restart Claude Code. Agent types are discovered at session startup, so if you installed autopilot mid-session, it won't be available until you restart.

**"get-shit-done-cc >= 1.15.0 is required"**
Install the dependency first: `npx get-shit-done-cc@latest`, then re-run `npx autopilot-cc@latest`.

**Phase keeps failing verification**
Try `--discuss` to clarify ambiguities, or `--lenient` to accept a lower alignment threshold. Check `.planning/phases/` for diagnostic files that explain what specifically fell short.

**"Context exhausted" or session becomes unresponsive**
autopilot hit its context window limit. Run `/clear` to reset the session, then `/autopilot resume` to pick up from the last checkpoint. For large projects, use `--checkpoint-every 3` to pause periodically.

**Commands not recognized after install**
Make sure you restarted Claude Code after installing. Commands are available immediately, but the background agent requires a restart to be discovered.

**Old subcommand syntax not working**
All subcommands now use colon syntax: `/autopilot:help`, `/autopilot:debug`, `/autopilot:update`, etc. The space-separated syntax (e.g., `/autopilot help`) is no longer supported.

---

## Future Ideas

These are capabilities under consideration for future development. Nothing here is guaranteed -- they represent directions the project may explore.

- **Context-aware session guidance** -- When autopilot needs to stop due to context limits, provide specific instructions for resuming (e.g., which phases remain, exact command to run next)
- **Parallel phase execution** -- Run independent phases simultaneously to reduce total wall-clock time on large projects
- **Custom verification plugins** -- Let users define project-specific verification steps beyond compile/lint/test
- **Cost estimation before execution** -- Show estimated token usage for a run before committing to it
- **Phase templates** -- Pre-built phase definitions for common tasks (auth, CRUD, testing setup, CI/CD)
- **Multi-model routing** -- Automatically select the best model (faster or more capable) based on task complexity

---

## Updating

```
/autopilot:update
```

Or reinstall directly:

```bash
npx autopilot-cc@latest
```

## Uninstalling

```bash
npx autopilot-cc@latest --uninstall
```

## License

MIT
