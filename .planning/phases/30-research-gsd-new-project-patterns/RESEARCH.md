# Research: Phase 30 -- gsd:new-project Pattern Analysis

## Summary

Comprehensive reverse-engineering of `/gsd:new-project` completed. The command follows a 9-step flow: Setup -> Brownfield Offer -> Deep Questioning -> Write PROJECT.md -> Workflow Preferences -> Research Decision -> Define Requirements -> Create Roadmap -> Done. Key patterns identified for phase creation adaptation.

## Key Findings

1. **The flow is orchestrator-driven with subagent spawning** -- the command file delegates to a workflow file which spawns specialized agents (project-researchers, synthesizers, roadmappers)
2. **Deep questioning is the highest-leverage step** -- uses a philosophy of "dream extraction, not requirements gathering" with follow-the-thread technique
3. **Parallel research across 4 dimensions** (Stack, Features, Architecture, Pitfalls) with synthesis creates comprehensive domain understanding
4. **Requirements are scoped interactively** -- research findings are presented by category, user selects which are v1/v2/out-of-scope
5. **The roadmapper uses goal-backward thinking** -- "What must be TRUE when this phase completes?" not "What tasks do we need?"
6. **100% coverage validation is non-negotiable** -- every requirement maps to exactly one phase
7. **Auto mode exists** for document-driven initialization, skipping interactive questioning

## Files Analyzed

- `/home/parth/.claude/commands/gsd/new-project.md` -- command definition
- `/home/parth/.claude/get-shit-done/workflows/new-project.md` -- full 9-step workflow
- `/home/parth/.claude/get-shit-done/references/questioning.md` -- questioning philosophy and techniques
- `/home/parth/.claude/get-shit-done/templates/project.md` -- PROJECT.md template
- `/home/parth/.claude/get-shit-done/templates/requirements.md` -- REQUIREMENTS.md template
- `/home/parth/.claude/agents/gsd-roadmapper.md` -- roadmap creation agent
- `/home/parth/.claude/agents/gsd-project-researcher.md` -- research agent
- `/home/parth/.claude/get-shit-done/references/ui-brand.md` -- visual patterns
- `/home/parth/.claude/get-shit-done/workflows/discuss-phase.md` -- discuss flow for comparison
- `src/commands/autopilot/add-phase.md` -- current autopilot add-phase command

## Codebase Structure

The current `/autopilot:add-phase` is a deterministic, non-interactive command that:
- Parses a phase description from arguments
- Extracts phase numbers via regex
- Creates directory, roadmap entries, progress table rows, execution order updates
- Produces stub sections with "[To be planned]" placeholders
- Has zero intelligence about the phase content -- no questioning, no research, no spec generation
