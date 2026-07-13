#!/usr/bin/env bash
# Soak/leak guardrail: stress the town headless and fail on a dangling lambda
# capture, a freed-object call, a non-finishing run, or orphan-node growth.
#   tools/soak_test.sh [seconds]   (env: GODOT, ORPHAN_GROWTH_MAX)
set -u
DUR="${1:-25}"
GODOT="${GODOT:-godot}"
MAX="${ORPHAN_GROWTH_MAX:-20}"
cd "$(dirname "$0")/.."
LOG="$(mktemp -t at_soak.XXXX)"

AGENT_TOWN_SOAK="$DUR" "$GODOT" --headless --path . > "$LOG" 2>&1 || true

fail=0
if grep -qE "Lambda capture .* was freed" "$LOG"; then
	echo "FAIL: dangling lambda capture detected:"
	grep -nE -A1 "Lambda capture .* was freed" "$LOG" | head
	fail=1
fi
if grep -qiE "Cannot call method .* on a null|on a previously freed" "$LOG"; then
	echo "FAIL: freed-object call detected:"
	grep -niE "Cannot call method .* on a null|previously freed" "$LOG" | head
	fail=1
fi
if ! grep -q "\[soak\] end" "$LOG"; then
	echo "FAIL: soak did not finish (crash/timeout). Tail:"
	tail -15 "$LOG"
	fail=1
fi
start="$(grep "\[soak\] start orphans=" "$LOG" | tail -1 | sed -E 's/.*orphans=([0-9]+).*/\1/')"
end="$(grep "\[soak\] end orphans=" "$LOG" | tail -1 | sed -E 's/.*orphans=([0-9]+).*/\1/')"
if [[ -n "$start" && -n "$end" ]]; then
	growth=$(( end - start ))
	echo "orphans: start=$start end=$end growth=$growth (max $MAX)"
	if (( growth > MAX )); then
		echo "FAIL: orphan node growth $growth exceeds $MAX"
		fail=1
	fi
else
	echo "FAIL: could not read orphan census"
	fail=1
fi

if [[ "$fail" -eq 0 ]]; then echo "SOAK PASS"; else echo "SOAK FAIL (log: $LOG)"; fi
exit "$fail"
