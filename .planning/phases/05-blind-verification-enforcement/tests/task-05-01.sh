#!/bin/bash
PASS=0; FAIL=0

# Criterion: Pre-spawn validation section exists in playbook
if grep -q 'Pre-Spawn Validation' src/protocols/autopilot-playbook.md; then echo "PASS: Pre-spawn validation section exists"; ((PASS++)); else echo "FAIL: Pre-spawn validation section missing"; ((FAIL++)); fi

# Criterion: Contamination markers defined in phase-runner (both direct and paraphrased)
if grep -q 'contamination marker\|Contamination marker' src/agents/autopilot-phase-runner.md; then echo "PASS: Contamination markers defined"; ((PASS++)); else echo "FAIL: Contamination markers not defined"; ((FAIL++)); fi

# Criterion: Cross-contamination detection logic defined
if grep -q 'cross_contamination_detection\|cross-contamination detection\|Cross-Contamination Detection' src/agents/autopilot-phase-runner.md; then echo "PASS: Cross-contamination detection defined"; ((PASS++)); else echo "FAIL: Cross-contamination detection not defined"; ((FAIL++)); fi

# Criterion: Post-return contamination check in playbook for verifier
if grep -A 5 'Contamination Check' src/protocols/autopilot-playbook.md | grep -qi 'verifier\|VERIFY'; then echo "PASS: Verifier contamination check exists"; ((PASS++)); else echo "FAIL: Verifier contamination check missing"; ((FAIL++)); fi

# Criterion: Post-return contamination check in playbook for judge
if grep -A 5 'Contamination Check' src/protocols/autopilot-playbook.md | grep -qi 'judge\|JUDGE'; then echo "PASS: Judge contamination check exists"; ((PASS++)); else echo "FAIL: Judge contamination check missing"; ((FAIL++)); fi

# Criterion: Post-return contamination check in playbook for rating
if grep -A 5 'Contamination Check' src/protocols/autopilot-playbook.md | grep -qi 'rating\|RATE'; then echo "PASS: Rating contamination check exists"; ((PASS++)); else echo "FAIL: Rating contamination check missing"; ((FAIL++)); fi

# Criterion: Max re-spawn limit documented
if grep -q 'Max 1 contamination re-spawn\|max 1 contamination\|Max.*1.*re-spawn.*contamination' src/protocols/autopilot-playbook.md; then echo "PASS: Max re-spawn limit documented"; ((PASS++)); else echo "FAIL: Max re-spawn limit not documented"; ((FAIL++)); fi

# Remediation Criterion: Paraphrased markers exist for verifier contamination (expanded markers)
if grep -qi 'executor indicated\|executor noted\|executor stated' src/agents/autopilot-phase-runner.md; then echo "PASS: Paraphrased verifier contamination markers exist"; ((PASS++)); else echo "FAIL: Paraphrased verifier contamination markers missing"; ((FAIL++)); fi

# Remediation Criterion: Paraphrased markers exist for judge contamination (expanded markers)
if grep -qi 'verifier indicated\|verifier noted\|verifier stated' src/agents/autopilot-phase-runner.md; then echo "PASS: Paraphrased judge contamination markers exist"; ((PASS++)); else echo "FAIL: Paraphrased judge contamination markers missing"; ((FAIL++)); fi

# Remediation Criterion: Paraphrased markers exist for rating agent contamination (expanded markers)
if grep -qi 'judge indicated\|judge noted\|judge stated' src/agents/autopilot-phase-runner.md; then echo "PASS: Paraphrased rating contamination markers exist"; ((PASS++)); else echo "FAIL: Paraphrased rating contamination markers missing"; ((FAIL++)); fi

# Remediation Criterion: False-positive exclusion section exists
if grep -qi 'false-positive exclusion\|False-positive exclusion' src/agents/autopilot-phase-runner.md; then echo "PASS: False-positive exclusion section exists"; ((PASS++)); else echo "FAIL: False-positive exclusion section missing"; ((FAIL++)); fi

# Remediation Criterion: False-positive safe patterns include procedural references
if grep -qi 'the verifier agent is spawned\|spawn the judge\|verifier prompt' src/agents/autopilot-phase-runner.md; then echo "PASS: Procedural safe patterns defined"; ((PASS++)); else echo "FAIL: Procedural safe patterns missing"; ((FAIL++)); fi

# Remediation Criterion: Playbook contamination checks reference paraphrased patterns
if grep -qi 'paraphrased patterns' src/protocols/autopilot-playbook.md; then echo "PASS: Playbook references paraphrased patterns"; ((PASS++)); else echo "FAIL: Playbook does not reference paraphrased patterns"; ((FAIL++)); fi

# Remediation Criterion: Playbook contamination checks reference false-positive exclusion
if grep -qi 'false-positive exclusion' src/protocols/autopilot-playbook.md; then echo "PASS: Playbook references false-positive exclusion"; ((PASS++)); else echo "FAIL: Playbook does not reference false-positive exclusion"; ((FAIL++)); fi

# False-positive resistance: legitimate process reference "the verifier agent is spawned" should be in safe patterns, not trigger contamination
# This test verifies the safe patterns list mentions this exact phrase
if grep -q 'the verifier agent is spawned' src/agents/autopilot-phase-runner.md; then echo "PASS: False-positive safe: 'the verifier agent is spawned' listed"; ((PASS++)); else echo "FAIL: False-positive safe: 'the verifier agent is spawned' not listed"; ((FAIL++)); fi

# False-positive resistance: "spawn the judge" should be in safe patterns
if grep -q 'spawn the judge' src/agents/autopilot-phase-runner.md; then echo "PASS: False-positive safe: 'spawn the judge' listed"; ((PASS++)); else echo "FAIL: False-positive safe: 'spawn the judge' not listed"; ((FAIL++)); fi

# False-positive resistance: "after the verifier returns" should be in safe patterns
if grep -q 'after the verifier returns' src/agents/autopilot-phase-runner.md; then echo "PASS: False-positive safe: 'after the verifier returns' listed"; ((PASS++)); else echo "FAIL: False-positive safe: 'after the verifier returns' not listed"; ((FAIL++)); fi

echo "RESULTS: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
