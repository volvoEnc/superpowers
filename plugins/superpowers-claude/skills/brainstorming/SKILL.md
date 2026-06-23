---
name: brainstorming
description: "Use before planning product or code changes. Protects the branch first, scouts context with subagents, and turns rough requests into approved design artifacts without polluting the orchestrator context."
---

# Brainstorming

Turn a rough chat request or task file into approved design artifacts while keeping the main agent's context clean.

## Core Rule

The main agent is the orchestrator, facilitator, and state keeper. It asks the human partner questions, records decisions, routes compact artifacts, and coordinates subagents. It should not perform large context exploration, question discovery, spec writing, or spec review inline when subagents are available.

## Hard Gates

1. First use `superpowers:using-git-branches` in `design-start` mode.
2. Do not explore repo context, read long task files, write artifacts, or ask the first clarifying question until branch safety is complete.
3. Do not invoke implementation skills, write code, scaffold projects, or modify behavior until the design is approved.
4. Do not transition to planning until the written spec is approved by the human partner.

## Orchestrated Flow

1. **Protect the branch** with `superpowers:using-git-branches` in `design-start` mode.
2. **Create a request brief.** For a short chat request, summarize it directly. For a long chat request or provided file, dispatch a fresh task-intake subagent (Task tool) and capture only its compact brief.
3. **Dispatch `repo-context-scout`.** Give it only the request brief plus targeted repo paths or instructions to inspect files, docs, and recent commits. It returns a compact context brief.
4. **Keep only the context brief.** The scout returns its result and terminates on its own. The context brief is the artifact. Do not carry raw file dumps, search logs, or exploration notes forward.
5. **Dispatch `question-strategist`.** Give it only the request brief, context brief, and current decision pack. It returns blocking unknowns and the next best question plan.
5a. **(Conditional — mandatory for Tier-1) Dispatch `multi-angle-analyzer`.** Trigger when a Tier-1 area is touched (Security-Review Risk Tiers in `superpowers:verification-before-completion`), OR more than one subsystem / many blocking unknowns are involved, OR the human partner asks for a deep analysis. **A Tier-1 area always triggers it — the "small/isolated" escape never applies to Tier-1 work.** Skip only for small, isolated, non-Tier-1 changes. It examines the request through 6-8 lenses — security, performance, data-integrity, UX, maintainability, failure-modes, cost/scale, ops-complexity — and returns at most one blocking concern per lens plus cross-cutting questions. Feed its concerns into the question plan and the Risk Dimensions table in the decision pack. Keep only its compact result.
6. **Ask the next question(s).** Default to one at a time for dependent unknowns; batch 2-4 **independent** questions in one `AskUserQuestion` call when their answers do not reframe each other (see Question Loop Rules for the independence test). The main agent records answers and updates the decision pack.
7. **Repeat with fresh question strategy when needed.** For non-trivial work, dispatch a fresh `question-strategist` after each material answer or small answer batch. Keep only its compact result.
8. **Return decisions to the orchestrator.** Once blocking questions are resolved, the main agent owns the approved decisions in the decision pack. Only the compact subagent results are kept; raw working context is not carried forward.
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
- raw subagent working context, file dumps, or transcripts (keep only their compact results/receipts)
- speculative implementation details not approved by the human partner

## Request Brief

Use this shape for short chat requests or as the output target for the task-intake subagent:

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

Tag each taxonomy dimension `DECIDED` | `TBD` | `NOT-APPLICABLE`:

| Dimension | Verdict | Decision / Note |
|---|---|---|
| Goal | TBD | |
| Scope | TBD | |
| Non-Goals | TBD | |
| Constraints | TBD | |
| Success Metrics | TBD | |
| Error Handling | TBD | |
| Data Model | TBD | |
| Security | TBD | |
| Performance | TBD | |
| UX | TBD | |
| Edge Cases | TBD | |
| Rollout/Verification | TBD | |

## Chosen Approach

## Alternatives Rejected

## Open Questions

## Risk Dimensions

Mandatory whenever a Tier-1 area is touched (the Multi-Angle Analyzer is required then, so this table must be filled). May be omitted or marked `NOT-APPLICABLE` only for non-Tier-1 changes where the analyzer was skipped.

| Lens | Top Concern | Severity | Cross-Question Raised |
|---|---|---|---|
```

Only approved decisions belong here. Do not copy the whole chat, rejected drafts, or exploration logs.

## Subagent Prompt Shapes

### Task Intake subagent

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
Map each blocking unknown to a Question Taxonomy dimension (Goal, Scope, Non-Goals, Constraints, Success Metrics, Error Handling, Data Model, Security, Performance, UX, Edge Cases, Rollout/Verification).
Return:
- blocking unknowns, each tagged with its taxonomy dimension
- dimensions covered so far, and dimensions still TBD
- the next dimension to address and why it matters now
- the next question(s): a single question for dependent unknowns, OR 2-4 independent questions the orchestrator can batch in one AskUserQuestion call
- 2-4 multiple-choice options when useful
- whether enough is known to discuss approaches
```

### Multi-Angle Analyzer subagent

Optional, risk-triggered. Use only when the Orchestrated Flow trigger is met.

```text
You are stress-testing the request through multiple lenses, not designing or implementing.
Use only the request brief, context brief, and current decision pack.
Examine 6-8 lenses: security, performance, data-integrity, UX, maintainability, failure-modes, cost/scale, ops-complexity.
Return at most ONE blocking concern per lens (skip lenses with no real concern), each with a severity and a concrete cross-question the orchestrator should ask.
Do not write a spec. Do not propose the full solution. Keep the output as a compact Risk Dimensions table.
```

### Approach Scout

```text
You are comparing solution approaches, not writing the final design.
Use only the decision pack and context brief.
Return 2-3 approaches with trade-offs, risks, and one recommendation.
Keep rejected or speculative details out of the decision pack unless the human partner approves them.
```

### Spec Author subagent

```text
You are writing the spec, not implementing code.
Use only the approved decision pack and listed repo context.
Do not use chat history.
Return a complete spec with goal, scope, architecture, behavior, error handling, testing strategy, and acceptance criteria.
```

### Spec Reviewer subagent

```text
You are reviewing a spec, not implementing code.
Use only the saved spec, decision pack, context brief, and listed repo files.
Check for missing decisions, contradictions, ambiguity, scope creep, placeholders, and untestable acceptance criteria.
Return a short receipt: approved | issues-found | blocked, with concrete findings and suggested spec edits.
```

## Question Loop Rules

- Default to one question per message for dependent or sequential clarifications (where the answer to one changes the wording or meaning of the next).
- You may batch 2-4 **independent** questions in a single `AskUserQuestion` call. Questions are independent when the answer to one does not change the wording or meaning of another.
  - Good (independent, batchable): "What is the primary goal?" + "What is the success metric?" + "What is the hard constraint?" — none reframes the others.
  - Bad (dependent, ask one at a time): "Should we use a queue?" then "Which queue technology?" — the second only makes sense, and is worded differently, depending on the first answer.
- `AskUserQuestion` is a Claude Code built-in; reference it without a `superpowers:` prefix.
- Prefer multiple-choice questions when useful.
- Continue until the decision pack can answer goal, scope, constraints, non-goals, success criteria, error handling expectations, and verification expectations.
- For large or independent subsystems, stop and help split the work into separate specs before planning details.
- Do not ask performative questions whose answers will not affect the design.
- If a human answer resolves several unknowns, record all resolved decisions before asking the next question.

## Question Taxonomy

Drive elicitation breadth across these 12 dimensions. The Question Strategist maps blocking unknowns onto them; the Decision Pack records the verdict per dimension.

1. **Goal** — what outcome the change must produce.
2. **Scope** — what is included in this change.
3. **Non-Goals** — what is explicitly excluded.
4. **Constraints** — technical, time, or policy limits.
5. **Success Metrics** — how "done/working" is measured.
6. **Error Handling** — failure modes and expected behavior.
7. **Data Model** — entities, shapes, migrations, persistence.
8. **Security** — auth/authz, secrets, exposure, trust boundaries.
9. **Performance** — latency, throughput, resource limits.
10. **UX** — user-visible behavior and interaction.
11. **Edge Cases** — boundary inputs and rare states.
12. **Rollout/Verification** — how the change ships and is verified.

**Adaptivity:** simple changes fill only the relevant dimensions and mark the rest `NOT-APPLICABLE`. Do not manufacture questions to fill every dimension — coverage means each dimension is consciously decided or dismissed, not exhaustively interrogated.

## Defaults

- Brainstorming is text-only.
- Do not offer or use the visual companion.
- Keep unrelated refactoring out of the design.
- Keep subagent outputs short and artifact-shaped.
- Keep only each subagent's compact result/receipt — never carry its raw working context, file dumps, or transcript forward. If follow-up is needed, dispatch a fresh subagent with the prior result and the exact follow-up scope.

## Fallback

If subagents are unavailable or the human partner asks you to work inline, the main agent may perform the same steps inline. It must still maintain the request brief, context brief, and decision pack as the only source of truth, and must not carry rejected chat history into planning.
