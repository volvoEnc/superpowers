# Task 2: verification-before-completion — риск-тиры, шаблон доказательств, поведенческая верификация
**Risk:** medium
**Depends on:** none
**Review policy:** per-task-plus-risk
**Files:**
- Modify: plugins/superpowers-claude/skills/verification-before-completion/SKILL.md

Контекст (не перечитывать спек). Этот скил становится ЕДИНСТВЕННЫМ источником определения риск-тиров для `/security-review` — на него ссылаются `executing-plans` (task 007) и `finishing-a-development-branch` (task 004). Нельзя дублировать тиры в других скилах. Встроенные механизмы Claude Code (`/security-review`, `verify`, `run`) упоминаются БЕЗ префикса `superpowers:`. Текущий файл содержит якоря: `## The Iron Law`, `## Common Failures` (таблица), `## Red Flags - STOP`. Три правки кодируют spec-пункты 10 (риск-тиры), 11 (поведенческая верификация) и шаблон сбора доказательств.

- [ ] Step 1: Определить acceptance-проверку. После правок ВСЕ команды ниже дают указанный результат:
  - (a) Секция риск-тиров: `grep -n "## Security-Review Risk Tiers" plugins/superpowers-claude/skills/verification-before-completion/SKILL.md` → ровно 1 совпадение.
  - (b) Все три тира присутствуют: `grep -cE "Tier 1|Tier 2|Tier 3" plugins/superpowers-claude/skills/verification-before-completion/SKILL.md` → не менее 3.
  - (c) Правило смешанных изменений: `grep -n "highest applicable tier" plugins/superpowers-claude/skills/verification-before-completion/SKILL.md` → не менее 1 совпадения.
  - (d) Шаблон сбора доказательств: `grep -n "## Evidence Capture" plugins/superpowers-claude/skills/verification-before-completion/SKILL.md` → ровно 1 совпадение, и `grep -n "Tests pass \[34/34, exit 0\]" SKILL.md` → не менее 1.
  - (e) Поведенческая строка в таблице Common Failures: `grep -n "verify/run" plugins/superpowers-claude/skills/verification-before-completion/SKILL.md` → не менее 1 совпадения.
  - (f) Валидация плагина зелёная (см. Step 4).
  - (g) Pressure-test (см. Step 4): на сценарии «работа задела модуль аутентификации, тесты зелёные» скил должен указывать на обязательный `/security-review` (Tier 1).

- [ ] Step 2: Убедиться, что проверка СЕЙЧАС ПРОВАЛИВАЕТСЯ (секции/поведение отсутствуют). Выполнить:
  ```
  grep -nE "Security-Review Risk Tiers|Evidence Capture|verify/run|highest applicable tier" plugins/superpowers-claude/skills/verification-before-completion/SKILL.md
  ```
  Ожидаемо: НИ ОДНОГО совпадения (exit code 1). Это подтверждает, что ни риск-тиров, ни шаблона доказательств, ни строки про verify/run в файле пока нет (baseline для pressure-test: текущий скил молчит про `/security-review` на auth-изменениях).

- [ ] Step 3: Применить правки. Три вставки/изменения, якоря грунтованы на реальном текущем файле.

  **Правка 3a — секция риск-тиров.** Вставить СРАЗУ ПОСЛЕ блока `## The Iron Law` (то есть после строки `If you haven't run the verification command in this message, you cannot claim it passes.` и перед `## The Gate Function`). Вставить:

  ```markdown

  ## Security-Review Risk Tiers

  Single source of truth for when `/security-review` is required. Other skills (`executing-plans`, `finishing-a-development-branch`, `subagent-driven-development`) reference THIS section — do not redefine tiers elsewhere.

  | Tier | `/security-review` | Areas |
  |------|--------------------|-------|
  | **Tier 1** | **Mandatory** | auth/authz, cryptography, secrets, external API keys, shell execution, file permissions, SQL/DB mutations + DDL + data export |
  | **Tier 2** | Optional (judgment) | large refactors, configuration changes |
  | **Tier 3** | Skip | docs, UI text, tests-only |

  **Mixed changes:** apply the highest applicable tier — if a change touches any Tier-1 area, the whole change is Tier 1. SQL/DB: mutations, DDL, and export are Tier 1; pure read-only queries are not Tier 1 by default (escalate only if context warrants).

  *(Default proposal — your human partner confirms the list against their threat model.)*
  ```

  **Правка 3b — шаблон сбора доказательств.** Вставить СРАЗУ ПОСЛЕ блока `## Red Flags - STOP` (после строки `- **ANY wording implying success without having run verification**` и перед `## Rationalization Prevention`). Вставить:

  ```markdown

  ## Evidence Capture

  Before any completion claim, capture one tight evidence line with these fields:

  - **Test count + exit code** — e.g. `34/34, exit 0`
  - **Build status** — e.g. `clean` / `exit 0`
  - **Diff stats** — files/lines changed
  - **Review verdict** — `/code-review` outcome (critical count) when a review ran

  Example: `Tests pass [34/34, exit 0]. Build clean. Diff: 3 files +52/-7. Code review: 0 critical.`

  Each field is a claim — only include a field you actually ran the command for (see The Gate Function).
  ```

  **Правка 3c — строка поведенческой верификации в таблицу `## Common Failures`.** Текущая таблица оканчивается строкой:
  ```
  | Requirements met | Line-by-line checklist | Tests passing |
  ```
  Добавить НЕПОСРЕДСТВЕННО ПОСЛЕ неё новую строку:
  ```
  | Behavioral change works | verify/run skill: app exercised, behavior observed | Unit tests green |
  ```
  (Поведенческая верификация отделена от командной: для user-visible/поведенческих изменений нужен встроенный `verify`/`run`, не только тесты. Пропускать для доков и чистой логики.)

- [ ] Step 4: Убедиться, что проверка ТЕПЕРЬ ПРОХОДИТ.
  - Прогнать все grep из Step 1 (a)-(e); каждый даёт указанное число совпадений.
  - Фронтматтер цел: `head -5 plugins/superpowers-claude/skills/verification-before-completion/SKILL.md` → первые строки `---`, `name: verification-before-completion`, `description: ...`, `---`.
  - Кросс-ссылки целы: `grep -rn "superpowers:" plugins/superpowers-claude/skills/*/SKILL.md` — внутренние `superpowers:*` ссылки не пострадали; в трёх вставленных блоках НЕТ префикса `superpowers:` перед `/security-review`, `verify`, `run` (проверить: `grep -n "superpowers:/security-review\|superpowers: verify\|superpowers: run" SKILL.md` → 0 совпадений).
  - Валидация плагина: `claude plugin validate plugins/superpowers-claude` → зелёно (exit 0, без ошибок).
  - Pressure-test (behavior-shaping): в чистой сессии подать сценарий «Я закончил правку модуля логина (auth), юнит-тесты зелёные, готов коммитить» и убедиться, что скил направляет на `/security-review` как Tier-1-обязательный и требует evidence-строку. Сравнить с baseline из Step 2 (раньше скил про `/security-review` молчал). Зафиксировать before/after результат как доказательство срабатывания.

- [ ] Step 5: Коммит.
  ```
  git add plugins/superpowers-claude/skills/verification-before-completion/SKILL.md
  git commit -m "feat(verification): добавить риск-тиры, шаблон доказательств и поведенческую верификацию"
  ```
