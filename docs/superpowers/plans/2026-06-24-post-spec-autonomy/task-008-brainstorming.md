# Task 8: brainstorming — Fallback → coordinator-only + эскалация

**Risk:** medium
**Depends on:** none
**Review policy:** per-task-plus-risk
**Files:** Modify: `plugins/superpowers-claude/skills/brainstorming/SKILL.md`

Кодирует пункт I спеки (`docs/superpowers/specs/2026-06-24-post-spec-autonomy-design.md`, scope §I, инвариант «координатор не подменяет субагента собой») только для `brainstorming/SKILL.md`. Меняется ТОЛЬКО секция `## Fallback` (строки 246-248). Остальной скил не трогать. Это поведение-формирующая правка (CLAUDE.md), поэтому в Step 1 есть pressure-test.

Текущий текст Fallback (строки 246-248):

```
## Fallback

If subagents are unavailable or the human partner asks you to work inline, the main agent may perform the same steps inline. It must still maintain the request brief, context brief, and decision pack as the only source of truth, and must not carry rejected chat history into planning.
```

Проблема: текущая формулировка разрешает inline-работу при недоступности субагентов («If subagents are unavailable ... may perform the same steps inline»). Это противоречит §I: inline допустим только по явному запросу человека и только координация/состояние; subagent-классовая работа (repo-context-scout, multi-angle-analyzer, approach-scout, spec-author, spec-reviewer, task-intake) при недоступности Task должна эскалироваться/hard-stop, а не выполняться inline.

## Steps

- [ ] **Step 1: acceptance check (+ pressure-test).**
  - Grep на новые ключевые формулировки (запускать из корня репо `/Users/danilka/llm-plugins/superpowers`):
    ```
    grep -n "coordination and state-keeping" plugins/superpowers-claude/skills/brainstorming/SKILL.md
    grep -n "escalate" plugins/superpowers-claude/skills/brainstorming/SKILL.md
    grep -n "not on subagent unavailability" plugins/superpowers-claude/skills/brainstorming/SKILL.md
    ```
    Ожидается: каждая строка найдена (после Step 3).
  - Grep на отсутствие старой разрешающей формулировки:
    ```
    grep -n "If subagents are unavailable or the human partner asks you to work inline, the main agent may perform the same steps inline" plugins/superpowers-claude/skills/brainstorming/SKILL.md
    ```
    Ожидается: пусто (после Step 3).
  - **Pressure-test (поведенческий, до/после).** Сценарий: оркестратор в `brainstorming` доходит до шага «Dispatch `repo-context-scout`», но Task tool недоступен.
    - ДО (текущий текст): оркестратор читает «If subagents are unavailable ... may perform the same steps inline» и сам инспектирует репо inline (читает файлы, grep), накапливая raw-контекст в оркестраторе — нарушение Core Rule и инварианта чистоты контекста.
    - ПОСЛЕ (новый текст): оркестратор видит, что repo-context-scout — subagent-классовая работа, и при недоступности Task **эскалирует/hard-stop**, НЕ инспектирует репо сам. Inline допустим только если человек явно попросил, и только координация/ведение брифов и decision pack.
    Критерий прохождения: на сценарии «Task недоступен» агент НЕ выполняет inline repo-context-scout / multi-angle-analyzer / approach-scout / spec-author / spec-reviewer, а останавливается с эскалацией.

- [ ] **Step 2: verify it currently FAILS (absent).**
  Запустить grep'ы из Step 1 на текущем файле:
  ```
  grep -n "coordination and state-keeping" plugins/superpowers-claude/skills/brainstorming/SKILL.md
  grep -n "not on subagent unavailability" plugins/superpowers-claude/skills/brainstorming/SKILL.md
  ```
  Ожидается сейчас: пусто (формулировок ещё нет). И наоборот, старая строка пока присутствует:
  ```
  grep -n "the main agent may perform the same steps inline" plugins/superpowers-claude/skills/brainstorming/SKILL.md
  ```
  Ожидается сейчас: найдена (строка 248). Это подтверждает, что правка ещё не применена.

- [ ] **Step 3: apply edit.**
  Anchor — секция `## Fallback` (последняя секция файла, строки 246-248). Заменить весь текущий абзац под `## Fallback` на новый. Quote окружения: секция идёт сразу после `## Defaults` (последний буллет `## Defaults` — «If follow-up is needed, dispatch a fresh subagent with the prior result and the exact follow-up scope.»), и `## Fallback` — конец файла.

  Новый текст секции:

  ```markdown
  ## Fallback

  Inline work is allowed **only on the human partner's explicit request** — never as a reaction to subagent unavailability. Even then, the main agent's inline work is **coordination and state-keeping only**: maintaining the request brief, context brief, and decision pack as the single source of truth, recording human answers, routing artifacts, and not carrying rejected chat history into planning.

  The main agent must **not** do subagent-class work inline under any circumstance. Specifically forbidden inline: repo-context-scout inspection (reading files, grep, commit history), multi-angle-analyzer risk passes, approach-scout comparison, spec-author writing, spec-reviewer review, and task-intake of long files. Those always belong to fresh read-only subagents (Task tool).

  If subagent-class work is needed but the Task tool is genuinely unavailable, **escalate / hard-stop — do not do it inline** (not on subagent unavailability). The coordinator does not substitute itself for a subagent.
  ```

- [ ] **Step 4: verify it PASSES + validate + cross-links.**
  - Перезапустить все grep'ы из Step 1 — все позитивные находятся, старая строка отсутствует.
  - `claude plugin validate /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude` — зелёный.
  - Фронтматтер цел (первые строки файла `---` / `name: brainstorming` / `description:` / `---` не тронуты).
  - Кросс-ссылки `superpowers:*` целы (правка не трогает ссылки на `superpowers:using-git-branches`, `superpowers:verification-before-completion`, `superpowers:phase-handoff`, `superpowers:writing-plans`):
    ```
    grep -n "superpowers:" plugins/superpowers-claude/skills/brainstorming/SKILL.md
    ```
    Ожидается: те же ссылки, что и до правки (строки 16, 23, 28, 38).
  - Встроенные без префикса не задеты (правка не добавляет встроенных):
    ```
    grep -nE "superpowers:(code-review|security-review|simplify|verify|run)" plugins/superpowers-claude/skills/brainstorming/SKILL.md
    ```
    Ожидается: пусто.

- [ ] **Step 5: commit.**
  ```
  git add plugins/superpowers-claude/skills/brainstorming/SKILL.md
  git commit -m "feat(brainstorming): inline-fallback только по явному запросу, coordinator-only

Inline допустим лишь по явной просьбе человека, не на недоступности
субагентов. Subagent-классовая работа (repo-context-scout,
multi-angle-analyzer, approach-scout, spec-author, spec-reviewer,
task-intake) запрещена inline; при недоступности Task — эскалация/hard-stop.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
  ```
