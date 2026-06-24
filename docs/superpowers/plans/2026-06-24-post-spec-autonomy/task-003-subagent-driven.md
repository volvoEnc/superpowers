# Task 3: subagent-driven-development — durable state, per-task receipts, bounded retries, repo-context prompts, load-and-discard

**Risk:** high
**Depends on:** 001 (phase-handoff defines the `state.json` schema this task references by name)
**Review policy:** per-task-plus-risk
**Files:** Modify:
- `plugins/superpowers-claude/skills/subagent-driven-development/SKILL.md`
- `plugins/superpowers-claude/skills/subagent-driven-development/implementer-prompt.md`
- `plugins/superpowers-claude/skills/subagent-driven-development/spec-reviewer-prompt.md`
- `plugins/superpowers-claude/skills/subagent-driven-development/code-quality-reviewer-prompt.md`

This task encodes spec items **C** (durable execution state + per-task result files), **G** (bounded retries + escalation outcomes + Blocking/Deferred + impl-wrong vs plan-wrong), **H** (repo root/branch/SHA + read-only note in dispatch prompts), **J** (per-task load-and-discard).

All commands run from repo root `/Users/danilka/llm-plugins/superpowers`. The `state.json` schema is single-sourced in `superpowers:phase-handoff` (`## State JSON` section) — this task **references it by name only**, never redefines field shapes. Built-in tools (`/code-review`, `/security-review`, `/simplify`) stay WITHOUT the `superpowers:` prefix. Risk tiers stay single-sourced in `superpowers:verification-before-completion`.

---

## Steps

- [ ] **Step 1 — Define acceptance checks (assert all the new content lands).**

  Structural acceptance (run from repo root, expected output noted):

  ```bash
  # C: new section heading exists
  grep -n "^## Maintaining Execution State" plugins/superpowers-claude/skills/subagent-driven-development/SKILL.md   # -> 1 match
  # C: per-task receipt artifact path referenced in the loop
  grep -n "docs/superpowers/runs/<run>/task-NNN-result.md" plugins/superpowers-claude/skills/subagent-driven-development/SKILL.md   # -> >=1 match
  # C: state fields written after each task (reference, not redefinition)
  grep -nE "current_task|completed_tasks|blocked_tasks|last_green_commit" plugins/superpowers-claude/skills/subagent-driven-development/SKILL.md   # -> >=1 line
  # C: schema is referenced, not redefined
  grep -n "superpowers:phase-handoff" plugins/superpowers-claude/skills/subagent-driven-development/SKILL.md   # -> >=1 match
  # G: bounded retries + escalation outcomes
  grep -nE "max 2 fix-attempts|approved-amended-plan|human-decision-required|task-removed" plugins/superpowers-claude/skills/subagent-driven-development/SKILL.md   # -> all four present
  # G: impl-wrong vs plan-wrong boundary
  grep -nE "implementation-wrong|plan-wrong" plugins/superpowers-claude/skills/subagent-driven-development/SKILL.md   # -> both present
  # G: Blocking vs Deferred categorization
  grep -nE "Blocking|Deferred" plugins/superpowers-claude/skills/subagent-driven-development/SKILL.md   # -> both present
  # J: per-this-task-only prefix + discard-after-capture
  grep -n "per this task only:" plugins/superpowers-claude/skills/subagent-driven-development/SKILL.md   # -> 1 match
  grep -niE "discard after capture|discard.*after.*receipt" plugins/superpowers-claude/skills/subagent-driven-development/SKILL.md   # -> >=1 match
  # H: repo-context block in implementer + both reviewer prompts
  grep -nl "Repo root:" plugins/superpowers-claude/skills/subagent-driven-development/implementer-prompt.md plugins/superpowers-claude/skills/subagent-driven-development/spec-reviewer-prompt.md plugins/superpowers-claude/skills/subagent-driven-development/code-quality-reviewer-prompt.md   # -> 3 files
  grep -niE "read-only|do not commit|don't commit" plugins/superpowers-claude/skills/subagent-driven-development/spec-reviewer-prompt.md   # -> >=1 match
  # H+J: implementer prompt told to work only on this task, not look ahead
  grep -ni "do not look ahead" plugins/superpowers-claude/skills/subagent-driven-development/implementer-prompt.md   # -> >=1 match
  ```

  **Behavioral pressure-tests** (record before/after; behavior-shaping changes per CLAUDE.md "Skill Changes Require Evaluation"):

  - **(G) BLOCKED does not loop.** Scenario: dispatch a task; implementer returns `BLOCKED`; fix-redispatch fails again.
    - BEFORE: "Handling Status / BLOCKED" only says "Change something before retrying… or escalate if the plan is wrong" — no count, agent can retry indefinitely.
    - AFTER: agent retries at most 2 fix-attempts, then escalates with one of `approved-amended-plan | human-decision-required | task-removed`; it does not dispatch a 3rd fix attempt.
  - **(G) impl-wrong vs plan-wrong routing.** Scenario A: reviewer says implementation diverges from a correct task → agent re-dispatches with narrowed fix scope (within the 2-attempt limit). Scenario B: reviewer says the task itself is wrong/unbuildable → agent escalates (does NOT silently retry, because auto-retry would mask a wrong plan).
  - **(C) Resume-after-compaction reads disk, not chat.** Scenario: orchestrator context is compacted mid-run. AFTER: agent reads `state.json` (`current_task`/`completed_tasks`/`blocked_tasks`/`last_green_commit`) and the per-task `task-NNN-result.md` receipts from disk to recover, instead of relying on prior chat turns.
  - **(J) No look-ahead.** Scenario: a 5-task plan. AFTER: the dispatched implementer prompt instructs working only on the current task and not reading ahead to later tasks; the loop holds only the current task in context and discards it after the receipt is written.

- [ ] **Step 2 — Verify the acceptance checks currently FAIL (content absent).**

  Run the Step 1 structural greps now, before editing. Expected current state (confirmed against the read of the four files):
  - `## Maintaining Execution State` — **absent** (0 matches).
  - `task-NNN-result.md`, `current_task`, `completed_tasks`, `blocked_tasks`, `last_green_commit` — **absent** in this SKILL.
  - `max 2 fix-attempts`, `approved-amended-plan`, `human-decision-required`, `task-removed`, `implementation-wrong`, `plan-wrong`, `Deferred` — **absent**.
  - `per this task only:`, discard-after-capture phrasing — **absent**.
  - `Repo root:` — **absent** in all three prompt files; `do not look ahead` — **absent** in implementer-prompt.md.

  Record the empty/0-match output as the pre-state for the diff.

- [ ] **Step 3 — Apply edits.**

  ### 3a. SKILL.md — add `## Maintaining Execution State` (item C)

  Anchor: insert a NEW `## Maintaining Execution State` section **immediately after the `## Per-Task Loop` section and before `## Built-In Review In The Loop`**. (The Per-Task Loop currently ends with the paragraph "After all tasks, dispatch a final reviewer, capture its result, then use `superpowers:finishing-a-development-branch`.")

  Content (reference the schema, do not redefine it):

  ```markdown
  ## Maintaining Execution State

  Execution state lives on disk so the orchestrator stays light and can resume after a compaction. Do not keep run progress only in chat.

  After **each task** completes (or blocks), update `state.json` in the run directory (`docs/superpowers/runs/<run>/state.json`). Write the fields `current_task`, `completed_tasks`, `blocked_tasks`, and `last_green_commit`. The full schema — including these fields and their shapes — is single-sourced in `superpowers:phase-handoff` (`## State JSON`); reference it there, do not redefine field shapes here.

  Each task also gets a durable **per-task receipt** at `docs/superpowers/runs/<run>/task-NNN-result.md` (NNN = zero-padded task number). The receipt captures the implementer status, what was built, test results, files changed, review verdicts, and any deferred findings. This file is the artifact — it survives compaction.

  **After a compaction, resume from these files, not from chat:** read `state.json` for `current_task`/`completed_tasks`/`blocked_tasks`/`last_green_commit`, and read the `task-NNN-result.md` receipts for what each completed task produced. Reconstruct the plan position from disk before dispatching the next subagent.
  ```

  ### 3b. SKILL.md — Per-Task Loop edits (items C, J)

  Anchor: the `## Per-Task Loop` numbered list. Make three edits:

  - **Step 1 prefix (J).** Replace the current step `1. Read the task file and the context pack.` with:
    `1. **Per this task only:** read this task file and the relevant context-pack slice — hold only the current task in context. Do not read ahead to later tasks. Discard the task text after its receipt is written (see "Maintaining Execution State").`
  - **Step 4 — durable receipt (C).** Replace the current step `4. Capture the result in your notes or task status.` with:
    `4. Write the result to the durable per-task receipt `docs/superpowers/runs/<run>/task-NNN-result.md` (see "Maintaining Execution State"). After compaction, read these receipt files — not chat — to recover prior results.`
  - **Step 13 / completion — state write (C).** Append to the existing step 13 (which ends "…re-tested and re-reviewed.") a trailing sentence:
    `Then update `state.json` (`current_task`, `completed_tasks`, `blocked_tasks`, `last_green_commit`) per "Maintaining Execution State".`

  ### 3c. SKILL.md — Handling Status: bounded retries + escalation + impl-wrong/plan-wrong + Blocking/Deferred (item G)

  Anchor: the `## Handling Status` section. Replace the current **BLOCKED** line:
  `**BLOCKED:** Change something before retrying: add context, use a more capable model, split the task, or escalate if the plan is wrong.`
  with an expanded block:

  ```markdown
  **BLOCKED / review issues — bounded retries:** Each task gets at most **2 fix-attempts**. Before retrying, change something: add context, use a more capable model, or split the task. After 2 failed attempts, **stop retrying and escalate** with one outcome:

  - `approved-amended-plan` — the plan was adjusted and the task can proceed under the amendment.
  - `human-decision-required` — the orchestrator cannot resolve it autonomously; hand to the human.
  - `task-removed` — the task is dropped from this run.

  **implementation-wrong vs plan-wrong.** Diagnose before retrying:

  - **implementation-wrong** (task is correct, the build diverged) → re-dispatch a fresh subagent with a narrowed **fix scope** (counts against the 2-attempt limit).
  - **plan-wrong** (the task itself is wrong, ambiguous, or unbuildable) → **escalate immediately**. Do not auto-retry — retrying would mask a wrong plan.

  **Categorize findings Blocking vs Deferred.** Blocking findings must be resolved (or the task escalated) before marking complete. Deferred findings are recorded in the task receipt and carried forward, not silently dropped.
  ```

  ### 3d. SKILL.md — Red Flags (item G reinforcement)

  Anchor: the `## Red Flags` "Never:" list. Add one bullet after the existing `- Move to the next task while review issues remain open` bullet:
  `- Retry a blocked task more than twice instead of escalating (`approved-amended-plan` / `human-decision-required` / `task-removed`), or auto-retry a plan-wrong task instead of escalating it`

  ### 3e. implementer-prompt.md — repo context + read-only + no-look-ahead (items H, J)

  Anchor: inside the fenced template, the `## Context` section (currently `[Scene-setting: where this fits, dependencies, architectural context]`). Insert a new `## Repo Context` subsection immediately after the `## Context` block and before `## Before You Begin`:

  ```markdown
    ## Repo Context

    - Repo root: [absolute path]
    - Branch: [task branch name]
    - You may read files and run `git diff` in this repo. **Do not work outside this task: do not look ahead to later tasks, do not touch files this task does not name.**
  ```

  Also extend the existing `## Your Job` / "Work only on what this task specifies" intent: change the loop's no-look-ahead into the prompt by appending to the `## Your Job` numbered list a final emphasis line right after item `6. Report back`:
  `**Work only on this task. Do not look ahead to other tasks in the plan.**`

  (Implementer commits its own work, so it keeps write access — the read-only note is for reviewers, see 3f/3g.)

  ### 3f. spec-reviewer-prompt.md — repo context + read-only (item H)

  Anchor: inside the fenced template, after the `## What Implementer Claims They Built` block and before `## CRITICAL: Do Not Trust the Report`. Insert:

  ```markdown
    ## Repo Context

    - Repo root: [absolute path]
    - Branch: [task branch name]
    - Base SHA: [commit before task]  Head SHA: [current commit]
    - You may read files and run `git diff` to verify. **Read-only: do not commit and do not edit files.**
  ```

  ### 3g. code-quality-reviewer-prompt.md — repo context + read-only (item H)

  Anchor: inside the fenced template, after the existing `HEAD_SHA: [current commit]` line. The template already passes `BASE_SHA`/`HEAD_SHA`; add repo root + branch + read-only note. Insert after the `HEAD_SHA:` line:

  ```markdown
    REPO_ROOT: [absolute path]
    BRANCH: [task branch name]
    NOTE: Read-only — you may read files and run `git diff`, but do not commit and do not edit files.
  ```

- [ ] **Step 4 — Verify acceptance PASSES + validate + cross-links intact.**

  ```bash
  # Re-run ALL Step 1 structural greps -> every one now matches as specified.
  # Plugin validation green:
  claude plugin validate /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude   # -> validation passes (no errors)
  # superpowers: cross-links still resolve in this skill (phase-handoff, verification-before-completion, finishing, etc. intact):
  grep -nE "superpowers:(phase-handoff|verification-before-completion|finishing-a-development-branch|using-git-branches|writing-plans|requesting-code-review|test-driven-development)" plugins/superpowers-claude/skills/subagent-driven-development/SKILL.md
  # Built-ins must NOT carry the superpowers: prefix (expected: NO output):
  grep -rnE "superpowers:(code-review|security-review|simplify|verify|run)" plugins/superpowers-claude/skills/subagent-driven-development/
  # YAML frontmatter intact (name + description unchanged, fences balanced):
  head -4 plugins/superpowers-claude/skills/subagent-driven-development/SKILL.md   # -> ---\nname: subagent-driven-development\ndescription: ...\n---
  ```

  Confirm the three prompt-file edits stay **inside** their fenced ` ``` ` template blocks (the repo-context content is part of the prompt the subagent receives, not skill prose). Re-confirm the four behavioral pressure-tests in Step 1 now resolve to the AFTER behavior.

- [ ] **Step 5 — Commit.**

  ```bash
  git add plugins/superpowers-claude/skills/subagent-driven-development/SKILL.md \
          plugins/superpowers-claude/skills/subagent-driven-development/implementer-prompt.md \
          plugins/superpowers-claude/skills/subagent-driven-development/spec-reviewer-prompt.md \
          plugins/superpowers-claude/skills/subagent-driven-development/code-quality-reviewer-prompt.md
  git commit -m "feat(subagent-driven): durable state, per-task receipts, ограниченные циклы и repo-контекст в промптах

C: секция Maintaining Execution State — state.json (схема из phase-handoff) после каждой задачи + per-task receipt docs/superpowers/runs/<run>/task-NNN-result.md, resume после компакта с диска
G: макс 2 fix-попытки -> эскалация (approved-amended-plan | human-decision-required | task-removed), impl-wrong vs plan-wrong, Blocking vs Deferred
H: repo root/branch/SHA + read-only пометка в implementer/spec/quality промптах
J: префикс 'per this task only:' + discard-after-capture + 'do not look ahead'"
  ```
