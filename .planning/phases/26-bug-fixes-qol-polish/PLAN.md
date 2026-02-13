# Phase 26: Bug Fixes and QoL Polish - Plan

## Overview

Phase 26 addresses two main items and a verification task:
1. **--discuss UX redesign** (main work): Transform from batch-dump Q&A to conversational gray-area probing modeled on /gsd:discuss
2. **--quality auto-routing verification** (already done): Verify commit 41b351e properly implements this
3. **Bug sweep confirmation**: Verify no pending bugs exist

## Wave 1: --discuss UX Redesign

<task id="26-01" type="auto" complexity="complex">

### Task 26-01: Redesign --discuss in orchestrator to conversational gray-area pattern

**Files:**
- `src/protocols/autopilot-orchestrator.md` (modify Section 1.7)

**Action:**
Rewrite Section 1.7 (Discuss Mode) in the orchestrator to follow the conversational pattern from /gsd:discuss:

1. **Replace the Discussion Agent prompt** with a two-phase approach:
   - Phase A: Gray Area Analysis -- spawn a subagent that reads the phase goal/requirements and identifies 3-5 domain-specific gray areas (not generic questions). The agent analyzes what kind of thing the phase builds (something users SEE, CALL, RUN, READ, or ORGANIZE) and generates concrete discussion topics.
   - Phase B: Conversational Probing -- instead of batching all questions, the orchestrator presents gray areas to the user for selection, then deep-dives each selected area with focused questions.

2. **Replace batch question collection** with interactive per-area discussion:
   - Present gray areas as a selection list (user picks which to discuss)
   - For each selected area: present 3-4 focused questions one area at a time
   - After each area: ask "More about this area, or move on?"
   - After all areas: confirm and create output

3. **Add scope guardrail**: When user suggests new capabilities during discussion, redirect to deferred ideas (do not expand scope).

4. **Update output format**: Write structured CONTEXT.md to phase directory (in addition to discuss-context.json for backward compatibility). CONTEXT.md has sections: Phase Boundary, Implementation Decisions per area, Claude's Discretion items, Specific Ideas, Deferred Ideas.

5. **Update the spawn prompt injection**: Phase-runners should read both `.autopilot/discuss-context.json` AND `{phase_dir}/CONTEXT.md` if they exist.

**Acceptance Criteria:**
- Section 1.7 contains a Gray Area Analysis Agent prompt that identifies domain-specific discussion topics (not generic questions) -- verified by: `grep -c 'gray.area\|Gray Area' src/protocols/autopilot-orchestrator.md | awk '{print ($1 >= 3) ? "PASS" : "FAIL"}'`
- Section 1.7 instructs the orchestrator to present gray areas for user selection before deep-diving -- verified by: `grep 'select.*area\|choose.*area\|pick.*area\|Which areas' src/protocols/autopilot-orchestrator.md`
- Section 1.7 includes per-area conversational probing with 3-4 questions per area -- verified by: `grep -c 'per.area\|each.*area\|per area\|questions per area' src/protocols/autopilot-orchestrator.md | awk '{print ($1 >= 2) ? "PASS" : "FAIL"}'`
- Section 1.7 includes depth control (user can request more questions or move to next area) -- verified by: `grep 'more.*question\|move.*next\|next area\|More about' src/protocols/autopilot-orchestrator.md`
- Section 1.7 includes scope guardrail that redirects scope creep to deferred ideas -- verified by: `grep -c 'scope.*guardrail\|scope.*creep\|deferred.*idea\|Deferred Ideas' src/protocols/autopilot-orchestrator.md | awk '{print ($1 >= 2) ? "PASS" : "FAIL"}'`
- Section 1.7 instructs writing CONTEXT.md to phase directory -- verified by: `grep 'CONTEXT.md' src/protocols/autopilot-orchestrator.md | grep -v 'discuss-context'`
- CONTEXT.md structure includes Phase Boundary, Implementation Decisions, Claude's Discretion, and Deferred Ideas sections -- verified by: `grep -c 'Phase Boundary\|Implementation Decisions\|Claude.*Discretion\|Deferred Ideas' src/protocols/autopilot-orchestrator.md | awk '{print ($1 >= 3) ? "PASS" : "FAIL"}'`
- The domain-analysis prompt includes category heuristics (SEE/CALL/RUN/READ/ORGANIZE) -- verified by: `grep -E 'SEE|CALL|RUN|READ|ORGANIZE' src/protocols/autopilot-orchestrator.md`

**Verify:** Run test specification at `.planning/phases/26-bug-fixes-qol-polish/tests/task-26-01.sh`
**Done:** false
</task>

## Wave 2: Command File and Playbook Updates

<task id="26-02" type="auto" complexity="medium">

### Task 26-02: Update autopilot command file and playbook references

**Files:**
- `src/commands/autopilot.md` (modify --discuss description)
- `src/protocols/autopilot-playbook.md` (modify discuss context references)

**Action:**
1. Update the `--discuss` description in `src/commands/autopilot.md` to reflect the new conversational UX:
   - Mention gray area identification, user-selectable topics, per-area deep-dive
   - Reference CONTEXT.md as the output artifact (in addition to discuss-context.json)

2. Update the `If --discuss` section in autopilot.md to describe the new flow

3. Update playbook references to discuss context:
   - The `discuss_context` input field description should reference both discuss-context.json and CONTEXT.md
   - Research step should include instruction to read CONTEXT.md from phase directory if it exists
   - Plan step should include instruction to use CONTEXT.md decisions when available

**Acceptance Criteria:**
- autopilot.md --discuss description mentions gray areas and conversational probing -- verified by: `grep 'gray area\|conversational\|per-area' src/commands/autopilot.md`
- autopilot.md --discuss description mentions CONTEXT.md -- verified by: `grep 'CONTEXT.md' src/commands/autopilot.md`
- autopilot.md If --discuss section describes the new two-phase flow (analysis then probing) -- verified by: `grep -A5 'If.*--discuss' src/commands/autopilot.md | grep -c 'gray area\|analysis\|CONTEXT.md' | awk '{print ($1 >= 1) ? "PASS" : "FAIL"}'`
- Playbook discuss_context input field references CONTEXT.md -- verified by: `grep -A2 'discuss_context' src/protocols/autopilot-playbook.md | grep 'CONTEXT.md'`
- Playbook research step mentions reading CONTEXT.md from phase directory -- verified by: `grep -B2 -A2 'CONTEXT.md' src/protocols/autopilot-playbook.md | grep -i 'research\|phase.*dir'`

**Verify:** Run test specification at `.planning/phases/26-bug-fixes-qol-polish/tests/task-26-02.sh`
**Done:** false
</task>

<task id="26-03" type="auto" complexity="simple">

### Task 26-03: Verify --quality auto-routing and confirm no pending bugs

**Files:**
- `src/protocols/autopilot-orchestrator.md` (read Section 1.5 to verify)
- `src/commands/autopilot.md` (read --quality description to verify)

**Action:**
1. Verify that the --quality auto-routing fix (commit 41b351e) is properly in place:
   - Section 1.5 should describe handling for unexecuted phases (standard pipeline with 9.5 threshold)
   - The autopilot.md --quality description should mention unexecuted phases

2. Confirm no pending bugs exist by scanning source files for TODO/FIXME/HACK markers

3. Document findings in EXECUTION-LOG.md

**Acceptance Criteria:**
- Orchestrator Section 1.5 describes --quality behavior for unexecuted phases -- verified by: `grep -i 'unexecuted\|not.*executed\|hasn.*executed\|standard pipeline' src/protocols/autopilot-orchestrator.md | grep -i 'quality'`
- autopilot.md --quality description mentions unexecuted phases -- verified by: `grep 'unexecuted' src/commands/autopilot.md`
- No TODO/FIXME/HACK markers exist in src/ directory -- verified by: `grep -r 'TODO\|FIXME\|HACK' src/ --include='*.md' | wc -l | awk '{print ($1 == 0) ? "PASS: no bugs found" : "FAIL: " $1 " markers found"}'`

**Verify:** Run test specification at `.planning/phases/26-bug-fixes-qol-polish/tests/task-26-03.sh`
**Done:** false
</task>

## Traceability

| Requirement | Task(s) | Status |
|-------------|---------|--------|
| 1. --discuss UX redesign | 26-01, 26-02 | Pending |
| 2. --quality auto-routing | 26-03 (verify only) | Already implemented |
| 3. Pending bugs resolved | 26-03 | Pending (verify) |
| 4. No regression | All tasks | Pending |

## Complexity Summary

| Task | Complexity | Files | Description |
|------|-----------|-------|-------------|
| 26-01 | complex | 1 | Rewrite orchestrator Section 1.7 |
| 26-02 | medium | 2 | Update command + playbook references |
| 26-03 | simple | 2 (read only) | Verify existing fixes, bug sweep |
