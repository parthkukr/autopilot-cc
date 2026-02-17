# Feature Research

**Domain:** Autonomous coding agent reliability and verification
**Researched:** 2026-02-17
**Confidence:** HIGH

## Feature Landscape

### Table Stakes (Users Expect These)

Features that must exist for the output to be trustworthy. Without these, every phase requires manual QA -- which defeats the purpose of autonomous execution.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Execution-based verification** | Pattern-matching (grep) cannot detect runtime bugs. The only way to know code works is to run it. Every serious agent (Devin, OpenHands, Aider) runs the code it generates. | HIGH | Requires detecting project type, finding/running compile/test/lint commands, parsing exit codes, and feeding errors back. This is the single most impactful feature -- everything else builds on it. |
| **Compile/build gate per task** | Code that does not compile is never correct. Committing broken code poisons downstream tasks. Aider's lint/test loop runs after every edit. | MEDIUM | Already partially exists in v1 (executor self-tests) but enforcement is advisory. Must become a hard gate: no commit without clean compile. |
| **Test execution gate** | Running existing tests catches regressions the agent introduced. SWE-bench Verified requires both FAIL_TO_PASS and PASS_TO_PASS tests to pass. Without this, agents "fix" one thing while breaking three others. | MEDIUM | Requires `npm test` / `pytest` / project-specific test runner. Must parse output for pass/fail count, not just exit code. |
| **Lint/format gate** | Agents generate code with style violations, unused imports, and formatting drift. Linters catch a class of bugs (unused variables, unreachable code) that compilation misses. | LOW | Low effort -- run linter, check exit code. Already in v1 playbook as SHOULD-level; needs to become MUST-level. |
| **Evidence-based verification reports** | Assertion-based verification ("I checked it") is the root cause of autopilot's 30-40% hit rate. Every claim must have a proof artifact: command output, exit code, file diff, or screenshot. Verdent and Warp treat verification as a "first-class stage, not an afterthought." | HIGH | Requires structured evidence format. Verifier must attach actual command output, not just "PASS". Judge and rating agent must evaluate evidence quality, not just presence. |
| **Self-correction loop (test-fix-retest)** | Agents that can iterate against error messages are dramatically more reliable. Devin's core value prop: "the magic of agents comes from their ability to fix their own mistakes." Claude Code's TDD loop (write code, run tests, read errors, fix, repeat) is the standard pattern. | HIGH | Already partially exists as remediation cycles. Needs to become per-task (not per-phase): fail fast, fix immediately, not after 5 tasks have been committed on top of a broken one. |
| **Git checkpoint before destructive changes** | Agents break things. Without rollback points, a bad edit cascades. Claude Code v2 added /rewind. Replit saves complete project state. mrq auto-checkpoints before every AI edit. This is universal. | LOW | Create a git tag or lightweight branch before each task execution. If task fails verification, reset to checkpoint. Trivial to implement, massive safety improvement. |
| **Structured planning with concrete acceptance criteria** | Vague plans produce vague code. SWE-bench research shows structured TODO lists prevent "model drift" and keep agents focused. Martin Fowler's research: agents that fill gaps with invented defaults corrupt outcomes. | MEDIUM | Already exists but quality is inconsistent. Plans need machine-verifiable criteria only -- no prose like "code is clean" or "handles errors properly." Every criterion must map to a command that returns pass/fail. |
| **Independent verification (blind verifier)** | The agent that wrote the code cannot objectively verify it -- confirmation bias. OpenHands uses a separate Reviewer agent. Autopilot v1 has this concept (judge + verifier + rater are separate from executor) but they currently read grep output, not execution output. | MEDIUM | Architecture exists. The fix is making verifier run actual commands (compile, test, lint) independently rather than reading executor's self-report. |
| **Project type detection and command discovery** | Different project types need different verification commands. A React app needs `npm run build`, a Python package needs `pytest`, a CLI tool needs integration tests. Agent must detect this automatically, not require manual config for basic cases. | MEDIUM | Read package.json scripts, Makefile targets, pyproject.toml, Cargo.toml. Fall back to manual `.planning/config.json` for non-standard setups. Devin and OpenHands both auto-detect. |

### Differentiators (Competitive Advantage)

Features that go beyond "code that compiles and passes tests" into "code I would actually ship." These are what separate a reliable agent from a merely functional one.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Visual verification (screenshot comparison)** | UI bugs survive every other verification method. A calendar renders wrong, a modal is mispositioned, a button is invisible -- tests pass, code compiles, but the user sees it immediately. Playwright's `toHaveScreenshot()` enables pixel-level comparison. The user's own calendar bug survived 4 phases because nobody looked at the screen. | HIGH | Requires Playwright/Puppeteer, headless browser, dev server management. First run generates baseline screenshots. Subsequent runs compare. Diff images highlight changes. Only needed for UI projects, but transformative for them. |
| **Automated test generation** | Existing tests only catch regressions. New features have zero test coverage by default. Agent should write tests for the code it generates, then run them. Claude Code's TDD pattern: write tests first, iterate until they pass. | HIGH | Must generate tests that are actually useful (not just `expect(true).toBe(true)`). Tests should exercise real logic, edge cases, error paths. The test-writing agent should NOT see the implementation to avoid tautological tests. |
| **Per-task verification loop (not per-phase)** | Current v1 runs 5 tasks, then verifies the whole phase. If task 2 broke something, tasks 3-5 build on a broken foundation. Per-task verification catches failures immediately while the context is fresh. Aider runs lint+test after every single edit. | MEDIUM | Already partially designed in v1 (mini-verify per task). Needs to become a hard loop: execute task -> compile -> test -> lint -> if fail: fix (max 2 retries) -> if still fail: rollback to checkpoint and report. |
| **Convergence detection in fix loops** | V1 remediation cycles can waste 3 full cycles on an unfixable 8.9 score. If score does not improve between cycles, stop. IBM's STRATUS agent detects when remediation is not converging and tries alternate strategies. | LOW | Compare score(cycle N) to score(cycle N-1). If delta < 0.5, declare convergence and accept current state. Saves 2 wasted cycles per stuck phase. |
| **Code review subagent** | SWE-bench top performers use dedicated code-review subagents. Catches AI-generated anti-patterns: over-engineering, abstraction bloat, unused code, security vulnerabilities. Martin Fowler's research found SonarQube-level static analysis catches critical issues agents introduce. | MEDIUM | Spawn a review agent that reads git diff and checks for: unused imports/variables, excessive complexity, duplicated code, security anti-patterns, style violations beyond what linters catch. Returns actionable feedback to executor before commit. |
| **Regression detection (PASS_TO_PASS)** | SWE-bench requires PASS_TO_PASS: tests that passed before the change must still pass after. Agents that fix one thing while breaking three others are net-negative. | MEDIUM | Run full test suite before and after each phase. Compare results. Any newly-failing test is a regression that must be fixed before declaring done. Requires test suite to exist (or be generated). |
| **Knowledge persistence across phases** | Devin maintains a "permanent knowledge base" of project patterns. Learned mistakes in phase 3 should prevent the same mistake in phase 7. Currently v1 resets learnings each run. | MEDIUM | Already exists as `.autopilot/learnings.md` but resets per run. Keep a curated top-10 across runs. Deduplicate similar rules. Phase-runner reads before each task. |
| **Sandbox execution environment** | Devin runs everything in isolated containers. OpenHands uses Docker. Running agent-generated code on the user's machine risks breaking the dev environment. Sandbox provides clean, reproducible execution. | HIGH | Docker container per phase execution. Mount project directory. Run compile/test/build inside container. Capture output. Requires Docker availability -- may need graceful fallback to host execution. |
| **Predictive scope analysis** | V1's context budget is advisory-only. A phase with 10 tasks and 15 step agents can exhaust context before finishing. Predict context usage before execution starts. If predicted > 70% budget, split proactively. | MEDIUM | Count expected agent spawns, estimate context per spawn, compare to budget. Split request early rather than discovering mid-execution. Saves wasted tokens and partial work. |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems. Deliberately NOT building these.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| **Real-time streaming dashboard / web UI** | Users want to watch progress in real-time | Adds massive complexity (websockets, frontend, process management) for two users. Claude Code's terminal output is sufficient. Building a UI is a project unto itself. | Structured progress lines in terminal output. Use `/autopilot:progress` for status checks. |
| **Unlimited autonomy (no human checkpoints)** | "Fire and forget" sounds like zero human involvement | Addy Osmani's research: agents amplify existing practices -- bad processes accumulate debt faster. Martin Fowler: "human in the loop remains essential." Unlimited autonomy without verification leads to codebases nobody understands. | Fire-and-forget for execution, but human reviews final output. Agent does the work; human approves the PR. Configurable autonomy levels per task type. |
| **Automatic dependency installation** | Agent discovers it needs a library and installs it | Supply chain risk. Agents install packages without checking licenses, CVEs, or organizational standards. A single `npm install malicious-package` in an autonomous loop is catastrophic. | Agent proposes dependencies in the plan. Plan-checker validates against allowlist. Installation requires explicit approval or pre-configured allow rules. |
| **Multi-model routing (use GPT for X, Claude for Y)** | Different models excel at different tasks | Adds API key management, cost tracking, prompt compatibility, and model-specific failure modes. Complexity explosion for marginal gains. autopilot runs on Claude Code which uses Claude -- embrace that constraint. | Optimize prompts for Claude. Use Claude's extended thinking for complex reasoning. Single model, well-tuned. |
| **Codebase-wide refactoring in a single phase** | "Rewrite the auth system" as one atomic operation | Agents degrade with long context sessions. Martin Fowler: "LLM generation results still become more hit and miss the longer a session becomes." Large refactors amplify assumption propagation. | Break large changes into 3-5 focused phases. Each phase has a clear boundary, testable independently. Modular changes with explicit integration points. |
| **Self-modifying agent prompts** | Agent improves its own instructions over time | Prompt drift is undebuggable. If the agent changes its own orchestration rules, failure modes become unpredictable. Learnings are the right abstraction -- fixed rules with variable data. | Learnings file for project-specific knowledge. Protocol files are human-maintained. Prompt improvements happen through explicit versioned releases. |
| **Retry-until-pass with no limit** | Keep trying until tests pass | Infinite loops burn tokens and money. An agent stuck on an unfixable bug will try the same wrong approach repeatedly. OpenAI's research shows single-attempt architectures are competitive. | Hard retry limits (2 per task, 3 per phase). Convergence detection. If stuck, report failure honestly rather than burning tokens. |
| **Visual "approval" UI for screenshots** | Show screenshots to user for manual approval | Defeats the purpose of autonomous verification. If the user has to look at every screenshot, they are the test suite again. | Automated baseline comparison. Pixel diff threshold. Agent self-reviews screenshots. Only surface screenshots to user when diff exceeds threshold. |

## Feature Dependencies

```
[Execution-based verification]
    |
    +--requires--> [Project type detection]
    |                  (must know what commands to run)
    |
    +--enables--> [Compile/build gate]
    |                 +--enables--> [Per-task verification loop]
    |
    +--enables--> [Test execution gate]
    |                 +--enables--> [Regression detection (PASS_TO_PASS)]
    |                 +--enables--> [Automated test generation]
    |
    +--enables--> [Lint/format gate]
    |
    +--enables--> [Evidence-based verification]
    |                 +--enables--> [Independent verification (blind verifier)]
    |
    +--enables--> [Self-correction loop]
                      +--requires--> [Git checkpoint]
                      +--enhanced-by--> [Convergence detection]

[Visual verification]
    +--requires--> [Project type detection] (must detect UI project)
    +--requires--> [Execution-based verification] (must run dev server)
    +--independent-of--> [Test execution gate] (parallel verification path)

[Automated test generation]
    +--requires--> [Test execution gate] (must be able to run generated tests)
    +--enhanced-by--> [Independent verification] (test writer should not see implementation)

[Code review subagent]
    +--independent-of--> [Execution-based verification] (static analysis, not execution)
    +--enhanced-by--> [Evidence-based verification] (review findings as evidence)

[Knowledge persistence]
    +--independent-of--> all other features (data layer, not execution)
    +--enhanced-by--> [Self-correction loop] (captures what was learned during fixes)

[Predictive scope analysis]
    +--independent-of--> all verification features
    +--enhances--> [Per-task verification loop] (prevents context exhaustion mid-loop)

[Sandbox execution]
    +--enhances--> [Execution-based verification] (safer execution environment)
    +--optional--> (graceful fallback to host execution)
```

### Dependency Notes

- **Execution-based verification requires Project type detection:** You cannot run `npm test` if you do not know the project uses npm. Detection is the foundation everything else builds on.
- **Self-correction loop requires Git checkpoint:** If the fix attempt makes things worse, you need to rollback. Without checkpoints, fix loops are one-directional (can only add more code, never undo).
- **Automated test generation requires Test execution gate:** Writing tests is useless if you cannot run them. The test generation feature is only valuable when paired with a working test runner.
- **Visual verification is a parallel path:** It does not depend on test execution. Some bugs are only visible, not testable. This is belt-and-suspenders with the test gate.
- **Predictive scope analysis enhances Per-task verification:** More verification per task means more context usage. Prediction prevents running out of budget mid-phase.

## MVP Definition

### Launch With (v1)

Minimum viable rebuild -- what is needed to move hit rate from 30-40% to 80%+.

- [x] **Execution-based verification** -- run compile, test, lint commands and check exit codes. This alone likely doubles the hit rate.
- [x] **Project type detection** -- auto-detect project type from package.json / Cargo.toml / pyproject.toml / Makefile. Fall back to `.planning/config.json`.
- [x] **Compile/build gate (hard, per-task)** -- no commit without clean compile. Blocks broken code from entering the repo.
- [x] **Test execution gate** -- run test suite, parse results, fail if any test regresses.
- [x] **Evidence-based verification** -- every verifier claim must include the command output that proves it. No more "I checked and it works."
- [x] **Self-correction loop (per-task)** -- execute -> compile -> test -> if fail: fix (max 2) -> if still fail: rollback.
- [x] **Git checkpoints** -- tag or branch before each task. Rollback target if fix loop exhausts retries.

### Add After Validation (v1.x)

Features to add once the core verification pipeline is proving reliable.

- [ ] **Visual verification** -- add when a UI project hits the "tests pass but it looks wrong" problem. Requires Playwright, dev server management, baseline screenshots.
- [ ] **Automated test generation** -- add when we see phases passing with zero new test coverage. Test writer agent that generates tests before the implementation agent writes code (TDD pattern).
- [ ] **Per-task verification loop** -- tighten the loop from "fix per phase" to "fix per task." Requires compile/test/lint gates to be working reliably first.
- [ ] **Code review subagent** -- add when we see patterns of over-engineering, abstraction bloat, or security issues in agent output.
- [ ] **Lint/format gate** -- promote from SHOULD to MUST once we have clean compile and test gates.
- [ ] **Convergence detection** -- add after we observe stuck remediation cycles in production. Simple score comparison, low effort.

### Future Consideration (v2+)

Features to defer until the core pipeline is battle-tested.

- [ ] **Sandbox execution** -- Docker-based isolation. Only matters when running untrusted code or when host environment contamination is a real risk.
- [ ] **Regression detection (PASS_TO_PASS)** -- full before/after test suite comparison. Requires test suite to exist (or test generation feature).
- [ ] **Knowledge persistence across runs** -- curated cross-run learnings. Current per-run reset is acceptable for now.
- [ ] **Predictive scope analysis** -- predict context exhaustion before it happens. Only matters for large phases (7+ tasks).

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Execution-based verification | HIGH | HIGH | P1 |
| Project type detection | HIGH | MEDIUM | P1 |
| Compile/build gate (hard) | HIGH | LOW | P1 |
| Test execution gate | HIGH | MEDIUM | P1 |
| Evidence-based verification | HIGH | HIGH | P1 |
| Self-correction loop (per-task) | HIGH | HIGH | P1 |
| Git checkpoints | HIGH | LOW | P1 |
| Structured planning (improved) | HIGH | MEDIUM | P1 |
| Independent verification (improved) | MEDIUM | MEDIUM | P1 |
| Per-task verification loop | HIGH | MEDIUM | P2 |
| Lint/format gate (hard) | MEDIUM | LOW | P2 |
| Visual verification | HIGH | HIGH | P2 |
| Automated test generation | HIGH | HIGH | P2 |
| Convergence detection | MEDIUM | LOW | P2 |
| Code review subagent | MEDIUM | MEDIUM | P2 |
| Regression detection (PASS_TO_PASS) | MEDIUM | MEDIUM | P3 |
| Knowledge persistence (cross-run) | MEDIUM | MEDIUM | P3 |
| Sandbox execution | LOW | HIGH | P3 |
| Predictive scope analysis | MEDIUM | MEDIUM | P3 |

**Priority key:**
- P1: Must have for launch -- without these, hit rate stays at 30-40%
- P2: Should have, add when P1 is proven -- takes hit rate from 80% to 95%+
- P3: Nice to have, future consideration -- polish and edge cases

## Competitor Feature Analysis

| Feature | Devin | OpenHands | Aider | Claude Code (native) | autopilot-cc v1 | autopilot-cc v2 (target) |
|---------|-------|-----------|-------|---------------------|-----------------|--------------------------|
| Sandbox execution | Cloud container | Docker container | None (host) | None (host) | None (host) | Deferred (P3) |
| Code execution | Full (shell + browser) | Full (Docker + browser) | Lint + test loop | Full terminal access | Advisory only | Hard gate (P1) |
| Test execution | CI/CD integration | Docker-based | After every edit | Manual (`npm test`) | Never runs tests | Automatic per-task (P1) |
| Visual verification | Browser in sandbox | BrowserGym | None | None | Config-based (broken) | Playwright-based (P2) |
| Self-correction | Error-driven iteration | Reviewer loop | Lint/test loop | Thinking + retry | 3 remediation cycles | Per-task fix loop (P1) |
| Test generation | Can write tests | Can write tests | None (runs existing) | Manual | Never | TDD pattern (P2) |
| Checkpoints | Full workspace state | Session snapshots | Git-based | /rewind command | State file only | Git tags per task (P1) |
| Knowledge persistence | Permanent knowledge base | Session context | None | CLAUDE.md | Resets per run | Cross-run learnings (P3) |
| Multi-agent verification | Single agent + CI | Programmer + Reviewer | Single agent | Single agent | Executor + Verifier + Judge + Rater (4 agents) | Same, with execution evidence (P1) |
| Planning | Dedicated planning mode | Step-oriented decomposition | None (direct edit) | Think before coding | Research + Plan + Plan-check | Same, with stricter criteria (P1) |
| Project type detection | Auto (cloud env) | Auto (Docker) | Auto (git + language) | Manual | Manual config.json | Auto-detect + fallback (P1) |

## Sources

- [Addy Osmani: The 80% Problem in Agentic Coding](https://addyo.substack.com/p/the-80-problem-in-agentic-coding) -- Anti-patterns, assumption propagation, comprehension debt
- [Martin Fowler: How Far Can We Push AI Autonomy in Code Generation](https://martinfowler.com/articles/pushing-ai-autonomy.html) -- False success declarations, brute force fixes, evidence-based verification
- [Devin: Coding Agents 101](https://devin.ai/agents101) -- Control loop architecture, knowledge management, CI integration
- [OpenHands Agent Framework](https://www.emergentmind.com/topics/openhands-agent-framework) -- Event-stream architecture, Docker sandbox, Programmer + Reviewer loop
- [LangChain: State of Agent Engineering](https://www.langchain.com/state-of-agent-engineering) -- 89% use observability, 32% cite quality as top barrier
- [Prompt Engineering: 2026 Playbook for Reliable Agentic Workflows](https://promptengineering.org/agents-at-work-the-2026-playbook-for-building-reliable-agentic-workflows/) -- Explicit planning, test-driven loops, human approval
- [HuggingFace: 2026 Agentic Coding Trends](https://huggingface.co/blog/Svngoku/agentic-coding-trends-2026) -- LLM-as-Judge, self-healing test loops, content-addressed artifacts
- [SWE-bench Verified (OpenAI)](https://openai.com/index/introducing-swe-bench-verified/) -- FAIL_TO_PASS and PASS_TO_PASS test methodology
- [Playwright Visual Comparisons](https://playwright.dev/docs/test-snapshots) -- `toHaveScreenshot()`, pixel-level baseline comparison
- [Claude Code TDD Pattern (Steve Kinney)](https://stevekinney.com/courses/ai-development/test-driven-development-with-claude) -- Red-green-refactor loop for autonomous agents
- [TDD Guard for Claude Code](https://github.com/nizos/tdd-guard) -- Automated TDD enforcement with multi-agent orchestration
- [IBM STRATUS: Undo Agent for Cloud](https://research.ibm.com/blog/undo-agent-for-cloud) -- Checkpoint + rollback architecture for autonomous agents
- [Faros AI: Best AI Coding Agents 2026](https://www.faros.ai/blog/best-ai-coding-agents-2026) -- Industry comparison and real-world reviews
- [Awesome Testing: AI Coding 2026 Hype vs Reality](https://www.awesome-testing.com/2026/02/ai-coding-2026-hype-vs-reality) -- Production reality of autonomous coding
- [ghuntley: Secure Codegen Anti-Patterns](https://ghuntley.com/secure-codegen/) -- Security-specific anti-patterns for AI code generation
- [Verdent: SWE-bench Verified Technical Report](https://www.verdent.ai/blog/swe-bench-verified-technical-report) -- Verification as first-class stage, structured TODO lists

---
*Feature research for: autonomous coding agent reliability and verification*
*Researched: 2026-02-17*
