---
name: reviewing-plans
description: Use when an implementation plan exists and needs pre-execution review, coverage checking, or validation after substantial edits
---

# Reviewing Plans

## Core Rule

The main agent is the review coordinator, not the reviewer. When subagents are available, dispatch fresh read-only reviewers (Task tool) with sterile inputs. The main agent only routes artifacts, merges receipts, and applies concrete plan edits.

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

## Subagent Roles

Dispatch only the roles needed for the selected mode:

1. **spec-coverage-reviewer** - maps spec requirements to plan tasks and verification steps.
2. **plan-correctness-reviewer** - checks file paths, task order, commands, dependencies, and stale references.
3. **snippet-reviewer** - checks imports, symbols, tests, function names, and code snippets against the repo.
4. **risk-reviewer** - checks migrations, security, data loss, concurrency, public APIs, rollback, and observability.

Each subagent must be read-only.

## Subagent Prompt Shape

```text
You are reviewing a plan, not implementing code.
Do not modify files. Do not commit. Read-only.
Do not use chat history.
Repo context:
- repo root: <absolute path>
- base branch: <base> (diff base for "what this plan changes")
- you may read repo files and run `git diff <base>...HEAD`; never write, never commit
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

After each subagent returns:

1. Capture the receipt.
2. Save it to `review-findings.md` or coordinator notes.

Each Task subagent returns its result and terminates on its own. Keep only its compact receipt — never carry its raw working context, file dumps, or transcript forward. If follow-up is needed, dispatch a fresh subagent with the prior result and the exact follow-up scope.

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

- replace subagent review with its own review when subagents are available
- give reviewers the full conversation
- let the plan author be the only reviewer
- ask reviewers to implement fixes
- approve a plan with blocking issues
- carry a completed subagent's raw working context forward instead of its compact receipt

## Re-review Rules

Run re-review only when:

- the plan changed since the last review
- a blocking or important issue was fixed
- referenced files or verifier state changed
- a new risk trigger appears
- the human partner requests it

When only one section changed, re-review that section plus dependencies. Do not run the whole review carousel for typo-only edits.

Cap each receipt at **max 1 round** of coordinator edit-and-re-review. After you fix the issues from a receipt and re-dispatch once:

- if the re-review surfaces a **new blocking issue**, stop and escalate as `human-decision-required` — do not start another edit/re-review round on the same receipt.
- if the re-review surfaces only non-blocking (important/minor) issues, **note** them in the findings and proceed; they do not gate execution.

Escalation outcomes follow the shared cycle-limit doctrine (see `superpowers:subagent-driven-development`): `approved-amended-plan` | `human-decision-required` | `task-removed`.

## Fallback

Inline review is **coordinator-only** and allowed **only when the human partner explicitly asks** to work inline — never as an automatic reaction to the Task tool being unavailable. Label it clearly as fallback mode.

Inline fallback is limited to lightweight coordinator-class checks against the saved spec, context pack, and plan:

- plan structure, placeholders, and obvious internal contradictions
- contradiction of the plan against the approved spec

The coordinator must **not** do reviewer-subagent-class work inline: no repo inspection, no snippet/symbol validation, no file audits, no `git diff` reading. That work goes to fresh read-only subagents.

If reviewer-subagent-class work (snippet, symbol, or repo inspection) is needed but the Task tool is genuinely unavailable, **escalate / hard-stop** — do not perform it inline. The coordinator never substitutes itself for a subagent.
