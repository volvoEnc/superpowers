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

1. **per this task only:** read this task file and the relevant context-pack slice — hold only the current task in context. Do not read ahead to later tasks. Discard the task text after its receipt is written (see "Maintaining Execution State").
2. Dispatch one implementation subagent (Task tool) with only the task text and needed context.
3. Wait for the result.
4. Write the result to the durable per-task receipt `docs/superpowers/runs/<run>/task-NNN-result.md` (see "Maintaining Execution State"). After compaction, read these receipt files — not chat — to recover prior results.
5. If the subagent reports `NEEDS_CONTEXT`, `BLOCKED`, or concerns, resolve that before review.
6. Dispatch a spec reviewer.
7. Wait and capture the review.
8. If spec review finds issues, dispatch a fresh follow-up subagent, then a fresh spec reviewer.
9. After spec review passes, dispatch a quality reviewer.
10. Wait and capture the review.
11. If quality review finds issues, dispatch a fresh follow-up subagent, then a fresh quality reviewer.
12. After quality review passes, run built-in mechanical review on the live task diff (see "Built-In Review In The Loop" below).
13. Mark the task complete only when manual reviews pass, built-in review findings are resolved (or consciously deferred), and any auto-applied edits (`/simplify`, `/code-review --fix`) are re-tested and re-reviewed. Then update `state.json` (`current_task`, `completed_tasks`, `blocked_tasks`, `last_green_commit`) per "Maintaining Execution State".

After all tasks, dispatch a final reviewer, capture its result, then use `superpowers:finishing-a-development-branch`.

## Maintaining Execution State

Execution state lives on disk so the orchestrator stays light and can resume after a compaction. Do not keep run progress only in chat.

**Before the first write** of `state.json` or any per-task receipt, ensure the run directory exists so the write does not fail: `mkdir -p docs/superpowers/runs/<run>/`.

After **each task** completes (or blocks), update `state.json` in the run directory (`docs/superpowers/runs/<run>/state.json`). Write the fields `current_task`, `completed_tasks`, `blocked_tasks`, and `last_green_commit`. The full schema — including these fields and their shapes — is single-sourced in `superpowers:phase-handoff` (`## State JSON`); reference it there, do not redefine field shapes here.

When a unit is dispatched, also track its liveness in `state.json` via the `inflight[]` entry (`deadline_s`, `promoted`, `dispatched_at`, `last_progress_at`, `restarts`) — field shapes are single-sourced in `superpowers:phase-handoff` (`## State JSON`); do not redefine them here. See `../../docs/liveness-doctrine.md` for when/how to promote and monitor a dispatched unit.

**Between tasks (floor check).** Before dispatching the next unit, run `../../scripts/liveness-floor.sh <state.json>` over the open `inflight[]`. The script is detect-only — it prints `STALE` for any unit past `G × deadline_s`; the orchestrator decides the response. For each `STALE` line, enter the response path in `../../docs/liveness-doctrine.md` (§7). Do not duplicate the floor mechanics here.

Each task also gets a durable **per-task receipt** at `docs/superpowers/runs/<run>/task-NNN-result.md` (NNN = zero-padded task number). The receipt captures the implementer status, what was built, test results, files changed, review verdicts, and any deferred findings. This file is the artifact — it survives compaction.

**After a compaction, resume from these files, not from chat:** read `state.json` for `current_task`/`completed_tasks`/`blocked_tasks`/`last_green_commit`, and read the `task-NNN-result.md` receipts for what each completed task produced. Reconstruct the plan position from disk before dispatching the next subagent.

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

1. Run `/code-review` at **low** effort for mechanical issues. This per-task built-in review is **ephemeral**: it gates the current task only and must **not** be written as the cacheable `code_review_verdict` in `state.json`. That field is reserved for the **branch-scope**, `>=medium`-effort review produced at verification/finishing (`scope:"branch"`). If you do record the per-task result, stamp it `scope:"task"`, `effort:"low"` so `superpowers:finishing-a-development-branch` correctly ignores it as a finishing-quality verdict. (Field shapes are single-sourced in `superpowers:phase-handoff`.)
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

**BLOCKED / review issues — bounded retries:** Each task gets **max 2 fix-attempts**. Before retrying, change something: add context, use a more capable model, or split the task. After 2 failed attempts, **stop retrying and escalate** with one outcome:

- `approved-amended-plan` — the plan was adjusted and the task can proceed under the amendment.
- `human-decision-required` — the orchestrator cannot resolve it autonomously; hand to the human.
- `task-removed` — the task is dropped from this run.

**implementation-wrong vs plan-wrong.** Diagnose before retrying:

- **implementation-wrong** (task is correct, the build diverged) → re-dispatch a fresh subagent with a narrowed **fix scope** (counts against the 2-attempt limit).
- **plan-wrong** (the task itself is wrong, ambiguous, or unbuildable) → **stop the run and escalate immediately**. Halt the per-task loop, report the escalation outcome (`human-decision-required`) in `state.json` and the task receipt, and do **not** process any further tasks until the human responds. Do not auto-retry — retrying would mask a wrong plan, and continuing to later tasks would build on a broken plan.

**Time/liveness trigger (subagent hung or died).** A subagent that **fails to return in time** — over budget with no progress, per the wall-clock floor / detection signals in the doctrine — is a different failure class from a content-triggered BLOCKED. Response: restart-fresh with carryover (prior partial + remaining scope + a note that the prior attempt hung/died) and increment `restarts`, up to `max_restarts` — the **liveness pool**, kept SEPARATE from max-2-fix-attempts. The pathological-repeat guard escalates early if the unit dies at the same point repeatedly, but only when a positional signal exists. **Carryover safety (compact + sanitize):** before the salvaged partial seeds the fresh agent it is compacted to a receipt AND **sanitized** — strip secrets/credentials/tokens and raw output dumps; if the partial is corrupt/unparseable, note that and carry only the validated remaining-scope rather than re-feeding corrupt content. The two pools are **independent** (separate counters) but compose under the combined per-task ceiling `max_dispatches_total` = `max_restarts + max_fix_attempts`: escalate when either pool exhausts OR the sum of fresh dispatches crosses the ceiling. Last-resort outcome is the existing `human-decision-required`; `plan-wrong` still stops the run immediately. Defer mechanics/constants to `../../docs/liveness-doctrine.md`.

**Categorize findings Blocking vs Deferred.** Blocking findings must be resolved (or the task escalated) before marking complete. Deferred findings are recorded in the task receipt and carried forward, not silently dropped.

## Red Flags

Never:

- Start implementation on `main` or `master`; run `superpowers:using-git-branches` first so it can create a task branch
- Create a worktree unless explicitly requested
- Skip spec review or quality review
- Move to the next task while review issues remain open
- Retry a blocked task more than twice instead of escalating (`approved-amended-plan` / `human-decision-required` / `task-removed`), or auto-retry a plan-wrong task instead of stopping the run and escalating it
- Process further tasks after a plan-wrong escalation instead of halting the run until the human responds
- Write a per-task built-in `/code-review` result as the cacheable branch-scope `code_review_verdict` in `state.json`
- Carry a subagent's raw working context or transcript forward instead of its compact result
- Reuse a prior subagent's result as memory in place of dispatching a fresh subagent with the exact follow-up scope
- Let a hung/non-returning subagent block the loop forever instead of applying the time/liveness trigger (restart-fresh up to `max_restarts`, then escalate `human-decision-required`) — and never conflate the liveness pool with the content max-2-fix-attempts pool

## Integration

Required workflow skills:

- `superpowers:using-git-branches`
- `superpowers:writing-plans`
- `superpowers:requesting-code-review`
- `superpowers:finishing-a-development-branch`

Subagents should follow `superpowers:test-driven-development` when a task requires implementation work.

Built-in review (`/code-review`, `/simplify`, `/security-review`) follows the doctrine in `../../docs/review-integration-doctrine.md`; risk tiers come from `superpowers:verification-before-completion`.
