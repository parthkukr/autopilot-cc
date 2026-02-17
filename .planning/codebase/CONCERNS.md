# Codebase Concerns

**Analysis Date:** 2026-02-17

## Tech Debt

**Protocol File Size Growth:**
- Issue: Core protocol files (`autopilot-orchestrator.md`, `autopilot-playbook.md`, `autopilot-schemas.md`) have grown to 1,700-1,900 lines each, creating maintenance and context budget concerns
- Files: `src/protocols/autopilot-orchestrator.md` (1,775 lines), `src/protocols/autopilot-playbook.md` (1,700 lines), `src/protocols/autopilot-schemas.md` (1,891 lines)
- Impact: Phase 28 identified 35.7% protocol growth from v1.8.0. Large protocols consume substantial context budgets when read by step agents, reducing room for actual work. Schema references are duplicated inline rather than externalized.
- Fix approach: Continue deduplication strategy from v1.8.8 (removed 8.4% redundancy). Move common patterns into reusable templates. Replace inline schema examples with references to `autopilot-schemas.md` Section references. Establish schema versioning to prevent inline drift.

**Placeholder Substitution Risk:**
- Issue: `__INSTALL_BASE__` placeholder replacement during installation (see `bin/install.js` line 257) is single-pass string replacement without context awareness
- Files: `bin/install.js` lines 250-264, all source files in `src/` with `__INSTALL_BASE__` references
- Impact: If any file contains the literal string `__INSTALL_BASE__` in comments or examples (not as a placeholder), it will be incorrectly replaced. No validation exists to confirm all placeholders were replaced or no stray replacements occurred.
- Fix approach: Use bounded regex replacement (e.g., only in YAML frontmatter or marked sections). Add post-install validation comparing file hashes against expected manifest. Add a verification script that checks for remaining unreplaced placeholders in the installed files.

**Context Budget Fragility:**
- Issue: Phase-runner's context budget enforcement is advisory-only (see `autopilot-orchestrator.md` line 1433: "Context tracking is for observability only -- the orchestrator NEVER auto-stops work")
- Files: `src/agents/autopilot-phase-runner.md` lines 70-83, `src/protocols/autopilot-orchestrator.md` lines 1430-1467
- Impact: No hard limit prevents runaway context consumption. Split-request detection is reactive (detected during planning/execution) rather than predictive. A poorly scoped phase can accumulate 10+ step agents (research, plan, execute x5 tasks, verify, judge, rate, debug x3) all reading overlapping context before hitting practical limits.
- Fix approach: Implement predictive scope analysis in triage step. Add file read budget per step (total N file reads = N * context lines). Pre-calculate cumulative agent budget before spawning. Return split_request earlier if prediction shows >70% estimated budget.

**Agent Discovery Timing Bug (Documented but Not Fully Mitigated):**
- Issue: Claude Code discovers agent types at session startup (eager), but commands load lazily (on first use). If user installs autopilot-cc mid-session, the `/autopilot` command works but the `autopilot-phase-runner` agent type is not found.
- Files: `bin/install.js` (no programmatic session restart), `src/commands/autopilot.md` (includes runtime check but fallback unclear)
- Impact: User can trigger full phase pipeline execution, which fails when orchestrator tries to spawn phase-runner. Confusing error messages. Workaround documented (restart session) but not enforced automatically.
- Fix approach: Add a pre-execution CLI check that verifies both command AND agent are discoverable before proceeding. If mid-session install detected, block execution with clear "Please restart" instruction. Optionally add a scheduled session-reset suggestion if multiple mid-session installs are detected in recent history.

---

## Known Bugs

**Grep-Only Verification Proxy (Documented Limitation):**
- Symptom: Phase verification relies on grep patterns as primary evidence (see Phase 26 analysis in CHANGELOG.md). This catches structural changes but not functional bugs.
- Files: `src/protocols/autopilot-playbook.md` lines 750-752 (acknowledges edge cases), phase 26 scorecard notes -1.0 penalty for weak proxy
- Trigger: A task writes code that compiles and passes grep patterns but has broken runtime logic. Example: function signature is correct but logic is inverted.
- Workaround: Execution-based criteria (compile, test, build, lint) are required when project has configured commands in `.planning/config.json`. Verifier performs behavioral traces for UI phases. But grep-only phases can still pass with functional bugs if no test coverage exists.
- Fix approach: Make execution-based criteria mandatory (not optional) for all tasks. Modify playbook Step 1.4 to require at least one non-grep criterion per task when `project.commands` exist.

**Visual Testing Path Dependencies:**
- Symptom: Visual testing requires exact config structure (`visual_testing.launch_command`, `visual_testing.base_url`, `visual_testing.routes` with path/name pairs). Missing any field silently degrades to no visual testing.
- Files: `src/protocols/autopilot-orchestrator.md` lines 1087-1090
- Trigger: User provides incomplete visual config (e.g., routes array but no launch_command). No error thrown, just silent skip.
- Workaround: Config validation warns but proceeds. Verifier skips visual testing step without explicit failure.
- Fix approach: Add early validation in orchestrator Section 3 (Step 1.2 Visual Testing) that FAILS the run if `--visual` flag is present but config is incomplete. Require explicit opt-out rather than silent fallback.

---

## Security Considerations

**Manifest Integrity Not Cryptographically Verified:**
- Risk: `autopilot-file-manifest.json` uses SHA-256 hashes but manifests are not signed. Compromised manifest could allow installation of altered files without detection.
- Files: `bin/install.js` lines 69, 262, 276 (writes manifest), no signature verification exists
- Current mitigation: Manifest is written locally by the installer (not transmitted). NPM package verification protects the installer itself.
- Recommendations: Add optional GPG signing of manifests for sensitive deployments. Implement manifest rollback detection (compare to previously installed manifest). Add hash verification on update operations.

**Environment Variable Exposure in Hook Logs:**
- Risk: `autopilot-check-update.js` (SessionStart hook) may log command output containing env vars if version check fails
- Files: `src/hooks/autopilot-check-update.js` (needs review of error logging)
- Current mitigation: Hook only logs version check results, not full process environment
- Recommendations: Audit hook output to ensure no env var leakage in error cases. Add explicit env filtering if hook needs to log subprocess errors.

**Placeholder Injection in Installed Files:**
- Risk: If `__INSTALL_BASE__` replacement is botched (e.g., partial replacement or injection in file paths), installed commands could reference incorrect paths or execute wrong scripts
- Files: All files in `src/` that contain `__INSTALL_BASE__` placeholders
- Current mitigation: Post-install manifest comparison catches hash mismatches, but only if manifest itself is correct
- Recommendations: Add a verification script that spot-checks critical placeholders (in YAML frontmatter, in path references) are properly replaced. Run this as part of install completion.

---

## Performance Bottlenecks

**Sequential Step Agent Spawning (PVRF-01 Implementation):**
- Problem: Per-task execution loop spawns executor, then mini-verifier, then debugger (max 2 attempts). Each is sequential despite `run_in_background=true` for executor.
- Files: `src/agents/autopilot-phase-runner.md` lines 166-177 (describes per-task loop), `src/protocols/autopilot-playbook.md` Step 3
- Cause: Mini-verifier must run after executor completes (not background), blocking task completion. For a 5-task phase with average 1 mini-verify failure per task, this adds ~5 sequential steps.
- Improvement path: Batch mini-verifications for multiple tasks in parallel. Use a lightweight verification aggregator agent that can verify 3-5 tasks in a single spawn. Reduces per-phase overhead from O(n) to O(log n) spawns.

**Repo-Map Incremental Update Cost:**
- Problem: After each executor commit, repo-map must be incremented for changed files. Executor reads entire repo-map for symbol lookup (see `autopilot-playbook.md` line 659), then re-reads modified files to update their entries.
- Files: `src/protocols/autopilot-playbook.md` lines 659-660 (incremental update described), `src/protocols/autopilot-orchestrator.md` lines 804-809 (refresh logic)
- Cause: Repo-map is append-only in memory. For phases with 10+ commits, map grows without pruning old entries. Verifier and judge both read full map during their tasks.
- Improvement path: Implement map versioning with per-file version numbers. Only load file entries needed for current verification task. Archive old versions periodically.

**Learnings File Accumulation (LRNG-03 Mitigation):**
- Problem: `.autopilot/learnings.md` is reset per run (line 25 of orchestrator), but within a run it can grow to 50+ entries (one per debug session). If debugging is triggered 10+ times, learnings file becomes a large context sink.
- Files: `src/protocols/autopilot-orchestrator.md` lines 25-26, line 1014 (learning consumption)
- Cause: Every debug produces a prevention rule added to learnings. No pruning or deduplication within a run.
- Improvement path: Implement learnings summary agent that deduplicates and consolidates similar rules. Keep only the top 5-10 most relevant learnings per run.

---

## Fragile Areas

**Phase Dependency Resolution:**
- Files: `src/protocols/autopilot-orchestrator.md` lines 38-40 (dependency graph building)
- Why fragile: Dependency parsing is regex-based on "Depends on:" field format. If roadmap author uses alternate syntax ("Requires", "Needs", or lowercase "depends"), dependency detection fails silently. Topological sort builds DAG but doesn't validate acyclic guarantee or warn on missing dependencies.
- Safe modification: Use structured YAML dependency sections in roadmap instead of prose. Validate roadmap format before execution. Add explicit cycle detection with informative error messages.
- Test coverage: No unit tests for dependency resolution. Cyclic dependency created in roadmap would cause orchestrator to hang or infinite loop.

**Triage Criteria Matching (Section 0.5):**
- Files: `src/protocols/autopilot-playbook.md` lines ~160-200 (triage step description expected but not fully detailed in read section)
- Why fragile: Triage uses ">80% criteria pass" heuristic to decide verify_only routing. What counts as "pass"? Grep match = pass? Code exists = pass? No explicit definition. If criteria are ambiguous ("function handles errors"), triage may incorrectly route to verify_only and skip real work.
- Safe modification: Define triage scoring rubric explicitly: each criterion maps to 1-2 verifiable checks (file exists AND has pattern, OR test passes). Triage must achieve >80% on ALL criteria, not just majority.
- Test coverage: No test cases for edge case criteria. Verify this in acceptance test suite.

**Plan-Check Gate (STEP 2):**
- Files: `src/protocols/autopilot-playbook.md` Step 2 (Plan Validation)
- Why fragile: Plan-check is spawned as `gsd-plan-checker` but no timeout or size limit is defined. If planner produces 100+ tasks, plan-check must validate all of them sequentially. Plan-check can fail for vague criteria ("code quality", "user-friendly"), triggering replan loop (max 1 attempt). If criteria are genuinely vague, replan + recheck can cycle indefinitely.
- Safe modification: Add explicit task count limit (recommend max 5 complex tasks per phase). Add criteria validation that rejects prose-only criteria in plan-check. Implement max retry counter that converts plan-check failure to phase failure if replan limit is hit.
- Test coverage: No test case for 10+ task plans. No test for degenerate criteria.

**Remediation Cycle Convergence:**
- Files: `src/protocols/autopilot-orchestrator.md` Section 1.6 (`--quality` mode), `src/protocols/autopilot-playbook.md` step replan logic
- Why fragile: Quality mode aims for 9.5/10 alignment through max 3 remediation cycles. Each cycle reruns research -> plan -> execute -> verify -> judge -> rate. If score is 8.9 and the issue is unfixable (e.g., "code style is not elegant enough"), cycle 1 -> cycle 2 -> cycle 3 will all fail identically. No convergence detection exists.
- Safe modification: Implement remediation convergence check: if cycle N score = cycle N-1 score, skip to cycle N+1 (no point redoing work). If cycle N alignment improves <0.5 points over cycle N-1, stop and declare convergence. Accept score as final rather than infinite retry.
- Test coverage: No test for degenerate 8.9 score case.

---

## Scaling Limits

**Protocol File Context Consumption:**
- Current capacity: Each protocol file is read in full by different step agents. Orchestrator reads orchestrator.md once. Phase-runner reads playbook.md once. Executor reads playbook.md section(s). Estimated total: 5,000+ lines of protocol text across a typical 5-phase run.
- Limit: At 7+ concurrent phases (in `--complete` mode with split requests), 7 phase-runners × 1,700 lines (playbook) = 11,900 lines of protocol content. This consumes ~10-15% of session context just for protocols.
- Scaling path: Extract task-step mappings (execute, test, compile) into a lightweight 200-line playbook subset. Provide section references instead of inline examples. Compress common patterns into parameterized templates.

**Repo-Map File Coverage:**
- Current capacity: `.autopilot/repo-map.json` supports projects with 100-300 files (estimated). Typical entries per file: 3-5 exports, 2-4 imports, 1-2 functions. Total JSON size: 50-100 KB.
- Limit: Projects with 1,000+ files would generate 500+ KB repo-map. Reading this for symbol lookup (executor pre-check) on every task burns context budget. Verifier reading map for every task verification is inefficient.
- Scaling path: Implement lazy loading of repo-map. Load only files touched by current phase. Implement file-level indexing so lookup is O(1) instead of full scan. Archive old versions.

**Learnings File Per-Run Growth:**
- Current capacity: Single run with 3 debug cycles produces 3-5 learnings entries (~500 bytes each). Stack up to 10 debug cycles: 2.5-5 KB per run.
- Limit: Projects with 20+ phases, each with 2-3 debug cycles, accumulate 40-60 learnings per run. Single learnings file can reach 30-50 KB. If this is read by every subsequent executor (LRNG-02), it becomes a context sink.
- Scaling path: Implement learnings summary agent (Phase 35-level feature) that consolidates similar rules. Keep top 5-10 per run. Archive old learnings to separate file.

---

## Dependencies at Risk

**GSD Dependency (get-shit-done-cc >= 1.15.0):**
- Risk: Autopilot uses GSD step agents (gsd-phase-researcher, gsd-planner, gsd-executor, gsd-verifier, gsd-plan-checker, gsd-debugger). If GSD introduces breaking changes, autopilot's entire pipeline breaks. Minimum version is 1.15.0 but no upper bound is specified.
- Impact: If GSD 2.0.0 ships with incompatible agent interfaces, autopilot must pin to GSD 1.x or rewrite all pipeline integration. No compatibility layer exists.
- Migration plan: Maintain backward compatibility bridge in phase-runner and playbook. Add GSD version detection in preflight (similar to checkGSD() in install.js). If GSD version is incompatible, log explicit error with upgrade path.

**NPM Package Security:**
- Risk: `bin/install.js` executes without any package integrity verification beyond what npm itself provides. If autopilot package is compromised on npm registry, installer runs untrusted code.
- Impact: Installer writes files to `~/.claude/` with elevated permissions. Compromised installer could modify GSD files, steal credentials, or inject malicious hooks.
- Migration plan: Implement optional GPG signature verification for package. Add SRI (Subresource Integrity) checksums for critical files. Document code review checklist for users installing from untrusted networks.

---

## Test Coverage Gaps

**Installer Logic (bin/install.js):**
- What's not tested: File copy correctness, placeholder substitution accuracy, manifest generation, hook injection/removal, uninstall file cleanup, directory permission handling
- Files: `bin/install.js` (no test file exists)
- Risk: Installer could silently fail to install critical files (e.g., protocol files), leaving command non-functional. User won't know until runtime.
- Priority: High - installer is entry point for all users.

**Dependency Resolution and Topological Sort:**
- What's not tested: Cyclic dependency detection, transitive dependency chains, missing dependency handling, topological sort correctness
- Files: `src/protocols/autopilot-orchestrator.md` (logic described, not tested)
- Risk: Circular dependency in roadmap could cause infinite loop. Missing dependency could be silently ignored, causing phase to execute before its dependencies.
- Priority: High - affects `--complete` mode correctness.

**Context Budget Enforcement:**
- What's not tested: Actual context usage per phase, split-request triggering accuracy, agent response truncation correctness, recovery from context exhaustion
- Files: `src/agents/autopilot-phase-runner.md` lines 70-83 (budgets defined), no integration test
- Risk: Phase-runner could exhaust context without triggering split-request, causing truncated responses or tool failures. No recovery mechanism in place.
- Priority: Medium - impacts projects with 7+ phases or complex phases.

**Triage Routing (Section 0.5):**
- What's not tested: Edge cases where criteria are ambiguous, >80% heuristic is inaccurate, false positives (skip work that should be done), false negatives (redo work that's done)
- Files: `src/protocols/autopilot-playbook.md` (triage logic)
- Risk: Triage could incorrectly route a phase to verify_only when work is needed, causing phase to pass with incomplete implementation. Or route to full_pipeline when verify_only would suffice, wasting time.
- Priority: Medium - affects efficiency of triage-routed phases.

**Remediation Convergence:**
- What's not tested: Quality mode convergence with stuck scores (e.g., 8.9 all 3 cycles), timeout/retry limits, convergence detection accuracy
- Files: `src/protocols/autopilot-orchestrator.md` Section 1.6
- Risk: Phase enters remediation loop indefinitely if issue is unfixable. No convergence check exists, so max_remediation_cycles must be hit (wastes 2 extra cycles).
- Priority: Medium - affects `--quality` mode users on difficult phases.

---

*Concerns audit: 2026-02-17*
