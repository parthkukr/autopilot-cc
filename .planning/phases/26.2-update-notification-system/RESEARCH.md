# Research: Phase 26.2 -- Update Notification System

## Key Findings

1. **SessionStart hook exists** (`src/hooks/autopilot-check-update.js`) -- runs on session start, spawns background node process to check npm for latest version, writes result to `~/.claude/cache/autopilot-update-check.json`
2. **Cache JSON schema**: `{ update_available: bool, installed: string, latest: string, checked: unix_timestamp }`
3. **No banner consumption exists** -- no command file reads from the cache file
4. **Colon syntax pattern** -- all subcommands use `autopilot:{name}` format (debug, help, add-phase, map, progress). Files live in `src/commands/autopilot/{name}.md`
5. **Installer FILE_MAP** in `bin/install.js` maps source files to install destinations; new files must be added here
6. **`__INSTALL_BASE__` placeholder** -- replaced with actual install path during install; used for referencing protocol files
7. **Main command handles `update` argument inline** -- the `update` logic in `autopilot.md` (lines 92-97) handles check/install. This needs to be extracted to `/autopilot:update` subcommand

## Recommended Approach

Create a reusable update banner snippet that each command file includes, plus an `/autopilot:update` subcommand. Since Claude Code command files are Markdown (not executable code), the banner must be an instruction within each command's prompt that tells the LLM to check the cache file and display a banner if an update is available. This is the simplest approach: add a `<update_check>` section to each command file that instructs the agent to read the cache and display a one-liner.

## Risks

- Adding banner logic to every command file creates maintenance burden -- but it's necessary since each command file is an independent prompt
- Cache file may not exist on first run or if hook hasn't fired yet -- handled by "silent when missing" requirement
