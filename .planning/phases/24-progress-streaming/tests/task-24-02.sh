#!/bin/bash
PASS=0; FAIL=0
BASE="/mnt/c/Users/parth/OneDrive/Documents/GitHub/autopilot-cc"
FILE="$BASE/src/protocols/autopilot-playbook.md"

# Criterion 1: Progress Emission section exists
if grep -q 'Progress Emission' "$FILE"; then echo "PASS: Progress Emission section exists"; ((PASS++)); else echo "FAIL: Progress Emission section missing"; ((FAIL++)); fi

# Criterion 2: Step-level progress for each major pipeline step (at least 6)
COUNT=$(grep -c '\[Phase {N}\] Step:' "$FILE" 2>/dev/null || echo 0)
if [ "$COUNT" -ge 6 ]; then echo "PASS: Step-level progress for pipeline steps ($COUNT occurrences)"; ((PASS++)); else echo "FAIL: Step-level progress insufficient ($COUNT, need >= 6)"; ((FAIL++)); fi

# Criterion 3: Task-number progress in per-task loop (at least 3 references)
COUNT=$(grep -c 'Task {task_id}' "$FILE" 2>/dev/null || echo 0)
if [ "$COUNT" -ge 3 ]; then echo "PASS: Task-number progress present ($COUNT occurrences)"; ((PASS++)); else echo "FAIL: Task-number progress insufficient ($COUNT, need >= 3)"; ((FAIL++)); fi

# Criterion 4: Compile gate results in task-level format
if grep -q 'compile.*PASS\|compile.*FAIL' "$FILE"; then echo "PASS: Compile gate results in task-level format"; ((PASS++)); else echo "FAIL: Compile gate results missing from task-level format"; ((FAIL++)); fi

# Criterion 5: File modification progress
if grep -qi 'modifying.*file\|file.*being modified\|modifying.*{file' "$FILE"; then echo "PASS: File modification progress present"; ((PASS++)); else echo "FAIL: File modification progress missing"; ((FAIL++)); fi

echo "RESULTS: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
