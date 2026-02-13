#!/bin/bash
PASS=0; FAIL=0

# Criterion: Orchestrator Section 1.5 describes --quality for unexecuted phases
if grep -i 'unexecuted\|not.*executed\|standard pipeline' src/protocols/autopilot-orchestrator.md 2>/dev/null | grep -q -i 'quality'; then echo "PASS: --quality handles unexecuted phases"; ((PASS++)); else echo "FAIL: --quality does not handle unexecuted phases"; ((FAIL++)); fi

# Criterion: autopilot.md --quality mentions unexecuted
if grep -q 'unexecuted' src/commands/autopilot.md 2>/dev/null; then echo "PASS: autopilot.md mentions unexecuted"; ((PASS++)); else echo "FAIL: autopilot.md does not mention unexecuted"; ((FAIL++)); fi

# Criterion: No TODO/FIXME/HACK in source
BUG_COUNT=$(grep -r 'TODO\|FIXME\|HACK' src/ --include='*.md' 2>/dev/null | wc -l)
if [ "$BUG_COUNT" -eq 0 ]; then echo "PASS: no bugs found ($BUG_COUNT markers)"; ((PASS++)); else echo "FAIL: $BUG_COUNT bug markers found"; ((FAIL++)); fi

echo "RESULTS: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
