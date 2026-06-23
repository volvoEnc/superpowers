# Task 008: /simplify заметка в фазе REFACTOR (test-driven-development)

**Risk:** low
**Depends on:** 001
**Review policy:** group
**Files:**
- Modify: plugins/superpowers-claude/skills/test-driven-development/SKILL.md

## Контекст

Spec item 4 / acceptance criterion 8: в фазе REFACTOR добавить короткую ОПЦИОНАЛЬНУЮ заметку — после green можно прогнать встроенный `/simplify` для авто-детекта дублирования и упрощения имён на крупных рефакторах, затем подтвердить, что тесты остаются зелёными. Явно: `/simplify` — только качество (не ищет баги); для корректности использовать `/code-review` отдельно. Кратко, со ссылкой на доктрину. `/simplify` и `/code-review` — встроенные механизмы Claude Code, БЕЗ префикса `superpowers:`.

Якорь правки (реальный текущий текст файла, секция `## Red-Green-Refactor` → подсекция REFACTOR, строки 185-192):

```
### REFACTOR - Clean Up

After green only:
- Remove duplication
- Improve names
- Extract helpers

Keep tests green. Don't add behavior.
```

Доктрина создана task 001 по пути `plugins/superpowers-claude/docs/review-integration-doctrine.md`. Из `skills/test-driven-development/SKILL.md` относительный путь — `../../docs/review-integration-doctrine.md`.

## Steps

- [ ] Step 1: Определить acceptance-check. Новая заметка считается на месте, если в файле есть упоминание `/simplify` именно в подсекции REFACTOR с пометкой про качество-only. Команда:
  ```
  grep -nE '/simplify|review-integration-doctrine' plugins/superpowers-claude/skills/test-driven-development/SKILL.md
  ```
  Ожидаемый результат ПОСЛЕ правки: минимум две строки — одна с `/simplify`, одна со ссылкой `../../docs/review-integration-doctrine.md`. Дополнительно проверить, что упоминание `/simplify` идёт без префикса `superpowers:`:
  ```
  grep -n 'superpowers:simplify\|superpowers:/simplify\|superpowers:code-review' plugins/superpowers-claude/skills/test-driven-development/SKILL.md
  ```
  Ожидаемый результат: пусто (exit code 1) — встроенные механизмы без префикса.

- [ ] Step 2: Убедиться, что check сейчас ПРОВАЛИВАЕТСЯ (заметка отсутствует). Команда:
  ```
  grep -nE '/simplify|review-integration-doctrine' plugins/superpowers-claude/skills/test-driven-development/SKILL.md
  ```
  Ожидаемый результат: пусто, exit code 1 (в файле сейчас нет ни `/simplify`, ни ссылки на доктрину).

- [ ] Step 3: Применить правку. В файле `plugins/superpowers-claude/skills/test-driven-development/SKILL.md` найти подсекцию REFACTOR (строки 185-192) и заменить точный блок:

  СТАРЫЙ блок (заменить):
  ```
  ### REFACTOR - Clean Up

  After green only:
  - Remove duplication
  - Improve names
  - Extract helpers

  Keep tests green. Don't add behavior.
  ```

  НОВЫЙ блок (вставить вместо него):
  ```
  ### REFACTOR - Clean Up

  After green only:
  - Remove duplication
  - Improve names
  - Extract helpers

  Keep tests green. Don't add behavior.

  **Optional (larger refactors):** after green, run `/simplify` to auto-detect
  duplication and simplify names, then re-run tests and confirm they stay green.
  `/simplify` is quality-only — it does NOT hunt for bugs. For correctness, run
  `/code-review` separately. Both are Claude Code built-ins; see
  [review-integration-doctrine](../../docs/review-integration-doctrine.md).
  ```

  Требования к вставке: заметка короткая (один абзац); `/simplify` и `/code-review` без префикса `superpowers:`; ссылка на доктрину относительным путём `../../docs/review-integration-doctrine.md`; не трогать YAML-фронтматтер (строки 1-4: `name`, `description`); не менять диаграмму `dot` и остальные подсекции.

- [ ] Step 4: Убедиться, что check теперь ПРОХОДИТ.
  ```
  grep -nE '/simplify|review-integration-doctrine' plugins/superpowers-claude/skills/test-driven-development/SKILL.md
  ```
  Ожидаемый результат: строки с `/simplify` и со ссылкой `../../docs/review-integration-doctrine.md`.
  Проверить отсутствие префикса (должно быть пусто):
  ```
  grep -n 'superpowers:simplify\|superpowers:code-review' plugins/superpowers-claude/skills/test-driven-development/SKILL.md
  ```
  Проверить целостность фронтматтера (первые 4 строки = `---` / `name:` / `description:` / `---`):
  ```
  head -5 plugins/superpowers-claude/skills/test-driven-development/SKILL.md
  ```
  Проверить, что внутренние кросс-ссылки `superpowers:*` целы (заметка не должна была их затронуть):
  ```
  grep -rn "superpowers:" plugins/superpowers-claude/skills/test-driven-development/SKILL.md
  ```
  Ожидаемый результат: без изменений относительно baseline (в этом файле кросс-ссылок `superpowers:*` нет — пусто; задача их не вводит).
  Проверить, что относительная ссылка резолвится в существующий файл доктрины:
  ```
  test -f plugins/superpowers-claude/docs/review-integration-doctrine.md && echo OK
  ```
  Ожидаемый результат: `OK` (файл создан task 001).
  Валидация плагина:
  ```
  claude plugin validate plugins/superpowers-claude
  ```
  Ожидаемый результат: зелёный (валидно, без ошибок).

- [ ] Step 5: Закоммитить.
  ```
  git add plugins/superpowers-claude/skills/test-driven-development/SKILL.md
  git commit -m "feat(tdd): опциональный /simplify в фазе REFACTOR со ссылкой на доктрину ревью"
  ```
