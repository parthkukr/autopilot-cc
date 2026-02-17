# Stack Research

**Domain:** Autonomous coding agent self-verification (code execution, automated testing, visual verification)
**Researched:** 2026-02-17
**Confidence:** HIGH

## Context

autopilot-cc is an npm package (v1.9.0) that orchestrates Claude Code sub-agents through a 3-tier hierarchy (orchestrator -> phase-runner -> step agents). It currently writes code and declares "done" without ever running it. Verification is pattern-matching, not execution. This stack research covers the technologies needed to add real code execution, automated test running, and visual verification via screenshots to an existing Node.js CLI tool that runs inside Claude Code sessions.

**Key constraint:** autopilot-cc does not bundle test runners or browsers itself. It orchestrates Claude Code, which has Bash tool access. The stack here is what autopilot-cc's protocols instruct the agents to *use*, plus the minimal libraries autopilot-cc itself needs for screenshot comparison and process management.

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended | Confidence |
|------------|---------|---------|-----------------|------------|
| Node.js `child_process` (built-in) | Node 20+ | Execute shell commands (test runners, build tools, dev servers) from agent protocols | Zero dependencies. Already available in any Node.js environment. Claude Code's Bash tool uses this under the hood. autopilot-cc needs the same for verification steps. Built-in `timeout` and `killSignal` options handle runaway processes. | HIGH |
| Playwright | 1.58.x | Screenshot capture, visual verification, browser automation for web projects | Industry standard for cross-browser automation. Unified API across Chromium/Firefox/WebKit. `page.screenshot()` API is simple and reliable. Headless by default. Used by Microsoft's own Playwright MCP server. Playwright over Puppeteer because: multi-browser support, better auto-waiting, built-in `expect(page).toHaveScreenshot()` for visual comparisons. | HIGH |
| @playwright/mcp | 0.0.x (rapidly iterating) | MCP server giving Claude Code agents direct browser control | Official Microsoft MCP server. Claude Code already supports MCP tool discovery. Uses accessibility tree snapshots (2-5KB structured data) instead of screenshots for most interactions, falling back to screenshots for visual verification. This means agents can navigate and interact efficiently, then screenshot for visual proof. | MEDIUM |
| pixelmatch | 7.1.0 | Pixel-level image comparison for screenshot diffs | 150 lines, zero dependencies, works on raw typed arrays. The standard library for screenshot comparison in Node.js. Used internally by Playwright's own `toHaveScreenshot()`. For cases where autopilot-cc needs to compare screenshots outside of Playwright's test framework (e.g., comparing "before" and "after" screenshots across phases). | HIGH |
| tree-kill | 1.2.2 | Kill entire process trees (dev servers, watchers) | Node's `ChildProcess.kill()` only kills the shell process, not descendants spawned with `shell: true`. tree-kill handles this cross-platform (Linux: `ps -o pid`, macOS: `pgrep -P`, Windows: `taskkill /T`). Zero dependencies. Essential for cleaning up dev servers and watchers that agents start. | HIGH |

### Supporting Libraries

| Library | Version | Purpose | When to Use | Confidence |
|---------|---------|---------|-------------|------------|
| pngjs | 7.x | PNG encode/decode for pixelmatch input | When doing custom screenshot comparison outside Playwright's built-in assertions. pixelmatch operates on raw pixel data; pngjs converts PNG files to/from that format. | HIGH |
| strip-ansi | 7.x | Remove ANSI color codes from CLI output | When parsing test runner output to extract pass/fail counts. Test runners output colored text; agents need clean text for analysis. | MEDIUM |
| wait-on | 8.x | Wait for TCP ports, HTTP endpoints, files before proceeding | When an agent starts a dev server and needs to wait for it to be ready before running tests or taking screenshots. Prevents race conditions between server startup and verification. | MEDIUM |

### Development Tools

| Tool | Purpose | Notes | Confidence |
|------|---------|-------|------------|
| Vitest | 4.0.x | Test runner for autopilot-cc's own tests | Vitest 4 is the current standard for Node.js testing in 2026. 4x faster cold starts than Jest. Native ESM and TypeScript support. Built-in visual regression via `toMatchScreenshot()`. Stable browser mode. autopilot-cc's own test suite should use this. | HIGH |
| c8 | 10.1.x | Code coverage using V8's built-in coverage | Lightweight, uses Node.js native V8 coverage. No instrumentation needed. Works with any test runner including `node:test` and Vitest. | MEDIUM |

---

## Architecture Decision: What autopilot-cc Owns vs. What It Delegates

This is the most important architectural decision for the stack.

**autopilot-cc SHOULD NOT bundle test runners for target projects.** A target project might use Jest, Vitest, Mocha, pytest, cargo test, go test, or anything else. autopilot-cc's job is to:

1. **Detect** the project's test infrastructure (`npm test`, `package.json` scripts, Makefile targets, etc.)
2. **Execute** those tests via shell commands (using Node.js `child_process` or Claude Code's Bash tool)
3. **Parse** the output to determine pass/fail
4. **Report** results back to the orchestrator

**autopilot-cc SHOULD own:**
- Screenshot capture and comparison (Playwright + pixelmatch) for visual verification
- Process lifecycle management (tree-kill, timeouts, cleanup)
- Output parsing for common test runners (exit codes, TAP format, JUnit XML)

---

## Installation

```bash
# Core dependencies (autopilot-cc package itself)
npm install playwright-core pixelmatch pngjs tree-kill

# Dev dependencies (autopilot-cc development)
npm install -D vitest @vitest/coverage-v8 @playwright/test

# Playwright browsers (needed at install time for visual verification)
npx playwright install chromium
```

**Note on `playwright-core` vs `playwright`:** Use `playwright-core` (no bundled browsers, no test runner) since autopilot-cc manages browser installation separately and does not use Playwright Test for its own testing. Use `@playwright/test` only as a dev dependency for autopilot-cc's own tests if needed.

**Note on MCP server:** `@playwright/mcp` is NOT an npm dependency of autopilot-cc. It is configured as an MCP server in the user's Claude Code settings. autopilot-cc's protocols instruct users to set it up, but the package itself does not install or depend on it.

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| `playwright-core` | Puppeteer | Only if you need Chrome-only and want marginally faster short scripts (~30% for quick tasks). For autopilot-cc, Playwright's cross-browser support and built-in visual comparison make it the clear winner. |
| `child_process` (built-in) | execa 9.x | If you need advanced features like piping, IPC, or template literal commands. However, execa is ESM-only since v6, which complicates integration if autopilot-cc stays CommonJS. The built-in `child_process` with `timeout` and `killSignal` options covers autopilot-cc's needs. |
| `child_process` (built-in) | nano-spawn 2.x | Lightweight alternative to execa from the same author. Still ESM-only. Only useful if you need cleaner API than raw child_process but not execa's full feature set. |
| pixelmatch | Playwright `toHaveScreenshot()` | When running inside Playwright Test context. For standalone screenshot comparison (comparing images taken at different times/phases), pixelmatch is more appropriate. |
| tree-kill | execa (subprocess management) | execa 9 has built-in process tree cleanup via `forceKillAfterDelay`. But ESM-only constraint makes tree-kill (CJS-compatible, zero deps) the better choice for autopilot-cc. |
| Vitest 4 | Jest 30.x | Only for React Native projects (Jest is mandatory there) or if migrating a large existing Jest test suite. For new Node.js projects in 2026, Vitest is the standard. |
| Vitest 4 | Node.js built-in `node:test` | For zero-dependency test scenarios. `node:test` is stable since Node 20 and fully production-ready in Node 24. However, it lacks Vitest's watch mode quality, snapshot testing maturity, and ecosystem of plugins. Suitable for simple utility testing; not recommended as the primary test runner for a project with visual regression needs. |
| `@playwright/mcp` (Microsoft official) | executeautomation/mcp-playwright | The community server has more features but is third-party. The Microsoft official server is maintained alongside Playwright itself and uses the more efficient accessibility-tree approach. Stick with official. |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| vm2 | Deprecated with critical sandbox escape vulnerabilities (CVE-2026-01). Maintainer recommends alternatives. Do NOT use for sandboxing untrusted code. | isolated-vm for in-process sandboxing, or `child_process` with timeouts for process-level isolation. For autopilot-cc's use case (running project tests), process-level isolation via child_process is sufficient and simpler. |
| isolated-vm | Native C++ dependency adds build complexity. Overkill for autopilot-cc's use case (running known project code, not arbitrary untrusted code). | `child_process` with `timeout`, `maxBuffer`, and `killSignal` options. |
| Puppeteer | Chrome-only, no built-in visual comparison, smaller community momentum in 2026 vs Playwright. Microsoft invests heavily in Playwright + MCP integration. | Playwright (`playwright-core` for library use, `@playwright/test` for testing). |
| Cypress | Heavy, browser-only, not suitable for programmatic/headless screenshot workflows. Designed for interactive test writing, not agent-driven verification. | Playwright for browser automation and visual verification. |
| Selenium/WebDriver | Legacy protocol, slower, more brittle, heavier setup. Every modern guide recommends Playwright or Puppeteer over Selenium for new projects. | Playwright. |
| Jest (for new projects) | Slower cold starts, CJS-first design clashes with ESM ecosystem, configuration complexity. Jest 30 improves ESM support but Vitest is purpose-built for it. | Vitest 4 for new test suites. |
| Docker-based sandboxing | Massive overhead for running `npm test`. Requires Docker daemon. Not available in all Claude Code environments. Adds 10-30 seconds of startup per test run. | Process-level isolation with child_process timeouts. Reserve Docker for untrusted code execution if that becomes a requirement later. |

---

## Stack Patterns by Use Case

**If the target project is a web app (React, Vue, Next.js, etc.):**
- Use Playwright to start the dev server, wait for it, take screenshots
- Use `@playwright/mcp` for agent-driven browser interaction
- Use pixelmatch for cross-phase visual comparison
- Run `npm test` via child_process for unit/integration tests
- Kill dev server via tree-kill when done

**If the target project is a CLI tool or library (Node.js, Python, Rust, etc.):**
- Run `npm test` / `pytest` / `cargo test` via child_process
- Parse exit codes (0 = pass, non-zero = fail)
- Parse stdout for test counts (framework-specific patterns)
- No browser/screenshot needed unless the tool generates visual output

**If the target project has no tests yet:**
- Agent writes tests as part of the phase
- Agent runs the tests it wrote via child_process
- Exit code verification confirms tests pass
- This is the "honest verification" pattern: if you wrote code, write a test, run the test

**If visual verification is needed but Playwright is not installed:**
- Fall back to CLI-only verification (run tests, check exit codes)
- Log a warning that visual verification was skipped
- Recommend Playwright installation for full verification

---

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| playwright-core@1.58.x | Node.js >= 18 | Requires Node 18+ for async iterators. Node 20 LTS or 24 LTS recommended. |
| pixelmatch@7.1.0 | Node.js >= 16, pngjs >= 7.x | ESM and CJS compatible. No native dependencies. |
| tree-kill@1.2.2 | Node.js >= 8 | Pure JavaScript, cross-platform. No compatibility concerns. |
| @playwright/mcp@0.0.x | Claude Code with MCP support | Rapidly iterating pre-1.0 package. Pin to specific version in MCP config. Expect breaking changes between minor versions. |
| vitest@4.0.x | Node.js >= 18, Vite >= 6 | ESM-only. Uses Vite under the hood for module resolution and transformation. |
| c8@10.1.x | Node.js >= 18 | Uses V8's built-in coverage. No native dependencies. |

---

## Node.js Version Requirement

**Recommendation: Require Node.js >= 20.0.0**

Current LTS versions (February 2026):
- Node.js 24.13.x (Active LTS "Krypton") - recommended
- Node.js 22.x (Maintenance LTS) - supported
- Node.js 20.x (Maintenance LTS until April 2026) - minimum

autopilot-cc currently requires `>=16.0.0` in package.json. This should be bumped to `>=20.0.0` because:
1. Playwright 1.58 requires Node 18+
2. `node:test` runner is stable only from Node 20+
3. Node 18 reached EOL in April 2025
4. Node 20 is the oldest still-supported LTS

---

## Sources

- [Playwright official docs - Screenshots](https://playwright.dev/docs/screenshots) -- screenshot API, fullPage, element screenshots (HIGH confidence)
- [Playwright official docs - Visual Comparisons](https://playwright.dev/docs/test-snapshots) -- toHaveScreenshot(), maxDiffPixels, maxDiffPixelRatio (HIGH confidence)
- [@playwright/mcp npm package](https://www.npmjs.com/package/@playwright/mcp) -- v0.0.68, Microsoft official MCP server (HIGH confidence)
- [Playwright npm package](https://www.npmjs.com/package/playwright) -- v1.58.2 latest stable (HIGH confidence)
- [Vitest 4.0 announcement](https://vitest.dev/blog/vitest-4) -- stable browser mode, visual regression testing (HIGH confidence)
- [Vitest 4.0 InfoQ coverage](https://www.infoq.com/news/2025/12/vitest-4-browser-mode/) -- Vitest 4 features: browser mode stable, toMatchScreenshot() (MEDIUM confidence)
- [vitest npm package](https://www.npmjs.com/package/vitest) -- v4.0.18 latest (HIGH confidence)
- [Node.js child_process docs](https://nodejs.org/api/child_process.html) -- timeout, killSignal, maxBuffer options (HIGH confidence)
- [Node.js test runner docs](https://nodejs.org/api/test.html) -- stable in Node 20+, process-level isolation (HIGH confidence)
- [pixelmatch npm](https://www.npmjs.com/package/pixelmatch) -- v7.1.0, zero dependencies, 150 LOC (HIGH confidence)
- [tree-kill npm](https://www.npmjs.com/package/tree-kill) -- v1.2.2, cross-platform process tree termination (HIGH confidence)
- [execa npm](https://www.npmjs.com/package/execa) -- v9.6.1, ESM-only since v6 (HIGH confidence)
- [nano-spawn npm](https://www.npmjs.com/package/nano-spawn) -- v2.0.0, ESM-only lightweight alternative (HIGH confidence)
- [vm2 security vulnerability](https://thehackernews.com/2026/01/critical-vm2-nodejs-flaw-allows-sandbox.html) -- critical sandbox escape, do not use (MEDIUM confidence)
- [c8 npm](https://www.npmjs.com/package/c8) -- v10.1.3, V8-native coverage (HIGH confidence)
- [Node.js releases](https://nodejs.org/en/about/previous-releases) -- Node 24 Active LTS, Node 20 Maintenance LTS (HIGH confidence)
- [Playwright vs Puppeteer 2026 - BrowserStack](https://www.browserstack.com/guide/playwright-vs-puppeteer) -- Playwright recommended for cross-browser, Puppeteer for Chrome-only speed (MEDIUM confidence)
- [Vitest vs Jest 2026](https://howtotestfrontend.com/resources/vitest-vs-jest-which-to-pick) -- Vitest recommended for new projects (MEDIUM confidence)
- [Claude Code MCP docs](https://code.claude.com/docs/en/mcp) -- MCP server configuration, stdio transport (HIGH confidence)
- [Playwright MCP + Claude Code integration](https://alexop.dev/posts/building_ai_qa_engineer_claude_code_playwright/) -- real-world agent + Playwright MCP setup (MEDIUM confidence)
- [Building an AI QA Engineer with Claude Code and Playwright MCP](https://nikiforovall.blog/ai/2025/09/06/playwright-claude-code-testing.html) -- practical guide for agent-driven testing (MEDIUM confidence)

---
*Stack research for: autopilot-cc self-verification rebuild*
*Researched: 2026-02-17*
