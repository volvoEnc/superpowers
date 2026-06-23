# Task 6: Вшить риск-тированное встроенное ревью в per-task цикл subagent-driven-development
**Risk:** medium
**Depends on:** 001, 002
**Review policy:** per-task-plus-risk
**Files:**
- Modify: `plugins/superpowers-claude/skills/subagent-driven-development/SKILL.md`

## Контекст (самодостаточно — не требует перечитывания спека)

Spec item 12. В per-task цикле `subagent-driven-development` нужно явно развести две роли ревью:
- **Механическое качество** (баги, мёртвый код, стиль, рефактор-гигиена) → встроенные Claude Code механизмы `/code-review` и `/simplify`. Это **дефолт** для механики.
- **Суждение** (реализует ли код спек? архитектура, намерение, домен) → ручные субагенты через Task tool (spec reviewer + quality reviewer). Остаются.

Изменения:
1. Сохранить spec reviewer как есть (шаги 6-8, роль «does it implement the spec?»).
2. Сохранить quality reviewer (шаги 9-11) — но уточнить: ручной quality reviewer делает **суждение**, а механическое качество теперь покрывает встроенное `/code-review`.
3. После quality review запускать `/code-review` (low effort, по живому диффу задачи) для механических находок + `/simplify` для рефактор-чистки.
4. `/security-review` — только если задача помечена Tier-1 (ссылка на риск-тиры из `verification-before-completion`, НЕ переопределять их здесь).
5. Опционально-по-риску: для крупных планов не жечь бюджет — встроенное ревью применяется по риску задачи, не на каждую тривиальную.
6. Встроенное ревью **заменяет только механико-качественную роль**, не роль суждения.

Жёсткие ограничения:
- `/code-review`, `/simplify`, `/security-review` — это **встроенные** механизмы Claude Code. Ссылаться как `/code-review` и т.п., **БЕЗ** префикса `superpowers:`.
- Доктрина: `plugins/superpowers-claude/docs/review-integration-doctrine.md` (создана task 001). Из этого SKILL.md относительный путь — `../../docs/review-integration-doctrine.md`. Ссылаться, не дублировать.
- Риск-тиры определены ОДИН раз в `superpowers:verification-before-completion` (секция «Security-Review Risk Tiers», task 002). Ссылаться, не переопределять.
- Не ломать существующие `superpowers:` кросс-ссылки: `superpowers:test-driven-development`, `superpowers:requesting-code-review`, `superpowers:finishing-a-development-branch`, `superpowers:using-git-branches`, `superpowers:writing-plans`.
- Не раздувать: вшить тонко, длинные правила — ссылкой на доктрину.

## Шаги

- [ ] Step 1: Определить acceptance-проверку. После правки в файле должна появиться вставка built-in ревью в per-task цикл со ссылкой на доктрину и на риск-тиры. Точная команда:
  ```
  grep -nE "/code-review|/simplify|/security-review|review-integration-doctrine\.md|Security-Review Risk Tiers" plugins/superpowers-claude/skills/subagent-driven-development/SKILL.md
  ```
  Ожидаемый результат: ненулевой вывод, минимум по одной строке на каждый паттерн: `/code-review` (low), `/simplify`, `/security-review` (Tier-1), относительный путь `../../docs/review-integration-doctrine.md`, и упоминание риск-тиров со ссылкой на `superpowers:verification-before-completion`.

- [ ] Step 2: Убедиться, что проверка сейчас ПРОВАЛИВАЕТСЯ (секции/поведения нет). Команда:
  ```
  grep -nE "/code-review|/simplify|/security-review|review-integration-doctrine" plugins/superpowers-claude/skills/subagent-driven-development/SKILL.md
  ```
  Ожидаемый результат: пустой вывод (exit code 1) — в текущем файле этих упоминаний нет.

- [ ] Step 3: Применить правку. В файле `subagent-driven-development/SKILL.md` секция `## Per-Task Loop` сейчас оканчивается строкой:
  > `After all tasks, dispatch a final reviewer, capture its result, then use \`superpowers:finishing-a-development-branch\`.`
  И перед ней идёт нумерованный список, заканчивающийся шагом:
  > `12. Mark the task complete only when reviews pass.`

  3a. Заменить шаг 12 нумерованного списка, добавив встроенное ревью между quality review и завершением. Найти точную строку:
  ```
  12. Mark the task complete only when reviews pass.
  ```
  и заменить на:
  ```
  12. After quality review passes, run built-in mechanical review on the live task diff (see "Built-In Review In The Loop" below).
  13. Mark the task complete only when manual reviews pass and built-in review findings are resolved (or consciously deferred).
  ```

  3b. Вставить новую секцию СРАЗУ ПОСЛЕ блока `## Per-Task Loop` (то есть после строки `After all tasks, dispatch a final reviewer, capture its result, then use \`superpowers:finishing-a-development-branch\`.` и пустой строки за ней), ПЕРЕД секцией `## Handling Status`. Точный якорь для вставки — строка `## Handling Status`; вставить новую секцию непосредственно перед ней. Содержимое для вставки:

  ```markdown
  ## Built-In Review In The Loop

  Split review by role. Manual subagents make **judgment** calls; built-in tools handle **mechanical quality**.

  | Role | Who | Looks for |
  |------|-----|-----------|
  | Spec review (judgment) | manual subagent (Task tool) | Does it implement the spec? Intent, scope, domain correctness. |
  | Quality review (judgment) | manual subagent (Task tool) | Architecture, design fit, maintainability decisions. |
  | Mechanical quality (default) | built-in `/code-review` + `/simplify` | Bugs, dead code, style; reuse and refactor cleanup. |
  | Security gate (risk-tiered) | built-in `/security-review` | Tier-1 tasks only. |

  Built-in tools **replace the mechanical-quality role only** — they do not replace the judgment of manual spec/quality reviewers.

  After the quality reviewer passes, on the live diff for that task:

  1. Run `/code-review` at **low** effort for mechanical issues.
  2. Run `/simplify` for refactor cleanup (quality only — it does not hunt for bugs; `/code-review` does that).
  3. If the task touches **Tier-1** areas, run `/security-review`. Tiers are defined once in `superpowers:verification-before-completion` ("Security-Review Risk Tiers") — do not redefine them here.
  4. Resolve findings (or consciously defer) before marking the task complete.

  **Optional by risk.** Built-in review is the default for mechanical quality, but apply it per task risk so large plans don't blow the budget: skip it on trivial Tier-3 tasks (docs, UI text, tests-only); always run it on risky or Tier-1 tasks. When skipped, note `NOT-APPLICABLE` for the task.

  See `../../docs/review-integration-doctrine.md` for the full automation-vs-judgment model, the effort ladder, and the conflict-precedence rule.
  ```

  3c. В секции `## Integration` под «Required workflow skills» список заканчивается строкой `- \`superpowers:finishing-a-development-branch\``, далее идёт строка про TDD. Дополнить блок Integration, добавив ссылку на доктрину. Найти финальную строку файла:
  ```
  Subagents should follow `superpowers:test-driven-development` when a task requires implementation work.
  ```
  и заменить на:
  ```
  Subagents should follow `superpowers:test-driven-development` when a task requires implementation work.

  Built-in review (`/code-review`, `/simplify`, `/security-review`) follows the doctrine in `../../docs/review-integration-doctrine.md`; risk tiers come from `superpowers:verification-before-completion`.
  ```

- [ ] Step 4: Проверить, что проверка теперь ПРОХОДИТ.
  4a. Команда из Step 1:
  ```
  grep -nE "/code-review|/simplify|/security-review|review-integration-doctrine\.md|Security-Review Risk Tiers" plugins/superpowers-claude/skills/subagent-driven-development/SKILL.md
  ```
  Ожидаемо: строки с `/code-review` (low effort), `/simplify`, `/security-review` (Tier-1), `../../docs/review-integration-doctrine.md`, и «Security-Review Risk Tiers».
  4a-bis. Целевой файл доктрины существует (ссылка не висячая):
  ```
  test -f plugins/superpowers-claude/docs/review-integration-doctrine.md && echo OK
  ```
  Ожидаемо: `OK` (иначе сначала выполнить task 001).
  4b. Валидатор плагина зелёный:
  ```
  claude plugin validate plugins/superpowers-claude
  ```
  Ожидаемо: статус valid / без ошибок.
  4c. Фронтматтер цел (name/description первыми):
  ```
  head -5 plugins/superpowers-claude/skills/subagent-driven-development/SKILL.md
  ```
  Ожидаемо: первые строки — `---`, `name: subagent-driven-development`, `description: ...`, `---`.
  4d. Кросс-ссылки `superpowers:*` целы (ни одна не получила случайного префикса у built-in, ни одна старая не пропала):
  ```
  grep -nE "superpowers:(test-driven-development|requesting-code-review|finishing-a-development-branch|using-git-branches|writing-plans|verification-before-completion)" plugins/superpowers-claude/skills/subagent-driven-development/SKILL.md
  ```
  Ожидаемо: все шесть ссылок присутствуют. И проверка, что built-in механизмы НЕ получили префикс:
  ```
  grep -nE "superpowers:(code-review|simplify|security-review)" plugins/superpowers-claude/skills/subagent-driven-development/SKILL.md
  ```
  Ожидаемо: пустой вывод (exit code 1).
  4e. Pressure-test (поведенческий, до/после). Сценарий: «Выполняю план из 5 задач; задача 3 трогает auth-токены». Baseline (до правки) — модель завершает задачу 3 только по ручным spec+quality ревью, без built-in `/security-review`. После правки — модель в per-task цикле задачи 3 распознаёт Tier-1, запускает `/code-review` low + `/simplify` и `/security-review`, а на тривиальной задаче 5 (правка README) помечает built-in ревью `NOT-APPLICABLE`. Зафиксировать, что новое поведение срабатывает (риск-тированность + опциональность по риску).

- [ ] Step 5: Коммит.
  ```
  git add plugins/superpowers-claude/skills/subagent-driven-development/SKILL.md
  git commit -m "feat(subagent-driven-development): риск-тированное встроенное ревью в per-task цикле"
  ```
