#!/bin/bash
PASS=0; FAIL=0

# Criterion: New check exists in orchestrator
if grep -q 'Cross-contamination detection' src/protocols/autopilot-orchestrator.md; then echo "PASS: Cross-contamination check exists"; ((PASS++)); else echo "FAIL: Cross-contamination check missing"; ((FAIL++)); fi

# Criterion: VRFY-06 label assigned
if grep -q 'VRFY-06' src/protocols/autopilot-orchestrator.md; then echo "PASS: VRFY-06 label found"; ((PASS++)); else echo "FAIL: VRFY-06 label missing"; ((FAIL++)); fi

# Criterion: Check scans VERIFICATION.md
if grep -A 15 'Cross-contamination detection' src/protocols/autopilot-orchestrator.md | grep -q 'VERIFICATION.md'; then echo "PASS: Scans VERIFICATION.md"; ((PASS++)); else echo "FAIL: Does not scan VERIFICATION.md"; ((FAIL++)); fi

# Criterion: Check scans JUDGE-REPORT.md
if grep -A 15 'Cross-contamination detection' src/protocols/autopilot-orchestrator.md | grep -q 'JUDGE-REPORT.md'; then echo "PASS: Scans JUDGE-REPORT.md"; ((PASS++)); else echo "FAIL: Does not scan JUDGE-REPORT.md"; ((FAIL++)); fi

# Criterion: Check scans SCORECARD.md
if grep -A 15 'Cross-contamination detection' src/protocols/autopilot-orchestrator.md | grep -q 'SCORECARD.md'; then echo "PASS: Scans SCORECARD.md"; ((PASS++)); else echo "FAIL: Does not scan SCORECARD.md"; ((FAIL++)); fi

# Criterion: Check is WARNING not REJECT
if grep -A 10 'VRFY-06' src/protocols/autopilot-orchestrator.md | grep -qi 'WARNING'; then echo "PASS: Is WARNING level"; ((PASS++)); else echo "FAIL: Not WARNING level"; ((FAIL++)); fi

# Remediation Criterion: Orchestrator VRFY-06 includes paraphrased patterns
if grep -A 20 'VRFY-06' src/protocols/autopilot-orchestrator.md | grep -qi 'paraphrased patterns\|Paraphrased patterns'; then echo "PASS: VRFY-06 includes paraphrased patterns"; ((PASS++)); else echo "FAIL: VRFY-06 missing paraphrased patterns"; ((FAIL++)); fi

# Remediation Criterion: Orchestrator VRFY-06 has false-positive exclusion
if grep -A 30 'VRFY-06' src/protocols/autopilot-orchestrator.md | grep -qi 'false-positive exclusion\|False-positive exclusion'; then echo "PASS: VRFY-06 has false-positive exclusion"; ((PASS++)); else echo "FAIL: VRFY-06 missing false-positive exclusion"; ((FAIL++)); fi

# Remediation Criterion: Orchestrator VRFY-06 mentions "executor indicated" as expanded pattern
if grep -A 20 'VRFY-06' src/protocols/autopilot-orchestrator.md | grep -qi 'executor indicated'; then echo "PASS: VRFY-06 has expanded executor pattern"; ((PASS++)); else echo "FAIL: VRFY-06 missing expanded executor pattern"; ((FAIL++)); fi

# Remediation Criterion: Orchestrator VRFY-06 mentions "verifier indicated" as expanded pattern
if grep -A 20 'VRFY-06' src/protocols/autopilot-orchestrator.md | grep -qi 'verifier indicated'; then echo "PASS: VRFY-06 has expanded verifier pattern"; ((PASS++)); else echo "FAIL: VRFY-06 missing expanded verifier pattern"; ((FAIL++)); fi

# Remediation Criterion: Orchestrator VRFY-06 mentions "judge indicated" as expanded pattern
if grep -A 30 'VRFY-06' src/protocols/autopilot-orchestrator.md | grep -qi 'judge indicated'; then echo "PASS: VRFY-06 has expanded judge pattern"; ((PASS++)); else echo "FAIL: VRFY-06 missing expanded judge pattern"; ((FAIL++)); fi

echo "RESULTS: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
