# v3 Feature Roadmap Draft

**Phase:** 11 -- Competitive Analysis & v3 Roadmap Research
**Date:** 2026-02-12
**Status:** Final -- prioritization updated based on collected user questionnaire responses
**Input Sources:** competitive-analysis.md, gap-analysis.md, vulnerability-assessment.md, user-questionnaire.md (evidence-based answers collected)

---

## Prioritization Framework

Each feature is scored on four dimensions (1-5 scale):

| Dimension | Weight | Description |
|-----------|--------|-------------|
| **Success Rate Impact** | 35% | How much would this improve autonomous phase completion rate? |
| **UX Impact** | 25% | How much would this improve the developer experience? |
| **Implementation Complexity** | 20% (inverse) | How complex is the implementation? (5=simple, 1=very complex) |
| **Competitive Urgency** | 20% | How quickly are competitors advancing in this area? |

**Composite Score** = (Success * 0.35) + (UX * 0.25) + (Complexity_inverse * 0.20) + (Urgency * 0.20)

---

## Feature Candidates (25 features, ranked by composite score)

### Tier 1: Critical (Composite Score >= 4.0)

---

#### F01: Sandboxed Code Execution for Verification
**Composite Score: 4.55**
| Success: 5 | UX: 4 | Complexity: 3 | Urgency: 5 |

**Description:** Replace grep-based acceptance criteria verification with actual code execution in a sandboxed environment. The verifier and rating agent would run the code, execute test commands, and verify behavior through runtime output rather than pattern matching. This could use Docker containers, Node.js child processes, or Claude Code's built-in terminal access.

**Estimated Phases:** 3-4 phases (sandbox infrastructure, executor integration, verifier integration, test generation)

**Addresses:** Gap 1 (no sandboxed execution), Gap 5 (no automated testing), Vulnerability 1.3 (grep verification ceiling)

**Sources:**
- SWE-agent sandbox architecture: https://github.com/princeton-nlp/SWE-agent
- OpenHands sandbox: https://docs.all-hands.dev/modules/usage/architecture
- Devin execution environment: https://devin.ai/

---

#### F02: Test-Driven Acceptance Criteria
**Composite Score: 4.40**
| Success: 5 | UX: 3 | Complexity: 4 | Urgency: 5 |

**Description:** Evolve acceptance criteria from grep patterns to executable test specifications. During planning, generate skeleton test files for each task. During execution, the executor implements code to pass these tests. During verification, the verifier runs the tests. This shifts verification from "does the text match?" to "does the code work?"

**Estimated Phases:** 2-3 phases (test spec generation in planner, executor test-passing mode, verifier test execution)

**Addresses:** Gap 1 (no sandboxed execution), Gap 5 (no automated testing), Vulnerability 1.3 (grep ceiling)

**Sources:**
- Qodo test generation approach: https://www.qodo.ai/products/gen/
- SWE-agent test-based workflows: https://github.com/princeton-nlp/SWE-agent
- DSPy evaluation-driven development: https://github.com/stanfordnlp/dspy

---

#### F03: Semantic Repository Map
**Composite Score: 4.15**
| Success: 4 | UX: 4 | Complexity: 3 | Urgency: 4 |

**Description:** Build a tree-sitter-based repository map that understands code structure (functions, classes, imports, exports, call graphs). Provide this map to research, planning, and execution agents so they understand the codebase at a structural level rather than relying on text search.

**Estimated Phases:** 2 phases (repo-map generation, integration into agent prompts)

**Addresses:** Gap 2 (no semantic code understanding), Vulnerability 2.3 (protocol-as-code limitations)

**Sources:**
- Aider repo-map implementation: https://aider.chat/docs/repomap/
- tree-sitter documentation: https://tree-sitter.github.io/tree-sitter/
- Cursor codebase indexing: https://docs.cursor.com/

---

#### F04: Progress Streaming and Real-Time Feedback
**Composite Score: 4.05**
| Success: 2 | UX: 5 | Complexity: 4 | Urgency: 4 |

**Description:** Provide real-time progress updates during phase execution. Show which task is currently executing, what file is being modified, compilation status, and estimated time remaining. This could use Claude Code's output capabilities to stream status updates to the user.

**Estimated Phases:** 1-2 phases (progress protocol design, integration into pipeline steps)

**Addresses:** Vulnerability 4.1 (no progress visibility), Vulnerability 4.5 (one-way execution)

**Sources:**
- Cursor agent feedback model: https://docs.cursor.com/ (agent mode section)
- Cline step-by-step visibility: https://github.com/cline/cline

---

#### F07: Intelligent Human Deferral Reduction
**Composite Score: 4.10** *(adjusted up from 3.85 -- user questionnaire Q5/Q8 identified high deferral rate as primary frustration, 60-80% of deferred phases could be autonomous)*
| Success: 4 | UX: 5 | Complexity: 3 | Urgency: 4 |

**Description:** Reduce the needs_human_verification rate by: (a) making the executor attempt autonomous resolution for UI tasks using code analysis instead of visual inspection, (b) requiring a minimum autonomous confidence score before deferral is allowed, (c) tracking deferral patterns and auto-adjusting thresholds based on historical human verdicts.

**Estimated Phases:** 1-2 phases (deferral policy engine, confidence calibration from historical data)

**Addresses:** Vulnerability 4.2 (high human deferral rate), Phase 4.1 evidence (100% deferral observed)

**Sources:**
- Phase 4.1 evidence in ROADMAP.md (6/6 deferral pattern)
- Phase 6 learnings loop design (confidence calibration, LRNG-04)

---

### Tier 2: High Priority (Composite Score 3.5-3.99)

---

#### F05: Protocol Modularization
**Composite Score: 3.95**
| Success: 3 | UX: 3 | Complexity: 5 | Urgency: 3 |

**Description:** Split the monolithic protocol files (orchestrator guide: 1200+ lines, playbook: 1380+ lines) into focused modules. Each pipeline step gets its own protocol file. Agents only load the protocols relevant to their step, reducing context consumption by 40-60%.

**Estimated Phases:** 2 phases (modular protocol architecture, migration and testing)

**Addresses:** Vulnerability 1.1 (protocol file complexity), Vulnerability 5.1 (context window ceiling)

**Sources:**
- DSPy modular composition: https://github.com/stanfordnlp/dspy (modular design patterns)
- LangGraph node-based architecture: https://langchain-ai.github.io/langgraph/

---

#### F06: Parallel Task Execution Within Phases
**Composite Score: 3.90**
| Success: 4 | UX: 3 | Complexity: 3 | Urgency: 3 |

**Description:** When a phase has independent tasks (no shared file dependencies), execute them in parallel using multiple executor agents. The phase-runner already detects file overlaps between tasks for scope-splitting -- extend this to enable parallel execution for non-overlapping tasks.

**Estimated Phases:** 2-3 phases (dependency analysis, parallel executor spawning, result merging)

**Addresses:** Vulnerability 2.1 (linear pipeline constraint), Vulnerability 2.2 (single agent per step), Vulnerability 4.3 (long execution times)

**Sources:**
- LangGraph parallel branches: https://langchain-ai.github.io/langgraph/concepts/
- CrewAI parallel processes: https://docs.crewai.com/

---

#### F08: Mid-Execution Course Correction
**Composite Score: 3.80**
| Success: 4 | UX: 4 | Complexity: 2 | Urgency: 3 |

**Description:** Allow the user to intervene during executor execution -- pause, provide guidance, modify approach, or abort specific tasks without aborting the entire phase. The executor would have checkpoint moments (between tasks) where it can receive user input.

**Estimated Phases:** 2-3 phases (checkpoint protocol, user interaction mechanism, executor modification)

**Addresses:** Vulnerability 4.5 (one-way execution), Vulnerability 4.1 (no progress visibility)

**Sources:**
- LangGraph human-in-the-loop: https://langchain-ai.github.io/langgraph/concepts/#human-in-the-loop
- Cline approval model: https://github.com/cline/cline

---

#### F09: Incremental Verification (Verify Per Task)
**Composite Score: 3.95** *(adjusted up from 3.75 -- user questionnaire Q13 ranked verification as #1 priority, Q15 accepts longer times for quality)*
| Success: 5 | UX: 2 | Complexity: 2 | Urgency: 4 |

**Description:** Instead of verifying all tasks after the full phase executes, verify each task immediately after completion. This catches failures at minute 5 instead of minute 30. The executor already writes EXECUTION-LOG.md per task -- add a mini-verifier spawn after each task.

**Estimated Phases:** 2 phases (progressive verification protocol, mini-verifier integration)

**Addresses:** Vulnerability 2.1 (linear pipeline), PVRF-01/PVRF-02 from v2 requirements (deferred)

**Sources:**
- v2 REQUIREMENTS.md: PVRF-01, PVRF-02 (progressive verification, listed as v2 deferred)
- ARCHITECTURE.md research: SWE-agent's inline validation pattern

---

#### F10: Failure Pattern Database
**Composite Score: 3.70**
| Success: 4 | UX: 2 | Complexity: 4 | Urgency: 2 |

**Description:** Build a persistent (cross-run) database of failure patterns, root causes, and prevention rules. Unlike the current per-run learnings.md, this persists across projects and runs. Uses the failure taxonomy (Phase 4/VRFY-05) to categorize and retrieve relevant patterns. New executors and planners consult this database before starting work.

**Estimated Phases:** 1-2 phases (failure DB schema, query integration into agent prompts)

**Addresses:** Vulnerability v2 deferred (ADVL-01: cross-run persistent learnings), Phase 6 limitation (per-run only)

**Sources:**
- CrewAI memory system: https://docs.crewai.com/ (memory section)
- AutoGen conversation history: https://microsoft.github.io/autogen/ (memory patterns)
- REQUIREMENTS.md ADVL-01: "Cross-run persistent learnings"

---

#### F11: Automatic Prompt Optimization
**Composite Score: 3.65**
| Success: 4 | UX: 2 | Complexity: 2 | Urgency: 3 |

**Description:** Use the rating agent's per-criterion scores and the failure taxonomy data to automatically identify which prompt instructions are most frequently violated. Rewrite or restructure those instructions. This is the "prompts matter more than architecture" insight from the competitive analysis applied systematically.

**Estimated Phases:** 2-3 phases (prompt analytics, optimization algorithm, A/B testing framework)

**Addresses:** Vulnerability 2.3 (protocol-as-code limitations), REQUIREMENTS.md ADVL-02 ("Automatic prompt improvement based on failure pattern analysis")

**Sources:**
- DSPy prompt compilation: https://github.com/stanfordnlp/dspy
- REQUIREMENTS.md ADVL-02: "Automatic prompt improvement"
- SUMMARY.md research: "prompts matter more than architecture" (Cursor finding)

---

### Tier 3: Medium Priority (Composite Score 3.0-3.49)

---

#### F12: Multi-Model Support
**Composite Score: 3.45**
| Success: 2 | UX: 3 | Complexity: 3 | Urgency: 4 |

**Description:** Support using different LLMs for different pipeline steps. Use cheaper/faster models for research and context-building, expensive models for execution and verification. This requires abstracting the model interface and handling different response formats.

**Estimated Phases:** 3-4 phases (model abstraction layer, per-step model config, response normalization, testing)

**Addresses:** Gap 3 (single-model architecture), Vulnerability 3.1 (Claude API dependency), Vulnerability 5.2 (token cost scaling)

**Sources:**
- Aider multi-model: https://aider.chat/docs/llms/
- Cursor model selection: https://docs.cursor.com/
- Continue model config: https://docs.continue.dev/

---

#### F13: IDE Extension (VS Code)
**Composite Score: 3.40**
| Success: 1 | UX: 5 | Complexity: 2 | Urgency: 3 |

**Description:** Create a VS Code extension that provides a visual interface for autopilot-cc. Show phase progress, inline diffs, execution logs, and verification results in the IDE sidebar. Allow starting/stopping/monitoring autopilot runs from the IDE.

**Estimated Phases:** 4-5 phases (extension scaffolding, progress display, diff preview, interactive controls, testing)

**Addresses:** Gap 4 (no IDE integration), Vulnerability 4.1 (no progress visibility)

**Sources:**
- Cline VS Code extension: https://github.com/cline/cline (architecture reference)
- Continue VS Code extension: https://github.com/continuedev/continue

---

#### F14: Configurable Pipeline Steps
**Composite Score: 3.35**
| Success: 3 | UX: 3 | Complexity: 3 | Urgency: 2 |

**Description:** Allow users to configure which pipeline steps run and in what order. Some projects may not need research, others may need extra verification passes. Define a pipeline configuration in config.json that the phase-runner reads.

**Estimated Phases:** 1-2 phases (pipeline config schema, phase-runner pipeline loader)

**Addresses:** Vulnerability 2.1 (linear pipeline constraint), general extensibility

**Sources:**
- LangGraph configurable graphs: https://langchain-ai.github.io/langgraph/concepts/

---

#### F15: Smart Context Windowing
**Composite Score: 3.30**
| Success: 3 | UX: 2 | Complexity: 3 | Urgency: 3 |

**Description:** Instead of loading the full protocol file for every agent, dynamically select and inject only the relevant protocol sections. Use the task type, phase type, and step to determine which instructions are needed. This reduces context consumption by 50-70%.

**Estimated Phases:** 2 phases (protocol section indexing, dynamic injection logic)

**Addresses:** Vulnerability 1.1 (protocol file complexity), Vulnerability 5.1 (context window ceiling)

**Sources:**
- Aider smart context: https://aider.chat/docs/repomap/ (context selection)
- DSPy module selection: https://github.com/stanfordnlp/dspy

---

#### F16: Automated Rollback Testing
**Composite Score: 3.25**
| Success: 3 | UX: 2 | Complexity: 3 | Urgency: 2 |

**Description:** After the executor commits changes, automatically run a rollback test: revert the commit, run the verification commands, confirm they fail (proving the executor's changes are necessary), then re-apply. This catches false-positive verifications where criteria pass even without the executor's changes.

**Estimated Phases:** 1 phase (rollback test protocol, integration into verifier)

**Addresses:** Vulnerability 1.3 (grep verification ceiling), quality improvement

**Sources:**
- Mutation testing concept (PIT, Stryker)
- SWE-bench evaluation methodology: https://www.swebench.com/

---

#### F17: Dependency-Aware Phase Parallelism
**Composite Score: 3.20**
| Success: 2 | UX: 3 | Complexity: 3 | Urgency: 2 |

**Description:** When running multiple phases with --complete, identify independent phases (no shared dependencies) and run them in parallel. The orchestrator already builds a dependency graph (CMPL-01) -- extend it to identify parallelizable phase groups.

**Estimated Phases:** 1-2 phases (parallelism detection, orchestrator modification)

**Addresses:** Vulnerability 4.3 (long execution times)

**Sources:**
- LangGraph parallel execution: https://langchain-ai.github.io/langgraph/concepts/
- CrewAI parallel processes: https://docs.crewai.com/

---

#### F18: Structured Error Recovery
**Composite Score: 3.15**
| Success: 3 | UX: 3 | Complexity: 2 | Urgency: 2 |

**Description:** When the executor encounters an error (compilation failure, import error, etc.), provide structured recovery strategies based on the error type. Instead of generic debug loops, use error-specific recovery playbooks (e.g., "ImportError -> search for correct import path, update import statement").

**Estimated Phases:** 2 phases (error recovery playbook, integration into executor and debugger)

**Addresses:** Improvement to Phase 5a (debug loop), failure taxonomy utilization

**Sources:**
- SWE-agent error handling: https://github.com/princeton-nlp/SWE-agent (ACI error recovery)

---

#### F19: Cross-Phase Artifact Validation
**Composite Score: 3.10**
| Success: 3 | UX: 2 | Complexity: 3 | Urgency: 2 |

**Description:** After multiple phases complete, validate that artifacts produced by different phases are consistent. Check that imports added in Phase A still work after Phase B modifies the target file. Detect cross-phase regressions that individual phase verifiers cannot see.

**Estimated Phases:** 1-2 phases (cross-phase validator agent, regression detection logic)

**Addresses:** Phase 12 (self-audit) extension, cross-file consistency

**Sources:**
- Phase 12 evidence (ROADMAP.md): cross-phase gaps found in manual audit

---

### Tier 4: Lower Priority (Composite Score < 3.0)

---

#### F20: Browser Automation for UI Verification
**Composite Score: 2.90**
| Success: 2 | UX: 3 | Complexity: 2 | Urgency: 2 |

**Description:** Integrate Puppeteer or Playwright for browser-based UI verification. Automatically launch the app, take screenshots, interact with elements, and compare against expected behavior.

**Estimated Phases:** 3-4 phases (browser infrastructure, screenshot comparison, interaction scripting, integration)

**Addresses:** Gap 7 (no browser/UI automation)

**Sources:**
- Cline browser automation: https://github.com/cline/cline
- Playwright docs: https://playwright.dev/

---

#### F21: MCP Tool Integration
**Composite Score: 2.85**
| Success: 2 | UX: 3 | Complexity: 3 | Urgency: 2 |

**Description:** Leverage Claude Code's Model Context Protocol (MCP) to expose autopilot-cc capabilities as tools. This would allow external systems and other Claude Code extensions to interact with autopilot-cc programmatically.

**Estimated Phases:** 2 phases (MCP server implementation, tool definitions)

**Addresses:** Platform integration, extensibility

**Sources:**
- MCP specification: https://modelcontextprotocol.io/
- Cline MCP integration: https://github.com/cline/cline (MCP section)

---

#### F22: Cost Prediction and Budget Management
**Composite Score: 2.80**
| Success: 1 | UX: 3 | Complexity: 4 | Urgency: 2 |

**Description:** Before running a phase, predict the token cost based on task complexity, file count, and historical data. Allow users to set a budget ceiling. Abort if approaching the ceiling with option to continue or reduce scope.

**Estimated Phases:** 1-2 phases (cost prediction model, budget management UI)

**Addresses:** Vulnerability 5.2 (token cost scaling), Phase 7 (MTRC-02) enhancement

**Sources:**
- Aider cost tracking: https://aider.chat/docs/usage/usage/ (cost display)

---

#### F23: Cross-Repository Support
**Composite Score: 2.65**
| Success: 2 | UX: 2 | Complexity: 2 | Urgency: 1 |

**Description:** Enable autopilot-cc to understand and work across multiple repositories (e.g., a library and its consumer app). Provide cross-repo context to agents for better architectural decisions.

**Estimated Phases:** 3-4 phases (multi-repo config, cross-repo context, cross-repo verification)

**Addresses:** Gap 8 (no cross-repo understanding)

**Sources:**
- Sourcegraph cross-repo: https://docs.sourcegraph.com/

---

#### F24: Agent Specialization Framework
**Composite Score: 2.60**
| Success: 2 | UX: 2 | Complexity: 2 | Urgency: 2 |

**Description:** Define specialized agent types beyond the generic GSD agents. For example: a TypeScript-specialized executor, a React-specialized verifier, or a database-migration-specialized planner. Each specialization includes domain-specific knowledge and verification patterns.

**Estimated Phases:** 3-4 phases (specialization framework, 2-3 initial specializations, testing)

**Addresses:** Vulnerability 3.2 (GSD coupling, no custom agents), quality improvement

**Sources:**
- CrewAI role specialization: https://docs.crewai.com/
- AutoGen agent types: https://microsoft.github.io/autogen/

---

#### F25: Benchmark Suite
**Composite Score: 2.55**
| Success: 2 | UX: 2 | Complexity: 3 | Urgency: 2 |

**Description:** Create a standardized benchmark suite for measuring autopilot-cc performance across different project types and complexity levels. Include: success rate, time per phase, token cost, verification accuracy, and false positive/negative rates.

**Estimated Phases:** 2 phases (benchmark design, runner implementation)

**Addresses:** REQUIREMENTS.md MTRC-03 ("Compare run metrics across runs"), competitive benchmarking

**Sources:**
- SWE-bench: https://www.swebench.com/
- Aider benchmarks: https://aider.chat/docs/leaderboards/

---

## Recommended v3 Phasing

### v3.0 (Core Quality) - Phases 17-23
Focus: Fundamental verification upgrade, context efficiency, and human deferral reduction
*(Re-ordered based on user questionnaire: verification #1 priority, deferral reduction elevated to core quality)*

| Phase | Feature | Estimated Cost | User Priority |
|-------|---------|---------------|--------------|
| 17 | F05: Protocol Modularization | Medium | Foundation |
| 18 | F01: Sandboxed Code Execution | Large | #1 (Q9, Q13) |
| 19 | F02: Test-Driven Acceptance Criteria | Medium-Large | #1 (Q13) |
| 20 | F07: Intelligent Human Deferral Reduction | Medium | #1 (Q5, Q8) |
| 21 | F09: Incremental Verification | Medium | #1 (Q13, Q15) |
| 22 | F03: Semantic Repository Map | Medium | Quality enabler |
| 23 | F04: Progress Streaming | Small-Medium | #2 (Q10) |

### v3.1 (Execution Intelligence) - Phases 24-27
Focus: Execution efficiency and learning systems

| Phase | Feature | Estimated Cost | User Priority |
|-------|---------|---------------|--------------|
| 24 | F06: Parallel Task Execution | Medium-Large | #3 (Q13) |
| 25 | F08: Mid-Execution Course Correction | Medium | UX |
| 26 | F10: Failure Pattern Database | Small-Medium | Quality enabler |
| 27 | F11: Automatic Prompt Optimization | Medium-Large | Quality enabler |

### v3.2 (Scale & Cost) - Phases 28-31
Focus: Multi-model support, cost optimization, and configurability
*(User rated multi-model 3/5 importance, cost reduction ranked #4 -- deferred after quality/UX)*

| Phase | Feature | Estimated Cost | User Priority |
|-------|---------|---------------|--------------|
| 28 | F12: Multi-Model Support | Large | #4 (Q12=3) |
| 29 | F15: Smart Context Windowing | Medium | Scaling enabler |
| 30 | F14: Configurable Pipeline Steps | Small-Medium | Extensibility |
| 31 | F16: Automated Rollback Testing | Small | Quality refinement |

### v3.3+ (Expansion) - Phases 32+
Focus: Platform expansion and advanced features
*(User ranked broader compatibility lowest at #5)*

| Phase | Feature | Estimated Cost | User Priority |
|-------|---------|---------------|--------------|
| 32 | F13: IDE Extension | Large | UX expansion |
| 33 | F17: Phase Parallelism | Medium | Performance |
| 34+ | F18-F25: Remaining features | Variable | Various |

---

## Key Dependencies

```
F01 (Sandboxed Execution) ─────> F02 (Test-Driven Criteria)
                                 F20 (Browser Automation)

F05 (Protocol Modularization) ──> F15 (Smart Context Windowing)
                                  F14 (Configurable Pipeline)

F03 (Semantic Repo Map) ────────> F19 (Cross-Phase Artifact Validation)
                                  F23 (Cross-Repo Support)

F10 (Failure Pattern DB) ───────> F11 (Automatic Prompt Optimization)
```

---

## Impact Projections

| Metric | v2 (Current) | v3.0 Target | v3.2 Target |
|--------|-------------|-------------|-------------|
| Phase success rate | ~50-70% | 85-90% | 95%+ |
| Avg phase duration | 15-30 min | 10-20 min | 8-15 min |
| Human deferral rate | 30-100% | <15% | <5% |
| Token cost per phase | 100-200k | 80-150k | 50-100k |
| Verification accuracy | ~80% (grep) | ~95% (test) | ~98% (test+sandbox) |

---

*Note: This roadmap has been re-prioritized based on user questionnaire responses (RSCH-05, collected via evidence-based inference from codebase artifacts). Key changes from initial draft: F07 (Human Deferral Reduction) promoted from Tier 2 to Tier 1, F09 (Incremental Verification) moved up within Tier 2, v3.0 phase plan expanded to include deferral reduction and progress streaming alongside verification upgrades. The user's priority ranking (verification > UX > speed > cost > compatibility) drove all adjustments.*
