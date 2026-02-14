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

# Remediation Criterion 4: SUMMARY.md references git-measured data
if grep -q 'Git-Measured\|git history\|git show\|dd606b1\|measured' .planning/phases/28-context-budget-regression/SUMMARY.md; then
  echo "PASS: SUMMARY.md references git-measured data"; ((PASS++))
else
  echo "FAIL: SUMMARY.md does not reference git-measured data"; ((FAIL++))
fi

# Remediation Criterion 5: SUMMARY.md mentions per-agent analysis
if grep -q 'per-agent\|30,514 tokens\|base cost\|highest-cost' .planning/phases/28-context-budget-regression/SUMMARY.md; then
  echo "PASS: SUMMARY.md references per-agent cost analysis"; ((PASS++))
else
  echo "FAIL: SUMMARY.md does not reference per-agent cost analysis"; ((FAIL++))
fi

echo "RESULTS: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
