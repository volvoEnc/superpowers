---
name: subagent-driven-development
description: Use when executing implementation plans with independent tasks in the current session
---

# Subagent-Driven Development

Execute a reviewed implementation plan with fresh subagents. The controller keeps the project state, dispatches one bounded unit of work at a time, records each result, and only then moves forward.

Under this skill, **every** implementation edit to a source file is authored by a fresh dispatched subagent — never hand-typed inline by the orchestrator. This is not a default you weigh against task size, token cost, or "I already have the context"; it is the execution mode itself. Task size is not the axis: a five-line pure function is dispatched exactly like a five-hundred-line one. The orchestrator's hands stay off source files; it coordinates, captures receipts, and dispatches. (The orchestrator still runs the sanctioned built-in mechanical-review tools — `/simplify`, `/code-review --fix` — on a task diff per "Built-In Review In The Loop"; those are review steps, not hand-authored implementation.) The only sanctioned way to run implementation inline-with-checkpoints is the explicit `superpowers:executing-plans` opt-in — see the Hard Gates.

## Start In The Current Checkout

Before implementation, use `superpowers:using-git-branches` in `implementation-start` mode.

- Work in the current checkout by default.
- If the current branch is `main` or `master`, the branch skill creates a task branch before implementation starts.
- Do not create a git worktree unless the human partner explicitly asks for one.
## Hard Gates

These fire **during execution**, on every task — not just when the skill is first invoked. Re-check them at the moment of each implementation edit, not once at the start. They govern **hand-authored** implementation edits; the orchestrator running the sanctioned built-in mechanical-review tools (`/simplify`, `/code-review --fix`) on a task diff per "Built-In Review In The Loop" is a review step, not a violation. They also do not touch the orchestrator's coordination writes — plan text, `state.json`, per-task receipts.

1. Do not hand-author an implementation Write or Edit to a source file in the orchestrator's own context. The orchestrator never types source edits itself; it dispatches a fresh subagent that authors them. This holds for the very first task and for every task after it.
2. Do not classify a task as "too small/simple/cheap to dispatch" and do it inline instead. Size, simplicity, and token cost are not exceptions to Gate 1 — there is no "trivial enough" threshold that unlocks hand-authored inline implementation.
3. Do not let an already-loaded context (sources, task files, prior receipts you happen to be holding) justify an inline edit. "I already have the context" is the trap this skill exists to prevent; if you are heavy, that is a reason to re-delegate, not to inline.
4. Do not run implementation inline unless you have **consciously and explicitly switched** to `superpowers:executing-plans` — announcing "Using executing-plans to implement this plan" — the one sanctioned inline-with-checkpoints path (which itself still delegates subagent-class sub-tasks like security fixes per its Step 2a). There is no third, ad-hoc inline path: the choice is subagent-driven (this skill) OR an explicit executing-plans switch. Freelance inline outside those two is forbidden.
5. Do not begin the per-task loop until you have committed to one of the two sanctioned paths. Make the choice **before the first implementation edit** and hold it; drifting from dispatch into inline mid-run — task 1 inline "just this once," then carrying that inertia into tasks 2 and 3 — is the exact failure these gates block. A legitimate mid-run escalation or a genuine Task-tool outage is not drift; handle it per "Handling Status", do not silently switch to freelance inline.

These gates do not override a direct human instruction: per `superpowers:using-superpowers` Instruction Priority, the human partner may explicitly direct inline work, and that instruction wins. The gates forbid the orchestrator *drifting* into inline on its own judgment, not a human choosing it.

## Subagent Lifecycle

Each Task subagent returns its result and terminates on its own. Keep only its compact result/receipt — never carry its raw working context, file dumps, or transcript forward.

```text
dispatch subagent (Task tool) -> wait for result -> capture result
```

This applies to task implementers, spec reviewers, quality reviewers, final reviewers, scouts, and investigation subagents.

The written result is the artifact. If follow-up is needed, dispatch a fresh subagent with the prior result and the exact follow-up scope.
## Token Cost Is Not A Reason To Go Inline

Subagent-driven development **intentionally** spends more tokens than inline work. That is the price of the two things it buys: a **light orchestrator** (project state stays in the controller; raw working context stays in the subagents) and **independent review** (a fresh spec/quality reviewer who never saw the implementer's reasoning). Both evaporate the moment the orchestrator hand-authors a source edit itself.

So a large planning/review spend is **not** a signal to switch to inline implementation. The arrow points the other way: the more tokens already burned, the **heavier** the orchestrator's context, and a heavy orchestrator is the **strongest** reason to delegate — inline only feels cheaper because the cost (a polluted controller, no independent review) is hidden, not absent.

Under a "cost is not a constraint" directive this conflict resolves **toward delegation, every time**. "We already spent ~5M tokens, don't burn more" is exactly the rationalization that drift exploits — naming it is the tell, not the justification. If you are tempted to go inline to save tokens, that temptation is the proof you should dispatch a subagent.

This is not a license to drift inline by another route. The only sanctioned execution paths remain subagent-driven-development (this skill, the default) and `superpowers:executing-plans` (explicit inline-with-checkpoints opt-in). Token anxiety is never a third path.


## Per-Task Loop

For each task in the plan:

1. **per this task only:** read only the minimum needed to *dispatch* this task — its id, the file paths it touches, and the scope to hand the subagent. The full task text and the relevant context-pack slice go **to the implementation subagent**, not into the orchestrator's context (per Hard Gate 3, "already have the context" is not a license to go heavy or inline). Do not read ahead to later tasks. Discard whatever you read for dispatch after the receipt is written (see "Maintaining Execution State").
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
- Hand-author a source edit yourself to "save tokens" because planning/review already burned a lot — heavy orchestrator context is a reason to delegate harder, not to drift inline (see "Token Cost Is Not A Reason To Go Inline")
- Reuse a prior subagent's result as memory in place of dispatching a fresh subagent with the exact follow-up scope
- Let a hung/non-returning subagent block the loop forever instead of applying the time/liveness trigger (restart-fresh up to `max_restarts`, then escalate `human-decision-required`) — and never conflate the liveness pool with the content max-2-fix-attempts pool
- Hand-author an implementation Write/Edit to a source file in the orchestrator's context instead of dispatching a fresh subagent — at the moment you reach for the editor, these thoughts mean STOP: "this task is too small to dispatch," "it's only a few lines," "I already have all the context loaded," "re-delegating would just burn more tokens," "I'll do this one inline and dispatch the rest." Each is a rationalization of the inline drift the Hard Gates forbid; dispatch, or consciously switch to `superpowers:executing-plans` — never freelance inline. (Running the built-in `/simplify` or `/code-review --fix` on a task diff is the sanctioned mechanical-review step, not hand-authored inline.)

## Integration

Required workflow skills:

- `superpowers:using-git-branches`
- `superpowers:writing-plans`
- `superpowers:requesting-code-review`
- `superpowers:finishing-a-development-branch`

Subagents should follow `superpowers:test-driven-development` when a task requires implementation work.

Built-in review (`/code-review`, `/simplify`, `/security-review`) follows the doctrine in `../../docs/review-integration-doctrine.md`; risk tiers come from `superpowers:verification-before-completion`.
