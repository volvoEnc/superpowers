# Task 010: writing-skills — пред-деплой eval-гейт качества скила

**Risk:** low
**Depends on:** 001 (doctrine doc `review-integration-doctrine.md` должен существовать)
**Review policy:** per-task-plus-risk (поведение-формирующий скил → нужен pressure-test после правки)
**Files:**
- Modify: `plugins/superpowers-claude/skills/writing-skills/SKILL.md`

## Контекст (что и зачем)

Spec item 14 / acceptance criterion 7. В `writing-skills` после блока `## STOP: Before Moving to Next Skill` (строки 583-594 текущего файла) добавить короткую секцию **пред-деплой eval-гейт качества скила**:
1. прогнать `/code-review` по самому `SKILL.md` (логические противоречия / нестыковки / расплывчатые инструкции);
2. прогнать `/security-review`, если скил трогает auth / секреты / права;
3. минимум один адверсариальный pressure-test ПОСЛЕ правок, доказывающий, что задуманная лазейка закрыта; для правок СУЩЕСТВУЮЩИХ скилов — сначала прогнать исходный сценарий как baseline, потом с правкой.
4. Что игнорировать: если ревью жалуется, что скил «слишком строгий» — это может быть намеренно.

Секция короткая, ссылается на доктрину (`../../docs/review-integration-doctrine.md`), не дублирует её. `/code-review` и `/security-review` — встроенные механизмы Claude Code, упоминать БЕЗ префикса `superpowers:`. Не путать встроенный pressure-test с уже существующим в скиле — новая секция явно про шаг ПОСЛЕ правок и не переопределяет RED-GREEN-REFACTOR, а добавляет финальный гейт перед деплоем.

## Шаги

- [ ] **Step 1: Определить acceptance-check.** После правки секция должна находиться по заголовку. Команда:
  ```
  grep -n "## Pre-Deployment Skill-Quality Gate" plugins/superpowers-claude/skills/writing-skills/SKILL.md
  ```
  Ожидаемый результат после правки: ровно одна строка с номером и заголовком `## Pre-Deployment Skill-Quality Gate`.
  Дополнительно проверить наличие ключевых упоминаний внутри секции:
  ```
  grep -nE "/code-review|/security-review|adversarial|baseline" plugins/superpowers-claude/skills/writing-skills/SKILL.md
  ```
  Ожидается: совпадения на `/code-review`, `/security-review`, `adversarial`, `baseline` внутри новой секции (минимум 4 совпадения помимо прочего текста файла).

- [ ] **Step 2: Убедиться, что check сейчас ПАДАЕТ (секция отсутствует).** Команда:
  ```
  grep -n "## Pre-Deployment Skill-Quality Gate" plugins/superpowers-claude/skills/writing-skills/SKILL.md
  ```
  Ожидаемый результат ДО правки: пустой вывод, код возврата 1 (секции нет). Это подтверждает RED.

- [ ] **Step 3: Применить правку.** Вставить новую секцию СРАЗУ ПОСЛЕ блока `## STOP: Before Moving to Next Skill` и ПЕРЕД `## Skill Creation Checklist (TDD Adapted)`.

  Якорь — конец блока STOP, текущий текст (строки 583-594):
  ```markdown
  ## STOP: Before Moving to Next Skill

  **After writing ANY skill, you MUST STOP and complete the deployment process.**

  **Do NOT:**
  - Create multiple skills in batch without testing each
  - Move to next skill before current one is verified
  - Skip testing because "batching is more efficient"

  **The deployment checklist below is MANDATORY for EACH skill.**

  Deploying untested skills = deploying untested code. It's a violation of quality standards.
  ```

  Вставить ПОСЛЕ строки `Deploying untested skills = deploying untested code. It's a violation of quality standards.` и ПЕРЕД строкой `## Skill Creation Checklist (TDD Adapted)` следующий блок (целиком, дословно):

  ```markdown
  ## Pre-Deployment Skill-Quality Gate

  Before deploying a skill, run a final quality gate ON the `SKILL.md` itself — separate from the behavioral pressure-tests above:

  1. **`/code-review` on the SKILL.md** — catches logical inconsistencies, internal contradictions, and vague/ambiguous instructions in the prose. This is automated hygiene, not a substitute for testing behavior.
  2. **`/security-review` — only if the skill touches auth, secrets, or permissions** (e.g. the skill tells agents how to handle credentials, shell execution, or file access). Skip otherwise.
  3. **At least one adversarial pressure-test AFTER your edits**, proving the loophole you intended to close is actually closed. For edits to an EXISTING skill: re-run the original pressure scenario as a baseline FIRST (confirm the old behavior), then run it again WITH the edit (confirm the new behavior). A passing test on the edited skill alone proves nothing without the baseline.

  **What to ignore:** if `/code-review` complains a skill is "too strict," "too repetitive," or "over-constrained," that may be intentional — discipline-enforcing skills deliberately close loopholes and repeat counters. Apply judgment; do not relax behavior-shaping content just because automated review flagged it.

  `/code-review` and `/security-review` are Claude Code built-ins, not skills. For the full automated-hygiene-vs-judgment model and the risk-tier definition that decides when `/security-review` applies, see the review integration doctrine: `../../docs/review-integration-doctrine.md`.
  ```

  Использовать инструмент Edit: `old_string` = строка `Deploying untested skills = deploying untested code. It's a violation of quality standards.` плюс следующая пустая строка плюс `## Skill Creation Checklist (TDD Adapted)`; `new_string` = та же первая строка + новая секция целиком + `## Skill Creation Checklist (TDD Adapted)`. Это гарантирует точное место вставки между двумя якорными заголовками.

- [ ] **Step 4: Проверить, что check теперь ПРОХОДИТ.**
  - Acceptance-grep из Step 1 возвращает ровно одну строку с `## Pre-Deployment Skill-Quality Gate`; второй grep находит `/code-review`, `/security-review`, `adversarial`, `baseline`.
  - Фронтматтер цел (name/description первыми):
    ```
    head -4 plugins/superpowers-claude/skills/writing-skills/SKILL.md
    ```
    Ожидается: строки `---`, `name: writing-skills`, `description: Use when creating new skills...`, `---`.
  - Валидация плагина зелёная:
    ```
    claude plugin validate plugins/superpowers-claude
    ```
    Ожидается: успешный вывод без ошибок.
  - Кросс-ссылки `superpowers:*` целы (правка ни одну не трогает):
    ```
    grep -n "superpowers:" plugins/superpowers-claude/skills/writing-skills/SKILL.md
    ```
    Ожидается: прежние совпадения (`superpowers:test-driven-development`, `superpowers:systematic-debugging`) на месте, новых `superpowers:`-префиксов у `/code-review` / `/security-review` НЕТ.
  - Ссылка на доктрину резолвится (файл существует, создан задачей 001):
    ```
    test -f plugins/superpowers-claude/docs/review-integration-doctrine.md && echo OK
    ```
    Ожидается: `OK`.
  - Pressure-test (поведенческий, для behavior-shaping правки): в свежей сессии дать субагенту сценарий «отредактируй существующий скил X, добавив правило, и сразу задеплой». ДО правки baseline: агент деплоит без финального `/code-review` по SKILL.md и без повторного baseline-сценария. ПОСЛЕ правки: агент, прочитав `writing-skills`, прогоняет `/code-review` по SKILL.md, повторяет исходный pressure-сценарий как baseline и только потом деплоит. Зафиксировать before/after как доказательство срабатывания гейта.

- [ ] **Step 5: Commit.**
  ```
  git add plugins/superpowers-claude/skills/writing-skills/SKILL.md
  git commit -m "feat(writing-skills): добавить пред-деплой eval-гейт качества скила"
  ```
