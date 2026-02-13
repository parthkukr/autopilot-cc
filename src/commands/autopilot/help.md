---
name: autopilot:help
description: Show all available autopilot commands, flags, and usage examples
---

<update_check>
**Before any output**, silently check for available updates:
1. Read the file at `__INSTALL_BASE__/cache/autopilot-update-check.json` -- if missing or unreadable, skip silently
2. Parse JSON. If `update_available` is `true` AND `checked` is within the last 86400 seconds of the current time, display this single line BEFORE all other output:
   `Update available: v{installed} -> v{latest} -- run /autopilot:update`
3. If the file is missing, malformed, stale (>24h), or `update_available` is false, display nothing -- proceed silently
This check must never block or delay command execution.
</update_check>

<objective>
Display the complete autopilot command reference.

Output ONLY the reference content below. Do NOT add:
- Project-specific analysis
- Git status or file context
- Next-step suggestions
- Any commentary beyond the reference
</objective>

<process>
Output the following command reference directly -- no additions or modifications.

```
AUTOPILOT COMMAND REFERENCE
===========================

COMMANDS
--------

  /autopilot <phases>
      Run 1-N development phases autonomously using the 3-tier orchestrator
      pattern. Phases are verified with evidence-backed scoring.

      Arguments:
        <phases>      Phase range to execute (e.g., 1-14, 3-7, 5)
        resume        Resume from last checkpoint
        status        Show current state without executing
        update        Check for and install autopilot-cc updates

  /autopilot:debug [issue | phase N failure | resume]
      Systematic debugging with persistent state. Spawns an autopilot-debugger
      agent using scientific method. Supports new issue investigation, phase
      failure analysis from post-mortems, and resuming active debug sessions.

  /autopilot:add-phase <description>
      Add a new phase to the project roadmap. Automatically determines the next
      phase number, creates the phase directory, and updates ROADMAP.md.

  /autopilot:map [scope]
      Analyze the codebase and produce a structured analysis document covering
      project structure, technology stack, key files, and architecture patterns.
      Optionally narrow to a specific directory or concern.

  /autopilot:progress [--verbose]
      Show current phase status, completion percentage, and recommended next
      actions. Use --verbose for detailed per-phase scores and durations.

  /autopilot:help
      Show this command reference.

FLAGS (for /autopilot)
----------------------

  --complete          Run all outstanding phases in dependency order without
                      specifying a range. Skips completed phases automatically.

  --lenient           Use relaxed 7/10 alignment threshold instead of default
                      9/10. Phases scoring 7-8 pass without remediation.

  --force [phase]     Re-execute a completed phase from scratch. Existing
                      commits preserved, new work layers on top.

  --quality [phase]   Execute with elevated 9.5/10 threshold. Enters
                      remediation loops (max 3 cycles) if needed.

  --gaps [phase]      Analyze and resolve specific deficiencies preventing a
                      phase from reaching 10/10. Max 5 gap-fix iterations.

  --discuss [phases]  Run conversational discussion per phase before execution.
                      Identifies gray areas for user input. Decisions captured
                      in CONTEXT.md.

  --visual [phases]   Enable visual testing during verification for UI phases.
                      Requires project.visual_testing config.

  --map [phases]      Audit context sufficiency before execution. Spawns
                      questioning agent for underspecified phases.

  --sequential        Force all phases to run sequentially (no parallelization).

  --checkpoint-every N
                      Pause for human review every N phases.

USAGE EXAMPLES
--------------

  /autopilot 3-7             Run phases 3 through 7
  /autopilot --complete      Run all remaining phases to completion
  /autopilot 5 --quality     Run phase 5 with elevated quality threshold
  /autopilot:debug phase 3 failure
                              Investigate a phase 3 failure using post-mortem
  /autopilot:progress        Show current project progress
  /autopilot:add-phase "API rate limiting"
                              Add a new phase to the roadmap

QUICK START
-----------

  1. Install:    npx autopilot-cc@latest
  2. Run:        /autopilot <phase-range>
  3. Monitor:    /autopilot:progress
  4. Debug:      /autopilot:debug <issue>
  5. Help:       /autopilot:help
```
</process>
