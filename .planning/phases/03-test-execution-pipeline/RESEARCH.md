# Research: Phase 3 -- Test Execution Pipeline

## Requirement
EXEC-03: Executor runs the project's test suite after each task and acts on failures before moving to the next task

## Roadmap Success Criteria
1. After each task is committed, the executor runs the project's test command and records the results
2. If tests fail after a task, the executor enters a fix loop before moving to the next task
3. Test results (pass count, fail count, failing test names) are captured as structured evidence in the execution log
4. If no test command is configured, the system proceeds without test gating and logs that tests were skipped (not silently ignored)

## Codebase State Analysis

### Existing Pattern: Compile/Lint Gate (Phase 2)
Phase 2 established the gate pattern in `src/protocols/autopilot-playbook.md`:
- Location: `<compile_lint_gate>` section (lines 663-706)
- Flow: Run command -> check exit code -> fix loop (max 2 attempts) -> block commit on failure
- Evidence: `gate_results` JSON with status/command/exit_code/output/attempts/fix_attempts
- Null handling: null command -> "skipped" (not failure)
- Mini-verifier validates: `gate_validation` field checks compile/lint status

### Schema State (autopilot-schemas.md)
- `gate_results` in executor return: has `compile` and `lint` sub-objects (lines 354-377)
- `gate_validation` in mini-verifier return: has `compile` and `lint` fields (lines 408-411)
- EXECUTION-LOG.md template: has Gate Results with Compile/Lint, no Test field (lines 427-429)
- Mini-Verification template: gate_validation with compile/lint only (line 435)

### Gap Analysis
1. No `<test_gate>` section exists in the executor prompt
2. No `test` field in `gate_results` schema
3. No `test` field in `gate_validation` schema
4. No `test` field in EXECUTION-LOG Gate Results template
5. No test-specific structured results (pass_count, fail_count, failing_tests)
6. The compile_lint_gate runs BEFORE commit; test gate should also run before commit (after compile/lint pass)

### Approach: Extend the Established Gate Pattern
The test gate follows the exact same pattern as compile/lint gates:
1. Add `<test_gate>` section in executor prompt, placed AFTER `</compile_lint_gate>` and BEFORE the `</must>` closing
2. Add `test` sub-object to `gate_results` in executor return and schemas
3. Add `test` to `gate_validation` in mini-verifier return and schemas
4. Add Test to EXECUTION-LOG Gate Results template
5. Extend test gate with additional fields: `pass_count`, `fail_count`, `failing_tests` (array)
6. Update commit gate: block if test gate has status "fail"

### Timing: Test gate runs AFTER compile/lint pass
The flow per task becomes: write code -> compile gate -> lint gate -> test gate -> commit gate
This ensures only compilable, lint-clean code is tested.

## Risks
- Test output parsing: unlike compile/lint which just need exit codes, test results need structured extraction (pass/fail counts, test names). The gate should capture raw output and attempt best-effort parsing, not block on parse failures.
- Long-running tests: tests may take significantly longer than compile/lint. No timeout change needed (test commands themselves handle timeouts).

## Open Questions
None -- the pattern is established and the extension is straightforward.
