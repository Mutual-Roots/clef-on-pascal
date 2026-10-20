#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Summarise an nvidia-smi trace written by gputrace.sh.

Usage: gputrace_summary.py FILE [FROM TO]
FROM/TO are ISO times like 2026-10-20T00:30:00, compared with the trace's own timestamps
(nvidia-smi writes local time of the host).
Prints all rows and the rows with GPU utilization >= 50 %: P-states, SM clock min/median/max,
power median/max, power limit, peak memory and the set of clock-event reasons.
"""
import csv
import sys
from datetime import datetime


def num(x):
    try:
        return float(x)
    except (TypeError, ValueError):
        return None


def ts(r):
    try:
        return datetime.strptime(r[0].strip(), '%Y/%m/%d %H:%M:%S.%f')
    except ValueError:
        return None


def stats(rs, label):
    if not rs:
        print(f'{label}: no rows')
        return
    sm = [num(r[2]) for r in rs]
    pw = [num(r[3]) for r in rs]
    mem = [num(r[6]) for r in rs]
    ps = sorted(set(r[1].strip() for r in rs))
    ev = sorted(set(r[5].strip() for r in rs))

    def med(v):
        return sorted(v)[len(v) // 2]
    print(f'{label}: n={len(rs)} pstate={ps} sm_MHz min/med/max={min(sm):.0f}/{med(sm):.0f}/{max(sm):.0f} '
          f'power_W med/max={med(pw):.1f}/{max(pw):.1f} limit_W={rs[0][4].strip()} mem_MiB max={max(mem):.0f} '
          f'events={ev}')


def main():
    if len(sys.argv) not in (2, 4):
        raise SystemExit(__doc__)
    with open(sys.argv[1], newline='') as fh:
        rows = [r for r in csv.reader(fh) if len(r) >= 9 and num(r[2]) is not None]
    if len(sys.argv) == 4:
        a = datetime.fromisoformat(sys.argv[2])
        b = datetime.fromisoformat(sys.argv[3])
        rows = [r for r in rows if ts(r) and a <= ts(r) <= b]
    stats(rows, 'all')
    stats([r for r in rows if (num(r[7]) or 0) >= 50], 'util>=50%')


if __name__ == '__main__':
    main()
