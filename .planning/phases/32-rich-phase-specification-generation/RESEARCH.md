# Research: Phase 32 -- Rich Phase Specification Generation

## Key Findings

1. **Current add-phase.md produces stubs:** The Phase 31 implementation in `src/commands/autopilot/add-phase.md` creates phases with `[To be planned]` Goal, `[To be defined]` criteria, and `Phase {N-1} (independent)` dependencies. Lines 123-133 define the stub template used for both single-phase and batch creation.

2. **DESIGN.md blueprint (Phase 30) specifies exact behavior for Phase 32:** Part 4, section "Phase 32" (lines 477-529) defines:
   - Goal Generation: min 2-3 sentences, goal-backward framing, references existing patterns
   - Success Criteria Generation: 3-5 per phase, specific/testable, "[Observable outcome] -- [how to verify]" pattern, at least one machine-verifiable
   - Dependency Analysis: Read existing roadmap, explain WHY, not just list numbers
   - Preliminary Task Breakdown: 2-5 high-level tasks, verb-phrases describing deliverables
   - Requirements Section: Reference existing REQ-IDs or suggest new ones

3. **Two integration points in add-phase.md:** The spec generation must be added:
   - In Step 3 (Single-Phase Fast Path), substep 7 -- where the phase detail section template is emitted (lines 118-133)
   - In Step 5 (Batch Phase Creation), substep 4e -- the batch equivalent (lines 226-232)

4. **Quality examples exist in ROADMAP.md:** Phases 2.1, 3.1, 4.1 demonstrate the quality bar:
   - Multi-sentence Goals that describe WHAT and WHY
   - Specific success criteria with observable outcomes
   - Dependency rationale (e.g., "Phase 2 (executor must have per-task commits and self-testing before integration checks layer on top)")
   - Evidence sections explaining why the phase exists

5. **The add-phase command is a .md prompt file, not code:** All changes are to the Claude command definition at `src/commands/autopilot/add-phase.md`. The "implementation" is instructional text telling Claude how to generate spec content.

## Recommended Approach

Replace the stub template in add-phase.md Steps 3.7 and 5.4e with detailed spec generation instructions. Add a new section (between current Steps 2 and 3) that defines the spec generation methodology: reading the roadmap for context, generating goal-backward criteria, analyzing dependencies against existing phases, and creating preliminary task breakdowns. The instructions should be detailed enough that Claude produces rich specs automatically without user prompting.

## Risks

1. **Instruction size:** Adding rich generation logic could significantly expand the add-phase.md file, potentially causing context issues when the command is invoked
2. **Quality consistency:** Claude's generation quality may vary -- the instructions need to be specific enough to consistently produce good output, not just occasionally

## Open Questions

1. Should the spec generation include the "Evidence (why this phase exists)" section seen in 2.1, 3.1, 4.1, or is that only for inserted phases?
