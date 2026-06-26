#!/usr/bin/env bash
# liveness-floor.sh — detect-only wall-clock floor over a state.json `inflight[]`.
#
# Turns doctrine §4.4 (resume floor) and §5.2 (bg-bash mtime staleness) into a
# checkable primitive. The floor is measured over PROGRESS, not dispatch: for every
# in-flight unit it takes progress_ref = max(dispatched_at, last_progress_at) and, for
# signal-less kinds (bg-agent / sync / bg-bash without an existing output file), prints a
# one-line STALE report when elapsed = now - progress_ref exceeds G x deadline_s. For
# kind == "bg-bash" WITH an existing output file, the file's mtime is the progress signal:
# the unit is STALE iff its output has not been touched for longer than S_bash seconds, and
# the deadline floor does not apply (a fresh mtime proves liveness regardless of dispatch
# age). DETECT-ONLY: it never restarts units, never stops or queries them via harness task
# ops, and never mutates state.json — it only reads and prints.
#
# Usage:   liveness-floor.sh <path-to-state.json>
# Env:
#   LIVENESS_NOW     ISO-8601 instant (or unix epoch seconds) treated as "now".
#                    Default: current system time.
#   LIVENESS_G       grace multiplier applied to deadline_s.   Default form: "${LIVENESS_G:-2}".
#   LIVENESS_S_BASH  bg-bash mtime staleness window (seconds).  Default form: "${LIVENESS_S_BASH:-120}".
#
# Output: one line per stale unit — `STALE <task> <elapsed>s/<budget>s <kind>[ <reason>]`.
#         Fresh units print nothing. Empty/absent inflight -> nothing, exit 0.
#         Broken/unparseable JSON -> nothing, non-zero exit (do not guess on partial reads).
#
# Security (Tier-1): the entire JSON parse, time arithmetic and os.stat happen inside a single
# python3 program. state.json field values (notably output_path) never leave python and are
# never spliced into a shell command — shell injection is structurally impossible. bash only
# forwards the path (as argv) and the env vars.
#
# Zero-dependency: bash + system python3 standard library (json, datetime, os) only.
set -euo pipefail

# Default forms below are load-bearing — a textual guard in the test suite asserts the exact
# strings "${LIVENESS_G:-2}" and "${LIVENESS_S_BASH:-120}", and the numbers 2 / 120 match the
# doctrine (§4.4 / §5.2). Change the form only in sync with those guards.
G="${LIVENESS_G:-2}"
S_BASH="${LIVENESS_S_BASH:-120}"
NOW="${LIVENESS_NOW:-}"

if [ "$#" -lt 1 ]; then
  echo "liveness-floor.sh: missing argument: path to state.json" >&2
  exit 2
fi
STATE_PATH="$1"
if [ ! -f "$STATE_PATH" ]; then
  echo "liveness-floor.sh: no such file: $STATE_PATH" >&2
  exit 2
fi

# Everything below runs in python; the state path is passed as argv[1], the tunables via env.
# `set -e` is intentionally relaxed for this one call so a non-zero parse exit propagates as our
# own exit code rather than aborting mid-pipeline.
LIVENESS_G="$G" LIVENESS_S_BASH="$S_BASH" LIVENESS_NOW="$NOW" \
python3 - "$STATE_PATH" <<'PY'
import json, os, sys
from datetime import datetime, timezone


def parse_instant(s):
    """Parse an ISO-8601 string (with optional trailing Z) or a unix-epoch number into
    an aware UTC datetime. Returns None if unparseable."""
    s = s.strip()
    if not s:
        return None
    # unix epoch (int or float seconds)
    try:
        return datetime.fromtimestamp(float(s), tz=timezone.utc)
    except (ValueError, OverflowError, OSError):
        pass
    try:
        dt = datetime.fromisoformat(s.replace("Z", "+00:00"))
    except ValueError:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def fail(msg):
    sys.stderr.write("liveness-floor.sh: %s\n" % msg)
    sys.exit(1)


state_path = sys.argv[1]

now_env = os.environ.get("LIVENESS_NOW", "") or ""
if now_env.strip():
    now = parse_instant(now_env)
    if now is None:
        fail("could not parse LIVENESS_NOW=%r" % now_env)
else:
    now = datetime.now(timezone.utc)

try:
    G = float(os.environ.get("LIVENESS_G", "2"))
    S_BASH = float(os.environ.get("LIVENESS_S_BASH", "120"))
except ValueError:
    fail("LIVENESS_G / LIVENESS_S_BASH must be numeric")

# Read + parse. Broken/partial JSON must not yield false STALE: print nothing, exit non-zero.
try:
    with open(state_path, "r") as fh:
        data = json.load(fh)
except (OSError, ValueError):
    fail("could not read or parse JSON: %s" % state_path)

if not isinstance(data, dict):
    fail("state.json root is not an object")

inflight = data.get("inflight")
if inflight is None:
    sys.exit(0)            # absent inflight -> nothing to report
if not isinstance(inflight, list):
    fail("inflight is not a list")

lines = []
for entry in inflight:
    if not isinstance(entry, dict):
        continue
    task = entry.get("task")
    kind = entry.get("kind")
    dispatched_raw = entry.get("dispatched_at")
    last_progress_raw = entry.get("last_progress_at")
    deadline_s = entry.get("deadline_s")
    output_path = entry.get("output_path")

    # dispatched_at is mandatory; an absent/unparseable value -> skip (do not guess).
    if dispatched_raw is None:
        continue
    dispatched = parse_instant(str(dispatched_raw))
    if dispatched is None:
        continue

    # last_progress_at refines the floor (§4.4): elapsed is measured from progress, not
    # dispatch. Absent -> fall back to dispatched. max() guards against a regressed value
    # (last_progress_at earlier than dispatched_at) so progress can never *shorten* elapsed.
    progress = dispatched
    if last_progress_raw is not None:
        lp = parse_instant(str(last_progress_raw))
        if lp is not None and lp > progress:
            progress = lp

    # deadline_s is mandatory; absent/non-numeric -> skip.
    if deadline_s is None:
        continue
    try:
        deadline_s = float(deadline_s)
    except (TypeError, ValueError):
        continue

    # elapsed is reported relative to progress_ref, not dispatch.
    elapsed = (now - progress).total_seconds()
    budget = G * deadline_s

    # bg-bash with an existing output file: mtime is the progress signal (§5.2). A fresh
    # mtime proves liveness, so the deadline floor does NOT apply here — only the mtime
    # window decides. (A bg-bash without an existing output file falls through to the
    # deadline floor below, like any other signal-less kind.)
    if kind == "bg-bash" and output_path:
        try:
            mtime = os.stat(output_path).st_mtime  # literal path; never executed by a shell
        except OSError:
            mtime = None
        if mtime is not None:
            age = now.timestamp() - mtime
            # Strict `>`; negative age (mtime in the future) is not staleness.
            if age > S_BASH:
                lines.append(
                    "STALE %s %ds/%ds %s output stale %ds>%ds"
                    % (task, int(elapsed), int(budget), kind, int(age), int(S_BASH))
                )
            continue

    # Deadline floor for signal-less kinds (bg-agent / sync / bg-bash without an existing
    # output file). Strict `>` means a negative elapsed (progress_ref in the future vs now,
    # i.e. clock skew) can never be stale — the unit "has not started yet".
    if elapsed > budget:
        lines.append(
            "STALE %s %ds/%ds %s" % (task, int(elapsed), int(budget), kind)
        )

for line in lines:
    print(line)

sys.exit(0)
PY
