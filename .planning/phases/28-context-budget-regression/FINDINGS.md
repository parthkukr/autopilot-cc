# Context Budget Regression Investigation -- Findings Report

**Date:** 2026-02-14
**Phase:** 28 -- Context Budget Regression Investigation
**Status:** Investigation complete. Strategy B (deduplication) applied. Awaiting user review for further fixes.

---

## Executive Summary

The v1.8.0 wave of upgrades (Phases 17-26) grew the total protocol text by **33.2%** (from 4,102 to 5,466 lines across 3 core files, measured from git history). The **Tier 2 (phase-runner) prompt load grew 34.5%** in the playbook alone, making it the primary bottleneck. The Tier 1 (orchestrator) is well-controlled at +21.6% thanks to the Phase 16 "manager-not-worker" principle.

Three features account for **48.0% of all growth**: Visual Testing (+271 lines), Per-Task Verification (+153 lines), and Progress Streaming (+158 lines).

Strategy B (playbook deduplication) has been applied, reducing the playbook from 1,856 to 1,700 lines (-8.4%). All quality enforcement markers are preserved.

---

## 1. Protocol File Size Comparison (Measured from Git History)

All baselines are measured using `git show` at commit `dd606b1` (v1.7.1, the last release before the v1.8.0 wave). Current values are from HEAD after Phase 28 deduplication. Pre-deduplication values are from commit `ac097ce` (after Phase 28 task 28-01, before deduplication).

### v1.7.x vs v1.8.x Comparison Table

| File | v1.7.1 Lines | v1.7.1 Bytes | v1.8.7 Lines (pre-dedup) | v1.8.7 Bytes (pre-dedup) | Growth (lines) | Growth (%) |
|------|-------------|-------------|-------------------------|-------------------------|---------------|-----------|
| autopilot-playbook.md | 1,380 | 78,639 | 1,856 | 115,996 | +476 | +34.5% |
| autopilot-orchestrator.md | 1,414 | 91,448 | 1,719 | 109,398 | +305 | +21.6% |
| autopilot-schemas.md | 1,308 | 56,536 | 1,891 | 81,813 | +583 | +44.6% |
| **Total** | **4,102** | **226,623** | **5,466** | **307,207** | **+1,364** | **+33.2%** |

**Measurement method:** `git show dd606b1:src/protocols/{file} | wc -l` for v1.7.1 baselines; `git show ac097ce:src/protocols/{file} | wc -l` for v1.8.7 pre-deduplication values.

### Post-Deduplication State (current HEAD)

| File | Current Lines | Current Bytes | Est. Tokens | Change from v1.8.7 pre-dedup |
|------|-------------|-------------|-------------|------------------------------|
| autopilot-playbook.md | 1,700 | 106,708 | ~26,677 | -156 lines (-8.4%) |
| autopilot-orchestrator.md | 1,719 | 109,398 | ~27,349 | 0 (unchanged) |
| autopilot-schemas.md | 1,891 | 81,813 | ~20,453 | 0 (unchanged) |
| **Total** | **5,310** | **297,919** | **~74,479** | **-156 lines (-2.9%)** |

---

## 2. Per-Phase Contribution Ranking (Measured from Git History)

Each row shows the total lines added across all 3 protocol files by that phase, measured by comparing `git show` at sequential phase-end commits.

| Rank | Phase | Feature | Playbook | Orchestrator | Schemas | Total Added | % of Growth |
|------|-------|---------|----------|-------------|---------|-------------|-------------|
| 1 | Phase 22 | Visual Testing & Screenshots | +130 | +9 | +132 | +271 | 19.9% |
| 2 | Phase 20 | Per-Task Verification (PVRF-01) | +109 | 0 | +44 | +153 | 11.2% |
| 3 | Phase 24 | Progress Streaming | +95 | +63 | 0 | +158 | 11.6% |
| 4 | Phase 17 | Sandbox Execution | +59 | +2 | +96 | +157 | 11.5% |
| 5 | Phase 19 | Semantic Repo Map | +3 | +29 | +111 | +143 | 10.5% |
| 6 | Phase 23 | Debug System | 0 | 0 | +135 | +135 | 9.9% |
| 7 | Phase 26 | QoL Polish (discuss redesign) | 0 | +115 | 0 | +115 | 8.4% |
| 8 | Phase 21 | Human Deferral Elimination | +35 | +36 | +5 | +76 | 5.6% |
| 9 | Phase 18 | Test-Driven Criteria | +35 | 0 | 0 | +35 | 2.6% |
| 10 | Phase 25 | Native CLI Commands | 0 | 0 | 0 | 0 | 0% |
| | **Total** | | **+466** | **+254** | **+523** | **+1,243** | |

**Measurement method:** For each phase, the playbook/orchestrator/schemas line count was measured at the last commit of the previous phase and the last commit of the current phase using `git show {sha}:src/protocols/{file} | wc -l`. The difference gives the exact contribution.

**Note:** The per-phase sum (+1,243) is less than the total v1.7.1-to-v1.8.7 growth (+1,364) because some growth occurred in integration fix commits, version bump commits, and Phase 26.x sub-phases (26.1, 26.2, 26.4) that shipped between v1.8.0 and v1.8.7.

**Top 3 account for 42.7% of growth. Top 5 account for 64.7%.**

---

## 3. Root Cause Analysis

### Root Cause 1: Playbook Monolith (Primary -- 35% of total growth)

The autopilot-playbook.md grew from 1,380 to 1,856 lines (+476, +34.5%, measured via git). It is loaded in full by every phase-runner, regardless of phase type. It contains detailed protocols for every possible scenario (visual testing, behavioral traces, debug loops, discuss output formatting) even though any given phase only uses a small subset.

**Impact:** Every phase-runner spends ~26.7K tokens loading the playbook (post-deduplication). For a protocol phase (no UI, no visual testing), approximately 174 lines (10.2%) are UI-only content that provides zero value.

### Root Cause 2: Per-Task Verification Overhead (Phase 20)

PVRF-01 added 3-5 mini-verifier agent spawns per phase. The protocol for this is 105+ lines in the playbook (within the 191-line STEP 3 Execute section). While the mini-verifiers individually consume little context (~5 lines per return), the cumulative overhead for a 5-task phase is approximately 25 lines of additional phase-runner context, plus the 105 lines of protocol instructions.

**Impact:** +153 lines in protocol files (measured), +25 lines runtime context per 5-task phase.

### Root Cause 3: Cross-File and Intra-File Redundancy (Secondary)

Several concepts are repeated across the orchestrator, playbook, and phase-runner definition:
- "alignment_score uses decimal x.x format" appears 30+ times across files
- PVRF-01 protocol details appear in 3 files
- Blind verification (VRFY-01) rules appear in 3 files
- Autonomous confidence / deferral evidence appears in 4 files
- Progress streaming format is defined in 3 places

**Impact:** ~1,250 tokens of redundant content, plus ~60 lines of overlap between the phase-runner agent definition (204 lines / 15,351 bytes) and the playbook.

### What Is NOT a Root Cause

- **New command files** (debug, map, progress, add-phase, etc.) -- these only load when their specific command is invoked, not during `/autopilot` runs
- **Schemas file growth** (+583 lines, +44.6%) -- it is a developer reference document, not routinely read in full at runtime
- **Orchestrator growth** (+305 lines, +21.6%) -- well-controlled thanks to Phase 16 delegation design

---

## 4. Per-Agent Context Consumption Analysis

### What gets loaded at each tier

| Tier | Component | File(s) Loaded | Chars | Words | Est. Tokens | Notes |
|------|-----------|---------------|-------|-------|-------------|-------|
| Tier 1 | Orchestrator | autopilot-orchestrator.md | 109,398 | 14,101 | ~27,349 | Loaded once per `/autopilot` run |
| Tier 2 | Phase-Runner (agent def) | autopilot-phase-runner.md | 15,351 | 2,173 | ~3,837 | Injected as system prompt at spawn |
| Tier 2 | Phase-Runner (playbook) | autopilot-playbook.md | 106,708 | 14,513 | ~26,677 | Read by phase-runner at start |
| **Tier 2** | **Phase-Runner TOTAL** | **agent def + playbook** | **122,059** | **16,686** | **~30,514** | **The primary bottleneck** |
| Tier 3 | Debugger | autopilot-debugger.md | 19,926 | 2,796 | ~4,981 | Loaded only on failure |

### Top 3 Highest-Cost Playbook Sections (loaded by every phase-runner)

| Rank | Playbook Section | Lines | % of Playbook | Primary Agents Using It |
|------|-----------------|-------|--------------|------------------------|
| 1 | STEP 4: Verify | 293 | 17.2% | Verifier only |
| 2 | STEP 6: Compose Result | 228 | 13.4% | Phase-runner only |
| 3 | STEP 3: Execute | 191 | 11.2% | Executor only |

**Insight:** The top 3 sections consume 712 lines (41.9% of the playbook). Each section is primarily used by a single agent type. The phase-runner loads ALL of them, but most of the content is prompt templates that get passed to sub-agents.

### Tier 3 Agent Spawn Prompt Sizes (measured from playbook template sections)

**Measurement methodology:** Each prompt size was measured by extracting the exact template section from `autopilot-playbook.md` (the lines between the opening and closing code fence markers for each STEP's prompt template) and computing character count via `wc -c` and line count via `wc -l`. Token estimates use the standard approximation: chars / 4 = approximate tokens. Measurements taken from the post-deduplication playbook at HEAD.

| Agent | Prompt Source (playbook lines) | Measured Lines | Measured Chars | Est. Tokens (chars/4) | Notes |
|-------|-------------------------------|---------------|---------------|----------------------|-------|
| Verifier | STEP 4 template, lines 718-982 | 265 | 17,767 | ~4,441 | Largest Tier 3 prompt; includes methodology, behavioral traces, visual testing, sandbox execution |
| Rating Agent | STEP 4.6 template, lines 1119-1223 | 105 | 8,592 | ~2,148 | Includes calibration guide, anti-inflation rules, behavioral criteria scoring |
| Executor | STEP 3 template, lines 628-691 | 64 | 7,286 | ~1,821 | Base template; add 5 lines / 553 chars / ~138 tokens for per-task incremental mode addition |
| Planner | STEP 2 template, lines 339-412 | 74 | 7,017 | ~1,754 | Includes test generation instructions, behavioral criteria requirements |
| Plan Checker | STEP 2.5 template, lines 437-489 | 53 | 5,318 | ~1,329 | Includes test spec requirements, behavioral criteria check |
| Judge | STEP 4.5 template, lines 1031-1092 | 62 | 4,042 | ~1,010 | Includes divergence protocol, behavioral spot-check requirement |
| Researcher | STEP 1 template, lines 267-313 | 47 | 3,657 | ~914 | Includes repo-map instructions, discuss context, context-map integration |
| Debugger | STEP 5a template, lines 1401-1448 | 48 | 1,452 | ~363 | Smallest full agent; spawned only on failure |
| Mini-Verifier | PVRF-01 template, lines 577-608 | 32 | 1,361 | ~340 | Spawned per task (3-5 times); smallest prompt |

**Total Tier 3 prompt budget per full pipeline phase (5-task):** Researcher (914) + Planner (1,754) + Plan Checker (1,329) + Executor 5x (5 x 1,959) + Mini-Verifier 5x (5 x 340) + Verifier (4,441) + Judge (1,010) + Rating Agent (2,148) = ~23,091 tokens in Tier 3 prompts alone.

### Proposed Reduction Strategies for Top 3 Cost Centers

**1. Verifier (293 playbook lines / 265-line measured prompt / ~4,441 tokens):**
- Extract the Visual Testing methodology (Step 2.5, lines 860-912) to a separate `playbook-visual.md` -- only loaded for UI phases
- **Estimated savings:** ~120 lines from playbook for non-UI phases (~3,000 tokens), reducing verifier prompt to ~145 lines / ~2,941 tokens

**2. Compose Result (228 lines):**
- Move the TRACE.jsonl aggregation details and return contract schema to autopilot-schemas.md (reference only)
- **Estimated savings:** ~80 lines from playbook (~2,000 tokens)

**3. Execute (191 playbook section lines / 64-line measured prompt / ~1,821 tokens):**
- The per-task verification loop (PVRF-01) protocol is 105 lines within this section (consumed by the phase-runner, not passed to the executor). The executor prompt itself is only 64 lines / 7,286 chars.
- **Estimated savings:** ~60 lines from playbook (~1,500 tokens) -- higher risk, requires careful extraction

---

## 5. Proposed Fix Strategies

### Strategy B: Deduplication (Applied -- Zero Risk)

**What:** Remove redundant content within the playbook:
- Condense trace aggregation section (17 lines to 3)
- Condense progress emission section (58 lines to 7)
- Condense sandbox execution policy examples (25 lines to 5)
- Condense visual regression loop (54 lines to 8)
- Merge mini-verifier context budget into main budget table (10 lines to 2)
- Condense EXECUTION-LOG.md entry template (14 lines to 2)
- Consolidate inline trace file schema references (7 x ~2 verbose to 7 x 1 line)
- Remove redundant "decimal x.x format" reminder (1 line)

**Delivered reduction:** -156 lines (-8.4% of playbook, ~2,325 tokens)
**Risk:** Zero -- removed true redundancy (exact duplicate content, verbose examples that restated adjacent prose)
**Quality enforcement preserved:** VRFY-01, BLIND VERIFICATION, CONTEXT ISOLATION, all STEP templates, all pipeline step definitions verified present after deduplication.

### Strategy A: Playbook Modularization (Highest Impact -- For Future Discussion)

**What:** Split the playbook into core + conditional modules:
- `autopilot-playbook.md` (core: ~1,200 lines, always loaded)
- `autopilot-playbook-visual.md` (visual testing: ~120 lines, loaded only for UI phases)
- `autopilot-playbook-debug.md` (debug protocol: ~120 lines, loaded only on failure)

**Expected reduction:** ~7,000 tokens per non-UI phase-runner (~23% of current Tier 2 playbook load)
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

**Strategy B has been applied** (deduplication, zero risk, immediate benefit of -156 lines / -2,325 tokens).

For further reduction, **discuss Strategy A** (playbook modularization) based on user feedback about:

1. How often visual testing is used in practice
2. Whether the multi-file architecture is acceptable
3. Whether further context reduction is needed beyond Strategy B

---

## 7. Results: Strategy B Applied

### Before and After Comparison

| Metric | v1.7.1 Baseline | v1.8.7 Pre-Dedup | v1.8.7 Post-Dedup | Net from v1.7.1 |
|--------|----------------|-----------------|-------------------|----------------|
| Playbook lines | 1,380 | 1,856 | 1,700 | +320 (+23.2%) |
| Playbook bytes | 78,639 | 115,996 | 106,708 | +28,069 (+35.7%) |
| Playbook tokens (est.) | ~19,660 | ~29,002 | ~26,677 | ~+7,017 (+35.7%) |
| Orchestrator lines | 1,414 | 1,719 | 1,719 | +305 (+21.6%) |
| Schemas lines | 1,308 | 1,891 | 1,891 | +583 (+44.6%) |
| **Total protocol lines** | **4,102** | **5,466** | **5,310** | **+1,208 (+29.4%)** |

### What Was Condensed (Specific Deduplications)

Each entry below identifies exact content that was condensed in the playbook. All condensations removed either (a) exact duplicate content already covered by adjacent prose, or (b) verbose examples that restated what the preceding description already specified. No unique information was lost.

| Section | Location | Before | After | Savings | What Was Removed |
|---------|----------|--------|-------|---------|-----------------|
| Trace aggregation (OBSV-02) | Lines ~92-108 (old) | 17 lines | 3 lines | -14 | Inline JSONL schema and format examples (schema defined in autopilot-schemas.md Section 6) |
| Progress emission | Lines ~96-153 (old) | 58 lines | 7 lines | -51 | Verbose step-by-step examples restating the format table; duplicated task-level format already in STEP 3 |
| Sandbox execution policy | Lines ~998-1022 (old) | 25 lines | 5 lines | -20 | Detailed command examples and boundary rules restating the inline policy in STEP 4 methodology |
| Visual regression loop | Lines ~1004-1057 (old) | 54 lines | 8 lines | -46 | Full loop protocol with VISUAL-BUGS.md schema (schema in autopilot-schemas.md Section 16) |
| Mini-verifier context budget | In STEP 3 | 10 lines | 2 lines | -8 | Separate budget table (merged into main Context Budget Table) |
| EXECUTION-LOG.md entry template | In STEP 3 | 14 lines | 2 lines | -12 | Full entry template (schema in autopilot-schemas.md Section 5) |
| Inline trace file reminders | 7 step sections | 7 x ~2 verbose | 7 x 1 ref | -7 | "Write trace file to {path} (JSONL, schema: autopilot-schemas.md Section 6)" condensed to 1-line refs |
| Redundant decimal format reminder | In STEP 4.6 | 1 line | removed | -1 | Second "decimal x.x format" reminder (first definition retained in Return JSON section) |
| **Total** | | | | **-159 gross** | **-156 net** (3 lines added for condensed replacements) |

### Quality Enforcement Preserved

All critical quality markers verified present after deduplication:
- VRFY-01 (blind verification): present (grep count: 1)
- BLIND VERIFICATION: present (grep count: 1)
- CONTEXT ISOLATION (rating agent): present (grep count: 1)
- All STEP references: present (grep count: 25+)
- All pipeline step templates (0 through 5a): present
- No accidental deletions detected

### Remaining Opportunity

Strategy B delivered an 8.4% line reduction / ~8.0% token reduction. For further context savings:
- **Strategy A** (playbook modularization) could save an additional ~7,000 tokens (~23%) per non-UI phase by extracting visual testing and debug protocol content
- This requires user discussion about file management trade-offs

---

## 8. Open Questions for User

1. Is the Tier 2 (phase-runner) context consumption the primary problem you're experiencing?
2. How often do you use visual testing (`--visual`)? If rarely, 174 lines of UI-only content in the playbook are pure waste for most runs.
3. Are you seeing context exhaustion in specific scenarios (large phases, remediation loops, `--quality` runs)?
4. Would you accept a multi-file playbook architecture (Strategy A)?
5. Is the per-task verification (PVRF-01) overhead worth keeping? It adds 3-5 mini-verifier spawns per phase but catches failures earlier.
