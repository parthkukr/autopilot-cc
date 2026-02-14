# Phase 28: Context Budget Regression Investigation -- PLAN

## Goal
Diagnose and fix the context exhaustion regression introduced after the v1.8.0 wave of upgrades (Phases 17-26). Present findings for user review, then apply targeted fixes (deduplication of redundant content in the phase-runner agent definition) that reduce context consumption without sacrificing quality enforcement.

## Approach
1. Produce a FINDINGS.md investigation report with quantified data
2. Apply Strategy B (deduplication of phase-runner agent definition overlap with playbook) as a zero-risk first fix
3. Leave Strategy A (playbook modularization) for future discussion

## Traceability

| Requirement | Tasks |
|-------------|-------|
| Diagnose context regression root causes | 28-01 |
| Quantify protocol file growth from Phases 17-26 | 28-01 |
| Apply zero-risk deduplication fixes | 28-02 |
| Verify context consumption reduction | 28-03 |

---

<task id="28-01" type="auto" complexity="medium">
### Task 28-01: Create Investigation Report (FINDINGS.md)

**Description:** Produce a clean, user-facing investigation report at `.planning/phases/28-context-budget-regression/FINDINGS.md` that summarizes the research with clear data tables, root cause analysis, and actionable recommendations. This is the primary deliverable for user review.

**Files:**
- CREATE: `.planning/phases/28-context-budget-regression/FINDINGS.md`

**Action:**
1. Read RESEARCH.md to extract key data points
2. Write a concise, well-structured FINDINGS.md that covers:
   - Protocol file size comparison (before vs. after v1.8.0)
   - Per-phase contribution ranking
   - Root cause analysis (3 causes)
   - Proposed fix strategies with trade-offs
   - Open questions for user
3. Commit the findings report

**Acceptance Criteria:**
1. FINDINGS.md exists and contains a data table of protocol file sizes -- verified by: `test -f .planning/phases/28-context-budget-regression/FINDINGS.md && grep -c '|.*lines.*|' .planning/phases/28-context-budget-regression/FINDINGS.md` (expect >= 3)
2. FINDINGS.md contains a per-phase contribution ranking table -- verified by: `grep -c 'Phase 2[0-6]' .planning/phases/28-context-budget-regression/FINDINGS.md` (expect >= 5)
3. FINDINGS.md contains root cause analysis section -- verified by: `grep -c 'Root Cause' .planning/phases/28-context-budget-regression/FINDINGS.md` (expect >= 3)
4. FINDINGS.md contains proposed strategies section -- verified by: `grep -c 'Strategy' .planning/phases/28-context-budget-regression/FINDINGS.md` (expect >= 2)

**Verify:** `bash .planning/phases/28-context-budget-regression/tests/task-28-01.sh`
**Done:** FINDINGS.md committed with investigation results
</task>

<task id="28-02" type="auto" complexity="medium">
### Task 28-02: Apply Strategy B Deduplication to Phase-Runner Agent Definition

**Description:** Remove redundant content from the phase-runner agent definition (`autopilot-phase-runner.md` or equivalent) that duplicates what is already in the playbook. The phase-runner reads the playbook at runtime, so having the same instructions in both places wastes context. Specifically target: progress streaming section overlap, PVRF-01 detailed description overlap, and spawning step agents details overlap.

**Files:**
- MODIFY: The phase-runner agent definition (the system prompt that is the current conversation -- since this IS the phase-runner agent definition, the actual changes go to the protocol files that agents reference)

NOTE: Since the phase-runner agent definition is part of the system prompt injected by the orchestrator at spawn time (not a standalone file in the protocols directory that we can directly edit), Strategy B targets the playbook itself to reduce INTERNAL redundancy, and the orchestrator spawn template to reduce what it injects. The key deduplication targets are:
- In the playbook: condense the trace aggregation section (17 lines can be 5)
- In the playbook: condense the progress emission section (58 lines can be 20)
- In the playbook: condense the PVRF-01 mini-verifier context budget table (redundant with main budget table)
- In the playbook: condense verbose examples in sandbox execution policy
- In the playbook: remove redundant "decimal x.x format" reminders after the first definition

**Action:**
1. Read the playbook and identify specific redundant passages
2. Condense trace aggregation from ~17 to ~5 lines
3. Condense progress emission from ~58 to ~20 lines
4. Remove redundant "decimal x.x format" reminders (keep the first, remove subsequent)
5. Condense mini-verifier context budget (merge into main budget table)
6. Condense sandbox execution policy examples
7. Run a line count before and after to measure reduction
8. Commit changes

**Acceptance Criteria:**
1. The playbook line count is reduced by at least 40 lines -- verified by: `wc -l < /mnt/c/Users/Parth/.claude/autopilot/protocols/autopilot-playbook.md` (expect <= 1816)
2. The trace aggregation section is condensed -- verified by: `grep -A 20 'Trace Aggregation' /mnt/c/Users/Parth/.claude/autopilot/protocols/autopilot-playbook.md | wc -l` (expect <= 12)
3. The progress emission section is condensed -- verified by: `grep -n 'Progress Emission' /mnt/c/Users/Parth/.claude/autopilot/protocols/autopilot-playbook.md | head -1`
4. All pipeline step prompt templates still exist (no accidental deletion) -- verified by: `grep -c 'STEP [0-9]' /mnt/c/Users/Parth/.claude/autopilot/protocols/autopilot-playbook.md` (expect >= 7)
5. Key quality enforcement preserved (blind verification, rating agent isolation) -- verified by: `grep -c 'VRFY-01\|BLIND VERIFICATION\|CONTEXT ISOLATION' /mnt/c/Users/Parth/.claude/autopilot/protocols/autopilot-playbook.md` (expect >= 3)

**Verify:** `bash .planning/phases/28-context-budget-regression/tests/task-28-02.sh`
**Done:** Playbook deduplication committed with measured line reduction
</task>

<task id="28-03" type="auto" complexity="simple">
### Task 28-03: Measure and Document Context Reduction

**Description:** Measure the actual context reduction achieved by the deduplication, update FINDINGS.md with the results, and create a SUMMARY.md for the phase.

**Files:**
- MODIFY: `.planning/phases/28-context-budget-regression/FINDINGS.md`
- CREATE: `.planning/phases/28-context-budget-regression/SUMMARY.md`

**Action:**
1. Measure post-fix line counts and byte counts of all protocol files
2. Calculate actual reduction vs. pre-fix baseline
3. Add a "Results" section to FINDINGS.md with before/after comparison
4. Create SUMMARY.md with phase completion summary
5. Commit

**Acceptance Criteria:**
1. FINDINGS.md contains a "Results" or "After" section with post-fix measurements -- verified by: `grep -c 'After\|Result\|Post-fix\|Reduction' .planning/phases/28-context-budget-regression/FINDINGS.md` (expect >= 2)
2. SUMMARY.md exists with phase summary -- verified by: `test -f .planning/phases/28-context-budget-regression/SUMMARY.md`
3. SUMMARY.md mentions the context reduction achieved -- verified by: `grep -c 'reduction\|reduced\|saved\|lines' .planning/phases/28-context-budget-regression/SUMMARY.md` (expect >= 1)

**Verify:** `bash .planning/phases/28-context-budget-regression/tests/task-28-03.sh`
**Done:** Reduction measured and documented
</task>
