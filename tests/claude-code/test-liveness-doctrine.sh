#!/usr/bin/env bash
# Test: liveness-doctrine consistency checks (spec §11.7) + verification-before-completion zero-change guard
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"
fail=0

echo "=== Test: liveness-doctrine consistency ==="

# 1. Field shapes single-sourced in phase-handoff: every skill file (other than phase-handoff)
#    that mentions a shape field must NOT define the shape. Cheap proxy: only phase-handoff may
#    contain the JSON shape keys ("kind":, "output_path":, "dispatched_at":, "restarts":).
leak=$(grep -rln '"kind":\|"output_path":\|"dispatched_at":\|"restarts":' plugins/superpowers-claude/skills/ | grep -v 'phase-handoff/SKILL.md' || true)
if [ -z "$leak" ]; then echo "  [PASS] no state.json shape leak outside phase-handoff"; else echo "  [FAIL] shape leak in: $leak"; fail=1; fi

# 2. phase-handoff actually defines the new fields.
if grep -q "inflight" plugins/superpowers-claude/skills/phase-handoff/SKILL.md \
   && grep -q "deadline_s" plugins/superpowers-claude/skills/phase-handoff/SKILL.md \
   && grep -q "promoted" plugins/superpowers-claude/skills/phase-handoff/SKILL.md; then
  echo "  [PASS] phase-handoff defines inflight/deadline_s/promoted"; else echo "  [FAIL] phase-handoff missing new fields"; fail=1; fi

# 3. Risk tiers not redefined outside verification-before-completion: the tier table header
#    ("/security-review" + "Areas") appears only there.
tierdefs=$(grep -rln "| \*\*Tier 1\*\* |" plugins/superpowers-claude/skills/ docs/ plugins/superpowers-claude/docs/ 2>/dev/null | grep -v 'verification-before-completion/SKILL.md' || true)
if [ -z "$tierdefs" ]; then echo "  [PASS] risk-tier table only in verification-before-completion"; else echo "  [FAIL] tier table redefined in: $tierdefs"; fail=1; fi

# 4. Built-in tools referenced bare (no superpowers: prefix) in the doctrine doc.
if grep -qE "superpowers:(TaskGet|TaskStop|Monitor|ScheduleWakeup)" plugins/superpowers-claude/docs/liveness-doctrine.md; then
  echo "  [FAIL] built-in tool carries superpowers: prefix in doctrine"; fail=1; else echo "  [PASS] built-in tools bare in doctrine"; fi

# 5. verification-before-completion is unchanged vs HEAD's base (ZERO-change, spec §9/§11.7).
#    The committed file must equal its pre-feature version. Use git diff against the merge-base with main.
#    Remediation if non-empty (FAIL): the file is a strictly read-only Tier-1 vocabulary source (spec §9).
#    Revert it to its pre-feature version and re-run:
#      git checkout "$(git merge-base main HEAD)" -- plugins/superpowers-claude/skills/verification-before-completion/SKILL.md
#    then confirm the diff is empty. No task in this plan may modify this file.
vbc=plugins/superpowers-claude/skills/verification-before-completion/SKILL.md
base="$(git merge-base main HEAD 2>/dev/null || git merge-base origin/main HEAD 2>/dev/null || true)"
if [ -z "$base" ]; then
  echo "  [SKIP] verification-before-completion diff guard — no local main/origin/main ref to diff against (shallow/CI clone); absence of a base is not evidence of modification"
elif git diff --quiet "$base" -- "$vbc"; then
  echo "  [PASS] verification-before-completion unchanged"
else
  echo "  [FAIL] verification-before-completion was modified"; fail=1
fi

# 6. The four editing skills reference the doctrine doc (additive, not duplicate).
for f in dispatching-parallel-agents subagent-driven-development executing-plans finishing-a-development-branch; do
  if grep -q "liveness-doctrine.md" "plugins/superpowers-claude/skills/$f/SKILL.md"; then
    echo "  [PASS] $f references liveness-doctrine.md"; else echo "  [FAIL] $f missing doctrine reference"; fail=1; fi
done

# 7. Additive-only: the existing content-triggered limit text survives.
if grep -q "max 2 fix-attempts" plugins/superpowers-claude/skills/subagent-driven-development/SKILL.md; then
  echo "  [PASS] existing max-2-fix-attempts limit preserved"; else echo "  [FAIL] content-triggered limit removed"; fail=1; fi

# 8. Acceptance criterion 2 (wall-clock floor on resume) — the stale fixture is over G×deadline_s.
if ! python3 - "$REPO_ROOT/tests/claude-code/fixtures/state-inflight-stale.json" <<'PY'
import json,sys
from datetime import datetime, timezone
d=json.load(open(sys.argv[1]))
e=d["inflight"][0]
dispatched=datetime.fromisoformat(e["dispatched_at"].replace("Z","+00:00"))
G=2  # grace multiplier default (tunable) — used only to compute the fixture's "stale" property
elapsed=(datetime.now(timezone.utc)-dispatched).total_seconds()
assert elapsed > G*e["deadline_s"], f"fixture not stale: {elapsed} <= {G*e['deadline_s']}"
print("  [PASS] stale fixture exceeds G*deadline_s (resume floor would fire)")
PY
then echo "  [FAIL] stale-fixture floor check (criterion §11.2)"; fail=1; fi

# 9. Acceptance criterion 3 (promotion rule) + output_path constraint — checked over ALL fresh entries
#    (positive + negative + signal-less) as STRUCTURAL invariants, not the tunable constant values.
if ! python3 - "$REPO_ROOT/tests/claude-code/fixtures/state-inflight-fresh.json" <<'PY'
import json,sys
T_PROMOTE=300  # promotion threshold default (tunable) — used only to check the PR-2 structural invariant
d=json.load(open(sys.argv[1]))
entries=d["inflight"]
assert len(entries) >= 3, "fresh fixture must exercise promote + sync + signal-less cases"
saw_promoted=saw_sync=False
for e in entries:
    kind, promoted, out = e["kind"], e["promoted"], e["output_path"]
    # promotion rule (structural): a promoted unit is never plain sync; a sync unit is never promoted
    if promoted:
        assert kind != "sync", f"promoted unit must be background, got {kind}"
        saw_promoted=True
    if kind == "sync":
        assert promoted is False, "sync unit must not be promoted"
        assert out is None, "sync unit must have output_path null"
        saw_sync=True
    # PR-2: a unit whose deadline_s exceeds T_promote must be promoted
    if e["deadline_s"] > T_PROMOTE:
        assert promoted is True, "deadline_s > T_promote must promote (PR-2)"
    # output_path constraint: bg-bash always writes an output file; bg-agent may be signal-less (null ok)
    if kind == "bg-bash":
        assert out is not None, "bg-bash must have an output_path"
assert saw_promoted and saw_sync, "fixture must cover both the promoted and the sync (negative) cases"
print("  [PASS] promotion + output_path structural invariants hold across all entries")
PY
then echo "  [FAIL] promotion/output_path structural check (criterion §11.3)"; fail=1; fi

if [ "$fail" -ne 0 ]; then echo "=== FAILURES ==="; exit 1; fi
echo "=== All liveness-doctrine consistency checks passed ==="
