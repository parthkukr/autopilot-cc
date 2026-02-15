#!/bin/bash
PASS=0; FAIL=0

# Criterion 1: Infrastructure inventory from completed phases
COUNT=$(grep -ci 'infrastructure\|completed.*phase.*capabilit\|inventory' src/commands/autopilot/add-phase.md 2>/dev/null || echo "0")
if [ "$COUNT" -ge 2 ]; then echo "PASS: Infrastructure inventory references ($COUNT >= 2)"; ((PASS++)); else echo "FAIL: Infrastructure inventory references insufficient ($COUNT < 2)"; ((FAIL++)); fi

# Criterion 2: Infrastructure referenced in Goal generation
COUNT=$(grep -ci 'infrastructure.*Goal\|existing.*capabilit.*Goal\|leverage.*exist\|reference.*existing.*infrastructure\|infrastructure.*spec' src/commands/autopilot/add-phase.md 2>/dev/null || echo "0")
if [ "$COUNT" -ge 1 ]; then echo "PASS: Infrastructure referenced in Goal generation"; ((PASS++)); else echo "FAIL: No infrastructure reference in Goal generation (count: $COUNT)"; ((FAIL++)); fi

# Criterion 3: Technical dependency identification
COUNT=$(grep -ci 'technical.*depend\|infrastructure.*depend\|actual.*technical' src/commands/autopilot/add-phase.md 2>/dev/null || echo "0")
if [ "$COUNT" -ge 1 ]; then echo "PASS: Technical dependency identification present"; ((PASS++)); else echo "FAIL: No technical dependency identification (count: $COUNT)"; ((FAIL++)); fi

# Criterion 4: Completed phase status reading
COUNT=$(grep -ci '\[x\].*completed\|completed.*\[x\]\|marked.*completed\|marked with \[x\]' src/commands/autopilot/add-phase.md 2>/dev/null || echo "0")
if [ "$COUNT" -ge 1 ]; then echo "PASS: Completed phase status reading present"; ((PASS++)); else echo "FAIL: No completed phase status reading (count: $COUNT)"; ((FAIL++)); fi

echo "RESULTS: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
