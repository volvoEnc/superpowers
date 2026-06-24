---
name: finishing-a-development-branch
description: Use when implementation is complete, tests pass, and you need to decide how to integrate the work
---

# Finishing a Development Branch

## Overview

Finish work in the current checkout. Verify tests, inspect branch state, present clear options, and execute the chosen path. This personal fork does not clean up git worktrees.

**Announce at start:** "I'm using the finishing-a-development-branch skill to complete this work."

## Step 1: Verify Tests

Run the project test suite before offering completion options:

```bash
npm test / cargo test / pytest / go test ./...
```

If tests fail, report failures and stop.

### Inputs (optional)

- **plan risk: `[Tier-1 | not]`** — if the caller (e.g. `executing-plans` Step 3) passes the plan's risk tier, use it as-is. Do **not** re-derive the tier. If not passed, fall back to detecting Tier-1 from the branch diff per `verification-before-completion` (`## Security-Review Risk Tiers`).

Read durable evidence before running any review. If `docs/superpowers/runs/<run>/state.json` exists, load it — its schema (incl. `code_review_verdict`, `security_review_status`, `plan_risk_tier`) is defined once in `superpowers:phase-handoff`; do not redefine it here. The cached verdicts drive Step 2's skip/re-run decision.

## Step 2: Code Review Gate

Tests passing is necessary, not sufficient. Before presenting completion options, run automated review on the branch diff.

**Cache check (per SHA).** First compute the current HEAD SHA (`git rev-parse HEAD`). For each cached verdict in `state.json` (`code_review_verdict`, `security_review_status`):

- `code_review_verdict`: `commit` == HEAD **and** `verdict == "clean"` **and** `effort` is `medium` or higher **and** `scope == "branch"` → **skip** `/code-review`, log `cached: clean`. A low-effort or task-scoped verdict — e.g. the per-task `/code-review` that `subagent-driven-development` records at **low** effort on a single task diff — does **not** satisfy this gate's **medium, full-branch** review. Re-run.
- `security_review_status`: `commit` == HEAD **and** `verdict == "clean"` **and** `scope == "branch"` → **skip** `/security-review`, log `cached: clean`. A **task-scoped** security verdict — e.g. `/security-review` that `subagent-driven-development` ran on a single Tier-1 task diff — does **not** satisfy the mandatory **accumulated-branch** security review (it misses cross-task interactions); re-run. A cached `n/a` may be reused **only when the current risk decision (Step 1 `plan risk`) is not Tier-1**; under Tier-1 a stale `n/a` at the same SHA does **not** satisfy the gate — run `/security-review`.
- SHA differs **or** the verdict is not clean **or** no record exists → **re-run** that review below.

Any new commit invalidates the cache (verdicts are bound to a SHA). Skipping a clean cached review avoids redoing fresh-subagent work the orchestrator already paid for.

Run `/code-review` at **medium** effort against the branch diff:

- **Critical issues found** → STOP. Do not present options yet. Fix the issues (or, if a finding is wrong, apply manual judgment per the precedent rule), re-run tests, then re-run `/code-review` until critical findings are resolved.
- **Minor issues only** → note them; surface in the Step 5 menu preamble so your human partner decides whether to address before merge.
- **Clean** → proceed.

If the branch is **Tier-1** (use the passed `plan risk` from Step 1 if provided, else detect from the diff), additionally run `/security-review` before presenting options — unless its cached `security_review_status` is clean for the current HEAD (`cached: clean`). Tier-1 is defined once in `verification-before-completion` (see its `## Security-Review Risk Tiers` section) — do not redefine it here. If not Tier-1, skip `/security-review` (adaptive by risk).

This gate is automated hygiene (bugs, dead code, style) plus risk-tiered security; it does not replace manual reviewer subagents for architecture/intent/domain judgment. See `../../docs/review-integration-doctrine.md` for the full division of labor and the effort ladder.

## Step 3: Detect Branch State

```bash
BRANCH=$(git branch --show-current)
STATUS=$(git status --short)
git log --oneline --decorate -5
```

If `BRANCH` is empty, ask how to proceed.

If `STATUS` is non-empty, report dirty files before destructive options.

## Step 4: Determine Base Branch

```bash
# Plausible long-lived PR bases: exist locally, are NOT the current branch, and are ancestors of HEAD.
CUR=$(git rev-parse --abbrev-ref HEAD)
for b in main master dev; do
  git show-ref --verify --quiet "refs/heads/$b" && [ "$b" != "$CUR" ] \
    && git merge-base --is-ancestor "$b" HEAD 2>/dev/null && echo "$b"
done
```

The PR base is a **long-lived integration branch**, not the feature branch's push-tracking upstream. Do **not** use `@{upstream}` to pick it: after `git push -u origin <feature>` the upstream is `origin/<feature>` (the head branch itself), so passing it to `gh pr create --base` would target the branch against itself or fail. Resolve from the candidates above: **exactly one** → that is the base; **two or more** (e.g. both `main` and `master`, or a release branch) → **ambiguous**, do not guess (`git merge-base HEAD main` succeeding does not prove `main` is intended when other candidates share history); **none** → ask. An ambiguous or empty result fires the Step 5 ambiguity trigger: ask which base branch to use; do not auto-PR against a guessed target.

## Step 5: Present Options

**Default: auto-push branch + open PR (no menu).** When ALL of these hold — on a feature branch that is **not** a long-lived base (not `main`/`master`/`dev` and not equal to the resolved base from Step 4), clean working tree, an unambiguous base branch (from Step 4), and no `--no-auto` flag — do NOT ask. Auto-execute the "push and create PR" path in Step 6: push the branch and open a PR with `gh` (never auto-merge). Log a one-line verdict first, e.g. `Tests pass. Code review: cached clean. Security: not required (not Tier-1). Opening PR.`

**Show the menu ONLY on an ambiguity trigger:**

- On a long-lived base branch (`main`/`master`/`dev`), **or** when the current branch equals the resolved base → **error** and stop unless `--allow-main` was passed. Never push/PR from a protected/base branch, and never open a PR of a branch against itself.
- Dirty working tree (Step 3 `STATUS` non-empty).
- Ambiguous base branch (Step 4 could not resolve a single base).
- Explicit `--no-auto` flag.

When a trigger fires, open the menu with the one-line verdict, e.g. `Tests pass. Code review: 0 critical, 1 minor. Security review: not required (not Tier-1). How to finish?`:

```text
Implementation complete on branch <branch>. What would you like to do?

1. Push and create a Pull Request (default)
2. Merge back to <base-branch> locally
3. Keep the branch as-is
4. Discard this branch

Which option?
```

**Override flags** (any one bypasses both the default and the menu, executing the named Step 6 path directly): `--merge` (merge locally), `--push` (push branch without PR), `--keep` (keep as-is), `--discard` (discard, still requires typed confirmation). `--allow-main` permits acting from `main`/`master`; `--no-auto` forces the menu.

## Step 6: Execute Choice

### Feature branch: merge locally

```bash
git checkout <base-branch>
git pull
git merge <feature-branch>
<test command>
git branch -d <feature-branch>
```

Only delete the feature branch after merge and tests succeed.

### Feature branch: push and create PR

```bash
git push -u origin <feature-branch>
gh pr create --base <base-branch> --title "<title>" --body "<summary and test plan>"
```

`<base-branch>` is the base resolved in Step 4 — always pass it explicitly. Omitting `--base` makes `gh pr create` fall back to `branch.<current>.gh-merge-base` or the repo default branch, which can target the wrong branch when the real base is `master`/`dev`/a release branch.

### Keep branch

Report that the branch remains in the current checkout.

### Discard branch

Require typed confirmation before deleting anything:

```text
Type 'discard' to confirm.
```

Then, if confirmed:

```bash
git checkout <base-branch>
git branch -D <feature-branch>
```

## Red Flags

Never:

- Proceed with failing tests
- Present completion options with unresolved critical `/code-review` findings
- Skip `/security-review` when the branch touched Tier-1 areas
- Merge without verifying tests on the result
- Delete work without typed confirmation
- Force-push without explicit request
- Remove or prune git worktrees

Always:

- Verify tests before offering options
- Run `/code-review` (medium) on the branch diff before presenting options
- Detect branch state before presenting the menu
- Ask before destructive actions
- Leave the current checkout in place
