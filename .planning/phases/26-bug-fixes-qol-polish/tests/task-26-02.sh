#!/bin/bash
PASS=0; FAIL=0

# Criterion: autopilot.md --discuss mentions gray areas or conversational
if grep -q -i 'gray area\|conversational\|per-area' src/commands/autopilot.md 2>/dev/null; then echo "PASS: --discuss description updated with new UX terms"; ((PASS++)); else echo "FAIL: --discuss description missing new UX terms"; ((FAIL++)); fi

# Criterion: autopilot.md --discuss mentions CONTEXT.md
if grep -q 'CONTEXT.md' src/commands/autopilot.md 2>/dev/null; then echo "PASS: CONTEXT.md referenced in autopilot.md"; ((PASS++)); else echo "FAIL: CONTEXT.md not referenced in autopilot.md"; ((FAIL++)); fi

# Criterion: If --discuss section describes new flow
COUNT=$(grep -A10 'If.*--discuss' src/commands/autopilot.md 2>/dev/null | grep -c -i 'gray area\|analysis\|CONTEXT.md')
if [ "$COUNT" -ge 1 ]; then echo "PASS: If --discuss section describes new flow"; ((PASS++)); else echo "FAIL: If --discuss section does not describe new flow"; ((FAIL++)); fi

# Criterion: Playbook discuss_context references CONTEXT.md
if grep -A3 'discuss_context' src/protocols/autopilot-playbook.md 2>/dev/null | grep -q 'CONTEXT.md'; then echo "PASS: Playbook discuss_context references CONTEXT.md"; ((PASS++)); else echo "FAIL: Playbook discuss_context does not reference CONTEXT.md"; ((FAIL++)); fi

# Criterion: Playbook research step mentions CONTEXT.md
if grep -B2 -A2 'CONTEXT.md' src/protocols/autopilot-playbook.md 2>/dev/null | grep -q -i 'research\|phase.*dir'; then echo "PASS: Playbook research step references CONTEXT.md"; ((PASS++)); else echo "FAIL: Playbook research step does not reference CONTEXT.md"; ((FAIL++)); fi

echo "RESULTS: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
