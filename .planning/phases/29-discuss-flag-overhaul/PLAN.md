# Phase 29: Discuss Flag Overhaul - Plan

## Overview

Rewrite the autopilot `--discuss` implementation to use GSD-style one-question-at-a-time interactive flow. The current implementation dumps questions as a text block; the new version asks one question at a time with concrete options and adaptive follow-ups.

## Traceability

| Requirement | Task |
|-------------|------|
| One-question-at-a-time flow | 29-01 |
| Concrete options per question | 29-01 |
| Context-aware follow-ups | 29-01 |
| Depth control (4 questions then offer more/next) | 29-01 |
| Gray area analysis produces question options | 29-02 |
| Update autopilot command definition | 29-03 |
| Structured output (CONTEXT.md format) preserved | 29-01 |

## Wave 1

<task id="29-01" type="auto" complexity="complex">
### Task 29-01: Rewrite Section 1.7 Steps 2-3 in Orchestrator Guide

**Files:** `/mnt/c/Users/Parth/.claude/autopilot/protocols/autopilot-orchestrator.md`

**Action:**
Rewrite Section 1.7 of the orchestrator guide (the `--discuss` mode), specifically Steps 2 and 3, to implement a GSD-style one-question-at-a-time interactive flow. Key changes:

1. **Step 2 (Gray Area Selection):** Keep the numbered list presentation but make it cleaner. After the gray area analysis agent returns, present areas with clear descriptions. User selects by number (already works).

2. **Step 3 (Per-Area Conversational Probing):** COMPLETELY REWRITE to use one-question-at-a-time flow:
   - For each selected area, present ONE question with 2-4 concrete options (not free text)
   - Each question is presented independently, with its options
   - After the user answers, the next question adapts based on the answer
   - After every 4 questions in an area: offer "More questions about {area}, or move to next area?"
   - If "more": generate 2-3 context-aware follow-up questions based on answers so far
   - If "next": proceed to next area
   - After all areas: "That covers {list}. Ready to create context?"

3. **Question format per question:**
   ```
   {area}: Question {N}

   {question text}

   Options:
   a) {concrete choice 1}
   b) {concrete choice 2}
   c) {concrete choice 3}
   d) You decide (Claude's discretion)

   (Enter a letter, or type a custom answer)
   ```

4. **Remove the old "Answer inline" block pattern.** Replace with the sequential one-question format above.

5. **Keep Steps 1, 4, 5 largely unchanged** (gray area analysis agent, output writing, phase-runner injection).

6. **Update the Step 1 gray area analysis agent prompt** to also generate concrete options for each sample question (so the orchestrator has options ready for the first round of questions).

**Verify:**
- One-question-at-a-time pattern exists in Step 3 -- verified by: `grep -c 'ONE question' /mnt/c/Users/Parth/.claude/autopilot/protocols/autopilot-orchestrator.md` (returns at least 1)
- Concrete options format present -- verified by: `grep 'Options:' /mnt/c/Users/Parth/.claude/autopilot/protocols/autopilot-orchestrator.md | grep -c 'a)'` (returns at least 1)
- Old "Answer inline" pattern removed -- verified by: `grep -c 'Answer inline' /mnt/c/Users/Parth/.claude/autopilot/protocols/autopilot-orchestrator.md` (returns 0)
- Depth control after 4 questions -- verified by: `grep -c 'After.*4 questions' /mnt/c/Users/Parth/.claude/autopilot/protocols/autopilot-orchestrator.md` (returns at least 1)
- Context-aware follow-ups mentioned -- verified by: `grep -c 'based on.*answer' /mnt/c/Users/Parth/.claude/autopilot/protocols/autopilot-orchestrator.md` (returns at least 1)
- Gray area analysis returns question options -- verified by: `grep 'options' /mnt/c/Users/Parth/.claude/autopilot/protocols/autopilot-orchestrator.md | grep -c 'sample_questions\|question_options'` (returns at least 1)
- Test specification -- verified by: `bash .planning/phases/29-discuss-flag-overhaul/tests/task-29-01.sh 2>&1; echo EXIT:$?` (expect EXIT:0)

**Done:** Section 1.7 Steps 2-3 fully rewritten with one-question-at-a-time flow, concrete options, adaptive follow-ups, and depth control.
</task>

<task id="29-02" type="auto" complexity="medium">
### Task 29-02: Update Gray Area Analysis Agent to Generate Question Options

**Files:** `/mnt/c/Users/Parth/.claude/autopilot/protocols/autopilot-orchestrator.md`

**Action:**
Update the Step 1 gray area analysis agent prompt (in Section 1.7) to generate concrete question options alongside sample questions. The current prompt asks for `sample_questions` but not options. Update:

1. Change the return JSON schema for the gray area analysis agent to include `question_options` per question:
   ```json
   {
     "gray_areas": [
       {
         "area": "specific area name",
         "description": "1-sentence description",
         "questions": [
           {
             "question": "question text",
             "options": ["concrete choice 1", "concrete choice 2", "concrete choice 3"]
           }
         ]
       }
     ]
   }
   ```

2. Add guidance in the agent prompt for generating good options:
   - Options should be concrete, not abstract ("Cards layout" not "Option A")
   - Include 2-4 options per question
   - One option can be "You decide" for deferring to Claude
   - Options should represent genuinely different implementation paths

3. Update the `<must>` section to require options generation.

**Verify:**
- Gray area analysis JSON includes question_options or options -- verified by: `grep -c '"options"' /mnt/c/Users/Parth/.claude/autopilot/protocols/autopilot-orchestrator.md` (returns at least 2)
- Options guidance in agent prompt -- verified by: `grep -c 'concrete.*not abstract\|concrete choice' /mnt/c/Users/Parth/.claude/autopilot/protocols/autopilot-orchestrator.md` (returns at least 1)
- Test specification -- verified by: `bash .planning/phases/29-discuss-flag-overhaul/tests/task-29-02.sh 2>&1; echo EXIT:$?` (expect EXIT:0)

**Done:** Gray area analysis agent prompt updated to generate concrete options per question.
</task>

<task id="29-03" type="auto" complexity="simple">
### Task 29-03: Update Autopilot Command Definition

**Files:** `/mnt/c/Users/Parth/.claude/commands/autopilot.md`

**Action:**
Update the `--discuss` section in the autopilot command definition to accurately reflect the new one-question-at-a-time interaction model:

1. Update the "If `--discuss`:" section (around line 140) to mention:
   - One-question-at-a-time flow (not a block of questions)
   - Concrete options per question
   - Adaptive follow-ups based on user answers
   - 4-question depth control per area

2. Keep the existing description of gray area identification and CONTEXT.md output.

3. Ensure the description matches the rewritten Section 1.7 in the orchestrator guide.

**Verify:**
- One-question-at-a-time mentioned in command definition -- verified by: `grep -c 'one.*question.*at.*a.*time\|one question at a time' /mnt/c/Users/Parth/.claude/commands/autopilot.md` (returns at least 1)
- Concrete options mentioned -- verified by: `grep -c 'concrete options\|concrete choices' /mnt/c/Users/Parth/.claude/commands/autopilot.md` (returns at least 1)
- Test specification -- verified by: `bash .planning/phases/29-discuss-flag-overhaul/tests/task-29-03.sh 2>&1; echo EXIT:$?` (expect EXIT:0)

**Done:** Autopilot command definition updated to reflect new discuss interaction model.
</task>

## Acceptance Criteria Summary

1. Section 1.7 Step 3 uses one-question-at-a-time flow (not block) -- verified by: `grep -c 'ONE question' /mnt/c/Users/Parth/.claude/autopilot/protocols/autopilot-orchestrator.md` (returns at least 1)
2. Questions have concrete options (a/b/c/d format) -- verified by: `grep 'Options:' /mnt/c/Users/Parth/.claude/autopilot/protocols/autopilot-orchestrator.md | grep -c 'a)'` (returns at least 1)
3. Old "Answer inline" block pattern removed -- verified by: `grep -c 'Answer inline' /mnt/c/Users/Parth/.claude/autopilot/protocols/autopilot-orchestrator.md` (returns 0)
4. Depth control (4 questions then offer more/next) present -- verified by: `grep -c 'After.*4 questions' /mnt/c/Users/Parth/.claude/autopilot/protocols/autopilot-orchestrator.md` (returns at least 1)
5. Gray area analysis agent generates options -- verified by: `grep -c '"options"' /mnt/c/Users/Parth/.claude/autopilot/protocols/autopilot-orchestrator.md` (returns at least 2)
6. Autopilot command definition reflects new model -- verified by: `grep -c 'one.*question.*at.*a.*time\|one question at a time' /mnt/c/Users/Parth/.claude/commands/autopilot.md` (returns at least 1)
