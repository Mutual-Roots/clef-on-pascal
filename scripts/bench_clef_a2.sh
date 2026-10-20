#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# bench_clef_a2.sh - run A2: Clef-Flash Q8_0 on the GPU again, after logging out the KDE Plasma
# session of SESSION_USER on seat0. Same llama-bench parameters as bench_clef.sh, plus a 1-second
# clock/power trace (A2.takt.csv).
#
# WARNING: this ends a desktop session; unsaved work in it is lost. It asks Plasma to log out
# (org.kde.Shutdown.logout) and only after 120 s uses "loginctl terminate-session".
# Needs passwordless sudo (sudo -n) to run dbus-send as SESSION_USER and for terminate-session.
# Optional WAIT_UNIT: first wait until this systemd --user unit (e.g. a running benchmark) is
# inactive or failed.
# Needs: LLAMA_CUDA_BIN (see bench_env.sh), CLEF_FLASH_GGUF.
# Usage: bash bench_clef_a2.sh OUT_DIR SESSION_USER
set -u
# shellcheck source=bench_env.sh
. "$(dirname "$0")/bench_env.sh"
OUT=${1:?usage: bench_clef_a2.sh OUT_DIR SESSION_USER}; SU=${2:?usage: bench_clef_a2.sh OUT_DIR SESSION_USER}
mkdir -p "$OUT"
need_var CLEF_FLASH_GGUF "path to Clef-Flash-Q8_0.gguf"; need_file "$CLEF_FLASH_GGUF"
WAIT_UNIT=${WAIT_UNIT:-}
gpu_procs(){ nvidia-smi | sed -n '/Processes/,$p' | grep -E '^\|\s+[0-9]'; }
plasma_count(){ local n; n=$(pgrep -c -x -u "$SU" 'plasmashell|kwin_x11|kwin_wayland|ksmserver'); echo "${n:-x}"; }

if [ -n "$WAIT_UNIT" ]; then
  echo "== A2 waits for $WAIT_UNIT $(ts)"
  while true; do
    s=$(systemctl --user is-active "$WAIT_UNIT")
    case "$s" in inactive|failed) break ;; *) sleep 20 ;; esac
  done
  echo "$WAIT_UNIT: $s $(ts)"
fi

S=$(loginctl list-sessions --no-legend | awk -v u="$SU" '$3==u && $4=="seat0" && $6=="user" {print $1}' | head -1)
echo "session of $SU on seat0 before logout: ${S:-none}"
echo "-- GPU processes before"; gpu_procs
if [ -n "$S" ]; then
  uid=$(id -u "$SU")
  sudo -n -u "$SU" env DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" XDG_RUNTIME_DIR="/run/user/$uid" \
    dbus-send --session --print-reply --dest=org.kde.Shutdown /Shutdown org.kde.Shutdown.logout > /dev/null
  echo "logout requested rc=$? $(ts)"
  n=x
  for _ in $(seq 1 120); do n=$(plasma_count); [ "$n" = 0 ] && break; sleep 1; done
  if [ "$n" != 0 ]; then
    echo "WARNING: Plasma still running after 120 s (n=$n), terminate-session $S $(ts)"
    sudo -n loginctl terminate-session "$S"; sleep 30
    n=$(plasma_count)
    [ "$n" = 0 ] || { echo "ABORT: Plasma keeps running (n=$n), A2 not measured"; exit 4; }
  fi
  echo "Plasma ended $(ts)"
fi
sleep 20
echo "-- GPU processes after"; gpu_procs

echo "== A2-flash-gpu-ohne-plasma $(ts)"
Q=timestamp,pstate,clocks.sm,clocks.mem,temperature.gpu,power.draw,power.limit,fan.speed,clocks_event_reasons.active
nvidia-smi --query-gpu=$Q --format=csv -lms 1000 > "$OUT/A2.takt.csv" 2>&1 &
smi=$!
( timeout 900 "${BENCH[@]}" -m "$CLEF_FLASH_GGUF" -p 512,2048 -b 2048 -ub 2048 -n 0 -r 2 -ngl 99 > "$OUT/A2.txt" 2>&1
  echo "rc=$?" >> "$OUT/A2.txt" )
kill "$smi" 2>/dev/null; wait "$smi" 2>/dev/null
show "$OUT/A2.txt"
echo "-- clock under load (rows with P0-P2, most frequent)"
grep -E ' P[0-2],' "$OUT/A2.takt.csv" | awk -F', ' '{print $2, $3, $4, $5, $6, $9}' | sort | uniq -c | sort -rn | head -6
echo "== A2 done $(ts)"
