---
name: brainstorming
description: Use before planning product or code changes
---

# Brainstorming

Turn a rough request into an approved written spec before implementation planning.

## Flow

1. Explore the current project context: files, docs, and recent commits.
2. Ask one clarifying question at a time.
3. Propose 2-3 approaches with trade-offs and a recommendation.
4. Present the design in readable sections and ask for approval.
5. Save the approved design to `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`.
6. Review the spec for placeholders, contradictions, ambiguity, and scope creep.
7. Ask for review of the written spec.
8. After approval, invoke `superpowers:writing-plans`.

## Defaults

- Brainstorming is text-only.
- Keep questions focused and one at a time.
- Prefer multiple-choice questions when useful.
- Split large ideas into independent specs before planning.
- Keep unrelated refactoring out of the design.

## Spec Review Checklist

- No TBD or TODO placeholders.
- No contradictory requirements.
- Scope fits one implementation plan.
- Ambiguous choices are made explicit.
