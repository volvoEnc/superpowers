---
name: executing-plans
description: Use when you have a written implementation plan to execute in a separate session with review checkpoints
---

# Executing Plans

Load the written plan, review it, execute tasks in order, and report when complete.

**Announce at start:** "I'm using the executing-plans skill to implement this plan."

## Step 0: Check Branch

Before editing, use `superpowers:using-git-branches` in `implementation-start` mode. Work in the current checkout. If execution starts from `main` or `master`, the branch skill creates a task branch before implementation starts.

## Step 1: Load and Review Plan

1. Read the plan file.
2. Review critically and identify questions or concerns.
3. If concerns exist, raise them before starting.
4. If no concerns exist, create TodoWrite and proceed. **Then discard the full plan body from context — keep only the overview (title / goal / risk tier) and the ordered task list.** Read each task file from disk at the start of its cycle in Step 2, and discard that task's text once its result receipt is captured. Never hold more than one task body in context at a time ("load-and-discard").

## Maintaining Execution State

Write `state.json` after each task so the run survives a compact and is resumable.

- The schema is defined once in `superpowers:phase-handoff` (section "State JSON"). Do not redefine fields here — reference it. Use the exact field names: `current_task`, `completed_tasks`, `blocked_tasks`, `last_green_commit` (plus the evidence fields `plan_risk_tier`, `test_results`, `code_review_verdict`, `security_review_status` written by `superpowers:verification-before-completion`).
- After each task: update `current_task` → next, append to `completed_tasks`, set `last_green_commit` to the last commit whose verification passed. On a blocked task, append to `blocked_tasks` instead.
- After verifications run, refresh the evidence fields per `superpowers:verification-before-completion` rather than restating verdicts in chat.
- **Writer authority:** the skill that *runs* a given review writes that verdict (SHA-stamped, scope-stamped). `superpowers:verification-before-completion` is not the sole writer — when executing-plans runs the Step 2a branch `/security-review`, executing-plans writes the branch `security_review_status` itself. No single-writer conflict.
- On resume after a compact, rebuild from `state.json` on disk, not from the chat transcript.

## Step 2: Execute Tasks

For each task:

1. Mark as in_progress.
2. Follow each step exactly.
3. Run verifications as specified.
4. Mark as completed.

## Step 2a: Security Risk Check Before Handoff

Before handing off to finishing, assess the security risk of the accumulated branch diff.

1. Re-read the plan's per-task risk assessment. Determine whether any completed task touched a **Tier-1** area. Tier-1 is defined once in `superpowers:verification-before-completion` → section "Security-Review Risk Tiers". Do not redefine the list here — consult that section.
2. **If any task was Tier-1: auto-run `/security-review` on the accumulated branch diff — no human approval gate.** `/security-review` is a Claude Code built-in (no `superpowers:` prefix). Then handle the verdict:
   - No critical findings → record `security_review_status` clean in `state.json` (per the schema, see below) and continue.
   - Critical findings → **dispatch a fresh subagent (Task tool) with a narrowed fix scope** to perform the fix (do NOT fix inline — inline work is coordinator-only; security fixes are subagent-class work), then re-run `/security-review` once. This branch security-gate fix cycle is **exactly one cycle**, independent of the per-task 2-attempt fix pool (that pool is per implementation task — see `superpowers:subagent-driven-development`).
   - If critical findings persist after this one fix-and-re-run cycle → **escalate** (`human-decision-required`); record `security_review_status` as `critical-open`. **Block handoff only on unresolved critical findings** — never on non-critical findings.
3. **If no task was Tier-1:** set `plan_risk_tier` to the actual tier (`"Tier-2"` or `"Tier-3"`) and record `security_review_status` as `{ required: false, verdict: "n/a", scope: "branch", commit: <HEAD sha>, timestamp: <iso> }` in `state.json`, then continue. Do not write a prose string.

**Recording risk/security to `state.json`** (schema is single-sourced in `superpowers:phase-handoff` → "State JSON" — do not redefine it):

- `plan_risk_tier`: the enum value (`"Tier-1"` | `"Tier-2"` | `"Tier-3"`), never a prose sentence.
- `security_review_status`: `{ required, verdict, scope: "branch", commit: <HEAD sha>, timestamp: <iso> }`. For a Tier-1 clean run: `{ required: true, verdict: "clean", scope: "branch", commit: <HEAD sha>, timestamp: <iso> }`; for unresolved critical findings use `verdict: "critical-open"`.

## Step 3: Complete Development

After all tasks complete and verification passes:

- Announce: "I'm using the finishing-a-development-branch skill to complete this work."
- **REQUIRED SUB-SKILL:** Use superpowers:finishing-a-development-branch.
- **Pass the plan risk tier explicitly.** State the `plan_risk_tier` from `state.json` when invoking finishing (e.g. "plan risk: Tier-1, /security-review run and clean" or "plan risk: not Tier-1") so finishing uses the passed tier instead of re-deriving it.
- Follow that skill to verify tests, present options, and execute the selected choice.

## When to Stop and Ask for Help

Stop immediately when:

- A dependency is missing.
- A test fails: first re-run it once (in case of flake). If it fails again, run **one** bounded fix-and-retest cycle via `superpowers:systematic-debugging`. If it still fails after that cycle, escalate (`human-decision-required`) — do not loop further.
- An instruction is unclear.
- The plan has critical gaps.
- You do not understand the next step.

Ask for clarification rather than guessing.

## Remember

- Review plan critically first.
- Follow plan steps exactly.
- Do not skip verifications.
- Reference skills when the plan says to.
- Stop when blocked.
- Do not start implementation on `main` or `master`; run `superpowers:using-git-branches` first so it can create a task branch.

## Integration

Required workflow skills:

- `superpowers:using-git-branches`
- `superpowers:writing-plans`
- `superpowers:finishing-a-development-branch`
