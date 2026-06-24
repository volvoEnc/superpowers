# Task 2: writing-plans — единственный гейт спека, subagent-driven дефолт, repo-контекст, coordinator-only fallback, branch-doc

**Risk:** high
**Depends on:** 001 (phase-handoff определяет схему `state.json`; здесь только ссылаемся на неё по имени, не переопределяем)
**Review policy:** per-task-plus-risk
**Files:** Modify: `plugins/superpowers-claude/skills/writing-plans/SKILL.md`

Кодирует пункты спеки A, B, H, I, L (см. `docs/superpowers/specs/2026-06-24-post-spec-autonomy-design.md` и file→scope map в `docs/superpowers/plans/2026-06-24-post-spec-autonomy/context-pack.md`). Все пять правок — поведение-формирующие, поэтому каждый sub-edit имеет behavioral pressure-test. Встроенные команды (`/code-review`, `/security-review`, `/simplify`, `verify`, `run`) — БЕЗ префикса `superpowers:`. Не трогать YAML-фронтматтер и существующие `superpowers:`-ссылки (строки 84, 126, 204 — `reviewing-plans`, `subagent-driven-development`, `executing-plans`, `using-git-branches`).

Все команды запускаются из корня репо `/Users/danilka/llm-plugins/superpowers`.

---

## Sub-edit A — заменить безусловный «Human approval» на авто-проход (спека A)

- [ ] **Step A1: acceptance check.** Целевое состояние: секция `### 6.` больше не требует безусловного approval; авто-проход при чистом ревью задокументирован; ревью плана всё равно выполняется всегда.
  - `grep -n "Auto-proceed when" plugins/superpowers-claude/skills/writing-plans/SKILL.md` → одна строка.
  - `grep -niE "Plan review still always runs|review still runs" plugins/superpowers-claude/skills/writing-plans/SKILL.md` → ≥1 строка.
  - `grep -niE "ask the human partner to approve the plan before execution" plugins/superpowers-claude/skills/writing-plans/SKILL.md` → ПУСТО (старый безусловный гейт удалён).
  - **Behavioral pressure-test (before/after).** Сценарий: спека одобрена, оркестратор пишет план, `reviewing-plans` вернул `approved` без блокеров. BEFORE: на шаге 6 агент останавливается и спрашивает у человека approval плана. AFTER: агент НЕ останавливается — логирует чистое ревью и сразу переходит к Execution Handoff; человеческий approval запрашивается ТОЛЬКО если ревью вернуло `issues-found`/`blocked` ИЛИ человек заранее попросил гейт.
- [ ] **Step A2: verify it currently FAILS (absent).** `grep -n "Auto-proceed when" plugins/superpowers-claude/skills/writing-plans/SKILL.md` → ПУСТО; `grep -niE "ask the human partner to approve the plan before execution" plugins/superpowers-claude/skills/writing-plans/SKILL.md` → находит текущую строку 94 (значит правка ещё не применена).
- [ ] **Step A3: apply edit.** Anchor — заголовок `### 6. Human approval` (строки 92-94). Заменить заголовок и его тело целиком. Текущий текст:
  > ```
  > ### 6. Human approval
  >
  > After blocking review findings are resolved, ask the human partner to approve the plan before execution.
  > ```
  Новый текст:
  ```
  ### 6. Approval gate (conditional)

  Plan review (`superpowers:reviewing-plans`) always runs — only the human approval step is conditional.

  Auto-proceed when the review receipt is `approved` with no open blockers: log the clean review and continue straight to Execution Handoff without asking. The approved spec is the single human gate; after it, the orchestrator runs to an open PR without further approval stops.

  Require explicit human approval only when the review returns `issues-found` or `blocked`, or when the human partner pre-requested a plan gate. Unresolved blockers escalate per the cycle limits (see `superpowers:reviewing-plans`), they do not silently auto-proceed.
  ```
- [ ] **Step A4: verify it PASSES.** Повторить grep'ы из Step A1 (все условия выполняются). Затем `claude plugin validate /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude` → зелёный. Кросс-ссылки целы: `grep -n "superpowers:" plugins/superpowers-claude/skills/writing-plans/SKILL.md` показывает строки с `reviewing-plans`, `subagent-driven-development`, `executing-plans`, `using-git-branches` (ни одна не удалена; добавилась новая ссылка на `reviewing-plans` — это норма).

---

## Sub-edit B — Execution Handoff: subagent-driven дефолт, убрать «Which approach?» (спека B)

- [ ] **Step B1: acceptance check.** Целевое состояние: `## Execution Handoff` объявляет subagent-driven дефолтом при наличии Task; inline (`executing-plans`) — явный opt-in/fallback; симметричный вопрос «Which approach?» удалён.
  - `grep -niE "subagent-driven .*default|default .*subagent-driven" plugins/superpowers-claude/skills/writing-plans/SKILL.md` → ≥1 строка.
  - `grep -n "Which approach?" plugins/superpowers-claude/skills/writing-plans/SKILL.md` → ПУСТО.
  - **Behavioral pressure-test (before/after).** Сценарий: план одобрен, Task tool доступен. BEFORE: агент предлагает симметричное меню из двух опций и спрашивает «Which approach?». AFTER: агент по умолчанию запускает subagent-driven (`superpowers:subagent-driven-development`) без вопроса; inline-исполнение (`superpowers:executing-plans`) выбирается только если человек явно его запросил.
- [ ] **Step B2: verify it currently FAILS (absent).** `grep -n "Which approach?" plugins/superpowers-claude/skills/writing-plans/SKILL.md` → находит текущую строку 216; `grep -niE "subagent-driven .*default" plugins/superpowers-claude/skills/writing-plans/SKILL.md` → ПУСТО.
- [ ] **Step B3: apply edit.** Anchor — заголовок `## Execution Handoff` (строки 206-217). Заменить весь блок (включая `text`-кодоблок с «Which approach?»). Текущий текст:
  > ```
  > ## Execution Handoff
  >
  > After plan review and human approval, offer:
  >
  > ```text
  > Plan complete and saved to <plan overview>. Review status: <approved/issues-found>. Two execution options:
  >
  > 1. Subagent-Driven - fresh subagent per task with review between tasks
  > 2. Inline Execution - execute in this session with checkpoints
  >
  > Which approach?
  > ```
  > ```
  Новый текст:
  ```
  ## Execution Handoff

  Once the approval gate is cleared (auto or explicit), hand off to execution. Subagent-driven is the default whenever the Task tool is available: launch `superpowers:subagent-driven-development` (fresh subagent per task, review between tasks) without asking.

  Inline execution (`superpowers:executing-plans`, this session with checkpoints) is an explicit opt-in/fallback — use it only when the human partner asked for inline, not as a symmetric choice. Do not present a "which approach?" menu.

  Log the handoff:

  ```text
  Plan complete and saved to <plan overview>. Review status: <approved/issues-found>. Executing subagent-driven per default.
  ```
  ```
- [ ] **Step B4: align Core Rule.** Anchor — `## Core Rule` (строка 10). Текущая последняя фраза: «When subagents are available, do not write or review the implementation plan inline.» Дополнить, чтобы дефолт исполнения согласовался: добавить отдельным предложением в конец абзаца строки 10:
  > `When subagents are available, do not write or review the implementation plan inline.`
  →
  > `When subagents are available, do not write or review the implementation plan inline, and default to subagent-driven execution rather than inline.`
- [ ] **Step B5: verify it PASSES.** Повторить grep'ы Step B1 (выполняются). Дополнительно `grep -n "default to subagent-driven execution" plugins/superpowers-claude/skills/writing-plans/SKILL.md` → одна строка (Core Rule согласован). `claude plugin validate /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude` → зелёный. Кросс-ссылки на `subagent-driven-development` и `executing-plans` присутствуют.

---

## Sub-edit H — repo root + read-only пометка в plan-author inputs (спека H)

- [ ] **Step H1: acceptance check.** Целевое состояние: в `### 3. Dispatch plan-author subagent` (строки 63-78) inputs включают repo root, а промпт-блок содержит read-only пометку.
  - `grep -niE "repository root|repo root" plugins/superpowers-claude/skills/writing-plans/SKILL.md` → ≥1 строка.
  - `grep -niE "may read|read-only|git diff" plugins/superpowers-claude/skills/writing-plans/SKILL.md` → ≥1 строка (read-only пометка в plan-author промпте).
  - **Behavioral pressure-test (before/after).** Сценарий: plan-author субагент диспатчится. BEFORE: ему не дан repo root, он не знает, что можно читать репо, и либо галлюцинирует пути, либо просит уточнения. AFTER: input включает repo root, а промпт явно разрешает читать/`git diff`, но запрещает коммитить/править — субагент проверяет реальные пути, не выдумывает.
- [ ] **Step H2: verify it currently FAILS (absent).** `grep -niE "repository root|repo root" plugins/superpowers-claude/skills/writing-plans/SKILL.md` → ПУСТО.
- [ ] **Step H3: apply edit.** Два под-правки внутри секции 3.
  1. Anchor — список inputs (строки 63-68), начинающийся «Dispatch a subagent. Give it only:». Текущий список:
     > ```
     > - approved spec path
     > - context-pack path
     > - explicit constraints
     > - required plan directory format
     > ```
     Добавить первым пунктом repo root:
     ```
     - repository root (absolute path)
     - approved spec path
     - context-pack path
     - explicit constraints
     - required plan directory format
     ```
  2. Anchor — `text`-промптблок plan-author (строки 70-78), который начинается «You are writing an implementation plan from saved artifacts.» и заканчивается «add an open question instead of guessing.». Добавить read-only пометку отдельной строкой после «Do not implement code.»:
     > `Do not implement code.`
     →
     > ```
     > Do not implement code.
     > You may read files and run git diff in the repository root to verify paths, symbols, and tests; do not commit or modify anything.
     > ```
- [ ] **Step H4: verify it PASSES.** Повторить grep'ы Step H1. `claude plugin validate /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude` → зелёный. Фронтматтер цел: `grep -nc "^name: writing-plans" plugins/superpowers-claude/skills/writing-plans/SKILL.md` → `1`.

---

## Sub-edit I — Fallback: coordinator-only + эскалация (спека I)

- [ ] **Step I1: acceptance check.** Целевое состояние: `## Fallback` (строки 219-221) ограничен координацией/состоянием; inline-инспекция репо/сниппеты/аудиты/context-pack явно запрещены; если субагент-классовая работа нужна, а Task недоступен — эскалация/hard-stop, НЕ выполнять inline.
  - `grep -niE "coordinator-only|coordination and state" plugins/superpowers-claude/skills/writing-plans/SKILL.md` → ≥1 строка.
  - `grep -niE "escalate|hard-stop|hard stop" plugins/superpowers-claude/skills/writing-plans/SKILL.md` → ≥1 строка.
  - `grep -niE "only when the human partner asks|explicit.*human.*request" plugins/superpowers-claude/skills/writing-plans/SKILL.md` → ≥1 строка (inline только по явному запросу человека, НЕ на недоступности Task).
  - **Behavioral pressure-test (before/after).** Сценарий: Task tool недоступен, нужна инспекция репо для context-pack. BEFORE: по текущему Fallback («If subagents are unavailable ... the main agent may write and review the plan inline») оркестратор сам инспектирует репо и пишет план inline, накапливая контекст. AFTER: оркестратор НЕ делает тяжёлую inline-работу при недоступности Task — он эскалирует/останавливается; inline допустим только координация/состояние и только если человек явно попросил inline.
- [ ] **Step I2: verify it currently FAILS (absent).** `grep -niE "coordinator-only|hard-stop|hard stop" plugins/superpowers-claude/skills/writing-plans/SKILL.md` → ПУСТО; `grep -n "If subagents are unavailable or the human partner asks you to work inline, the main agent may write and review the plan inline" plugins/superpowers-claude/skills/writing-plans/SKILL.md` → находит текущую строку 221.
- [ ] **Step I3: apply edit.** Anchor — заголовок `## Fallback` (строки 219-221). Заменить тело целиком. Текущий текст:
  > ```
  > ## Fallback
  >
  > If subagents are unavailable or the human partner asks you to work inline, the main agent may write and review the plan inline. It must still use the approved spec and context pack as the only source of truth and must not carry brainstorming history into execution.
  > ```
  Новый текст:
  ```
  ## Fallback

  The fallback is coordinator-only. Inline work is limited to coordination and state (dispatching, capturing receipts, writing artifacts) and is allowed only when the human partner explicitly asks you to work inline — never as an automatic response to the Task tool being unavailable.

  Do not perform subagent-class work inline: no repo inspection, no snippet checking, no file audits, no context-pack generation. That work always goes to fresh read-only subagents.

  If subagent-class work (inspection, spec, plan, or review) is needed but the Task tool is genuinely unavailable, escalate to the human partner or hard-stop. Do not substitute the coordinator for a subagent. Whatever runs inline must still use the approved spec and context pack as the only source of truth and must not carry brainstorming history into execution.
  ```
- [ ] **Step I4: verify it PASSES.** Повторить grep'ы Step I1. `claude plugin validate /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude` → зелёный.

---

## Sub-edit L — Branch Context: убрать фантомный выбор ветки (спека L)

- [ ] **Step L1: acceptance check.** Целевое состояние: `## Branch Context` (строка 204) больше не предлагает «ask whether to create a feature branch» — `using-git-branches` авто-создаёт ветку на main/master.
  - `grep -niE "auto-creates|automatically creates|creates a feature branch" plugins/superpowers-claude/skills/writing-plans/SKILL.md` → ≥1 строка.
  - `grep -ni "ask whether to create a feature branch" plugins/superpowers-claude/skills/writing-plans/SKILL.md` → ПУСТО.
  - **Behavioral pressure-test (before/after).** Сценарий: оркестратор на `main`, начинает исполнение. BEFORE: по текущей строке 204 агент спрашивает, создавать ли feature-ветку. AFTER: агент не спрашивает — полагается на `superpowers:using-git-branches`, которая авто-создаёт ветку на main/master.
- [ ] **Step L2: verify it currently FAILS (absent).** `grep -ni "ask whether to create a feature branch" plugins/superpowers-claude/skills/writing-plans/SKILL.md` → находит текущую строку 204.
- [ ] **Step L3: apply edit.** Anchor — `## Branch Context` (строка 204). Заменить предложение про выбор ветки, сохранив ссылку `superpowers:using-git-branches` и пометку про worktree. Текущий текст:
  > `Before execution, use `superpowers:using-git-branches`. Work in the current checkout. If on `main` or `master`, ask whether to create a feature branch or work directly there. Do not create a worktree unless explicitly requested.`
  Новый текст:
  > `Before execution, use `superpowers:using-git-branches`. It auto-creates a feature branch when on `main` or `master`, so do not ask whether to create one — just invoke it and work in the resulting checkout. Do not create a worktree unless explicitly requested.`
- [ ] **Step L4: verify it PASSES.** Повторить grep'ы Step L1. `claude plugin validate /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude` → зелёный. Ссылка `superpowers:using-git-branches` цела: `grep -n "superpowers:using-git-branches" plugins/superpowers-claude/skills/writing-plans/SKILL.md` → одна строка.

---

## Final verification (весь файл, перед коммитом)

- [ ] **Step F1: все sub-edit acceptance grep'ы зелёные** (повтор Step A1/B1/H1/I1/L1).
- [ ] **Step F2: структурная целостность.**
  - `claude plugin validate /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude` → зелёный.
  - Кросс-ссылки целы: `grep -n "superpowers:" plugins/superpowers-claude/skills/writing-plans/SKILL.md` содержит `reviewing-plans`, `subagent-driven-development`, `executing-plans`, `using-git-branches`.
  - Никакого префикса у встроенных: `grep -rnE "superpowers:(code-review|security-review|simplify|verify|run)" plugins/superpowers-claude/skills/writing-plans/SKILL.md` → ПУСТО.
  - Фронтматтер цел: первые две строки тела — `name: writing-plans` и `description:` внутри `---` блока.

---

## Commit

- [ ] **Step C1: commit.**
  ```bash
  git add plugins/superpowers-claude/skills/writing-plans/SKILL.md
  git commit -m "feat(writing-plans): спека — единственный гейт, subagent-driven дефолт, repo-контекст и coordinator-only fallback"
  ```
