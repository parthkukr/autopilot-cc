# Phase 28: Context Budget Regression Investigation -- Summary

## What Was Done

Diagnosed the context exhaustion regression from v1.8.0 upgrades (Phases 17-26) and applied zero-risk deduplication fixes. All baselines and growth figures are measured from git history using `git show` at version boundary commits.

## Key Findings (Git-Measured)

- Protocol files grew 33.2% (from 4,102 to 5,466 lines, measured at v1.7.1 commit dd606b1 vs v1.8.7 commit ac097ce)
- The Tier 2 (phase-runner) playbook grew 34.5% (1,380 to 1,856 lines), making it the primary context bottleneck
- Top 3 growth contributors: Visual Testing (+271 lines), Progress Streaming (+158 lines), Per-Task Verification (+153 lines)
- The phase-runner's total base cost is ~30,514 tokens (agent def + playbook read), consuming a significant portion of the context window before any work begins
- Top 3 highest-cost playbook sections: Verify (293 lines), Compose (228 lines), Execute (191 lines) -- totaling 712 lines (41.9% of playbook)

## Context Reduction Achieved

Applied Strategy B (deduplication) to the playbook:
- Reduced from 1,856 to 1,700 lines (-156 lines, -8.4% reduction)
- Estimated ~2,325 tokens saved per phase-runner context load
- Total protocol text reduced from 5,466 to 5,310 lines (net +29.4% from v1.7.1, down from +33.2%)
- All quality enforcement preserved (VRFY-01, BLIND VERIFICATION, CONTEXT ISOLATION)
- All pipeline step templates preserved

## What Changed

Modified file: `src/protocols/autopilot-playbook.md` (and installed copy at `~/.claude/autopilot/protocols/`)
- Condensed 8 verbose sections by referencing schemas instead of inlining definitions
- Specific deduplications documented with before/after line counts per section in FINDINGS.md Section 7

## Remaining Opportunities

Strategy A (playbook modularization) could save an additional ~7,000 tokens (~23%) per non-UI phase but requires user discussion about architecture trade-offs. The investigation findings, per-agent consumption analysis, and open questions are documented in FINDINGS.md for user review.
