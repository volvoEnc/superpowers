---
name: phase-handoff
description: Use when moving between finalized workflow phases, resuming after compaction, or continuing work from saved specs, plans, or partial execution state
---

# Phase Handoff

## Overview

Create a compact handoff artifact between workflow phases so the next agent or fresh session can continue from saved decisions instead of dragging the whole conversation forward.

A handoff is a context reset with receipts. It preserves decisions, state, and next actions. It discards rejected ideas, stale drafts, and exploration noise.

**Announce at start:** "I'm using the phase-handoff skill to preserve the current workflow state before continuing."

## When to Use

Use this skill when moving between durable artifacts:

- Brainstorming or design -> approved spec
- Approved spec -> implementation plan
- Reviewed plan -> execution
- Partial execution -> resumed execution
- Before compacting or clearing a long context
- When a subagent needs a clean context pack

Do not use this for tiny one-step tasks where the current context is still small and clean.

## Handoff Location

Save handoffs near the work they describe:

```text
docs/superpowers/runs/YYYY-MM-DD-<feature-name>/handoff.md
docs/superpowers/runs/YYYY-MM-DD-<feature-name>/state.json
```

If there is already a plan directory, save a copy or link there:

```text
docs/superpowers/plans/YYYY-MM-DD-<feature-name>/handoff.md
```

User preferences for location override these defaults.

## Handoff Document

Use this structure:

```markdown
# Handoff: [Feature Name]

**Created:** YYYY-MM-DD
**Current phase:** spec | plan | review | execution | finishing
**Next phase:** spec | plan | review | execution | finishing

## Source of Truth

- Spec: `docs/superpowers/specs/...`
- Plan: `docs/superpowers/plans/.../overview.md`
- Context pack: `docs/superpowers/plans/.../context-pack.md`
- Review receipt: `docs/superpowers/plans/.../review-findings.md`

## Current Git State

- Repository: `...`
- Branch: `...`
- Worktree: `...`
- Base commit: `...`
- Last green commit: `...`
- Dirty files: none, or exact paths

## Decisions Preserved

- ...

## Completed Work

- ...

## Current Status

- Current task: `task-NNN-name.md`
- Completed tasks: ...
- Blocked tasks: ...
- Review status: approved | issues-found | blocked

## Next Action

Use `superpowers:<skill-name>` to ...

## Do Not Reload

- Brainstorming transcript
- Rejected approaches
- Old draft plans
- Tool logs unless needed for a blocker
- Intermediate review receipts and decision packs (read the saved file on resume, not the chat)
- Per-task result files (docs/superpowers/runs/<run>/task-NNN-result.md) unless investigating a blocker

## Open Questions

- None, or exact questions that block the next phase
```

## State JSON

Save a small machine-readable state file:

```json
{
  "run_id": "YYYY-MM-DD-feature-name",
  "current_phase": "execution",
  "next_phase": "execution",
  "spec": "docs/superpowers/specs/YYYY-MM-DD-feature.md",
  "plan": "docs/superpowers/plans/YYYY-MM-DD-feature/overview.md",
  "context_pack": "docs/superpowers/plans/YYYY-MM-DD-feature/context-pack.md",
  "review_receipt": "docs/superpowers/plans/YYYY-MM-DD-feature/review-findings.md",
  "current_task": "task-003-name.md",
  "completed_tasks": ["task-001-name.md", "task-002-name.md"],
  "blocked_tasks": [],
  "last_green_commit": "abc1234",
  "next_action": "Execute task-003-name.md with superpowers:subagent-driven-development",
  "plan_risk_tier": "Tier-1 | Tier-2 | Tier-3",
  "test_results":           { "summary": "34/34", "exit_code": 0, "commit": "<sha>", "timestamp": "<iso>" },
  "code_review_verdict":    { "verdict": "clean | issues-found | blocked", "effort": "low | medium | high | max", "scope": "branch | task", "commit": "<sha>", "timestamp": "<iso>" },
  "security_review_status": { "required": true, "verdict": "clean | critical-open | n/a", "commit": "<sha>", "timestamp": "<iso>" }
}
```

Each evidence field records the `commit` and `timestamp` of the run that produced it. A cached verdict (`test_results`, `code_review_verdict`, `security_review_status`) is valid only when its `commit == current HEAD` SHA. Any new commit invalidates every cached verdict. Downstream skills such as `superpowers:finishing-a-development-branch` re-run the corresponding check whenever the SHA differs, the verdict is not clean, or the field is missing. This schema is defined here once; other skills reference these field names and must not redefine them.

Keep this file boring. Boring state survives compaction.

## Context Hygiene Rules

- Preserve only final decisions, current state, and next actions.
- Prefer links to durable artifacts over copied transcripts.
- Include exact paths and commits where they matter.
- Mark unresolved questions explicitly.
- Do not preserve discarded alternatives unless they explain a constraint the next agent must obey.
- Do not summarize tests as passing unless you actually ran them.

## Resume Instructions

When resuming from a handoff:

1. Read `handoff.md`.
2. Read only the artifacts listed under Source of Truth.
3. Check current git state against the handoff.
4. If `current_task` is set in `state.json`, confirm the remaining work for that task before acting on Next Action.
5. Continue from Next Action.
6. If state drifted, update the handoff before continuing.

## Red Flags

Never:

- Treat chat history as more authoritative than the approved spec or plan
- Carry old draft content into the next phase without labeling it stale
- Hide blockers inside a general summary
- Claim tests are green without command evidence
- Ask the next agent to infer next steps from prose when exact paths and tasks exist
