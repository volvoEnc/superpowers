---
name: writing-plans
description: Use when you have a spec or requirements for a multi-step task, before touching code
---

# Writing Plans

## Overview

Write comprehensive implementation plans from an approved spec, not from a polluted conversation history. The plan should be clear enough for an enthusiastic junior engineer with poor taste, no judgement, no project context, and an aversion to testing to follow. Document files, code, testing, docs, risks, and exact verification steps. DRY. YAGNI. TDD. Frequent commits.

Assume the implementer is a skilled developer, but knows almost nothing about our toolset or problem domain. Assume they don't know good test design very well.

**Announce at start:** "I'm using the writing-plans skill to create the implementation plan."

**Context:** Before execution, branch state should be checked with `superpowers:using-git-branches`. Work happens in the current checkout unless the human partner explicitly asked for a worktree.

**Save plans to:** `docs/superpowers/plans/YYYY-MM-DD-<feature-name>/overview.md`
- Put task details in sibling `task-NNN-<name>.md` files for non-trivial plans.
- Save a context pack at `docs/superpowers/plans/YYYY-MM-DD-<feature-name>/context-pack.md`.
- User preferences for plan location override this default.
- Single-file plans are acceptable for small changes, but directory plans are preferred once a plan has more than three tasks or broad context.

## Source of Truth

Use saved artifacts, not chat history.

1. The approved spec or requirements document is authoritative.
2. Old brainstorms, rejected approaches, and previous draft plans are not authoritative.
3. If the final decision is only in chat, copy it into the spec or context pack before planning.
4. If a requirement is ambiguous, resolve it before writing implementation steps.

When the platform supports subagents, use a fresh plan-author subagent for non-trivial plans. Give it only:

- Approved spec path
- Context pack path
- Relevant file map
- Test/build commands
- Explicit constraints and risks
- Required plan format

Do not give the plan-author the full conversation transcript. It is planning food poisoning.

## Scope Check

If the spec covers multiple independent subsystems, it should have been broken into sub-project specs during brainstorming. If it wasn't, suggest breaking this into separate plans, one per subsystem. Each plan should produce working, testable software on its own.

## Context Pack

Before defining tasks, write a concise context pack. This is the sterile context handed to plan authors, plan reviewers, and implementers.

```markdown
# Context Pack

**Spec:** docs/superpowers/specs/YYYY-MM-DD-feature.md

## Repository Map

| Path | Responsibility | Why it matters |
|------|----------------|----------------|
| `src/path/file.ts` | ... | ... |

## Existing Patterns

- ...

## Constraints

- ...

## Test Commands

- Unit: `...`
- Full suite: `...`

## Risk Triggers

- public API | migration | security | data loss | concurrency | cross-cutting refactor | none

## Open Questions

- None, or exact questions that block planning
```

Keep the context pack short. It should help a fresh agent orient itself without dragging in the whole archaeology pit.

## File Structure

Before defining tasks, map out which files will be created or modified and what each one is responsible for. This is where decomposition decisions get locked in.

- Design units with clear boundaries and well-defined interfaces. Each file should have one clear responsibility.
- You reason best about code you can hold in context at once, and your edits are more reliable when files are focused. Prefer smaller, focused files over large ones that do too much.
- Files that change together should live together. Split by responsibility, not by technical layer.
- In existing codebases, follow established patterns. If the codebase uses large files, don't unilaterally restructure - but if a file you're modifying has grown unwieldy, including a split in the plan is reasonable.

This structure informs the task decomposition. Each task should produce self-contained changes that make sense independently.

## Plan Directory Structure

For non-trivial work, save plans as a directory:

```text
docs/superpowers/plans/YYYY-MM-DD-<feature-name>/
  overview.md
  context-pack.md
  task-001-red-test.md
  task-002-minimal-implementation.md
  task-003-refactor.md
  review-findings.md
  status.json
```

`overview.md` is the map. Each `task-NNN-*.md` is a self-contained execution unit.

`status.json` should be simple and machine-readable:

```json
{
  "plan_id": "YYYY-MM-DD-feature-name",
  "spec": "docs/superpowers/specs/YYYY-MM-DD-feature.md",
  "current_task": "task-001-red-test.md",
  "completed_tasks": [],
  "blocked_tasks": [],
  "review_mode": "risk-tiered"
}
```

## Bite-Sized Task Granularity

**Each step is one action (2-5 minutes):**
- "Write the failing test" - step
- "Run it to make sure it fails" - step
- "Implement the minimal code to make the test pass" - step
- "Run the tests and make sure they pass" - step
- "Commit" - step

## Plan Overview Header

**Every plan overview MUST start with this header:**

```markdown
# [Feature Name] Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Before execution, validate the plan with superpowers:reviewing-plans. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

**Spec:** `docs/superpowers/specs/YYYY-MM-DD-feature.md`

**Context Pack:** `docs/superpowers/plans/YYYY-MM-DD-feature/context-pack.md`

**Review Mode:** light | targeted | full | risk-tiered

---
```

## Task Index

`overview.md` must include a task index:

```markdown
## Task Index

| Task | File | Risk | Depends on | Summary |
|------|------|------|------------|---------|
| 001 | `task-001-red-test.md` | medium | none | Add failing coverage for ... |
| 002 | `task-002-minimal-implementation.md` | medium | 001 | Implement ... |
```

Use risk tiers:

- **low:** mechanical rename, docs, small formatting, isolated test change
- **medium:** behavior change, multi-file integration, public behavior with low blast radius
- **high:** security, data loss, migrations, public APIs, concurrency, irreversible operations

## Task Structure

Each task file follows this structure:

````markdown
# Task N: [Component Name]

**Risk:** low | medium | high
**Depends on:** Task N, or none
**Review policy:** group | per-task | per-task-plus-risk

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

## Context

Why this task exists and how it fits the plan. Keep it short.

- [ ] **Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

- [ ] **Step 3: Write minimal implementation**

```python
def function(input):
    return expected
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```
````

## No Placeholders

Every step must contain the actual content an engineer needs. These are **plan failures** - never write them:
- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" / "add validation" / "handle edge cases"
- "Write tests for the above" (without actual test code)
- "Similar to Task N" (repeat the code or reference the exact task file section the implementer must read)
- Steps that describe what to do without showing how when code is required
- References to types, functions, or methods not defined in any task or already present in the repository

## Code Density

Plans need enough detail to execute, but code snippets can rot when they over-specify broad changes. Choose the density deliberately:

| Density | Use when | Required detail |
|---------|----------|-----------------|
| full | Small isolated functions, tests, exact scaffolding | Complete code blocks |
| skeletal | Multi-file changes where exact code may evolve | Exact APIs, assertions, commands, and small snippets |
| referenced | Large refactors or repo-pattern work | Exact file paths, behavior, acceptance tests, commands |

If you use skeletal or referenced density, explain why and make verification especially concrete.

## Remember

- Exact file paths always
- Complete code for small code steps
- Exact commands with expected output
- DRY, YAGNI, TDD, frequent commits
- Risk tier and review policy per task
- Each task file should be executable without rereading the whole plan

## Plan Review

After writing the complete plan, use `superpowers:reviewing-plans` before execution.

If the platform supports subagents, dispatch fresh read-only reviewers with only the approved spec, context pack, plan directory, and relevant repo files. Do not let the same plan-author be the only reviewer.

After each reviewer returns a terminal result, capture the receipt and close that subagent immediately. If re-review is needed, dispatch a fresh reviewer with the changed sections and prior receipt.

Minimum checks:

1. **Spec coverage:** Each spec requirement maps to a task and a verification step.
2. **Placeholder scan:** No patterns from the "No Placeholders" section.
3. **Type consistency:** Types, method signatures, property names, imports, and test names are consistent across tasks.
4. **Repository accuracy:** Existing files, exports, commands, and test paths actually exist or are created by earlier tasks.
5. **Risk review:** High-risk changes have rollback, compatibility, and verification strategy.

If review finds issues, fix the plan inline and re-review only changed sections plus their dependencies. If review finds a spec requirement with no task, add the task.

## Execution Handoff

After saving and reviewing the plan, offer execution choice:

**"Plan complete and saved to `docs/superpowers/plans/<plan-id>/overview.md`. Review status: <approved/issues-found>. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?"**

**If Subagent-Driven chosen:**
- **REQUIRED SUB-SKILL:** Use superpowers:subagent-driven-development
- Fresh subagent per task + two-stage review
- Use the context pack plus the current task file, not the full brainstorming transcript

**If Inline Execution chosen:**
- **REQUIRED SUB-SKILL:** Use superpowers:executing-plans
- Batch execution with checkpoints for review
