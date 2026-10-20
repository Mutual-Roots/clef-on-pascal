# shellcheck shell=bash disable=SC2034
# SPDX-License-Identifier: GPL-3.0-or-later
# bench_env.sh - shared settings for the bench_*.sh scripts. Sourced, not executed.
#
# Required (the scripts stop with a clear message if a value is missing):
#   LLAMA_CUDA_BIN      directory of the llama.cpp CUDA build (contains llama-bench, llama-server)
# Optional:
#   LLAMA_CUDA_LIBPATH  extra library directories for that build, ':'-separated (e.g. the cudart bundle)
#   CUDA_CACHE_PATH     persistent PTX-JIT cache (default: ${XDG_CACHE_HOME:-$HOME/.cache}/nv-computecache)
#   CUDA_CACHE_MAXSIZE  JIT cache limit in bytes (default 4294967296)
#   DM_UNIT             display-manager unit that some scripts stop and restart (default sddm)
export LANG=C.UTF-8 LC_ALL=C.UTF-8

die(){ echo "ABORT: $*" >&2; exit 2; }
need_var(){ [ -n "${!1:-}" ] || die "$1 is not set ($2)"; }
need_file(){ [ -f "$1" ] || die "file not found: $1"; }

need_var LLAMA_CUDA_BIN "directory of the llama.cpp CUDA build"
[ -x "$LLAMA_CUDA_BIN/llama-bench" ] || die "no executable llama-bench in LLAMA_CUDA_BIN=$LLAMA_CUDA_BIN"
CUDA_LD="$LLAMA_CUDA_BIN${LLAMA_CUDA_LIBPATH:+:$LLAMA_CUDA_LIBPATH}"
BENCH=(env "LD_LIBRARY_PATH=$CUDA_LD" "$LLAMA_CUDA_BIN/llama-bench")
export CUDA_CACHE_PATH="${CUDA_CACHE_PATH:-${XDG_CACHE_HOME:-$HOME/.cache}/nv-computecache}"
export CUDA_CACHE_MAXSIZE="${CUDA_CACHE_MAXSIZE:-4294967296}"
DM_UNIT=${DM_UNIT:-sddm}

ts(){ date -u +%H:%M:%SZ; }
vram(){ nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | head -1; }
# Sessions on seat0 as user/class, e.g. "sddm/greeter" or "alice/user".
seat0_sessions(){ loginctl list-sessions --no-legend | awk '$4=="seat0"{print $3"/"$6}' | tr '\n' ' '; }
refuse_user_session(){
  case "$(seat0_sessions)" in
    *"/user"*) echo "ABORT: a desktop session is logged in on seat0; measure only with the greeter or without X" >&2; exit 4 ;;
  esac
}
# Peak VRAM (MiB) while process $1 runs, sampled once per second.
watch_peak(){ local pid=$1 peak=0 v; while kill -0 "$pid" 2>/dev/null; do v=$(vram); [ "${v:-0}" -gt "$peak" ] && peak=$v; sleep 1; done; echo "$peak"; }
show(){ grep -E "^\| clef|rc=|error|failed|out of memory" "$1" | tail -"${2:-4}"; }
