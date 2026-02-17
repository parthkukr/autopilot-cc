# Project Research Summary

**Project:** autopilot-cc — Autonomous coding agent self-verification rebuild
**Domain:** Agentic coding systems — code execution, automated testing, visual verification
**Researched:** 2026-02-17
**Confidence:** HIGH

## Executive Summary

autopilot-cc is a v1.9.0 autonomous coding agent orchestrator that has a documented 30-40% hit rate on delivered features. The core failure is that the system declares completion based on pattern-matching (grep, code inspection) rather than execution. Every serious competitor in this space — Devin, OpenHands, Aider — runs the code it generates. The rebuild is not a greenfield project; all the architectural infrastructure (schemas, protocols, file paths, multi-tier agent hierarchy) already exists. The gap is enforcement: the verifier is instructed to run commands but nothing structurally validates that it did. The fix is to make execution evidence a machine-parseable requirement at the phase-runner level, not an instruction the agent can ignore.

The recommended approach is an incremental, dependency-ordered rebuild. The foundation is project type detection and hard compile/lint gates per task — without these, nothing downstream is trustworthy. On top of that, sandbox execution enforcement turns the verifier's advisory command running into a mandatory gate. Test spec quality enforcement follows, turning the planner's existing `.sh` file generation into real executable assertions. The capstone of the core pipeline is evidence-based gate decisions, where the phase-runner rejects returns with empty `commands_run` lists. Visual verification — Playwright screenshots routed through a debug loop — is an independent capability that addresses the class of bugs invisible to code analysis.

The key risk is building too fast without validating the foundation. If the compile gate is not enforced before the test spec pipeline is built, broken code cascades through every verification step. If hallucinated verification is not eliminated before visual testing is added, visual verification becomes another form of rubber-stamping with images. The phase ordering in this summary is derived from the architecture research's dependency graph: each capability depends on the ones before it. Skipping ahead produces a system that looks complete but fails in production for the same reasons v1 does.

---

## Key Findings

### Recommended Stack

See `.planning/research/STACK.md` for full details.

autopilot-cc does not bundle test runners for target projects. Its job is to detect what the project uses and invoke it. The only new runtime dependencies it needs are for screenshot capture and process management. The key constraint driving all technology choices is ESM compatibility: autopilot-cc should stay CJS-compatible, which rules out execa (ESM-only since v6) in favor of Node.js built-in `child_process`. The Node.js minimum requirement should be bumped from `>=16.0.0` to `>=20.0.0` because Playwright requires Node 18+ and Node 18 reached EOL in April 2025.

**Core technologies:**
- `child_process` (Node built-in): Execute shell commands (compile, test, lint, build) — zero dependencies, timeout and killSignal built in, already in any Node environment
- `playwright-core@1.58.x`: Screenshot capture and visual verification for UI projects — cross-browser, built-in visual comparison, officially supported by Microsoft with active MCP integration
- `pixelmatch@7.1.0`: Pixel-level screenshot diff for cross-phase visual comparison — 150 lines, zero dependencies, used internally by Playwright's own `toHaveScreenshot()`
- `tree-kill@1.2.2`: Kill entire process trees (dev servers, watchers) — Node's `ChildProcess.kill()` only kills the shell process, not spawned descendants
- `pngjs@7.x`: PNG encode/decode for pixelmatch input — needed when comparing screenshots taken outside Playwright's test context
- `vitest@4.0.x` (dev dependency): Test runner for autopilot-cc's own tests — current standard for Node.js in 2026, 4x faster than Jest, native ESM + TypeScript support

**What to avoid:**
- `vm2`: Deprecated with critical sandbox escape CVE (2026-01) — use `child_process` with timeouts
- Docker-based sandboxing: Massive overhead, not available in all Claude Code environments — process-level isolation is sufficient for the threat model
- Puppeteer: Chrome-only, no built-in visual comparison — Playwright is the clear winner for this use case

### Expected Features

See `.planning/research/FEATURES.md` for full details, competitor comparison, and dependency graph.

The feature dependency graph is the most important output of the features research. Almost everything depends on execution-based verification, which itself depends on project type detection. This creates a strict build order: you cannot have meaningful test gates without execution, cannot have per-task fix loops without test gates, cannot have regression detection without a test gate that works reliably. Visual verification is an independent parallel track that does not depend on the test pipeline.

**Must have (P1 — table stakes, needed to move from 30-40% to 80%+ hit rate):**
- Execution-based verification — run compile/test/lint commands, check exit codes; the single highest-impact change
- Project type detection — auto-detect from `package.json` / `Cargo.toml` / `pyproject.toml` / `Makefile`; prerequisite for everything else
- Compile/build gate (hard, per-task) — no commit without clean compile; currently advisory, must become structural
- Test execution gate — run test suite, parse pass/fail; currently never runs
- Evidence-based verification — every verifier claim must include command output that proves it; no more "I checked and it works"
- Self-correction loop (per-task) — execute → compile → test → if fail: fix (max 2 retries) → if still fail: rollback
- Git checkpoints — tag or branch before each task; rollback target if fix loop exhausts retries

**Should have (P2 — takes hit rate from 80% to 95%+, add after P1 is proven):**
- Visual verification — Playwright screenshots for UI projects; catches bugs invisible to code analysis
- Automated test generation — TDD pattern; test writer must not see implementation to avoid tautological tests
- Per-task verification loop — tighten from "fix per phase" to "fix per task"
- Lint/format gate (promoted to MUST) — currently SHOULD in playbook
- Convergence detection — if alignment score does not improve between debug cycles, stop; prevents wasted cycles
- Code review subagent — static analysis for over-engineering, abstraction bloat, security patterns

**Defer (P3 — v2+, after core pipeline is battle-tested):**
- Sandbox execution (Docker) — full container isolation; process-level isolation is sufficient for current threat model
- Regression detection (PASS_TO_PASS) — full before/after test suite comparison; requires reliable test gate first
- Knowledge persistence across runs — cross-run learnings; current per-run reset is acceptable for now
- Predictive scope analysis — context budget prediction before execution; only matters for phases with 7+ tasks

**Anti-features (explicitly not building):**
- Real-time streaming dashboard/web UI — massive complexity for marginal value
- Unlimited autonomy without checkpoints — amplifies bad practices
- Automatic dependency installation — supply chain risk without explicit approval
- Multi-model routing — complexity explosion for marginal gains with Claude

### Architecture Approach

See `.planning/research/ARCHITECTURE.md` for full data flow diagrams, component boundaries, and build order.

The existing 3-tier architecture (orchestrator → phase-runner → step agents) is sound and does not need restructuring. No new files or directories are needed — all schemas, protocols, and file locations already exist. The rebuild is about strengthening enforcement. The critical architectural invariant is blind verification: three independent agents (verifier, judge, rating agent) must all run their own commands. The verifier does NOT receive executor evidence. The judge does NOT receive verifier conclusions. The rating agent is context-isolated from all other agents. Any deviation from this pattern is the fox-guarding-the-henhouse anti-pattern.

**Major components (existing, roles being strengthened):**
1. **Orchestrator (T1)** — Loop control, state persistence, remediation cycles; gains: validates `visual_testing` config before spawning, routes visual issues into debug loop
2. **Phase-runner (T2)** — Pipeline sequencing, context budget enforcement, evidence routing; gains: rejects returns with empty `commands_run`, enforces execution evidence in gate decisions, routes visual bugs to debugger
3. **Planner (T3)** — Task decomposition, acceptance criteria; gains: generates real executable test specs (`.sh` files) with actual assertions referencing `project.commands.*`
4. **Executor (T3)** — Code writing; gains: hard compile + lint gates before every commit (not advisory), reports build output as structured evidence
5. **Verifier (T3)** — Blind verification; gains: Step 1.5 becomes mandatory (not optional) when commands configured, Step 1.7 runs test specs as primary evidence, Step 2.5 captures screenshots for UI phases
6. **Judge (T3)** — Independent spot-checks; gains: explicitly runs own git diff and verification commands, never receives verifier conclusions
7. **Rating Agent (T3)** — Context-isolated scoring; gains: must run own verification commands, test spec results are primary scoring evidence, rejects scoring from code-reading-only analysis
8. **Debugger (T3)** — Fix application; gains: receives `VISUAL-BUGS.md` alongside functional failures, re-runs screenshots after fixes

**Key patterns:**
- Evidence chain: execution output (exit codes, stdout/stderr) flows upward through tiers as structured data, not prose
- Test spec as ground truth: planner-generated `.sh` files are PRIMARY verification evidence, overriding grep-based checks
- Visual testing as enhancement not gate: infrastructure failure (Playwright not installed) gracefully skips; visual bugs when found DO enter debug loop
- Mini-verification per task: runs only task-specific test spec (fast, seconds); full test suite runs once in VERIFY step (not per-task)

### Critical Pitfalls

See `.planning/research/PITFALLS.md` for full prevention strategies, warning signs, and recovery steps.

1. **Hallucinated verification (rubber-stamping)** — Verifier generates a plausible verification report without running any commands. Prevention: phase-runner structurally rejects returns with empty `commands_run`; rating agent re-runs a sample of claimed commands independently; minimum verification duration of 120 seconds enforced and validated. This is THE foundational pitfall — all other verification improvements depend on eliminating it first.

2. **Gaslighting completions (executor lies about what it built)** — Executor reports "implemented X" but git diff shows minimal or wrong changes. Prevention: BLIND VERIFICATION enforced structurally (phase-runner strips executor evidence from verifier prompt, not just instructionally); diff size check against claimed features; verifier independently reproduces a subset of executor's claimed results.

3. **Degenerate fix loops (debugging makes things worse)** — Each debug cycle adds failure context until the agent loses sight of the original requirements and is patching patches. Prevention: `git diff` size check between cycles (if growing larger than original implementation, halt); context reset between cycles (cycle 2 debugger does not see cycle 1's reasoning, only factual diff and test results); score regression trigger (if score decreases between cycles, rollback to checkpoint).

4. **Tautological testing (tests verify the implementation, not the requirement)** — Agent writes tests that pass by definition because they test what the code does rather than what it should do. Prevention: test generation prompt must receive ONLY requirements and API signatures, never implementation source; at least one negative test per feature; every test must trace back to an acceptance criterion.

5. **Visual confirmation bias (screenshot verification sees what it wants to see)** — VLM analyzes screenshot structurally ("a calendar is present") rather than semantically ("calendar shows February 2026 with 28 days"). Prevention: visual verification prompts must include specific measurable checkpoints derived from acceptance criteria, not vague "check if it looks right"; adversarial "what's wrong with this screenshot?" prompt alongside positive check; element-level screenshots in addition to full-page; pixel-diff tools alongside VLM analysis.

6. **Sandbox escape through tooling side channels** — Git hooks, npm postinstall scripts, or test code spawning processes can execute arbitrary code even in a sandboxed environment. Prevention: disable git hooks in executor environment (`git config core.hooksPath /dev/null`); `npm install --ignore-scripts`; post-execution filesystem audit for changes outside project directory; lint test files for `child_process`/`exec`/`spawn` before running them.

7. **Context poisoning in fix loops** — Cumulative debug context (failure history, fix attempts, re-verification logs) crowds out original requirements by cycle 3. Prevention: hard budget for total debug context (sum across cycles < 50% of context window); each debug cycle receives only: original criteria, failing test, relevant code section, previous diff (not reasoning); `learnings.md` reset extends to debug cycles within a phase.

---

## Implications for Roadmap

The build order is driven by the dependency graph from ARCHITECTURE.md. Each capability depends on those above it in the stack. Building visual testing before compile gates work is wasted effort — visual bugs cannot be reliably diagnosed when the underlying code pipeline is not trustworthy.

### Phase 1: Project Detection and Configuration Foundation
**Rationale:** Everything depends on knowing what commands to run. This is the prerequisite for all execution. `config.json` `project.commands.*` must be reliably populated before any execution gate can work. Covers the build order's "Foundation Layer" items 1-2.
**Delivers:** Reliable `project.commands.compile`, `.test`, `.lint`, `.build` from auto-detection (package.json scripts, Makefile, pyproject.toml, Cargo.toml) with `.planning/config.json` as override/fallback
**Addresses:** Project type detection (P1), Compile/build gate (P1)
**Avoids:** "Cannot run tests without knowing project uses npm" dependency failure

### Phase 2: Executor Compile and Lint Gates
**Rationale:** Broken code must not enter the repo. Once commands are reliably configured (Phase 1), the executor must be forced to run them before every commit. This is currently advisory text — it needs to become a structural gate enforced by the phase-runner reading the executor's return JSON and rejecting commits without compile evidence.
**Delivers:** Hard per-task compile and lint enforcement; no code enters git without passing both gates; executor returns structured `{compile_result, lint_result}` evidence
**Addresses:** Compile/build gate hard enforcement (P1)
**Avoids:** Gaslighting completions pitfall; broken code cascading through downstream tasks
**Research flag:** Standard patterns — compile/lint gating is well-documented

### Phase 3: Sandbox Execution Enforcement
**Rationale:** Once the executor has working compile gates, the verifier needs to run commands reliably and safely. Sandbox enforcement (command whitelisting, filesystem audit, git hook disabling, npm `--ignore-scripts`) must be in place before the verifier is required to execute commands, otherwise execution becomes a security risk. Covers build order item 3.
**Delivers:** Pre-execution command validation against blocklist; post-execution filesystem audit; git hooks disabled; `npm install --ignore-scripts`; structured `{command, exit_code, stdout, stderr}` evidence format
**Addresses:** Evidence-based verification (P1), sandbox enforcement
**Avoids:** Sandbox escape through tooling side channels pitfall

### Phase 4: Test Spec Quality Enforcement
**Rationale:** The planner already generates `.sh` test files but they are skeletal. Once the sandbox is trustworthy (Phase 3), these test specs can become real executable assertions. The quality bar: every spec must run, produce structured PASS/FAIL output, and gate phase progression. Covers build order item 4.
**Delivers:** Planner generates test specs with real assertions from acceptance criteria (not implementation code); verifier runs specs as primary evidence (Step 1.7); test spec output gates the rating agent's scoring
**Addresses:** Test execution gate (P1), evidence-based verification (P1)
**Avoids:** Tautological testing pitfall — spec generation prompt never receives implementation source
**Research flag:** Test spec generation patterns are reasonably documented, but quality enforcement heuristics may need iteration

### Phase 5: Evidence-Based Gate Decisions and Blind Verification Enforcement
**Rationale:** With working compile gates, sandbox execution, and test specs, the phase-runner can now structurally enforce blind verification. This phase makes the architectural invariant structural rather than instructional: phase-runner rejects returns with empty `commands_run`, strips executor evidence from verifier prompt, and validates rating agent ran its own commands. Covers build order items 5-6.
**Delivers:** Phase-runner structurally rejects rubber-stamped verification; BLIND VERIFICATION enforced by prompt construction (not instruction); rating agent must include `commands_run` evidence; minimum verification duration validated
**Addresses:** Independent verification (P1), evidence-based verification (P1)
**Avoids:** Hallucinated verification pitfall (THE foundational pitfall); gaslighting completions pitfall

### Phase 6: Self-Correction Loop with Git Checkpoints
**Rationale:** With a trustworthy execution pipeline, the per-task fix loop can be added safely. Git checkpoints before each task provide rollback targets. The loop: execute → compile → test → if fail: fix (max 2 retries) → if still fail: rollback to checkpoint and report. Convergence detection prevents the degenerate fix loop pitfall.
**Delivers:** Git tag/branch before each task execution; per-task test-fail-fix-retest loop (max 2 retries); convergence detection (score must not decrease between cycles); context reset between debug cycles (factual-only carryover); rollback to checkpoint if fix loop exhausts retries
**Addresses:** Self-correction loop (P1), Git checkpoints (P1), Convergence detection (P2)
**Avoids:** Degenerate fix loops pitfall; context poisoning pitfall

### Phase 7: Visual Verification Pipeline
**Rationale:** With the core execution pipeline reliable, visual verification addresses the class of bugs invisible to code analysis — layout breaks, wrong data rendered, missing elements. This is the independent parallel track from the architecture research. Built after the core pipeline is proven to avoid compounding unreliable foundations with fragile infrastructure.
**Delivers:** Config-driven visual testing (`visual_testing.*` in config.json); orchestrator validates config before spawning; verifier Step 2.5 launches app + captures screenshots + analyzes with specific measurable assertions; VISUAL-BUGS.md generated when issues found; debugger receives visual bugs alongside functional failures; pixel-diff (pixelmatch) alongside VLM analysis; element-level screenshots for UI-critical components
**Stack:** Playwright (`playwright-core@1.58.x`), pixelmatch, pngjs, tree-kill
**Addresses:** Visual verification (P2)
**Avoids:** Visual confirmation bias pitfall — specific measurable checkpoints required, adversarial prompting, pixel-diff validation
**Research flag:** Playwright integration is well-documented. The VLM visual assertion prompting patterns are less documented — may need iteration to get specific enough to avoid confirmation bias.

### Phase 8: Advanced Verification Features
**Rationale:** Once the foundation is battle-tested, add the features that take hit rate from 80% to 95%+. These are all P2 features that depend on the P1 pipeline working reliably.
**Delivers:** Automated test generation (TDD pattern; test writer does not see implementation); per-task verification loop tightened; lint/format gate promoted from SHOULD to MUST; code review subagent for anti-pattern detection
**Addresses:** Automated test generation (P2), Per-task verification loop (P2), Code review subagent (P2)
**Avoids:** Tautological testing pitfall for generated tests
**Research flag:** Test generation quality patterns need deeper research — how to ensure generated tests have semantic diversity and trace to requirements, not implementation

### Phase Ordering Rationale

- Project detection must come first because every other capability derives commands from it
- Compile gates come before sandbox enforcement because you need trusted execution infrastructure before requiring execution
- Sandbox enforcement comes before mandatory execution gates because running commands without safety checks is a security risk
- Test specs come before evidence-based gates because the gates need something meaningful to enforce
- Blind verification enforcement comes after all evidence producers are working, because structural enforcement is only useful when evidence is actually being produced
- Git checkpoints and fix loops come after the verification pipeline is trustworthy, because a fix loop against unreliable verification is circular
- Visual verification is independent of the test pipeline but is built after it, because fragile infrastructure layered on an unreliable foundation compounds failures
- Advanced features come last, after the core is battle-tested

### Research Flags

**Phases likely needing deeper research during planning:**
- **Phase 4 (Test Spec Quality):** Quality enforcement heuristics for generated test specs — what makes a spec "real" vs skeletal — may need to research mutation testing approaches and how to validate spec quality automatically
- **Phase 7 (Visual Verification):** VLM visual assertion prompting patterns to prevent confirmation bias — specific wording of "find what's wrong" adversarial prompts, and optimal pixelmatch thresholds for different UI types
- **Phase 8 (Automated Test Generation):** Test semantic diversity metrics — how to detect tautological tests programmatically, mutation testing tooling compatibility

**Phases with standard patterns (skip or minimize research):**
- **Phase 1 (Project Detection):** Package manifest parsing is well-documented; standard patterns for detecting Jest vs Vitest vs pytest
- **Phase 2 (Compile/Lint Gates):** Straightforward protocol changes with well-understood patterns
- **Phase 3 (Sandbox Enforcement):** NVIDIA and Claude Code docs are comprehensive; patterns are clear
- **Phase 5 (Blind Verification):** Architectural pattern is clear from existing codebase and research; implementation is protocol modification
- **Phase 6 (Self-Correction Loop):** Git checkpoint patterns are standard; convergence detection is a simple score comparison

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Core technologies (child_process, Playwright, pixelmatch, tree-kill) are stable with official documentation. Only `@playwright/mcp` is pre-1.0 and rapidly iterating — pin version in MCP config. ESM vs CJS constraint is well-understood. |
| Features | HIGH | Derived from multiple independent sources (Devin, OpenHands, Aider, SWE-bench research, Addy Osmani, Martin Fowler). Competitor feature table provides strong triangulation. Priority matrix is well-grounded. |
| Architecture | HIGH | Primary source is the existing codebase itself — the architecture already exists and is well-understood. External sources confirm the blind verification and evidence chain patterns. Build order is derived directly from dependency analysis. |
| Pitfalls | HIGH | Grounded in autopilot-cc's own documented failure history (PROJECT.md, 34 phases of data) plus industry sources. The specific failure patterns (hallucinated verification, gaslighting completions) are observed, not hypothetical. |

**Overall confidence:** HIGH

### Gaps to Address

- **MCP server version stability:** `@playwright/mcp@0.0.x` is pre-1.0 and breaking changes happen between minor versions. The phase-runner protocol should treat Playwright MCP as optional enhancement, not required dependency. Document recommended version pinning strategy when implementing Phase 7.

- **Node.js minimum version update:** The package currently requires `>=16.0.0`. This needs to be updated to `>=20.0.0` as part of Phase 1 (before Playwright is added as a dependency). Validate that the installer and all current users are on Node 20+.

- **Visual assertion prompt quality:** The most uncertain part of the entire stack is how to write visual verification prompts that produce specific, non-confirming analysis. This is a prompt engineering problem, not a technology problem, and it will likely need empirical iteration. Phase 7 planning should budget for prompt tuning.

- **Test spec mutation testing integration:** To catch tautological tests, mutation testing (e.g., Stryker for JS) would provide strong validation. However, mutation testing adds significant test execution time. Whether to include it as part of Phase 4 or defer to Phase 8 is a tradeoff that needs evaluation during Phase 4 planning.

- **Config.json migration path:** The existing `.planning/config.json` format may not have `project.commands.*` populated for existing autopilot projects. Phase 1 must handle backward compatibility — auto-detection should populate the config if missing, not fail on missing keys.

---

## Sources

### Primary (HIGH confidence)
- Existing autopilot-cc codebase (`src/protocols/`, `src/agents/`, `.planning/PROJECT.md`) — primary source for architecture and pitfall history
- [Playwright official docs](https://playwright.dev/docs/screenshots) — screenshot API, visual comparisons
- [Node.js child_process docs](https://nodejs.org/api/child_process.html) — timeout, killSignal, maxBuffer options
- [Vitest 4.0 npm package](https://www.npmjs.com/package/vitest) — v4.0.18 latest stable
- [Node.js releases](https://nodejs.org/en/about/previous-releases) — LTS schedule, EOL dates
- [Claude Code official docs](https://code.claude.com/docs/en/how-claude-code-works) — agent architecture, MCP support
- [NVIDIA security guidance for agentic workflows](https://developer.nvidia.com/blog/practical-security-guidance-for-sandboxing-agentic-workflows-and-managing-execution-risk/) — sandbox pitfalls
- [Claude Code sandboxing documentation](https://code.claude.com/docs/en/sandboxing) — permission model

### Secondary (MEDIUM confidence)
- [Addy Osmani — The 80% Problem in Agentic Coding](https://addyo.substack.com/p/the-80-problem-in-agentic-coding) — anti-patterns, context drift, evidence-based verification
- [Martin Fowler — How Far Can We Push AI Autonomy](https://martinfowler.com/articles/pushing-ai-autonomy.html) — false success declarations, human-in-loop necessity
- [Devin: Coding Agents 101](https://devin.ai/agents101) — knowledge management, CI integration, checkpoint architecture
- [OpenHands Agent Framework](https://www.emergentmind.com/topics/openhands-agent-framework) — Docker sandbox, Programmer + Reviewer loop
- [SWE-bench Verified](https://openai.com/index/introducing-swe-bench-verified/) — FAIL_TO_PASS and PASS_TO_PASS methodology
- [IBM STRATUS](https://research.ibm.com/blog/undo-agent-for-cloud) — checkpoint + rollback architecture for autonomous agents
- [Playwright vs Puppeteer 2026](https://www.browserstack.com/guide/playwright-vs-puppeteer) — technology comparison
- [Martin Alderson — Why sandboxing coding agents is harder than you think](https://martinalderson.com/posts/why-sandboxing-coding-agents-is-harder-than-you-think/) — side channel attacks via tooling
- [BrowserStack — Playwright flaky tests](https://www.browserstack.com/guide/playwright-flaky-tests) — screenshot stability patterns

### Tertiary (LOW confidence / needs validation)
- ICLR 2024 research on LLM self-correction limitations — cited in multiple sources but needs direct validation
- [vm2 CVE-2026-01](https://thehackernews.com/2026/01/critical-vm2-nodejs-flaw-allows-sandbox.html) — avoid vm2; use child_process instead

---
*Research completed: 2026-02-17*
*Ready for roadmap: yes*
