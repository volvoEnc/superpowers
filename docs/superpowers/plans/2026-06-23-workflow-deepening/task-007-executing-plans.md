# Task 7: executing-plans — Tier-1 security-review handoff перед finishing

**Risk:** low
**Depends on:** 002 (определяет секцию `## Security-Review Risk Tiers` в `verification-before-completion`; эта задача только ссылается на неё, не переопределяет)
**Review policy:** group
**Files:**
- Modify: `/Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude/skills/executing-plans/SKILL.md`

## Контекст (самодостаточно, не нужно перечитывать спеку)

Spec item 15 / acceptance criteria 3: `executing-plans` перед хендоффом в `finishing-a-development-branch` должен иметь **конкретный шаг** (не просто ссылку): если план задел Tier-1 область — запросить одобрение human partner на `/security-review` по накопленному диффу ветки и передать риск-оценку плана вперёд, чтобы finishing знал, авто-триггерить ли security-review.

Жёсткие ограничения:
- `/security-review` — **встроенный** механизм Claude Code. Ссылаться как `/security-review`, БЕЗ префикса `superpowers:`.
- Определение Tier-1 живёт ОДИН раз — в `verification-before-completion`, секция `## Security-Review Risk Tiers` (создаётся задачей 002). Здесь — только ссылка на неё, без дублирования списка категорий.
- Не ломать существующие кросс-ссылки `superpowers:*` (в файле: `superpowers:using-git-branches`, `superpowers:writing-plans`, `superpowers:finishing-a-development-branch`).
- Не раздувать скил: вставка короткая.

Реальная текущая структура файла (якоря): `## Step 0: Check Branch` → `## Step 1: Load and Review Plan` → `## Step 2: Execute Tasks` (заканчивается списком из 4 пунктов про каждую задачу) → `## Step 3: Complete Development` → `## When to Stop and Ask for Help` → `## Remember` → `## Integration`. Точка вставки: новый шаг между концом `## Step 2: Execute Tasks` и началом `## Step 3: Complete Development`.

## Шаги

- [ ] **Step 1: Определить acceptance-проверку.** После правки должны проходить:
  - `grep -n "Security-Review Risk Tiers" /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude/skills/executing-plans/SKILL.md` — ожидается ≥1 строка (ссылка на единый источник риск-тиров).
  - `grep -n "/security-review" /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude/skills/executing-plans/SKILL.md` — ожидается ≥1 строка с упоминанием встроенного `/security-review`.
  - `grep -n "superpowers:security-review" /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude/skills/executing-plans/SKILL.md` — ожидается ПУСТОЙ вывод (встроенный механизм не должен иметь префикса).
  - `grep -n "^## Step 2a" /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude/skills/executing-plans/SKILL.md` — ожидается 1 строка (новый шаг существует).
  - Поведенческий pressure-test: см. Step 4.

- [ ] **Step 2: Убедиться, что проверка сейчас ПАДАЕТ (поведение отсутствует).** Выполнить:
  - `grep -n "/security-review" /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude/skills/executing-plans/SKILL.md` — ожидается ПУСТОЙ вывод (секции/упоминания нет).
  - `grep -n "Security-Review Risk Tiers" /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude/skills/executing-plans/SKILL.md` — ожидается ПУСТОЙ вывод.
  - `grep -n "^## Step 2a" /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude/skills/executing-plans/SKILL.md` — ожидается ПУСТОЙ вывод.

- [ ] **Step 3: Применить правку.** Вставить новый раздел `## Step 2a` МЕЖДУ концом `## Step 2: Execute Tasks` и началом `## Step 3: Complete Development`.

  Якорь — конец секции Step 2. Сейчас она такая:
  ```
  ## Step 2: Execute Tasks

  For each task:

  1. Mark as in_progress.
  2. Follow each step exactly.
  3. Run verifications as specified.
  4. Mark as completed.

  ## Step 3: Complete Development
  ```

  Заменить строку-разделитель (пустую строку + `## Step 3: Complete Development`) так, чтобы перед `## Step 3` появился новый раздел. Конкретно — вставить ПОСЛЕ строки `4. Mark as completed.` и ПЕРЕД `## Step 3: Complete Development` следующий блок (именно этот текст):

  ```
  ## Step 2a: Security Risk Check Before Handoff

  Before handing off to finishing, assess the security risk of the accumulated branch diff.

  1. Re-read the plan's per-task risk assessment. Determine whether any completed task touched a **Tier-1** area. Tier-1 is defined once in `superpowers:verification-before-completion` → section "Security-Review Risk Tiers" (auth/authz, crypto, secrets, external API keys, shell execution, file permissions, SQL/DB mutations, data export). Do not redefine the list here — consult that section.
  2. **If any task was Tier-1:** stop before handoff and ask your human partner for approval to run `/security-review` on the accumulated branch diff. `/security-review` is a Claude Code built-in (no `superpowers:` prefix). Run it only after explicit approval. Critical findings → fix before proceeding.
  3. **If no task was Tier-1:** note "plan risk: not Tier-1, /security-review not required" and continue.
  4. **Pass the risk assessment forward.** When invoking finishing in Step 3, state the plan's risk tier explicitly (e.g. "plan risk: Tier-1, /security-review run and clean" or "plan risk: not Tier-1") so finishing knows whether to auto-trigger its own `/security-review` gate rather than re-deriving it.

  ```

  ВАЖНО: блок заканчивается пустой строкой, чтобы между ним и `## Step 3: Complete Development` остался ровно один пустой разделитель. Существующие секции и кросс-ссылки не трогать. Ссылка на доктрину здесь не обязательна (item 15 требует только ссылку на риск-тиры и конкретный шаг); ничего из `superpowers:*` не удалять.

- [ ] **Step 4: Убедиться, что проверка теперь ПРОХОДИТ.**
  - `grep -n "^## Step 2a" /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude/skills/executing-plans/SKILL.md` → 1 строка.
  - `grep -n "Security-Review Risk Tiers" /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude/skills/executing-plans/SKILL.md` → ≥1 строка.
  - `grep -n "/security-review" /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude/skills/executing-plans/SKILL.md` → ≥1 строка.
  - `grep -n "superpowers:security-review" /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude/skills/executing-plans/SKILL.md` → ПУСТО.
  - Фронтматтер цел: `head -4 /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude/skills/executing-plans/SKILL.md` → первые строки `---`, `name: executing-plans`, `description: ...`, `---`.
  - Кросс-ссылки целы: `grep -n "superpowers:" /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude/skills/executing-plans/SKILL.md` → присутствуют `superpowers:using-git-branches`, `superpowers:writing-plans`, `superpowers:finishing-a-development-branch` (как минимум те, что были до правки; ничего не пропало).
  - Валидация плагина зелёная: `claude plugin validate /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude` → без ошибок.
  - **Поведенческий pressure-test (before/after).** Сценарий: «Выполни этот план через executing-plans; одна из задач меняет логику аутентификации (auth). Все задачи завершены, тесты зелёные — переходи к finishing.»
    - *Before* (baseline на исходном файле): модель идёт прямо в Step 3 / finishing, не упоминая `/security-review` и риск-тиры.
    - *After*: модель на Step 2a распознаёт auth как Tier-1, останавливается и запрашивает у human partner одобрение на `/security-review` по диффу ветки ПЕРЕД хендоффом в finishing, и явно передаёт риск-оценку плана дальше. Зафиксировать, что after-поведение срабатывает, а before — нет.

- [ ] **Step 5: Коммит.**
  - `git add /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude/skills/executing-plans/SKILL.md`
  - `git commit -m "feat(executing-plans): шаг Tier-1 /security-review перед хендоффом в finishing"`
