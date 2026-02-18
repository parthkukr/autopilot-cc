#!/bin/bash
PASS=0; FAIL=0

# Criterion: Mini-verifier prompt validates test gate_results
COUNT=$(grep -c 'gate_results.*test\|test.*gate' src/protocols/autopilot-playbook.md 2>/dev/null)
if [ "$COUNT" -ge 3 ]; then echo "PASS: mini-verifier validates test gate_results (count: $COUNT)"; ((PASS++)); else echo "FAIL: mini-verifier test gate_results references insufficient (count: $COUNT)"; ((FAIL++)); fi

# Criterion: Test gate failure forces mini-verifier to fail
if grep 'test.*fail\|gate_results.*test.*status.*fail' src/protocols/autopilot-playbook.md | grep -qiE 'pass.*false|MUST.*fail|must.*return'; then echo "PASS: test gate failure causes mini-verifier to fail"; ((PASS++)); else echo "FAIL: test gate failure does not cause mini-verifier failure"; ((FAIL++)); fi

# Criterion: gate_validation includes test field
if grep -A5 'gate_validation' src/protocols/autopilot-playbook.md | grep -q 'test'; then echo "PASS: gate_validation includes test field"; ((PASS++)); else echo "FAIL: gate_validation missing test field"; ((FAIL++)); fi

# Criterion: Skipped test gates accepted
if grep -i 'test.*skipped.*acceptable\|skipped.*not.*fail' src/protocols/autopilot-playbook.md | grep -q .; then echo "PASS: skipped test gates are acceptable"; ((PASS++)); else echo "FAIL: skipped test gates not documented as acceptable"; ((FAIL++)); fi

echo "RESULTS: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
