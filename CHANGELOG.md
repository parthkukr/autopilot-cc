# Changelog

## 1.4.0 (2026-02-10)

### Features

- **Post-Completion Self-Audit (Phase 12):** Orchestrator automatically audits implementation against frozen spec requirements after phases complete, produces structured gap reports with file:line evidence, routes fixes by complexity (small via general-purpose, large via executor), re-verifies fixes in bounded loop (max 2 cycles), and includes audit results in completion report
- **Auto-update without confirmation (Phase 13):** `/autopilot update` now installs updates immediately without confirmation prompt; version info displayed for transparency before install

## 1.3.1 (2026-02-10)

### Fixes

- **Phase 7 Documentation Gaps:** Added `estimated_tokens` to state.json phase record schema, `metrics.json` to directory structure, and `estimated_tokens` placeholder to spawn template

## 1.3.0 (2026-02-10)

### Features

- **Execution Trace and Observability (Phase 5):** Structured JSONL tracing with per-tool-invocation spans from step agents, phase-level trace aggregation into TRACE.jsonl, auto-generated post-mortems on failure with root cause, timeline, evidence chain, and prevention rules
- **Post-Mortem and Cross-Phase Learning (Phase 6):** Prevention rules appended to learnings.md after each failure, planner and executor primed with accumulated learnings, learnings file scoped to current run and reset at start, human verdict calibration from needs_human_verification outcomes
- **Metrics and Cost Tracking (Phase 7):** Run-level metrics.json with success rate, failure taxonomy histogram, and alignment scores; pre-execution cost estimation with budget warnings at 80% cap; cross-run trend comparison with recurring failure detection

## 1.2.0 (2026-02-10)

### Features

- **Verification Pipeline Hardening (Phase 4):** Blind verification (verifier never sees executor claims), JUDGE-REPORT.md artifact with divergence analysis, verifier rubber-stamp detection (2-min minimum + non-empty commands_run), judge rubber-stamp detection (independent evidence required), 10-category failure taxonomy
- **Status Decision Governance (Phase 4.1):** Evidence validation applied to all status decisions regardless of final status, structured human_verify_justification field with orchestrator rejection, unnecessary deferral warnings, human-defer rate tracking with >50% warning, human verdict recording for confidence calibration

## 1.1.2 (2026-02-10)

### Features

- **Pre-Execution Triage (Phase 3.1):** Fast codebase scan before pipeline launch detects already-implemented phases and routes to verify-only path, saving full pipeline cost

## 1.1.1 (2026-02-10)

### Features

- **Post-Creation Integration Check (Phase 2.1):** Executor auto-verifies new files are imported/wired into the codebase; verifier independently checks for orphaned files

## 1.1.0 (2026-02-10)

### Features

- **Prompt Architecture (Phase 1):** Structured MUST/SHOULD/MAY delimiter system across all 8 agent types, enforced context budgets per step, JSON handoff protocol replacing prose summaries
- **Executor Quality Enforcement (Phase 2):** Per-file compile gates blocking further writes on failure, per-task self-testing against acceptance criteria, structured per-task commits with task ID references, incremental EXECUTION-LOG.md writing, confidence scoring with mini-verification on low confidence, context priming before execution
- **Plan Quality Gates (Phase 3):** Plan-checker rejects acceptance criteria lacking concrete verification commands, prose-only criteria blocklist with blocker severity, required complexity estimation (simple/medium/complex) per task

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

- 3-tier autonomous phase execution (orchestrator -> phase-runner -> step agents)
- Adversarial verification pipeline (verifier + judge)
- Circuit breaker system with 10 tunable thresholds
- Crash recovery via idempotent state file
- Inlined autopilot_mode context in spawn prompts (no modified GSD agents needed)
- SessionStart hook for background update checks
- Global and local install support
- `/autopilot update` command for in-place updates
