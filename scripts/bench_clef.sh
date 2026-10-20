#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# bench_clef.sh - prefill load test (runs A, B, C, D in data/messungen.csv):
#   A  Clef-Flash 9B Q8_0 fully on the GPU
#   B  Clef 27B Q4_K_M on the CPU only (CUDA hidden)
#   C  Clef 27B with the GPU as compute engine: -ngl 0, weights stay in RAM ("op offload")
#   D  Clef 27B with 16, 24 and 32 of its 64 blocks in VRAM
# Prefill only: Clef is an encoder-style decision model, the whole input must fit into one
# micro-batch (-ub >= input tokens). <id>.vram0 holds the VRAM in use BEFORE the run (display
# baseline); the peak during the run is printed as "VRAM peak".
# Needs: LLAMA_CUDA_BIN (see bench_env.sh), CLEF_FLASH_GGUF, CLEF_27B_GGUF.
# Usage: bash bench_clef.sh OUT_DIR
set -u
# shellcheck source=bench_env.sh
. "$(dirname "$0")/bench_env.sh"
OUT=${1:?usage: bench_clef.sh OUT_DIR}; mkdir -p "$OUT"
need_var CLEF_FLASH_GGUF "path to Clef-Flash-Q8_0.gguf"; need_file "$CLEF_FLASH_GGUF"
need_var CLEF_27B_GGUF "path to Clef-Q4_K_M.gguf"; need_file "$CLEF_27B_GGUF"
P=(-p "512,2048" -b 2048 -ub 2048 -n 0 -r 2)

run(){
  local id=$1 pid peak; shift
  echo "== $id $(ts)"
  vram > "$OUT/$id.vram0"
  ( "$@" > "$OUT/$id.txt" 2>&1; echo "rc=$?" >> "$OUT/$id.txt" ) &
  pid=$!
  peak=$(watch_peak "$pid")
  show "$OUT/$id.txt"
  echo "VRAM peak: ${peak} MiB"
}

run A-flash-gpu          timeout 900  "${BENCH[@]}" -m "$CLEF_FLASH_GGUF" "${P[@]}" -ngl 99
run B-27b-cpu            timeout 1800 env CUDA_VISIBLE_DEVICES= "${BENCH[@]}" -m "$CLEF_27B_GGUF" "${P[@]}" -ngl 0
run C-27b-gpu-rechenwerk timeout 1800 "${BENCH[@]}" -m "$CLEF_27B_GGUF" "${P[@]}" -ngl 0
for n in 16 24 32; do
  run "D-27b-ngl$n" timeout 1800 "${BENCH[@]}" -m "$CLEF_27B_GGUF" "${P[@]}" -ngl "$n"
done
echo "== done $(ts)"
