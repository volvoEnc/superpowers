---
name: verification-before-completion
description: Use when about to claim work is complete, fixed, or passing, before committing or creating PRs - requires running verification commands and confirming output before making any success claims; evidence before assertions always
---

# Verification Before Completion

## Overview

Claiming work is complete without verification is dishonesty, not efficiency.

**Core principle:** Evidence before claims, always.

**Violating the letter of this rule is violating the spirit of this rule.**

## The Iron Law

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

If you haven't run the verification command in this message, you cannot claim it passes.

## Security-Review Risk Tiers

Single source of truth for when `/security-review` is required. Other skills (`executing-plans`, `finishing-a-development-branch`, `subagent-driven-development`) reference THIS section — do not redefine tiers elsewhere.

| Tier | `/security-review` | Areas |
|------|--------------------|-------|
| **Tier 1** | **Mandatory** | auth/authz, cryptography, secrets, external API keys, shell execution, file permissions, SQL/DB mutations + DDL + data export |
| **Tier 2** | Optional (judgment) | large refactors, configuration changes |
| **Tier 3** | Skip | docs, UI text, tests-only |

**Mixed changes:** apply the highest applicable tier — if a change touches any Tier-1 area, the whole change is Tier 1. SQL/DB: mutations, DDL, and export are Tier 1; pure read-only queries are not Tier 1 by default (escalate only if context warrants).

*(Default proposal — your human partner confirms the list against their threat model.)*

## The Gate Function

```
BEFORE claiming any status or expressing satisfaction:

1. IDENTIFY: What command proves this claim?
2. RUN: Execute the FULL command (fresh, complete)
3. READ: Full output, check exit code, count failures
4. VERIFY: Does output confirm the claim?
   - If NO: State actual status with evidence
   - If YES: State claim WITH evidence
5. ONLY THEN: Make the claim

Skip any step = lying, not verifying
```

## Common Failures

| Claim | Requires | Not Sufficient |
|-------|----------|----------------|
| Tests pass | Test command output: 0 failures | Previous run, "should pass" |
| Linter clean | Linter output: 0 errors | Partial check, extrapolation |
| Build succeeds | Build command: exit 0 | Linter passing, logs look good |
| Bug fixed | Test original symptom: passes | Code changed, assumed fixed |
| Regression test works | Red-green cycle verified | Test passes once |
| Agent completed | VCS diff shows changes | Agent reports "success" |
| Requirements met | Line-by-line checklist | Tests passing |
| Behavioral change works | verify/run skill: app exercised, behavior observed | Unit tests green |

## Red Flags - STOP

- Using "should", "probably", "seems to"
- Expressing satisfaction before verification ("Great!", "Perfect!", "Done!", etc.)
- About to commit/push/PR without verification
- Trusting agent success reports
- Relying on partial verification
- Thinking "just this once"
- Tired and wanting work over
- **ANY wording implying success without having run verification**

## Evidence Capture

Before any completion claim, capture one tight evidence line with these fields:

- **Test count + exit code** — e.g. `34/34, exit 0`
- **Build status** — e.g. `clean` / `exit 0`
- **Diff stats** — files/lines changed
- **Review verdict** — `/code-review` outcome (critical count) when a review ran

Example: `Tests pass [34/34, exit 0]. Build clean. Diff: 3 files +52/-7. Code review: 0 critical.`

Each field is a claim — only include a field you actually ran the command for (see The Gate Function).

### Persist evidence to durable state

The tight line goes in your context. **Additionally, write the structured evidence into `state.json`** so downstream skills (`finishing-a-development-branch`) can read it without re-running anything. Use the shared schema fields defined in `superpowers:phase-handoff` — do not redefine the schema here:

- `test_results` — when you ran the test command (summary, exit_code).
- `code_review_verdict` — when `/code-review` ran (verdict, effort, and `scope`: `branch` for a full-branch review, `task` for a single-task diff). `finishing` only reuses a cached verdict that is `effort` ≥ medium **and** `scope == "branch"`, so always stamp both — a low-effort or task-scoped review will (correctly) not satisfy the final branch gate.
- `security_review_status` — when `/security-review` ran or was decided n/a (required, verdict).
- `plan_risk_tier` — the tier from the Security-Review Risk Tiers table above, if known.

**Stamp each record with the current commit SHA** (`git rev-parse HEAD`) in its `commit` field, plus a `timestamp`. The SHA stamp is load-bearing: `finishing` SHA-validates each cached verdict against HEAD — matching SHA + clean verdict → skip the re-review; differing SHA → re-run. Write only fields you actually verified (a record is a claim — same rule as the tight line).

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "Should work now" | RUN the verification |
| "I'm confident" | Confidence ≠ evidence |
| "Just this once" | No exceptions |
| "Linter passed" | Linter ≠ compiler |
| "Agent said success" | Verify independently |
| "I'm tired" | Exhaustion ≠ excuse |
| "Partial check is enough" | Partial proves nothing |
| "Different words so rule doesn't apply" | Spirit over letter |

## Key Patterns

**Tests:**
```
✅ [Run test command] [See: 34/34 pass] "All tests pass"
❌ "Should pass now" / "Looks correct"
```

**Regression tests (TDD Red-Green):**
```
✅ Write → Run (pass) → Revert fix → Run (MUST FAIL) → Restore → Run (pass)
❌ "I've written a regression test" (without red-green verification)
```

**Build:**
```
✅ [Run build] [See: exit 0] "Build passes"
❌ "Linter passed" (linter doesn't check compilation)
```

**Requirements:**
```
✅ Re-read plan → Create checklist → Verify each → Report gaps or completion
❌ "Tests pass, phase complete"
```

**Agent delegation:**
```
✅ Agent reports success → Check VCS diff → Verify changes → Report actual state
❌ Trust agent report
```

## Why This Matters

From 24 failure memories:
- your human partner said "I don't believe you" - trust broken
- Undefined functions shipped - would crash
- Missing requirements shipped - incomplete features
- Time wasted on false completion → redirect → rework
- Violates: "Honesty is a core value. If you lie, you'll be replaced."

## When To Apply

**ALWAYS before:**
- ANY variation of success/completion claims
- ANY expression of satisfaction
- ANY positive statement about work state
- Committing, PR creation, task completion
- Moving to next task
- Delegating to agents

**Rule applies to:**
- Exact phrases
- Paraphrases and synonyms
- Implications of success
- ANY communication suggesting completion/correctness

## The Bottom Line

**No shortcuts for verification.**

Run the command. Read the output. THEN claim the result.

This is non-negotiable.
