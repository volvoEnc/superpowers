---
name: brainstorming
description: Use before planning product or code changes
---

# Brainstorming

Turn a rough request into approved design artifacts without letting the orchestrator carry draft noise into planning.

## Core Rule

The main agent is the facilitator and state keeper. It asks questions, records decisions, and coordinates helpers. It should not perform spec writing or spec review inline when helper/subagent support is available.

## Flow

1. Explore the current project context: files, docs, recent commits.
2. Ask one clarifying question at a time.
3. Propose 2-3 approaches with trade-offs and a recommendation.
4. Present the design in readable sections and get approval.
5. Create a compact decision pack from approved decisions only.
6. Dispatch a fresh spec-author helper with the decision pack and relevant repo context.
7. Capture the spec-author result, save the spec, then close the helper.
8. Dispatch a fresh spec-reviewer helper with only the saved spec, decision pack, and relevant files.
9. Capture the review receipt, close the reviewer, and patch only concrete findings.
10. If the spec changed materially, dispatch a fresh reviewer for the changed sections.
11. Ask the human partner to review the written spec.
12. After approval, use `superpowers:phase-handoff`, then `superpowers:writing-plans`.

## Decision Pack

Save or keep a short decision pack before writing the spec:

```markdown
# Decision Pack

## Goal

## Approved Scope

## Out of Scope

## Constraints

## Chosen Approach

## Alternatives Rejected

## Open Questions
```

Only approved decisions belong here. Do not copy the whole chat, rejected drafts, or exploration logs.

## Spec Author Helper

Give the helper this shape:

```text
You are writing the spec, not implementing code.
Use only the decision pack and listed repo context.
Do not use chat history.
Return a complete spec with goal, scope, architecture, behavior, error handling, testing strategy, and acceptance criteria.
```

After the helper returns, save the spec to:

```text
docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md
```

Then close the helper immediately.

## Spec Reviewer Helper

Give the reviewer this shape:

```text
You are reviewing a spec, not implementing code.
Use only the saved spec, decision pack, and listed repo context.
Check for missing decisions, contradictions, ambiguity, scope creep, placeholders, and untestable acceptance criteria.
Return a short receipt: approved | issues-found | blocked, with concrete findings and suggested spec edits.
```

After the reviewer returns, save the receipt if useful, then close the helper immediately.

## Defaults

- Brainstorming is text-only.
- Do not offer or use the visual companion.
- Keep questions focused and one at a time.
- Prefer multiple-choice questions when useful.
- Split large ideas into independent specs before planning.
- Keep unrelated refactoring out of the design.
- Do not transition to planning until the written spec is approved.

## Fallback

If helper/subagent support is unavailable, the main agent may write and review the spec inline, but must keep the decision pack as the only source of truth and must not carry rejected chat history into planning.
