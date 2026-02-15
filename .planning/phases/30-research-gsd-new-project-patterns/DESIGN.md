# Design Document: gsd:new-project Pattern Analysis for Phase Creation

**Phase:** 30 -- Research gsd:new-project Patterns for Phase Creation
**Author:** Autopilot Phase Runner
**Date:** 2026-02-15
**Purpose:** Blueprint for Phases 31-34 (Smart Input Parsing, Rich Spec Generation, Codebase-Aware Positioning, Deep Context Gathering)

---

## Part 1: Complete /gsd:new-project Flow Analysis

### Overview

`/gsd:new-project` is an orchestrator command that initializes a new project through a unified flow: questioning -> research (optional) -> requirements -> roadmap. It creates 6 artifacts: PROJECT.md, config.json, research directory (optional), REQUIREMENTS.md, ROADMAP.md, and STATE.md.

The command file (`/home/parth/.claude/commands/gsd/new-project.md`) delegates to a workflow file (`/home/parth/.claude/get-shit-done/workflows/new-project.md`) and references supporting files:
- `references/questioning.md` -- questioning philosophy and techniques
- `references/ui-brand.md` -- visual patterns for banners and checkpoints
- `templates/project.md` -- PROJECT.md template
- `templates/requirements.md` -- REQUIREMENTS.md template

### Step 1: Setup

**Purpose:** Environment validation before any user interaction.

**Actions:**
- Runs `gsd-tools.js init new-project` to detect environment state
- Parses JSON for: `researcher_model`, `synthesizer_model`, `roadmapper_model`, `commit_docs`, `project_exists`, `has_codebase_map`, `planning_exists`, `has_existing_code`, `has_package_file`, `is_brownfield`, `needs_codebase_map`, `has_git`
- If project already exists: Error, direct to `/gsd:progress`
- If no git: Initialize git

**Questions Asked:** None (automated checks only)
**Decision Points:** Project exists? Git exists?
**Artifacts Created:** Git repository (if not present)

**Quality Pattern:** Fail-fast validation. Never start interactive flow on invalid state.

### Step 2: Brownfield Offer

**Purpose:** Detect existing codebase and offer to map it first.

**Actions:**
- If existing code detected but no codebase map: Ask user whether to map codebase first
- Uses AskUserQuestion with header "Existing Code" and two options: "Map codebase first" or "Skip mapping"
- If "Map codebase first": Exit, run `/gsd:map-codebase` first

**Questions Asked (via AskUserQuestion):**
- "I detected existing code in this directory. Would you like to map the codebase first?"
  - Option 1: "Map codebase first" -- Run /gsd:map-codebase (Recommended)
  - Option 2: "Skip mapping" -- Proceed with project initialization

**Decision Points:** Brownfield vs greenfield project path
**Artifacts Created:** None directly (delegates to map-codebase if selected)

**Quality Pattern:** Context-aware routing. Detect existing state before asking questions about new state.

### Step 3: Deep Questioning

**Purpose:** Extract the user's vision through collaborative conversation. This is the highest-leverage step -- everything downstream depends on the quality of context gathered here.

**Actions:**
- Displays stage banner: "GSD > QUESTIONING"
- Opens with freeform inline question: "What do you want to build?"
- Follows the thread based on user's response with AskUserQuestion
- Keeps exploring until sufficient context gathered
- Uses "Ready?" gate: AskUserQuestion asking if ready to create PROJECT.md

**Questions Asked:**
- Opening (freeform, NOT AskUserQuestion): "What do you want to build?"
- Follow-ups (AskUserQuestion with options): Based on what user said, probing:
  - What excited them
  - What problem sparked this
  - What vague terms mean
  - What it would actually look like
  - What is already decided
- Decision gate (AskUserQuestion):
  - Header: "Ready?"
  - Question: "I think I understand what you're after. Ready to create PROJECT.md?"
  - Options: "Create PROJECT.md" / "Keep exploring"

**Questioning Philosophy (from references/questioning.md):**
- "Dream extraction, not requirements gathering"
- "You are a thinking partner, not an interviewer"
- Follow energy -- dig into what excited them
- Challenge vagueness -- never accept fuzzy answers
- Make abstract concrete -- "Walk me through using this"
- Context checklist (background, not spoken): What they are building, Why it exists, Who it is for, What done looks like

**Questioning Techniques:**
- Motivation: "What prompted this?", "What are you doing today that this replaces?"
- Concreteness: "Walk me through using this", "Give me an example"
- Clarification: "When you say Z, do you mean A or B?"
- Success: "How will you know this is working?"

**AskUserQuestion Pattern for Probing:**
- Present options that are interpretations, specific examples, concrete choices
- 2-4 options is ideal
- Always include a "Let me explain" escape option
- Example: User says "it should be fast" -> Options: "Sub-second response", "Handles large datasets", "Quick to build", "Let me explain"

**Anti-Patterns to Avoid:**
- Checklist walking -- going through domains regardless of what user said
- Canned questions -- asking "What's your core value?" regardless of context
- Corporate speak -- "What are your success criteria?"
- Interrogation -- firing questions without building on answers
- Rushing -- minimizing questions to get to "the work"
- Shallow acceptance -- taking vague answers without probing
- NEVER asking about user's technical experience (Claude builds)

**Decision Points:** Loop until user selects "Create PROJECT.md"
**Artifacts Created:** None yet (context held in conversation)

**Quality Pattern:** Conversational depth over breadth. Follow threads, do not checklist-walk.

### Step 4: Write PROJECT.md

**Purpose:** Synthesize all gathered context into the project context document.

**Actions:**
- Synthesizes context into `.planning/PROJECT.md` using template
- For greenfield: Requirements as hypotheses (none validated yet)
- For brownfield: Infer validated requirements from existing code via ARCHITECTURE.md and STACK.md
- Initializes Key Decisions table from questioning
- Commits PROJECT.md immediately

**Questions Asked:** None (synthesis step)
**Decision Points:** Greenfield vs brownfield requirement initialization
**Artifacts Created:**
- `.planning/PROJECT.md` -- containing: What This Is, Core Value, Requirements (Validated/Active/Out of Scope), Context, Constraints, Key Decisions

**Template Structure (from templates/project.md):**
```
# [Project Name]
## What This Is -- 2-3 sentence description
## Core Value -- ONE thing that must work
## Requirements -- Validated / Active / Out of Scope
## Context -- Background informing implementation
## Constraints -- Hard limits (tech, timeline, budget)
## Key Decisions -- Choices that constrain future work
```

**Quality Pattern:** Immediate atomic commit. Artifacts persist even if context is lost.

### Step 5: Workflow Preferences

**Purpose:** Configure how the project workflow will operate.

**Actions:**
- Round 1: 4 core questions via multi-option AskUserQuestion
- Round 2: 4 agent configuration questions
- Creates `.planning/config.json` with all settings
- Commits config.json immediately

**Questions Asked (Round 1 -- Core Workflow, 4 questions):**
1. "How do you want to work?" -- YOLO (auto-approve) / Interactive (confirm each step)
2. "How thorough should planning be?" -- Quick (3-5 phases) / Standard (5-8 phases) / Comprehensive (8-12 phases)
3. "Run plans in parallel?" -- Parallel (Recommended) / Sequential
4. "Commit planning docs to git?" -- Yes (Recommended) / No

**Questions Asked (Round 2 -- Workflow Agents, 4 questions):**
1. "Research before planning each phase?" -- Yes / No
2. "Verify plans will achieve their goals?" -- Yes / No
3. "Verify work satisfies requirements after each phase?" -- Yes / No
4. "Which AI models for planning agents?" -- Balanced / Quality / Budget

**Decision Points:** Each question determines a config setting
**Artifacts Created:**
- `.planning/config.json` -- containing: mode, depth, parallelization, commit_docs, model_profile, workflow (research, plan_check, verifier)

**Quality Pattern:** Structured multi-select with descriptions and recommendations. Batch related questions together.

### Step 5.5: Resolve Model Profile

**Purpose:** Map model profile to specific agent models.

**Actions:**
- Uses models from init: `researcher_model`, `synthesizer_model`, `roadmapper_model`
- These are pre-resolved by gsd-tools.js based on the model profile selection

**Questions Asked:** None
**Decision Points:** None (automated resolution)
**Artifacts Created:** None

### Step 6: Research Decision

**Purpose:** Decide whether to research the domain before defining requirements.

**Actions:**
- AskUserQuestion: Research first (Recommended) or Skip research
- If research: Displays "RESEARCHING" banner
- Creates research directory
- Spawns 4 parallel gsd-project-researcher agents with rich context prompts

**Questions Asked (via AskUserQuestion):**
- Header: "Research"
- Question: "Research the domain ecosystem before defining requirements?"
- Options: "Research first (Recommended)" / "Skip research"

**If Research Selected -- Parallel Research Spawning:**

4 agents spawned simultaneously, each with:
- `<research_type>` -- dimension being researched
- `<milestone_context>` -- greenfield vs subsequent
- `<question>` -- specific research question
- `<project_context>` -- summary from PROJECT.md
- `<downstream_consumer>` -- what the output feeds into
- `<quality_gate>` -- specific quality checks for each dimension
- `<output>` -- target file and template

Research dimensions:
1. **Stack** -- "What's the standard 2025 stack for [domain]?" -> writes STACK.md
2. **Features** -- "What features do [domain] products have?" -> writes FEATURES.md
3. **Architecture** -- "How are [domain] systems typically structured?" -> writes ARCHITECTURE.md
4. **Pitfalls** -- "What do [domain] projects commonly get wrong?" -> writes PITFALLS.md

After all 4 complete: Synthesis agent spawned to create SUMMARY.md from the 4 research files.

**Decision Points:** Research vs skip
**Artifacts Created (if research selected):**
- `.planning/research/STACK.md`
- `.planning/research/FEATURES.md`
- `.planning/research/ARCHITECTURE.md`
- `.planning/research/PITFALLS.md`
- `.planning/research/SUMMARY.md`

**Quality Pattern:** Parallel subagent spawning with rich context. Each agent gets downstream-consumer awareness (who reads their output and how). Quality gates are dimension-specific, not generic.

### Step 7: Define Requirements

**Purpose:** Transform project context and research into scoped, ID-tagged requirements.

**Actions:**
- Displays "DEFINING REQUIREMENTS" banner
- Loads context from PROJECT.md (core value, constraints, scope boundaries)
- If research exists: reads FEATURES.md for feature categories
- Presents features by category with table stakes vs differentiators
- For each category: AskUserQuestion with multiSelect for v1 scope
- Identifies gaps: asks if research missed anything
- Validates against core value
- Generates REQUIREMENTS.md with REQ-IDs (format: [CATEGORY]-[NUMBER])
- Presents full list for user confirmation
- Commits REQUIREMENTS.md

**Questions Asked:**
- Per category (AskUserQuestion, multiSelect):
  - Header: "[Category name]"
  - Question: "Which [category] features are in v1?"
  - Options: Features listed with descriptions + "None for v1"
- Gap identification (AskUserQuestion):
  - Header: "Additions"
  - Question: "Any requirements research missed?"
  - Options: "No, research covered it" / "Yes, let me add some"
- Confirmation (inline):
  - "Does this capture what you're building? (yes / adjust)"

**Requirement Quality Criteria:**
- Specific and testable: "User can reset password via email link" not "Handle password reset"
- User-centric: "User can X" not "System does Y"
- Atomic: One capability per requirement
- Independent: Minimal dependencies on other requirements
- Reject vague requirements -- push for specificity

**Decision Points:** Per-category scope selection, gap additions, final confirmation
**Artifacts Created:**
- `.planning/REQUIREMENTS.md` -- REQ-IDs grouped by category, v1/v2/Out of Scope, traceability section

**Quality Pattern:** Interactive scoping with user control. Vague requirements are rejected and pushed for specificity. REQ-ID system enables traceability.

### Step 8: Create Roadmap

**Purpose:** Transform requirements into a phase structure with success criteria.

**Actions:**
- Displays "CREATING ROADMAP" banner
- Spawns gsd-roadmapper agent with full context (PROJECT.md, REQUIREMENTS.md, research/SUMMARY.md, config.json)
- Roadmapper writes files immediately (ROADMAP.md, STATE.md, updates REQUIREMENTS.md traceability)
- Presents roadmap inline in table format
- AskUserQuestion for approval: "Approve" / "Adjust phases" / "Review full file"
- If "Adjust": Re-spawns roadmapper with revision context, loops until approved
- Commits all roadmap files

**Questions Asked (via AskUserQuestion):**
- Header: "Roadmap"
- Question: "Does this roadmap structure work for you?"
- Options: "Approve" / "Adjust phases" / "Review full file"

**Roadmapper Agent Philosophy:**
- Solo developer + Claude workflow (no teams, sprints, stakeholders)
- Anti-enterprise: delete PM theater
- Requirements drive structure: derive phases from requirements, do not impose structure
- Goal-backward thinking: "What must be TRUE for users when this phase completes?"
- 100% coverage validation: every v1 requirement maps to exactly one phase
- Depth calibration from config: Quick (3-5 phases), Standard (5-8), Comprehensive (8-12)

**Phase Identification Methodology:**
1. Group requirements by category
2. Identify dependencies between categories
3. Create delivery boundaries (coherent, verifiable capabilities)
4. Assign requirements -- each to exactly one phase
5. Derive 2-5 success criteria per phase using goal-backward

**Coverage Validation:**
- Build explicit coverage map: REQ-ID -> Phase N
- If orphaned requirements found: present options (create new phase, add to existing, defer to v2)
- Do not proceed until coverage = 100%

**Decision Points:** Roadmap approval/revision loop
**Artifacts Created:**
- `.planning/ROADMAP.md` -- phases with goals, dependencies, requirements, success criteria
- `.planning/STATE.md` -- project memory with current position, metrics, accumulated context
- `.planning/REQUIREMENTS.md` -- updated traceability section

**Quality Pattern:** Subagent with specialized domain knowledge. Files written immediately (persist across context loss). Iterative approval loop. 100% coverage as hard gate.

### Step 9: Done

**Purpose:** Present completion summary and next steps.

**Actions:**
- Displays "PROJECT INITIALIZED" banner
- Shows artifact table (Project, Config, Research, Requirements, Roadmap)
- Shows phase count and requirement count
- Recommends next step: `/gsd:discuss-phase 1`
- Suggests `/clear` for fresh context window

**Questions Asked:** None
**Decision Points:** None
**Artifacts Created:** None (presentation only)

**Quality Pattern:** Clear next-step guidance. Context reset recommendation.

---

## Part 2: Pattern Applicability Analysis

This section identifies which `/gsd:new-project` patterns are applicable to phase creation (the `/autopilot:add-phase` redesign) versus which are project-level-only concerns.

### Applicable Patterns for Phase Creation

| Pattern | Source Step | How to Adapt for Phase Creation |
|---------|-----------|-------------------------------|
| **Deep questioning / thread-following** | Step 3 | Ask about the phase's purpose, scope, edge cases, and expected outcomes. Follow threads from user's description. |
| **Freeform input -> structured output** | Step 3-4 | Accept freeform phase description -> generate structured Goal, Success Criteria, Dependencies |
| **AskUserQuestion with interpretive options** | Step 3 | When user's description is ambiguous, present interpretations as options |
| **Goal-backward success criteria** | Step 8 | "What must be TRUE when this phase completes?" instead of listing tasks |
| **Requirement quality enforcement** | Step 7 | Success criteria must be specific, testable, atomic -- reject vague criteria |
| **Iterative approval loop** | Step 8 | Present generated spec, allow adjustments, loop until approved |
| **Immediate artifact persistence** | Steps 4,5,7,8 | Write files immediately, commit atomically |
| **Context-aware routing** | Step 2 | Check existing roadmap/codebase before creating (detect duplicates, position correctly) |
| **Parallel research** | Step 6 | Not directly applicable to add-phase, but applicable to --deep flag enrichment |
| **Downstream consumer awareness** | Step 6 | Generated specs should be written with awareness of what autopilot phase-runner needs |
| **Anti-pattern awareness** | Step 3, 8 | Avoid checklist walking, vague criteria, horizontal layers |

### Not Applicable Patterns (Project-Level Only)

| Pattern | Source Step | Why Not Applicable to Phase Creation |
|---------|-----------|-------------------------------------|
| **Brownfield detection** | Step 2 | Phase creation happens within an existing project -- brownfield/greenfield is already known |
| **Workflow preferences (config.json)** | Step 5 | Project config already exists when adding phases |
| **REQUIREMENTS.md generation** | Step 7 | Phase creation adds to existing requirements, doesn't create the requirements framework |
| **PROJECT.md generation** | Step 4 | Project context already exists |
| **4-dimension parallel research** | Step 6 | Phase-level research is narrower -- investigate specific technical domain, not full ecosystem |
| **Traceability matrix creation** | Step 7 | Traceability updates are simpler for a single phase addition |
| **Git initialization** | Step 1 | Git already exists in phase creation context |

### Partially Applicable Patterns (Need Adaptation)

| Pattern | Source Step | Adaptation Needed |
|---------|-----------|------------------|
| **Roadmap structure generation** | Step 8 | Phase creation updates an existing roadmap, not creates one from scratch. Need insert/append logic, not generation. |
| **Coverage validation** | Step 8 | Phase creation should validate the new phase doesn't create orphaned requirements or overlap with existing phases, but doesn't need full coverage audit. |
| **Research before planning** | Step 6 | Applicable to `--deep` flag only. Default phase creation skips research. |
| **Multi-agent orchestration** | Steps 6, 8 | Default add-phase should be single-agent. `--deep` flag can introduce multi-step orchestration. |

---

## Part 3: Output Quality Characteristics

### What Makes /gsd:new-project Output High Quality

1. **Rich context capture:** The questioning step gathers WHY behind the WHAT. Downstream phases inherit this understanding.

2. **Specificity enforcement:** Vague inputs are challenged, not accepted. "Handle authentication" becomes "User can log in with email/password and stay logged in across sessions."

3. **Goal-backward criteria:** Success criteria describe observable user outcomes, not implementation tasks. "User can reset forgotten password" not "Implement password reset endpoint."

4. **100% traceability:** Every requirement maps to a phase. No orphans. This is enforced as a hard gate.

5. **Immediate persistence:** Files are written and committed at each step. Context loss doesn't lose progress.

6. **Downstream consumer awareness:** Each artifact is designed with awareness of who reads it next. Research is written for the roadmapper. Requirements are written for the planner. Criteria are written for the executor.

7. **Anti-enterprise philosophy:** No PM theater. Phases are buckets of work, not project management artifacts. Solo developer + Claude workflow.

8. **Iterative refinement:** Users can adjust the roadmap through an approval loop. The system doesn't force-accept its first draft.

### Quality Gaps in Current /autopilot:add-phase

1. **Zero intelligence:** Current command is purely mechanical -- regex parsing, template insertion. No understanding of what the phase should accomplish.

2. **Stub placeholders:** All generated content is "[To be planned]" -- provides no value to the phase-runner.

3. **No questioning:** User provides a short description, gets a stub. No follow-up, no probing, no context gathering.

4. **No codebase awareness:** Doesn't check for duplicate phases, doesn't understand existing infrastructure, doesn't position with correct dependencies.

5. **No spec generation:** Doesn't generate success criteria, doesn't analyze requirements, doesn't estimate complexity.

6. **No decomposition:** A complex description that should be 3 phases gets created as 1. No multi-phase detection.

---

## Part 4: Concrete Specification for Redesigned /autopilot:add-phase

This section specifies the redesigned command across Phases 31-34. Each phase builds incrementally on the previous.

### Phase 31: Smart Input Parsing and Auto-Decomposition

**Goal:** Accept freeform input of any complexity and auto-decompose into multiple phases when appropriate.

**Behavior Specification:**

1. **Input Acceptance:** The command accepts arbitrarily long freeform text, including:
   - One-liner descriptions ("Add dark mode support")
   - Multi-sentence descriptions with context
   - Stream-of-consciousness brain dumps mixing features, bugs, improvements
   - Structured lists of items

2. **Semantic Analysis:** The command analyzes the input to determine:
   - How many distinct units of work are described
   - Whether units are independent or have dependencies
   - The complexity category of each unit (small fix, feature, infrastructure, research)

3. **Decomposition Decision Logic:**
   ```
   If input describes 1 coherent unit of work:
     -> Create 1 phase (fast path, no overhead)
   If input describes 2+ distinct items:
     -> Present numbered decomposition to user
     -> Each item: proposed title + one-sentence description
     -> User can: approve, edit, merge items, or force single phase
   ```

4. **Decomposition Presentation:**
   ```
   I see 3 distinct items in your description:

   1. Dark Mode Support -- Add system-wide dark mode toggle with theme persistence
   2. Performance Optimization -- Address slow list rendering with virtualization
   3. Export Feature -- Allow users to export data as CSV/JSON

   These would be better as separate phases. Approve this breakdown? (yes / adjust / single phase)
   ```

5. **Dependency Chain:** When multiple phases are created, the command:
   - Analyzes which phases depend on others
   - Sets dependency chains automatically
   - Numbers sequentially from the next available integer

**Implementation Details:**
- Input parsing should use Claude's semantic understanding, not keyword matching
- The "single coherent unit" test: Could this be delivered and verified independently as one phase?
- When in doubt, ask the user rather than auto-decomposing

**Files to Modify:**
- `src/commands/autopilot/add-phase.md` -- complete rewrite of the execution section

**Acceptance Criteria for Phase 31:**
1. Freeform descriptions of any length accepted without truncation
2. Multi-item inputs detected and presented as decomposition proposals
3. Single-item inputs create one phase instantly (no added latency)
4. User can approve, edit, or reject decomposition
5. Multiple phases created with proper numbering and dependency chains

---

### Phase 32: Rich Phase Specification Generation

**Goal:** Generate detailed phase specifications instead of stub placeholders.

**Behavior Specification:**

1. **Goal Generation:** From the user's description (or decomposed item), generate a detailed Goal section:
   - Minimum 2-3 sentences
   - Describes WHAT needs to be done and WHY
   - Uses goal-backward framing: "When this phase completes, X will be true"
   - References existing codebase patterns where relevant

2. **Success Criteria Generation:** Generate 3-5 success criteria per phase:
   - Each criterion is specific and testable
   - Uses the pattern: "[Observable outcome] -- [how to verify]"
   - Criteria describe user-observable outcomes, not implementation tasks
   - At least one criterion should be machine-verifiable (grep pattern, file existence, command output)

3. **Dependency Analysis:** Analyze and generate a "Depends on" section:
   - Read existing roadmap phases
   - Identify which existing phases provide infrastructure this new phase needs
   - Explain WHY each dependency exists, not just list numbers
   - Example: "Depends on Phase 29 (reuses the one-question-at-a-time discuss infrastructure)"

4. **Preliminary Task Breakdown:** Generate a preliminary plans section:
   - 2-5 high-level tasks that decompose the goal
   - Each task is a verb-phrase describing a deliverable
   - Tasks ordered by natural execution sequence

5. **Requirements Section:** If the phase maps to existing requirements, reference them. If new requirements are implied, suggest REQ-IDs.

**Quality Enforcement:**
- Reject criteria that are purely prose ("should work correctly")
- Push for specificity: "Feature X is implemented" -> "User can invoke feature X and see result Y"
- Success criteria should satisfy the plan-checker's requirements (PLAN-01, PLAN-02)
- Generated specs should match quality of best existing phases (2.1, 3.1, 4.1 as examples)

**Downstream Consumer Awareness:**
Generated specs must be rich enough that `autopilot <N>` (the phase-runner) can:
- Research the domain effectively
- Plan executable tasks
- Execute and verify without additional user input
- The phase-runner should NOT need to re-derive what "done" looks like

**Files to Modify:**
- `src/commands/autopilot/add-phase.md` -- add spec generation logic after decomposition

**Acceptance Criteria for Phase 32:**
1. Every created phase has a Goal section of 2+ sentences (not a one-liner placeholder)
2. Every created phase has 3+ success criteria that are specific and verifiable
3. Every created phase has a Depends on section with rationale
4. Generated specs match quality of best existing roadmap entries
5. The command uses understanding of the request to generate criteria, not just parroting input

---

### Phase 33: Codebase-Aware Phase Positioning

**Goal:** Before creating phases, scan existing roadmap and codebase to avoid duplicates and position correctly.

**Behavior Specification:**

1. **Duplicate Detection:** Before creating a new phase, the command:
   - Reads all existing phase entries in ROADMAP.md
   - Compares the proposed phase against existing phases (semantic similarity, not just string matching)
   - If overlap detected (>70% semantic overlap with an existing phase):
     ```
     Warning: This looks similar to existing Phase 27: "Phase Management Command Overhaul"

     Options:
     1. Create anyway (it's different enough)
     2. Extend Phase 27 instead (use /autopilot:insert-phase 27.1)
     3. Cancel
     ```

2. **Infrastructure Awareness:** The command:
   - Reads completed phases to understand what infrastructure exists
   - Scans the codebase (using repo-map if available) for relevant existing implementations
   - References existing capabilities in the new phase's spec
   - Example: "This phase can leverage the one-question-at-a-time pattern already implemented in Phase 29"

3. **Dependency Positioning:** The command:
   - Analyzes technical dependencies between the new phase and existing phases
   - Sets the Depends on field based on actual technical needs
   - Positions the phase in the execution order at the correct point
   - Does NOT just append to the end -- inserts at the dependency-correct position

4. **Completed Phase Awareness:** The command:
   - Knows which phases are completed, in progress, or pending
   - Does not suggest dependencies on pending phases unless necessary
   - Warns if the new phase depends on a pending phase: "This depends on Phase 31 which hasn't been executed yet"

**Files to Modify:**
- `src/commands/autopilot/add-phase.md` -- add codebase scanning and duplicate detection before creation

**Acceptance Criteria for Phase 33:**
1. Duplicate/overlap detection warns before creating redundant phases
2. New phases reference existing infrastructure in their specs
3. Dependencies are set based on technical analysis, not just sequential numbering
4. When overlap with existing phase is detected, user can choose to extend instead of duplicate

---

### Phase 34: Deep Context Gathering Flag (--deep)

**Goal:** Add a `--deep` flag that triggers conversational context gathering before phase creation.

**Behavior Specification:**

1. **Invocation:** `/autopilot:add-phase --deep <description>`

2. **Questioning Flow:** Adapts the `/gsd:new-project` Step 3 (Deep Questioning) pattern for phase-level scope:
   - Opens with the user's description as context
   - Asks phase-specific questions about:
     - Expected behavior in detail
     - Edge cases and error handling
     - Scope boundaries (what's in vs out)
     - Implementation preferences
     - Relationship to existing features
   - Uses one-question-at-a-time pattern (from Phase 29's discuss overhaul)
   - Adapts questions based on answers (not a fixed script)

3. **Question Generation:** Questions are derived from the phase content, not generic:
   ```
   For "Add dark mode support":
   - "Should dark mode follow system preference, have its own toggle, or both?"
   - "Which components should be themed? Everything, or just the main views?"
   - "Should the theme persist across sessions?"
   - "Any specific color palette in mind, or should I follow standard dark mode patterns?"

   NOT:
   - "Tell me more about this feature"
   - "What are your success criteria?"
   - "Who are the stakeholders?"
   ```

4. **Context Incorporation:** Answers are incorporated into the generated phase spec:
   - Success criteria become more specific based on answers
   - Goal section reflects user's exact vision
   - Edge cases mentioned become explicit acceptance criteria
   - Scope boundaries become Out of Scope items in the phase detail

5. **Context Persistence:** The gathered context is saved to a CONTEXT.md file in the phase directory:
   - Same format as `/gsd:discuss-phase` CONTEXT.md
   - Available to the phase-runner during research and planning
   - Structured as decisions (not raw Q&A)

6. **Adaptive Flow with Decision Gate:**
   - After each answer, determine if more questions are needed
   - Check context checklist mentally: Do we know what, why, how, and what "done" looks like?
   - When sufficient context gathered, offer to proceed:
     ```
     "I think I have a good understanding. Ready to create the phase?"
     Options: "Create phase" / "I want to add more"
     ```

7. **Without --deep:** The command works well without the flag (Phases 31-33 handle baseline quality). The flag is purely additive -- it enriches the spec, doesn't gate basic functionality.

**Anti-Patterns to Avoid (adapted from questioning.md):**
- Checklist walking -- do not ask generic questions for every phase
- Corporate speak -- no "stakeholders", "success criteria", "KPIs"
- Interrogation -- build on answers, do not fire questions
- Premature constraints -- ask about what before how
- Shallow acceptance -- probe vague answers

**Files to Modify:**
- `src/commands/autopilot/add-phase.md` -- add --deep flag handling and questioning flow

**Files to Reference:**
- Phase 29's discuss implementation (one-question-at-a-time infrastructure)
- `questioning.md` reference file for techniques

**Acceptance Criteria for Phase 34:**
1. `--deep` flag triggers interactive question flow with one-question-at-a-time pattern
2. Questions are specific to the phase content, not generic
3. Answers are incorporated into richer Goal and Success Criteria sections
4. Questions adapt based on previous answers
5. Without `--deep`, the command still works well (baseline from phases 31-33)
6. Context is saved to CONTEXT.md in the phase directory

---

## Part 5: Implementation Sequence and Dependencies

```
Phase 31 (Smart Input Parsing)
    |
    v
Phase 32 (Rich Spec Generation)  -- builds on parsed input from Phase 31
    |
    v
Phase 33 (Codebase-Aware Positioning)  -- enhances specs from Phase 32 with codebase context
    |
    v
Phase 34 (Deep Context Gathering)  -- adds optional --deep enrichment on top of Phase 33
```

Each phase is independently deliverable and testable. Phase 31 alone improves add-phase significantly. Phase 32 adds spec quality. Phase 33 adds awareness. Phase 34 adds depth.

### File Modification Summary

All 4 phases modify the same primary file:
- `src/commands/autopilot/add-phase.md` -- progressive enhancement of the command

Supporting changes may include:
- Roadmap updates (success criteria, plans sections for phases 31-34)
- REQUIREMENTS.md updates if new requirement IDs are needed

### Quality Targets

The redesigned `/autopilot:add-phase` should produce phase specifications that:
1. A phase-runner can execute without additional context gathering (autonomy target)
2. The plan-checker accepts on first pass (machine-verifiable criteria)
3. Match the quality of manually-authored phases like 2.1, 3.1, 4.1 (detail level target)
4. Never produce "[To be planned]" stubs (zero-stub target)
5. Position correctly in the roadmap without manual dependency adjustment (positioning target)

---

## Appendix A: Comparison -- Current vs. Redesigned add-phase

| Aspect | Current `/autopilot:add-phase` | Redesigned (Phases 31-34) |
|--------|-------------------------------|--------------------------|
| Input | Short description string | Freeform text of any length |
| Decomposition | None (always 1 phase) | Auto-detects multi-phase inputs |
| Goal section | "[To be planned]" stub | 2-3 sentence detailed goal |
| Success criteria | "[To be defined]" stub | 3-5 specific, testable criteria |
| Dependencies | "Phase {N-1} (independent)" | Analyzed from roadmap and codebase |
| Codebase awareness | None | Scans for duplicates and existing infrastructure |
| Questioning | None | Optional --deep flag for interactive context gathering |
| Requirement mapping | None | Maps to existing or suggests new REQ-IDs |
| Quality enforcement | None | Rejects vague criteria, enforces specificity |
| Phase-runner readiness | Not ready (stubs everywhere) | Ready to execute without additional research |

## Appendix B: Pattern Catalog from /gsd:new-project

| # | Pattern Name | Description | Files Where Implemented |
|---|-------------|-------------|------------------------|
| 1 | Dream Extraction | Collaborative thinking to sharpen fuzzy ideas | questioning.md |
| 2 | Thread Following | Dig into what excited user, follow energy | questioning.md |
| 3 | Vagueness Challenge | Never accept fuzzy answers, push for specificity | questioning.md |
| 4 | Abstract -> Concrete | "Walk me through using this" technique | questioning.md |
| 5 | Goal-Backward Criteria | "What must be TRUE?" not "What tasks?" | gsd-roadmapper.md |
| 6 | 100% Coverage Gate | Every requirement maps to a phase, no orphans | gsd-roadmapper.md |
| 7 | Parallel Research | 4-dimension research with synthesis | new-project.md workflow |
| 8 | Downstream Consumer Awareness | Each artifact designed for its reader | gsd-project-researcher.md |
| 9 | Anti-Enterprise | No PM theater, solo dev + Claude workflow | gsd-roadmapper.md |
| 10 | Atomic Commits | Write and commit at each step | new-project.md workflow |
| 11 | Iterative Approval | Present, allow adjustment, loop until approved | new-project.md workflow Step 8 |
| 12 | AskUserQuestion Probing | Options as interpretations, 2-4 choices, escape hatch | questioning.md |
| 13 | Context Checklist | Background mental check, not spoken | questioning.md |
| 14 | Decision Gate | "Ready to proceed?" with keep-exploring option | questioning.md |
| 15 | Auto Mode | Document-driven initialization skipping interaction | new-project.md workflow |
| 16 | Brownfield Detection | Context-aware routing based on existing state | new-project.md workflow Step 2 |
| 17 | REQ-ID System | Category-prefixed IDs for traceability | requirements.md template |
| 18 | Depth Calibration | Quick/Standard/Comprehensive compression guidance | gsd-roadmapper.md |
| 19 | Structured Returns | ROADMAP CREATED / BLOCKED / REVISED protocols | gsd-roadmapper.md |
| 20 | Stage Banners | Visual workflow progression indicators | ui-brand.md |
