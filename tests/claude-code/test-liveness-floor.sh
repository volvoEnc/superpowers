#!/usr/bin/env bash
# Test: liveness-floor.sh — detect-only wall-clock floor over inflight[] (spec §4.4 / §5.2).
# TDD: this test is written FIRST (RED) and must FAIL until
# plugins/superpowers-claude/scripts/liveness-floor.sh exists (task-002 turns it GREEN).
#
# Determinism: "now"/grace/staleness-window are injected via env so the test never
# depends on the system clock:
#   LIVENESS_NOW      — ISO-8601 instant treated as "now"
#   LIVENESS_G        — grace multiplier (default 2)
#   LIVENESS_S_BASH   — bg-bash mtime staleness window in seconds (default 120)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"
fail=0

SCRIPT=plugins/superpowers-claude/scripts/liveness-floor.sh
DOCTRINE=plugins/superpowers-claude/docs/liveness-doctrine.md

# Scratch dir for synthetic state files / output files (read-only fixtures stay untouched).
WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; rm -f /tmp/pwned; }
trap cleanup EXIT

echo "=== Test: liveness-floor ==="

# Build a state.json from a JSON string in $WORK; echoes the path.
# Input is parsed with json.loads (no eval) — safe even though the JSON here is test-authored.
# Usage: make_state '<json string evaluating to an object>'
make_state() {
  local json="$1"
  local out="$WORK/state-$RANDOM-$RANDOM.json"
  python3 - "$out" "$json" <<'PY'
import json, sys
out, raw = sys.argv[1], sys.argv[2]
st = json.loads(raw)          # round-trip validates the literal; no eval
open(out, "w").write(json.dumps(st))
PY
  printf '%s' "$out"
}

# Set mtime of a file to (LIVENESS_NOW - age_seconds), portably, via python os.utime.
set_mtime_age() {
  local path="$1" now_iso="$2" age="$3"
  python3 - "$path" "$now_iso" "$age" <<'PY'
import os, sys
from datetime import datetime, timezone
path, now_iso, age = sys.argv[1], sys.argv[2], float(sys.argv[3])
now = datetime.fromisoformat(now_iso.replace("Z", "+00:00"))
ts = now.timestamp() - age
os.utime(path, (ts, ts))
PY
}

# ---------------------------------------------------------------------------
# Check 1: script exists and is executable (RED anchor).
# Until task-002 writes the script, this FAILS and fails the whole test.
# ---------------------------------------------------------------------------
if [ -x "$SCRIPT" ]; then
  echo "  [PASS] script exists and is executable"
else
  echo "  [FAIL] script missing or not executable: $SCRIPT (expected RED before task-002)"
  fail=1
fi

# ---------------------------------------------------------------------------
# Check 2: stale fixture -> prints STALE for task-003-name.md.
# ---------------------------------------------------------------------------
if [ -x "$SCRIPT" ]; then
  out="$(LIVENESS_NOW=2026-06-26T00:00:00Z bash "$SCRIPT" \
        tests/claude-code/fixtures/state-inflight-stale.json 2>/dev/null || true)"
  if printf '%s\n' "$out" | grep -q '^STALE task-003-name.md'; then
    echo "  [PASS] stale fixture prints STALE for task-003-name.md"
  else
    echo "  [FAIL] stale fixture did not print STALE task-003-name.md; got: $out"
    fail=1
  fi
else
  echo "  [FAIL] check 2 skipped — script missing (RED)"
  fail=1
fi

# ---------------------------------------------------------------------------
# Check 3: fresh -> no STALE line. Two sub-cases that are BOTH internally consistent
# with the literal contract (elapsed > G*deadline_s applies to every entry, including
# kind=sync — confirmed against doctrine §4.4 and the spec's "Логика" section).
#
#   3a) The real fresh fixture at the spec's now=2026-06-24T10:00:00Z (acceptance
#       criterion 3, "now близко к dispatched_at"): every elapsed is within budget.
#       (Note: now=10:11:00Z would make task-004 (sync, deadline_s=120) genuinely
#        stale — elapsed 360 > budget 240 — so that instant is NOT a valid "all fresh"
#        witness. The spec instant is.)
#   3b) A synthetic entry with a strictly POSITIVE elapsed comfortably inside budget,
#       so freshness is proven by real headroom to the deadline, not by negative time.
# ---------------------------------------------------------------------------
if [ -x "$SCRIPT" ]; then
  out="$(LIVENESS_NOW=2026-06-24T10:00:00Z bash "$SCRIPT" \
        tests/claude-code/fixtures/state-inflight-fresh.json 2>/dev/null || true)"
  if printf '%s\n' "$out" | grep -q '^STALE'; then
    echo "  [FAIL] 3a fresh fixture unexpectedly printed STALE; got: $out"
    fail=1
  else
    echo "  [PASS] 3a fresh fixture (now=spec 10:00) prints no STALE"
  fi

  # 3b: dispatched_at=10:00:00Z, now=10:01:00Z -> elapsed 60s, deadline_s=600 -> budget 1200.
  # Positive elapsed, far from stale: freshness by headroom, not by negative time.
  st_fresh_pos="$(make_state '{"inflight":[{"task":"fresh-pos.md","kind":"bg-agent","promoted":true,"deadline_s":600,"dispatched_at":"2026-06-24T10:00:00Z","last_progress_at":"2026-06-24T10:00:00Z","output_path":null,"restarts":0}]}')"
  out_fp="$(LIVENESS_NOW=2026-06-24T10:01:00Z bash "$SCRIPT" "$st_fresh_pos" 2>/dev/null || true)"
  if printf '%s\n' "$out_fp" | grep -q '^STALE'; then
    echo "  [FAIL] 3b positive-elapsed-within-budget printed STALE; got: $out_fp"
    fail=1
  else
    echo "  [PASS] 3b positive elapsed (60s) within budget (1200s) -> no STALE"
  fi
else
  echo "  [FAIL] check 3 skipped — script missing (RED)"
  fail=1
fi

# ---------------------------------------------------------------------------
# Check 4: behavioral guard of constants (NO env override of G / S_bash).
#   G boundary at budget = 2 x deadline_s (deadline_s=100 -> budget 200):
#     elapsed 201s -> STALE, 199s -> empty  (proves multiplier is exactly 2).
#   bg-bash mtime boundary at S_bash=120:
#     output mtime age 121s -> STALE, 119s -> empty (proves threshold 120).
# ---------------------------------------------------------------------------
if [ -x "$SCRIPT" ]; then
  GUARD_NOW=2026-06-24T12:00:00Z
  # G boundary: dispatched_at = now - elapsed; deadline_s=100 -> budget=200 at G=2.
  # 201s before noon = 11:56:39Z ; 199s before noon = 11:56:41Z.
  st_g_stale="$(make_state '{"inflight":[{"task":"g-stale.md","kind":"bg-agent","promoted":true,"deadline_s":100,"dispatched_at":"2026-06-24T11:56:39Z","last_progress_at":"2026-06-24T11:56:39Z","output_path":null,"restarts":0}]}')"
  st_g_fresh="$(make_state '{"inflight":[{"task":"g-fresh.md","kind":"bg-agent","promoted":true,"deadline_s":100,"dispatched_at":"2026-06-24T11:56:41Z","last_progress_at":"2026-06-24T11:56:41Z","output_path":null,"restarts":0}]}')"

  out_gs="$(LIVENESS_NOW="$GUARD_NOW" bash "$SCRIPT" "$st_g_stale" 2>/dev/null || true)"
  out_gf="$(LIVENESS_NOW="$GUARD_NOW" bash "$SCRIPT" "$st_g_fresh" 2>/dev/null || true)"

  if printf '%s\n' "$out_gs" | grep -q '^STALE g-stale.md'; then
    echo "  [PASS] G-guard: elapsed 201s > 2x100 -> STALE"
  else
    echo "  [FAIL] G-guard: elapsed 201s should be STALE (budget 200); got: $out_gs"
    fail=1
  fi
  if printf '%s\n' "$out_gf" | grep -q '^STALE'; then
    echo "  [FAIL] G-guard: elapsed 199s should be fresh (budget 200); got: $out_gf"
    fail=1
  else
    echo "  [PASS] G-guard: elapsed 199s < 2x100 -> fresh"
  fi

  # S_bash boundary: bg-bash with an EXISTING output file whose mtime age straddles 120s.
  # Keep dispatched_at well within wall-clock budget so the mtime rule (not deadline) decides.
  bash_dispatched=2026-06-24T11:59:00Z   # 60s before now, deadline_s=600 -> budget 1200, far from stale
  out_stale_file="$WORK/bg-stale.log"
  out_fresh_file="$WORK/bg-fresh.log"
  : > "$out_stale_file"
  : > "$out_fresh_file"
  set_mtime_age "$out_stale_file" "$GUARD_NOW" 121
  set_mtime_age "$out_fresh_file" "$GUARD_NOW" 119

  st_s_stale="$(make_state "{\"inflight\":[{\"task\":\"s-stale.md\",\"kind\":\"bg-bash\",\"promoted\":true,\"deadline_s\":600,\"dispatched_at\":\"$bash_dispatched\",\"last_progress_at\":\"$bash_dispatched\",\"output_path\":\"$out_stale_file\",\"restarts\":0}]}")"
  st_s_fresh="$(make_state "{\"inflight\":[{\"task\":\"s-fresh.md\",\"kind\":\"bg-bash\",\"promoted\":true,\"deadline_s\":600,\"dispatched_at\":\"$bash_dispatched\",\"last_progress_at\":\"$bash_dispatched\",\"output_path\":\"$out_fresh_file\",\"restarts\":0}]}")"

  out_ss="$(LIVENESS_NOW="$GUARD_NOW" bash "$SCRIPT" "$st_s_stale" 2>/dev/null || true)"
  out_sf="$(LIVENESS_NOW="$GUARD_NOW" bash "$SCRIPT" "$st_s_fresh" 2>/dev/null || true)"

  if printf '%s\n' "$out_ss" | grep -q '^STALE s-stale.md'; then
    echo "  [PASS] S_bash-guard: mtime age 121s > 120 -> STALE"
  else
    echo "  [FAIL] S_bash-guard: mtime age 121s should be STALE; got: $out_ss"
    fail=1
  fi
  if printf '%s\n' "$out_sf" | grep -q '^STALE'; then
    echo "  [FAIL] S_bash-guard: mtime age 119s should be fresh; got: $out_sf"
    fail=1
  else
    echo "  [PASS] S_bash-guard: mtime age 119s < 120 -> fresh"
  fi

  # Textual guard (EARLY signal only — behavior above is authoritative):
  # default forms in the script must match the doctrine numbers.
  if grep -Fq '${LIVENESS_G:-2}' "$SCRIPT" && grep -Fq '${LIVENESS_S_BASH:-120}' "$SCRIPT"; then
    echo "  [PASS] textual guard: default forms \${LIVENESS_G:-2} / \${LIVENESS_S_BASH:-120} present"
  else
    echo "  [FAIL] textual guard: default forms for G/S_bash not found in script"
    fail=1
  fi
  if grep -q 'G.*дефолт 2×\|G.*=2' "$DOCTRINE" && grep -q 'S_bash.*дефолт.*120\|120 s' "$DOCTRINE"; then
    echo "  [PASS] textual guard: doctrine numbers (G=2 / S_bash=120) in place"
  else
    echo "  [FAIL] textual guard: doctrine numbers not found in $DOCTRINE"
    fail=1
  fi
else
  echo "  [FAIL] check 4 skipped — script missing (RED)"
  fail=1
fi

# ---------------------------------------------------------------------------
# Check 5: negative elapsed (dispatched_at in the future vs now) -> NOT stale, no crash.
# ---------------------------------------------------------------------------
if [ -x "$SCRIPT" ]; then
  st_neg="$(make_state '{"inflight":[{"task":"future.md","kind":"bg-agent","promoted":true,"deadline_s":120,"dispatched_at":"2026-06-24T10:10:00Z","last_progress_at":"2026-06-24T10:10:00Z","output_path":null,"restarts":0}]}')"
  if out="$(LIVENESS_NOW=2026-06-24T10:00:00Z bash "$SCRIPT" "$st_neg" 2>/dev/null)"; then
    neg_exit=0
  else
    neg_exit=$?
  fi
  if [ "$neg_exit" -eq 0 ] && ! printf '%s\n' "$out" | grep -q '^STALE'; then
    echo "  [PASS] negative elapsed -> not stale, exit 0"
  else
    echo "  [FAIL] negative elapsed mishandled (exit=$neg_exit, out=$out)"
    fail=1
  fi
else
  echo "  [FAIL] check 5 skipped — script missing (RED)"
  fail=1
fi

# ---------------------------------------------------------------------------
# Check 6: no shell injection via output_path.
# Payloads are placed into JSON as DATA (json.dumps), never interpolated into a shell command.
# A correct script must os.stat the literal path and never execute the payload.
# ---------------------------------------------------------------------------
if [ -x "$SCRIPT" ]; then
  inj_ok=1
  for payload in '$(touch /tmp/pwned).log' 'x; touch /tmp/pwned' 'a b.log'; do
    rm -f /tmp/pwned
    st_inj="$(python3 - "$WORK" "$payload" <<'PY'
import json, os, sys
work, payload = sys.argv[1], sys.argv[2]
st = {"inflight": [{
    "task": "inj.md", "kind": "bg-bash", "promoted": True, "deadline_s": 120,
    "dispatched_at": "2020-01-01T00:00:00Z", "last_progress_at": "2020-01-01T00:00:00Z",
    "output_path": payload, "restarts": 0,
}]}
p = os.path.join(work, "inj-state.json")
open(p, "w").write(json.dumps(st))
print(p)
PY
)"
    # Run script; injection-firing or a crash both fail the case.
    LIVENESS_NOW=2026-06-26T00:00:00Z bash "$SCRIPT" "$st_inj" >/dev/null 2>&1 || true
    if [ -e /tmp/pwned ]; then
      echo "  [FAIL] injection fired for payload: $payload (/tmp/pwned created)"
      inj_ok=0
    fi
  done
  rm -f /tmp/pwned
  if [ "$inj_ok" -eq 1 ]; then
    echo "  [PASS] no shell injection via output_path (/tmp/pwned never created)"
  else
    fail=1
  fi
else
  echo "  [FAIL] check 6 skipped — script missing (RED)"
  fail=1
fi

# ---------------------------------------------------------------------------
# Check 7: broken JSON -> no STALE, non-zero exit (do not guess on partial reads).
# ---------------------------------------------------------------------------
if [ -x "$SCRIPT" ]; then
  broken="$WORK/broken.json"
  printf '%s' '{ broken' > "$broken"
  if out="$(LIVENESS_NOW=2026-06-26T00:00:00Z bash "$SCRIPT" "$broken" 2>/dev/null)"; then
    br_exit=0
  else
    br_exit=$?
  fi
  if [ "$br_exit" -ne 0 ] && ! printf '%s\n' "$out" | grep -q '^STALE'; then
    echo "  [PASS] broken JSON -> no STALE, non-zero exit ($br_exit)"
  else
    echo "  [FAIL] broken JSON mishandled (exit=$br_exit, out=$out)"
    fail=1
  fi
else
  echo "  [FAIL] check 7 skipped — script missing (RED)"
  fail=1
fi

# ---------------------------------------------------------------------------
# Check 8: progress-based floor (doctrine §4.4 + inflight[].last_progress_at).
# The floor must measure elapsed from PROGRESS (max(dispatched_at, last_progress_at)),
# not from dispatched_at — otherwise a live unit that reported progress is falsely STALE.
#   8a) bg-agent: dispatched long ago (> budget) BUT last_progress_at recent (within budget)
#       -> NOT stale  [core of the fix]
#   8b) bg-agent: dispatched long ago AND last_progress_at also long ago (> budget) -> STALE
#   8c) bg-bash: dispatched long ago (> budget), output_path EXISTS with FRESH mtime
#       (age < S_bash) -> NOT stale  (mtime is bg-bash's progress signal; deadline-floor
#       does not apply to a bg-bash with a live output file)  [bg-bash part of the fix]
#   8d) bg-bash: output_path EXISTS with STALE mtime (age > S_bash) -> STALE
# ---------------------------------------------------------------------------
if [ -x "$SCRIPT" ]; then
  PNOW=2026-06-24T12:00:00Z
  # deadline_s=100, G=2 -> budget 200. dispatched 11:50:00Z (600s ago, > budget).
  # 8a: last_progress_at 11:59:00Z (60s ago, well within budget) -> NOT stale.
  st_prog_fresh="$(make_state '{"inflight":[{"task":"prog-fresh.md","kind":"bg-agent","promoted":true,"deadline_s":100,"dispatched_at":"2026-06-24T11:50:00Z","last_progress_at":"2026-06-24T11:59:00Z","output_path":null,"restarts":0}]}')"
  out_pf="$(LIVENESS_NOW="$PNOW" bash "$SCRIPT" "$st_prog_fresh" 2>/dev/null || true)"
  if printf '%s\n' "$out_pf" | grep -q '^STALE'; then
    echo "  [FAIL] 8a bg-agent with recent last_progress_at unexpectedly STALE; got: $out_pf"
    fail=1
  else
    echo "  [PASS] 8a bg-agent dispatched-old but progress-recent -> not stale"
  fi

  # 8b: last_progress_at 11:50:00Z (== dispatched, 600s ago, > budget 200) -> STALE.
  st_prog_stale="$(make_state '{"inflight":[{"task":"prog-stale.md","kind":"bg-agent","promoted":true,"deadline_s":100,"dispatched_at":"2026-06-24T11:50:00Z","last_progress_at":"2026-06-24T11:50:00Z","output_path":null,"restarts":0}]}')"
  out_ps="$(LIVENESS_NOW="$PNOW" bash "$SCRIPT" "$st_prog_stale" 2>/dev/null || true)"
  if printf '%s\n' "$out_ps" | grep -q '^STALE prog-stale.md'; then
    echo "  [PASS] 8b bg-agent dispatched-old and progress-old -> STALE"
  else
    echo "  [FAIL] 8b bg-agent with old last_progress_at should be STALE; got: $out_ps"
    fail=1
  fi

  # 8c/8d: bg-bash dispatched 11:50:00Z (600s ago, > budget 200), output file EXISTS.
  # mtime decides: fresh (60s < 120) -> not stale; stale (180s > 120) -> STALE.
  bash_disp=2026-06-24T11:50:00Z
  out_bash_fresh="$WORK/prog-bash-fresh.log"
  out_bash_stale="$WORK/prog-bash-stale.log"
  : > "$out_bash_fresh"
  : > "$out_bash_stale"
  set_mtime_age "$out_bash_fresh" "$PNOW" 60
  set_mtime_age "$out_bash_stale" "$PNOW" 180

  st_bash_fresh="$(make_state "{\"inflight\":[{\"task\":\"prog-bash-fresh.md\",\"kind\":\"bg-bash\",\"promoted\":true,\"deadline_s\":100,\"dispatched_at\":\"$bash_disp\",\"last_progress_at\":\"$bash_disp\",\"output_path\":\"$out_bash_fresh\",\"restarts\":0}]}")"
  st_bash_stale="$(make_state "{\"inflight\":[{\"task\":\"prog-bash-stale.md\",\"kind\":\"bg-bash\",\"promoted\":true,\"deadline_s\":100,\"dispatched_at\":\"$bash_disp\",\"last_progress_at\":\"$bash_disp\",\"output_path\":\"$out_bash_stale\",\"restarts\":0}]}")"

  out_bf="$(LIVENESS_NOW="$PNOW" bash "$SCRIPT" "$st_bash_fresh" 2>/dev/null || true)"
  out_bs="$(LIVENESS_NOW="$PNOW" bash "$SCRIPT" "$st_bash_stale" 2>/dev/null || true)"

  if printf '%s\n' "$out_bf" | grep -q '^STALE'; then
    echo "  [FAIL] 8c bg-bash dispatched-old but mtime-fresh unexpectedly STALE; got: $out_bf"
    fail=1
  else
    echo "  [PASS] 8c bg-bash dispatched-old, output mtime fresh -> not stale"
  fi
  if printf '%s\n' "$out_bs" | grep -q '^STALE prog-bash-stale.md'; then
    echo "  [PASS] 8d bg-bash output mtime stale (180s > 120) -> STALE"
  else
    echo "  [FAIL] 8d bg-bash with stale output mtime should be STALE; got: $out_bs"
    fail=1
  fi
else
  echo "  [FAIL] check 8 skipped — script missing (RED)"
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  echo "=== FAILURES ==="
  exit 1
fi
echo "=== All liveness-floor checks passed ==="
