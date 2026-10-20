#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# gputrace.sh - clock/power trace of the GPU every 500 ms, to run alongside any GPU measurement.
# Columns: timestamp, pstate, SM clock, power draw, power limit, clock-event reasons, memory used,
# utilization, temperature. Summary: python3 gputrace_summary.py FILE [FROM TO]
# Usage: gputrace.sh start FILE | gputrace.sh stop FILE
set -euo pipefail
cmd=${1:?usage: gputrace.sh start|stop FILE}; f=${2:?usage: gputrace.sh start|stop FILE}
case "$cmd" in
  start)
    nohup nvidia-smi --query-gpu=timestamp,pstate,clocks.sm,power.draw,power.limit,clocks_event_reasons.active,memory.used,utilization.gpu,temperature.gpu \
      --format=csv,noheader,nounits -lms 500 > "$f" 2>&1 &
    echo $! > "$f.pid"; echo "trace pid=$(cat "$f.pid")" ;;
  stop)
    kill "$(cat "$f.pid")" 2>/dev/null || true; rm -f "$f.pid"; echo "trace stopped, lines=$(wc -l < "$f")" ;;
  *) echo "usage: gputrace.sh start|stop FILE" >&2; exit 2 ;;
esac
