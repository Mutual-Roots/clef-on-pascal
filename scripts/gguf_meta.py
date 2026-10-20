#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""gguf_meta: print scalar GGUF metadata keys whose name contains one of the filters.

Reads only the header (key/value section); arrays are skipped, strings are cut at 80 characters.
Usage: gguf_meta.py FILE.gguf [SUBSTRING ...]
Example: gguf_meta.py Clef-Q4_K_M.gguf block_count general.name decision
"""
import struct
import sys

SCALAR = {0: "<B", 1: "<b", 2: "<H", 3: "<h", 4: "<I", 5: "<i", 6: "<f", 7: "<?", 10: "<Q", 11: "<q", 12: "<d"}


def rd(f, fmt):
    n = struct.calcsize(fmt)
    return struct.unpack(fmt, f.read(n))[0]


def rstr(f):
    return f.read(rd(f, "<Q")).decode("utf-8", "replace")


def skip_val(f, t):
    if t in SCALAR:
        f.seek(struct.calcsize(SCALAR[t]), 1)
    elif t == 8:
        f.seek(rd(f, "<Q"), 1)
    elif t == 9:
        et, n = rd(f, "<I"), rd(f, "<Q")
        for _ in range(n):
            skip_val(f, et)
    else:
        raise SystemExit("unknown GGUF value type %d" % t)


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    path, filt = sys.argv[1], [s.lower() for s in sys.argv[2:]]
    with open(path, "rb") as f:
        if f.read(4) != b"GGUF":
            raise SystemExit("not a GGUF file: %s" % path)
        ver, ntens, nkv = rd(f, "<I"), rd(f, "<Q"), rd(f, "<Q")
        print("gguf v%d tensors=%d kv=%d" % (ver, ntens, nkv))
        for _ in range(nkv):
            k, t = rstr(f), rd(f, "<I")
            if t in SCALAR or t == 8:
                v = rstr(f) if t == 8 else rd(f, SCALAR[t])
                if not filt or any(s in k.lower() for s in filt):
                    print("%s = %s" % (k, v if t != 8 else v[:80]))
            else:
                skip_val(f, t)


if __name__ == "__main__":
    main()
