#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# bench_flash_repeat.sh - repeat runs of Clef-Flash on CUDA (runs repeat-* in data/messungen.csv):
# is ~875 or ~1000 t/s the normal state? Per run: load average, seat0 sessions, and a 500-ms trace
# of P-state, SM/memory clock, temperature, power, PCIe generation and clock-event reasons.
# Needs: LLAMA_CUDA_BIN (see bench_env.sh), CLEF_FLASH_GGUF.
# Usage: bash bench_flash_repeat.sh OUT_DIR [COUNT]
set -u
# shellcheck source=bench_env.sh
. "$(dirname "$0")/bench_env.sh"
OUT=${1:?usage: bench_flash_repeat.sh OUT_DIR [COUNT]}; N=${2:-3}; mkdir -p "$OUT"
need_var CLEF_FLASH_GGUF "path to Clef-Flash-Q8_0.gguf"; need_file "$CLEF_FLASH_GGUF"
Q=timestamp,pstate,clocks.sm,clocks.mem,temperature.gpu,power.draw,pcie.link.gen.current,clocks_event_reasons.active
for i in $(seq 1 "$N"); do
  echo "== run $i $(ts) load=$(cut -d' ' -f1-3 /proc/loadavg) seat0=$(seat0_sessions)"
  nvidia-smi --query-gpu=$Q --format=csv,noheader -lms 500 > "$OUT/takt-$i.csv" 2>&1 & smi=$!
  timeout 600 "${BENCH[@]}" -m "$CLEF_FLASH_GGUF" -p 512,2048 -b 2048 -ub 2048 -n 0 -r 2 -ngl 99 > "$OUT/lauf-$i.txt" 2>&1
  echo "rc=$?" >> "$OUT/lauf-$i.txt"
  kill "$smi" 2>/dev/null; wait "$smi" 2>/dev/null
  grep -E "^\| clef|rc=" "$OUT/lauf-$i.txt"
  echo "-- clock under load (pstate, sm, mem, temp, W, pcie gen, reasons), most frequent states:"
  awk -F', ' '$2=="P2"||$2=="P0"{print $2, $3, $4, $5, int($6), $7, $8}' "$OUT/takt-$i.csv" | sort | uniq -c | sort -rn | head -4
  sleep 5
done
