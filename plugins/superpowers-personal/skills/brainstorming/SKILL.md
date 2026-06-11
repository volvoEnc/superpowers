---
name: brainstorming
description: "Use before planning product or code changes. Protects the branch first, scouts context with helpers, and turns rough requests into approved design artifacts without polluting the orchestrator context."
---

# Brainstorming

Turn a rough chat request or task file into approved design artifacts while keeping the main agent's context clean.

## Core Rule

The main agent is the orchestrator, facilitator, and state keeper. It asks the human partner questions, records decisions, routes compact artifacts, and coordinates helpers. It should not perform large context exploration, question discovery, spec writing, or spec review inline when helper/subagent support is available.

## Hard Gates

1. First use `superpowers:using-git-branches` in `design-start` mode.
2. Do not explore repo context, read long task files, write artifacts, or ask the first clarifying question until branch safety is complete.
3. Do not invoke implementation skills, write code, scaffold projects, or modify behavior until the design is approved.
4. Do not transition to planning until the written spec is approved by the human partner.

## Orchestrated Flow

1. **Protect the branch** with `superpowers:using-git-branches` in `design-start` mode.
2. **Create a request brief.** For a short chat request, summarize it directly. For a long chat request or provided file, dispatch a fresh `task-intake-helper` and capture only its compact brief.
3. **Dispatch `repo-context-scout`.** Give it only the request brief plus targeted repo paths or instructions to inspect files, docs, and recent commits. It returns a compact context brief.
4. **Close the scout immediately.** The context brief is the artifact. Do not carry raw file dumps, search logs, or exploration notes forward.
5. **Dispatch `question-strategist`.** Give it only the request brief, context brief, and current decision pack. It returns blocking unknowns and the next best question plan.
6. **Ask one question at a time.** The main agent asks the human partner the next question, records the answer, and updates the decision pack.
7. **Repeat with fresh question strategy when needed.** For non-trivial work, dispatch a fresh `question-strategist` after each material answer or small answer batch. Close it after capturing the result.
8. **Return decisions to the orchestrator.** Once blocking questions are resolved, the main agent owns the approved decisions in the decision pack. Helper threads are closed.
9. **Dispatch `approach-scout`.** Give it the decision pack and context brief. It proposes 2-3 approaches with trade-offs and a recommendation.
10. **Present approaches and design sections.** The main agent presents readable sections, asks for approval, and updates the decision pack from approved decisions only.
11. **Dispatch `spec-author`.** Give it only the approved decision pack and relevant context brief. It writes the spec, not code.
12. **Save the spec** to `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` unless the human partner specified another location.
13. **Dispatch `spec-reviewer`.** Give it only the saved spec, decision pack, context brief, and relevant file paths.
14. **Patch concrete findings only.** If the spec changes materially, dispatch a fresh targeted reviewer for changed sections.
15. **Ask the human partner to review the written spec.** After approval, use `superpowers:phase-handoff`, then `superpowers:writing-plans`.

## Clean Context Contract

The main agent may keep:

- request brief
- context brief
- active decision pack
- current open question
- latest human answer
- artifact paths and review receipts

The main agent must not keep or forward:

- full chat transcript
- full task file contents after intake
- raw grep/search/tool logs
- rejected drafts
- old helper threads as memory
- speculative implementation details not approved by the human partner

## Request Brief

Use this shape for short chat requests or as the output target for `task-intake-helper`:

```markdown
# Request Brief

## Raw Input Source
- chat | file:<path> | mixed

## User Goal

## Explicit Requirements

## Implied Requirements

## Constraints

## Non-Goals Mentioned

## Repo Areas Likely Relevant

## Initial Risks

## Unknowns For Clarification
```

## Decision Pack

Keep this short and update it after each human answer:

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

## Helper Prompt Shapes

### Task Intake Helper

Use for long chat requests, attached files, or dense requirement documents:

```text
You are creating a compact task brief, not designing or implementing.
Read only the provided request/file content and return the Request Brief shape.
Do not inspect the repository unless explicitly told.
Do not use chat history.
Highlight contradictions, missing decisions, and likely first questions.
```

### Repo Context Scout

```text
You are scouting repository context for brainstorming.
Do not write a spec. Do not write a plan. Do not modify files.
Use only the request brief and targeted repository inspection.
Return a compact context brief: relevant files, existing patterns, constraints, risks, test/build signals, and questions the orchestrator should ask.
Do not include raw file dumps or long excerpts.
```

### Question Strategist

```text
You are helping the orchestrator decide what to ask next.
Do not ask the human directly. Do not write a spec. Do not design the full solution.
Use only the request brief, context brief, and current decision pack.
Return:
- blocking unknowns
- whether enough is known to discuss approaches
- the single next best question
- 2-4 multiple-choice options when useful
- why this question matters
```

### Approach Scout

```text
You are comparing solution approaches, not writing the final design.
Use only the decision pack and context brief.
Return 2-3 approaches with trade-offs, risks, and one recommendation.
Keep rejected or speculative details out of the decision pack unless the human partner approves them.
```

### Spec Author Helper

```text
You are writing the spec, not implementing code.
Use only the approved decision pack and listed repo context.
Do not use chat history.
Return a complete spec with goal, scope, architecture, behavior, error handling, testing strategy, and acceptance criteria.
```

### Spec Reviewer Helper

```text
You are reviewing a spec, not implementing code.
Use only the saved spec, decision pack, context brief, and listed repo files.
Check for missing decisions, contradictions, ambiguity, scope creep, placeholders, and untestable acceptance criteria.
Return a short receipt: approved | issues-found | blocked, with concrete findings and suggested spec edits.
```

## Question Loop Rules

- Ask exactly one question per message.
- Prefer multiple-choice questions when useful.
- Continue until the decision pack can answer goal, scope, constraints, non-goals, success criteria, error handling expectations, and verification expectations.
- For large or independent subsystems, stop and help split the work into separate specs before planning details.
- Do not ask performative questions whose answers will not affect the design.
- If a human answer resolves several unknowns, record all resolved decisions before asking the next question.

## Defaults

- Brainstorming is text-only.
- Do not offer or use the visual companion.
- Keep unrelated refactoring out of the design.
- Keep helper outputs short and artifact-shaped.
- Close every completed helper immediately after its result is captured.

## Fallback

If helper/subagent support is unavailable, the main agent may perform the same steps inline. It must still maintain the request brief, context brief, and decision pack as the only source of truth, and must not carry rejected chat history into planning.
