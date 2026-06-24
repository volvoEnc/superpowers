# Task 7: reviewing-plans — лимит ре-ревью, repo-контекст ревьюеру, coordinator-only fallback

**Risk:** medium
**Depends on:** none
**Review policy:** per-task-plus-risk
**Files:** Modify: `plugins/superpowers-claude/skills/reviewing-plans/SKILL.md`

Encodes spec items G, H, I for this file only:
- **G:** Re-review Rules — cap coordinator edit-and-re-review at **max 1 round per receipt**; new blocking issues on re-review → escalate (`human-decision-required`); non-blocking → note and proceed.
- **H:** Subagent Prompt Shape — add repo root + base branch + diff base + read-only note.
- **I:** Fallback → coordinator-only — replace permissive "repo files as source material" with lightweight guardrails (structure / contradiction-against-spec only, escalate); forbid inline repo inspection / snippet validation; escalate if reviewer subagent needed but Task unavailable.

All risk-tier / state-schema / review-doctrine concepts are single-sourced elsewhere — this task only references them, never redefines. Built-in commands stay WITHOUT `superpowers:` prefix (none are added here). Run all commands from repo root `/Users/danilka/llm-plugins/superpowers`.

---

## Steps

- [ ] **Step 1: Acceptance checks (define expected end-state).**
  After the edit, ALL of these must hold (run from repo root):
  - `grep -n "max 1 round" plugins/superpowers-claude/skills/reviewing-plans/SKILL.md` → matches the new Re-review cap.
  - `grep -n "human-decision-required" plugins/superpowers-claude/skills/reviewing-plans/SKILL.md` → matches the escalation outcome on new blocking issues.
  - `grep -n "base branch" plugins/superpowers-claude/skills/reviewing-plans/SKILL.md` → matches the new repo-context line in Subagent Prompt Shape.
  - `grep -n "git diff" plugins/superpowers-claude/skills/reviewing-plans/SKILL.md` → matches the read-only diff note in the prompt shape.
  - `grep -n "coordinator-only" plugins/superpowers-claude/skills/reviewing-plans/SKILL.md` → matches the tightened Fallback section.
  - `grep -n "repo files as source material" plugins/superpowers-claude/skills/reviewing-plans/SKILL.md` → returns **nothing** (permissive line removed).

  **Behavioral pressure-test (G — re-review loop):**
  - *Before:* Coordinator fixes a blocking issue, re-dispatches, the re-review surfaces a NEW blocking issue, coordinator fixes again, re-dispatches again… unbounded edit/re-review loop with no human gate.
  - *After:* Coordinator runs at most ONE edit-and-re-review round per receipt. If that re-review surfaces a new blocking issue, coordinator STOPS and escalates as `human-decision-required` instead of looping. Non-blocking issues on re-review are noted and execution proceeds.

  **Behavioral pressure-test (I — fallback):**
  - *Before:* Task tool unavailable → coordinator reads repo files itself and performs a full inline review (snippet/symbol validation, file audits) "as source material".
  - *After:* Task tool unavailable but a reviewer-subagent-class job (snippet/symbol/repo inspection) is needed → coordinator HARD-STOPS / escalates, never substitutes itself. Inline is permitted ONLY for lightweight coordinator-class checks (plan structure + contradiction-against-spec) and only on explicit human request.

- [ ] **Step 2: Verify the change currently FAILS (absent).**
  Run from repo root — confirm the new state is NOT yet present:
  - `grep -n "max 1 round" plugins/superpowers-claude/skills/reviewing-plans/SKILL.md` → no output.
  - `grep -n "base branch" plugins/superpowers-claude/skills/reviewing-plans/SKILL.md` → no output.
  - `grep -n "coordinator-only" plugins/superpowers-claude/skills/reviewing-plans/SKILL.md` → no output.
  - `grep -n "repo files as source material" plugins/superpowers-claude/skills/reviewing-plans/SKILL.md` → **one** match (the current permissive Fallback line at end of file, ~line 119). Confirms the line we will replace exists.

- [ ] **Step 3: Apply the edits.**

  **Edit 3a (H) — Subagent Prompt Shape.** Anchor: `## Subagent Prompt Shape`. In the fenced `text` block, the current `Inputs:` list ends with `- relevant repository files: <paths>` and the line `Do not use chat history.` appears just above. Add repo-context lines so the reviewer can read source and run `git diff` read-only. Replace this block:

  ```text
  You are reviewing a plan, not implementing code.
  Do not modify files.
  Do not use chat history.
  Inputs:
  - approved spec: <path>
  - context pack: <path>
  - plan: <path or directory>
  - relevant repository files: <paths>
  ```

  with:

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
  ```

  (Keep the rest of the block — the `Return a receipt only:` section — unchanged.)

  **Edit 3b (G) — Re-review Rules cap + escalation.** Anchor: `## Re-review Rules`. The section currently ends with the paragraph beginning `When only one section changed, re-review that section plus dependencies. Do not run the whole review carousel for typo-only edits.` Append a new cap paragraph immediately after that line:

  ```markdown
  Cap each receipt at **max 1 round** of coordinator edit-and-re-review. After you fix the issues from a receipt and re-dispatch once:

  - if the re-review surfaces a **new blocking issue**, stop and escalate as `human-decision-required` — do not start another edit/re-review round on the same receipt.
  - if the re-review surfaces only non-blocking (important/minor) issues, **note** them in the findings and proceed; they do not gate execution.

  Escalation outcomes follow the shared cycle-limit doctrine (see `superpowers:subagent-driven-development`): `approved-amended-plan` | `human-decision-required` | `task-removed`.
  ```

  **Edit 3c (I) — Fallback → coordinator-only.** Anchor: `## Fallback`. Replace the entire current Fallback body (the single paragraph starting `If subagents are unavailable or the human partner asks you to work inline...` and ending `...plan, and repo files as source material.`) with:

  ```markdown
  Inline review is **coordinator-only** and allowed **only when the human partner explicitly asks** to work inline — never as an automatic reaction to the Task tool being unavailable. Label it clearly as fallback mode.

  Inline fallback is limited to lightweight coordinator-class checks against the saved spec, context pack, and plan:

  - plan structure, placeholders, and obvious internal contradictions
  - contradiction of the plan against the approved spec

  The coordinator must **not** do reviewer-subagent-class work inline: no repo inspection, no snippet/symbol validation, no file audits, no `git diff` reading. That work goes to fresh read-only subagents.

  If reviewer-subagent-class work (snippet, symbol, or repo inspection) is needed but the Task tool is genuinely unavailable, **escalate / hard-stop** — do not perform it inline. The coordinator never substitutes itself for a subagent.
  ```

- [ ] **Step 4: Verify it PASSES + plugin validates + cross-links intact.**
  - Re-run every check from Step 1 — all pass; `repo files as source material` returns nothing.
  - `claude plugin validate /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude` → green (no errors).
  - Frontmatter intact: `head -4 plugins/superpowers-claude/skills/reviewing-plans/SKILL.md` → `name: reviewing-plans` / `description:` unchanged.
  - Cross-links intact: `grep -n "superpowers:" plugins/superpowers-claude/skills/reviewing-plans/SKILL.md` → includes the new `superpowers:subagent-driven-development` reference; no link was broken.
  - No built-in prefixed: `grep -rnE "superpowers:(code-review|security-review|simplify|verify|run)" plugins/superpowers-claude/skills/reviewing-plans/SKILL.md` → empty.

- [ ] **Step 5: Commit.**
  ```bash
  git add plugins/superpowers-claude/skills/reviewing-plans/SKILL.md
  git commit -m "feat(reviewing-plans): лимит 1 раунд ре-ревью с эскалацией, repo-контекст ревьюеру, coordinator-only fallback"
  ```
