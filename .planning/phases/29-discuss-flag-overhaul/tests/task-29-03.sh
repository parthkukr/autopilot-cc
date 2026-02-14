#!/bin/bash
PASS=0; FAIL=0
CMD="src/commands/autopilot.md"

# Criterion: One-question-at-a-time mentioned in command definition
if grep -qi 'one.*question.*at.*a.*time\|one question at a time' "$CMD"; then echo "PASS: One-question-at-a-time mentioned"; ((PASS++)); else echo "FAIL: One-question-at-a-time mentioned"; ((FAIL++)); fi

# Criterion: Concrete options mentioned
if grep -qi 'concrete options\|concrete choices' "$CMD"; then echo "PASS: Concrete options mentioned"; ((PASS++)); else echo "FAIL: Concrete options mentioned"; ((FAIL++)); fi

echo "RESULTS: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
