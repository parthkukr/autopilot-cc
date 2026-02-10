# Changelog

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
