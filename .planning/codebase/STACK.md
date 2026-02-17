# Technology Stack

**Analysis Date:** 2026-02-17

## Languages

**Primary:**
- JavaScript (Node.js) - Core application logic, installer, hooks, protocols
- Markdown - Command definitions, agents, protocol documentation (Claude Code format)

## Runtime

**Environment:**
- Node.js >= 16.0.0 (specified in `package.json` engines field)

**Package Manager:**
- npm (implicit, used for package distribution and update checks)
- Lockfile: Not present (single-file installer, no dependencies)

## Frameworks

**CLI/Installation:**
- No external framework - pure Node.js `fs`, `path`, `os`, `crypto`, `child_process` modules

**Claude Code Integration:**
- Claude Code command system (YAML frontmatter-based command definitions)
- Claude Code agent system (subagent spawning via Task tool)

## Key Dependencies

**Critical:**
- `get-shit-done-cc` >= 1.15.0 - Required GSD framework for phase execution (enforced in installer with version check)

**Why it matters:** autopilot-cc is entirely dependent on GSD for:
- Phase research, planning, execution step agents (gsd-phase-researcher, gsd-planner, gsd-executor)
- Verification framework (gsd-verifier)
- Debugging system (gsd-debugger as fallback)
- The entire `.planning/` directory structure and roadmap format

**Built-in (Node.js stdlib only):**
- `fs` - File I/O for installer, manifest management, VERSION tracking
- `path` - Cross-platform path resolution for `~/.claude/` and `./.claude/` installs
- `os` - Detect home directory for global vs local installation
- `crypto` - SHA256 hashing for file integrity verification in manifests
- `child_process` - Background process spawning for update checks, phase execution coordination

## Configuration

**Environment:**
- No `.env` files used (configuration is installed via manifests, state tracked in `.autopilot/state.json`)
- Installation target: `~/.claude/` (global default) or `./.claude/` (project-local with `--local` flag)
- Version stored in `autopilot/VERSION` (installed alongside other files)

**Build:**
- No build process (installed files are shipped as-is with `__INSTALL_BASE__` placeholder replacement)
- `bin/install.js` is the sole entry point (referenced in `package.json` bin field)

**Key Configuration Requirements:**
- GSD >= 1.15.0 must be installed in the same target directory
- `~/.claude/settings.json` or `./.claude/settings.json` must exist for hook registration (created automatically by Claude Code if missing)
- `.planning/config.json` in target project (created by GSD) for phase specifications and visual testing config

## File Distribution

**Installed Files (via `bin/install.js`):**

| Source | Destination | Purpose |
|--------|-------------|---------|
| `src/commands/autopilot.md` | `commands/autopilot.md` | Primary command definition with orchestrator logic |
| `src/commands/autopilot/*.md` | `commands/autopilot/*.md` (8 subcommands) | Subcommand handlers (debug, add-phase, map, progress, help, update, insert-phase, remove-phase) |
| `src/agents/autopilot-phase-runner.md` | `agents/autopilot-phase-runner.md` | Phase execution agent definition |
| `src/agents/autopilot-debugger.md` | `agents/autopilot-debugger.md` | Debug system agent definition |
| `src/protocols/autopilot-orchestrator.md` | `autopilot/protocols/autopilot-orchestrator.md` | Orchestrator instructions (read by main command) |
| `src/protocols/autopilot-playbook.md` | `autopilot/protocols/autopilot-playbook.md` | Phase-runner step-by-step instructions |
| `src/protocols/autopilot-schemas.md` | `autopilot/protocols/autopilot-schemas.md` | Reference documentation (schemas, state contracts) |
| `src/protocols/update-check-banner.md` | `autopilot/protocols/update-check-banner.md` | Update banner protocol |
| `src/hooks/autopilot-check-update.js` | `hooks/autopilot-check-update.js` | SessionStart hook for background update checks |
| `VERSION` | `autopilot/VERSION` | Version tracking for update checks and display |

**Manifest Tracking:**
- `autopilot-file-manifest.json` written to install target after each install
- Contains SHA256 hashes of all installed files for integrity verification
- Format: `{ version, installed_at, target, files: [{ dest, hash }] }`

## Platform Requirements

**Development:**
- Node.js 16.0.0 or higher
- npm (for publishing/updates)
- Git (for distribution)
- Claude Code (requires active session to run commands)

**Production/Deployment:**
- Claude Code environment (commands installed in `~/.claude/`)
- Target project must have GSD >= 1.15.0 installed
- Target project must have `.planning/` directory structure (created by GSD)

## Update Mechanism

**Version Check:**
- Hook: `autopilot-check-update.js` runs on SessionStart, spawns background process
- Cache: Result written to `~/.claude/cache/autopilot-update-check.json` with 24-hour TTL
- Display: Update banner shown on every `/autopilot:*` command if newer version available
- Install: `npm view autopilot-cc version` (called with 10-second timeout)

**Version File Locations (checked in priority order):**
1. `./.claude/autopilot/VERSION` (project-local install)
2. `~/.claude/autopilot/VERSION` (global install)

---

*Stack analysis: 2026-02-17*
