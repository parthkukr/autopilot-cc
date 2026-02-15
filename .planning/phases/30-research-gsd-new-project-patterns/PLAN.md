---
phase: 30
name: Research gsd:new-project Patterns for Phase Creation
type: protocol
tasks: 1
checkpoint_human_verify: 0
---

# Plan: Phase 30 -- Research gsd:new-project Patterns

## Overview

This is a pure research phase producing a single comprehensive design document. No code changes. The design document serves as the blueprint for phases 31-34.

## Tasks

### Task 30-01: Write Comprehensive Design Document (auto)

**Description:** Create a detailed design document at `.planning/phases/30-research-gsd-new-project-patterns/DESIGN.md` that catalogs the entire `/gsd:new-project` flow, identifies patterns applicable to phase creation, and provides a concrete specification for the redesigned `/autopilot:add-phase` command.

**Acceptance Criteria:**

1. Document exists at `.planning/phases/30-research-gsd-new-project-patterns/DESIGN.md`
   - Verification: `test -f .planning/phases/30-research-gsd-new-project-patterns/DESIGN.md`

2. Document catalogs every step of `/gsd:new-project` in order: Setup, Brownfield Offer, Deep Questioning, Write PROJECT.md, Workflow Preferences, Research Decision, Define Requirements, Create Roadmap, Done
   - Verification: `grep -c "## Step" .planning/phases/30-research-gsd-new-project-patterns/DESIGN.md` returns >= 9

3. Document includes the questions asked at each step, the decision points, and the artifacts created
   - Verification: `grep -c "Questions\|Decision\|Artifacts\|AskUserQuestion" .planning/phases/30-research-gsd-new-project-patterns/DESIGN.md` returns >= 10

4. Document identifies which patterns are applicable to phase creation vs. project-level-only
   - Verification: `grep -c "Applicable\|Not Applicable\|Phase Creation\|Project-Level Only" .planning/phases/30-research-gsd-new-project-patterns/DESIGN.md` returns >= 5

5. Document includes concrete specification for phases 31-34 covering Smart Input Parsing, Rich Spec Generation, Codebase-Aware Positioning, and Deep Context Gathering
   - Verification: `grep -c "Phase 3[1-4]" .planning/phases/30-research-gsd-new-project-patterns/DESIGN.md` returns >= 4

6. Document includes output quality characteristics
   - Verification: `grep -c "Quality" .planning/phases/30-research-gsd-new-project-patterns/DESIGN.md` returns >= 3

7. No source code files modified
   - Verification: `git diff --name-only dbe4635 | grep "^src/" | wc -l` returns 0

**Estimated complexity:** Medium (research and synthesis, no code)
**Files to create:** `.planning/phases/30-research-gsd-new-project-patterns/DESIGN.md`
**Files to modify:** None
