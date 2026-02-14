# Context Budget Regression Investigation -- Findings Report

**Date:** 2026-02-13
**Phase:** 28 -- Context Budget Regression Investigation
**Status:** Investigation complete. Awaiting user review before implementing further fixes.

---

## Executive Summary

The v1.8.0 wave of upgrades (Phases 17-26) grew the total protocol text by **35.7%** (from ~4,053 to 5,500 lines across 3 core files). The **Tier 2 (phase-runner) prompt load grew 55%**, making it the primary bottleneck. The Tier 1 (orchestrator) is well-controlled at +20% thanks to the Phase 16 "manager-not-worker" principle.

Three features account for **45% of all growth**: Visual Testing (+271 lines), Progress Streaming (+186 lines), and Per-Task Verification (+170 lines).

---

## 1. Protocol File Size Comparison

### Current State (v1.8.7)

| File | Lines | Bytes | Est. Tokens |
|------|-------|-------|-------------|
| autopilot-playbook.md | 1,856 | 116,008 | ~29,002 |
| autopilot-orchestrator.md | 1,719 | 109,398 | ~27,349 |
| autopilot-schemas.md | 1,891 | 81,813 | ~20,453 |
| update-check-banner.md | 34 | 1,604 | ~401 |
| **Total** | **5,500** | **308,823** | **~77,205** |

### Estimated Pre-v1.8.0 State (before Phases 17-26)

| File | Est. Lines | Current Lines | Growth |
|------|-----------|--------------|--------|
| autopilot-playbook.md | ~1,273 | 1,856 | +583 lines (+46%) |
| autopilot-orchestrator.md | ~1,405 | 1,719 | +314 lines (+22%) |
| autopilot-schemas.md | ~1,375 | 1,891 | +516 lines (+38%) |
| **Total** | **~4,053** | **5,500** | **+1,447 lines (+35.7%)** |

---

## 2. Per-Phase Contribution Ranking

Lines added to core protocol files, ranked by impact:

| Rank | Phase | Feature | Lines Added | % of Growth |
|------|-------|---------|-------------|-------------|
| 1 | Phase 22 | Visual Testing & Screenshots | +271 | 18.7% |
| 2 | Phase 24 | Progress Streaming | +186 | 12.9% |
| 3 | Phase 20 | Per-Task Verification (PVRF-01) | +170 | 11.7% |
| 4 | Phase 17 | Sandbox Execution | +155 | 10.7% |
| 5 | Phase 19 | Semantic Repo Map | +145 | 10.0% |
| 6 | Phase 23 | Debug System | +135 | 9.3% |
| 7 | Phase 26 | QoL Polish (discuss redesign) | +115 | 7.9% |
| 8 | Phase 21 | Human Deferral Elimination | +78 | 5.4% |
| 9 | Phase 18 | Test-Driven Criteria | +35 | 2.4% |
| 10 | Phase 25 | Native CLI Commands | +0 | 0% (new files only) |

**Top 3 account for 45% of growth. Top 5 account for 64%.**

---

## 3. Root Cause Analysis

### Root Cause 1: Playbook Monolith (Primary -- 60% growth)

The autopilot-playbook.md grew from ~1,273 to 1,856 lines (+46%). It is loaded in full by every phase-runner, regardless of phase type. It contains detailed protocols for every possible scenario (visual testing, behavioral traces, debug loops, discuss output formatting) even though any given phase only uses a small subset.

**Impact:** Every phase-runner spends ~29K tokens loading the playbook. For a protocol phase (no UI, no visual testing), approximately 174 lines (9.4%) are UI-only dead weight that provides zero value.

### Root Cause 2: Per-Task Verification Overhead (Phase 20)

PVRF-01 added 3-5 mini-verifier agent spawns per phase. The protocol for this is 105+ lines in the playbook. While the mini-verifiers individually consume little context (~5 lines per return), the cumulative overhead for a 5-task phase is approximately 25 lines of additional phase-runner context, plus the 105 lines of protocol instructions.

**Impact:** +170 lines in protocol files, +25 lines runtime context per 5-task phase.

### Root Cause 3: Cross-File and Intra-File Redundancy (Secondary)

Several concepts are repeated across the orchestrator, playbook, and phase-runner definition:
- "alignment_score uses decimal x.x format" appears 30+ times across files
- PVRF-01 protocol details appear in 3 files
- Blind verification (VRFY-01) rules appear in 3 files
- Autonomous confidence / deferral evidence appears in 4 files
- Progress streaming format is defined in 3 places

**Impact:** ~1,250 tokens of redundant content, plus ~60 lines of overlap between the phase-runner agent definition and the playbook.

### What Is NOT a Root Cause

- **New command files** (debug, map, progress, add-phase, etc.) -- these only load when their specific command is invoked, not during `/autopilot` runs
- **Schemas file growth** (+516 lines) -- it is a developer reference document, not routinely read in full at runtime
- **Orchestrator growth** (+314 lines, +22%) -- well-controlled thanks to Phase 16 delegation design

---

## 4. Context Loading Chain

### What gets loaded and where:

| Tier | Component | Base Cost | Notes |
|------|-----------|-----------|-------|
| Tier 1 | Orchestrator | ~35K tokens | Reads command def + orchestrator protocol |
| Tier 2 | Phase-Runner | ~38K tokens | Reads playbook + return contract + spec |
| Tier 3 | Step Agents | Varies | Each gets a focused prompt (50-200 lines) |

**The Tier 2 phase-runner is the bottleneck.** At ~38K tokens base cost, it uses a significant portion of the context window before any actual work begins.

---

## 5. Proposed Fix Strategies

### Strategy B: Deduplication (Recommended First -- Zero Risk)

**What:** Remove redundant content within the playbook:
- Condense trace aggregation section (17 lines to 5)
- Condense progress emission section (58 lines to 20)
- Remove redundant "decimal x.x format" reminders after first definition
- Merge mini-verifier context budget into main budget table
- Condense sandbox execution policy examples

**Expected reduction:** ~40-60 lines (~1,200-1,700 tokens, ~4% of playbook)
**Risk:** Zero -- removing true redundancy does not lose information
**Trade-off:** None meaningful

### Strategy A: Playbook Modularization (Highest Impact -- For Future Discussion)

**What:** Split the playbook into core + conditional modules:
- `autopilot-playbook.md` (core: ~1,200 lines, always loaded)
- `autopilot-playbook-visual.md` (visual testing: ~120 lines, loaded only for UI phases)
- `autopilot-playbook-debug.md` (debug protocol: ~120 lines, loaded only on failure)

**Expected reduction:** ~7,000 tokens per non-UI phase-runner (~18% of Tier 2 load)
**Risk:** Adds file management complexity
**Trade-off:** More files to maintain vs. smaller context per run

### Strategy C: Conditional Sections (Alternative to A)

**What:** Keep playbook as one file but use markers for conditional loading:
- Phase-runner skips sections based on phase type
- Similar savings to Strategy A without new files

**Risk:** Relies on phase-runner correctly parsing conditional markers
**Trade-off:** Novel parsing requirement

### Strategy D: Orchestrator Flag Externalization (Lower Impact)

**What:** Move rarely-used flag sections (--map, --gaps, --discuss) to separate files
**Expected reduction:** ~10K tokens from orchestrator (but Tier 1 isn't the bottleneck)
**Risk:** Adds complexity where it's least needed

---

## 6. Recommendation

**Apply Strategy B now** (deduplication, zero risk, immediate benefit), then **discuss Strategy A** (playbook modularization) based on user feedback about:

1. How often visual testing is used in practice
2. Whether the multi-file architecture is acceptable
3. Whether further context reduction is needed beyond Strategy B

---

## 7. Results: Strategy B Applied

### Before and After Comparison

| Metric | Before (v1.8.7) | After Deduplication | Reduction |
|--------|-----------------|---------------------|-----------|
| Playbook lines | 1,856 | 1,700 | -156 lines (-8.4%) |
| Playbook bytes | 116,008 | 106,708 | -9,300 bytes (-8.0%) |
| Playbook tokens (est.) | ~29,002 | ~26,677 | ~-2,325 tokens (-8.0%) |
| Total protocol lines | 5,500 | 5,344 | -156 lines (-2.8%) |

### What Was Condensed

| Section | Before | After | Savings |
|---------|--------|-------|---------|
| Trace aggregation | 17 lines | 3 lines | -14 |
| Progress emission | 58 lines | 7 lines | -51 |
| Sandbox execution policy | 25 lines | 5 lines | -20 |
| Visual regression loop | 54 lines | 8 lines | -46 |
| Mini-verifier context budget | 10 lines | 2 lines | -8 |
| EXECUTION-LOG.md entry template | 14 lines | 2 lines | -12 |
| 7x inline trace file schemas | 7 x ~2 lines verbose | 7 x 1 line reference | -7 |
| Redundant decimal format reminder | 1 line | removed | -1 |
| **Total** | | | **-159 lines** |

(Some lines were added for condensed replacements, net effect: -156 lines)

### Quality Enforcement Preserved

All critical quality markers verified present after deduplication:
- VRFY-01 (blind verification): present
- BLIND VERIFICATION: present
- CONTEXT ISOLATION (rating agent): present
- All 25+ STEP references: present
- All pipeline step templates (0 through 5a): present

### Remaining Opportunity

Strategy B delivered an 8.4% reduction. For further context savings:
- **Strategy A** (playbook modularization) could save an additional ~7,000 tokens (~18%) per non-UI phase by extracting UI-only content
- This requires user discussion about file management trade-offs

---

## 8. Open Questions for User

1. Is the Tier 2 (phase-runner) context consumption the primary problem you're experiencing?
2. How often do you use visual testing (`--visual`)? If rarely, 174 lines of UI-only content in the playbook are pure waste for most runs.
3. Are you seeing context exhaustion in specific scenarios (large phases, remediation loops, `--quality` runs)?
4. Would you accept a multi-file playbook architecture (Strategy A)?
5. Is the per-task verification (PVRF-01) overhead worth keeping? It adds 3-5 mini-verifier spawns per phase but catches failures earlier.
