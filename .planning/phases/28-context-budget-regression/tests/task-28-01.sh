#!/bin/bash
PASS=0; FAIL=0

# Criterion 1: FINDINGS.md exists with data tables
if test -f .planning/phases/28-context-budget-regression/FINDINGS.md; then
  count=$(grep -c '|.*lines.*|' .planning/phases/28-context-budget-regression/FINDINGS.md 2>/dev/null || echo 0)
  if [ "$count" -ge 3 ]; then
    echo "PASS: FINDINGS.md exists with data tables ($count rows)"; ((PASS++))
  else
    echo "FAIL: FINDINGS.md exists but insufficient data tables ($count rows, need >= 3)"; ((FAIL++))
  fi
else
  echo "FAIL: FINDINGS.md does not exist"; ((FAIL++))
fi

# Criterion 2: Per-phase contribution ranking
count=$(grep -c 'Phase 2[0-6]' .planning/phases/28-context-budget-regression/FINDINGS.md 2>/dev/null || echo 0)
if [ "$count" -ge 5 ]; then
  echo "PASS: Per-phase contribution ranking present ($count mentions)"; ((PASS++))
else
  echo "FAIL: Per-phase contribution ranking insufficient ($count mentions, need >= 5)"; ((FAIL++))
fi

# Criterion 3: Root cause analysis
count=$(grep -c 'Root Cause' .planning/phases/28-context-budget-regression/FINDINGS.md 2>/dev/null || echo 0)
if [ "$count" -ge 3 ]; then
  echo "PASS: Root cause analysis present ($count mentions)"; ((PASS++))
else
  echo "FAIL: Root cause analysis insufficient ($count mentions, need >= 3)"; ((FAIL++))
fi

# Criterion 4: Proposed strategies
count=$(grep -c 'Strategy' .planning/phases/28-context-budget-regression/FINDINGS.md 2>/dev/null || echo 0)
if [ "$count" -ge 2 ]; then
  echo "PASS: Proposed strategies present ($count mentions)"; ((PASS++))
else
  echo "FAIL: Proposed strategies insufficient ($count mentions, need >= 2)"; ((FAIL++))
fi

echo "RESULTS: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
