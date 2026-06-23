---
name: writing-plans
description: Use when an approved spec or requirements artifact exists and implementation planning must happen before code changes
---

# Writing Plans

## Core Rule

The main agent is the orchestrator, not the plan author. It prepares durable inputs, dispatches fresh subagents (Task tool), captures their compact outputs, and stores artifacts. Each Task subagent returns its result and terminates on its own — keep only its compact result/receipt, never its raw working context. When subagents are available, do not write or review the implementation plan inline.

## Source of Truth

Use saved artifacts, not chat history.

Authoritative inputs:

1. Approved spec or requirements document
2. Decision pack or phase handoff, if present
3. Current repository state
4. Explicit human constraints

Do not use rejected brainstorming ideas, old draft plans, or conversation sludge unless they were copied into the approved spec or decision pack.

## Output Location

For non-trivial work, save plans as a directory:

```text
docs/superpowers/plans/YYYY-MM-DD-<feature-name>/
  overview.md
  context-pack.md
  task-001-name.md
  task-002-name.md
  review-findings.md
  status.json
```

Single-file plans are allowed only for tiny changes. The default is a plan directory.

## Orchestrated Planning Flow

### 1. Prepare inputs

The main agent reads only the approved spec, decision pack/handoff, and minimal repository metadata needed to dispatch subagents.

### 2. Dispatch context-scout subagent

Dispatch a subagent (Task tool). Give it only the approved spec, decision pack/handoff, and repository paths to inspect.

```text
You are building a context pack for implementation planning.
Do not write a plan.
Do not modify files.
Do not use chat history.
Return: relevant files, responsibilities, existing patterns, test commands, constraints, risks, and open questions.
```

Capture the result as `context-pack.md`. Keep only that compact artifact; do not carry the subagent's raw working context forward.

### 3. Dispatch plan-author subagent

Dispatch a subagent. Give it only:

- approved spec path
- context-pack path
- explicit constraints
- required plan directory format

```text
You are writing an implementation plan from saved artifacts.
Do not use chat history.
Do not implement code.
Write a plan directory with overview.md, task files, status.json, and concrete verification steps.
Prefer TDD task order.
Mark risk tier and review policy per task.
If something is unknown, add an open question instead of guessing.
```

Capture the result and write the plan files. Keep only the compact receipt; do not carry the subagent's raw working context forward.

### 4. Review the plan with fresh subagents

Use `superpowers:reviewing-plans`. Reviewers get only the approved spec, context pack, plan directory, and relevant repository files.

After each reviewer returns, capture its compact receipt and discard its raw working context. If follow-up is needed, dispatch a fresh subagent with the prior result and the exact follow-up scope.

### 5. Patch and re-review

The main agent may patch plan text only to apply concrete reviewer findings. If the plan changed materially, dispatch a fresh targeted reviewer for changed sections plus dependencies. Do not re-run full review for typo-only edits.

### 6. Human approval

After blocking review findings are resolved, ask the human partner to approve the plan before execution.

## Context Pack Template

```markdown
# Context Pack

**Spec:** docs/superpowers/specs/YYYY-MM-DD-feature.md

## Repository Map

| Path | Responsibility | Why it matters |
|------|----------------|----------------|

## Existing Patterns

## Constraints

## Test Commands

## Risk Triggers

## Open Questions
```

Keep it concise. It is sterile context for subagents, not a chat transcript.

## Plan Overview Template

```markdown
# [Feature Name] Implementation Plan

> **For agentic workers:** Before execution, validate with `superpowers:reviewing-plans`, then execute with `superpowers:subagent-driven-development` or `superpowers:executing-plans`.

**Goal:** ...
**Architecture:** ...
**Tech Stack:** ...
**Spec:** `...`
**Context Pack:** `...`
**Review Mode:** light | targeted | full | risk-tiered

## Task Index

| Task | File | Risk | Depends on | Summary |
|------|------|------|------------|---------|
```

## Task File Template

````markdown
# Task N: [Name]

**Risk:** low | medium | high
**Depends on:** Task N, or none
**Review policy:** group | per-task | per-task-plus-risk

**Files:**
- Create: `exact/path`
- Modify: `exact/path`
- Test: `exact/path`

## Context

Why this task exists.

- [ ] **Step 1: Write failing test**

```language
actual test code or exact test description
```

- [ ] **Step 2: Verify RED**

Run: `exact command`
Expected: exact failure

- [ ] **Step 3: Minimal implementation**

```language
code for small changes, or exact implementation instructions for large changes
```

- [ ] **Step 4: Verify GREEN**

Run: `exact command`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add <paths>
git commit -m "..."
```
````

## Review Requirements

Plan review must check:

- spec coverage
- missing or extra scope
- stale files, imports, symbols, commands, and tests
- task dependency order
- concrete verification
- risk handling for high-risk changes

Any blocking issue prevents execution.

## Branch Context

Before execution, use `superpowers:using-git-branches`. Work in the current checkout. If on `main` or `master`, ask whether to create a feature branch or work directly there. Do not create a worktree unless explicitly requested.

## Execution Handoff

After plan review and human approval, offer:

```text
Plan complete and saved to <plan overview>. Review status: <approved/issues-found>. Two execution options:

1. Subagent-Driven - fresh subagent per task with review between tasks
2. Inline Execution - execute in this session with checkpoints

Which approach?
```

## Fallback

If subagents are unavailable or the human partner asks you to work inline, the main agent may write and review the plan inline. It must still use the approved spec and context pack as the only source of truth and must not carry brainstorming history into execution.
