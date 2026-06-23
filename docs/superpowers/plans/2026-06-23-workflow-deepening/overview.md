# Workflow Deepening — Implementation Plan

> **For agentic workers:** Before execution, validate with `superpowers:reviewing-plans`, then execute with `superpowers:subagent-driven-development` or `superpowers:executing-plans`. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Углубить персональный воркфлоу superpowers (Claude-вариант) — глубже элиситация + опора на встроенные механизмы Claude Code (`/code-review`, `/security-review`, `/simplify`, `verify`/`run`, Workflow tool).
**Architecture:** Точечные правки 9 SKILL.md + 1 новый reference-doc (доктрина ревью), только в `plugins/superpowers-claude/`. Доктрина и риск-тиры — единые источники, на которые ссылаются остальные правки. Без новых скилов, без переписи на Workflow (отложено).
**Tech Stack:** Markdown skills, YAML frontmatter, `claude plugin` CLI для валидации.
**Spec:** `docs/superpowers/specs/2026-06-23-workflow-deepening-design.md`
**Context Pack:** `docs/superpowers/plans/2026-06-23-workflow-deepening/context-pack.md`
**Review Mode:** risk-tiered

## Task Index

| Task | File | Risk | Depends on | Summary |
|------|------|------|------------|---------|
| 001 | `task-001-review-doctrine.md` | low | — | Создать `docs/review-integration-doctrine.md` (единая модель ревью) |
| 002 | `task-002-verification-before-completion.md` | medium | — | Risk-tiers + шаблон доказательств + поведенческая verify |
| 003 | `task-003-brainstorming.md` | medium | 002 | Question Taxonomy + 12-мерный Decision Pack + батчинг + coverage + multi-angle analyzer (opt-in по риску) |
| 004 | `task-004-finishing-branch.md` | medium | 001, 002 | Гейт `/code-review` + риск-тированный `/security-review` |
| 005 | `task-005-requesting-code-review.md` | low | 001 | Секция «built-in vs subagent reviewers» → доктрина |
| 006 | `task-006-subagent-driven-development.md` | medium | 001, 002 | Риск-тированное встроенное ревью в per-task цикл |
| 007 | `task-007-executing-plans.md` | low | 002 | Tier-1 `/security-review` хендофф перед finishing |
| 008 | `task-008-test-driven-development.md` | low | 001 | Опциональный `/simplify` в REFACTOR |
| 009 | `task-009-dispatching-parallel-agents.md` | low | — | Таблица «ручной Task-диспатч vs Workflow» |
| 010 | `task-010-writing-skills.md` | low | 001 | Пред-деплой eval-гейт качества скила |

**Порядок (обязателен):** 001 (доктрина + каталог `docs/`) и 002 (Risk Tiers) ДОЛЖНЫ быть завершены ДО задач 003, 004, 006, 007, 008, 010 — они ссылаются на доктрину и/или риск-тиры. Иначе вставляются висячие ссылки. Задачи 005 и 009 от 001/002 не зависят критично (005 ссылается на доктрину → после 001). После 001/002 остальные правят каждая свой файл → конфликтов правки нет, можно параллелить.

## Review Requirements
Plan review (`superpowers:reviewing-plans`) проверяет: покрытие спеки, отсутствие лишнего объёма, валидность якорей вставки против текущих файлов, корректность кросс-ссылок (`superpowers:*` и доктрина), конкретность верификации, обработку риска для medium-задач. Любой блокирующий issue останавливает исполнение.

## Branch Context
Уже на ветке `chore/workflow-deepening`. Работа в текущем checkout, без worktree. Перед исполнением — `superpowers:using-git-branches` (implementation-start) для базовой проверки.

## Verification (общая для всех задач)
- `claude plugin validate plugins/superpowers-claude` — зелёный.
- `grep -rn "superpowers:" plugins/superpowers-claude/skills/*/SKILL.md` — все ссылки на существующие скилы.
- Изменённый SKILL.md: фронтматтер цел (`head -5`), нет оборванных секций.
- Поведенческие задачи (003, 004, 006): pressure-test до/после, доказывающий новое поведение.

## Global validation (после ВСЕХ задач)
- Доктрина существует: `test -f plugins/superpowers-claude/docs/review-integration-doctrine.md && echo OK`.
- Нет висячих ссылок на доктрину: для каждого SKILL.md, упоминающего `review-integration-doctrine.md`, относительный путь резолвится (`test -f` от каталога скила).
- Встроенные механизмы НЕ имеют префикса `superpowers:`: `grep -rnE "superpowers:(code-review|security-review|simplify|verify|run)" plugins/superpowers-claude/skills` → пусто.
- `claude plugin validate plugins/superpowers-claude` зелёный; `claude plugin details` показывает 17 скилов.

## Pressure-Test Protocol (для задач 003, 004, 006)
- Сценарий формулируется ДО правки (что агент должен начать делать после неё).
- Baseline: зафиксировать поведение на текущем (до-правочном) тексте скила (ожидаемо — старое поведение).
- After: применить правку, прогнать тот же сценарий, зафиксировать новое поведение.
- Доказательство — текстовая фиксация «до/после» (не скриншот): напр. для 003 — brainstorming задаёт многоугловой батч вопросов; для 004 — finishing не предлагает merge без отчёта `/code-review`.

## Execution Handoff
После ревью плана и одобрения human — выбор:
1. **Subagent-Driven** — свежий субагент на задачу с ревью между задачами.
2. **Inline Execution** — исполнение в этой сессии с чекпойнтами.
