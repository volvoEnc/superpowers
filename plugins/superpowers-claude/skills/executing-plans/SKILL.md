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
4. If no concerns exist, create TodoWrite and proceed.

## Step 2: Execute Tasks

For each task:

1. Mark as in_progress.
2. Follow each step exactly.
3. Run verifications as specified.
4. Mark as completed.

## Step 3: Complete Development

After all tasks complete and verification passes:

- Announce: "I'm using the finishing-a-development-branch skill to complete this work."
- **REQUIRED SUB-SKILL:** Use superpowers:finishing-a-development-branch.
- Follow that skill to verify tests, present options, and execute the selected choice.

## When to Stop and Ask for Help

Stop immediately when:

- A dependency is missing.
- A test fails repeatedly.
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
