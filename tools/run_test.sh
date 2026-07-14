#!/usr/bin/env bash
# Blessed way to run a headless Godot test in this repo.
#
# WHY THIS EXISTS: `godot --headless -s res://tools/<t>.gd` boots the WHOLE
# project (autoloads included). A test that errors before its own quit() then
# leaves a full app looping forever — with the known idle leak it climbs to
# tens/hundreds of GB and the OS OOM-kills the editor. This once hit 150 GB.
#
# This wrapper bounds every run two ways so a stuck test can never run away:
#   1. --quit-after <frames>  : engine-level hard ceiling (fires even if quit()
#                               is never reached).
#   2. a wall-clock `timeout` : suspenders in case the engine itself wedges.
#
# Usage:
#   tools/run_test.sh tools/test_timeline_view.gd
#   tools/run_test.sh res://tools/test_ass_title.gd
#   QUIT_AFTER=1200 TIMEOUT_SECS=60 tools/run_test.sh tools/test_pipeline.gd
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: tools/run_test.sh <test.gd> [extra godot args...]" >&2
  exit 2
fi

SCRIPT="$1"; shift
# accept a bare path or a res:// path
case "$SCRIPT" in
  res://*) RES="$SCRIPT" ;;
  /*)      RES="res://${SCRIPT#*/agent-town-1/}" ;;
  *)       RES="res://${SCRIPT#./}" ;;
esac

QUIT_AFTER="${QUIT_AFTER:-600}"     # main-loop iterations (~10s at 60fps)
TIMEOUT_SECS="${TIMEOUT_SECS:-45}"  # wall-clock backstop

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

GODOT="${GODOT:-godot}"
# prefer a `timeout` binary if present (coreutils / gtimeout); else run bare —
# --quit-after already guarantees the engine ceiling.
TO=""
if command -v timeout   >/dev/null 2>&1; then TO="timeout ${TIMEOUT_SECS}";  fi
if command -v gtimeout  >/dev/null 2>&1; then TO="gtimeout ${TIMEOUT_SECS}"; fi

echo ">>> $RES  (--quit-after ${QUIT_AFTER}, timeout ${TIMEOUT_SECS}s)"
exec $TO "$GODOT" --headless --path "$PROJECT_DIR" --quit-after "$QUIT_AFTER" -s "$RES" "$@"
