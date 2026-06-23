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
12. After quality review passes, run built-in mechanical review on the live task diff (see "Built-In Review In The Loop" below).
13. Mark the task complete only when manual reviews pass, built-in review findings are resolved (or consciously deferred), and any auto-applied edits (`/simplify`, `/code-review --fix`) are re-tested and re-reviewed.

After all tasks, dispatch a final reviewer, capture its result, then use `superpowers:finishing-a-development-branch`.

## Built-In Review In The Loop

Split review by role. Manual subagents make **judgment** calls; built-in tools handle **mechanical quality**.

| Role | Who | Looks for |
|------|-----|-----------|
| Spec review (judgment) | manual subagent (Task tool) | Does it implement the spec? Intent, scope, domain correctness. |
| Quality review (judgment) | manual subagent (Task tool) | Architecture, design fit, maintainability decisions. |
| Mechanical quality (default) | built-in `/code-review` + `/simplify` | Bugs, dead code, style; reuse and refactor cleanup. |
| Security gate (risk-tiered) | built-in `/security-review` | Tier-1 tasks only. |

Built-in tools **replace the mechanical-quality role only** — they do not replace the judgment of manual spec/quality reviewers.

After the quality reviewer passes, on the live diff for that task:

1. Run `/code-review` at **low** effort for mechanical issues.
2. Run `/simplify` for refactor cleanup (quality only — it does not hunt for bugs; `/code-review` does that). Skip if the implementer already ran `/simplify` in the TDD REFACTOR phase for this task.
3. If the task touches **Tier-1** areas, run `/security-review`. Tiers are defined once in `superpowers:verification-before-completion` ("Security-Review Risk Tiers") — do not redefine them here.
4. Resolve findings (or consciously defer).
5. **If any step applied edits** (`/simplify` or `/code-review --fix` changed files), re-run the task's tests and re-check the post-edit diff against spec and quality review before marking complete. An auto-applied fix that has not been re-tested and re-reviewed does not count as reviewed.

**Optional by risk.** Built-in review is the default for mechanical quality, but apply it per task risk so large plans don't blow the budget: skip it on trivial Tier-3 tasks (docs, UI text, tests-only); always run it on risky or Tier-1 tasks. When skipped, note `NOT-APPLICABLE` for the task.

See `../../docs/review-integration-doctrine.md` for the full automation-vs-judgment model, the effort ladder, and the conflict-precedence rule.

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

Built-in review (`/code-review`, `/simplify`, `/security-review`) follows the doctrine in `../../docs/review-integration-doctrine.md`; risk tiers come from `superpowers:verification-before-completion`.
