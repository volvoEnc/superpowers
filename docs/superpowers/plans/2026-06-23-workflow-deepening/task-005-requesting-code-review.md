# Task 5: requesting-code-review — секция «Built-in code review vs subagent reviewers»
**Risk:** low
**Depends on:** 001
**Review policy:** group
**Files:**
- Modify: `/Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude/skills/requesting-code-review/SKILL.md`

Контекст (самодостаточно, чтобы не перечитывать спек):
Добавить в скил `requesting-code-review` одну новую секцию, разделяющую встроенный `/code-review` и ручных субагентов-ревьюеров, со ссылкой на доктрину ревью (создана в task 001 по пути `plugins/superpowers-claude/docs/review-integration-doctrine.md`). Секция должна: (1) сказать, что `/code-review` берёт на себя корректность/мёртвый-код/стиль на effort low-medium, а ручные субагенты — архитектуру/домен/кросс-системное суждение; (2) описать лестницу effort (low — рутина → medium — рискованно → high+ — пред-мердж); (3) упомянуть `/code-review --comment` (инлайн-аннотации в PR) и `--fix` (только ПОСЛЕ одобрения ручным ревью, чтобы избежать конфликтующих правок); (4) сослаться на доктрину относительным путём.

ЖЁСТКИЕ ПРАВИЛА:
- `/code-review` — это ВСТРОЕННЫЙ механизм Claude Code. Ссылаться как `/code-review`, НИКОГДА с префиксом `superpowers:`.
- Не дублировать содержимое доктрины — ссылаться на неё, держать секцию короткой.
- Не ломать YAML-фронтматтер (`name`, `description` первыми) и существующие ссылки (`requesting-code-review/code-reviewer.md`).
- Текущий ручной диспатч субагентов остаётся валидным дефолтом — не объявлять его неправильным.

Текущее состояние файла (якоря, дословно):
- Строки 12-23 — секция `## When to Request Review` (Mandatory / Optional but valuable), заканчивается перед `## How to Request` (строка 24).
- Доктрина в task 001 ещё не сослана отсюда — это и есть новизна.

Шаги:

- [ ] Step 1: Определить приёмочную проверку. После правки команда
  `grep -n "Built-in code review vs subagent reviewers" /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude/skills/requesting-code-review/SKILL.md`
  должна вернуть ровно одну строку с заголовком секции. Дополнительно
  `grep -n "review-integration-doctrine.md" /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude/skills/requesting-code-review/SKILL.md`
  должна найти относительную ссылку на доктрину, и
  `grep -nE "\-\-comment|\-\-fix" /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude/skills/requesting-code-review/SKILL.md`
  должна найти упоминания обоих флагов.

- [ ] Step 2: Убедиться, что проверка сейчас ПРОВАЛИВАЕТСЯ (секция отсутствует). Выполнить
  `grep -c "Built-in code review vs subagent reviewers" /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude/skills/requesting-code-review/SKILL.md`
  Ожидаемый вывод: `0`. И
  `grep -c "review-integration-doctrine.md" /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude/skills/requesting-code-review/SKILL.md`
  Ожидаемый вывод: `0`.

- [ ] Step 3: Применить правку. Вставить новую секцию СРАЗУ ПОСЛЕ конца секции `## When to Request Review` и ПЕРЕД `## How to Request`. Точный якорь — последний пункт секции `When to Request Review`:
  ```
  **Optional but valuable:**
  - When stuck (fresh perspective)
  - Before refactoring (baseline check)
  - After fixing complex bug
  ```
  Сразу после строки `- After fixing complex bug` (и пустой строки за ней), перед строкой `## How to Request`, вставить ровно следующий блок:

  ```markdown
  ## Built-in code review vs subagent reviewers

  Two complementary tools. Choose by what kind of judgment is needed.

  - **`/code-review` (built-in)** — automatic hygiene: correctness bugs, dead code, style, simplification. Fast, runs on the live diff, no clean-context dispatch needed. Default for mechanical quality.
  - **Manual subagent reviewers** (this skill) — judgment: architecture, intent, domain rules, cross-system effects. Gets precisely crafted context, preserves orchestrator context. Use when the question is "is this the *right* design?", not "is this code correct?".

  They are not redundant — run both when the work is non-trivial. When a built-in finding and a manual reviewer's judgment conflict, manual judgment wins; on a real contradiction, ask your human partner. Full decision tree, effort ladder, and precedence rule: `../../docs/review-integration-doctrine.md`.

  **Effort ladder for `/code-review`:**
  - `low` — routine, low-risk changes (per-task during implementation).
  - `medium` — riskier changes; default gate before finishing a branch.
  - `high`+ — pre-merge or high-stakes diffs; broader, may surface uncertain findings.

  **Flags:**
  - `/code-review --comment` — posts findings as inline PR annotations (review-in-place on a PR).
  - `/code-review --fix` — applies the findings to the working tree. Run this **only after** a manual reviewer has approved the design, so auto-edits don't conflict with judgment-level changes you still intend to make.
  ```

- [ ] Step 4: Проверить, что приёмка ПРОХОДИТ. Выполнить три grep из Step 1 — заголовок найден один раз, ссылка `review-integration-doctrine.md` присутствует, `--comment` и `--fix` присутствуют. Затем подтвердить целостность:
  - Фронтматтер цел: `head -5 /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude/skills/requesting-code-review/SKILL.md` — первые непустые строки `---`, `name: requesting-code-review`, `description: ...`.
  - Существующая ссылка цела: `grep -n "requesting-code-review/code-reviewer.md" /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude/skills/requesting-code-review/SKILL.md` — одна строка.
  - НЕТ ошибочного префикса: `grep -n "superpowers:.*code-review" /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude/skills/requesting-code-review/SKILL.md` — пустой вывод.
  - Валидация плагина зелёная: `claude plugin validate /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude` — без ошибок.
  - Поведенческий pressure-test: задать вопрос «нужно ли запускать `/code-review --fix` сразу после автонаходок» — скил после правки должен указывать, что `--fix` применяется только после одобрения ручным ревью (раньше скил молчал об этом).

- [ ] Step 5: Коммит. Выполнить
  `git -C /Users/danilka/llm-plugins/superpowers add plugins/superpowers-claude/skills/requesting-code-review/SKILL.md`
  затем
  `git -C /Users/danilka/llm-plugins/superpowers commit -m "feat(requesting-code-review): секция встроенный /code-review vs субагенты со ссылкой на доктрину"`
