# Task 9: Repo-access context for code-reviewer prompt

**Risk:** medium
**Depends on:** none
**Review policy:** per-task-plus-risk
**Files:** Modify: `plugins/superpowers-claude/skills/requesting-code-review/code-reviewer.md`

Scope: Spec H, this file only. The dispatched code-reviewer subagent needs explicit repository access context so a fresh, context-clean reviewer knows where the repo is, which branch/SHAs to look at, and that it is allowed to read and run `git diff`/`git show` but must NOT modify or commit. The template today (lines 22-31) gives `{BASE_SHA}`/`{HEAD_SHA}` and a `git diff` snippet but never states the repo root, the branch, or the read-only boundary — a subagent could try to "fix" the issues it finds. Keep ALL existing review instructions intact (What to Check, Calibration, Output Format, Critical Rules, Example Output).

This is a behavior-shaping change (dispatch-prompt prose). Develop/verify via `superpowers:writing-skills`.

Run all commands from repo root `/Users/danilka/llm-plugins/superpowers`.

- [ ] Step 1: Acceptance check (define target end-state).
  - Structural: after the edit, the prompt body MUST contain a `## Repository Access` section AND the read-only boundary phrase. Target-passing command:
    `grep -n "## Repository Access" plugins/superpowers-claude/skills/requesting-code-review/code-reviewer.md && grep -n "do not modify or commit" plugins/superpowers-claude/skills/requesting-code-review/code-reviewer.md`
    Expected after edit: two matching lines (one per grep).
  - New placeholders documented: `grep -nE "\{REPO_ROOT\}|\{BRANCH\}" plugins/superpowers-claude/skills/requesting-code-review/code-reviewer.md` — expected after edit: matches in both the prompt body and the `**Placeholders:**` list.
  - Behavioral pressure-test (before/after): dispatch a reviewer subagent that finds a Critical issue.
    - BEFORE: prompt names no repo root, no branch, and no read-only boundary; a fresh reviewer may `cd` blindly, may guess the repo, or may "helpfully" edit/commit a fix instead of only reporting it.
    - AFTER: prompt states `**Repo root:** {REPO_ROOT}`, `**Branch:** {BRANCH}`, base/head SHAs, and an explicit "You may read files and run `git diff`/`git show`; do not modify or commit." The reviewer operates in the right repo and returns findings ONLY (no edits, no commits), matching the existing `## Critical Rules` verdict-only contract.

- [ ] Step 2: Verify it currently FAILS (context absent).
  - `grep -c "## Repository Access" plugins/superpowers-claude/skills/requesting-code-review/code-reviewer.md` → expected `0`.
  - `grep -c "do not modify or commit" plugins/superpowers-claude/skills/requesting-code-review/code-reviewer.md` → expected `0`.
  - `grep -cE "\{REPO_ROOT\}|\{BRANCH\}" plugins/superpowers-claude/skills/requesting-code-review/code-reviewer.md` → expected `0`.

- [ ] Step 3: Apply edit — add a `## Repository Access` block to the prompt body and document the new placeholders. Keep everything else byte-for-byte.

  3a. ANCHOR — the existing `## Git Range to Review` block (lines 22-31), which currently reads:

  ```
      ## Git Range to Review

      **Base:** {BASE_SHA}
      **Head:** {HEAD_SHA}

      ```bash
      git diff --stat {BASE_SHA}..{HEAD_SHA}
      git diff {BASE_SHA}..{HEAD_SHA}
      ```
  ```

  Insert a new `## Repository Access` section immediately BEFORE `## Git Range to Review` (i.e. after `{PLAN_OR_REQUIREMENTS}` block, before the Git Range heading), preserving the 4-space indentation used inside the fenced prompt:

  ```
      ## Repository Access

      **Repo root:** {REPO_ROOT}
      **Branch:** {BRANCH}
      **Base:** {BASE_SHA}
      **Head:** {HEAD_SHA}

      Work inside the repo root above. You may read any files and run
      read-only git commands (`git diff`, `git show`, `git log`) to inspect
      the change. You may NOT modify files, stage, or commit — return your
      review as text only. This is a review, not an implementation task.
  ```

  Note: `**Base:**`/`**Head:**` already appear under `## Git Range to Review`. Keep that block as-is (do not delete the duplicate) so the `git diff` snippet below it stays anchored to its SHAs and no existing instruction is lost.

  3b. ANCHOR — the `**Placeholders:**` list (lines 124-128), which currently reads:

  ```
  **Placeholders:**
  - `{DESCRIPTION}` — brief summary of what was built
  - `{PLAN_OR_REQUIREMENTS}` — what it should do (plan file path, task text, or requirements)
  - `{BASE_SHA}` — starting commit
  - `{HEAD_SHA}` — ending commit
  ```

  Add two entries so every new placeholder is documented:

  ```
  **Placeholders:**
  - `{DESCRIPTION}` — brief summary of what was built
  - `{PLAN_OR_REQUIREMENTS}` — what it should do (plan file path, task text, or requirements)
  - `{REPO_ROOT}` — absolute path to the repository root the reviewer works in
  - `{BRANCH}` — branch under review
  - `{BASE_SHA}` — starting commit
  - `{HEAD_SHA}` — ending commit
  ```

- [ ] Step 4: Verify it PASSES + plugin valid + links intact.
  - Re-run Step 1 structural greps → all expected matches present.
  - `claude plugin validate /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude` → expected: validation passes (green, no errors).
  - Cross-links / single-source integrity (no regressions introduced by this edit):
    - `grep -nE "superpowers:(code-review|security-review|simplify|verify|run)" plugins/superpowers-claude/skills/requesting-code-review/code-reviewer.md` → expected: empty (built-ins stay unprefixed; this file should not introduce any).
    - No state.json schema introduced here: `grep -nc "state.json" plugins/superpowers-claude/skills/requesting-code-review/code-reviewer.md` → expected `0` (schema is single-sourced in phase-handoff; this task does not reference it).
  - Confirm existing review instructions untouched: `grep -nc "## Critical Rules" plugins/superpowers-claude/skills/requesting-code-review/code-reviewer.md` → expected `1`; `grep -nc "## Output Format" ...` → expected `1`; `grep -nc "## What to Check" ...` → expected `1`.

- [ ] Step 5: Commit.
  - `git add plugins/superpowers-claude/skills/requesting-code-review/code-reviewer.md`
  - `git commit -m "feat(code-reviewer): добавить repo root/branch/SHA и read-only-границу в шаблон диспатча"`
