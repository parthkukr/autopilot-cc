#!/bin/bash
PASS=0; FAIL=0
ORCH="src/protocols/autopilot-orchestrator.md"

# Criterion: Gray area analysis JSON includes options field
if grep -q '"options"' "$ORCH"; then echo "PASS: options field present in schema"; ((PASS++)); else echo "FAIL: options field not in schema"; ((FAIL++)); fi

# Criterion: Options guidance in agent prompt (concrete not abstract)
if grep -qi 'concrete.*not abstract\|concrete choice' "$ORCH"; then echo "PASS: Options guidance present"; ((PASS++)); else echo "FAIL: Options guidance not present"; ((FAIL++)); fi

# Criterion: Questions array with options in gray area schema
if grep -q '"question"' "$ORCH" && grep -q '"options"' "$ORCH"; then echo "PASS: Questions with options in schema"; ((PASS++)); else echo "FAIL: Questions with options not in schema"; ((FAIL++)); fi

echo "RESULTS: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
