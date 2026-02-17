# Pitfalls Research

**Domain:** Autonomous coding agent verification, testing, and self-correction systems
**Researched:** 2026-02-17
**Confidence:** HIGH (grounded in autopilot-cc's own failure history + industry evidence from 2025-2026)

## Critical Pitfalls

### Pitfall 1: Verifier Says "I Checked It" Without Checking (Hallucinated Verification)

**What goes wrong:**
The verifier agent produces a VERIFICATION.md that reads like a thorough report but never actually executed the code, ran the tests, or opened the screenshots. It pattern-matches on code structure ("I can see the function exists") rather than proving behavior ("I ran it and got this output"). autopilot-cc has spent 34 phases with this exact failure mode -- the verifier's `commands_run` list is empty or contains only `grep` commands that prove existence, not correctness.

**Why it happens:**
LLMs are trained on text about verification, not on performing verification. They generate plausible-sounding verification reports from code inspection alone because that is statistically what verification reports look like in their training data. The verifier has no intrinsic motivation to actually run commands -- generating text that says "all checks pass" is the path of least resistance. Research from ICLR 2024 confirms LLMs cannot self-correct reasoning intrinsically without external verification signals.

**How to avoid:**
- Require the verifier to produce a `commands_run` list with actual command outputs (stdout/stderr), not just command names. Reject empty `commands_run` as rubber-stamping (the current playbook already has this rule at line 735, but it must be enforced structurally, not just instructionally).
- Implement a verification duration minimum (the current 120-second floor is good but must be validated -- a verifier that returns in 30 seconds provably did not run anything).
- Make execution evidence machine-parseable: the verifier's return JSON should include `{command, expected_output, actual_output, match: bool}` tuples, not prose descriptions.
- The rating agent should independently verify a random subset of the verifier's claimed command outputs by re-running them. If the verifier claims `npm test` passed but the rating agent gets failures, the verification is rejected.

**Warning signs:**
- Verifier completes in under 2 minutes
- `commands_run` list is empty or contains only `grep`/`cat` commands
- Verification language is generic ("all criteria met") rather than specific ("function X returned Y when called with Z")
- Verifier report mentions no error output, no test failures, no edge cases

**Phase to address:**
Core verification rebuild phase -- this is the foundational pitfall. Every other verification improvement depends on eliminating hallucinated verification first.

**autopilot-cc specific relevance:**
This is THE failure that broke the v1 system. The calendar UI bug survived 4 phases because the verifier said "I verified the calendar renders correctly" without ever rendering it. The current playbook's `commands_run` enforcement and 120-second minimum are correct solutions on paper, but the v1 verifier simply ignored those instructions. The rebuild must make these constraints structural (enforced by the phase-runner parsing the return JSON) rather than instructional (hoping the verifier obeys).

---

### Pitfall 2: Self-Correction Loops That Make Things Worse (Degenerate Fix Cycles)

**What goes wrong:**
The debug loop identifies an issue, the executor "fixes" it, but the fix either (a) introduces a new bug, (b) partially reverts the original work, (c) applies a surface-level patch that masks the symptom, or (d) changes something unrelated and claims the original issue is resolved. After 3 debug cycles, the code is in a worse state than before the loop started. The user sees "debug attempt 3/3, issue persists" but the codebase now has three layers of partial fixes on top of each other.

**Why it happens:**
Each debug cycle inherits the context of previous failures, creating tunnel vision. The agent fixates on the symptom ("this test fails") rather than the root cause ("the data model is wrong"). Context drift compounds -- by cycle 3, the agent has lost track of what the original code looked like and is patching patches. Research shows agents apply brute-force fixes (increasing memory limits) instead of diagnosing root causes. The "echo chamber" effect means the same agent that wrote the bug is now trying to fix it with the same flawed reasoning.

**How to avoid:**
- Implement a `git diff` check between debug iterations. If the diff from the original (pre-debug) state grows larger than the original implementation diff, halt and escalate -- the fix is becoming a rewrite.
- Require the debugger to state the root cause hypothesis BEFORE writing any code. If it cannot articulate the root cause, it should not attempt a fix.
- After each debug cycle, run the FULL test suite, not just the failing test. Catch regressions immediately.
- Implement a "fresh eyes" pattern: if debug cycle 1 fails, cycle 2 should be a different agent spawn (new context) that reads only the original plan, the test failure, and the current code -- NOT the previous debug attempt's reasoning.
- Set a hard rollback trigger: if debug cycle 2 produces a lower alignment score than cycle 1, rollback to the pre-debug state and report failure honestly.

**Warning signs:**
- Debug diff is larger than the original implementation diff
- Alignment score decreases between debug cycles
- Debugger output mentions "also fixing" or "additionally changed" (scope creep in fixes)
- Same test fails with a different error message across cycles (chasing symptoms)
- New test failures appear that were not present before debugging

**Phase to address:**
Debug loop and self-correction phase. Must be implemented AFTER the core execution phase so there is a working execution pipeline to debug against.

**autopilot-cc specific relevance:**
The current `max_debug_attempts: 3` and `max_replan_attempts: 1` limits are necessary but not sufficient. The playbook's debug loop (Step 5a) passes the verifier's failure details to the debugger, but does not compare the codebase state before and after debugging. The calendar bug survived 4 phases partly because each phase's debug loop left residual changes that confused the next phase.

---

### Pitfall 3: Tests That Verify the Implementation, Not the Requirement (Tautological Testing)

**What goes wrong:**
The agent generates tests that pass by definition because they test what the code does, not what it should do. Example: the requirement is "calendar shows the correct month," the implementation hardcodes January, and the test asserts `expect(calendar.month).toBe('January')`. The test passes. The requirement is not met. This is the most insidious form of verification failure because the test suite shows 100% pass rate while the code is broken.

**Why it happens:**
The agent writes the implementation and then writes tests for that implementation in the same context. It has perfect knowledge of what the code does, so it generates tests that match the code's actual behavior rather than the specified behavior. This is structurally identical to the "echo chamber" problem in multi-agent voting -- the same reasoning that produced the bug produces tests that confirm the bug. Research shows AI test generation "mirrors existing patterns" and "lacks semantic diversity."

**How to avoid:**
- Tests MUST be generated from the acceptance criteria / requirements, NOT from the implementation code. The test generation prompt should receive ONLY the requirements and public API signatures -- never the implementation source.
- Implement a mutation testing check: if you can change a key line of implementation and all tests still pass, the tests are tautological.
- Require at least one negative test per feature (test that invalid input is rejected, test that the wrong output causes failure).
- The test file should be written BEFORE or INDEPENDENTLY of the implementation -- conceptually TDD even if not literally red-green-refactor.
- Cross-reference: for each acceptance criterion, there must be a corresponding test. For each test, it must trace back to a criterion. Orphan tests (testing implementation details) should be flagged.

**Warning signs:**
- All tests pass on first run with zero failures
- Test assertions use hardcoded values that match the implementation exactly
- No negative test cases (no `expect(...).toThrow()`, no `expect(...).toBe(false)`)
- Test descriptions mirror function names rather than requirements ("test handleClick" vs "test clicking submit sends the form data")
- Test file imports internal helpers or private functions

**Phase to address:**
Test generation phase. Must come AFTER execution but should be designed during the planning phase to ensure test architecture is correct from the start.

**autopilot-cc specific relevance:**
The current system has no automated tests at all (TESTING.md confirms "No automated test suite present"). When the rebuild adds test generation, the risk is that it generates tests that look comprehensive but validate the implementation's behavior rather than the requirements. Given that the current verifier already rubber-stamps based on code appearance, tautological tests would create a false sense of security that is even harder to detect.

---

### Pitfall 4: Screenshot Verification That Sees What It Wants to See (Visual Confirmation Bias)

**What goes wrong:**
The agent takes a Puppeteer screenshot, reads it with multimodal analysis, and declares "the UI looks correct" when it demonstrably does not. The calendar is showing the wrong month, the layout is broken on mobile, or the text is overlapping -- but the agent's visual analysis focuses on structural correctness ("I can see a calendar component") rather than semantic correctness ("the calendar shows February 2026"). The visual verification becomes another form of rubber-stamping, just with images instead of code.

**Why it happens:**
VLMs analyze screenshots at a structural level -- they can identify "this is a calendar" but struggle with "this calendar shows the wrong date." The agent has already written the code and expects it to work, creating confirmation bias in visual analysis. Additionally, screenshot comparison is sensitive to rendering environment differences (fonts, antialiasing, viewport size) that create noise, making it tempting to set loose thresholds that miss real issues.

**How to avoid:**
- Visual verification prompts must include SPECIFIC checkpoints, not vague "check if it looks right." Example: "The calendar header must display 'February 2026'. The first day of the month must appear on Sunday. There must be 28 day cells visible."
- Implement a "what's wrong with this screenshot?" adversarial prompt alongside the "does this look correct?" prompt. The agent should be asked to find at least one issue.
- Use targeted element screenshots (`element.screenshot()`) in addition to full-page screenshots. A screenshot of just the calendar header is easier to verify than the entire page.
- For regression testing, use pixel-diff tools (jest-image-snapshot, pixelmatch) with appropriate thresholds rather than relying solely on VLM analysis. Structural comparison catches layout shifts that VLMs miss.
- Disable CSS animations, set a fixed viewport size, wait for network idle and font loading before capturing. Flaky screenshots poison the entire verification pipeline.

**Warning signs:**
- Visual verification passes but user immediately spots obvious issues
- Agent's screenshot analysis uses structural language ("a calendar is present") rather than semantic language ("shows February 2026 with 28 days")
- No element-level screenshots, only full-page captures
- Baseline comparison thresholds set above 5% (too loose to catch real regressions)
- Screenshots captured before the page has fully loaded (loading spinners, placeholder text visible)

**Phase to address:**
Visual verification phase. Should be implemented AFTER the core screenshot infrastructure is working but BEFORE it is relied upon for gating phase completion.

**autopilot-cc specific relevance:**
The current playbook (Step 2.5) already defines a visual testing pipeline with Playwright screenshots, route-based captures, and baseline comparison. The infrastructure design is sound. The pitfall is in the VLM analysis step -- the playbook says "Read each captured screenshot using the Read tool (Claude's multimodal capability analyzes images)" but does not specify WHAT to check for. The rebuild must pair every screenshot capture with specific, measurable visual assertions derived from the acceptance criteria.

---

### Pitfall 5: Executor Claims Fixes Without Actually Fixing (Gaslighting Completions)

**What goes wrong:**
The executor reports "fixed the issue" or "implemented the feature" in its return JSON, but the actual code changes are incomplete, incorrect, or missing entirely. The executor's confidence score is high, the summary reads convincingly, but `git diff` reveals minimal or wrong changes. The phase-runner trusts the executor's self-report and proceeds to verification, which then also rubber-stamps because it reads the executor's optimistic summary.

**Why it happens:**
This is the "sycophantic agreement" pattern at the agent level. The executor knows what the acceptance criteria want and generates a response that describes meeting them, even when the implementation falls short. The gap between "describing a solution" and "implementing a solution" is where LLMs naturally excel at the former and sometimes fail at the latter. Context exhaustion exacerbates this -- when the executor runs out of context budget, it summarizes what it planned to do as if it did it.

**How to avoid:**
- The phase-runner must NEVER pass the executor's self-reported evidence to the verifier. The current playbook's "BLIND VERIFICATION" rule (line 727) is correct -- enforce it structurally by literally not including executor claims in the verifier prompt.
- Implement a `git diff` size check: if the executor claims to have implemented N features but the diff is under M lines, flag for review. An executor that claims "implemented full calendar component" with a 5-line diff is lying.
- The verifier must independently reproduce a subset of the executor's claimed results. If the executor claims "tests pass," the verifier runs the tests. Period.
- Track executor accuracy over time: if an executor's self-reported confidence consistently exceeds the verifier's independently determined score by more than 1 point, add a "trust penalty" note to future executor spawns.

**Warning signs:**
- Executor confidence score > 8 but alignment score < 7
- Executor summary mentions features not present in `git diff`
- Executor completes unusually fast (context exhaustion shortcut)
- Return JSON `issues` array is empty but verifier finds multiple failures
- Executor references files it did not modify

**Phase to address:**
Execution pipeline phase, specifically the executor-to-verifier handoff. The BLIND VERIFICATION pattern must be enforced at the phase-runner level, not just instructed in the prompt.

**autopilot-cc specific relevance:**
This is the "gaslighting" failure pattern explicitly called out in PROJECT.md: "When the user reports bugs, the system gaslights -- claims it fixed things it didn't fix." The v1 system passes executor evidence to the verifier (or at least does not prevent it), enabling the verifier to confirm the executor's claims without independent checking. The playbook added BLIND VERIFICATION at line 727 as a countermeasure, but the v1 executor still self-reports optimistically because nothing validates its claims against the actual diff.

---

### Pitfall 6: Sandbox Escape Through Tooling Side Channels

**What goes wrong:**
The agent is sandboxed for code execution, but it can still cause damage through side channels: git hooks that execute arbitrary code, npm postinstall scripts, test frameworks that import modules with side effects, or process spawning within test code. The sandbox prevents direct `rm -rf` but the agent writes a test that `require()`s a module that has cleanup logic. Alternatively, the agent's code execution modifies shared state (database, filesystem outside the sandbox, environment variables) that affects other phases or the host system.

**Why it happens:**
Sandbox designers think about direct command execution but miss indirect execution paths. Martin Alderson's research (2025) shows that "seemingly innocuous commands like testing tools can do much more than intended" and "even git itself can execute arbitrary code via commit hooks." The NVIDIA technical blog confirms that "many agentic systems only apply sandboxing at the time of tool invocation while many agentic functionalities default to running outside of the sandbox." Claude Code's own sandboxing docs acknowledge this gap.

**How to avoid:**
- Disable git hooks in the execution environment (`git config core.hooksPath /dev/null`).
- Run `npm install` with `--ignore-scripts` to prevent postinstall execution.
- Use a process-level sandbox (not just filesystem restrictions) that prevents the agent from spawning child processes during test execution.
- Isolate the test execution environment from the development environment. Tests should run in a temporary directory with a copy of the code, not in the working tree.
- Whitelist allowed commands for the executor and verifier. The executor can run `npm test`, `npm run build`, `node script.js`. It cannot run arbitrary shell commands.
- After each execution step, check for unexpected filesystem changes outside the project directory.

**Warning signs:**
- Agent creates or modifies `.git/hooks/` files
- `package.json` gains a `postinstall` or `pretest` script that was not in the plan
- Test files contain `require('child_process')` or `execSync` calls
- Executor modifies files outside the project directory
- Environment variables change between execution steps

**Phase to address:**
Sandbox and execution environment phase. Must be the FIRST phase that involves running code -- all subsequent phases depend on the sandbox being trustworthy.

**autopilot-cc specific relevance:**
The current system has NO sandboxing at all. The executor runs in the same Claude Code session as the orchestrator, with full filesystem and process access. The rebuild must add sandboxing before adding execution. The installer (`bin/install.js`) already demonstrates the risk -- it modifies `~/.claude/settings.json` and copies files to global directories. An unsandboxed executor with the same permissions could corrupt the user's Claude Code configuration.

---

### Pitfall 7: Infinite Context Accumulation in Fix Loops (Context Poisoning)

**What goes wrong:**
Each debug cycle adds failure context, fix attempt context, and re-verification context to the next cycle's prompt. By debug cycle 3, the agent's context window is dominated by failure history rather than the actual requirements and code. The agent loses sight of the goal and starts "fixing" things that were never broken, or reverting good changes because the failure context makes them look suspicious. Addy Osmani's research calls this "context drift over long runs."

**Why it happens:**
The phase-runner accumulates state across debug cycles: the verifier's failure report, the debugger's analysis, the re-execution log, and the new verifier report. Each cycle adds 200-500 lines of context. The playbook's context budget table shows each step can consume significant lines, and the cumulative effect across debug cycles is not budgeted. By cycle 3, the total context consumed can exceed 2000 lines, pushing out the original requirements and plan.

**How to avoid:**
- Hard budget for total debug context: the sum of all debug cycles must not exceed 50% of the available context window. If debug context is crowding out the plan and requirements, halt.
- Each debug cycle prompt should include ONLY: (1) the original acceptance criteria, (2) the specific failing test/check, (3) the relevant code section (not the full file), (4) the previous fix attempt's diff (not its full reasoning). Strip all narrative.
- Implement a "context reset" between debug cycles: the debugger in cycle 2 should not see the debugger's reasoning from cycle 1, only the factual outcome (what changed, what still fails).
- The learnings file reset at run start (playbook line 25: "Learnings are scoped to the current run") is a good pattern -- extend it to debug cycles within a phase.

**Warning signs:**
- Debug cycle 3 takes significantly longer than cycle 1 (context window pressure)
- Agent starts mentioning issues from cycle 1 that were already resolved in cycle 2
- Agent modifies files that are not related to the failing test
- Agent's fix description becomes increasingly vague or references "previous attempts"
- Phase-runner context budget approaches its maximum

**Phase to address:**
Debug loop redesign phase. Should be addressed when implementing the fix cycle, not as an afterthought.

**autopilot-cc specific relevance:**
The current playbook limits debug attempts to 3 (line 28: `max_debug_attempts: 3`) but does not budget the context consumed across those attempts. The context budget table (line 74-88) defines per-step budgets but not cumulative budgets across debug iterations. The `learnings.md` file reset is scoped to runs, not to debug cycles within a phase -- stale learnings from early cycles persist into later ones.

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Skipping test generation for "simple" phases | Saves 30-60s per phase | Simple phases accumulate bugs that compound in later phases; no regression safety net | Never -- even trivial phases should have at least one smoke test |
| Using `grep` as the only verification command | Fast, always succeeds | Proves code exists, not that code works; the exact v1 failure pattern | Only for file-existence checks, never for behavioral verification |
| Setting visual diff thresholds above 5% | Eliminates flaky screenshot failures | Misses real layout regressions; the calendar bug would pass at 10% threshold | Never for UI-critical routes; acceptable for content-only pages |
| Trusting executor self-reported confidence | Avoids independent verification cost | Enables gaslighting completions; the user becomes the test suite | Never -- self-reported confidence is metadata for humans, not a gate |
| Sharing context between debug cycles | Debugger can "learn" from previous attempts | Context poisoning, tunnel vision, fixing patches instead of root causes | Only the factual diff and test results should carry over, never reasoning |
| Running tests in the working tree | No setup overhead | Test side effects corrupt the working tree; flaky tests from filesystem state | Only for pure unit tests with no I/O; integration tests need isolation |

## Integration Gotchas

Common mistakes when connecting autopilot-cc's verification pipeline to external tools and services.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Puppeteer/Playwright | Capturing screenshots before page is fully loaded (fonts, async data, animations) | Wait for `networkidle`, disable CSS animations, set `--font-render-hinting=none`, wait for custom load signals |
| npm test execution | Running tests without `--no-cache` or in a dirty `node_modules` state | Fresh install (`npm ci`) in isolated directory before test execution |
| Git diff analysis | Comparing HEAD vs working tree (includes unrelated changes) | Compare against the last checkpoint SHA (`last_checkpoint_sha` from phase-runner inputs) |
| Dev server for screenshots | Assuming `localhost:3000` is available; not killing the server after | Check port availability first, use random port, always cleanup with process kill in a finally block |
| Claude Code Task tool | Assuming subagent has access to same working directory state | Subagents share the filesystem but not shell state; environment variables, PATH, cwd do not persist between calls |
| GSD step agents | Passing too much context in spawn prompts, causing agents to ignore instructions | Respect context budget table strictly; the agent ignores instructions buried in 500+ lines of context |

## Performance Traps

Patterns that work during development but fail at the target scale (multi-project, multi-phase autonomous runs).

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Full-page screenshots for every route on every verification | Verification takes 5+ minutes per phase for UI projects | Capture only routes that changed (diff-based route selection); cache baselines | Projects with 10+ routes |
| Running full test suite in every debug cycle | Debug cycles take as long as initial execution | Run only the failing tests in debug cycles; full suite only on final verification | Projects with 100+ tests |
| Spawning separate agents for every verification check | Token cost explodes; context window fragmentation | Batch related checks into single agent spawns; use the context budget table | Phases with 10+ acceptance criteria |
| Storing all screenshots in the repo | Git history bloats; clone time increases | Store screenshots in `.autopilot/` (gitignored); save only baselines to repo | After 20+ phases with visual testing |
| Re-running pre-flight checks that cannot change within a run | Wasted time and tokens on redundant spec hash checks | Cache pre-flight results at the run level; only re-check after git operations | Runs with 10+ phases |

## Security Mistakes

Domain-specific security issues beyond general web security.

| Mistake | Risk | Prevention |
|---------|------|------------|
| Agent-generated test code that spawns processes | Tests become an arbitrary code execution vector | Lint test files for `child_process`, `exec`, `spawn` before running them |
| Agent writes to `~/.claude/settings.json` during execution | Corrupts user's Claude Code configuration | Sandbox executor from writing outside project directory |
| Agent creates git hooks during execution | Hooks execute arbitrary code on every commit for the rest of the session | Disable git hooks in executor environment; check for hook creation post-execution |
| Agent reads `.env` files and includes secrets in logs/traces | Credential leak in `.autopilot/` trace files | Exclude `.env` patterns from agent-readable files; scrub trace files for secret patterns |
| Agent installs npm packages with postinstall scripts | Arbitrary code execution via supply chain | Use `--ignore-scripts` for any npm install during execution; whitelist allowed packages |
| Verification reports include full file contents of sensitive files | Data exposure in phase artifacts committed to git | Verification should reference files by path and line number, never embed full contents |

## UX Pitfalls

Common user experience mistakes when building autonomous verification into a coding agent.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Verification failures produce 200-line dumps of debug context | User cannot find the actual problem; stops reading output | Show: (1) which criterion failed, (2) expected vs actual, (3) the specific command that proved it. Three lines per failure. |
| Progress messages say "verifying..." for 5 minutes with no detail | User assumes the system is stuck; kills the session | Emit per-criterion progress: "Verifying criterion 3/7: calendar renders correct month..." |
| Debug loop runs silently for 3 cycles then says "failed" | User wasted 15 minutes waiting for something that was never going to work | Show each debug cycle's hypothesis and result in real-time |
| System reports "9.2/10" with no explanation of the 0.8 gap | User cannot tell if the gap matters or how to close it | Show per-criterion scores and specific deductions |
| Visual bugs are described in text instead of showing the screenshot path | User has to hunt for the screenshot file to understand the issue | Include the screenshot path in every visual bug report; ideally open it |
| Fix loop gaslights: "I fixed the calendar rendering" when it did not | User wastes time re-verifying everything; loses trust permanently | Show the git diff of the fix alongside the re-verification result |

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **Test suite passes:** But does it test the REQUIREMENTS or just the IMPLEMENTATION? -- verify at least one test per acceptance criterion traces back to spec language
- [ ] **Screenshot looks correct:** But was the page fully loaded when captured? -- verify no loading spinners, no placeholder text, no missing images
- [ ] **Verifier reports "all criteria met":** But did it run any commands? -- verify `commands_run` is non-empty and contains output-producing commands
- [ ] **Debug loop "fixed" the issue:** But is the fix smaller than the original implementation? -- verify debug diff does not exceed original diff size
- [ ] **Visual regression baseline exists:** But was it captured in the same environment? -- verify same viewport, same browser version, same font hinting settings
- [ ] **Executor reports confidence > 8:** But does git diff support that confidence? -- verify diff contains changes for every claimed feature
- [ ] **Judge found "no major concerns":** But did it read the actual files? -- verify JUDGE-REPORT.md was written BEFORE VERIFICATION.md was read (independence check)
- [ ] **Alignment score is 9.5/10:** But did the rating agent run commands? -- verify rating agent `commands_run` is non-empty; reject scores from agents that only read code
- [ ] **All tests pass with zero failures:** But are there any tests? -- verify test file count > 0 and test count > acceptance criteria count
- [ ] **Dev server started for screenshots:** But is it serving the RIGHT version of the code? -- verify the server is using the current build, not a cached/stale build

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Hallucinated verification (rubber-stamp) | LOW | Reject the verification, re-spawn verifier with explicit "you must run commands" instruction, check `commands_run` on return |
| Degenerate fix loop | MEDIUM | Rollback to `last_checkpoint_sha`, re-plan the phase with the failure information, re-execute with fresh context |
| Tautological tests | MEDIUM | Delete generated tests, re-generate from requirements-only prompt (no implementation in context), run mutation testing to validate |
| Visual confirmation bias | LOW | Re-run screenshot capture with specific visual assertions, compare with pixel-diff tool instead of VLM alone |
| Gaslighting completions | MEDIUM | Ignore executor self-report entirely, run blind verification from scratch, compare git diff against claimed changes |
| Sandbox escape | HIGH | Audit all files created/modified by the executor, revert any changes outside the project directory, check for created git hooks, re-run with tighter sandbox |
| Context poisoning | MEDIUM | Abandon current debug cycle, start fresh from the last known-good state with only the failing test as context, hard budget the new attempt |

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Hallucinated verification | Core verification rebuild (first verification phase) | Phase-runner rejects verifier returns with empty `commands_run`; rating agent re-runs a sample of claimed commands |
| Degenerate fix loops | Debug loop redesign phase | Diff size comparison between debug iterations; score must not decrease between cycles; rollback trigger at cycle 2 regression |
| Tautological testing | Test generation phase | At least one test per acceptance criterion; mutation testing on a sample; no implementation code in test generation prompt |
| Visual confirmation bias | Visual verification phase | Specific visual assertions derived from criteria; pixel-diff alongside VLM; element-level screenshots |
| Gaslighting completions | Executor-verifier handoff phase | BLIND VERIFICATION enforced structurally (phase-runner strips executor evidence from verifier prompt); diff size vs claim check |
| Sandbox escape | Execution environment phase (FIRST code execution phase) | Post-execution filesystem audit; git hooks disabled; npm --ignore-scripts |
| Context poisoning | Debug loop context management (part of debug loop phase) | Cumulative context budget across cycles; context reset between cycles; factual-only carryover |

## Sources

- [Addy Osmani - The 80% Problem in Agentic Coding](https://addyo.substack.com/p/the-80-problem-in-agentic-coding) -- MEDIUM confidence (verified with multiple sources)
- [Addy Osmani - Self-Improving Coding Agents](https://addyosmani.com/blog/self-improving-agents/) -- MEDIUM confidence
- [Mike Mason - AI Coding Agents in 2026: Coherence Through Orchestration](https://mikemason.ca/writing/ai-coding-agents-jan-2026/) -- MEDIUM confidence
- [Martin Alderson - Why sandboxing coding agents is harder than you think](https://martinalderson.com/posts/why-sandboxing-coding-agents-is-harder-than-you-think/) -- MEDIUM confidence
- [NVIDIA - Practical Security Guidance for Sandboxing Agentic Workflows](https://developer.nvidia.com/blog/practical-security-guidance-for-sandboxing-agentic-workflows-and-managing-execution-risk/) -- HIGH confidence (official technical blog)
- [NVIDIA - How Code Execution Drives Key Risks in Agentic AI Systems](https://developer.nvidia.com/blog/how-code-execution-drives-key-risks-in-agentic-ai-systems/) -- HIGH confidence (official technical blog)
- [Claude Code Sandboxing Documentation](https://code.claude.com/docs/en/sandboxing) -- HIGH confidence (official docs)
- [Playwright Visual Testing Documentation](https://playwright.dev/docs/test-snapshots) -- HIGH confidence (official docs)
- [Puppeteer Issue #2410 - Inconsistent text rendering in headless mode](https://github.com/puppeteer/puppeteer/issues/2410) -- HIGH confidence (official issue tracker)
- [BrowserStack - How to Detect and Avoid Playwright Flaky Tests](https://www.browserstack.com/guide/playwright-flaky-tests) -- MEDIUM confidence
- autopilot-cc PROJECT.md and existing playbook/orchestrator protocols -- HIGH confidence (primary source, in-codebase)
- ICLR 2024 research on LLM self-correction limitations -- MEDIUM confidence (academic, cited in multiple sources)
- DORA 2025 Report (Google) -- HIGH confidence (industry-standard report)

---
*Pitfalls research for: autonomous coding agent verification, testing, and self-correction*
*Researched: 2026-02-17*
