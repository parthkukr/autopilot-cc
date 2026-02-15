# Plan: Phase 33 -- Codebase-Aware Phase Positioning

## Phase Goal
Before creating new phases, `/autopilot:add-phase` scans the existing roadmap, codebase architecture, and completed work to understand the current state -- it avoids creating duplicate phases, positions new phases with correct dependencies, and understands what infrastructure already exists that new phases can build on.

## Requirements Traceability

| Criterion | Task(s) |
|-----------|---------|
| Overlap detection warns before creating redundant phases | 33-01 |
| Analyzes completed phases for existing infrastructure | 33-02 |
| Dependencies set based on technical analysis | 33-02, 33-03 |
| Suggests extending existing phase via insert-phase | 33-01 |

## Tasks

<task id="33-01" type="auto" complexity="medium">
### Task 33-01: Add Overlap Detection and Insert-Phase Suggestion

**Files:** `src/commands/autopilot/add-phase.md`
**Action:** Add a new Step 1.5 "Codebase and Roadmap Awareness Scan" between Step 1 (Accept Freeform Input) and Step 2 (Semantic Analysis). This step:
1. Reads all existing phase entries from ROADMAP.md (titles, goals, success criteria)
2. For each proposed phase (before creating it), semantically compares it against every existing phase
3. If overlap detected (>70% semantic overlap), presents a warning with options:
   - "Create anyway (it's different enough)"
   - "Extend [Phase N] instead (use /autopilot:insert-phase N.X)"
   - "Cancel"
4. When the user chooses "extend", instructs to use /autopilot:insert-phase with the overlapping phase number
5. For multi-phase decompositions (Step 4/5), the overlap check runs per-item before batch creation

**Acceptance Criteria:**
1. Step 1.5 exists between Step 1 and Step 2 with overlap detection logic -- verified by: `grep -c 'Step 1.5.*Codebase.*Roadmap.*Awareness' src/commands/autopilot/add-phase.md` (expect >= 1)
2. The overlap detection reads all existing phases from ROADMAP.md -- verified by: `grep -c 'existing.*phase.*ROADMAP\|ROADMAP.*existing.*phase' src/commands/autopilot/add-phase.md` (expect >= 1)
3. Semantic overlap comparison is described (not just string matching) -- verified by: `grep -c 'semantic.*overlap\|semantic.*similar\|semantic.*compar' src/commands/autopilot/add-phase.md` (expect >= 1)
4. Warning presentation includes create-anyway, extend-via-insert-phase, and cancel options -- verified by: `grep -c 'insert-phase' src/commands/autopilot/add-phase.md` (expect >= 1)
5. The overlap check applies to both single-phase and multi-phase paths -- verified by: `grep -c 'overlap' src/commands/autopilot/add-phase.md` (expect >= 3)

**Verify:** Run `.planning/phases/33-codebase-aware-phase-positioning/tests/task-33-01.sh`
**Done:** Step 1.5 with overlap detection and insert-phase suggestion is present in add-phase.md
</task>

<task id="33-02" type="auto" complexity="medium">
### Task 33-02: Add Infrastructure Awareness and Completed Phase Analysis

**Files:** `src/commands/autopilot/add-phase.md`
**Action:** Enhance Step 1.5 and Step 2.5 to:
1. In Step 1.5, scan completed phases (those marked [x] in ROADMAP.md) to build an infrastructure inventory of what capabilities, patterns, and systems already exist
2. In Step 2.5 (Generate Rich Phase Specification), use the infrastructure inventory to:
   - Reference existing capabilities in the new phase's Goal section (e.g., "This phase can leverage the one-question-at-a-time pattern already implemented in Phase 29")
   - Set dependencies based on actual technical needs from infrastructure analysis
   - Mention available infrastructure in the dependency rationale
3. Read STATE.md and/or EXECUTION-LOG.md from completed phase dirs to understand what was actually built

**Acceptance Criteria:**
1. Step 1.5 includes infrastructure inventory from completed phases -- verified by: `grep -c 'infrastructure\|completed.*phase.*capabilit\|inventory' src/commands/autopilot/add-phase.md` (expect >= 2)
2. Step 2.5 references infrastructure inventory in Goal generation -- verified by: `grep -c 'infrastructure.*Goal\|existing.*capabilit.*Goal\|leverage.*exist' src/commands/autopilot/add-phase.md` (expect >= 1)
3. Dependency analysis uses infrastructure inventory for technical dependency identification -- verified by: `grep -c 'technical.*depend\|infrastructure.*depend\|actual.*technical' src/commands/autopilot/add-phase.md` (expect >= 1)
4. The command reads completed phase status from ROADMAP.md markers -- verified by: `grep -c '\[x\].*completed\|completed.*\[x\]\|marked.*completed' src/commands/autopilot/add-phase.md` (expect >= 1)

**Verify:** Run `.planning/phases/33-codebase-aware-phase-positioning/tests/task-33-02.sh`
**Done:** Infrastructure awareness and completed phase analysis integrated into add-phase.md
</task>

<task id="33-03" type="auto" complexity="medium">
### Task 33-03: Add Technical Dependency Positioning Logic

**Files:** `src/commands/autopilot/add-phase.md`
**Action:** Enhance the dependency analysis in Step 2.5 and the execution order update logic to:
1. In Step 2.5's dependency analysis section, add explicit technical dependency positioning logic:
   - Analyze what the new phase technically requires (infrastructure, APIs, patterns, files)
   - Match those requirements against existing phases' deliverables
   - Set the "Depends on" field based on these technical matches, not sequential numbering
2. In the execution order update (Step 3 substep 9, Step 5 substep 4g), position the new phase after its last technical dependency in the execution order chain, not just appended to the end
3. Warn if the new phase depends on a pending (not yet executed) phase
4. Update the success_criteria section of add-phase.md to include the new codebase-awareness criteria

**Acceptance Criteria:**
1. Dependency analysis includes technical requirement matching logic -- verified by: `grep -c 'technical.*require\|require.*infrastructure\|deliverable.*match\|what.*phase.*need' src/commands/autopilot/add-phase.md` (expect >= 1)
2. Execution order positioning considers dependencies, not just appending -- verified by: `grep -c 'position.*after.*depend\|dependency.*position\|after.*last.*depend' src/commands/autopilot/add-phase.md` (expect >= 1)
3. Warning for dependencies on pending phases -- verified by: `grep -c 'pending.*phase.*warn\|warn.*pending\|not.*executed.*yet\|not.*completed.*depend' src/commands/autopilot/add-phase.md` (expect >= 1)
4. Success criteria section updated with codebase-awareness criteria -- verified by: `grep -c 'overlap.*detect\|infrastructure.*aware\|codebase.*aware\|duplicate.*detect' src/commands/autopilot/add-phase.md` (expect >= 1)

**Verify:** Run `.planning/phases/33-codebase-aware-phase-positioning/tests/task-33-03.sh`
**Done:** Technical dependency positioning and pending-phase warnings integrated into add-phase.md
</task>
