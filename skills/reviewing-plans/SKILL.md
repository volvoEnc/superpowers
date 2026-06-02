---
name: reviewing-plans
description: Use when an implementation plan exists and needs pre-execution review, coverage checking, or validation after substantial edits
---

# Reviewing Plans

## Overview

Review implementation plans before execution so stale assumptions, missing requirements, bad file references, invalid snippets, and unsafe task ordering are caught while they are still cheap to fix.

A plan review is not implementation. It is a bounded quality gate that compares saved artifacts against the current repository.

**Announce at start:** "I'm using the reviewing-plans skill to validate this implementation plan before execution."

## Source of Truth

Use saved artifacts, not chat history.

Required inputs:

1. Approved spec or requirements document
2. Implementation plan file or plan directory
3. Current repository state
4. Known test/build commands, if available

Ignore rejected brainstorming ideas, old draft plans, and speculative notes unless they were copied into the approved spec or current plan.

## Review Modes

Choose the lightest mode that can catch the relevant failure class.

| Mode | Use when | Review scope |
|------|----------|--------------|
| Light lint | Small plan, docs-only change, mechanical task | Structure, placeholders, missing commands, obvious contradictions |
| Targeted review | Plan changed after review, or one task was rewritten | Only changed sections and their dependencies |
| Full review | New plan, multi-file change, behavior change, public API, migration, security, concurrency, data loss | Entire plan against spec and repository |

Do not skip review because the change seems easy. Downgrade scope only when the risk is genuinely narrow.

## Risk Triggers

Escalate to full review when any of these appear:

- Public API, CLI behavior, wire format, schema, or migration changes
- Authentication, authorization, secrets, permissions, or sandbox behavior
- Data deletion, data mutation, irreversible operations, or persistence changes
- Concurrency, locking, async coordination, caching, retries, or timeouts
- Cross-cutting refactors touching many files
- Plan contains non-trivial code snippets, imports, function names, or test scaffolding
- The plan was produced after a long brainstorming session with rejected alternatives

## Subagent Review

When the platform supports subagents, dispatch fresh read-only reviewers. They should receive only a curated context pack, not the full conversation.

Recommended reviewer roles:

1. **Spec coverage reviewer**: Maps every spec requirement to plan tasks and finds missing or extra scope.
2. **Plan correctness reviewer**: Checks file paths, task ordering, dependency flow, commands, and stale references.
3. **Snippet reviewer**: Checks code snippets, imports, test names, function names, and APIs against the repository.
4. **Risk reviewer**: Checks high-risk areas such as migrations, security, data loss, concurrency, public APIs, and rollback.

If subagents are unavailable, perform the same checks inline and clearly separate findings by role.

### Reviewer Instructions

Give reviewers this instruction shape:

```text
You are reviewing a plan, not implementing code.
Do not modify files.
Do not use chat history.
Inputs:
- approved spec: <path>
- plan: <path or directory>
- context pack: <path, if present>
- relevant repository files: <paths>

Return a receipt only:
- Verdict: approved | issues-found | blocked
- Blocking issues
- Non-blocking issues
- Evidence with file paths and plan task references
- Minimal recommended edits to the plan
```

Reviewer output should be short, factual, and evidence-based. No essays. No applause confetti.

## Review Checklist

### 1. Spec Coverage

For each requirement in the approved spec:

- Identify the plan task that implements it
- Identify the verification step that proves it works
- Mark any requirement with no task as blocking
- Mark any planned behavior not requested by the spec as a scope issue

### 2. File and Symbol Accuracy

Check that the plan references real repository structure:

- Existing files exist at the specified paths
- New files are created before later tasks modify or import them
- Imports match current project conventions
- Functions, methods, classes, types, properties, commands, and test names are consistent across tasks
- Line references are not treated as authoritative when files may have changed

### 3. Task Ordering

Check that tasks form a safe dependency graph:

- Tests are introduced before implementation when TDD applies
- Shared helpers are created before consumers use them
- Migration or compatibility layers are introduced before old paths are removed
- Rollback or recovery behavior is planned for risky changes
- Commits are small enough to review and recover

### 4. Testability

Every behavior change needs verification:

- Exact test command or build command
- Expected failing result for RED steps
- Expected passing result for GREEN steps
- Existing test suite command for regression coverage
- Clear acceptance criteria for manual verification, when automation is not possible

### 5. Placeholder and Hand-Wave Scan

These are plan defects:

- `TBD`, `TODO`, `later`, `follow up`, `etc.`, `and so on`
- "Add appropriate error handling" without exact cases
- "Write tests" without specific tests or assertions
- "Similar to previous task" instead of the needed content
- "Update docs" without exact doc paths and expected edits

### 6. Risk Handling

For medium/high-risk plans, verify the plan includes:

- Compatibility or migration strategy
- Failure modes and expected errors
- Backward compatibility checks, if relevant
- Security or privacy checks, if relevant
- Observability, logging, or diagnostics, if behavior can fail in production

## Finding Severity

| Severity | Meaning | Required action |
|----------|---------|-----------------|
| Blocking | Plan cannot be executed safely or will likely fail | Fix before execution |
| Important | Plan may work but has material risk or unclear verification | Fix or explicitly accept risk |
| Minor | Clarity or maintainability improvement | Fix when cheap |

A plan with any blocking issue is not approved.

## Review Receipt Format

Save review results beside the plan when possible:

```markdown
# Plan Review Receipt

**Plan:** docs/superpowers/plans/YYYY-MM-DD-feature/overview.md
**Spec:** docs/superpowers/specs/YYYY-MM-DD-feature.md
**Review mode:** full
**Verdict:** issues-found

## Blocking Issues

1. **Missing spec coverage:** Requirement "..." has no task.
   - Evidence: spec section "..."
   - Recommended edit: Add a task that ...

## Important Issues

1. **Stale symbol:** Task 3 imports `...`, but the repository exports `...`.
   - Evidence: `src/path/file.ts`
   - Recommended edit: Change Task 3 to ...

## Minor Issues

- ...

## Approved Sections

- Task 1
- Task 2

## Re-review Admission

Re-review only these sections after edits:
- Task 3
- Task 5
```

## Re-review Rules

Run another review only when there is a concrete reason:

- The plan diff changed since the last review
- A blocking or important issue was fixed and needs verification
- The verifier state changed, such as tests or referenced files changing
- A new risk trigger appears
- A human reviewer requested another pass

When only one section changed, re-review that section plus its dependencies. Do not re-run the whole review carousel for a typo fix.

## Fixing the Plan

After findings are merged:

1. Patch the plan directly.
2. Preserve useful reviewer evidence in `review-findings.md` or a plan receipt.
3. Re-run only the necessary review scope.
4. Do not execute until blocking issues are resolved or explicitly accepted by the human partner.

## Red Flags

Never:

- Let the same agent's self-review be the only plan review for non-trivial work
- Give reviewers the full brainstorming transcript when an approved spec exists
- Ask a reviewer to implement fixes while reviewing
- Ignore a stale file path because the plan "probably meant" another file
- Approve a plan with tests that cannot be run or verified
- Treat low cost as a reason to skip safety checks for high-risk changes
