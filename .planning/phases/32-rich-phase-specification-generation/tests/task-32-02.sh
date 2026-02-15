#!/bin/bash
PASS=0; FAIL=0

# Criterion: Batch creation references spec generation methodology
COUNT=$(grep -c -E '(spec generation|Generate Rich Phase Specification|generated_goal|rich specification)' src/commands/autopilot/add-phase.md)
if [ "$COUNT" -ge 3 ]; then echo "PASS: Batch creation references spec generation ($COUNT occurrences)"; ((PASS++)); else echo "FAIL: Batch creation references spec generation (only $COUNT, need >= 3)"; ((FAIL++)); fi

# Criterion: Anti-parroting rule exists
if grep -qE '(anti-parroting|NOT simply restate|Do NOT.*restate|parroting)' src/commands/autopilot/add-phase.md; then echo "PASS: Anti-parroting rule exists"; ((PASS++)); else echo "FAIL: Anti-parroting rule exists"; ((FAIL++)); fi

# Criterion: Vague criteria blocklist exists
if grep -qE '(should work correctly|vague criteria|blocklist|properly handles)' src/commands/autopilot/add-phase.md; then echo "PASS: Vague criteria blocklist exists"; ((PASS++)); else echo "FAIL: Vague criteria blocklist exists"; ((FAIL++)); fi

# Criterion: Downstream consumer awareness instruction exists
if grep -qE '(downstream consumer|phase-runner.*can.*research.*plan|rich enough.*autopilot)' src/commands/autopilot/add-phase.md; then echo "PASS: Downstream consumer awareness present"; ((PASS++)); else echo "FAIL: Downstream consumer awareness present"; ((FAIL++)); fi

# Criterion: Success criteria section updated with rich spec criteria
COUNT2=$(grep -c -E '(rich.*spec|detailed Goal|verifiable success criteria|dependency.*rationale)' src/commands/autopilot/add-phase.md)
if [ "$COUNT2" -ge 2 ]; then echo "PASS: Success criteria section updated ($COUNT2 occurrences)"; ((PASS++)); else echo "FAIL: Success criteria section updated (only $COUNT2, need >= 2)"; ((FAIL++)); fi

# Criterion: No remaining "Define success criteria" guidance
if grep -q 'Define success criteria in ROADMAP' src/commands/autopilot/add-phase.md; then echo "FAIL: Still contains old 'Define success criteria' guidance"; ((FAIL++)); else echo "PASS: Old 'Define success criteria' guidance removed"; ((PASS++)); fi

echo "RESULTS: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
