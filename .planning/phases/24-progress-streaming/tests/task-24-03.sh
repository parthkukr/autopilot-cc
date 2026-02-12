#!/bin/bash
PASS=0; FAIL=0
BASE="/mnt/c/Users/parth/OneDrive/Documents/GitHub/autopilot-cc"
FILE="$BASE/src/agents/autopilot-phase-runner.md"

# Criterion 1: progress_streaming section exists
if grep -q 'progress_streaming' "$FILE"; then echo "PASS: progress_streaming section exists"; ((PASS++)); else echo "FAIL: progress_streaming section missing"; ((FAIL++)); fi

# Criterion 2: Step-level progress emission instructions
if grep -qi 'emit.*progress\|Progress.*step\|pipeline step' "$FILE"; then echo "PASS: Step-level progress instructions present"; ((PASS++)); else echo "FAIL: Step-level progress instructions missing"; ((FAIL++)); fi

# Criterion 3: Executor progress format passing
if grep -qi 'executor.*progress\|progress.*executor' "$FILE"; then echo "PASS: Executor progress format instructions present"; ((PASS++)); else echo "FAIL: Executor progress format instructions missing"; ((FAIL++)); fi

# Criterion 4: Compile-gate result streaming
if grep -qi 'compil.*progress\|compile.*result\|compile.*gate.*stream\|compilation.*status' "$FILE"; then echo "PASS: Compile-gate result streaming instructions present"; ((PASS++)); else echo "FAIL: Compile-gate result streaming instructions missing"; ((FAIL++)); fi

echo "RESULTS: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
