#!/bin/bash
PASS=0; FAIL=0
ORCH="src/protocols/autopilot-orchestrator.md"

# Criterion: One-question-at-a-time pattern exists in Step 3
if grep -qi 'ONE question' "$ORCH"; then echo "PASS: One-question-at-a-time pattern exists"; ((PASS++)); else echo "FAIL: One-question-at-a-time pattern exists"; ((FAIL++)); fi

# Criterion: Concrete options format present (a) b) c) on separate lines)
if grep -q 'a) {concrete choice' "$ORCH"; then echo "PASS: Concrete options format present"; ((PASS++)); else echo "FAIL: Concrete options format present"; ((FAIL++)); fi

# Criterion: Old "Answer inline" pattern removed
if grep -q 'Answer inline' "$ORCH"; then echo "FAIL: Old Answer inline pattern removed (still found)"; ((FAIL++)); else echo "PASS: Old Answer inline pattern removed"; ((PASS++)); fi

# Criterion: Depth control after 4 questions
if grep -qi 'After.*4 questions' "$ORCH"; then echo "PASS: Depth control after 4 questions"; ((PASS++)); else echo "FAIL: Depth control after 4 questions"; ((FAIL++)); fi

# Criterion: Context-aware follow-ups mentioned
if grep -qi 'based on.*answer' "$ORCH"; then echo "PASS: Context-aware follow-ups"; ((PASS++)); else echo "FAIL: Context-aware follow-ups"; ((FAIL++)); fi

# Criterion: Gray area analysis returns question options (options in JSON schema)
if grep -q '"options"' "$ORCH"; then echo "PASS: Gray area analysis returns question options"; ((PASS++)); else echo "FAIL: Gray area analysis returns question options"; ((FAIL++)); fi

echo "RESULTS: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
