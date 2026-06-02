---
name: reviewing-plans
description: Use when an implementation plan exists and needs pre-execution review, coverage checking, or validation after substantial edits
---

# Reviewing Plans

## Core Rule

The main agent is the review coordinator, not the reviewer. When helper/subagent support is available, dispatch fresh read-only reviewers with sterile inputs. The main agent only routes artifacts, merges receipts, applies concrete plan edits, and closes helpers.

## Inputs

Use saved artifacts only:

1. Approved spec
2. Context pack
3. Plan directory or plan file
4. Relevant repository files
5. Known test/build commands

Do not provide chat history, rejected brainstorming notes, old draft plans, or speculative comments.

## Review Modes

| Mode | Use when | Scope |
|------|----------|-------|
| light | tiny docs/mechanical change | structure, placeholders, obvious contradictions |
| targeted | only one task or section changed | changed sections plus dependencies |
| full | new plan or risky plan | entire plan against spec and repository |

Escalate to full review for public API, migrations, security, data loss, concurrency, cross-cutting refactors, or non-trivial code snippets.

## Helper Roles

Dispatch only the roles needed for the selected mode:

1. **spec-coverage-reviewer** - maps spec requirements to plan tasks and verification steps.
2. **plan-correctness-reviewer** - checks file paths, task order, commands, dependencies, and stale references.
3. **snippet-reviewer** - checks imports, symbols, tests, function names, and code snippets against the repo.
4. **risk-reviewer** - checks migrations, security, data loss, concurrency, public APIs, rollback, and observability.

Each helper must be read-only.

## Helper Prompt Shape

```text
You are reviewing a plan, not implementing code.
Do not modify files.
Do not use chat history.
Inputs:
- approved spec: <path>
- context pack: <path>
- plan: <path or directory>
- relevant repository files: <paths>

Return a receipt only:
- Verdict: approved | issues-found | blocked
- Blocking issues
- Important issues
- Minor issues
- Evidence with file paths and plan task references
- Minimal recommended edits
```

After each helper returns:

1. Capture the receipt.
2. Save it to `review-findings.md` or coordinator notes.
3. Close the helper immediately.

## Review Criteria

A plan is approved only when:

- every spec requirement maps to at least one task
- every behavior change has a verification step
- no task adds unrequested scope without approval
- existing files and symbols are real
- new files are created before they are used
- commands are concrete and runnable
- task order respects dependencies
- high-risk changes include compatibility, rollback, and failure-mode handling
- no placeholders or hand-waves remain

## Coordinator Duties

The main agent may:

- combine reviewer receipts
- apply concrete edits to the plan
- ask the human partner about true ambiguity
- dispatch targeted re-review for changed sections

The main agent must not:

- replace helper review with its own review when helpers are available
- give reviewers the full conversation
- let the plan author be the only reviewer
- ask reviewers to implement fixes
- approve a plan with blocking issues
- keep completed helpers open

## Re-review Rules

Run re-review only when:

- the plan changed since the last review
- a blocking or important issue was fixed
- referenced files or verifier state changed
- a new risk trigger appears
- the human partner requests it

When only one section changed, re-review that section plus dependencies. Do not run the whole review carousel for typo-only edits.

## Fallback

If helper/subagent support is unavailable, the main agent may perform the review inline. It must clearly label this as fallback mode and use only the approved spec, context pack, plan, and repo files as source material.
