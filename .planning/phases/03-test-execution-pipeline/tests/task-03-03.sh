#!/bin/bash
PASS=0; FAIL=0

# Criterion: Schema has test sub-object in gate_results
if grep -A20 'gate_results' src/protocols/autopilot-schemas.md | grep -q 'test'; then echo "PASS: schema has test in gate_results"; ((PASS++)); else echo "FAIL: schema missing test in gate_results"; ((FAIL++)); fi

# Criterion: Schema documents pass_count, fail_count, failing_tests
PC=$(grep -c 'pass_count' src/protocols/autopilot-schemas.md 2>/dev/null)
FC=$(grep -c 'fail_count' src/protocols/autopilot-schemas.md 2>/dev/null)
FT=$(grep -c 'failing_tests' src/protocols/autopilot-schemas.md 2>/dev/null)
TOTAL=$((PC + FC + FT))
if [ "$TOTAL" -ge 3 ]; then echo "PASS: test-specific fields documented (pass_count=$PC, fail_count=$FC, failing_tests=$FT)"; ((PASS++)); else echo "FAIL: test-specific fields missing in schema (pass_count=$PC, fail_count=$FC, failing_tests=$FT)"; ((FAIL++)); fi

# Criterion: gate_validation schema includes test
if grep -A5 'gate_validation' src/protocols/autopilot-schemas.md | grep -q 'test'; then echo "PASS: gate_validation schema includes test"; ((PASS++)); else echo "FAIL: gate_validation schema missing test"; ((FAIL++)); fi

# Criterion: EXECUTION-LOG template includes Test gate result
if grep -qi 'Test.*PASS.*FAIL.*SKIPPED\|Test.*gate' src/protocols/autopilot-schemas.md; then echo "PASS: EXECUTION-LOG template has test gate"; ((PASS++)); else echo "FAIL: EXECUTION-LOG template missing test gate"; ((FAIL++)); fi

# Criterion: Existing Step Agent summary mentions test
if grep -A3 'Existing Step Agent' src/protocols/autopilot-schemas.md | grep -qi 'test'; then echo "PASS: step agent summary mentions test"; ((PASS++)); else echo "FAIL: step agent summary does not mention test"; ((FAIL++)); fi

echo "RESULTS: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
