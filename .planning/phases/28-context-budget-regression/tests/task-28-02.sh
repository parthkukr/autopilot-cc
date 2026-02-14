#!/bin/bash
PASS=0; FAIL=0

PLAYBOOK="/mnt/c/Users/Parth/.claude/autopilot/protocols/autopilot-playbook.md"

# Criterion 1: Playbook line count reduced by at least 40 lines (from 1856)
linecount=$(wc -l < "$PLAYBOOK")
if [ "$linecount" -le 1816 ]; then
  echo "PASS: Playbook line count reduced ($linecount lines, was 1856)"; ((PASS++))
else
  echo "FAIL: Playbook line count not sufficiently reduced ($linecount lines, need <= 1816)"; ((FAIL++))
fi

# Criterion 2: Trace aggregation section condensed
trace_lines=$(grep -A 20 'Trace Aggregation' "$PLAYBOOK" | wc -l)
if [ "$trace_lines" -le 12 ]; then
  echo "PASS: Trace aggregation condensed ($trace_lines lines)"; ((PASS++))
else
  echo "FAIL: Trace aggregation still too long ($trace_lines lines, need <= 12)"; ((FAIL++))
fi

# Criterion 3: Progress emission section exists (verify it wasn't accidentally deleted)
progress_line=$(grep -n 'Progress Emission' "$PLAYBOOK" | head -1 | cut -d: -f1)
if [ -n "$progress_line" ]; then
  echo "PASS: Progress emission section exists at line $progress_line"; ((PASS++))
else
  echo "FAIL: Progress emission section missing"; ((FAIL++))
fi

# Criterion 4: All pipeline step templates still exist
step_count=$(grep -c 'STEP [0-9]' "$PLAYBOOK")
if [ "$step_count" -ge 7 ]; then
  echo "PASS: All pipeline step templates present ($step_count found)"; ((PASS++))
else
  echo "FAIL: Pipeline step templates missing ($step_count found, need >= 7)"; ((FAIL++))
fi

# Criterion 5: Quality enforcement preserved
quality_count=$(grep -c 'VRFY-01\|BLIND VERIFICATION\|CONTEXT ISOLATION' "$PLAYBOOK")
if [ "$quality_count" -ge 3 ]; then
  echo "PASS: Quality enforcement markers preserved ($quality_count found)"; ((PASS++))
else
  echo "FAIL: Quality enforcement markers missing ($quality_count found, need >= 3)"; ((FAIL++))
fi

echo "RESULTS: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
