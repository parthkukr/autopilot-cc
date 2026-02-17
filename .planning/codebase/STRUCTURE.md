# Codebase Structure

**Analysis Date:** 2026-02-17

## Directory Layout

```
autopilot-cc/
├── bin/                          # Installation and CLI entry points
│   └── install.js                # NPM installer script (Node.js)
├── src/                          # Source code (distributed to ~/.claude/ on install)
│   ├── commands/                 # User-facing CLI commands
│   │   ├── autopilot.md          # Primary /autopilot orchestrator command
│   │   └── autopilot/            # Subcommands (accessible as /autopilot:subcommand)
│   │       ├── help.md
│   │       ├── progress.md
│   │       ├── debug.md
│   │       ├── map.md
│   │       ├── add-phase.md
│   │       ├── insert-phase.md
│   │       ├── remove-phase.md
│   │       └── update.md
│   ├── agents/                   # Claude Code agent definitions (YAML frontmatter)
│   │   ├── autopilot-phase-runner.md    # Tier 2: Executes full pipeline per phase
│   │   └── autopilot-debugger.md        # Tier 3 debug specialist
│   ├── hooks/                    # Background processes
│   │   └── autopilot-check-update.js    # SessionStart hook (checks npm for updates)
│   ├── protocols/                # Shared documentation (not executable, read by agents/commands)
│   │   ├── autopilot-orchestrator.md    # Tier 1 orchestrator step-by-step guide
│   │   ├── autopilot-playbook.md        # Tier 2 phase-runner pipeline steps
│   │   ├── autopilot-schemas.md         # Data format specifications (JSON, event schema)
│   │   └── update-check-banner.md       # Update notification format
├── .planning/                    # Planning artifacts (auto-created by orchestrator)
│   └── codebase/                 # Codebase analysis documents (this directory)
├── .autopilot/                   # Runtime state (auto-created by orchestrator)
│   ├── state.json                # Orchestrator state: completed phases, scores, timestamps
│   ├── context-map.json          # User answers from --map and --discuss modes
│   ├── learnings.md              # Cross-phase learning rules (reset per run)
│   ├── diagnostics/              # Phase diagnostic files (per-phase confidence, debug traces)
│   ├── cache/                    # Cached data (update check results)
│   └── archive/                  # Archived prior run state
├── bin/                          # CLI/NPM entry point
├── package.json                  # Node.js package metadata
├── VERSION                       # Version string (semantic versioning)
├── CHANGELOG.md                  # Release notes
├── README.md                     # User documentation
└── CLAUDE.md                     # Project-specific instructions
```

## Directory Purposes

**`bin/`:**
- Purpose: Installation entry point
- Contains: Node.js executable scripts
- Key files: `install.js` - handles `npx autopilot-cc` installation, file copying, hook registration

**`src/commands/`:**
- Purpose: User-facing CLI command definitions
- Contains: YAML frontmatter markdown files defining commands
- Key files:
  - `autopilot.md`: Orchestrator command (primary entry point for all phase execution)
  - Each subcommand is a separate .md file that inherits tools/behavior from parent

**`src/agents/`:**
- Purpose: Claude Code agent type definitions
- Contains: YAML frontmatter markdown with agent role, pipeline instructions, tools
- Key files:
  - `autopilot-phase-runner.md`: Tier 2 agent (spawned by orchestrator for each phase)
  - `autopilot-debugger.md`: Debugging specialist (spawned by phase-runner for failures)

**`src/hooks/`:**
- Purpose: Background processes triggered by Claude Code lifecycle events
- Contains: Node.js scripts
- Key files: `autopilot-check-update.js` - registered as SessionStart hook

**`src/protocols/`:**
- Purpose: Shared documentation for agents and commands (NOT code, NOT executable)
- Contains: Markdown reference documents read by agents and commands
- Key files:
  - `autopilot-orchestrator.md`: Complete Tier 1 orchestrator guide (step-by-step logic)
  - `autopilot-playbook.md`: Tier 2 phase-runner pipeline template
  - `autopilot-schemas.md`: JSON schema definitions for all data structures
  - `update-check-banner.md`: User-facing update notification format

**`.planning/`:**
- Purpose: Project planning artifacts (created by GSD, read by autopilot)
- Contains: ROADMAP.md, REQUIREMENTS.md, phase directories
- **Not in this repo** but referenced: created by user via `/gsd:new-project`

**`.autopilot/`:**
- Purpose: Runtime execution state (created by orchestrator)
- Contains: JSON state files, diagnostic output, cached data
- Auto-managed: Do NOT commit to git (should be in .gitignore)
- Key files:
  - `state.json`: Orchestrator checkpoint (phase status, scores, timestamps)
  - `context-map.json`: User answers from context mapping
  - `learnings.md`: Learning rules (prevents cross-run pollution)

## Key File Locations

**Entry Points:**
- `src/commands/autopilot.md`: Main orchestrator command - user runs `/autopilot <phases>`
- `bin/install.js`: Installation script - user runs `npx autopilot-cc@latest`

**Configuration:**
- `package.json`: NPM metadata, version, dependency requirements
- `VERSION`: Single-line version string
- `CHANGELOG.md`: User-facing release notes (public artifact)
- `.gitignore`: Git ignore rules

**Core Logic:**
- `src/agents/autopilot-phase-runner.md`: Full phase pipeline orchestration
- `src/agents/autopilot-debugger.md`: Systematic debugging methodology
- `src/protocols/autopilot-orchestrator.md`: Tier 1 orchestrator algorithm
- `src/protocols/autopilot-playbook.md`: Tier 2 phase-runner step templates

**Subcommands:**
- `src/commands/autopilot/help.md`: Command reference
- `src/commands/autopilot/progress.md`: Show completion status
- `src/commands/autopilot/debug.md`: Interactive debugging
- `src/commands/autopilot/map.md`: Codebase analysis and context auditing
- `src/commands/autopilot/add-phase.md`: Add new phase to roadmap
- `src/commands/autopilot/insert-phase.md`: Insert phase in sequence
- `src/commands/autopilot/remove-phase.md`: Remove phase from roadmap
- `src/commands/autopilot/update.md`: Check/install package updates

**Background:**
- `src/hooks/autopilot-check-update.js`: Update checker (runs at session start)

## Naming Conventions

**Files:**
- Commands: `{name}.md` (lowercase, hyphens)
  - Examples: `autopilot.md`, `add-phase.md`, `autopilot-check-update.js`
- Agents: `{agent-type}.md` (lowercase, hyphens)
  - Examples: `autopilot-phase-runner.md`, `autopilot-debugger.md`
- Protocols: `{protocol-name}.md` (lowercase, hyphens)
  - Examples: `autopilot-orchestrator.md`, `autopilot-playbook.md`

**Directories:**
- Top-level structure: lowercase with underscores when compound
  - Examples: `src/`, `.planning/`, `.autopilot/`
- Nested: hyphens for word separation
  - Examples: `autopilot/`, `src/commands/autopilot/`

**YAML Frontmatter:**
- All command and agent files MUST have YAML frontmatter
- `name`: Exactly matches filename (without .md)
- `description`: One-line purpose
- `tools`: Array of tool names (Read, Write, Edit, Bash, Task, Glob, Grep)
- `color`: Optional (for visual identification in Claude Code UI)

## Where to Add New Code

**New Subcommand:**
1. Create `src/commands/autopilot/{name}.md`
2. Include YAML frontmatter with name, description, allowed-tools
3. Follow command template structure (update_check, objective, execution sections)
4. During install, manually add to FILE_MAP in `bin/install.js` (lines 19-34)

**New Step Agent (for extending pipeline):**
1. Create `src/agents/{agent-type}.md`
2. Include YAML frontmatter, tools, color
3. Define role, input contract, output JSON schema
4. Document in autopilot-playbook.md Context Budget Table
5. Ensure phase-runner knows how to spawn it (via task type or spawn logic)

**New Protocol Documentation:**
1. Create `src/protocols/{protocol-name}.md`
2. Target audience: agents/commands that will read it
3. Add entry to FILE_MAP if it's a runtime reference (required to be installed)
4. Reference via `__INSTALL_BASE__/autopilot/protocols/{protocol-name}.md` in other files

**New Feature (e.g., new orchestrator mode):**
1. Extend `src/commands/autopilot.md` flag parsing (lines with `--` flags)
2. Add orchestrator logic to `src/protocols/autopilot-orchestrator.md` (new Section)
3. Update phase-runner context if needed in `src/agents/autopilot-phase-runner.md`
4. Document publicly in `README.md`

## Special Directories

**`.autopilot/` (Runtime State):**
- Purpose: Orchestrator-managed execution checkpoint
- Generated: YES (created automatically during phase execution)
- Committed: NO (add to .gitignore)
- Contents:
  - `state.json`: JSON checkpoint (phase status, scores, timing)
  - `context-map.json`: User responses from --map/--discuss
  - `learnings.md`: Learned failure patterns (reset per run)
  - `diagnostics/`: Per-phase analysis (confidence scores, debug traces)
  - `cache/`: Cached lookup results (update check)
  - `archive/`: Prior run snapshots (for rollback/review)

**`.planning/` (Project Planning):**
- Purpose: GSD-created project structure and roadmap
- Generated: YES (by `/gsd:new-project` command)
- Committed: YES (human-written roadmap is source truth)
- Standard contents (created by GSD):
  - `ROADMAP.md`: Phase definitions, dependencies, goals
  - `REQUIREMENTS.md` or `PROJECT.md`: Frozen spec
  - `phases/{N}-{name}/`: Per-phase directories with plan, research, etc.

**`src/` (Distribution)**
- Purpose: Source files copied to ~/.claude/ during install
- Generated: NO (handwritten)
- Committed: YES
- Installation behavior: Files are copied, `__INSTALL_BASE__` placeholder replaced with install path

## Installation File Map

When user runs `npx autopilot-cc@latest`, `bin/install.js` copies files from `src/` to `~/.claude/` (or `./.claude/` if --local):

| Source | Destination (relative to ~/.claude/) |
|--------|--------------------------------------|
| `src/commands/autopilot.md` | `commands/autopilot.md` |
| `src/commands/autopilot/*.md` | `commands/autopilot/*.md` |
| `src/agents/autopilot-phase-runner.md` | `agents/autopilot-phase-runner.md` |
| `src/agents/autopilot-debugger.md` | `agents/autopilot-debugger.md` |
| `src/protocols/autopilot-orchestrator.md` | `autopilot/protocols/autopilot-orchestrator.md` |
| `src/protocols/autopilot-playbook.md` | `autopilot/protocols/autopilot-playbook.md` |
| `src/protocols/autopilot-schemas.md` | `autopilot/protocols/autopilot-schemas.md` |
| `src/protocols/update-check-banner.md` | `autopilot/protocols/update-check-banner.md` |
| `src/hooks/autopilot-check-update.js` | `hooks/autopilot-check-update.js` |
| `VERSION` | `autopilot/VERSION` |

**Placeholder replacement:** During install, all instances of `__INSTALL_BASE__` in file contents are replaced with the actual install path (e.g., `/Users/user/.claude`).

---

*Structure analysis: 2026-02-17*
