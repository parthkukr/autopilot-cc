# Phase 16: Context Exhaustion Prevention - Context

**Gathered:** 2026-02-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Prevent orchestrator and phase-runner agents from exhausting their context windows during execution. The root cause is oversized work scope, not missing budget tracking. The fix is automatic scope splitting when a phase-runner detects work is too large, plus architectural enforcement that the orchestrator stays lightweight (manager, not worker).

</domain>

<decisions>
## Implementation Decisions

### Orchestrator role (manager, not worker)
- Orchestrator MUST NOT read detailed files (UAT reports, plans, source code, full state dumps)
- Orchestrator only holds: phase names, scores, status, routing decisions
- All detailed analysis is delegated to sub-agents who return summaries
- If the orchestrator needs to assess UAT results, it spawns a sub-agent that reads the files and returns "phase 16: 5 issues, phase 17: 4 issues, summaries: [...]"
- This is the PRIMARY prevention mechanism -- a lightweight orchestrator will never hit context limits

### Scope splitting (phase-runner initiated)
- Phase-runner detects scope is too large DURING execution (not pre-assessed by orchestrator)
- When too large: phase-runner returns a **split request** to orchestrator instead of results
- Split request contains: recommended sub-phases, issue groupings, and rationale
- Orchestrator reads the split request and spawns N sub-agents in parallel, one per sub-phase
- Each sub-phase goes through its own validation/verification cycle independently
- Priority order: **Quality > Time > Tokens** -- spawning 14 sub-agents is fine if quality requires it

### Sub-phase execution
- Sub-phases run in **parallel** by default
- Each sub-phase gets its own verification (not shared)
- Completion report shows sub-phases inline: "Phase 20a, 20b, 20c" in the existing table format

### Context tracking
- Track context % for observability -- show in progress status table
- **Warn** at high thresholds but **never auto-stop** work because of context percentage
- No artificial 40% cap. The existing 40% threshold is removed as a hard gate
- If orchestrator context gets high, it should be because something is architecturally wrong (orchestrator reading too much), not because it needs a budget limit

### State management
- State.json updates use **incremental Edit()** for targeted field changes, not full-file Write() rewrites
- Each state update should consume <20 lines of context instead of 150+

### Split UX
- Brief inline notification when split happens: "Phase 20 too large (6 issues). Splitting into 6 sub-phases, launching in parallel..."
- Auto-proceed without asking user confirmation
- Completion report: same table format + split info column

### Recovery / auto-resume
- If orchestrator ever needs to /clear (safety net, should be rare): write handoff, auto-resume when user re-invokes
- Phase-runners that return split requests are NOT failures -- they're doing their job correctly

### Claude's Discretion
- Exact threshold for when a phase-runner decides work is "too large" (could be issue count, file count, estimated complexity)
- Whether step-level line budgets in the playbook are worth keeping (they're orthogonal to the scope splitting fix)
- Sub-phase planning: whether each sub-phase gets its own mini-plan or just gets the issue + "fix it"
- Whether normal (non-quality) phases should also support auto-splitting

</decisions>

<specifics>
## Specific Ideas

- "The orchestrator is like a manager -- he knows what's going on and where a project is in the pipeline, but if you ask him to edit an image he'd say 'yo I don't edit, I manage.'" The orchestrator finds the right agent for the job, doesn't do the work itself.
- "We don't care about tokens, we care about quality, and then after quality we care about time" -- spawning many parallel sub-agents is preferred over trying to squeeze everything into fewer agents
- The incident that triggered this: `/autopilot --quality` on 6 phases, all 6 phase-runners + orchestrator hit context limit. The orchestrator had read 7 UAT files and written state.json twice before even spawning agents.

</specifics>

<deferred>
## Deferred Ideas

None -- discussion stayed within phase scope

</deferred>

---

*Phase: 16-context-exhaustion-prevention*
*Context gathered: 2026-02-11*
