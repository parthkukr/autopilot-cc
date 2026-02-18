# Plan: Phase 3 -- Test Execution Pipeline

## Overview
Add a test execution gate to the autopilot pipeline, following the exact pattern established by Phase 2's compile/lint gates. After each task's code passes compile and lint, the executor runs the project's test suite, captures structured results (pass/fail counts, failing test names), enters a fix loop on failure, and blocks the commit if tests cannot be fixed. This ensures the test suite stays green after every task.

## Traceability

| Requirement | Task(s) | Description |
|-------------|---------|-------------|
| EXEC-03 | 03-01, 03-02, 03-03 | Test execution gate with fix loop, structured results, and null-command handling |

## Wave 1

<task id="03-01" type="auto" complexity="medium">

### Task 03-01: Add Test Gate Section to Executor Prompt

**Files:** src/protocols/autopilot-playbook.md

**Action:** In the executor prompt template (STEP 3), add a dedicated `<test_gate>` section immediately AFTER the `</compile_lint_gate>` closing tag and BEFORE the `<should>` block. The test gate follows the same structure as the compile_lint_gate but with test-specific additions:

1. Define the test gate protocol (EXEC-03) as a clearly delineated section
2. Specify the gate execution flow: after compile/lint gates pass (or are skipped), run `project.commands.test` from `.planning/config.json`
3. Record structured test evidence: command, exit_code, output (first 500 chars of stdout/stderr)
4. Add test-specific result fields: `pass_count` (integer or null), `fail_count` (integer or null), `failing_tests` (array of test name strings, or empty array)
5. Best-effort parsing: the executor attempts to extract pass/fail counts and test names from the output. If parsing fails (non-standard output format), set pass_count and fail_count to null and failing_tests to empty array. The raw output is always captured regardless.
6. Fix-attempt evidence when tests fail: what_failed (failing test names or error), fix_applied (description), result (pass/fail after fix). Max 2 fix attempts.
7. Null-command handling: if `project.commands.test` is null, gate status = "skipped" (not failure), matching compile/lint pattern
8. Update the commit gate (item 3 in compile_lint_gate): do NOT commit if ANY gate (compile, lint, OR test) has status "fail"

Also add `test` to the `gate_results` JSON in the executor return:
```json
"test": {
  "status": "pass|fail|skipped",
  "command": "string|null",
  "exit_code": 0,
  "output": "first 500 chars of stdout/stderr",
  "pass_count": null,
  "fail_count": null,
  "failing_tests": [],
  "attempts": 1,
  "fix_attempts": []
}
```

**Verify:**
- The playbook contains a dedicated test_gate section in the executor prompt -- verified by: `grep -c 'test_gate' src/protocols/autopilot-playbook.md` (returns at least 2)
- The test gate references project.commands.test -- verified by: `grep 'project.commands.test' src/protocols/autopilot-playbook.md | grep -c 'test_gate\|Test Gate\|test gate'` (returns at least 1)
- The gate includes test-specific result fields (pass_count, fail_count, failing_tests) -- verified by: `grep -c 'pass_count\|fail_count\|failing_tests' src/protocols/autopilot-playbook.md` (returns at least 3)
- Fix attempts are documented with max 2 attempts -- verified by: `grep 'test.*fix.*attempt\|fix.*attempt.*test\|max 2' src/protocols/autopilot-playbook.md | grep -ic 'test'` (returns at least 1)
- Null test command is handled as skipped -- verified by: `grep -A2 'project.commands.test.*null' src/protocols/autopilot-playbook.md | grep -c 'skipped'` (returns at least 1)
- Commit gate blocks on test failure -- verified by: `grep 'compile.*lint.*test\|compile.*lint.*OR.*test\|NOT commit.*test' src/protocols/autopilot-playbook.md` (returns at least 1)
- Test specification passes -- verified by: `bash .planning/phases/03-test-execution-pipeline/tests/task-03-01.sh 2>&1; echo EXIT:$?` (expect EXIT:0)

**Done:** The executor prompt has a dedicated test gate section with structured test results, fix loop, and null-command handling.

</task>

<task id="03-02" type="auto" complexity="medium">

### Task 03-02: Add Test Gate Validation to Mini-Verifier and PVRF-01

**Files:** src/protocols/autopilot-playbook.md

**Action:** Extend the PVRF-01 mini-verifier prompt to validate the test gate, following the exact pattern used for compile/lint gate validation:

1. In the mini-verifier prompt template (STEP 3 "Per-Task Execution Loop"), update the MUST item about gate validation to also check the test gate in `gate_results`
2. Add test gate validation logic: if `gate_results.test.status` is "fail", the mini-verifier MUST return `pass: false`
3. If `gate_results.test` is missing (and project has a configured test command), flag as concern but do not hard-fail (the test gate is new; existing executors may not include it yet during transition)
4. Validate that if `gate_results.test.status` is "fail", the fix_attempts array is non-empty (executor should have tried to fix before declaring failure)
5. Skipped test gates are acceptable (not failure), consistent with compile/lint skipped handling
6. Update the `gate_validation` field in the mini-verifier return JSON to include `test`:
```json
"gate_validation": {
  "compile": "pass|fail|skipped|missing",
  "lint": "pass|fail|skipped|missing",
  "test": "pass|fail|skipped|missing"
}
```
7. Update the phase-runner's PVRF-01 loop documentation to pass test gate_results from executor return to mini-verifier

**Verify:**
- Mini-verifier prompt validates test gate_results -- verified by: `grep -c 'gate_results.*test\|test.*gate' src/protocols/autopilot-playbook.md` (returns at least 3)
- Test gate failure forces mini-verifier to fail -- verified by: `grep 'test.*fail\|gate_results.*test.*status.*fail' src/protocols/autopilot-playbook.md | grep -ic 'pass.*false\|MUST.*fail\|must.*return'` (returns at least 1)
- gate_validation includes test field -- verified by: `grep -A5 'gate_validation' src/protocols/autopilot-playbook.md | grep -c 'test'` (returns at least 1)
- Skipped test gates accepted -- verified by: `grep -i 'test.*skipped.*acceptable\|skipped.*not.*fail' src/protocols/autopilot-playbook.md` (returns at least 1)
- Test specification passes -- verified by: `bash .planning/phases/03-test-execution-pipeline/tests/task-03-02.sh 2>&1; echo EXIT:$?` (expect EXIT:0)

**Done:** The mini-verifier structurally validates test gate results from executor returns, rejecting tasks with failed tests while accepting skipped (null command) test gates.

</task>

## Wave 2

<task id="03-03" type="auto" complexity="medium">

### Task 03-03: Update Schemas and EXECUTION-LOG with Test Gate Evidence

**Files:** src/protocols/autopilot-schemas.md

**Action:** Extend the schemas documentation to cover the test gate, following the pattern established by Phase 2 for compile/lint:

1. Add `test` sub-object to the `gate_results` schema in the executor return (Section 5), with all test-specific fields: status, command, exit_code, output, pass_count, fail_count, failing_tests, attempts, fix_attempts
2. Add documentation explaining the test gate fields:
   - pass_count/fail_count: integer or null (null when output format cannot be parsed)
   - failing_tests: array of test name strings (empty array when parsing fails)
   - Best-effort parsing note: raw output always captured, structured fields are best-effort
3. Add `test` field to `gate_validation` in the mini-verifier return schema
4. Update the EXECUTION-LOG.md template to include Test in the Gate Results section:
   ```markdown
   - **Test:** {PASS|FAIL|SKIPPED} (command: {cmd}, exit_code: {N}, pass: {N}, fail: {N}, attempts: {N})
   ```
5. Update the Mini-Verification gate_validation template to include test
6. Update the "Existing Step Agent Return Schemas" summary to mention test gate
7. Add a paragraph after the existing Compile/Lint Gate Results documentation explaining the Test Gate Results (EXEC-03), following the same documentation style

**Verify:**
- Schema has test sub-object in gate_results -- verified by: `grep -A20 'gate_results' src/protocols/autopilot-schemas.md | grep -c 'test'` (returns at least 1)
- Schema documents pass_count, fail_count, failing_tests fields -- verified by: `grep -c 'pass_count\|fail_count\|failing_tests' src/protocols/autopilot-schemas.md` (returns at least 3)
- gate_validation schema includes test -- verified by: `grep -A5 'gate_validation' src/protocols/autopilot-schemas.md | grep -c 'test'` (returns at least 1)
- EXECUTION-LOG template includes Test gate result -- verified by: `grep -c 'Test.*PASS.*FAIL.*SKIPPED\|Test.*gate' src/protocols/autopilot-schemas.md` (returns at least 1)
- Existing Step Agent summary mentions test -- verified by: `grep -A3 'Existing Step Agent' src/protocols/autopilot-schemas.md | grep -c 'test'` (returns at least 1)
- Test specification passes -- verified by: `bash .planning/phases/03-test-execution-pipeline/tests/task-03-03.sh 2>&1; echo EXIT:$?` (expect EXIT:0)

**Done:** The schemas documentation fully covers test gate evidence in executor returns, mini-verifier validation, and EXECUTION-LOG templates.

</task>
