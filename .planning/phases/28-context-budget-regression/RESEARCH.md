# Phase 28: Context Budget Regression Investigation -- RESEARCH

**Status:** Investigation complete. Findings ready for user discussion.
**Constraint:** NO code changes. Investigation only. Fixes require user review first.

---

## Executive Summary

The v1.8.0 wave (Phases 17-26) grew the **Tier 2 (phase-runner) prompt load by 55%** and the **Tier 1 (orchestrator) prompt load by 20%**. The total protocol text went from ~241KB to ~408KB across all src/ files (+69%). However, the context regression is **not uniformly distributed** -- three phases account for 52% of the growth in the core files, and the phase-runner's context window is the primary bottleneck (not the orchestrator's).

### Key Numbers

| Metric | v1.7.0 (Pre-Phase 17) | Current (v1.8.7) | Growth |
|--------|----------------------|-------------------|--------|
| Tier 1 prompt load (command + orchestrator) | ~29K tokens | ~35K tokens | +20% |
| Tier 2 prompt load (agent def + playbook + return contract) | ~25K tokens | ~38K tokens | **+55%** |
| Core protocol files (3 files) | 219,350 bytes | 307,171 bytes | +40% |
| Total src/ text (all files) | 241,447 bytes | 407,971 bytes | +69% |
| File count in src/ | 6 | 16 | +10 new files |
| Schemas file (developer reference) | 56,536 bytes | 81,789 bytes | +45% |

---

## 1. Per-Phase Contribution to Core File Bloat

Net lines added to the 3 core protocol files + phase-runner agent definition, ranked by impact:

| Rank | Phase | Feature | NET Lines Added | % of Total Growth |
|------|-------|---------|----------------|-------------------|
| 1 | **Phase 22** | Visual Testing | +271 lines | **19.5%** |
| 2 | **Phase 24** | Progress Streaming | +186 lines | **13.4%** |
| 3 | **Phase 20** | Per-Task Verification (PVRF-01) | +170 lines | **12.2%** |
| 4 | **Phase 17** | Sandbox Execution | +155 lines | 11.1% |
| 5 | **Phase 19** | Semantic Repo Map | +145 lines | 10.4% |
| 6 | **Phase 23** | Debug System | +135 lines | 9.7% |
| 7 | **Phase 26** | QoL Polish (discuss redesign) | +115 lines | 8.3% |
| 8 | **Phase 21** | Human Deferral Elimination | +78 lines | 5.6% |
| 9 | **Phase 18** | Test-Driven Criteria | +35 lines | 2.5% |
| 10 | **Phase 25** | Native CLI Commands | +0 lines | 0% (new files only) |

**Top 3 account for 45% of all growth (627 of ~1,390 net lines).**

### Where the lines landed (per-file growth from v1.7.0):

| File | v1.7.0 | Current | Growth | Growth % |
|------|--------|---------|--------|----------|
| autopilot-playbook.md | 1,345 lines / 72,674 bytes | 1,856 lines / 115,996 bytes | +511 lines / +43,322 bytes | **+60%** |
| autopilot-orchestrator.md | 1,405 lines / 90,140 bytes | 1,719 lines / 109,386 bytes | +314 lines / +19,246 bytes | +21% |
| autopilot-schemas.md | 1,308 lines / 56,536 bytes | 1,891 lines / 81,789 bytes | +583 lines / +25,253 bytes | +45% |
| autopilot-phase-runner.md | 153 lines / 10,525 bytes | 204 lines / 15,351 bytes | +51 lines / +4,826 bytes | +46% |

**The playbook is the #1 growth area** -- it grew 60% and is the file that gets loaded into every phase-runner's context window (~33K tokens).

---

## 2. Context Loading Chain Analysis

Understanding WHAT gets loaded WHERE is critical. Not all file growth equally impacts context consumption.

### Tier 1: Orchestrator Context Window

When the user types `/autopilot <phases>`:
1. `src/commands/autopilot.md` is auto-loaded as the command definition (~3.8K tokens)
2. Orchestrator reads `src/protocols/autopilot-orchestrator.md` in full (~31K tokens)
3. Orchestrator reads `.planning/ROADMAP.md` (project-specific, varies)
4. Orchestrator reads `.autopilot/state.json` (runtime, varies)
5. Orchestrator receives phase-runner JSON returns (~80-125 lines per phase)

**Total Tier 1 base cost: ~35K tokens** before any phase execution begins.
**Per-phase marginal cost: ~100-300 tokens** (JSON returns only, thanks to manager-not-worker principle from Phase 16).

**Assessment: Tier 1 is NOT the bottleneck.** The 20% growth is manageable because the orchestrator correctly delegates all heavy work to sub-agents. The Phase 16 "manager-not-worker" design is working as intended.

### Tier 2: Phase-Runner Context Window (THE BOTTLENECK)

When the orchestrator spawns a phase-runner:
1. `src/agents/autopilot-phase-runner.md` is auto-loaded as agent definition (~4.4K tokens)
2. Phase-runner reads `src/protocols/autopilot-playbook.md` in full (~33K tokens)
3. Phase-runner reads a section of `src/protocols/autopilot-orchestrator.md` for the return contract (~0.9K tokens)
4. Phase-runner reads the frozen spec (project-specific, varies)
5. Phase-runner spawns 7-12 step agents, each consuming context for spawn prompts and JSON returns

**Total Tier 2 base cost: ~38K tokens** before any step agents are spawned.
**Per-step-agent marginal cost:** 5-15 lines of JSON ingested per step agent return.

**The playbook at 33K tokens is the single largest context consumer in the system.** Every phase-runner reads the entire file, but most of its content is irrelevant to any single phase:
- Visual testing (118 lines) is only relevant for UI phases with visual testing enabled
- Debug protocol (121 lines) is only relevant when a failure occurs (~20% of phases)
- Per-task execution loop details (95 lines) could be summarized
- Behavioral trace protocol (75 lines) is only relevant for UI phases
- Discuss mode output format (20 lines) is only relevant when --discuss was used

### Tier 3: Step Agent Context Windows

Step agents (researcher, planner, executor, verifier, judge, rating agent) each have their own context windows. They receive:
- A spawn prompt from the phase-runner (varies, 50-200 lines typically)
- They do NOT read the playbook or orchestrator files (good -- clean separation)
- The debugger agent (`autopilot-debugger.md`) has its own 20KB agent definition

**Assessment: Tier 3 is generally well-contained.** Each step agent gets a focused prompt. The exception is the debugger at 20KB -- but it only spawns on failures.

### New Files (Not Loaded During /autopilot Runs)

10 new files were added (debug command, map, progress, update, add-phase, insert-phase, remove-phase, help, debugger agent, update-check-banner). These total ~72K bytes but are only loaded when their specific command is invoked. **They do NOT contribute to /autopilot run context consumption.**

---

## 3. Redundancy Analysis

### Cross-File Redundancy (Same Concept Repeated Across Files)

| Concept | Occurrences | Files | Tokens Wasted |
|---------|-------------|-------|---------------|
| "alignment_score uses decimal x.x format" | **30+** mentions | All 4 core files | ~300 tokens |
| PVRF-01 per-task verification protocol | 40 mentions | 3 files (phase-runner, playbook, schemas) | ~200 tokens |
| Blind verification (VRFY-01) rules | 12 mentions | 3 files | ~150 tokens |
| Autonomous confidence / deferral evidence | 27 mentions | 4 files | ~250 tokens |
| Rubber-stamp detection | 17 mentions | 2 files | ~150 tokens |
| Rating agent isolation rules | 8 mentions | 3 files | ~100 tokens |
| Pipeline step sequence | 5 mentions | 3 files | ~100 tokens |

**Estimated redundancy overhead: ~1,250 tokens across all files.** This is actually relatively small (~3% of total load) because the redundancy is mostly brief reminders, not copy-pasted sections.

### Intra-File Redundancy (Within a Single File)

The **playbook** has the most internal redundancy:
- The verification methodology (Section 2, Step 4) is 170+ lines of detailed protocol that repeats concepts from the verifier spawn prompt
- The judge section repeats "independent" and "divergence" concepts multiple times
- Progress streaming format is described in both the agent definition AND the playbook

### Phase-Runner Agent Definition vs. Playbook Overlap

The phase-runner agent definition (204 lines) has **moderate** overlap with the playbook:
- Pipeline structure: defined in both (agent definition: concise, playbook: detailed)
- Per-task verification: referenced in both (agent definition: 13 lines, playbook: 95 lines)
- Progress streaming: described in both (agent definition: 27 lines, playbook: 56 lines)
- Quality mindset: agent definition has 20 lines that duplicate playbook concepts

**Estimated overlap: ~60 lines (~1,700 tokens) of agent definition content that is also in the playbook.** Since both are loaded into the same context window (Tier 2), this is true waste.

---

## 4. Top 3 Largest Contributors to Context Bloat

### #1: Visual Testing Protocol (Phase 22) -- 271 net lines across core files

**Where it lives:**
- Playbook: 118 lines (visual testing step, regression loop, quality assessment)
- Schemas: 131 lines (configuration schema, screenshot schema, bug report schema, verifier results)
- Orchestrator: 9 lines (config validation, --visual flag handling)

**Why it's bloated:**
- 65 lines of detailed Playwright screenshot capture instructions (bash commands, cleanup, error handling)
- 53 lines of visual regression loop protocol
- Full bug report schema and resolution tracking
- All of this loads into EVERY phase-runner, even for non-UI phases that will never use visual testing

**Impact:** ~750 tokens loaded into every phase-runner context for a feature that's used <10% of the time.

### #2: Progress Streaming Protocol (Phase 24) -- 186 net lines across core files

**Where it lives:**
- Phase-runner agent definition: 27 lines (full progress streaming section)
- Playbook: 56+ lines distributed (step-level progress, task-level progress, format rules)
- Orchestrator: 69 lines (3-tier progress architecture, captured output, progress buffering)

**Why it's bloated:**
- Progress format is defined in 3 places (agent definition, playbook, orchestrator)
- Detailed format specifications with example progressions in multiple locations
- The orchestrator's progress architecture section (61 lines, Tiers 1-3) could be drastically simplified

**Impact:** ~530 tokens of redundant progress format definitions across files.

### #3: Per-Task Verification (Phase 20, PVRF-01) -- 170 net lines across core files

**Where it lives:**
- Playbook: 111 lines (full per-task execution loop, mini-verifier prompt, failure handling, budget)
- Schemas: 44 lines (mini-verifier return schema, EXECUTION-LOG extension)
- Phase-runner agent definition: 20 lines (PVRF-01 summary, mini-verifier budget)

**Why it's bloated:**
- Full mini-verifier prompt template (36 lines) is inline in the playbook
- Detailed failure handling protocol (27 lines) with debug escalation
- Context budget calculations (8 lines) that duplicate the budget table
- The agent definition repeats the concept despite playbook being the authority

**Impact:** ~490 tokens, with ~20 lines of true redundancy between agent definition and playbook.

---

## 5. Schemas File: Not a Runtime Context Consumer

The schemas file grew from 56K to 82K bytes (+45%), adding:
- Section 13: Sandbox Execution Schemas (94 lines, Phase 17)
- Section 14: Repository Map Schema (109 lines, Phase 19)
- Section 15: Debug Session Schema (133 lines, Phase 23)
- Section 16: Visual Testing Schemas (131 lines, Phase 22)
- Phase 20: Mini-Verifier schemas (42 lines within Section 5)

**However, the schemas file is NOT read in full during normal /autopilot runs.** It is a developer reference document. Agents reference specific sections by name when needed (e.g., "see schema in autopilot-schemas.md Section 14"). The only agent that reads it is the debugger, and only for the debug session schema.

**Assessment: Schemas file growth is NOT a context regression contributor.** Its growth is appropriate for documentation purposes. No optimization needed here.

---

## 6. Agent Spawn Count Analysis

### Spawn Points in a Typical Phase Run (Happy Path)

| Step | Agent Type | Spawns | Context Cost |
|------|-----------|--------|-------------|
| Pre-flight | general-purpose | 1 | ~5 lines ingested |
| Research | gsd-phase-researcher | 1 | ~10 lines ingested |
| Plan | gsd-planner | 1 | ~10 lines ingested |
| Plan-Check | gsd-plan-checker | 1 | ~5 lines ingested |
| Execute (per task, 3-5 tasks typical) | gsd-executor | 3-5 | ~15 lines ingested |
| Mini-Verify (per task) | general-purpose | 3-5 | ~5 lines per task |
| Verify | gsd-verifier | 1 | ~10 lines ingested |
| Judge | general-purpose | 1 | ~5 lines ingested |
| Rate | general-purpose | 1 | ~5 lines ingested |
| **Total (happy path, 4 tasks)** | | **14** | **~80 lines** |

### Spawn Points Added by v1.8.0 (vs Pre-Phase 17)

- **Phase 20 (PVRF-01):** Added 3-5 mini-verifier spawns per phase (general-purpose agents). This is the biggest new spawn source. Previously, verification was a single phase-level step.
- **Phase 23 (Debug):** Added autopilot-debugger agent type (replaces gsd-debugger). Same spawn count, different agent type with larger definition.
- **Phase 24 (Progress):** No new spawns, but added text processing overhead per step.
- **Phase 19 (Repo Map):** Added 1-2 general-purpose agent spawns for map generation/refresh at orchestrator level.

**Net new spawns per phase: +3-5 (from PVRF-01 mini-verifiers).** This is a significant increase in Tier 2 context consumption because each mini-verifier return must be parsed and processed.

### Orchestrator-Level Spawns (Before Phase Loop)

The orchestrator may also spawn agents for:
- `--map` mode: 1 questioning agent per underspecified phase
- `--discuss` mode: 1 gray-area analysis agent per target phase
- Repo map generation: 1 general-purpose agent
- Self-audit (completion): 1 general-purpose agent
- `--quality` remediation: re-spawns phase-runner up to 3 times

**These are situational and don't contribute to the baseline regression.**

---

## 7. Externalization Opportunities

Content that could be moved out of the always-loaded playbook/orchestrator into separate files that are read only when needed:

### High-Impact Candidates (Reduce Playbook Size)

| Content | Current Location | Lines | Condition for Use | Savings |
|---------|-----------------|-------|-------------------|---------|
| Visual testing protocol | Playbook lines 948-1012 | 65 | UI phases with visual_testing config only | ~1,860 tokens |
| Visual regression loop | Playbook lines 1116-1168 | 53 | UI phases with visual_testing config only | ~1,510 tokens |
| Behavioral trace protocol | Playbook lines 926-946 | 21 | UI/mixed phases only | ~600 tokens |
| Debug step (STEP 5a) | Playbook lines 1548-1668 | 121 | Only on verification failure | ~3,460 tokens |
| Discuss mode output format | Orchestrator lines 570-611 | 42 | Only with --discuss flag | ~1,200 tokens |
| Partial progress state example | Playbook lines 1750-1809 | 60 | Only on context exhaustion | ~1,710 tokens |

**Total potential savings from externalization: ~10,340 tokens (~27% of playbook load).**

### Medium-Impact Candidates (Reduce Agent Definition Overlap)

| Content | Current Location | Lines | Action |
|---------|-----------------|-------|--------|
| Progress streaming section | Phase-runner agent def lines 105-131 | 27 | Remove from agent def, keep only in playbook |
| PVRF-01 detailed description | Phase-runner agent def lines 166-178 | 13 | Condense to 3-line reference to playbook |
| Spawning step agents details | Phase-runner agent def lines 153-194 | 42 | Condense, point to playbook for details |

**Total potential savings from deduplication: ~2,300 tokens (~6% of Tier 2 load).**

### Low-Impact Candidates (Orchestrator Sections)

| Content | Current Location | Lines | Condition |
|---------|-----------------|-------|-----------|
| --map mode (context mapping) | Orchestrator lines 81-232 | 152 | Only with --map flag |
| --gaps mode | Orchestrator lines 355-449 | 95 | Only with --gaps flag |
| --discuss mode | Orchestrator lines 450-583 | 134 | Only with --discuss flag |

These are in the orchestrator (Tier 1), which is less constrained. Moving them out would save ~10K tokens from the orchestrator but adds complexity.

---

## 8. Root Cause Summary

The context exhaustion regression has **three root causes**:

### Root Cause 1: Playbook Monolith (Primary)
The playbook grew from 73KB to 116KB (+60%) and is loaded in full by every phase-runner. It contains detailed protocols for every possible scenario (visual testing, behavioral traces, debug loops, discuss output, partial progress) even though any given phase only uses a subset. This is the single largest context consumer in the system.

### Root Cause 2: Per-Task Verification Overhead (Phase 20)
PVRF-01 added 3-5 mini-verifier spawns per phase. Each spawn adds context for the spawn prompt, the agent's response, and the JSON parsing. While individually small (~5 lines per mini-verifier), the cumulative effect on a 5-task phase is ~25 lines of additional context, plus the 95 lines of PVRF-01 protocol in the playbook.

### Root Cause 3: Cross-File Redundancy (Secondary)
The same concepts (decimal scoring, blind verification, autonomous confidence, rating agent isolation) are repeated across the orchestrator, playbook, phase-runner definition, and schemas. While each repetition is small, they collectively add ~1,250 tokens of redundancy that compounds across tiers.

### What is NOT a Root Cause

- **New command files** (debug, map, progress, etc.) -- these don't load during /autopilot runs
- **Schemas file growth** -- it's not routinely read in full at runtime
- **Orchestrator growth** -- it's well-controlled at +20% and delegates correctly
- **Agent spawn count** -- the per-step context budget system works, spawn count is manageable

---

## 9. Proposed Fix Strategies (For Discussion)

### Strategy A: Playbook Modularization (Highest Impact)

Split the playbook into a core file + conditional modules:
- `autopilot-playbook.md` (core: ~1,200 lines, always loaded)
- `autopilot-playbook-visual.md` (visual testing: ~120 lines, loaded only for UI phases with visual config)
- `autopilot-playbook-debug.md` (debug protocol: ~120 lines, loaded only on failure)

**Estimated savings:** ~7,000 tokens per non-UI phase-runner (~18% reduction)
**Risk:** Adds file management complexity; phase-runner must conditionally read extra files
**Trade-off:** More files to maintain vs. smaller context per run

### Strategy B: Aggressive Deduplication (Medium Impact)

Eliminate redundant content across files:
- Remove progress streaming section from agent definition (keep only in playbook)
- Consolidate PVRF-01 description to playbook only; agent definition gets a 2-line reference
- Deduplicate "decimal x.x format" to a single definition point
- Condense spawning instructions in agent definition

**Estimated savings:** ~2,300 tokens per phase-runner (~6% reduction)
**Risk:** Low -- removing true redundancy doesn't lose information
**Trade-off:** None meaningful; this is pure improvement

### Strategy C: Conditional Protocol Sections (Medium Impact)

Keep the playbook as one file but mark sections as conditional:
- `<!-- IF visual_testing -->` ... `<!-- ENDIF -->` markers
- Phase-runner skips sections based on phase type and flags

**Estimated savings:** Similar to Strategy A but without new files
**Risk:** Relies on phase-runner parsing markdown conditionals correctly
**Trade-off:** Simpler file management but novel parsing requirement

### Strategy D: Orchestrator Flag Externalization (Lower Impact, Tier 1)

Move rarely-used flag sections (--map, --gaps, --discuss) to separate protocol files:
- `autopilot-orchestrator-map.md` (152 lines)
- `autopilot-orchestrator-gaps.md` (95 lines)
- `autopilot-orchestrator-discuss.md` (134 lines)

**Estimated savings:** ~10K tokens from orchestrator (but Tier 1 isn't the bottleneck)
**Risk:** Adds complexity; orchestrator must conditionally read based on flags
**Trade-off:** Marginal improvement where it's least needed

### Recommended Approach

**Strategy B first (easy wins, no architectural change), then Strategy A (if further reduction needed).**

Strategy B is low-risk, pure improvement. Strategy A requires more discussion about file management trade-offs. Strategies C and D are less favorable due to added complexity.

---

## 10. Open Questions for User Discussion

1. **Is the Tier 2 (phase-runner) context consumption the primary problem you're experiencing?** The data shows the orchestrator is well-controlled but the phase-runner has grown significantly.

2. **How often do you use visual testing (--visual)?** If rarely, the 118 lines of visual testing protocol in the playbook are pure waste for most runs.

3. **Are you seeing context exhaustion in specific scenarios (e.g., large phases, remediation loops, --quality runs)?** This would help prioritize which strategy to pursue.

4. **Would you accept a multi-file playbook architecture (Strategy A)?** It's the highest-impact fix but adds file management overhead.

5. **Is the per-task verification (PVRF-01) overhead worth it?** It adds 3-5 spawns per phase but catches failures earlier. If it's rarely catching issues, the batch fallback (single verification at end) could be the default.

---

## SUMMARY

The context regression is real and measurable: Tier 2 prompt load grew 55% (+13K tokens per phase-runner). The primary cause is the playbook monolith absorbing detailed protocols for every feature added in Phases 17-26. The top 3 contributors (visual testing +271 lines, progress streaming +186 lines, per-task verification +170 lines) account for 45% of all growth. The fix path starts with deduplication (Strategy B, ~6% reduction, zero risk) and can escalate to playbook modularization (Strategy A, ~18% reduction, moderate complexity) if needed.
