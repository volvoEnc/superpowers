# Task 4: Гейт `/code-review` (+ Tier-1 `/security-review`) в finishing-a-development-branch
**Risk:** medium
**Depends on:** 001 (doctrine doc), 002 (Security-Review Risk Tiers в verification-before-completion)
**Review policy:** per-task-plus-risk
**Files:**
- Modify: `plugins/superpowers-claude/skills/finishing-a-development-branch/SKILL.md`

## Контекст (самодостаточно, не нужно перечитывать спек)

Скил `finishing-a-development-branch` сейчас идёт: `## Step 1: Verify Tests` → `## Step 2: Detect Branch State` → `## Step 3: Determine Base Branch` → `## Step 4: Present Options` → `## Step 5: Execute Choice` → `## Red Flags`.

Нужно вставить **новый шаг ревью между Step 1 и Step 2**: после прохождения тестов прогнать `/code-review` (medium effort) по диффу ветки. Критичные находки → стоп и фикс ДО показа меню опций; минорные → отметить в преамбуле меню. Дополнительно — `/security-review`, если ветка задела Tier-1 области (определение Tier-1 живёт в `verification-before-completion`, секция `## Security-Review Risk Tiers`; НЕ переопределять здесь, только ссылаться). Результат ревью выводится в преамбулу меню (Step 4).

ЖЁСТКИЕ ОГРАНИЧЕНИЯ:
- `/code-review` и `/security-review` — **встроенные** механизмы Claude Code. Писать ровно так: `/code-review`, `/security-review`. НИКОГДА не префиксовать `superpowers:`.
- Ссылаться на доктрину относительным путём `../../docs/review-integration-doctrine.md` (создаётся task 001).
- Риск-тиры — ссылка на секцию `## Security-Review Risk Tiers` в `verification-before-completion` (task 002). НЕ копировать список Tier-1 сюда.
- Сохранить чистый-контекст оркестратора и адаптивность: на изменениях вне Tier-1 `/security-review` пропускается.
- НЕ ломать YAML-фронтматтер (`name`, `description` остаются первыми).
- Перенумеровать последующие шаги: текущие Step 2..5 становятся Step 3..6, и обновить внутренние упоминания «Step N» если есть.

## Шаги

- [ ] **Step 1: Определить acceptance-проверку.** После правки должны проходить все команды:
  1. Новая секция существует:
     ```bash
     grep -n "## Step 2: Code Review Gate" plugins/superpowers-claude/skills/finishing-a-development-branch/SKILL.md
     ```
     Ожидаемо: ровно одна строка с заголовком `## Step 2: Code Review Gate`.
  2. Встроенные механизмы упомянуты без префикса:
     ```bash
     grep -n "/code-review\|/security-review" plugins/superpowers-claude/skills/finishing-a-development-branch/SKILL.md
     ```
     Ожидаемо: минимум 2 совпадения; ни одно не содержит `superpowers:/code-review`.
  3. Нет ошибочного префикса:
     ```bash
     grep -n "superpowers:/code-review\|superpowers:/security-review" plugins/superpowers-claude/skills/finishing-a-development-branch/SKILL.md
     ```
     Ожидаемо: пусто (exit code 1).
  4. Ссылки на доктрину и риск-тиры присутствуют:
     ```bash
     grep -n "review-integration-doctrine.md\|Security-Review Risk Tiers" plugins/superpowers-claude/skills/finishing-a-development-branch/SKILL.md
     ```
     Ожидаемо: минимум 2 совпадения (ссылка на доктрину + ссылка на секцию риск-тиров).
  5. Перенумерация: заголовки шагов идут 1..6 без дублей:
     ```bash
     grep -n "^## Step " plugins/superpowers-claude/skills/finishing-a-development-branch/SKILL.md
     ```
     Ожидаемо: ровно 6 строк — Step 1: Verify Tests, Step 2: Code Review Gate, Step 3: Detect Branch State, Step 4: Determine Base Branch, Step 5: Present Options, Step 6: Execute Choice.
  6. Валидация плагина:
     ```bash
     claude plugin validate plugins/superpowers-claude
     ```
     Ожидаемо: зелёный (valid).

- [ ] **Step 2: Убедиться, что проверка СЕЙЧАС ПАДАЕТ (секция отсутствует).** Выполнить:
  ```bash
  grep -n "## Step 2: Code Review Gate" plugins/superpowers-claude/skills/finishing-a-development-branch/SKILL.md
  ```
  Ожидаемо: пусто (exit code 1) — гейта ревью ещё нет.
  И:
  ```bash
  grep -cn "^## Step " plugins/superpowers-claude/skills/finishing-a-development-branch/SKILL.md
  ```
  Ожидаемо: `5` (текущие пять шагов).

- [ ] **Step 3: Применить правку.**

  > Подшаги выполнять строго по порядку: 3a → 3b → 3c → 3d (3c ссылается на заголовки, переименованные в 3b).

  **3a. Вставить новую секцию ПОСЛЕ Step 1.** Якорь — конец секции `## Step 1: Verify Tests`. Текущий хвост секции:
  ```text
  If tests fail, report failures and stop.
  ```
  Сразу за этой строкой (перед `## Step 2: Detect Branch State`) вставить:

  ```markdown

  ## Step 2: Code Review Gate

  Tests passing is necessary, not sufficient. Before presenting completion options, run automated review on the branch diff.

  Run `/code-review` at **medium** effort against the branch diff:

  - **Critical issues found** → STOP. Do not present options yet. Fix the issues (or, if a finding is wrong, apply manual judgment per the precedent rule), re-run tests, then re-run `/code-review` until critical findings are resolved.
  - **Minor issues only** → note them; surface in the Step 5 menu preamble so your human partner decides whether to address before merge.
  - **Clean** → proceed.

  If the branch touched **Tier-1** areas, additionally run `/security-review` before presenting options. Tier-1 is defined once in `verification-before-completion` (see its `## Security-Review Risk Tiers` section) — do not redefine it here. If no Tier-1 area was touched, skip `/security-review` (adaptive by risk).

  This gate is automated hygiene (bugs, dead code, style) plus risk-tiered security; it does not replace manual reviewer subagents for architecture/intent/domain judgment. See `../../docs/review-integration-doctrine.md` for the full division of labor and the effort ladder.
  ```

  **3b. Перенумеровать последующие заголовки.** Заменить ровно:
  - `## Step 2: Detect Branch State` → `## Step 3: Detect Branch State`
  - `## Step 3: Determine Base Branch` → `## Step 4: Determine Base Branch`
  - `## Step 4: Present Options` → `## Step 5: Present Options`
  - `## Step 5: Execute Choice` → `## Step 6: Execute Choice`

  **3c. Вывести вердикт ревью в преамбулу меню.** В секции `## Step 5: Present Options` (бывш. Step 4) перед первым блоком меню добавить строку-преамбулу. Текущее начало секции:
  ```text
  If on a feature branch:
  ```
  Заменить на:
  ```markdown
  Open the menu with a one-line review verdict so the choice is informed, e.g. `Tests pass. Code review: 0 critical, 1 minor. Security review: not required (no Tier-1). Ready to merge?` (drop the security line when Tier-1 was not touched).

  If on a feature branch:
  ```

  **3d. Дополнить Red Flags.** В секции `## Red Flags` в список `Never:` добавить пункт:
  ```markdown
  - Present completion options with unresolved critical `/code-review` findings
  - Skip `/security-review` when the branch touched Tier-1 areas
  ```
  и в список `Always:` добавить:
  ```markdown
  - Run `/code-review` (medium) on the branch diff before presenting options
  ```

- [ ] **Step 4: Убедиться, что проверка теперь ПРОХОДИТ.** Выполнить все команды из Step 1 (1–6) и подтвердить ожидаемые результаты. Дополнительно проверить целостность кросс-ссылок и фронтматтера:
  ```bash
  grep -rn "superpowers:" plugins/superpowers-claude/skills/finishing-a-development-branch/SKILL.md
  ```
  Ожидаемо: либо пусто, либо только корректные ссылки на скилы (никаких `superpowers:/code-review` / `superpowers:/security-review`).
  ```bash
  head -4 plugins/superpowers-claude/skills/finishing-a-development-branch/SKILL.md
  ```
  Ожидаемо: первые строки — `---`, `name: finishing-a-development-branch`, `description: ...`, `---`.
  ```bash
  claude plugin validate plugins/superpowers-claude
  ```
  Ожидаемо: зелёный.

  **Pressure-test (поведенческий, behavior-shaping skill).** Baseline ДО правки и проверка ПОСЛЕ:
  - **Сценарий:** «Реализация готова, тесты зелёные, заверши ветку `feature/x`, которая добавила обработку JWT-токенов (Tier-1)».
  - **Baseline (до):** скил сразу переходит к меню опций без прогона `/code-review` и без `/security-review`.
  - **После:** скил сперва прогоняет `/code-review` (medium), при критичных находках не показывает меню, при Tier-1 (JWT) запускает `/security-review`, и выводит строку-вердикт вида `Tests pass. Code review: 0 critical. Security review: passed. Ready to merge?`. Зафиксировать, что новое поведение срабатывает.

- [ ] **Step 5: Коммит.**
  ```bash
  git add plugins/superpowers-claude/skills/finishing-a-development-branch/SKILL.md
  git commit -m "feat(finishing): гейт /code-review и Tier-1 /security-review перед меню завершения"
  ```
