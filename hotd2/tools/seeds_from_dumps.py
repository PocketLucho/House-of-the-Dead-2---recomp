#!/usr/bin/env python3
"""Seed file for the static decoder (VNBA_AOT_STATIC): every block address seen in coverage dumps.

usage: seeds_from_dumps.py <dump.cpp>... > seeds.txt
Only addresses inside the game program (default 0x0C020000-0x0C150000, physical) are kept.
"""
import re, sys

lo, hi = 0x0C020000, 0x0C150000
hdr = re.compile(r"^//@BLOCK ([0-9A-F]{8}) ")
seen = set()
for p in sys.argv[1:]:
    for line in open(p, errors="replace"):
        m = hdr.match(line)
        if m:
            a = int(m[1], 16) & 0x1FFFFFFF
            if lo <= a < hi:
                seen.add(a)
for a in sorted(seen):
    print(f"{a:08x}")
print(f"{len(seen)} seeds", file=sys.stderr)
