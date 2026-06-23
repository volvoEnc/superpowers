# Task 3: Углубление элиситации в brainstorming

**Risk:** medium
**Depends on:** 002 (multi-angle analyzer триггерится по Tier-1 из verification-before-completion)
**Review policy:** per-task-plus-risk
**Files:**
- Modify: `/Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude/skills/brainstorming/SKILL.md`

Кодирует spec-пункты 1, 6, 7, 8. Пять связанных правок в одном файле:
(a) новая секция **Question Taxonomy** (12 измерений) сразу после `## Question Loop Rules`;
(b) расширение шаблона **Decision Pack** до этих 12 измерений с тегами `DECIDED | TBD | NOT-APPLICABLE` + новая таблица **Risk Dimensions** + правило адаптивности;
(c) смягчение **Question Loop Rules** — батч 2-4 независимых вопросов одним вызовом `AskUserQuestion`, один-за-раз дефолт для зависимых;
(d) расширение **Question Strategist** в `## Subagent Prompt Shapes` — мапить блокирующие неизвестные на измерения таксономии, возвращать covered/next/why;
(e) опциональный шаг **multi-angle-analyzer** в `## Orchestrated Flow` (6-8 линз, adaptive по риску).

`AskUserQuestion` — встроенный инструмент Claude Code, упоминать БЕЗ префикса `superpowers:`. Риск-тиры НЕ переопределять здесь — Tier-1 определяется в `verification-before-completion` (Task 002); ссылаться на него по имени.

---

- [ ] **Step 1: Определить acceptance-проверку.** После всех правок должны пройти эти команды (точный ожидаемый вывод — непустой/совпадает):

  ```bash
  F=/Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude/skills/brainstorming/SKILL.md
  grep -c "## Question Taxonomy" "$F"            # ожидаем: 1
  grep -c "## Multi-Angle Analyzer" "$F"          # ожидаем: 1
  grep -c "Risk Dimensions" "$F"                  # ожидаем: >=1 (таблица в Decision Pack)
  grep -c "NOT-APPLICABLE" "$F"                   # ожидаем: >=2 (Decision Pack + правило адаптивности)
  grep -c "DECIDED" "$F"                          # ожидаем: >=1
  grep -Ec "batch|batching|2-4 independent" "$F"  # ожидаем: >=1 (новое правило батчинга)
  grep -c "dimensions covered" "$F"               # ожидаем: >=1 (Question Strategist coverage)
  ```

  Структурная проверка плагина:
  ```bash
  claude plugin validate /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude   # ожидаем: зелёный (valid)
  ```

  Кросс-ссылки целы (число вхождений `superpowers:` не уменьшилось; до правок их 5 — `using-git-branches`, `phase-handoff`, `writing-plans` и т.д.):
  ```bash
  grep -c "superpowers:" /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude/skills/brainstorming/SKILL.md   # ожидаем: >=5
  ```

  Проверка отсутствия префикса у built-in:
  ```bash
  grep -c "superpowers:AskUserQuestion" /Users/danilka/llm-plugins/superpowers/skills/brainstorming/SKILL.md 2>/dev/null; grep -c "superpowers:AskUserQuestion" "$F"   # ожидаем: 0
  ```

  **Pressure-test (поведенческий, behavior-shaping skill).** Сценарий «нетривиальная задача, задеты несколько подсистем»: дать агенту запрос вида «добавь экспорт данных пользователя с фоновой джобой и письмом-уведомлением». Ожидаемое НОВОЕ поведение: (1) Question Strategist возвращает covered/next-dimension/why по таксономии; (2) orchestrator батчит 2-4 независимых вопроса (напр. Goal + Success Metrics + Constraints) одним `AskUserQuestion`; (3) запускается multi-angle-analyzer (триггер: >1 подсистема + Tier-1 экспорт данных), его находки попадают в таблицу Risk Dimensions. Baseline-сценарий ДО правок: тех же сигналов нет (один вопрос за раз, нет таксономии, нет multi-angle шага).

- [ ] **Step 2: Убедиться, что проверка сейчас ПАДАЕТ (секции/поведение отсутствуют).** Выполнить:

  ```bash
  F=/Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude/skills/brainstorming/SKILL.md
  grep -c "## Question Taxonomy" "$F"     # ожидаем сейчас: 0
  grep -c "## Multi-Angle Analyzer" "$F"  # ожидаем сейчас: 0
  grep -c "Risk Dimensions" "$F"          # ожидаем сейчас: 0
  grep -c "NOT-APPLICABLE" "$F"           # ожидаем сейчас: 0
  ```
  Все нули подтверждают, что новые секции и теги отсутствуют. Также вручную убедиться: `## Question Loop Rules` начинается со строки «- Ask exactly one question per message.» (текущая жёсткая формулировка), а Question Strategist в `## Subagent Prompt Shapes` НЕ упоминает таксономию.

- [ ] **Step 3: Применить правки.** Файл сейчас ~195 строк. Четыре точечные правки + одна новая секция. Использовать Edit/Write с точными якорями ниже.

  **3a. Смягчить `## Question Loop Rules` (батчинг).** Текущая секция целиком:
  ```markdown
  ## Question Loop Rules

  - Ask exactly one question per message.
  - Prefer multiple-choice questions when useful.
  - Continue until the decision pack can answer goal, scope, constraints, non-goals, success criteria, error handling expectations, and verification expectations.
  - For large or independent subsystems, stop and help split the work into separate specs before planning details.
  - Do not ask performative questions whose answers will not affect the design.
  - If a human answer resolves several unknowns, record all resolved decisions before asking the next question.
  ```
  Заменить первую строку-буллет «- Ask exactly one question per message.» на блок:
  ```markdown
  - Default to one question per message for dependent or sequential clarifications (where the answer to one changes the wording or meaning of the next).
  - You may batch 2-4 **independent** questions in a single `AskUserQuestion` call. Questions are independent when the answer to one does not change the wording or meaning of another.
    - Good (independent, batchable): "What is the primary goal?" + "What is the success metric?" + "What is the hard constraint?" — none reframes the others.
    - Bad (dependent, ask one at a time): "Should we use a queue?" then "Which queue technology?" — the second only makes sense, and is worded differently, depending on the first answer.
  - `AskUserQuestion` is a Claude Code built-in; reference it without a `superpowers:` prefix.
  ```
  (Остальные буллеты секции оставить без изменений.)

  **3b. Вставить новую секцию `## Question Taxonomy` сразу ПОСЛЕ секции `## Question Loop Rules`** (то есть перед `## Defaults`). Вставить целиком:
  ```markdown
  ## Question Taxonomy

  Drive elicitation breadth across these 12 dimensions. The Question Strategist maps blocking unknowns onto them; the Decision Pack records the verdict per dimension.

  1. **Goal** — what outcome the change must produce.
  2. **Scope** — what is included in this change.
  3. **Non-Goals** — what is explicitly excluded.
  4. **Constraints** — technical, time, or policy limits.
  5. **Success Metrics** — how "done/working" is measured.
  6. **Error Handling** — failure modes and expected behavior.
  7. **Data Model** — entities, shapes, migrations, persistence.
  8. **Security** — auth/authz, secrets, exposure, trust boundaries.
  9. **Performance** — latency, throughput, resource limits.
  10. **UX** — user-visible behavior and interaction.
  11. **Edge Cases** — boundary inputs and rare states.
  12. **Rollout/Verification** — how the change ships and is verified.

  **Adaptivity:** simple changes fill only the relevant dimensions and mark the rest `NOT-APPLICABLE`. Do not manufacture questions to fill every dimension — coverage means each dimension is consciously decided or dismissed, not exhaustively interrogated.
  ```

  **3c. Расширить шаблон `## Decision Pack`.** Текущий шаблон внутри fenced-блока:
  ```markdown
  # Decision Pack

  ## Goal

  ## Approved Scope

  ## Out of Scope

  ## Constraints

  ## Chosen Approach

  ## Alternatives Rejected

  ## Open Questions
  ```
  Заменить весь этот fenced-блок на:
  ```markdown
  # Decision Pack

  Tag each taxonomy dimension `DECIDED` | `TBD` | `NOT-APPLICABLE`:

  | Dimension | Verdict | Decision / Note |
  |---|---|---|
  | Goal | TBD | |
  | Scope | TBD | |
  | Non-Goals | TBD | |
  | Constraints | TBD | |
  | Success Metrics | TBD | |
  | Error Handling | TBD | |
  | Data Model | TBD | |
  | Security | TBD | |
  | Performance | TBD | |
  | UX | TBD | |
  | Edge Cases | TBD | |
  | Rollout/Verification | TBD | |

  ## Chosen Approach

  ## Alternatives Rejected

  ## Open Questions

  ## Risk Dimensions

  Filled only when the Multi-Angle Analyzer runs (see Orchestrated Flow); otherwise omit or mark `NOT-APPLICABLE`.

  | Lens | Top Concern | Severity | Cross-Question Raised |
  |---|---|---|---|
  ```
  (Строку-пояснение под блоком «Only approved decisions belong here...» оставить без изменений.)

  **3d. Расширить `### Question Strategist` в `## Subagent Prompt Shapes`.** Текущий prompt-блок:
  ```text
  You are helping the orchestrator decide what to ask next.
  Do not ask the human directly. Do not write a spec. Do not design the full solution.
  Use only the request brief, context brief, and current decision pack.
  Return:
  - blocking unknowns
  - whether enough is known to discuss approaches
  - the single next best question
  - 2-4 multiple-choice options when useful
  - why this question matters
  ```
  Заменить на:
  ```text
  You are helping the orchestrator decide what to ask next.
  Do not ask the human directly. Do not write a spec. Do not design the full solution.
  Use only the request brief, context brief, and current decision pack.
  Map each blocking unknown to a Question Taxonomy dimension (Goal, Scope, Non-Goals, Constraints, Success Metrics, Error Handling, Data Model, Security, Performance, UX, Edge Cases, Rollout/Verification).
  Return:
  - blocking unknowns, each tagged with its taxonomy dimension
  - dimensions covered so far, and dimensions still TBD
  - the next dimension to address and why it matters now
  - the next question(s): a single question for dependent unknowns, OR 2-4 independent questions the orchestrator can batch in one AskUserQuestion call
  - 2-4 multiple-choice options when useful
  - whether enough is known to discuss approaches
  ```

  **3e. Вставить опциональный шаг Multi-Angle Analyzer в `## Orchestrated Flow`.** Текущий шаг 5 и 6:
  ```markdown
  5. **Dispatch `question-strategist`.** Give it only the request brief, context brief, and current decision pack. It returns blocking unknowns and the next best question plan.
  6. **Ask one question at a time.** The main agent asks the human partner the next question, records the answer, and updates the decision pack.
  ```
  Вставить НОВЫЙ шаг между ними (перенумеровывать остальные не требуется — добавить как «5a», чтобы не трогать ссылки на номера в других местах файла):
  ```markdown
  5a. **(Optional) Dispatch `multi-angle-analyzer`.** Trigger when a Tier-1 area is touched (Security-Review Risk Tiers in `superpowers:verification-before-completion`), OR more than one subsystem / many blocking unknowns are involved, OR the human partner asks for a deep analysis. Skip for small isolated changes. It examines the request through 6-8 lenses — security, performance, data-integrity, UX, maintainability, failure-modes, cost/scale, ops-complexity — and returns at most one blocking concern per lens plus cross-cutting questions. Feed its concerns into the question plan and the Risk Dimensions table in the decision pack. Keep only its compact result.
  ```
  И добавить prompt-shape для нового субагента в `## Subagent Prompt Shapes` (сразу после `### Question Strategist`):
  ```markdown
  ### Multi-Angle Analyzer subagent

  Optional, risk-triggered. Use only when the Orchestrated Flow trigger is met.

  ```text
  You are stress-testing the request through multiple lenses, not designing or implementing.
  Use only the request brief, context brief, and current decision pack.
  Examine 6-8 lenses: security, performance, data-integrity, UX, maintainability, failure-modes, cost/scale, ops-complexity.
  Return at most ONE blocking concern per lens (skip lenses with no real concern), each with a severity and a concrete cross-question the orchestrator should ask.
  Do not write a spec. Do not propose the full solution. Keep the output as a compact Risk Dimensions table.
  ```
  ```
  (Внимание: вложенный fenced-блок — использовать внешнюю разметку аккуратно, как в существующих prompt-shapes файла, где каждый prompt обёрнут в ```text ... ```.)

- [ ] **Step 4: Убедиться, что проверка теперь ПРОХОДИТ.** Прогнать все grep из Step 1 — получить ожидаемые значения (Question Taxonomy=1, Multi-Angle Analyzer=1, Risk Dimensions>=1, NOT-APPLICABLE>=2, DECIDED>=1, батчинг>=1, «dimensions covered»>=1, `superpowers:AskUserQuestion`=0). Затем:
  ```bash
  claude plugin validate /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude   # ожидаем: зелёный
  head -4 /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude/skills/brainstorming/SKILL.md   # ожидаем: YAML-фронтматтер цел (--- / name: brainstorming / description: ... / ---)
  grep -c "superpowers:" /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude/skills/brainstorming/SKILL.md   # ожидаем: >=5 (кросс-ссылки целы)
  ```
  Прогнать pressure-test из Step 1 (до/после): убедиться, что новое поведение (taxonomy-coverage + батчинг + multi-angle на нетривиальной задаче) срабатывает, а на простом изолированном изменении остаётся лёгким (multi-angle пропускается, лишние измерения → `NOT-APPLICABLE`). Зафиксировать before/after результат в receipt.

- [ ] **Step 5: Commit.**
  ```bash
  git add /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude/skills/brainstorming/SKILL.md
  git commit -m "feat(brainstorming): таксономия вопросов, батчинг и опциональный многоугловой анализ"
  ```
