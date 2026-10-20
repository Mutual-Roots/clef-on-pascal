#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# bench_cuda_baseline.sh - does the CUDA build run on this driver at all, and how fast?
# Packages the llama-bench calls behind the cuda-20261019-* rows in data/messungen.csv, which were
# run by hand from a runbook before and after the driver change (550 -> 580):
#   1. driver, compute capability, devices seen by llama.cpp
#   2. architecture names found in libggml-cuda.so (a hint only: names, not a SASS/PTX listing)
#   3. GPU pp512 twice in a row: the first start JIT-compiles the PTX, the second reads the cache
#   4. flash attention off/on at pp512 and pp2048 with -ub 2048
#   5. CPU only (CUDA hidden) pp512
# On a driver older than the build's CUDA version step 3 aborts with
# "the provided PTX was compiled with an unsupported toolchain"; the script continues with step 5.
# Needs: LLAMA_CUDA_BIN (see bench_env.sh).
# Usage: bash bench_cuda_baseline.sh OUT_DIR MODEL.gguf
set -u
# shellcheck source=bench_env.sh
. "$(dirname "$0")/bench_env.sh"
OUT=${1:?usage: bench_cuda_baseline.sh OUT_DIR MODEL.gguf}; M=${2:?usage: bench_cuda_baseline.sh OUT_DIR MODEL.gguf}
mkdir -p "$OUT"; need_file "$M"
echo "start $(ts) model=$(basename "$M") ($(stat -c %s "$M") bytes)"
echo "== driver"; nvidia-smi --query-gpu=name,driver_version,compute_cap,memory.used,memory.total --format=csv,noheader
echo "== devices"
if [ -x "$LLAMA_CUDA_BIN/llama-server" ]; then
  LD_LIBRARY_PATH=$CUDA_LD timeout 60 "$LLAMA_CUDA_BIN/llama-server" --list-devices 2>&1 | tail -4
fi
echo "== architecture names in libggml-cuda.so"
strings -a "$LLAMA_CUDA_BIN/libggml-cuda.so" 2>/dev/null | grep -oE "(sm|compute)_[0-9]+a?" | sort -u | tr '\n' ' '; echo
echo "== JIT cache: $CUDA_CACHE_PATH ($(du -sh "$CUDA_CACHE_PATH" 2>/dev/null | cut -f1) before)"
for i in 1 2; do
  t0=$(date +%s.%N)
  timeout 600 "${BENCH[@]}" -m "$M" -p 512 -n 0 -ngl 99 -r 1 > "$OUT/gpu-jit$i.txt" 2>&1; rc=$?
  t1=$(date +%s.%N)
  echo "-- GPU run $i rc=$rc wall_s=$(python3 -I -c 'import sys; print(round(float(sys.argv[2])-float(sys.argv[1]),1))' "$t0" "$t1")"
  grep -E "^\| |error|PTX|unsupported|no kernel" "$OUT/gpu-jit$i.txt" | grep -vE "^\| model|^\| -" | tail -4
done
echo "== JIT cache after: $(du -sh "$CUDA_CACHE_PATH" 2>/dev/null | cut -f1)"
echo "== flash attention 0/1"
timeout 900 "${BENCH[@]}" -m "$M" -p 512,2048 -b 2048 -ub 2048 -n 0 -ngl 99 -fa 0,1 -o md > "$OUT/gpu-fa.md" 2> "$OUT/gpu-fa.err"
echo "rc=$?"; cat "$OUT/gpu-fa.md"
echo "== CPU only (CUDA hidden), pp512, 2 repetitions"
timeout 900 env CUDA_VISIBLE_DEVICES= "${BENCH[@]}" -m "$M" -p 512 -n 0 -ngl 0 -r 2 > "$OUT/cpu.txt" 2>&1
echo "rc=$?"; grep -E "^\| |error|failed" "$OUT/cpu.txt" | grep -vE "^\| model|^\| -" | tail -3
echo "end $(ts)"
