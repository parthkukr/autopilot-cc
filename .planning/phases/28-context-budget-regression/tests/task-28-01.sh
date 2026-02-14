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

# Remediation Criterion 5: Git-measured baselines (not estimated)
if grep -q 'git show' .planning/phases/28-context-budget-regression/FINDINGS.md && grep -q 'dd606b1' .planning/phases/28-context-budget-regression/FINDINGS.md; then
  echo "PASS: Baselines measured from git history (references git show and commit hash)"; ((PASS++))
else
  echo "FAIL: Baselines not measured from git history"; ((FAIL++))
fi

# Remediation Criterion 6: v1.7.x vs v1.8.x comparison table
if grep -q 'v1.7.1 Lines' .planning/phases/28-context-budget-regression/FINDINGS.md || grep -q 'v1.7.1.*v1.8' .planning/phases/28-context-budget-regression/FINDINGS.md; then
  echo "PASS: v1.7.x vs v1.8.x comparison table present"; ((PASS++))
else
  echo "FAIL: v1.7.x vs v1.8.x comparison table missing"; ((FAIL++))
fi

# Remediation Criterion 7: Per-agent context consumption analysis
if grep -q 'Per-Agent Context' .planning/phases/28-context-budget-regression/FINDINGS.md && grep -q 'Est. Tokens' .planning/phases/28-context-budget-regression/FINDINGS.md; then
  echo "PASS: Per-agent context consumption analysis present"; ((PASS++))
else
  echo "FAIL: Per-agent context consumption analysis missing"; ((FAIL++))
fi

# Remediation Criterion 8: Top 3 highest-cost agents with reduction strategies
if grep -q 'Top 3 Highest-Cost' .planning/phases/28-context-budget-regression/FINDINGS.md && grep -q 'Estimated savings' .planning/phases/28-context-budget-regression/FINDINGS.md; then
  echo "PASS: Top 3 highest-cost sections with reduction strategies present"; ((PASS++))
else
  echo "FAIL: Top 3 highest-cost sections with reduction strategies missing"; ((FAIL++))
fi

# Remediation Criterion 9: Specific deduplications with before/after line counts
if grep -q 'What Was Condensed' .planning/phases/28-context-budget-regression/FINDINGS.md && grep -q 'What Was Removed' .planning/phases/28-context-budget-regression/FINDINGS.md; then
  echo "PASS: Specific deduplications documented with before/after counts"; ((PASS++))
else
  echo "FAIL: Specific deduplications not documented with detail"; ((FAIL++))
fi

echo "RESULTS: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
