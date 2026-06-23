---
name: subagent-driven-development
description: Use when executing implementation plans with independent tasks in the current session
---

# Subagent-Driven Development

Execute a reviewed implementation plan with fresh subagents. The controller keeps the project state, dispatches one bounded unit of work at a time, records each result, and only then moves forward.

## Start In The Current Checkout

Before implementation, use `superpowers:using-git-branches` in `implementation-start` mode.

- Work in the current checkout by default.
- If the current branch is `main` or `master`, the branch skill creates a task branch before implementation starts.
- Do not create a git worktree unless the human partner explicitly asks for one.

## Subagent Lifecycle

Each Task subagent returns its result and terminates on its own. Keep only its compact result/receipt — never carry its raw working context, file dumps, or transcript forward.

```text
dispatch subagent (Task tool) -> wait for result -> capture result
```

This applies to task implementers, spec reviewers, quality reviewers, final reviewers, scouts, and investigation subagents.

The written result is the artifact. If follow-up is needed, dispatch a fresh subagent with the prior result and the exact follow-up scope.

## Per-Task Loop

For each task in the plan:

1. Read the task file and the context pack.
2. Dispatch one implementation subagent (Task tool) with only the task text and needed context.
3. Wait for the result.
4. Capture the result in your notes or task status.
5. If the subagent reports `NEEDS_CONTEXT`, `BLOCKED`, or concerns, resolve that before review.
6. Dispatch a spec reviewer.
7. Wait and capture the review.
8. If spec review finds issues, dispatch a fresh follow-up subagent, then a fresh spec reviewer.
9. After spec review passes, dispatch a quality reviewer.
10. Wait and capture the review.
11. If quality review finds issues, dispatch a fresh follow-up subagent, then a fresh quality reviewer.
12. Mark the task complete only when reviews pass.

After all tasks, dispatch a final reviewer, capture its result, then use `superpowers:finishing-a-development-branch`.

## Handling Status

**DONE:** Continue to spec review.

**DONE_WITH_CONCERNS:** Read the concerns. If they affect correctness or scope, resolve them before review. Otherwise note them and continue.

**NEEDS_CONTEXT:** Capture the request, then provide the missing context to a fresh subagent.

**BLOCKED:** Change something before retrying: add context, use a more capable model, split the task, or escalate if the plan is wrong.

## Red Flags

Never:

- Start implementation on `main` or `master`; run `superpowers:using-git-branches` first so it can create a task branch
- Create a worktree unless explicitly requested
- Skip spec review or quality review
- Move to the next task while review issues remain open
- Carry a subagent's raw working context or transcript forward instead of its compact result
- Reuse a prior subagent's result as memory in place of dispatching a fresh subagent with the exact follow-up scope

## Integration

Required workflow skills:

- `superpowers:using-git-branches`
- `superpowers:writing-plans`
- `superpowers:requesting-code-review`
- `superpowers:finishing-a-development-branch`

Subagents should follow `superpowers:test-driven-development` when a task requires implementation work.
