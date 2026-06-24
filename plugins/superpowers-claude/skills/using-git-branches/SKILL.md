---
name: using-git-branches
description: Use at the start of brainstorming, planning, or implementation to prepare a protected branch without worktrees
---

# Using Git Branches

Prepare the current checkout without creating git worktrees. Run this before brainstorming, task intake, spec writing, plan writing, or implementation.

## Core Rule

If the current branch is a long-lived base (`main`, `master`, or `dev`), create a new task branch before continuing. The normal workflow starts design and implementation work on a branch, not on a release/integration branch.

Use `superpowers:using-git-worktrees` only when the human partner explicitly asks for a worktree.

## Modes

| Mode | Use when | Work performed |
|------|----------|----------------|
| `design-start` | brainstorming, task intake, specs, planning | branch safety only |
| `implementation-start` | executing a reviewed plan | branch safety, setup if needed, baseline tests |

If no mode is specified, brainstorming/design/planning means `design-start`; implementation means `implementation-start`.

## Step 1: Detect Current State

```bash
BRANCH=$(git branch --show-current)
STATUS=$(git status --short)
```

| State | Action |
|-------|--------|
| `main`, `master`, or `dev` | Create a new task branch |
| Other named branch | Continue there |
| Detached HEAD | Stop and ask how to proceed |
| Dirty tree | Report dirty files; if also on a long-lived base (`main`/`master`/`dev`), branch first and carry the files over |

## Step 2: Create a Task Branch

Pick a short branch name from the request:

- `feature/<slug>` for features or behavior changes
- `fix/<slug>` for bug fixes
- `chore/<slug>` for docs, config, or process changes
- `spike/<slug>` for exploration

```bash
git checkout -b <prefix>/<short-task-slug>
```

If that name exists, append `-2` or today's date. If the tree was dirty, report that the uncommitted files moved onto the new branch.

## Step 3: Existing Task Branch

If already on a non-main branch, continue there. If the tree is dirty, report dirty files before writing anything new. If they look unrelated, ask whether to continue, stash, or stop.

## Step 4: Implementation Setup Only

For `design-start`, stop after branch safety. Do not install dependencies or run tests unless explicitly requested.

For `implementation-start`, run project setup only when needed, then run the project-appropriate baseline test command:

```bash
npm test / cargo test / pytest / go test ./...
```

If tests fail, report failures and ask whether to proceed or investigate.

## Report

```text
Working in current checkout on branch <branch>.
Branch is protected for <design|implementation> work.
```

## Guardrails

- Keep normal feature work off long-lived bases (`main`, `master`, `dev`).
- Keep worktree creation opt-in only.
- Report dirty files before adding new changes.
- Keep design-start lightweight: no setup or test run unless requested.
