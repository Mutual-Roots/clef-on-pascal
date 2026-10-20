#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# bench_vulkan_cuda.sh - CUDA against Vulkan (runs vulkan-cuda-* in data/messungen.csv): same
# llama.cpp version, same GGUF, same parameters, back to back. For each TAG=MODEL.gguf it runs
# V-TAG (Vulkan build) and C-TAG (CUDA build) and reports the VRAM peak.
# The original run used TAG flash-q8 (Clef-Flash Q8_0) and qwen9b-q4 (an Ollama model blob, which
# failed to load in both builds; no data).
# Needs: LLAMA_CUDA_BIN (see bench_env.sh), LLAMA_VULKAN_BIN (directory of the Vulkan build),
# optional LLAMA_VULKAN_LIBPATH. Refuses to run while a desktop session is logged in on seat0.
# Usage: bash bench_vulkan_cuda.sh OUT_DIR TAG=MODEL.gguf [TAG=MODEL.gguf ...]
set -u
# shellcheck source=bench_env.sh
. "$(dirname "$0")/bench_env.sh"
OUT=${1:?usage: bench_vulkan_cuda.sh OUT_DIR TAG=MODEL.gguf ...}; shift
[ $# -ge 1 ] || die "at least one TAG=MODEL.gguf is needed"
mkdir -p "$OUT"
need_var LLAMA_VULKAN_BIN "directory of the llama.cpp Vulkan build"
[ -x "$LLAMA_VULKAN_BIN/llama-bench" ] || die "no executable llama-bench in LLAMA_VULKAN_BIN=$LLAMA_VULKAN_BIN"
VK_LD="$LLAMA_VULKAN_BIN${LLAMA_VULKAN_LIBPATH:+:$LLAMA_VULKAN_LIBPATH}"
P=(-p "512,2048" -b 2048 -ub 2048 -n 0 -r 2 -ngl 99)
for arg in "$@"; do
  tag=${arg%%=*}; model=${arg#*=}
  if [ "$tag" = "$arg" ] || [ -z "$tag" ]; then die "argument '$arg' is not TAG=MODEL.gguf"; fi
  need_file "$model"
done

echo "seat0: $(seat0_sessions)"; refuse_user_session
echo "driver: $(nvidia-smi --query-gpu=driver_version --format=csv,noheader)"

run(){
  local id=$1 lib=$2 bin=$3 model=$4 pid peak
  echo "== $id $(ts)"
  ( LD_LIBRARY_PATH=$lib timeout 900 "$bin" -m "$model" "${P[@]}" > "$OUT/$id.txt" 2>&1; echo "rc=$?" >> "$OUT/$id.txt" ) &
  pid=$!
  peak=$(watch_peak "$pid")
  grep -E "ggml_vulkan: 0|^\| |rc=|error|failed" "$OUT/$id.txt" | grep -vE "^\| model|^\| -" | tail -4
  echo "VRAM peak: $peak MiB"
}

for arg in "$@"; do
  tag=${arg%%=*}; model=${arg#*=}
  run "V-$tag" "$VK_LD"   "$LLAMA_VULKAN_BIN/llama-bench" "$model"
  run "C-$tag" "$CUDA_LD" "$LLAMA_CUDA_BIN/llama-bench"   "$model"
done
echo "== done $(ts)"
