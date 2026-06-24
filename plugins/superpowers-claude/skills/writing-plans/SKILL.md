---
name: writing-plans
description: Use when an approved spec or requirements artifact exists and implementation planning must happen before code changes
---

# Writing Plans

## Core Rule

The main agent is the orchestrator, not the plan author. It prepares durable inputs, dispatches fresh subagents (Task tool), captures their compact outputs, and stores artifacts. Each Task subagent returns its result and terminates on its own — keep only its compact result/receipt, never its raw working context. When subagents are available, do not write or review the implementation plan inline, and default to subagent-driven execution rather than inline.

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

- repository root (absolute path)
- approved spec path
- context-pack path
- explicit constraints
- required plan directory format

```text
You are writing an implementation plan from saved artifacts.
Do not use chat history.
Do not implement code.
You may read files and run git diff in the repository root to verify paths, symbols, and tests; do not commit or modify anything.
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

### 6. Approval gate (conditional)

Plan review (`superpowers:reviewing-plans`) always runs — only the human approval step is conditional.

Auto-proceed when the review receipt is `approved` with no open blockers: log the clean review and continue straight to Execution Handoff without asking. The approved spec is the single human gate; after it, the orchestrator runs to an open PR without further approval stops.

Require explicit human approval only when the review returns `issues-found` or `blocked`, or when the human partner pre-requested a plan gate. Unresolved blockers escalate per the cycle limits (see `superpowers:reviewing-plans`), they do not silently auto-proceed.

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

Before execution, use `superpowers:using-git-branches`. It auto-creates a feature branch when on a long-lived base (`main`, `master`, or `dev`), so do not ask whether to create one — just invoke it and work in the resulting checkout. Do not create a worktree unless explicitly requested.

## Execution Handoff

Once the approval gate is cleared (auto or explicit), hand off to execution. Subagent-driven is the default whenever the Task tool is available: launch `superpowers:subagent-driven-development` (fresh subagent per task, review between tasks) without asking.

Inline execution (`superpowers:executing-plans`, this session with checkpoints) is an explicit opt-in/fallback — use it only when the human partner asked for inline, not as a symmetric choice. Do not present a "which approach?" menu.

Log the handoff:

```text
Plan complete and saved to <plan overview>. Review status: <approved/issues-found>. Executing subagent-driven per default.
```

## Fallback

The fallback is coordinator-only. Inline work is limited to coordination and state (dispatching, capturing receipts, writing artifacts) and is allowed only when the human partner explicitly asks you to work inline — never as an automatic response to the Task tool being unavailable.

Do not perform subagent-class work inline: no repo inspection, no snippet checking, no file audits, no context-pack generation. That work always goes to fresh read-only subagents.

If subagent-class work (inspection, spec, plan, or review) is needed but the Task tool is genuinely unavailable, escalate to the human partner or hard-stop. Do not substitute the coordinator for a subagent. Whatever runs inline must still use the approved spec and context pack as the only source of truth and must not carry brainstorming history into execution.
