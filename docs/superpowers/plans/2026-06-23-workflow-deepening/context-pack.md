# Context Pack — Workflow Deepening

**Spec:** `docs/superpowers/specs/2026-06-23-workflow-deepening-design.md`
**Plugin:** `plugins/superpowers-claude/` (v5.1.0-personal.1, установленный Claude Code вариант)
**New doc:** `plugins/superpowers-claude/docs/review-integration-doctrine.md` (каталог `docs/` создать)

## Repository Map (целевые файлы + якоря вставки)

| Файл (skills/<...>/SKILL.md) | Изменение | Якорь (после какой `##`) |
|------|-----------|--------------------------|
| `brainstorming` | Question Taxonomy; расширить Decision Pack (+Risk Dimensions); смягчить Question Loop Rules (батчинг); coverage в Question Strategist; opt-in multi-angle-analyzer шаг | `Question Loop Rules` (новая секция после); `Decision Pack` (правка шаблона); `Orchestrated Flow` (новый шаг); `Subagent Prompt Shapes` (правка Question Strategist) |
| `verification-before-completion` | Security-Review Risk Tiers; шаблон сбора доказательств; поведенческая verify-строка | после `The Iron Law`; после `Red Flags - STOP`; строка в таблицу `Common Failures` |
| `finishing-a-development-branch` | гейт `/code-review` + риск-тированный `/security-review` | после `Step 1: Verify Tests` |
| `requesting-code-review` | секция «Built-in vs subagent reviewers» → ссылка на доктрину | после вводного абзаца / `When to Request Review` |
| `subagent-driven-development` | риск-тированные `/code-review` + `/simplify` + `/security-review` в per-task цикл | внутри `Per-Task Loop` |
| `executing-plans` | Tier-1 `/security-review` хендофф перед finishing | конец `Step 2` / начало `Step 3` |
| `test-driven-development` | опциональный `/simplify` в REFACTOR | `Red-Green-Refactor` → REFACTOR |
| `dispatching-parallel-agents` | таблица «ручной Task-диспатч vs Workflow» | после `When to Use` |
| `writing-skills` | пред-деплой eval-гейт качества скила | после `STOP: Before Moving to Next Skill` |

## Cross-link Map (не сломать `superpowers:*`)
- `executing-plans` и `subagent-driven-development` → требуют `finishing-a-development-branch`.
- `subagent-driven-development` → `requesting-code-review`, `test-driven-development`, `using-git-branches`.
- `brainstorming` → `using-git-branches`, `phase-handoff`, `writing-plans`.
- `writing-skills` → `test-driven-development`.
- Новые секции ссылаются на доктрину **относительным путём** `../../docs/review-integration-doctrine.md` или по имени; риск-тиры — на секцию в `verification-before-completion`.

## Constraints
- Встроенные механизмы `/code-review`, `/security-review`, `/simplify`, `verify`, `run` — это Claude Code built-ins, ссылаться **без** префикса `superpowers:`.
- Сохранить модель чистого контекста оркестратора; адаптивность (NOT-APPLICABLE / opt-in по риску).
- CSO: не ломать YAML-фронтматтер (`name`, `description` первыми); описания не раздувать.
- Не дублировать контент: длинные правила — ссылкой на доктрину, не копией.
- Все правки только в `superpowers-claude/`. Codex-вариант не трогаем.

## Validation / Test Commands
- `claude plugin validate plugins/superpowers-claude`
- `grep -rn "superpowers:" plugins/superpowers-claude/skills/*/SKILL.md` — кросс-ссылки целы.
- `head -5 <SKILL.md>` — фронтматтер валиден.
- Поведенческий pressure-test: прогон сценария до/после на изменённых скилах (элиситация, гейты).

## Risk Triggers
- Оборванные кросс-ссылки при правке заголовков → grep-проверка после каждой правки.
- Доктрина должна существовать до правок, которые на неё ссылаются (Task 001 первым).
- Риск-тиры — единый источник в `verification-before-completion`; остальные ссылаются (Task 002 рано).
- `writing-skills` уже большой (~656 строк) — новая секция короткая, ссылкой на доктрину.

## Open Questions
- Подтверждение Tier-1 списка и состава таксономии (12) — даны дефолты в спеке.
- Только Claude-вариант в этом раунде (подтверждено).
