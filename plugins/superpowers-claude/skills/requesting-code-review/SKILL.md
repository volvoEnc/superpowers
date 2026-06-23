---
name: requesting-code-review
description: Use when completing tasks, implementing major features, or before merging to verify work meets requirements
---

# Requesting Code Review

Dispatch a code reviewer subagent to catch issues before they cascade. The reviewer gets precisely crafted context for evaluation — never your session's history. This keeps the reviewer focused on the work product, not your thought process, and preserves your own context for continued work.

**Core principle:** Review early, review often.

## When to Request Review

**Mandatory:**
- After each task in subagent-driven development
- After completing major feature
- Before merge to main

**Optional but valuable:**
- When stuck (fresh perspective)
- Before refactoring (baseline check)
- After fixing complex bug

## Built-in code review vs subagent reviewers

Two complementary tools. Choose by what kind of judgment is needed.

- **`/code-review` (built-in)** — automatic hygiene: correctness bugs, dead code, style, simplification. Fast, runs on the live diff, no clean-context dispatch needed. Default for mechanical quality.
- **Manual subagent reviewers** (this skill) — judgment: architecture, intent, domain rules, cross-system effects. Gets precisely crafted context, preserves orchestrator context. Use when the question is "is this the *right* design?", not "is this code correct?".

They are not redundant — run both when the work is non-trivial. When a built-in finding and a manual reviewer's judgment conflict, manual judgment wins; on a real contradiction, ask your human partner. Full decision tree, effort ladder, and precedence rule: `../../docs/review-integration-doctrine.md`.

**Effort ladder for `/code-review`:**
- `low` — routine, low-risk changes (per-task during implementation).
- `medium` — riskier changes; default gate before finishing a branch.
- `high`+ — pre-merge or high-stakes diffs; broader, may surface uncertain findings.

**Flags:**
- `/code-review --comment` — posts findings as inline PR annotations (review-in-place on a PR).
- `/code-review --fix` — applies the findings to the working tree. Run this **only after** a manual reviewer has approved the design, so auto-edits don't conflict with judgment-level changes you still intend to make.

## How to Request

**1. Get git SHAs:**
```bash
BASE_SHA=$(git rev-parse HEAD~1)  # or origin/main
HEAD_SHA=$(git rev-parse HEAD)
```

**2. Dispatch code reviewer subagent:**

Use Task tool with `general-purpose` type, fill template at `code-reviewer.md`

**Placeholders:**
- `{DESCRIPTION}` - Brief summary of what you built
- `{PLAN_OR_REQUIREMENTS}` - What it should do
- `{BASE_SHA}` - Starting commit
- `{HEAD_SHA}` - Ending commit

**3. Act on feedback:**
- Fix Critical issues immediately
- Fix Important issues before proceeding
- Note Minor issues for later
- Push back if reviewer is wrong (with reasoning)

## Example

```
[Just completed Task 2: Add verification function]

You: Let me request code review before proceeding.

BASE_SHA=$(git log --oneline | grep "Task 1" | head -1 | awk '{print $1}')
HEAD_SHA=$(git rev-parse HEAD)

[Dispatch code reviewer subagent]
  DESCRIPTION: Added verifyIndex() and repairIndex() with 4 issue types
  PLAN_OR_REQUIREMENTS: Task 2 from docs/superpowers/plans/deployment-plan.md
  BASE_SHA: a7981ec
  HEAD_SHA: 3df7661

[Subagent returns]:
  Strengths: Clean architecture, real tests
  Issues:
    Important: Missing progress indicators
    Minor: Magic number (100) for reporting interval
  Assessment: Ready to proceed

You: [Fix progress indicators]
[Continue to Task 3]
```

## Integration with Workflows

**Subagent-Driven Development:**
- Review after EACH task
- Catch issues before they compound
- Fix before moving to next task

**Executing Plans:**
- Review after each task or at natural checkpoints
- Get feedback, apply, continue

**Ad-Hoc Development:**
- Review before merge
- Review when stuck

## Red Flags

**Never:**
- Skip review because "it's simple"
- Ignore Critical issues
- Proceed with unfixed Important issues
- Argue with valid technical feedback

**If reviewer wrong:**
- Push back with technical reasoning
- Show code/tests that prove it works
- Request clarification

See template at: requesting-code-review/code-reviewer.md
