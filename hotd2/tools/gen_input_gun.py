#!/usr/bin/env python3
"""Random light-gun input script for lr_headless coverage runs (The House of the Dead 2).

usage: gen_input_gun.py <seed> <frames> [start_frame] [players]
Lines: "<frame> <port> <id> <value>" with light gun ids + 100 (see host/lr_headless.cpp):
  113 SCREEN_X / 114 SCREEN_Y (-32767..32767), 115 IS_OFFSCREEN, 102 TRIGGER, 116 RELOAD,
  106 START, 107 SELECT (coin)
The gun sweeps the screen, fires bursts, reloads (off-screen shot) every few shots, and
inserts coins / presses START regularly so that continues and the name entry are reached too.
"""
import random, sys

seed, frames = int(sys.argv[1]), int(sys.argv[2])
start = int(sys.argv[3]) if len(sys.argv) > 3 else 900
players = int(sys.argv[4]) if len(sys.argv) > 4 else 1
rnd = random.Random(seed)
ev = []


def tap(f, port, bid, dur=4):
    ev.append((f, port, bid, 1))
    ev.append((f + dur, port, bid, 0))


for port in range(players):
    # aim at the centre first, gun on screen
    ev += [(0, port, 113, 0), (0, port, 114, 0), (0, port, 115, 0)]
    f = start + port * 11
    x, y = 0, 0
    shots = 0
    while f < frames:
        # coin + start fairly often: first credit, continues, joining in
        if rnd.random() < 0.10:
            tap(f, port, 107, 3)
            tap(f + 8, port, 106, 10)	# START must be held for a while
        # move the aim: jumps (new target) or small drifts (tracking)
        if rnd.random() < 0.5:
            x, y = rnd.randint(-30000, 30000), rnd.randint(-28000, 28000)
        else:
            x = max(-32000, min(32000, x + rnd.randint(-6000, 6000)))
            y = max(-30000, min(30000, y + rnd.randint(-5000, 5000)))
        ev += [(f, port, 113, x), (f, port, 114, y)]
        # fire: single shot or a burst
        n = rnd.choice([1, 1, 2, 3, 4])
        for i in range(n):
            tap(f + 1 + i * 6, port, 102, 3)
        shots += n
        f += 1 + n * 6
        # reload: off-screen shot (both the RELOAD id and an IS_OFFSCREEN + trigger pull)
        if shots >= rnd.choice([3, 5, 6]):
            shots = 0
            if rnd.random() < 0.5:
                tap(f + 2, port, 116, 4)
            else:
                ev.append((f + 2, port, 115, 1))
                tap(f + 3, port, 102, 3)
                ev.append((f + 9, port, 115, 0))
            f += 10
        f += rnd.choice([4, 8, 12, 20, 30])
for e in sorted(ev):
    print(*e)
