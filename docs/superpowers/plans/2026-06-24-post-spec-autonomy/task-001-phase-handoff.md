# Task 1: Extend state.json schema contract + Do-Not-Reload + mid-task resume (phase-handoff)

**Risk:** medium
**Depends on:** none
**Review policy:** per-task-plus-risk
**Files:** Modify: `plugins/superpowers-claude/skills/phase-handoff/SKILL.md`

This file is the SINGLE SOURCE for the `state.json` schema. Tasks 003-006 reference it by name and MUST NOT redefine these fields. This task is FOUNDATIONAL (spec items D + L) — it lands first.

## Steps

- [ ] **Step 1: Define acceptance checks (run from repo root `/Users/danilka/llm-plugins/superpowers`).**
  Four new schema fields, the SHA-cache rule, two new Do-Not-Reload entries, and the mid-task resume check must exist after the edit.
  - `grep -c '"plan_risk_tier"\|"test_results"\|"code_review_verdict"\|"security_review_status"' plugins/superpowers-claude/skills/phase-handoff/SKILL.md` → expected `4`
  - `grep -n 'commit == current HEAD' plugins/superpowers-claude/skills/phase-handoff/SKILL.md` → matches the cache-validity sentence
  - `grep -n 'review receipt\|decision pack' plugins/superpowers-claude/skills/phase-handoff/SKILL.md` → matches new Do Not Reload bullets
  - `grep -n 'current_task is set' plugins/superpowers-claude/skills/phase-handoff/SKILL.md` → matches new resume step
  - **Behavioral pressure-test (schema is the cross-skill contract).**
    BEFORE: `finishing` resumes after a stale compact, sees a `state.json` with no commit-bound evidence fields, and re-runs `/code-review` and `/security-review` from scratch every time (wasted cycles), OR trusts a cached "clean" verdict produced 3 commits ago and skips review on dirty code.
    AFTER: with the extended schema, every cached verdict carries `commit` + `timestamp`; `finishing` (Task 005) compares `verdict.commit` to current HEAD SHA — skips only on exact match + clean verdict, re-runs otherwise. A new commit always invalidates the cache. The schema lives ONLY here; downstream skills read these field names without redefining them.

- [ ] **Step 2: Verify the checks currently FAIL (fields absent).**
  - `grep -c '"plan_risk_tier"\|"test_results"\|"code_review_verdict"\|"security_review_status"' plugins/superpowers-claude/skills/phase-handoff/SKILL.md` → expected `0`
  - `grep -n 'commit == current HEAD\|current_task is set\|review receipt\|decision pack' plugins/superpowers-claude/skills/phase-handoff/SKILL.md` → no matches (exit 1)

- [ ] **Step 3a: Extend the `## State JSON` block with the four contract fields.**
  Anchor: the JSON object under `## State JSON` (currently lines ~108-123). The block ends with:
  ```json
    "last_green_commit": "abc1234",
    "next_action": "Execute task-003-name.md with superpowers:subagent-driven-development"
  }
  ```
  Add a trailing comma after the `next_action` line and append the four evidence fields exactly as the context-pack contract defines (field names verbatim). The object becomes:
  ```json
    "last_green_commit": "abc1234",
    "next_action": "Execute task-003-name.md with superpowers:subagent-driven-development",
    "plan_risk_tier": "Tier-1 | Tier-2 | Tier-3",
    "test_results":           { "summary": "34/34", "exit_code": 0, "commit": "<sha>", "timestamp": "<iso>" },
    "code_review_verdict":    { "verdict": "clean | issues-found | blocked", "effort": "medium", "commit": "<sha>", "timestamp": "<iso>" },
    "security_review_status": { "required": true, "verdict": "clean | critical-open | n/a", "commit": "<sha>", "timestamp": "<iso>" }
  }
  ```

- [ ] **Step 3b: Add the SHA-cache invalidation rule.**
  Immediately AFTER the JSON block in `## State JSON`, BEFORE the line `Keep this file boring. Boring state survives compaction.`, insert a prose paragraph stating: each evidence field carries the `commit` and `timestamp` of the run that produced it; a cached verdict (`test_results`, `code_review_verdict`, `security_review_status`) is valid ONLY when its `commit` == the current HEAD SHA. Any new commit invalidates every cached verdict — downstream skills (e.g. `superpowers:finishing-a-development-branch`) re-run the check when the SHA differs, the verdict is not clean, or the field is absent. Keep the `superpowers:` prefix on the cross-link; built-in commands stay unprefixed if mentioned. Suggested text:
  > Each evidence field records the `commit` and `timestamp` of the run that produced it. A cached verdict (`test_results`, `code_review_verdict`, `security_review_status`) is valid only when its `commit` equals the current HEAD SHA. Any new commit invalidates every cached verdict. Downstream skills such as `superpowers:finishing-a-development-branch` re-run the corresponding check whenever the SHA differs, the verdict is not clean, or the field is missing. This schema is defined here once; other skills reference these field names and must not redefine them.

- [ ] **Step 3c: Add intermediate receipts/decision-packs to `## Do Not Reload`.**
  In the `## Do Not Reload` section of the Handoff Document template (the bulleted list under that heading, currently `Brainstorming transcript` / `Rejected approaches` / `Old draft plans` / `Tool logs unless needed for a blocker`), append two bullets:
  - `Intermediate review receipts and decision packs (read the saved file on resume, not the chat)`
  - `Per-task result files (docs/superpowers/runs/<run>/task-NNN-result.md) unless investigating a blocker`

- [ ] **Step 3d: Add the mid-task resume check to `## Resume Instructions`.**
  In the numbered list under `## Resume Instructions` (steps 1-5, currently ending `5. If state drifted, update the handoff before continuing.`), insert a new step BETWEEN current step 3 (`Check current git state against the handoff.`) and current step 4 (`Continue from Next Action.`), renumbering the rest:
  > If `current_task` is set in `state.json`, confirm the remaining work for that task before acting on Next Action.

- [ ] **Step 4: Verify all checks PASS + validate + cross-links intact.**
  - Re-run every grep from Step 1 → all expected outputs.
  - `claude plugin validate /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude` → green (no errors).
  - `grep -n 'superpowers:' plugins/superpowers-claude/skills/phase-handoff/SKILL.md` → existing cross-links plus the new `superpowers:finishing-a-development-branch` link present, none broken.
  - `grep -nE 'superpowers:(code-review|security-review|simplify|verify|run)' plugins/superpowers-claude/skills/phase-handoff/SKILL.md` → empty (built-ins stay unprefixed).
  - Confirm YAML frontmatter (lines 1-4: `name: phase-handoff`, `description:`) is unchanged.

- [ ] **Step 5: Commit.**
  - `git add plugins/superpowers-claude/skills/phase-handoff/SKILL.md`
  - `git commit -m "feat(phase-handoff): расширить схему state.json evidence-полями и добавить mid-task resume"`
