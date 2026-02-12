---
name: autopilot-debug
description: Systematic debugging with persistent state -- spawns autopilot-debugger agent using scientific method
argument-hint: [issue description | phase N failure | resume]
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
Debug issues using scientific method with subagent isolation. Fully native to autopilot-cc -- no dependency on external debug systems.

**Orchestrator role:** Gather symptoms, spawn autopilot-debugger agent, handle checkpoints, spawn continuations. Integrate findings with autopilot's failure taxonomy and learnings loop.

**Why subagent:** Investigation burns context fast (reading files, forming hypotheses, testing). Fresh 200k context per investigation. Main context stays lean for user interaction.

**Arguments:**
- Issue description: Free-form text describing the bug (e.g., `"executor creates orphaned files"`)
- Phase failure reference: `phase N failure` to load context from post-mortem (e.g., `phase 5 failure`)
- `resume` -- resume an active debug session
</objective>

<reference>
**Architecture:**
```
Tier 1: You (Debug Orchestrator) -- manages sessions and user interaction
Tier 2: autopilot-debugger agent -- performs the actual investigation
```

**Integration points:**
- Post-mortems: `.autopilot/diagnostics/phase-{N}-postmortem.json` -- loaded when user references a phase failure
- Learnings: `.autopilot/learnings.md` -- findings appended as prevention rules
- Failure taxonomy: `executor_incomplete`, `executor_wrong_approach`, `compilation_failure`, `lint_failure`, `build_failure`, `acceptance_criteria_unmet`, `scope_creep`, `context_exhaustion`, `tool_failure`, `coordination_failure`
- Debug sessions: `.planning/debug/{slug}.md` -- persistent state files

**Session file location:**
```
.planning/debug/{slug}.md          -- active sessions
.planning/debug/resolved/{slug}.md -- resolved sessions
```
</reference>

<execution>

## On Invocation

1. **Parse argument** -- determine if issue description, phase failure reference, or resume
2. **Agent availability check** -- Verify `autopilot-debugger` agent type is available. If NOT:
   ```
   autopilot-debugger agent type not found.

   Claude Code discovers agent types at session startup. This means you
   installed or updated autopilot-cc after this session started.

   Fix: Exit Claude Code and start a new session, then re-run /autopilot debug.
   ```

## If `resume` (no arguments, or explicit `resume`)

### Check Active Sessions

```bash
ls .planning/debug/*.md 2>/dev/null | grep -v resolved | head -10
```

**If active sessions exist:**
- List sessions with status, current hypothesis, next action (read frontmatter of each)
- User picks a session number to resume OR describes a new issue

**If no active sessions:**
- "No active debug sessions. Describe the issue to start investigating."

### Resume Selected Session

Spawn autopilot-debugger with the session file as context:

```
Task(
  prompt="Continue debugging from session file. Evidence and state are in the debug file.

  <prior_state>
  Debug file: .planning/debug/{slug}.md
  </prior_state>

  <mode>
  goal: find_and_fix
  </mode>",
  subagent_type="autopilot-debugger",
  description="Resume debug {slug}"
)
```

## If Phase Failure Reference (e.g., `phase 5 failure`)

1. **Load post-mortem context:**
   ```bash
   # Check for post-mortem
   cat .autopilot/diagnostics/phase-{N}-postmortem.json 2>/dev/null
   # Check for confidence diagnostic
   cat .autopilot/diagnostics/phase-{N}-confidence.md 2>/dev/null
   ```

2. **Extract failure context:**
   - Root cause category from post-mortem
   - Timeline of events
   - Files involved
   - Prevention rule (what was tried)

3. **Pre-fill symptoms** from post-mortem data and spawn debugger with `symptoms_prefilled: true`

4. **Spawn autopilot-debugger:**
   ```
   Task(
     prompt="Investigate phase {N} failure.

     <objective>
     Investigate issue: phase-{N}-{failure_category}

     **Summary:** {root_cause_from_postmortem}
     </objective>

     <symptoms>
     expected: Phase {N} should complete with alignment >= pass_threshold
     actual: {failure_description}
     errors: {error_details}
     reproduction: Re-run phase {N} to observe the failure
     timeline: Failed during {step_name} step
     </symptoms>

     <postmortem_context>
     {postmortem_json_summary}
     </postmortem_context>

     <mode>
     symptoms_prefilled: true
     goal: find_and_fix
     </mode>

     <debug_file>
     Create: .planning/debug/phase-{N}-{failure_category}.md
     </debug_file>",
     subagent_type="autopilot-debugger",
     description="Debug phase {N} failure"
   )
   ```

## If Issue Description (free-form text)

### 1. Gather Symptoms

Ask the user for each piece of information:

1. **Expected behavior** -- What should happen?
2. **Actual behavior** -- What happens instead?
3. **Error messages** -- Any errors? (paste or describe)
4. **Timeline** -- When did this start? Ever worked?
5. **Reproduction** -- How do you trigger it?

After all gathered, confirm ready to investigate.

### 2. Spawn autopilot-debugger Agent

Generate a slug from the issue description (lowercase, hyphens, max 30 chars).

```
Task(
  prompt="Investigate issue: {slug}

  <objective>
  **Summary:** {issue_description}
  </objective>

  <symptoms>
  expected: {expected}
  actual: {actual}
  errors: {errors}
  reproduction: {reproduction}
  timeline: {timeline}
  </symptoms>

  <mode>
  symptoms_prefilled: true
  goal: find_and_fix
  </mode>

  <debug_file>
  Create: .planning/debug/{slug}.md
  </debug_file>",
  subagent_type="autopilot-debugger",
  description="Debug {slug}"
)
```

## Handle Agent Return

**If `## ROOT CAUSE FOUND`:**
- Display root cause and evidence summary
- Offer options:
  - "Fix now" -- spawn fix agent (autopilot-debugger in find_and_fix mode)
  - "Manual fix" -- user handles it
  - "Add to learnings" -- append prevention rule to `.autopilot/learnings.md`

**If `## DEBUG COMPLETE`:**
- Display fix summary and verification results
- Auto-append prevention rule to `.autopilot/learnings.md` with failure category
- Report completion

**If `## CHECKPOINT REACHED`:**
- Present checkpoint details to user
- Get user response
- Spawn continuation agent with debug file + user response:
  ```
  Task(
    prompt="Continue debugging {slug}. Evidence is in the debug file.

    <prior_state>
    Debug file: .planning/debug/{slug}.md
    </prior_state>

    <checkpoint_response>
    **Type:** {checkpoint_type}
    **Response:** {user_response}
    </checkpoint_response>

    <mode>
    goal: find_and_fix
    </mode>",
    subagent_type="autopilot-debugger",
    description="Continue debug {slug}"
  )
  ```

**If `## INVESTIGATION INCONCLUSIVE`:**
- Show what was checked and eliminated
- Offer options:
  - "Continue investigating" -- spawn new agent with additional context
  - "Manual investigation" -- done
  - "Add more context" -- gather more symptoms, spawn again

## Learnings Integration

After any debug session completes (ROOT CAUSE FOUND or DEBUG COMPLETE), append a prevention rule to `.autopilot/learnings.md`:

```markdown
### Debug session: {slug} -- {failure_category}
**Prevention rule:** {prevention_rule_from_debug_session}
**Context:** Debug session `{slug}` identified `{failure_category}`. Root cause: {root_cause}. Recorded: {ISO-8601 timestamp}.
```

This ensures future executors and planners benefit from debugging discoveries.

</execution>

<success_criteria>
- [ ] Active sessions checked on invocation
- [ ] Symptoms gathered (if new issue) or pre-filled (if phase failure)
- [ ] autopilot-debugger agent spawned with full context
- [ ] Checkpoints handled correctly with user interaction
- [ ] Root cause confirmed before fixing
- [ ] Findings feed into learnings loop with failure category
- [ ] No dependency on external debug systems
</success_criteria>
