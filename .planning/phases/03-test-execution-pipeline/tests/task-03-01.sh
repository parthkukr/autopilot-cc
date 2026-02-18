#!/bin/bash
PASS=0; FAIL=0

# Criterion: Playbook contains a dedicated test_gate section
COUNT=$(grep -c 'test_gate' src/protocols/autopilot-playbook.md 2>/dev/null)
if [ "$COUNT" -ge 2 ]; then echo "PASS: test_gate section exists (count: $COUNT)"; ((PASS++)); else echo "FAIL: test_gate section missing or insufficient (count: $COUNT)"; ((FAIL++)); fi

# Criterion: Test gate references project.commands.test
if grep 'project.commands.test' src/protocols/autopilot-playbook.md | grep -qi 'test_gate\|Test Gate\|test gate'; then echo "PASS: test gate references project.commands.test"; ((PASS++)); else echo "FAIL: test gate does not reference project.commands.test"; ((FAIL++)); fi

# Criterion: Test-specific result fields present (pass_count, fail_count, failing_tests)
PC=$(grep -c 'pass_count' src/protocols/autopilot-playbook.md 2>/dev/null)
FC=$(grep -c 'fail_count' src/protocols/autopilot-playbook.md 2>/dev/null)
FT=$(grep -c 'failing_tests' src/protocols/autopilot-playbook.md 2>/dev/null)
TOTAL=$((PC + FC + FT))
if [ "$TOTAL" -ge 3 ]; then echo "PASS: test-specific fields present (pass_count=$PC, fail_count=$FC, failing_tests=$FT)"; ((PASS++)); else echo "FAIL: test-specific fields missing (pass_count=$PC, fail_count=$FC, failing_tests=$FT)"; ((FAIL++)); fi

# Criterion: Fix attempts documented with max 2 attempts
if grep 'test.*fix.*attempt\|fix.*attempt.*test\|max 2' src/protocols/autopilot-playbook.md | grep -qi 'test'; then echo "PASS: fix attempts for test gate documented"; ((PASS++)); else echo "FAIL: fix attempts for test gate not documented"; ((FAIL++)); fi

# Criterion: Null test command handled as skipped
if grep -A2 'project.commands.test.*null' src/protocols/autopilot-playbook.md | grep -q 'skipped'; then echo "PASS: null test command handled as skipped"; ((PASS++)); else echo "FAIL: null test command not handled as skipped"; ((FAIL++)); fi

# Criterion: Commit gate blocks on test failure
if grep -qi 'compile.*lint.*test\|compile.*lint.*OR.*test\|NOT commit.*test' src/protocols/autopilot-playbook.md; then echo "PASS: commit gate blocks on test failure"; ((PASS++)); else echo "FAIL: commit gate does not block on test failure"; ((FAIL++)); fi

echo "RESULTS: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
