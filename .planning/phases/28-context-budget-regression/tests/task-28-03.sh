#!/bin/bash
PASS=0; FAIL=0

# Criterion 1: FINDINGS.md contains results section
count=$(grep -ci 'After\|Result\|Post-fix\|Reduction' .planning/phases/28-context-budget-regression/FINDINGS.md 2>/dev/null || echo 0)
if [ "$count" -ge 2 ]; then
  echo "PASS: FINDINGS.md contains results section ($count mentions)"; ((PASS++))
else
  echo "FAIL: FINDINGS.md missing results section ($count mentions, need >= 2)"; ((FAIL++))
fi

# Criterion 2: SUMMARY.md exists
if test -f .planning/phases/28-context-budget-regression/SUMMARY.md; then
  echo "PASS: SUMMARY.md exists"; ((PASS++))
else
  echo "FAIL: SUMMARY.md does not exist"; ((FAIL++))
fi

# Criterion 3: SUMMARY.md mentions reduction
count=$(grep -ci 'reduction\|reduced\|saved\|lines' .planning/phases/28-context-budget-regression/SUMMARY.md 2>/dev/null || echo 0)
if [ "$count" -ge 1 ]; then
  echo "PASS: SUMMARY.md mentions context reduction ($count mentions)"; ((PASS++))
else
  echo "FAIL: SUMMARY.md missing reduction details ($count mentions, need >= 1)"; ((FAIL++))
fi

echo "RESULTS: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
