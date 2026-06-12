---
name: subagent-driven-development
description: Use when executing implementation plans with independent tasks in the current session
---

# Subagent-Driven Development

Execute a reviewed implementation plan with fresh helper agents. The controller keeps the project state, dispatches one bounded unit of work at a time, records each result, closes the helper, and only then moves forward.

## Start In The Current Checkout

Before implementation, use `superpowers:using-git-branches` in `implementation-start` mode.

- Work in the current checkout by default.
- If the current branch is `main` or `master`, the branch skill creates a task branch before implementation starts.
- Do not create a git worktree unless the human partner explicitly asks for one.

## Required Helper Lifecycle

Every helper that returns a terminal result must be closed immediately after its result is captured.

```text
spawn helper -> wait for result -> capture result -> close helper
```

This applies to task implementers, spec reviewers, quality reviewers, final reviewers, scouts, and investigation helpers.

Do not keep completed helpers open for later. Their written result is the artifact. If more work is needed, start a new helper with the prior result and exact follow-up scope.

## Per-Task Loop

For each task in the plan:

1. Read the task file and the context pack.
2. Dispatch one implementation helper with only the task text and needed context.
3. Wait for the result.
4. Capture the result in your notes or task status.
5. Close the implementation helper.
6. If the helper reports `NEEDS_CONTEXT`, `BLOCKED`, or concerns, resolve that before review.
7. Dispatch a spec reviewer.
8. Wait, capture the review, and close the reviewer.
9. If spec review finds issues, dispatch a fresh follow-up helper, then a fresh spec reviewer.
10. After spec review passes, dispatch a quality reviewer.
11. Wait, capture the review, and close the reviewer.
12. If quality review finds issues, dispatch a fresh follow-up helper, then a fresh quality reviewer.
13. Mark the task complete only when reviews pass.

After all tasks, dispatch a final reviewer, capture its result, close it, then use `superpowers:finishing-a-development-branch`.

## Handling Status

**DONE:** Continue to spec review.

**DONE_WITH_CONCERNS:** Read the concerns. If they affect correctness or scope, resolve them before review. Otherwise note them and continue.

**NEEDS_CONTEXT:** Provide the missing context to a fresh helper. Close the original helper after capturing the request.

**BLOCKED:** Change something before retrying: add context, use a more capable model, split the task, or escalate if the plan is wrong.

## Red Flags

Never:

- Start implementation on `main` or `master`; run `superpowers:using-git-branches` first so it can create a task branch
- Create a worktree unless explicitly requested
- Skip spec review or quality review
- Move to the next task while review issues remain open
- Leave a completed helper open after reading its result
- Use an old helper thread as memory for a later phase

## Integration

Required workflow skills:

- `superpowers:using-git-branches`
- `superpowers:writing-plans`
- `superpowers:requesting-code-review`
- `superpowers:finishing-a-development-branch`

Helpers should follow `superpowers:test-driven-development` when a task requires implementation work.
