#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# bench_boost_x.sh - boost probe (runs boost-x-* in data/messungen.csv): does the 1480 MHz clock cap
# depend on the X server? Four points: greeter running for a long time | display manager stopped
# (no X) | 20 s after restarting it | 120 s after restarting it.
# Stops and restarts the display manager (DM_UNIT, default sddm) with sudo -n; a trap restarts it
# in every case. Refuses to run while a desktop session is logged in on seat0.
# Needs: LLAMA_CUDA_BIN (see bench_env.sh), CLEF_FLASH_GGUF.
# Usage: bash bench_boost_x.sh OUT_DIR
set -u
# shellcheck source=bench_env.sh
. "$(dirname "$0")/bench_env.sh"
OUT=${1:?usage: bench_boost_x.sh OUT_DIR}; mkdir -p "$OUT"
need_var CLEF_FLASH_GGUF "path to Clef-Flash-Q8_0.gguf"; need_file "$CLEF_FLASH_GGUF"
Q=timestamp,pstate,clocks.sm,clocks.mem,temperature.gpu,power.draw,clocks_event_reasons.active
refuse_user_session
restore(){ systemctl is-active --quiet "$DM_UNIT" || { sudo -n systemctl start "$DM_UNIT"; echo "trap: $DM_UNIT started rc=$?"; }; }
trap restore EXIT INT TERM HUP
probe(){
  local id=$1 smi
  echo "== $id $(ts) $DM_UNIT=$(systemctl is-active "$DM_UNIT") xorg=$(pgrep -c -x Xorg)"
  nvidia-smi --query-gpu=$Q --format=csv,noheader -lms 500 > "$OUT/$id.takt.csv" 2>&1 & smi=$!
  timeout 300 "${BENCH[@]}" -m "$CLEF_FLASH_GGUF" -p 2048 -b 2048 -ub 2048 -n 0 -r 3 -ngl 99 > "$OUT/$id.txt" 2>&1
  echo "rc=$?" >> "$OUT/$id.txt"
  kill "$smi" 2>/dev/null; wait "$smi" 2>/dev/null
  grep -E "^\| clef|rc=" "$OUT/$id.txt"
  awk -F', ' '$2=="P2"||$2=="P0"{print $2, $3, int($6)"W", $7}' "$OUT/$id.takt.csv" | sort | uniq -c | sort -rn | head -3
}
probe 1-greeter-lange
sudo -n systemctl stop "$DM_UNIT"; sleep 10
probe 2-ohne-x
sudo -n systemctl start "$DM_UNIT"; sleep 20
probe 3-x-frisch-20s
sleep 100
probe 4-x-nach-120s
echo "== done $(ts) $DM_UNIT=$(systemctl is-active "$DM_UNIT")"
