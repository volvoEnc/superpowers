# Task 4: executing-plans — durable state, авто-security, тест-фейл лимиты, load-and-discard, риск-тир в finishing

**Risk:** high
**Depends on:** 001 (phase-handoff определяет схему `state.json`), 006 (verification-before-completion пишет evidence — для согласованности ссылок). Если 006 ещё не готов на момент исполнения — ссылку на риск-тиры всё равно делаем (секция уже существует в текущем файле), порядок коммитов не блокирует.
**Review policy:** per-task-plus-risk
**Files:** Modify: `plugins/superpowers-claude/skills/executing-plans/SKILL.md`

Кодирует пункты спеки C, E, G, J, K (см. `docs/superpowers/specs/2026-06-24-post-spec-autonomy-design.md`, scope-карта в `docs/superpowers/plans/2026-06-24-post-spec-autonomy/context-pack.md`).

ВАЖНО — единые источники (не переопределять, ссылаться по имени):
- Схема `state.json` — определена ОДИН раз в `superpowers:phase-handoff`, секция "## State JSON". Поля (контракт из context-pack): `current_task`, `completed_tasks`, `blocked_tasks`, `last_green_commit`, `plan_risk_tier`, `test_results`, `code_review_verdict`, `security_review_status`.
- Риск-тиры — определены ОДИН раз в `superpowers:verification-before-completion`, секция "## Security-Review Risk Tiers".
- Встроенные `/security-review`, `systematic-debugging` (это superpowers-скил → `superpowers:systematic-debugging`); `/security-review` — БЕЗ префикса `superpowers:`.

Все команды запускать из корня репо `/Users/danilka/llm-plugins/superpowers`.

---

## Шаги

- [ ] **Step 1: Acceptance-проверки (зафиксировать целевое состояние).**
  После всех правок должны проходить:
  - (C) `grep -n "Maintaining Execution State" plugins/superpowers-claude/skills/executing-plans/SKILL.md` → ≥1 совпадение; в этой секции есть ссылка `superpowers:phase-handoff` и упоминание `state.json` + `last_green_commit`.
  - (E) `grep -n "auto-run\|/security-review" plugins/superpowers-claude/skills/executing-plans/SKILL.md` → есть авто-ран; `grep -in "ask your human partner for approval to run" plugins/superpowers-claude/skills/executing-plans/SKILL.md` → ПУСТО (гейт approval убран).
  - (E) `grep -in "block only on unresolved critical\|human-decision-required" plugins/superpowers-claude/skills/executing-plans/SKILL.md` → есть.
  - (G) `grep -in "flake\|systematic-debugging\|re-run" plugins/superpowers-claude/skills/executing-plans/SKILL.md` → есть в секции "When to Stop".
  - (J) `grep -in "load-and-discard\|discard after\|only this task" plugins/superpowers-claude/skills/executing-plans/SKILL.md` → есть.
  - (K) `grep -in "plan_risk_tier\|plan risk:" plugins/superpowers-claude/skills/executing-plans/SKILL.md` → есть в Step 3.
  - Префикс встроенных корректен: `grep -nE "superpowers:(code-review|security-review|simplify|verify|run)" plugins/superpowers-claude/skills/executing-plans/SKILL.md` → ПУСТО.

  **Behavioral pressure-test (поведение-формирующие правки E, G):**
  - Сценарий E (before): «Завершил Tier-1 задачу. По текущему скилу: останавливаюсь и спрашиваю человека разрешение запустить /security-review» → нарушает автономность.
  - Сценарий E (after, целевое): «Завершил Tier-1 задачу → автоматически запускаю `/security-review` на накопленном диффе, без вопроса человеку. Critical → автономный fix (1 цикл) → ре-ран; critical остаётся → эскалация `human-decision-required`; блокируюсь ТОЛЬКО на нерешённых critical».
  - Сценарий G (before): «Тест упал второй раз → "test fails repeatedly" → останавливаюсь и спрашиваю» → теряем автономный bounded-retry.
  - Сценарий G (after, целевое): «Тест упал → 1 ре-ран (вдруг флаки); упал снова → 1 ограниченный fix-and-retest через `superpowers:systematic-debugging`; всё ещё красный → эскалация. Не зацикливаюсь».

- [ ] **Step 2: Verify FAILS сейчас (правки отсутствуют).**
  - `grep -c "Maintaining Execution State" plugins/superpowers-claude/skills/executing-plans/SKILL.md` → `0`.
  - `grep -in "ask your human partner for approval to run" plugins/superpowers-claude/skills/executing-plans/SKILL.md` → совпадение есть (старый гейт, строка ~37).
  - `grep -ic "systematic-debugging\|flake\|load-and-discard" plugins/superpowers-claude/skills/executing-plans/SKILL.md` → `0`.
  Подтверждает, что секции/поведение пока отсутствуют.

- [ ] **Step 3: Применить правки.** Четыре точечные правки в `plugins/superpowers-claude/skills/executing-plans/SKILL.md`.

  **(3a) [J] Step 1 — load-and-discard + новая секция "Maintaining Execution State" [C].**
  Якорь — текущая секция `## Step 1: Load and Review Plan` (строки 16–21), точный текущий текст:
  ```
  ## Step 1: Load and Review Plan

  1. Read the plan file.
  2. Review critically and identify questions or concerns.
  3. If concerns exist, raise them before starting.
  4. If no concerns exist, create TodoWrite and proceed.
  ```
  Заменить ПУНКТ 4 на расширенный (load-and-discard) и СРАЗУ ПОСЛЕ секции вставить новую секцию состояния:
  ```
  4. If no concerns exist, create TodoWrite and proceed. **Then discard the full plan body from context — keep only the overview (title / goal / risk tier) and the ordered task list.** Read each task file from disk at the start of its cycle in Step 2, and discard that task's text once its result receipt is captured. Never hold more than one task body in context at a time ("load-and-discard").

  ## Maintaining Execution State

  Write `state.json` after each task so the run survives a compact and is resumable.

  - The schema is defined once in `superpowers:phase-handoff` (section "State JSON"). Do not redefine fields here — reference it. Use the exact field names: `current_task`, `completed_tasks`, `blocked_tasks`, `last_green_commit` (plus the evidence fields `plan_risk_tier`, `test_results`, `code_review_verdict`, `security_review_status` written by `superpowers:verification-before-completion`).
  - After each task: update `current_task` → next, append to `completed_tasks`, set `last_green_commit` to the last commit whose verification passed. On a blocked task, append to `blocked_tasks` instead.
  - After verifications run, refresh the evidence fields per `superpowers:verification-before-completion` rather than restating verdicts in chat.
  - On resume after a compact, rebuild from `state.json` on disk, not from the chat transcript.
  ```

  **(3b) [E] Step 2a — убрать гейт approval, авто-ран `/security-review`, critical fix-цикл, эскалация.**
  Якорь — секция `## Step 2a: Security Risk Check Before Handoff`. Заменить весь текущий нумерованный список (текущие пункты 1–4, строки 36–39). Сохранить пункт 1 (ссылка на риск-тиры — единый источник), переписать 2, обновить 3, перенести смысл "pass forward" в Step 3 (см. 3d). Новый текст пунктов:
  ```
  1. Re-read the plan's per-task risk assessment. Determine whether any completed task touched a **Tier-1** area. Tier-1 is defined once in `superpowers:verification-before-completion` → section "Security-Review Risk Tiers". Do not redefine the list here — consult that section.
  2. **If any task was Tier-1: auto-run `/security-review` on the accumulated branch diff — no human approval gate.** `/security-review` is a Claude Code built-in (no `superpowers:` prefix). Then handle the verdict:
     - No critical findings → record `security_review_status` clean in `state.json` and continue.
     - Critical findings → attempt one autonomous fix cycle (bounded by the same retry limits as the per-task loop — see `superpowers:subagent-driven-development`), then re-run `/security-review` once.
     - If critical findings persist after the fix-and-re-run cycle → **escalate** (`human-decision-required`); record `security_review_status` as `critical-open`. **Block handoff only on unresolved critical findings** — never on non-critical findings.
  3. **If no task was Tier-1:** record "plan risk: not Tier-1, /security-review not required" in `state.json` and continue.
  ```

  **(3c) [G] "When to Stop" — определить test-fail handling (bounded retry, потом эскалация).**
  Якорь — секция `## When to Stop and Ask for Help` (строки 49–59), текущий пункт `- A test fails repeatedly.`. Заменить ТОЛЬКО эту строку на bounded-политику:
  ```
  - A test fails: first re-run it once (in case of flake). If it fails again, run **one** bounded fix-and-retest cycle via `superpowers:systematic-debugging`. If it still fails after that cycle, escalate (`human-decision-required`) — do not loop further.
  ```
  Остальные пункты ("A dependency is missing", "An instruction is unclear", "The plan has critical gaps", "You do not understand the next step") оставить без изменений.

  **(3d) [K] Step 3 — передать риск-тир в finishing явно.**
  Якорь — секция `## Step 3: Complete Development` (строки 41–47). Текущий маркированный список:
  ```
  - Announce: "I'm using the finishing-a-development-branch skill to complete this work."
  - **REQUIRED SUB-SKILL:** Use superpowers:finishing-a-development-branch.
  - Follow that skill to verify tests, present options, and execute the selected choice.
  ```
  Добавить ПОСЛЕ второго маркера новый пункт (между REQUIRED SUB-SKILL и "Follow that skill"):
  ```
  - **Pass the plan risk tier explicitly.** State the `plan_risk_tier` from `state.json` when invoking finishing (e.g. "plan risk: Tier-1, /security-review run and clean" or "plan risk: not Tier-1") so finishing uses the passed tier instead of re-deriving it.
  ```
  (Текущий Step 2a пункт 4 "Pass the risk assessment forward" уже заменён в 3b — смысл переезжает сюда, дублирования нет.)

- [ ] **Step 4: Verify PASSES + структурная валидация.**
  - Прогнать все grep из Step 1 — ожидаемые результаты совпадают.
  - `grep -in "ask your human partner for approval to run" plugins/superpowers-claude/skills/executing-plans/SKILL.md` → ПУСТО (гейт удалён).
  - Фронтматтер цел: первая строка файла `---`, есть `name: executing-plans` и `description:`.
  - Кросс-ссылки целы: `grep -n "superpowers:" plugins/superpowers-claude/skills/executing-plans/SKILL.md` → присутствуют `superpowers:phase-handoff`, `superpowers:verification-before-completion`, `superpowers:systematic-debugging`, `superpowers:subagent-driven-development`, `superpowers:using-git-branches`, `superpowers:finishing-a-development-branch`, `superpowers:writing-plans` (секция Integration не сломана).
  - Префикс встроенных: `grep -nE "superpowers:(code-review|security-review|simplify|verify|run)" plugins/superpowers-claude/skills/executing-plans/SKILL.md` → ПУСТО.
  - `claude plugin validate /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude` → зелёный.
  - Перечитать диалог сценариев из Step 1 against итоговый текст — поведение after зафиксировано в прозе.

- [ ] **Step 5: Commit.**
  ```
  git add plugins/superpowers-claude/skills/executing-plans/SKILL.md
  git commit -m "feat(executing-plans): автономный security-ран, durable state, лимиты тест-фейлов и load-and-discard

  - Step 1: load-and-discard плана + новая секция Maintaining Execution State (ссылка на схему phase-handoff)
  - Step 2a: убран гейт approval, авто-ран /security-review при Tier-1, fix-цикл и эскалация на нерешённых critical
  - When to Stop: bounded test-fail (1 ре-ран флаки + 1 fix-and-retest через systematic-debugging, затем эскалация)
  - Step 3: явная передача plan_risk_tier в finishing"
  ```
