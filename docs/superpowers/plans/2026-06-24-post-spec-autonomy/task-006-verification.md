# Task 6: verification-before-completion — писать evidence в state.json (Spec D, write side)

**Risk:** medium
**Depends on:** 001 (phase-handoff определяет схему `state.json` с полями `plan_risk_tier`, `test_results`, `code_review_verdict`, `security_review_status`)
**Review policy:** per-task-plus-risk
**Files:** Modify: `plugins/superpowers-claude/skills/verification-before-completion/SKILL.md`

Контекст: Spec D (write side) + context-pack File→Scope map (строка 31: `verification-before-completion/SKILL.md → D (писать evidence в state.json)`).
Сейчас секция `## Evidence Capture` (строки 78-89) пишет evidence только как «одну тугую строку» в контекст. Нужно дополнительно инструктировать писать структурированный evidence в `state.json` по полям схемы `phase-handoff` (`test_results`, `code_review_verdict`, `security_review_status`, `plan_risk_tier`), каждое со штампом текущего commit SHA, чтобы `finishing` (task 008) мог прочитать и SHA-сверить кеш. Схему НЕ переопределять — только ссылка на `superpowers:phase-handoff`.

Поведенческий pressure-test (before/after): сценарий — субагент верификации прогнал тесты `34/34, exit 0` на коммите `abc123` и собирается отчитаться.
- BEFORE: агент пишет только tight-строку в контекст; `finishing` позже не находит durable evidence, перезапускает все ревью с нуля.
- AFTER: агент ДОПОЛНИТЕЛЬНО записывает `test_results {summary,exit_code,commit,timestamp}` в `state.json` со штампом `commit: abc123`; `finishing` читает запись, сверяет `commit` с HEAD, при совпадении кеширует `cached: clean`.

## Steps

- [ ] Step 1: Acceptance check (запускать из корня репо `/Users/danilka/llm-plugins/superpowers`).
  - Структурный: `grep -n "state.json" plugins/superpowers-claude/skills/verification-before-completion/SKILL.md` → минимум 1 совпадение внутри секции `## Evidence Capture`.
  - Структурный: `grep -nE "superpowers:phase-handoff" plugins/superpowers-claude/skills/verification-before-completion/SKILL.md` → минимум 1 совпадение (ссылка на единый источник схемы).
  - Структурный: `grep -nE "test_results|code_review_verdict|security_review_status|plan_risk_tier" plugins/superpowers-claude/skills/verification-before-completion/SKILL.md` → присутствуют все четыре имени поля (точно как в context-pack контракте).
  - Структурный (без переопределения схемы): новый текст НЕ содержит JSON-блока с определением полей — только перечисление имён + ссылка. Проверка вручную: в секции `## Evidence Capture` нет ```` ```json ```` блока.
  - Поведенческий pressure-test: см. before/after выше — после правки текст явно требует записать evidence в `state.json` со штампом commit SHA, а не только в контекст.

- [ ] Step 2: Verify it currently FAILS (отсутствует).
  - `grep -c "state.json" plugins/superpowers-claude/skills/verification-before-completion/SKILL.md` → ожидаемо `0` (сейчас секция Evidence Capture пишет только tight-строку в контекст, durable-записи нет).
  - `grep -c "phase-handoff" plugins/superpowers-claude/skills/verification-before-completion/SKILL.md` → ожидаемо `0`.

- [ ] Step 3: Apply edit.
  - Anchor: секция `## Evidence Capture` (строки 78-89). Сохранить существующий текст про «одну тугую строку» и пример `Tests pass [34/34, exit 0]. Build clean. ...` и строку про «Each field is a claim».
  - Вставить после строки `Each field is a claim — only include a field you actually ran the command for (see The Gate Function).` (последняя строка секции перед `## Rationalization Prevention`) новый подраздел:

    ```
    ### Persist evidence to durable state

    The tight line goes in your context. **Additionally, write the structured evidence into `state.json`** so downstream skills (`finishing-a-development-branch`) can read it without re-running anything. Use the shared schema fields defined in `superpowers:phase-handoff` — do not redefine the schema here:

    - `test_results` — when you ran the test command (summary, exit_code).
    - `code_review_verdict` — when `/code-review` ran (verdict, effort).
    - `security_review_status` — when `/security-review` ran or was decided n/a (required, verdict).
    - `plan_risk_tier` — the tier from the Security-Review Risk Tiers table above, if known.

    **Stamp each record with the current commit SHA** (`git rev-parse HEAD`) in its `commit` field, plus a `timestamp`. The SHA stamp is load-bearing: `finishing` SHA-validates each cached verdict against HEAD — matching SHA + clean verdict → skip the re-review; differing SHA → re-run. Write only fields you actually verified (a record is a claim — same rule as the tight line).
    ```

  - Не трогать YAML frontmatter (строки 1-4), `## Security-Review Risk Tiers` (single source — оставить как есть), прочие секции.
  - Использовать встроенные `/code-review` и `/security-review` БЕЗ префикса `superpowers:`.

- [ ] Step 4: Verify it PASSES + validate + cross-links.
  - Повторить все grep из Step 1 → проходят.
  - Cross-link цел/добавлен: `grep -nE "superpowers:(phase-handoff|finishing-a-development-branch)" plugins/superpowers-claude/skills/verification-before-completion/SKILL.md`.
  - Встроенные без префикса: `grep -nE "superpowers:(code-review|security-review|simplify|verify|run)" plugins/superpowers-claude/skills/verification-before-completion/SKILL.md` → пусто (exit 1).
  - Risk-tier single source цел: `grep -n "## Security-Review Risk Tiers" plugins/superpowers-claude/skills/verification-before-completion/SKILL.md` → 1 совпадение, секция не дублирована.
  - Frontmatter цел: `head -4 plugins/superpowers-claude/skills/verification-before-completion/SKILL.md` начинается с `---` / `name: verification-before-completion`.
  - Validate зелёный: `claude plugin validate /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude`.

- [ ] Step 5: Commit.
  - `git add plugins/superpowers-claude/skills/verification-before-completion/SKILL.md`
  - `git commit -m "feat(verification): писать структурированный evidence в state.json со штампом commit SHA"`
