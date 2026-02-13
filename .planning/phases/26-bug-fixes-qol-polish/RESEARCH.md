# Phase 26: Bug Fixes and QoL Polish - Research

## Key Findings

### 1. --discuss Flag UX Gap Analysis

**Current autopilot --discuss flow (batch-dump pattern):**
- Orchestrator spawns a discussion agent per phase that generates 3-5 questions
- All questions across all phases are batched into ONE big text block
- User answers everything at once (inline with "Phase N, Q1: ...")
- Answers stored to `.autopilot/discuss-context.json`
- Phase-runner reads answers during research step

**GSD /gsd:discuss flow (conversational pattern):**
- Analyzes phase to identify domain-specific "gray areas" (not generic questions)
- Presents gray areas as a multi-select menu (user picks which to discuss)
- Deep-dives each selected area: 4 questions per area using AskUserQuestion
- After 4 questions, asks "more or next area?"
- Writes CONTEXT.md with structured decisions (not raw Q&A)
- Uses scope guardrail (redirects scope creep to deferred ideas)

**Key differences:**
1. Batch vs interactive: --discuss dumps all questions at once; GSD probes iteratively
2. Generic vs domain-aware: --discuss generates "targeted questions"; GSD identifies gray areas by analyzing the phase domain (UI = layout/interactions, CLI = flags/output, etc.)
3. Output format: --discuss records raw Q&A to JSON; GSD writes structured CONTEXT.md with decisions, Claude's discretion items, and deferred ideas
4. User agency: --discuss forces answering everything; GSD lets user select which areas to discuss
5. Depth control: --discuss has fixed question count; GSD offers "more questions or next?"

### 2. --quality Auto-Routing (Already Fixed)

Commit 41b351e (before checkpoint) already fixed this. The orchestrator now:
- For unexecuted phases: runs standard pipeline with 9.5 threshold
- For completed phases below 9.5: enters remediation loops
- Documentation in both autopilot.md and autopilot-orchestrator.md is updated

### 3. Known Bugs / Quality Issues

No TODO/FIXME/HACK markers found in source files.
No dedicated bugs/todo file exists.
The codebase appears clean.

### 4. Files That Need Modification

- `src/protocols/autopilot-orchestrator.md` -- Section 1.7 (Discuss Mode) needs redesign
- `src/commands/autopilot.md` -- --discuss description may need update
- `src/protocols/autopilot-playbook.md` -- Research/plan steps reference discuss-context.json; may need update for CONTEXT.md pattern

### 5. Existing Patterns to Follow

- The discuss-context.json schema in autopilot-schemas.md
- The GSD discuss-phase.md workflow pattern (gray areas, AskUserQuestion, CONTEXT.md)
- The orchestrator's existing --discuss implementation in Section 1.7

## Risks

1. The redesigned --discuss cannot use AskUserQuestion directly since it runs inside the orchestrator (not a slash command that has direct user interaction) -- the orchestrator communicates with users through text output, not structured question tools
2. The conversational depth (4 questions per area, iterative probing) may be hard to replicate in a subagent spawned by the orchestrator -- the orchestrator would need to manage the conversation loop itself

## Recommended Approach

Redesign --discuss in the orchestrator to follow the GSD pattern: (1) analysis phase identifies domain-specific gray areas, (2) present areas for user selection, (3) conversational deep-dive per area with depth control, (4) output structured CONTEXT.md (not just raw JSON). The orchestrator manages the conversation loop since it can print to user and wait for responses, similar to how --map collects answers.

## Open Questions

1. Should the output be CONTEXT.md (GSD pattern) or discuss-context.json (current pattern), or both?
2. Should the phase-runner still read discuss-context.json, or should it read CONTEXT.md from the phase directory instead?
