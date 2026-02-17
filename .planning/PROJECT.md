# autopilot-cc v2 Rebuild

## What This Is

An npm package that adds autonomous multi-phase development to Claude Code. It orchestrates a 3-tier agent hierarchy (orchestrator -> phase-runner -> step agents) to execute entire roadmaps without human intervention. The sub-agent architecture lets it stay within context windows while doing massive amounts of work — that part is revolutionary. But the code it produces is unreliable, the verification pipeline lies about what it checked, and the user ends up babysitting every phase. This rebuild makes the output actually work.

## Core Value

If autopilot says "done," the code works. Verified by actually running it — not by pattern-matching or self-reporting. Zero tolerance for rubber-stamped completions.

## Requirements

### Validated

- ✓ 3-tier orchestrator pattern (orchestrator -> phase-runner -> step agents) — existing, keep and improve
- ✓ Sub-agent context management (stays within context window for large codebases) — existing, revolutionary
- ✓ Crash recovery via idempotent state file — existing, keep and improve
- ✓ Global and local install support via npx — existing
- ✓ Uses unmodified GSD step agents (executor, planner, verifier, etc.) — existing
- ✓ Agent availability pre-flight check with restart guidance — existing

### Active

- [ ] 100% phase success rate — if it says done, the code actually runs correctly
- [ ] Real code execution — autopilot runs the code it generates and checks the output
- [ ] Automated test generation — writes and runs real tests for logic verification
- [ ] Visual verification — screenshots/Puppeteer for UI projects to catch what humans would see in 5 seconds
- [ ] Honest verification — verifier must prove claims with evidence, not just assert them
- [ ] Self-fixing loop — when tests or screenshots reveal issues, fix them before reporting done
- [ ] GSD-level questioning depth — ask better questions before building, don't rush in
- [ ] GSD-level plan quality — detailed, executable plans, not stub outlines
- [ ] GSD-level polish and UX — auto-read files silently, proactive suggestions, guide the user, feel finished
- [ ] Fire-and-forget execution — kick off a project, come back hours later, it's done and working
- [ ] Zero babysitting — never need to intervene between kickoff and completion
- [ ] Works across project types — web apps, full-stack, CLI tools, npm packages

### Out of Scope

- GUI/dashboard — CLI-only, no web UI for monitoring
- Multi-repo orchestration — one project at a time
- Enterprise features — built for personal use (user + brother), not teams
- Competitive analysis — not trying to match specific competitors

## Context

**Current state:** v1.9.0 on npm. 34 phases accumulated over months, 16 completed. Hit rate on code quality is ~30-40%. User runs 4+ projects in parallel and has to manually QA every single one. One project has a calendar UI bug that's survived 4 phases of attempted fixes because the system never actually renders and looks at what it built.

**The fundamental problem:** Autopilot writes code and says "done" without ever running it. The verification pipeline pattern-matches on code structure instead of executing it. When the user reports bugs, the system gaslights — claims it fixed things it didn't fix. The user becomes the test suite.

**What works well:**
- The 3-tier sub-agent architecture is genuinely innovative — nobody else does this
- Context window management through sub-agents enables massive codebases
- The npx install pattern and GSD integration are clean
- State/recovery system works

**What's broken:**
- Verification is theater — checks boxes without running code
- No real testing — never executes what it builds
- No visual verification — never sees what the user sees
- Fix loops are dishonest — claims fixes without actually fixing
- Prompts/protocols lack the polish and depth of GSD
- Plans are rushed — doesn't think through edge cases before building
- UX is janky — announces reads instead of just reading, no proactive guidance

**GSD as the quality bar:** GSD's polish is the target — auto-reads files silently, proactive suggestions, guides the user, makes the user feel like they did the work. Autopilot should feel like a better GSD that runs autonomously.

**Ecosystem:** Depends on get-shit-done-cc >= 1.15.0 for step agents. No external runtime dependencies beyond Node.js builtins. Puppeteer/Playwright needed for visual testing.

## Constraints

- **Architecture**: Preserve 3-tier pattern — orchestrator stays lean, phase-runners do the work
- **Dependencies**: Continue using unmodified GSD agents — all autopilot context inlined into spawn prompts
- **Platform**: Claude Code's Task tool is the only subagent mechanism
- **Compatibility**: Backward-compatible with existing .autopilot/ state files
- **Users**: Primarily two users (personal use) — optimize for power user workflow, not onboarding
- **Quality bar**: 100% — if done means done, then verification must be proof-based, not assertion-based

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Archive v1 planning, rebuild from scratch | 34 phases accumulated cruft, many irrelevant — clean slate needed | — Pending |
| Real code execution as core requirement | Pattern-matching verification has failed for months — the only way to know code works is to run it | — Pending |
| Both automated tests + visual verification | Logic bugs caught by tests, UI bugs caught by screenshots — belt and suspenders | — Pending |
| GSD quality as the bar, not just features | The polish, UX, and thoughtfulness of GSD is what makes it trustworthy — autopilot needs the same | — Pending |
| 100% success rate target | 90% still means 1-in-10 phases needs babysitting — unacceptable for fire-and-forget | — Pending |

---
*Last updated: 2026-02-17 after rebuild initialization*
