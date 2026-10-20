#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# bench_clef_pair.sh - pair test (runs paar-* in data/messungen.csv): Clef-Flash fully in VRAM and
# Clef 27B with the GPU as compute engine (-ngl 0) at the same time. First the 27B baselines
# (ngl 0 and ngl 32) so the comparison is fair; then 27B (-r 4) in the background while Flash
# runs in a loop for as long as the 27B run lasts.
# Needs: LLAMA_CUDA_BIN (see bench_env.sh), CLEF_FLASH_GGUF, CLEF_27B_GGUF.
# Usage: bash bench_clef_pair.sh OUT_DIR
set -u
# shellcheck source=bench_env.sh
. "$(dirname "$0")/bench_env.sh"
OUT=${1:?usage: bench_clef_pair.sh OUT_DIR}; mkdir -p "$OUT"
need_var CLEF_FLASH_GGUF "path to Clef-Flash-Q8_0.gguf"; need_file "$CLEF_FLASH_GGUF"
need_var CLEF_27B_GGUF "path to Clef-Q4_K_M.gguf"; need_file "$CLEF_27B_GGUF"
P=(-p "512,2048" -b 2048 -ub 2048 -n 0)

echo "seat0 sessions: $(seat0_sessions)  VRAM baseline: $(vram) MiB"
base27(){
  local id=$1 ngl=$2 pk
  echo "== $id $(ts)"
  ( timeout 1800 "${BENCH[@]}" -m "$CLEF_27B_GGUF" "${P[@]}" -r 2 -ngl "$ngl" > "$OUT/$id.txt" 2>&1; echo "rc=$?" >> "$OUT/$id.txt" ) &
  pk=$(watch_peak $!); show "$OUT/$id.txt" 6; echo "VRAM peak: $pk MiB"
}
base27 C2-27b-ngl0 0
base27 D2-27b-ngl32 32

echo "== PAAR $(ts): 27B ngl 0 (-r 4) in the background, Flash ngl 99 in a loop while 27B runs"
( timeout 1800 "${BENCH[@]}" -m "$CLEF_27B_GGUF" "${P[@]}" -r 4 -ngl 0 > "$OUT/PAAR-27b.txt" 2>&1; echo "rc=$?" >> "$OUT/PAAR-27b.txt" ) &
p27=$!
peakfile=$OUT/PAAR.vram
( pk=$(watch_peak "$p27"); echo "$pk" > "$peakfile" ) &
sleep 8
i=0
while kill -0 "$p27" 2>/dev/null; do
  i=$((i+1)); s=$(ts)
  timeout 600 "${BENCH[@]}" -m "$CLEF_FLASH_GGUF" "${P[@]}" -r 2 -ngl 99 > "$OUT/PAAR-flash-$i.txt" 2>&1; rc=$?
  e=$(ts); alive=$(kill -0 "$p27" 2>/dev/null && echo yes || echo no)
  echo "-- Flash run $i $s-$e rc=$rc 27B still running at the end: $alive"; show "$OUT/PAAR-flash-$i.txt" 6
done
wait "$p27"
echo "-- 27B in the pair:"; show "$OUT/PAAR-27b.txt" 6
wait
echo "VRAM peak pair: $(cat "$peakfile") MiB"
echo "== done $(ts)"
