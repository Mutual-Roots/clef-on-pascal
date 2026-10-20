#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# gpu_power.sh - set and show the power profile of the NVIDIA card.
# Values come ONLY from the config (default /etc/fordiverse/gpu/gpu.conf, override with GPU_CONF):
#   GPU_POWER_PROFILE_DEFAULT        profile applied at boot
#   GPU_POWER_MIN_W, GPU_POWER_MAX_W allowed range from the power sweep (not the hardware range)
#   GPU_POWER_W_<profile>            watts per profile; a '-' in the profile name is '_' in the key
# Usage: gpu_power.sh apply PROFILE | apply-default | status | list
# "apply" runs as root via systemd (fordiverse-gpu-power@PROFILE.service); status/list need no root.
set -Eeuo pipefail
export LANG=C.UTF-8 LC_ALL=C.UTF-8
CONF=${GPU_CONF:-/etc/fordiverse/gpu/gpu.conf}
STATE_DIR=${RUNTIME_DIRECTORY:-/run/fordiverse-gpu}
die(){ echo "ABORT: $*" >&2; exit 2; }
[ -r "$CONF" ] || die "config $CONF is missing or not readable"
# shellcheck source=/dev/null
. "$CONF"

need(){ local v=${!1:-}; [ -n "$v" ] || die "$1 missing in $CONF"; printf '%s' "$v"; }
num(){ [[ "$2" =~ ^[0-9]+$ ]] || die "$1=$2 is not a whole number"; }
valid_name(){ [[ "$1" =~ ^[a-z][a-z0-9-]*$ ]] || die "profile name '$1' is invalid"; }
watts_for(){ local key="GPU_POWER_W_${1//-/_}" w; w=$(need "$key"); num "$key" "$w"; printf '%s' "$w"; }
profiles(){ compgen -v GPU_POWER_W_ | sed 's/^GPU_POWER_W_//; s/_/-/g'; }
limit_now(){ nvidia-smi --query-gpu=power.limit --format=csv,noheader,nounits | head -1 | cut -d. -f1; }

apply(){
  local p=$1 w min max got
  valid_name "$p"
  w=$(watts_for "$p"); min=$(need GPU_POWER_MIN_W); max=$(need GPU_POWER_MAX_W)
  num GPU_POWER_MIN_W "$min"; num GPU_POWER_MAX_W "$max"
  { [ "$w" -ge "$min" ] && [ "$w" -le "$max" ]; } || die "profile $p: $w W is outside $min-$max W (range from the power sweep)"
  [ "$(id -u)" -eq 0 ] || die "apply needs root: systemctl start fordiverse-gpu-power@$p.service"
  nvidia-smi -pl "$w" > /dev/null || die "nvidia-smi -pl $w refused"
  got=$(limit_now); [ "$got" -eq "$w" ] || die "read back $got W instead of $w W"
  mkdir -p "$STATE_DIR"
  printf '%s %s %s\n' "$p" "$w" "$(date -u +%FT%TZ)" > "$STATE_DIR/power-profile"
  echo "GPU power profile $p: $w W set and read back"
}

status(){
  local s="(no profile set since boot)"
  [ -r "$STATE_DIR/power-profile" ] && s=$(cat "$STATE_DIR/power-profile")
  echo "profile (name watts since): $s"
  nvidia-smi --query-gpu=power.limit,power.draw,clocks.sm,pstate,temperature.gpu --format=csv,noheader \
    | sed 's/^/card now (limit, draw, SM clock, P-state, temp): /'
}

list(){
  local min max p
  min=$(need GPU_POWER_MIN_W); max=$(need GPU_POWER_MAX_W)
  echo "range $min-$max W, default at boot: $(need GPU_POWER_PROFILE_DEFAULT)"
  for p in $(profiles); do printf '  %-14s %s W\n' "$p" "$(watts_for "$p")"; done
}

case "${1:-status}" in
  apply) [ $# -eq 2 ] || die "usage: apply PROFILE"; apply "$2" ;;
  apply-default) apply "$(need GPU_POWER_PROFILE_DEFAULT)" ;;
  status) status ;;
  list) list ;;
  *) die "unknown command '$1' (apply PROFILE | apply-default | status | list)" ;;
esac
