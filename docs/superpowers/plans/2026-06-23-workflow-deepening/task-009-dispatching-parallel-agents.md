# Task 9: dispatching-parallel-agents — решающая таблица «ручной Task-диспатч vs Workflow»
**Risk:** low
**Depends on:** none
**Review policy:** group
**Files:**
- Modify: plugins/superpowers-claude/skills/dispatching-parallel-agents/SKILL.md

Цель: после секции `## When to Use` добавить образовательную (только-примаер, без поведенческого мандата) секцию-решающую-таблицу «Manual Task dispatch vs Workflow tool». Она объясняет, когда встроенный Workflow-инструмент (`parallel()`/`pipeline()`) помогает, а когда переусложняет, и явно фиксирует, что текущий ручной Task-диспатч НЕ является ошибкой и остаётся дефолтом. Опционально упоминает 1-2 opt-in паттерна Workflow как будущие опции. `/code-review`, `/security-review`, `/simplify`, `verify`, `run`, Workflow — это Claude Code built-ins, ссылаемся БЕЗ префикса `superpowers:`.

- [ ] Step 1: Определить проверку приёмки. Команда:
  `grep -n "Manual Task dispatch vs Workflow tool" plugins/superpowers-claude/skills/dispatching-parallel-agents/SKILL.md`
  Ожидаемый результат ПОСЛЕ правки: ровно одна строка с заголовком `## Manual Task dispatch vs Workflow tool`.
  Дополнительная проверка содержания:
  `grep -n "is NOT wrong\|over-engineer" plugins/superpowers-claude/skills/dispatching-parallel-agents/SKILL.md`
  Ожидается ПОСЛЕ правки: минимум одна строка (формулировка «текущий ручной подход НЕ неправильный» + про over-engineering).

- [ ] Step 2: Убедиться, что проверка сейчас ПРОВАЛИВАЕТСЯ (секция отсутствует). Выполнить:
  `grep -n "Manual Task dispatch vs Workflow tool" plugins/superpowers-claude/skills/dispatching-parallel-agents/SKILL.md ; echo "exit=$?"`
  Ожидаемый результат СЕЙЧАС: нет совпадений, `exit=1` (grep ничего не нашёл — секции нет).

- [ ] Step 3: Применить правку. Якорь — конец секции `## When to Use`, перед началом `## The Pattern`. В файле эта граница выглядит так (вставлять НОВЫЙ блок между этими двумя строками, после блока «Don't use when»):

  ```
  **Don't use when:**
  - Failures are related (fix one might fix others)
  - Need to understand full system state
  - Agents would interfere with each other

  ## The Pattern
  ```

  Вставить после строки `- Agents would interfere with each other` и пустой строки, ПЕРЕД `## The Pattern`, следующий блок ДОСЛОВНО:

  ```markdown
  ## Manual Task dispatch vs Workflow tool

  Everything above describes **manual Task dispatch**: you hand-craft each agent's
  prompt and integrate results yourself. This is the default and **it is NOT wrong** —
  it is the right tool for most parallel work. Claude Code also ships a built-in
  **Workflow tool** (`parallel()` / `pipeline()`) that orchestrates agents for you.
  This section is an educational primer on *when* Workflow helps versus *when* it
  over-engineers a job that manual dispatch already does well. It mandates nothing.

  | Dimension | Manual Task dispatch (default) | Workflow tool (`parallel()` / `pipeline()`) |
  |-----------|--------------------------------|---------------------------------------------|
  | Problem shape | Heterogeneous problems — each agent does something different | Homogeneous domain — same operation fanned across many inputs |
  | Result shape | Uncertain / free-form summaries you read and reconcile | High-confidence, predictable result schema you can consume programmatically |
  | Human input mid-flow | Flow may need a human interruption or course-correction partway | No mid-flow human input — fire, collect, done |
  | Integration | You judge and merge results case by case | Mechanical aggregation of uniform outputs |

  **Rule of thumb:** if you would write three *different* agent prompts and then
  *think* about how to combine the answers, stay manual. If you would write the *same*
  prompt N times over uniform inputs and expect uniform structured results with no
  human checkpoint, Workflow may remove boilerplate. When unsure, manual dispatch is
  the safe default — do not reach for Workflow just because it exists.

  **Opt-in Workflow patterns (future options, not requirements):**
  - **Plan review as parallel + verify:** fan one plan out to several reviewer agents
    with a shared rubric (`parallel()`), then a final verify step aggregates findings.
  - **Homogeneous batch fix:** apply the identical fix recipe across many independent
    files where each result is "patched / not patched" with the same shape.

  Both are experiments to prototype on a single real workload before treating Workflow
  as anything more than an occasional opt-in.
  ```

  Ограничения при вставке: НЕ менять YAML-фронтматтер (строки 1–4, `name`/`description` первыми). Никаких префиксов `superpowers:` у `parallel()`/`pipeline()`/Workflow. Содержание держать компактным — не дублировать «The Pattern», только решающая таблица + правило + opt-in.

- [ ] Step 4: Проверить, что проверка теперь ПРОХОДИТ. Выполнить:
  - `grep -n "Manual Task dispatch vs Workflow tool" plugins/superpowers-claude/skills/dispatching-parallel-agents/SKILL.md` → ровно одна строка с `## Manual Task dispatch vs Workflow tool`.
  - `grep -n "is NOT wrong\|over-engineer" plugins/superpowers-claude/skills/dispatching-parallel-agents/SKILL.md` → минимум одна строка.
  - Новая секция стоит между `## When to Use` и `## The Pattern` (порядок секций):
    `grep -n "^## " plugins/superpowers-claude/skills/dispatching-parallel-agents/SKILL.md`
    Ожидается, что `## Manual Task dispatch vs Workflow tool` идёт сразу после `## When to Use` и перед `## The Pattern`.
  - Фронтматтер цел: `head -5 plugins/superpowers-claude/skills/dispatching-parallel-agents/SKILL.md` → первые строки `---`, `name: dispatching-parallel-agents`, `description: ...`, `---`.
  - Кросс-ссылки `superpowers:` не появились ошибочно у built-ins:
    `grep -n "superpowers:" plugins/superpowers-claude/skills/dispatching-parallel-agents/SKILL.md` → не должно быть строк, привязывающих `superpowers:` к `parallel`/`pipeline`/`Workflow`/`verify`/`run` (для этого файла ожидается отсутствие совпадений вовсе).
  - Валидация плагина зелёная: `claude plugin validate plugins/superpowers-claude` → успех, без ошибок.

- [ ] Step 5: Коммит:
  `git add plugins/superpowers-claude/skills/dispatching-parallel-agents/SKILL.md`
  `git commit -m "docs(skills): добавить решающую таблицу ручной Task-диспатч vs Workflow в dispatching-parallel-agents"`
