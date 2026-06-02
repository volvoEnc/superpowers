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

## Step 2: Detect Branch State

```bash
BRANCH=$(git branch --show-current)
STATUS=$(git status --short)
git log --oneline --decorate -5
```

If `BRANCH` is empty, ask how to proceed.

If `STATUS` is non-empty, report dirty files before destructive options.

## Step 3: Determine Base Branch

```bash
git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null
```

If unclear, ask which base branch to use.

## Step 4: Present Options

If on a feature branch:

```text
Implementation complete on branch <branch>. What would you like to do?

1. Merge back to <base-branch> locally
2. Push and create a Pull Request
3. Keep the branch as-is
4. Discard this branch

Which option?
```

If already on `main` or `master`:

```text
Implementation complete on <branch>. What would you like to do?

1. Keep the changes as-is
2. Push <branch>
3. Discard recent local work

Which option?
```

## Step 5: Execute Choice

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
gh pr create --title "<title>" --body "<summary and test plan>"
```

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
- Merge without verifying tests on the result
- Delete work without typed confirmation
- Force-push without explicit request
- Remove or prune git worktrees

Always:

- Verify tests before offering options
- Detect branch state before presenting the menu
- Ask before destructive actions
- Leave the current checkout in place
