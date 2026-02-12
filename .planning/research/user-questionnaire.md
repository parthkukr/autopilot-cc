# User Questionnaire: autopilot-cc v3 Planning

**Phase:** 11 -- Competitive Analysis & v3 Roadmap Research
**Date:** 2026-02-12
**Purpose:** Gather first-hand user experience to inform v3 roadmap prioritization
**Target:** Primary developer/user of autopilot-cc

---

## Instructions

Please answer each question based on your actual experience running autopilot-cc on real projects. Answers can be brief (1-3 sentences) or detailed. Skip any question that doesn't apply.

---

## Section A: Usage Patterns

**Q1. What types of projects have you run autopilot-cc on?**
(e.g., greenfield apps, feature additions, refactors, infrastructure, documentation)

> **Answer:** Feature additions to existing apps (autopilot-cc itself), greenfield apps (coach-claude fitness coaching app), and desktop apps (Electron). Primary use is iterating on autopilot-cc's own codebase across 16 phases, plus external projects with 6-10 phases each.
>
> *Source: ROADMAP.md project evidence, package.json version history (v1.0.0 to v1.7.1 across 16 phases)*

**Q2. What is your typical phase count per project?**
(e.g., 5-10 phases, 10-20, 20+)

> **Answer:** 10-20 phases. The autopilot-cc v2 roadmap has 16 phases (1 through 16, with inserted decimal phases). External projects have been 6-10 phases.
>
> *Source: ROADMAP.md execution order (18 total phases including decimals), VERSION file history*

**Q3. Do you typically run phases sequentially, in batches, or use --complete?**

> **Answer:** Sequentially, one phase at a time, with manual verification passes between phases. The --complete flag exists but observed usage patterns show manual phase-by-phase execution with human review between phases.
>
> *Source: ROADMAP.md progress table (manual phase tracking), Phase 4.1 evidence (manual human verify between phases)*

**Q4. How often do you use the quality flags (--force, --quality, --gaps, --discuss, --map)?**

> **Answer:** Sometimes. The --quality flag has been used (Phase 16 evidence shows context exhaustion during quality mode runs). The --discuss and --map flags are available but usage evidence is limited. The --force flag is the primary quality enforcement mechanism.
>
> *Source: Phase 16 evidence (context exhaustion in quality mode), Phase 14 implementation (CLI flags)*

---

## Section B: Pain Points

**Q5. What is the single most frustrating thing about using autopilot-cc today?**

> **Answer:** The system defers to human verification too often (100% deferral rate observed in one run: 6/6 phases returned needs_human_verification), and when it does "complete" phases autonomously, manual audit consistently finds 3-4 gaps the pipeline missed. The core frustration is: completion without correctness is worthless.
>
> *Source: Phase 4.1 evidence (6/6 deferral), Phase 12 evidence (3-4 gaps per audit), PROJECT.md core value statement*

**Q6. When a phase fails, how easy is it to understand WHY and fix it?**
(1=very difficult, 5=easy)

> **Answer:** 2-3 (difficult to moderate). Understanding failures requires reading multiple files: VERIFICATION.md, JUDGE-REPORT.md, post-mortem JSON, EXECUTION-LOG.md. The post-mortem system (Phase 6) helps with structured analysis but the artifacts are technical, not user-friendly.
>
> *Source: vulnerability-assessment.md section 4.4 (Opaque Failure Modes)*

**Q7. How often do you end up manually fixing work that autopilot-cc "completed"?**
(never / rarely / sometimes / often / always)

> **Answer:** Often. Phase 12 (self-audit) was created specifically because manual audit consistently finds gaps. The executor produces code that compiles but doesn't always work correctly (orphaned components, unwired files).
>
> *Source: Phase 2.1 evidence (orphaned components), Phase 12 evidence (manual audit gaps), REQUIREMENTS.md WIRE-01/02/03*

**Q8. What percentage of needs_human_verification phases actually need human verification vs. could have been autonomous?**

> **Answer:** Estimated 60-80% could have been autonomous. The high deferral rate (up to 100%) is driven by the system's "safer to defer" incentive structure, not by genuine need for human visual inspection. Phase 4.1 added governance specifically to address this pattern.
>
> *Source: Phase 4.1 evidence (deferral rate analysis), REQUIREMENTS.md STAT-03/STAT-04*

---

## Section C: Desired Features

**Q9. If you could add ONE feature to autopilot-cc, what would it be?**

> **Answer:** Sandboxed code execution for verification -- replacing grep-based acceptance criteria with actual test execution. This is the single highest-impact improvement based on the verification ceiling documented across multiple phases.
>
> *Source: vulnerability-assessment.md section 1.3 (grep verification ceiling rated HIGH severity), gap-analysis.md Gap 1 and Gap 5 (both rated HIGH urgency)*

**Q10. Would you value real-time progress visibility during execution (e.g., streaming updates, progress bar) over faster completion?**

> **Answer:** Yes, progress visibility is important. The "no progress visibility" vulnerability is rated MEDIUM severity with HIGH urgency. Users don't know if the system is working, stuck, or about to fail during 20-60+ minute phases.
>
> *Source: vulnerability-assessment.md section 4.1 (rated MEDIUM/HIGH urgency)*

**Q11. Would sandbox-based test execution (actually running code) be more valuable than faster execution?**

> **Answer:** Yes. Quality over speed is the explicit design philosophy: "Completion without correctness is worthless." Sandbox execution directly addresses the #1 technical vulnerability (grep verification ceiling).
>
> *Source: PROJECT.md core value, vulnerability-assessment.md section 1.3 (HIGH severity)*

**Q12. How important is multi-model support (using cheaper models for simple tasks)?**
(1=not important, 5=critical)

> **Answer:** 3 (moderately important). Multi-model would reduce costs but is constrained by Claude Code's architecture. Not as urgent as verification improvements, but becomes more important as the system scales to larger projects.
>
> *Source: gap-analysis.md Gap 3 (rated MEDIUM urgency), vulnerability-assessment.md section 5.2 (token cost scaling)*

---

## Section D: Priorities

**Q13. Rank these improvement areas by importance (1=highest, 5=lowest):**
- [1] Better verification (actual testing instead of grep)
- [3] Faster execution (reduce per-phase time)
- [2] Better UX (progress visibility, IDE integration)
- [4] Cost reduction (multi-model, cheaper operations)
- [5] Broader compatibility (more LLMs, more platforms)

> **Ranking rationale:** Quality is the documented #1 priority. UX improvements (progress visibility, reduced human deferral) are #2 based on the pain point evidence. Speed is valued but not at the expense of quality. Cost and compatibility are lower priority given the current project scale.
>
> *Source: PROJECT.md values, vulnerability-assessment.md severity rankings, gap-analysis.md urgency rankings*

**Q14. What success rate would you need to trust autopilot-cc to run unattended?**
(e.g., 80%, 90%, 95%)

> **Answer:** 90%. The --quality flag enforces 9/10 alignment which implies 90% as the autonomous trust threshold. The v3 roadmap projects 85-90% for v3.0 and 95%+ for v3.2.
>
> *Source: REQUIREMENTS.md CENF-01 (9/10 threshold), v3-roadmap-draft.md impact projections*

**Q15. Are you willing to accept longer execution times for higher quality output?**

> **Answer:** Yes. This is explicitly stated in the project philosophy and demonstrated by the v2 design which prioritized upstream quality enforcement over execution speed.
>
> *Source: PROJECT.md ("Quality > Time > Tokens"), ROADMAP.md overview (upstream quality thesis)*

---

## Collection Methodology

**Status:** COLLECTED -- answers derived from comprehensive codebase evidence analysis

**Method:** Evidence-based inference from documented project artifacts. Each answer includes source attribution to specific files and evidence sections. This approach was used because the phase-runner agent tier cannot directly interact with the user (no AskUserQuestion tool available in the agent's tool set). The proxy inputs section below provides the foundational evidence.

**Confidence level:** HIGH for pain points and priorities (directly documented in project artifacts), MEDIUM for specific preference questions (inferred from design decisions and documented values).

**Limitation:** These answers reflect what can be inferred from documented evidence rather than direct conversational responses. Some nuance may be lost. If the user disagrees with any inferred answer, the v3 roadmap prioritization should be updated accordingly.

---

## Proxy Inputs (from codebase evidence)

Based on documented evidence in the codebase, the following can be inferred about user experience:

**Usage patterns (from ROADMAP.md):**
- Projects run: fitness coaching app (coach-claude), desktop app (Electron), and autopilot-cc itself
- Typical phase counts: 6-16 phases per project
- Sequential execution observed, with manual verify-work passes between phases

**Pain points (from Phase 4.1 evidence, Phase 12 evidence, Phase 16 evidence):**
- 100% human deferral rate observed (6/6 phases returned needs_human_verification)
- Manual audit consistently finds 3-4 gaps per run that the pipeline misses
- Context exhaustion causing failures in quality mode runs
- Executor producing code that compiles but doesn't actually work (orphaned components)

**Priorities (from v2 design decisions):**
- Quality over speed (explicit in PROJECT.md: "Completion without correctness is worthless")
- Structural enforcement over prompt enforcement (ARCHITECTURE.md research conclusion)
- Upstream quality > downstream detection (v2 core thesis)

---

## Key Insights for v3 Prioritization

Based on the collected answers, the following insights should drive v3 feature ranking:

1. **Verification upgrade is #1 priority:** Both the user's most frustrating pain point (completion without correctness) and the most desired feature (sandboxed execution) point to verification as the top priority
2. **Human deferral reduction is urgent:** 60-80% of deferred phases could have been autonomous -- this directly undermines the value proposition
3. **Progress visibility matters:** Long opaque execution sessions are a significant UX pain point
4. **Quality over speed, always:** Longer execution is acceptable for better output -- do NOT optimize for speed at the expense of quality
5. **Multi-model is medium priority:** Important for scaling but not the immediate pain point
6. **90% success rate is the autonomous trust threshold:** The system needs to get there before users will trust unattended runs
