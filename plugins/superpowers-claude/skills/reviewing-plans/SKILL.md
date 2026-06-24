---
name: reviewing-plans
description: Use when an implementation plan exists and needs pre-execution review, coverage checking, or validation after substantial edits
---

# Reviewing Plans

## Core Rule

The main agent is the review coordinator, not the reviewer. It routes artifacts, merges receipts, and applies concrete plan edits — it never reviews inline in place of a reviewer. The default coordination path is the shipped Workflow; manual subagent dispatch is the documented fallback.

## Default: Workflow

When you are the **main agent** reviewing a **non-trivial plan**, run the shipped review Workflow instead of hand-dispatching reviewers. The Workflow encodes the same review dimensions (spec-coverage, plan-correctness, snippet, risk, security) as a parallel fan-out plus an adversarial-verify pass, and returns a structured verdict.

```text
Workflow({
  scriptPath: "<base directory for this skill>/review-plan.workflow.js",
  args: { planDir, specPath, contextPackPath, repoRoot, mode }
})
```

The base directory is the absolute path given at skill launch ("Base directory for this skill: …"). Build `scriptPath` from it — never guess a relative path.

- `mode` is one of `light | targeted | full` (see Review Modes); it selects which reviewer dimensions run and how deep, not how many rounds.
- The script runs **one** find→verify pass: parallel reviewers produce findings, then each finding is adversarially verified and REFUTED findings are dropped. It does not loop and it does not patch the plan.

Consume its structured verdict:

```text
{ verdict, blocking, important, minor }
// verdict: approved | issues-found | blocked
```

The coordinator then applies concrete plan edits for `blocking`/`important` findings, observing the cycle limit (max 1 re-review round — see Re-review Rules). Re-review = run the same Workflow again in `targeted` mode over the changed sections. The Workflow never edits the plan; patching stays with the coordinator.

Use the **Fallback (manual subagent dispatch)** path instead when the Workflow tool is unavailable — most commonly because you are running from inside a subagent (the Workflow tool can only be called by the main agent; nesting throws), or for a trivial plan where a full fan-out is overkill.

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

## Review Criteria (dimensions)

The same dimensions are checked on either path — the Workflow encodes them in its parallel reviewers; the manual fallback dispatches one read-only subagent per dimension:

1. **spec-coverage** - every spec requirement maps to at least one task and verification step; no unrequested scope.
2. **plan-correctness** - file paths, task order, commands, dependencies, and stale references are real and runnable; new files are created before use; no placeholders or hand-waves remain.
3. **snippet** - imports, symbols, tests, function names, and code snippets check out against the repo.
4. **risk** - migrations, security, data loss, concurrency, public APIs, rollback, and observability are handled.
5. **security** - security-sensitive changes have compatibility, rollback, and failure-mode handling.

A plan is approved only when every dimension passes with no blocking issues. Escalate to `full` mode for public API, migrations, security, data loss, concurrency, cross-cutting refactors, or non-trivial code snippets.

## Fallback (manual subagent dispatch)

Use this path automatically when the Workflow tool is unavailable: you are **invoked from within a subagent** (the Workflow tool can only be called by the main agent — calling `workflow()` from a subagent throws), or the plan is **trivial** and a full fan-out is overkill.

This fallback is manual **subagent dispatch** (Task tool), one reviewer at a time — **not** inline work by the orchestrator. You still send the review out to fresh read-only subagents; you only orchestrate the dispatch by hand instead of through the Workflow. It therefore does **not** violate coordinator-only-inline: the coordinator never performs reviewer-class work (repo inspection, snippet/symbol validation, file audits, `git diff` reading) itself.

### Subagent Roles

Dispatch only the roles needed for the selected mode (same dimensions as above):

1. **spec-coverage-reviewer** - maps spec requirements to plan tasks and verification steps.
2. **plan-correctness-reviewer** - checks file paths, task order, commands, dependencies, and stale references.
3. **snippet-reviewer** - checks imports, symbols, tests, function names, and code snippets against the repo.
4. **risk-reviewer** - checks migrations, data loss, concurrency, public APIs, rollback, and observability.
5. **security-reviewer** - checks security-sensitive changes (authn/authz, secrets, input validation, injection, unsafe external calls) and their compatibility, rollback, and failure-mode handling.

Each subagent must be read-only. These five roles mirror the Workflow's dimensions (full mode runs all five; lighter modes run a subset).

### Subagent Prompt Shape

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

## Coordinator-only-inline guardrail

Neither path lets the coordinator do reviewer-class work itself. On the **Default: Workflow** path the reviewing happens inside the Workflow's agents; on the **Fallback (manual subagent dispatch)** path it happens inside hand-dispatched Task subagents. The coordinator never inspects the repo, validates snippets/symbols, audits files, or reads `git diff` in place of a reviewer.

Inline coordinator work is allowed **only when the human partner explicitly asks** to work inline — never as an automatic reaction to a tool being unavailable. When asked, it is limited to lightweight coordinator-class checks against the saved spec, context pack, and plan:

- plan structure, placeholders, and obvious internal contradictions
- contradiction of the plan against the approved spec

If reviewer-class work (snippet, symbol, or repo inspection) is needed but both the Workflow tool and the Task tool are genuinely unavailable, **escalate / hard-stop** — do not perform it inline. The coordinator never substitutes itself for a reviewer.
