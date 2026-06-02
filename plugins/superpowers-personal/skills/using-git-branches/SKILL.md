---
name: using-git-branches
description: Use when starting feature work, before executing implementation plans, or whenever the current Git branch may be main or master
---

# Using Git Branches

## Overview

Prepare the current checkout for development without creating git worktrees. Work in the current directory. If the current branch is `main` or `master`, ask the human partner whether to create a feature branch or continue on the current branch.

**Core principle:** Stay in place. Do not create worktrees. Protect `main` and `master` by asking before editing them.

**Announce at start:** "I'm using the using-git-branches skill to prepare the current branch for development."

## Step 1: Detect Current Branch

Run read-only git checks:

```bash
BRANCH=$(git branch --show-current)
STATUS=$(git status --short)
```

Handle each state:

| State | Action |
|-------|--------|
| `main` or `master` | Ask whether to create a new branch or work directly on the current branch |
| Any other branch | Continue on the current branch |
| Detached HEAD | Stop and ask how to proceed |
| Dirty tree | Report dirty files and ask whether to continue, stash, or commit first |

## Step 2: Main/Master Choice

If on `main` or `master`, ask exactly this:

```text
You're on <branch>. How would you like to proceed?

1. Create a new feature branch
2. Work directly on <branch>

Which option?
```

Do not assume the safer option silently. Ask once, then follow the answer.

If the human partner chooses a feature branch:

```bash
git checkout -b <descriptive-branch-name>
```

Use a short branch name based on the approved spec or task, such as `feature/auth-refresh` or `fix/session-timeout`.

If the human partner chooses to work directly on `main` or `master`, proceed in place. Record that explicit consent in any plan or handoff.

## Step 3: Project Setup

Auto-detect and run appropriate setup only when needed:

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

## Step 4: Verify Clean Baseline

Run the project-appropriate baseline test command:

```bash
npm test / cargo test / pytest / go test ./...
```

**If tests fail:** Report failures and ask whether to proceed or investigate.

**If tests pass:** Report ready.

### Report

```text
Working in current checkout on branch <branch>.
Tests passing (<N> tests, 0 failures).
Ready to implement <feature-name>.
```

## Quick Reference

| Situation | Action |
|-----------|--------|
| On `main` or `master` | Ask branch vs work directly |
| On feature branch | Continue in place |
| Detached HEAD | Ask how to proceed |
| Dirty tree | Report dirty files before changes |
| Tests fail during baseline | Report failures and ask |
| User asks for worktree | Follow explicit user request, otherwise do not create one |

## Red Flags

Never:

- Create a git worktree unless the human partner explicitly asks for one
- Start editing on `main` or `master` without explicit consent
- Hide a dirty working tree
- Proceed with failing baseline tests without asking
- Switch branches when there are uncommitted changes without explaining the risk

Always:

- Work in the current checkout by default
- Ask before editing `main` or `master`
- Use a normal feature branch when requested
- Verify baseline tests before implementation when practical
