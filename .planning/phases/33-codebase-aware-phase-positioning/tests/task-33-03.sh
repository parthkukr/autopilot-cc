#!/bin/bash
PASS=0; FAIL=0

# Criterion 1: Technical requirement matching logic
COUNT=$(grep -ci 'technical.*require\|require.*infrastructure\|deliverable.*match\|what.*phase.*need\|technically.*require' src/commands/autopilot/add-phase.md 2>/dev/null || echo "0")
if [ "$COUNT" -ge 1 ]; then echo "PASS: Technical requirement matching logic present"; ((PASS++)); else echo "FAIL: No technical requirement matching logic (count: $COUNT)"; ((FAIL++)); fi

# Criterion 2: Execution order considers dependencies
COUNT=$(grep -ci 'position.*after.*depend\|dependency.*position\|after.*last.*depend\|insert.*after.*depend' src/commands/autopilot/add-phase.md 2>/dev/null || echo "0")
if [ "$COUNT" -ge 1 ]; then echo "PASS: Execution order considers dependencies"; ((PASS++)); else echo "FAIL: Execution order does not consider dependencies (count: $COUNT)"; ((FAIL++)); fi

# Criterion 3: Warning for pending phase dependencies
COUNT=$(grep -ci 'pending.*phase.*warn\|warn.*pending\|not.*executed.*yet\|not.*completed.*depend\|depends.*pending' src/commands/autopilot/add-phase.md 2>/dev/null || echo "0")
if [ "$COUNT" -ge 1 ]; then echo "PASS: Warning for pending phase dependencies present"; ((PASS++)); else echo "FAIL: No warning for pending phase dependencies (count: $COUNT)"; ((FAIL++)); fi

# Criterion 4: Success criteria updated with codebase-awareness
COUNT=$(grep -ci 'overlap.*detect\|infrastructure.*aware\|codebase.*aware\|duplicate.*detect' src/commands/autopilot/add-phase.md 2>/dev/null || echo "0")
if [ "$COUNT" -ge 1 ]; then echo "PASS: Success criteria include codebase-awareness"; ((PASS++)); else echo "FAIL: No codebase-awareness in success criteria (count: $COUNT)"; ((FAIL++)); fi

echo "RESULTS: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
