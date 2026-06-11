---
name: using-git-branches
description: Use at the start of brainstorming, planning, or implementation to protect main/master and prepare the current checkout without worktrees
---

# Using Git Branches

## Overview

Prepare the current checkout for development without creating git worktrees. Branch protection runs before any repository artifact is written, any spec is saved, any plan is created, or any implementation work begins.

**Core principle:** branch first, then think. If the current branch is `main` or `master`, create a new branch before continuing. Do not ask to work directly on `main` or `master` for normal feature work.

**Announce at start:** "I'm using the using-git-branches skill to protect the current branch before continuing."

## When to Use

Use this skill before:

- brainstorming a product or code change
- reading large task files for a change request
- writing specs, handoffs, plans, or review receipts
- executing implementation plans
- modifying code, tests, docs, config, or generated artifacts
- any moment where the current branch may be `main` or `master`

## Modes

Choose the lightest mode that fits the phase:

| Mode | Use when | Work performed |
|------|----------|----------------|
| `design-start` | brainstorming, task intake, spec writing, planning | branch safety only |
| `implementation-start` | executing a reviewed implementation plan | branch safety, setup if needed, baseline tests |

If the caller does not specify a mode, infer it from the phase. Brainstorming, design, specs, and plans use `design-start`. Implementation uses `implementation-start`.

## Step 1: Detect Current State

Run read-only checks:

```bash
BRANCH=$(git branch --show-current)
STATUS=$(git status --short)
```

Handle each state:

| State | Action |
|-------|--------|
| `main` or `master` | Create a new branch immediately |
| Any other named branch | Continue on the current branch |
| Detached HEAD | Stop and ask how to proceed |
| Dirty tree | Report dirty files; if on `main` or `master`, branch first and carry changes with you |

## Step 2: Auto-Branch from Main/Master

If `BRANCH` is `main` or `master`, create a feature branch before any other work.

Choose a short branch name from the current task:

| Work type | Branch prefix | Example |
|-----------|---------------|---------|
| feature or behavior change | `feature/` | `feature/auth-refresh` |
| bug fix | `fix/` | `fix/session-timeout` |
| docs/config/process change | `chore/` | `chore/brainstorming-flow` |
| exploration with unclear final shape | `spike/` | `spike/cache-design` |

If the task is still vague, use the best short slug from the human partner's request and refine later only if needed. Do not stay on `main` or `master` just because the branch name is imperfect.

```bash
git checkout -b <prefix>/<short-task-slug>
```

If that branch name already exists, append a small suffix such as `-2` or today's date and create that branch instead. Do not switch to an existing branch unless the human partner explicitly asks for it.

If `STATUS` was non-empty before branching, report that the uncommitted changes were carried onto the new branch. This is expected for `git checkout -b` from the current commit.

## Step 3: Non-Main Branch Handling

If already on a non-`main`/`master` branch:

- Continue on that branch.
- If the tree is dirty, report the dirty files before writing anything new.
- If the dirty files look unrelated to the current task, ask whether to continue, stash, or stop.
- If the human partner already made clear that the dirty files are part of this task, continue.

## Step 4: Detached HEAD Handling

If `BRANCH` is empty, stop and ask how to proceed. Do not create a branch from detached HEAD without an explicit target name or base.

## Step 5: Project Setup for Implementation Mode Only

For `design-start`, stop after branch safety. Do not install dependencies or run baseline tests during brainstorming or planning unless the human partner explicitly asks.

For `implementation-start`, auto-detect and run setup only when needed:

```bash
# Node.js
if [ -f package.json ]; then npm install; fi

# Rust
if [ -f Cargo.toml ]; then cargo build; fi

# Python
if [ -f requirements.txt ]; then pip install -r requirements.txt; fi
if [ -f pyproject.toml ]; then poetry install; fi

# Go
if [ -f go.mod ]; then go mod download; fi
```

If dependencies are already installed and the project does not require setup, skip this step.

## Step 6: Verify Clean Baseline for Implementation Mode Only

For `implementation-start`, run the project-appropriate baseline test command:

```bash
npm test / cargo test / pytest / go test ./...
```

**If tests fail:** Report failures and ask whether to proceed or investigate.

**If tests pass:** Report ready.

## Reports

After `design-start`:

```text
Working in current checkout on branch <branch>.
Branch is protected for design work.
```

After `implementation-start`:

```text
Working in current checkout on branch <branch>.
Tests passing (<N> tests, 0 failures).
Ready to implement <feature-name>.
```

## Quick Reference

| Situation | Action |
|-----------|--------|
| On `main` or `master` | Create a new branch immediately |
| On feature branch | Continue in place |
| Detached HEAD | Ask how to proceed |
| Dirty tree on `main`/`master` | Create branch and carry changes over, then report dirty files |
| Dirty tree on feature branch | Report dirty files before changes |
| Tests fail during implementation baseline | Report failures and ask |
| User asks for worktree | Follow explicit user request with `superpowers:using-git-worktrees` |

## Red Flags

Never:

- Work directly on `main` or `master` for normal feature work
- Ask whether to work directly on `main` or `master` unless the human partner explicitly requested that option
- Create a git worktree unless the human partner explicitly asks for one
- Hide a dirty working tree
- Run dependency setup or tests during brainstorming unless requested
- Proceed with failing implementation baseline tests without asking
- Switch to an existing branch with uncommitted changes unless the human partner explicitly asked

Always:

- Branch before context exploration, spec writing, planning, or implementation when starting from `main` or `master`
- Work in the current checkout by default
- Keep branch creation lightweight during design phases
- Verify baseline tests before implementation when practical
