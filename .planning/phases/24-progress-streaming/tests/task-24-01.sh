#!/bin/bash
PASS=0; FAIL=0
BASE="/mnt/c/Users/parth/OneDrive/Documents/GitHub/autopilot-cc"
FILE="$BASE/src/protocols/autopilot-orchestrator.md"

# Criterion 1: Progress Streaming Protocol subsection exists
if grep -q 'Progress Streaming Protocol' "$FILE"; then echo "PASS: Progress Streaming Protocol subsection exists"; ((PASS++)); else echo "FAIL: Progress Streaming Protocol subsection missing"; ((FAIL++)); fi

# Criterion 2: Phase header emitted before spawning
if grep -q 'PHASE.*phase_name\|PHASE.*{N}' "$FILE"; then echo "PASS: Phase header emission present"; ((PASS++)); else echo "FAIL: Phase header emission missing"; ((FAIL++)); fi

# Criterion 3: Step-level progress in results parsing
if grep -q 'Step:' "$FILE"; then echo "PASS: Step-level progress present"; ((PASS++)); else echo "FAIL: Step-level progress missing"; ((FAIL++)); fi

# Criterion 4: Machine-parseable format prefix
COUNT=$(grep -c '\-\-\- \[PHASE' "$FILE" 2>/dev/null || echo 0)
if [ "$COUNT" -ge 2 ]; then echo "PASS: Machine-parseable PHASE prefix found ($COUNT occurrences)"; ((PASS++)); else echo "FAIL: Machine-parseable PHASE prefix insufficient ($COUNT, need >= 2)"; ((FAIL++)); fi

echo "RESULTS: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
