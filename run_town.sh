#!/bin/zsh
# Agent Town supervisor: the engine occasionally SIGSEGVs on an internal
# WorkerThread (see DiagnosticReports 2026-07-09, null+0x10 — engine race,
# not our scripts). All town state is persistent (queue/, user://, memory),
# so the correct mitigation is auto-revive: crash becomes a 3-second blip.
# Exit code log tells us exactly how each session ended.
LOG=/tmp/at_supervisor.log
cd "$(dirname "$0")"
while true; do
  echo "[$(date '+%F %T')] launch" >> "$LOG"
  /Applications/Godot.app/Contents/MacOS/Godot --path . >> /tmp/at_run.log 2>&1
  CODE=$?
  echo "[$(date '+%F %T')] exited code=$CODE" >> "$LOG"
  if [ $CODE -eq 0 ]; then
    echo "[$(date '+%F %T')] clean quit (Cmd+Q) — supervisor stops" >> "$LOG"
    break
  fi
  sleep 3
done
