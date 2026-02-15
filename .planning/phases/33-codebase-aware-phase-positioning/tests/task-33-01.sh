#!/bin/bash
PASS=0; FAIL=0

# Criterion 1: Step 1.5 exists with overlap detection logic
COUNT=$(grep -c 'Step 1.5' src/commands/autopilot/add-phase.md 2>/dev/null || echo "0")
if [ "$COUNT" -ge 1 ]; then echo "PASS: Step 1.5 exists in add-phase.md"; ((PASS++)); else echo "FAIL: Step 1.5 not found in add-phase.md (count: $COUNT)"; ((FAIL++)); fi

# Criterion 2: Overlap detection reads existing phases from ROADMAP
COUNT=$(grep -ci 'existing.*phase.*ROADMAP\|ROADMAP.*existing.*phase\|existing.*roadmap.*phase\|read.*existing.*phase' src/commands/autopilot/add-phase.md 2>/dev/null || echo "0")
if [ "$COUNT" -ge 1 ]; then echo "PASS: Overlap detection reads existing phases from ROADMAP"; ((PASS++)); else echo "FAIL: No reference to reading existing phases from ROADMAP (count: $COUNT)"; ((FAIL++)); fi

# Criterion 3: Semantic overlap comparison described
COUNT=$(grep -ci 'semantic.*overlap\|semantic.*similar\|semantic.*compar' src/commands/autopilot/add-phase.md 2>/dev/null || echo "0")
if [ "$COUNT" -ge 1 ]; then echo "PASS: Semantic overlap comparison described"; ((PASS++)); else echo "FAIL: No semantic overlap comparison (count: $COUNT)"; ((FAIL++)); fi

# Criterion 4: insert-phase suggestion in warning options
COUNT=$(grep -c 'insert-phase' src/commands/autopilot/add-phase.md 2>/dev/null || echo "0")
if [ "$COUNT" -ge 1 ]; then echo "PASS: insert-phase suggestion present"; ((PASS++)); else echo "FAIL: No insert-phase reference (count: $COUNT)"; ((FAIL++)); fi

# Criterion 5: Overlap check applies to both paths (multiple references)
COUNT=$(grep -ci 'overlap' src/commands/autopilot/add-phase.md 2>/dev/null || echo "0")
if [ "$COUNT" -ge 3 ]; then echo "PASS: Overlap referenced $COUNT times (>= 3)"; ((PASS++)); else echo "FAIL: Overlap referenced only $COUNT times (need >= 3)"; ((FAIL++)); fi

echo "RESULTS: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
