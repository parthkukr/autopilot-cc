# Phase 28: Context Budget Regression Investigation -- Summary

## What Was Done

Diagnosed the context exhaustion regression from v1.8.0 upgrades (Phases 17-26) and applied zero-risk deduplication fixes.

## Key Findings

- Protocol files grew 35.7% (from ~4,053 to 5,500 lines) across Phases 17-26
- The Tier 2 (phase-runner) playbook grew 46%, making it the primary context bottleneck
- Top 3 growth contributors: Visual Testing (+271 lines), Progress Streaming (+186 lines), Per-Task Verification (+170 lines)
- 174 lines (9.4%) of the playbook are UI-only dead weight loaded for all phase types

## Context Reduction Achieved

Applied Strategy B (deduplication) to the playbook:
- Reduced from 1,856 to 1,700 lines (-156 lines, -8.4% reduction)
- Estimated ~2,325 tokens saved per phase-runner context load
- All quality enforcement preserved (VRFY-01, BLIND VERIFICATION, CONTEXT ISOLATION)
- All pipeline step templates preserved

## What Changed

Modified file: `src/protocols/autopilot-playbook.md` (and installed copy at `~/.claude/autopilot/protocols/`)
- Condensed 8 verbose sections by referencing schemas instead of inlining definitions
- Removed redundant repetitions of the same concepts

## Remaining Opportunities

Strategy A (playbook modularization) could save an additional ~7,000 tokens (~18%) per non-UI phase but requires user discussion about architecture trade-offs. The investigation findings and open questions are documented in FINDINGS.md for user review.
