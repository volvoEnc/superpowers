# Post-Spec Autonomy — Implementation Plan

> **For agentic workers:** validate with `superpowers:reviewing-plans`, then execute with `superpowers:subagent-driven-development`. Steps use `- [ ]` checkboxes.

**Goal:** Спека = единственный человеческий гейт; после approval оркестратор автономно идёт план→исполнение→security→finishing=PR с макс чистотой контекста.
**Architecture:** Точечные правки 8 SKILL.md + 4 prompt/reference файла + новый per-task-result артефакт, только в `plugins/superpowers-claude/`. Единый контракт `state.json` (в `phase-handoff`) — основа resume и evidence-кеша.
**Spec:** `docs/superpowers/specs/2026-06-24-post-spec-autonomy-design.md`
**Context Pack:** `docs/superpowers/plans/2026-06-24-post-spec-autonomy/context-pack.md`
**Review Mode:** risk-tiered

## Task Index

| Task | Файл | Risk | Depends | Scope |
|------|------|------|---------|-------|
| 001 | `phase-handoff/SKILL.md` | low | — | D (схема-контракт state.json), L (Do-Not-Reload + mid-task resume) — **FOUNDATIONAL** |
| 002 | `writing-plans/SKILL.md` | medium | 001 | A (убрать plan-approval), B (subagent-driven дефолт), H, I, L |
| 003 | `subagent-driven-development/SKILL.md` + prompt-файлы | medium | 001 | C (state+result-файлы), G (лимиты), H, J |
| 004 | `executing-plans/SKILL.md` | medium | 001 | C, E (авто security+critical цикл), G, J, K |
| 005 | `finishing-a-development-branch/SKILL.md` | medium | 001 | D (читать evidence, SHA-сверка), F (PR дефолт+триггеры), K |
| 006 | `verification-before-completion/SKILL.md` | low | 001 | D (писать evidence) |
| 007 | `reviewing-plans/SKILL.md` | low | — | G (1 ре-ревью+эскалация), H, I |
| 008 | `brainstorming/SKILL.md` | low | — | I (inline coordinator-only+эскалация) |
| 009 | `requesting-code-review/code-reviewer.md` | low | — | H (repo-контекст код-ревьюеру) |

**Порядок:** 001 первым (контракт схемы, на него ссылаются 002-006). Затем остальные — каждая правит свой файл, конфликтов нет, параллелизуемо.

## Review Requirements
`reviewing-plans` проверяет: покрытие спеки (A-L), согласованность контракта state.json между файлами, валидность якорей, целостность `superpowers:*`, конкретность лимитов/эскалаций, отсутствие нового человеческого гейта в автономном пути.

## Verification (общая)
- `claude plugin validate plugins/superpowers-claude` зелёный.
- `grep` целостности ссылок; встроенные без префикса; фронтматтер.
- Pressure-test: (a) после спеки нет стопа на approval плана; (b) BLOCKED эскалирует после 2 попыток; (c) Tier-1 авто-security+блок на critical; (d) finishing дефолт PR; (e) resume из state.json.

## Execution Handoff
Subagent-driven по умолчанию. После исполнения — finishing = авто-пуш + PR (автономно, по новой модели).
