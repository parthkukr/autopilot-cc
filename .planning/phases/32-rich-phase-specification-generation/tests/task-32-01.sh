#!/bin/bash
PASS=0; FAIL=0

# Criterion: Spec generation section exists
if grep -q 'Generate Rich Phase Specification' src/commands/autopilot/add-phase.md; then echo "PASS: Spec generation section exists"; ((PASS++)); else echo "FAIL: Spec generation section exists"; ((FAIL++)); fi

# Criterion: Goal generation requires minimum 2-3 sentences and goal-backward framing
if grep -qE '(goal-backward|2-3 sentences|minimum.*sentence)' src/commands/autopilot/add-phase.md; then echo "PASS: Goal generation has sentence and framing requirements"; ((PASS++)); else echo "FAIL: Goal generation has sentence and framing requirements"; ((FAIL++)); fi

# Criterion: Success criteria instructions require 3-5 criteria with specific/testable pattern
if grep -qE '(3-5 success criteria|specific and testable|Observable outcome.*how to verify)' src/commands/autopilot/add-phase.md; then echo "PASS: Success criteria instructions present"; ((PASS++)); else echo "FAIL: Success criteria instructions present"; ((FAIL++)); fi

# Criterion: Dependency analysis requires explaining WHY
if grep -qE '(explain WHY|WHY each dependency|dependency.*rationale)' src/commands/autopilot/add-phase.md; then echo "PASS: Dependency analysis requires WHY"; ((PASS++)); else echo "FAIL: Dependency analysis requires WHY"; ((FAIL++)); fi

# Criterion: Template uses generated_goal instead of [To be planned] stub
# The template section (detail section format) should contain {generated_goal}, not [To be planned]
if grep -q '{generated_goal' src/commands/autopilot/add-phase.md; then echo "PASS: Template uses generated_goal instead of stub"; ((PASS++)); else echo "FAIL: Template uses generated_goal instead of stub"; ((FAIL++)); fi

# Criterion: Template uses generated_criterion instead of [To be defined] stub
# The template section should contain {generated_criterion}, not [To be defined]
if grep -q '{generated_criterion' src/commands/autopilot/add-phase.md; then echo "PASS: Template uses generated criteria instead of stub"; ((PASS++)); else echo "FAIL: Template uses generated criteria instead of stub"; ((FAIL++)); fi

# Criterion: Task breakdown instructions present
if grep -qE '(2-5.*task|verb-phrase|preliminary task)' src/commands/autopilot/add-phase.md; then echo "PASS: Task breakdown instructions present"; ((PASS++)); else echo "FAIL: Task breakdown instructions present"; ((FAIL++)); fi

echo "RESULTS: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
