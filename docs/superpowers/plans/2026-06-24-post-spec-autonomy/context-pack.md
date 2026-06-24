# Context Pack — Post-Spec Autonomy

**Spec:** `docs/superpowers/specs/2026-06-24-post-spec-autonomy-design.md`
**Plugin:** `plugins/superpowers-claude/`
**Goal:** спека = единственный гейт; после approval — автономный прогон до PR; макс чистота контекста оркестратора.

## SHARED CONTRACT — расширенная схема `state.json` (единый источник: `phase-handoff`)

Все скилы используют ОДНУ схему (определяется в `phase-handoff`, остальные ссылаются, НЕ переопределяют). Существующие поля (`run_id, current_phase, next_phase, spec, plan, context_pack, review_receipt, current_task, completed_tasks, blocked_tasks, last_green_commit, next_action`) дополняются:

```json
{
  "plan_risk_tier": "Tier-1 | Tier-2 | Tier-3",
  "test_results":          { "summary": "34/34", "exit_code": 0, "commit": "<sha>", "timestamp": "<iso>" },
  "code_review_verdict":   { "verdict": "clean | issues-found | blocked", "effort": "medium", "commit": "<sha>", "timestamp": "<iso>" },
  "security_review_status":{ "required": true, "verdict": "clean | critical-open | n/a", "commit": "<sha>", "timestamp": "<iso>" }
}
```

**Правило кеша (для `finishing`):** вердикт валиден только если его `commit` == текущий HEAD SHA. Иначе перезапустить. Любой новый коммит инвалидирует кеш.

## File → Scope map (правки группированы ПО ФАЙЛУ — параллельная правка безопасна)

| Файл | Пункты спеки |
|------|--------------|
| `phase-handoff/SKILL.md` | D (схема-контракт ↑), L (Do-Not-Reload + mid-task resume) — **FOUNDATIONAL** |
| `writing-plans/SKILL.md` | A (убрать plan-approval гейт), B (subagent-driven дефолт, убрать «Which approach?»), H (repo-контекст plan-author), I (inline coordinator-only), L (branch doc) |
| `subagent-driven-development/SKILL.md` (+ `implementer-prompt.md`, `spec-reviewer-prompt.md`, `code-quality-reviewer-prompt.md`) | C (write state + per-task result files — **новый артефакт** `docs/superpowers/runs/<run>/task-NNN-result.md`), G (лимиты циклов/эскалация), H (repo-контекст в промптах), J (load-and-discard) |
| `executing-plans/SKILL.md` | C (write state), E (авто security + critical fix-цикл), G (тест-фейл лимиты), J (load-and-discard), K (передать риск-тир в finishing) |
| `finishing-a-development-branch/SKILL.md` | D (читать evidence, SHA-сверка → пропуск/перезапуск), F (дефолт PR + триггеры меню), K (принять риск-тир) |
| `verification-before-completion/SKILL.md` | D (писать evidence в state.json) |
| `reviewing-plans/SKILL.md` | G (1 раунд ре-ревью + эскалация), H (repo-контекст ревьюеру), I (inline coordinator-only) |
| `brainstorming/SKILL.md` | I (inline coordinator-only + эскалация) |
| `requesting-code-review/code-reviewer.md` | H (repo-контекст для код-ревьюера) |

## Лимиты (из спеки G — дефолты)
- 2 fix-попытки/задача → эскалация (`approved-amended-plan` | `human-decision-required` | `task-removed`).
- reviewing-plans: 1 раунд edit-and-re-review/receipt → эскалация новых блокеров.
- тесты: 1 ре-ран на флаки + 1 fix-and-retest цикл (`systematic-debugging`) → эскалация.
- impl-wrong → ре-диспатч с fix-scope (в лимите); plan-wrong → эскалация.

## Constraints
- Встроенные `/code-review`, `/security-review`, `/simplify`, `verify`, `run` — БЕЗ префикса `superpowers:`.
- Единые источники: схема state (`phase-handoff`), риск-тиры (`verification-before-completion`), доктрина ревью.
- Не дублировать; ссылаться. Сохранить адаптивность и чистоту контекста.
- Все правки только в `superpowers-claude/`. `superpowers:*` ссылки целы. Фронтматтер цел.

## Validation
- `claude plugin validate /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude`
- `grep -rn "superpowers:" .../skills/*/SKILL.md` — ссылки целы.
- `grep -rnE "superpowers:(code-review|security-review|simplify|verify|run)"` — пусто.
- Pressure-test ключевых правок (см. спеку Testing).
