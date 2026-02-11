# Changelog

## 1.7.0 (2026-02-11)

### Features

- **Context Exhaustion Prevention:** Orchestrator enforces manager-not-worker principle -- delegates all detailed analysis to sub-agents, never reads plan files, source code, or full state dumps directly
- **Scope Splitting:** Phase-runners detect oversized work scopes and return split requests; orchestrator spawns parallel sub-phase-runners with independent verification per sub-phase
- **Handoff-on-Failure:** Phase-runners write HANDOFF.md partial-progress files when hitting context limits; orchestrator detects these during resume and re-spawns with only remaining tasks
- **Incremental State Updates:** State.json updates use targeted Edit() operations instead of full-file rewrites, reducing per-update context consumption from 150+ lines to under 20
- **Observability-Only Context Tracking:** Replaced the 40% hard context gate with advisory-only warnings at 70% and 90% thresholds -- the system never auto-stops work due to context percentage
- **Pre-Run Context Cost Estimation:** Multi-phase quality/force runs get estimated context cost before execution begins, with warnings when estimated cost exceeds 80% of session budget

## 1.6.1 (2026-02-11)

### Features

- **CLI Quality Flags:** Four new flags for post-completion quality management -- `--force` re-executes completed phases from scratch through the full pipeline, `--quality` runs remediation loops targeting 9.5/10 alignment (max 3 cycles), `--gaps` analyzes and fixes specific deficiencies with micro-targeted iterations toward 9.5+/10, `--discuss` runs interactive Q&A per phase before execution to enrich context
- **Score History Tracking:** Each quality flag execution preserves the old alignment score in a history array for trend tracking
- **Flag Combinability:** `--discuss` combines with any flag (always runs first); `--gaps` combines with `--quality`; `--force` and `--quality` are mutually exclusive

## 1.6.0 (2026-02-11)

### Features

- **Dedicated Rating Agent:** Alignment scoring moved from inline judge/verifier assessment to a context-isolated rating agent (STEP 4.6) that does nothing but evaluate work quality -- cannot see executor confidence, verifier report, or judge recommendation
- **Decimal Precision Scoring:** All alignment scores now use x.x/10 format (e.g., 7.3, 8.6, 9.2) instead of integers, forcing granular quality distinctions
- **Calibrated Score Distribution:** Six-band calibration guide ensures scores reflect actual quality -- 9.5+ requires verified excellence, 7.0-8.9 means real deficiencies exist, below 5.0 means fundamental failures
- **Per-Criterion Scorecards:** Rating agent produces detailed SCORECARD.md with per-criterion scores, verification evidence, and justifications

## 1.5.3 (2026-02-11)

### Changes

- **Changelog Cleanup:** Removed internal phase references from all changelog entries; feature-focused descriptions only

## 1.5.2 (2026-02-10)

### Docs

- **README Rewrite:** Product-focused README organized by Executes/Verifies/Learns/Scales; removed internal phase references

## 1.5.0 (2026-02-10)

### Features

- **Batch Completion Mode:** `--complete` flag runs all outstanding phases without manual selection, with dependency-aware ordering, skip logging for completed phases, failure-resilient continuation for independent phases, and aggregated completion reporting with project completion percentage
- **Pre-Execution Context Mapping:** `--map` flag audits phase context sufficiency (1-10 scoring), spawns questioning agent for underspecified phases (<8), batches questions in single interactive session, persists answers to context-map.json across runs, emits low-confidence warnings during normal execution
- **Confidence Enforcement:** Default 9/10 alignment threshold with `--lenient` flag to revert to 7/10, remediation loops (up to 2 extra verify+judge cycles) for sub-threshold phases, diagnostic debug files for every sub-9 completion with actionable "path to 9/10" section, force_incomplete marking preserving progress when remediation exhausts

## 1.4.0 (2026-02-10)

### Features

- **Post-Completion Self-Audit:** Orchestrator automatically audits implementation against frozen spec requirements after phases complete, produces structured gap reports with file:line evidence, routes fixes by complexity (small via general-purpose, large via executor), re-verifies fixes in bounded loop (max 2 cycles), and includes audit results in completion report
- **Auto-Update Without Confirmation:** `/autopilot update` now installs updates immediately without confirmation prompt; version info displayed for transparency before install

## 1.3.1 (2026-02-10)

### Fixes

- **Documentation Gaps:** Added `estimated_tokens` to state.json phase record schema, `metrics.json` to directory structure, and `estimated_tokens` placeholder to spawn template

## 1.3.0 (2026-02-10)

### Features

- **Execution Trace and Observability:** Structured JSONL tracing with per-tool-invocation spans from step agents, phase-level trace aggregation into TRACE.jsonl, auto-generated post-mortems on failure with root cause, timeline, evidence chain, and prevention rules
- **Post-Mortem and Cross-Phase Learning:** Prevention rules appended to learnings.md after each failure, planner and executor primed with accumulated learnings, learnings file scoped to current run and reset at start, human verdict calibration from needs_human_verification outcomes
- **Metrics and Cost Tracking:** Run-level metrics.json with success rate, failure taxonomy histogram, and alignment scores; pre-execution cost estimation with budget warnings at 80% cap; cross-run trend comparison with recurring failure detection

## 1.2.0 (2026-02-10)

### Features

- **Verification Pipeline Hardening:** Blind verification (verifier never sees executor claims), JUDGE-REPORT.md artifact with divergence analysis, verifier rubber-stamp detection (2-min minimum + non-empty commands_run), judge rubber-stamp detection (independent evidence required), 10-category failure taxonomy
- **Status Decision Governance:** Evidence validation applied to all status decisions regardless of final status, structured human_verify_justification field with orchestrator rejection, unnecessary deferral warnings, human-defer rate tracking with >50% warning, human verdict recording for confidence calibration

## 1.1.2 (2026-02-10)

### Features

- **Pre-Execution Triage:** Fast codebase scan before pipeline launch detects already-implemented phases and routes to verify-only path, saving full pipeline cost

## 1.1.1 (2026-02-10)

### Features

- **Post-Creation Integration Check:** Executor auto-verifies new files are imported/wired into the codebase; verifier independently checks for orphaned files

## 1.1.0 (2026-02-10)

### Features

- **Prompt Architecture:** Structured MUST/SHOULD/MAY delimiter system across all 8 agent types, enforced context budgets per step, JSON handoff protocol replacing prose summaries
- **Executor Quality Enforcement:** Per-file compile gates blocking further writes on failure, per-task self-testing against acceptance criteria, structured per-task commits with task ID references, incremental EXECUTION-LOG.md writing, confidence scoring with mini-verification on low confidence, context priming before execution
- **Plan Quality Gates:** Plan-checker rejects acceptance criteria lacking concrete verification commands, prose-only criteria blocklist with blocker severity, required complexity estimation (simple/medium/complex) per task

## 1.0.2 (2026-02-10)

### Changes

- Add MIT LICENSE file

## 1.0.1 (2026-02-10)

### Bug Fixes

- Halt with actionable error when `autopilot-phase-runner` agent type is not found (instead of silent fallback to `general-purpose`)
- Add restart warning to installer output — agent types are discovered at session startup
- Add pre-flight agent availability check in `/autopilot` command

## 1.0.0 (2026-02-09)

### Initial Release

- 3-tier autonomous execution (orchestrator -> phase-runner -> step agents)
- Adversarial verification pipeline (verifier + judge)
- Circuit breaker system with 10 tunable thresholds
- Crash recovery via idempotent state file
- Inlined autopilot_mode context in spawn prompts (no modified GSD agents needed)
- SessionStart hook for background update checks
- Global and local install support
- `/autopilot update` command for in-place updates
