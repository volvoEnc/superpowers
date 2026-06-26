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
  "security_review_status": { "required": true, "verdict": "clean | critical-open | n/a", "scope": "branch | task", "commit": "<sha>", "timestamp": "<iso>" }
}
```

In `security_review_status`, `required` is a boolean: `true` when the change is Tier-1 (security review mandatory), `false` otherwise — and verdict `n/a` pairs with `required: false`.

Each evidence field records the `commit` and `timestamp` of the run that produced it. A cached verdict (`test_results`, `code_review_verdict`, `security_review_status`) is valid only when its `commit == current HEAD` SHA. Any new commit invalidates every cached verdict. Downstream skills such as `superpowers:finishing-a-development-branch` re-run the corresponding check whenever the SHA differs, the verdict is not clean, or the field is missing. This schema is defined here once; other skills reference these field names and must not redefine them.

### Liveness fields (in-flight tracking)

Optional liveness fields track units that have been dispatched but not yet reconciled. They sit alongside the fields above (same conventions: ISO-8601 timestamps, enum strings not prose). This section defines the **shapes** only; the liveness **behavior** that consumes them lives in `../../docs/liveness-doctrine.md`.

```jsonc
{
  // ... all existing fields unchanged ...

  // units currently dispatched and not yet reconciled
  "inflight": [
    {
      "task": "task-003-name.md",          // which task this dispatch is for
      "kind": "bg-bash",                    // "sync" | "bg-agent" | "bg-bash"
      "promoted": true,                     // true when the unit went background+monitored
      "deadline_s": 600,                    // budgeted wall-clock for THIS task (tunable)
      "dispatched_at": "2026-06-24T10:00:00Z",
      "last_progress_at": "2026-06-24T10:00:00Z", // initialized to dispatched_at; updated on any progress signal
      "output_path": "docs/superpowers/runs/<run>/bg-task-003.log", // bg-bash/bg-agent only; null for sync
      "restarts": 0                         // liveness restart count (tunable bound),
                                            //   separate from the content max-2-fix-attempts pool
    }
  ]
}
```

- **`inflight`** is an **array** (a batch may dispatch several units). An entry is **removed** when the unit completes and its receipt is written, so a non-empty `inflight` on resume == "something was in flight." Unlike the SHA-gated evidence caches (`test_results` / `code_review_verdict` / `security_review_status`), `inflight` is **NOT** a SHA-gated cache: its lifecycle is "removed on completion + receipt write," not "invalidated on new commit."
- **`deadline_s`** is **per-task**, assigned by risk tier at dispatch. Default ladder (all **tunable**, the orchestrator may override per task): Tier-3 `120`, Tier-2 `300`, Tier-1 `600`.
- **`promoted`** records whether the unit went background+monitored (vs. a plain synchronous dispatch).
- **`restarts`** is the **liveness** pool — explicitly **separate** from the content-triggered max-2-fix-attempts pool, which stays where it is.
- **`last_progress_at`** is **initialized to `dispatched_at`** at dispatch for **every** unit and is updated on any progress signal. For a `sync`/non-promoted unit and for a signal-less bg-agent (no cheap progress signal) it simply tracks `dispatched_at`, so the floor governs on `now - dispatched_at` until a real progress signal arrives.
- **Compaction survival:** a resumed orchestrator reads `state.json`, sees a non-empty `inflight`, and for each entry computes `now - dispatched_at` / `now - last_progress_at`; if that exceeds `G × deadline_s` (grace multiplier `G`, **tunable**) it concludes "in flight too long → check/restart." This is why `inflight` lives in `state.json` and not in chat.

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
5. **Run the liveness floor against `state.json`.** If `inflight[]` is non-empty, run `../../scripts/liveness-floor.sh <state.json>` — it is detect-only: it flags `STALE` units (`now - dispatched_at` past `G × deadline_s`) and the orchestrator decides the response. For each `STALE` line, enter the response path in `../../docs/liveness-doctrine.md` (§7). This is the only liveness signal that survives compaction (§8); the script does not change `state.json`.
6. Continue from Next Action.
7. If state drifted, update the handoff before continuing.

## Red Flags

Never:

- Treat chat history as more authoritative than the approved spec or plan
- Carry old draft content into the next phase without labeling it stale
- Hide blockers inside a general summary
- Claim tests are green without command evidence
- Ask the next agent to infer next steps from prose when exact paths and tasks exist
