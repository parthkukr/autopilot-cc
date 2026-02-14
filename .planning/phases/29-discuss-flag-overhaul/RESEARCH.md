# Phase 29: Discuss Flag Overhaul - Research

## Key Findings

### 1. GSD Discuss-Phase Pattern (Gold Standard)
The GSD `/gsd:discuss-phase` command (at `/mnt/c/Users/Parth/.claude/commands/gsd/discuss-phase.md`) uses a one-question-at-a-time flow with `AskUserQuestion` tool:
- **Step 1:** Analyze phase domain, identify 3-4 gray areas
- **Step 2:** Present gray areas with multiSelect, user picks which to discuss (NO skip option)
- **Step 3:** Per-area deep-dive: 4 questions at a time using AskUserQuestion with concrete options, then offer "more or next?"
- **Step 4:** Write CONTEXT.md with structured sections (domain, decisions, specifics, deferred)
- Uses AskUserQuestion tool for EACH interaction (not a wall of text)
- Questions have concrete options (2-3 choices + "You decide")
- Context-aware follow-ups based on answers

### 2. Current Autopilot --discuss Implementation (Section 1.7 of orchestrator)
Located at lines 452-671 of `autopilot-orchestrator.md`:
- **Step 1:** Spawns a gray area analysis *subagent* (not direct)
- **Step 2:** Presents gray areas for selection as numbered list text
- **Step 3:** Presents 3-4 questions PER AREA as a BLOCK of text, asks user to "Answer inline (e.g., 'Q1: ..., Q2: ...')"
- **Step 4:** Writes CONTEXT.md + discuss-context.json

**Core Problem:** Step 3 dumps multiple questions at once as text, not using AskUserQuestion. The user sees a wall of numbered questions and must answer them all inline. This is the "usable vs unusable" gap.

### 3. Specific Differences Between GSD and Autopilot Discuss

| Aspect | GSD discuss-phase | Autopilot --discuss |
|--------|-------------------|---------------------|
| Question delivery | One at a time via AskUserQuestion | Block of 3-4 at once as text |
| Options | Concrete choices (AskUserQuestion) | Free text inline answers |
| Depth control | After 4 questions: "more or next?" | After answers: "more or next?" |
| Gray area selection | AskUserQuestion multiSelect | Numbered list, parse text |
| Scope guardrail | Redirects scope creep inline | Same pattern (text-based) |
| Tool used | AskUserQuestion | Direct text output |
| Adaptive follow-ups | Yes (next question informed by answer) | Partially (follow-ups after block) |

### 4. Files That Need Modification

1. **`/mnt/c/Users/Parth/.claude/autopilot/protocols/autopilot-orchestrator.md`** -- Section 1.7 (lines 452-671): The discuss mode implementation. This is the PRIMARY target. Must rewrite Steps 2-3 to use one-question-at-a-time flow.

2. **`/mnt/c/Users/Parth/.claude/commands/autopilot.md`** -- The autopilot command definition (lines 140-148): The --discuss section. May need minor updates to reflect the new interaction model.

3. **No new files needed** -- this is a rewrite of existing protocol sections.

### 5. AskUserQuestion Availability
The autopilot command definition does NOT include `AskUserQuestion` in its allowed-tools list. The GSD command DOES. This is a critical difference -- the orchestrator cannot currently use AskUserQuestion.

However, the orchestrator runs as a top-level command with direct user interaction. It can ask questions directly in its output and read user responses. The key insight is that the orchestrator ALREADY has direct user interaction (Step 2 asks questions and waits for responses). The problem is HOW it structures those interactions, not the tool availability.

The orchestrator uses Task tool subagents. The gray area analysis agent runs as a background Task. But the Q&A happens at the orchestrator level directly.

### 6. Output Format Compatibility
Both GSD and autopilot produce the same output artifacts:
- CONTEXT.md in the phase directory
- The format is compatible (same sections: domain, decisions, Claude's discretion, deferred ideas)
- Autopilot additionally writes discuss-context.json for backward compatibility
- No changes needed to the output format

## Recommended Approach

Rewrite Section 1.7 of `autopilot-orchestrator.md` to implement the GSD-style one-question-at-a-time interaction pattern. Specifically: (1) Keep Step 1 (gray area analysis agent) as-is. (2) Rewrite Step 2 to present gray areas as a cleaner selection prompt. (3) Completely rewrite Step 3 to use a one-question-at-a-time loop with concrete options per question, context-aware follow-ups, and proper depth control (4 questions per area, then offer more/next). (4) Keep Steps 4-5 (output writing and phase-runner injection) largely as-is. (5) Update the autopilot command definition to reflect the new interaction model.

## Risks

1. The autopilot orchestrator does not have AskUserQuestion -- it communicates via direct text. The one-question-at-a-time pattern must be adapted to work with direct text Q&A rather than structured tool calls.
2. Protocol-only changes are hard to fully test -- verification relies on grep-based pattern matching rather than runtime execution.

## Open Questions

1. Should the gray area analysis agent prompt also be updated to generate better question options (concrete choices per question for the follow-up)?
