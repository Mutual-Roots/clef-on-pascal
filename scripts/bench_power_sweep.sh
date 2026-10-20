#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# bench_power_sweep.sh - power sweep (runs power-sweep-pl* in data/messungen.csv): Clef-Flash Q8_0
# pp2048 at several power limits. Measured without X (display manager stopped), so that only the
# power limit acts on the clock. Per point: t/s, mean power under load (> 100 W), J/token, most
# frequent SM clock, peak temperature. Raw traces: plNNN.csv, llama-bench output: plNNN.bench.csv.
# Sets limits with "sudo -n nvidia-smi -pl". A trap ALWAYS restores the limit that was active before
# the sweep and restarts the display manager (DM_UNIT, default sddm).
# Change against the original run: the original restored the card's default limit (250 W); this
# version restores the previous limit, so an active power profile survives the sweep.
# Needs: LLAMA_CUDA_BIN (see bench_env.sh), CLEF_FLASH_GGUF.
# Usage: bash bench_power_sweep.sh OUT_DIR ["125 150 175 200 225 250"]
set -u
# shellcheck source=bench_env.sh
. "$(dirname "$0")/bench_env.sh"
OUT=${1:?usage: bench_power_sweep.sh OUT_DIR [LIMITS]}; LIMITS=${2:-"125 150 175 200 225 250"}; mkdir -p "$OUT"
need_var CLEF_FLASH_GGUF "path to Clef-Flash-Q8_0.gguf"; need_file "$CLEF_FLASH_GGUF"
PREV_PL=$(nvidia-smi --query-gpu=power.limit --format=csv,noheader,nounits | head -1 | cut -d. -f1)
DEFAULT_PL=$(nvidia-smi --query-gpu=power.default_limit --format=csv,noheader,nounits | head -1 | cut -d. -f1)
refuse_user_session
restore(){
  sudo -n nvidia-smi -pl "$PREV_PL" > /dev/null
  echo "trap: power limit $(nvidia-smi --query-gpu=power.limit --format=csv,noheader)"
  systemctl is-active --quiet "$DM_UNIT" || { sudo -n systemctl start "$DM_UNIT"; echo "trap: $DM_UNIT started rc=$?"; }
}
trap restore EXIT INT TERM HUP
sudo -n systemctl stop "$DM_UNIT"; sleep 8
echo "start $(ts) $DM_UNIT=$(systemctl is-active "$DM_UNIT") default_limit=${DEFAULT_PL} W previous_limit=${PREV_PL} W"
printf "%-7s %-10s %-9s %-9s %-9s %s\n" "limit" "t/s" "W(load)" "J/token" "SM-MHz" "temp"
for pl in $LIMITS; do
  sudo -n nvidia-smi -pl "$pl" > /dev/null || { echo "ABORT: -pl $pl refused"; exit 5; }
  sleep 3
  nvidia-smi --query-gpu=power.draw,clocks.sm,temperature.gpu --format=csv,noheader,nounits -lms 250 > "$OUT/pl$pl.csv" 2>&1 & smi=$!
  timeout 300 "${BENCH[@]}" -m "$CLEF_FLASH_GGUF" -p 2048 -b 2048 -ub 2048 -n 0 -r 3 -ngl 99 -o csv > "$OUT/pl$pl.bench.csv" 2> "$OUT/pl$pl.err"
  kill "$smi" 2>/dev/null; wait "$smi" 2>/dev/null
  tps=$(python3 -I -c 'import csv,sys; r=list(csv.DictReader(open(sys.argv[1]))); print(r[-1]["avg_ts"])' "$OUT/pl$pl.bench.csv" 2>/dev/null)
  python3 -I -c '
import sys, statistics as st
pl, tps, f = sys.argv[1], float(sys.argv[2] or 0), sys.argv[3]
rows = [l.split(",") for l in open(f) if l.count(",") == 2]
load = [(float(a), int(b), int(c)) for a, b, c in rows if float(a) > 100]
if not load or not tps:
    print(pl, "no load data"); sys.exit()
w = st.mean(x[0] for x in load); mhz = st.mode(x[1] for x in load); t = max(x[2] for x in load)
print("%-7s %-10.1f %-9.1f %-9.3f %-9d %d" % (pl + " W", tps, w, w / tps, mhz, t))' "$pl" "${tps:-0}" "$OUT/pl$pl.csv"
done
echo "end $(ts)"
