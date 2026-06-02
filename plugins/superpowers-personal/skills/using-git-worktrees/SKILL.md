---
name: using-git-worktrees
description: Use only when the human partner explicitly asks for git worktrees; otherwise use using-git-branches
---

# Using Git Worktrees

## Personal Fork Override

This fork does not use git worktrees for normal development. Do not offer a worktree, do not create `.worktrees/`, and do not call native worktree tools unless the human partner explicitly asks for worktrees in the current task.

For normal feature work, use `superpowers:using-git-branches` instead.

## If This Skill Was Triggered Accidentally

Stop this skill and invoke `superpowers:using-git-branches`.

## If The Human Explicitly Asked For A Worktree

Only then follow the platform's native worktree mechanism or plain git worktree commands. Confirm the target directory before creating anything.
