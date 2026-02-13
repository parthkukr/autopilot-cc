#!/bin/bash
PASS=0; FAIL=0

# Criterion: Section 1.7 contains Gray Area Analysis references
COUNT=$(grep -c -i 'gray.area\|Gray Area' src/protocols/autopilot-orchestrator.md 2>/dev/null)
if [ "$COUNT" -ge 3 ]; then echo "PASS: Gray Area references found ($COUNT occurrences)"; ((PASS++)); else echo "FAIL: Gray Area references insufficient ($COUNT < 3)"; ((FAIL++)); fi

# Criterion: Section 1.7 instructs presenting gray areas for user selection
if grep -q -i 'select.*area\|choose.*area\|pick.*area\|Which areas' src/protocols/autopilot-orchestrator.md 2>/dev/null; then echo "PASS: User selection of areas present"; ((PASS++)); else echo "FAIL: User selection of areas missing"; ((FAIL++)); fi

# Criterion: Per-area conversational probing
COUNT=$(grep -c -i 'per.area\|each.*area\|per area\|questions per area' src/protocols/autopilot-orchestrator.md 2>/dev/null)
if [ "$COUNT" -ge 2 ]; then echo "PASS: Per-area probing present ($COUNT occurrences)"; ((PASS++)); else echo "FAIL: Per-area probing insufficient ($COUNT < 2)"; ((FAIL++)); fi

# Criterion: Depth control
if grep -q -i 'more.*question\|move.*next\|next area\|More about' src/protocols/autopilot-orchestrator.md 2>/dev/null; then echo "PASS: Depth control present"; ((PASS++)); else echo "FAIL: Depth control missing"; ((FAIL++)); fi

# Criterion: Scope guardrail
COUNT=$(grep -c -i 'scope.*guardrail\|scope.*creep\|deferred.*idea\|Deferred Ideas' src/protocols/autopilot-orchestrator.md 2>/dev/null)
if [ "$COUNT" -ge 2 ]; then echo "PASS: Scope guardrail present ($COUNT occurrences)"; ((PASS++)); else echo "FAIL: Scope guardrail insufficient ($COUNT < 2)"; ((FAIL++)); fi

# Criterion: CONTEXT.md output instruction
if grep -q 'CONTEXT.md' src/protocols/autopilot-orchestrator.md 2>/dev/null; then echo "PASS: CONTEXT.md referenced"; ((PASS++)); else echo "FAIL: CONTEXT.md not referenced"; ((FAIL++)); fi

# Criterion: CONTEXT.md structure sections
COUNT=$(grep -c -i 'Phase Boundary\|Implementation Decisions\|Claude.*Discretion\|Deferred Ideas' src/protocols/autopilot-orchestrator.md 2>/dev/null)
if [ "$COUNT" -ge 3 ]; then echo "PASS: CONTEXT.md structure sections present ($COUNT)"; ((PASS++)); else echo "FAIL: CONTEXT.md structure sections insufficient ($COUNT < 3)"; ((FAIL++)); fi

# Criterion: Domain analysis heuristics
if grep -q -E 'SEE|CALL|RUN|READ|ORGANIZE' src/protocols/autopilot-orchestrator.md 2>/dev/null; then echo "PASS: Domain analysis heuristics present"; ((PASS++)); else echo "FAIL: Domain analysis heuristics missing"; ((FAIL++)); fi

echo "RESULTS: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
