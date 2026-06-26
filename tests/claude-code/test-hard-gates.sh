#!/usr/bin/env bash
# Guard test for the subagent-driven inline-slide hardening (fix/subagent-driven-hard-gates).
#
# Behavior-shaping content is "code that shapes agent behavior" — a careless future reword could silently
# delete a load-bearing gate, carve-out, or the user-override pointer and pass unnoticed. This test pins
# the invariants the fix depends on so any such drift fails loudly. It is a TEXTUAL guard (grep), not a
# behavioral eval — the before/after eval evidence lives in the PR.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SK="$REPO_ROOT/plugins/superpowers-claude/skills"

SD="$SK/subagent-driven-development/SKILL.md"
US="$SK/using-superpowers/SKILL.md"
WP="$SK/writing-plans/SKILL.md"
RP="$SK/reviewing-plans/SKILL.md"
BR="$SK/brainstorming/SKILL.md"

FAILS=0
have() {  # have <file> <fixed-string> <desc>
  if [ -f "$1" ] && grep -qF -- "$2" "$1"; then
    echo "  [PASS] $3"
  else
    echo "  [FAIL] $3 (не найдено: $2)"; FAILS=$((FAILS + 1))
  fi
}

echo "=== subagent-driven-development: Hard Gates + Token section ==="
have "$SD" "## Hard Gates" "есть секция Hard Gates"
have "$SD" "## Token Cost Is Not A Reason To Go Inline" "есть секция про токены"
have "$SD" "five-line pure function is dispatched exactly like a five-hundred-line one" "размер не ось (5 строк = 500 строк)"
# the five numbered gates — distinctive phrase of each
have "$SD" "Do not hand-author an implementation Write or Edit" "Gate 1: запрет ручной правки исходника"
have "$SD" "too small/simple/cheap to dispatch" "Gate 2: размер не исключение"
have "$SD" "I already have the context" "Gate 3: ловушка готового контекста"
have "$SD" "consciously and explicitly switched" "Gate 4: осознанный переход в executing-plans"
have "$SD" "before the first implementation edit" "Gate 5: выбор до первой правки"
# carve-out: gates must never forbid the skill's own mechanical-review step
have "$SD" "/code-review --fix" "carve-out для built-in mechanical review"
# user-override pointer must survive
have "$SD" "do not override a direct human instruction" "сохранён приоритет команды человека"

echo "=== using-superpowers: rule #2 + execution-time Red Flags ==="
have "$US" "task size is irrelevant" "правило №2: размер нерелевантен"
have "$US" "Before your first hand-authored Write/Edit" "bootstrap-клауза про осознанный вход в навык"
have "$US" "I already have the context, inline is cheaper" "Red Flag: уже есть контекст"
have "$US" "just one small function" "Red Flag: всего одна мелкая функция"
have "$US" "Red flags fire DURING execution too" "Red Flag: флаги срабатывают во время исполнения"

echo "=== Clean Context Contract на патч-шагах ==="
have "$WP" "Patching obeys the Clean Context Contract too" "writing-plans: патч под Clean Context Contract"
have "$RP" "The patch step obeys the Clean Context Contract" "reviewing-plans: патч под Clean Context Contract"
have "$BR" "source files or full task files pulled in to apply a review/patch finding" "brainstorming: пункт в каноничном списке"

echo
if [ "$FAILS" -eq 0 ]; then
  echo "ВСЕ ИНВАРИАНТЫ НА МЕСТЕ"
  exit 0
else
  echo "ПРОВАЛЕНО ИНВАРИАНТОВ: $FAILS"
  exit 1
fi
