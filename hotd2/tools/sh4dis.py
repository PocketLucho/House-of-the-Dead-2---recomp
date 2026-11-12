#!/usr/bin/env python3
"""Minimal SH-4 disassembler for looking around a program image (little endian).

usage: sh4dis.py <image.bin> <load address (hex)> <start (hex)> [count]
The image is a raw memory image (e.g. the first 0x126000 bytes of epr-21585.ic22 loaded at
0x0C020000, or a RAM dump loaded at 0x0C000000). PC-relative literals are resolved.
"""
import struct, sys


def s8(v): return v - 256 if v & 0x80 else v
def s12(v): return v - 4096 if v & 0x800 else v


def dis(img, base, pc):
    def r16(a):
        o = a - base
        return struct.unpack_from('<H', img, o)[0] if 0 <= o < len(img) - 1 else 0
    def r32(a):
        o = a - base
        return struct.unpack_from('<I', img, o)[0] if 0 <= o < len(img) - 3 else 0
    op = r16(pc)
    n, m, d4, d8 = (op >> 8) & 15, (op >> 4) & 15, op & 15, op & 255
    hi, lo = op >> 12, op & 15
    R = lambda x: f'r{x}'
    F = lambda x: f'fr{x}'
    if op == 0x0009: return 'nop'
    if op == 0x000B: return 'rts'
    if op == 0x002B: return 'rte'
    if op == 0x0019: return 'div0u'
    if op == 0x0008: return 'clrt'
    if op == 0x0018: return 'sett'
    if op == 0x0028: return 'clrmac'
    if op == 0xF3FD: return 'fschg'
    if op == 0xFBFD: return 'frchg'
    if hi == 0:
        t = {0x2: 'stc sr,', 0xA: None}
        if lo == 3:
            return {0: f'bsrf {R(n)}', 2: f'braf {R(n)}', 8: f'pref @{R(n)}'}.get(m, f'.word {op:04x}')
        if lo in (4, 5, 6): return f"mov.{'bwl'[lo-4]} {R(m)},@(r0,{R(n)})"
        if lo == 7: return f'mul.l {R(m)},{R(n)}'
        if lo in (12, 13, 14): return f"mov.{'bwl'[lo-12]} @(r0,{R(m)}),{R(n)}"
        if lo == 15: return f'mac.l @{R(m)}+,@{R(n)}+'
        if lo == 2: return f"stc {['sr','gbr','vbr','ssr','spc'][m] if m < 5 else 'r%d_bank' % (m-8)},{R(n)}"
        if lo == 10: return f"sts {({0:'mach',1:'macl',2:'pr',5:'fpul',6:'fpscr'}).get(m, '?')},{R(n)}"
        if op & 0xF0FF == 0x0029: return f'movt {R(n)}'
        return f'.word {op:04x}'
    if hi == 1: return f'mov.l {R(m)},@({d4*4},{R(n)})'
    if hi == 2:
        names = {0: 'mov.b', 1: 'mov.w', 2: 'mov.l'}
        if lo in names: return f'{names[lo]} {R(m)},@{R(n)}'
        if lo in (4, 5, 6): return f"mov.{'bwl'[lo-4]} {R(m)},@-{R(n)}"
        return f"{ {7:'div0s',8:'tst',9:'and',10:'xor',11:'or',12:'cmp/str',13:'xtrct',14:'mulu.w',15:'muls.w'}[lo] } {R(m)},{R(n)}"
    if hi == 3:
        nm = {0: 'cmp/eq', 2: 'cmp/hs', 3: 'cmp/ge', 4: 'div1', 5: 'dmulu.l', 6: 'cmp/hi', 7: 'cmp/gt', 8: 'sub', 10: 'subc',
              11: 'subv', 12: 'add', 13: 'dmuls.l', 14: 'addc', 15: 'addv'}.get(lo)
        return f'{nm} {R(m)},{R(n)}' if nm else f'.word {op:04x}'
    if hi == 4:
        t = {0x00: 'shll', 0x01: 'shlr', 0x04: 'rotl', 0x05: 'rotr', 0x08: 'shll2', 0x09: 'shlr2', 0x10: 'dt', 0x11: 'cmp/pz',
             0x15: 'cmp/pl', 0x18: 'shll8', 0x19: 'shlr8', 0x20: 'shal', 0x21: 'shar', 0x24: 'rotcl', 0x25: 'rotcr',
             0x28: 'shll16', 0x29: 'shlr16', 0x0B: 'jsr @', 0x2B: 'jmp @', 0x1B: 'tas.b @'}
        if d8 in t: return f'{t[d8]}{" " if not t[d8].endswith("@") else ""}{R(n)}'
        if d8 == 0x22: return f'sts.l pr,@-{R(n)}'
        if d8 == 0x26: return f'lds.l @{R(n)}+,pr'
        if d8 == 0x2A: return f'lds {R(n)},pr'
        if d8 == 0x5A: return f'lds {R(n)},fpul'
        if d8 == 0x6A: return f'lds {R(n)},fpscr'
        if d8 == 0x0A: return f'lds {R(n)},mach'
        if d8 == 0x1A: return f'lds {R(n)},macl'
        if d8 in (0x02, 0x12, 0x52, 0x62): return f"sts.l {({0:'mach',1:'macl',5:'fpul',6:'fpscr'})[m]},@-{R(n)}"
        if d8 in (0x06, 0x16, 0x56, 0x66): return f"lds.l @{R(n)}+,{({0:'mach',1:'macl',5:'fpul',6:'fpscr'})[m]}"
        if lo == 12: return f'shad {R(m)},{R(n)}'
        if lo == 13: return f'shld {R(m)},{R(n)}'
        if lo == 14: return f'ldc {R(n)},cr{m}'
        if lo == 7: return f'ldc.l @{R(n)}+,cr{m}'
        if lo == 3: return f'stc.l cr{m},@-{R(n)}'
        return f'.word {op:04x}'
    if hi == 5: return f'mov.l @({d4*4},{R(m)}),{R(n)}'
    if hi == 6:
        nm = {0: 'mov.b @{m},{n}', 1: 'mov.w @{m},{n}', 2: 'mov.l @{m},{n}', 3: 'mov {m},{n}', 4: 'mov.b @{m}+,{n}', 5: 'mov.w @{m}+,{n}',
              6: 'mov.l @{m}+,{n}', 7: 'not {m},{n}', 8: 'swap.b {m},{n}', 9: 'swap.w {m},{n}', 10: 'negc {m},{n}', 11: 'neg {m},{n}',
              12: 'extu.b {m},{n}', 13: 'extu.w {m},{n}', 14: 'exts.b {m},{n}', 15: 'exts.w {m},{n}'}[lo]
        return nm.format(m=R(m), n=R(n))
    if hi == 7: return f'add #{s8(d8)},{R(n)}'
    if hi == 8:
        if n == 0: return f'mov.b r0,@({d4},{R(m)})'
        if n == 1: return f'mov.w r0,@({d4*2},{R(m)})'
        if n == 4: return f'mov.b @({d4},{R(m)}),r0'
        if n == 5: return f'mov.w @({d4*2},{R(m)}),r0'
        if n == 8: return f'cmp/eq #{s8(d8)},r0'
        if n in (9, 11, 13, 15): return f"{ {9:'bt',11:'bf',13:'bt/s',15:'bf/s'}[n] } {pc + 4 + s8(d8) * 2:08x}"
        return f'.word {op:04x}'
    if hi == 9:
        a = pc + 4 + d8 * 2
        v = r16(a)
        return f'mov.w @({a:08x}),{R(n)}  ; #{v:04x} ({v - 65536 if v & 0x8000 else v})'
    if hi in (10, 11): return f"{'bra' if hi == 10 else 'bsr'} {pc + 4 + s12(op & 0xFFF) * 2:08x}"
    if hi == 12:
        if n == 7: return f'mova @({(pc & ~3) + 4 + d8 * 4:08x}),r0'
        if n == 3: return f'trapa #{d8}'
        nm = {0: 'mov.b r0,@({d},gbr)', 1: 'mov.w r0,@({d2},gbr)', 2: 'mov.l r0,@({d4},gbr)', 4: 'mov.b @({d},gbr),r0', 5: 'mov.w @({d2},gbr),r0',
              6: 'mov.l @({d4},gbr),r0', 8: 'tst #{d},r0', 9: 'and #{d},r0', 10: 'xor #{d},r0', 11: 'or #{d},r0'}.get(n)
        return nm.format(d=d8, d2=d8 * 2, d4=d8 * 4) if nm else f'.word {op:04x}'
    if hi == 13:
        a = (pc & ~3) + 4 + d8 * 4
        v = r32(a)
        return f'mov.l @({a:08x}),{R(n)}  ; #{v:08x} ({struct.unpack("<f", struct.pack("<I", v))[0]:.6g})'
    if hi == 14: return f'mov #{s8(d8)},{R(n)}'
    # FPU (register names assume single precision, SZ=0)
    nm = {0: 'fadd {m},{n}', 1: 'fsub {m},{n}', 2: 'fmul {m},{n}', 3: 'fdiv {m},{n}', 4: 'fcmp/eq {m},{n}', 5: 'fcmp/gt {m},{n}',
          6: 'fmov.s @(r0,{rm}),{n}', 7: 'fmov.s {m},@(r0,{rn})', 8: 'fmov.s @{rm},{n}', 9: 'fmov.s @{rm}+,{n}', 10: 'fmov.s {m},@{rn}',
          11: 'fmov.s {m},@-{rn}', 12: 'fmov {m},{n}', 14: 'fmac fr0,{m},{n}'}.get(lo)
    if nm: return nm.format(m=F(m), n=F(n), rm=R(m), rn=R(n))
    if lo == 13:
        t = {0: 'fsts fpul,{n}', 1: 'flds {n},fpul', 2: 'float fpul,{n}', 3: 'ftrc {n},fpul', 4: 'fneg {n}', 5: 'fabs {n}', 6: 'fsqrt {n}',
             7: 'fsrra {n}', 8: 'fldi0 {n}', 9: 'fldi1 {n}', 10: 'fcnvsd fpul,{n}', 11: 'fcnvds {n},fpul', 14: 'fipr fv{b},fv{a}'}.get(m)
        if m == 15: return f'fsca fpul,dr{n & 14}' if not n & 1 else f'ftrv xmtrx,fv{n & 12}'
        return t.format(n=F(n), a=n & 12, b=(n & 3) * 4) if t else f'.word {op:04x}'
    return f'.word {op:04x}'


if __name__ == '__main__':
    img = open(sys.argv[1], 'rb').read()
    base, start = int(sys.argv[2], 16), int(sys.argv[3], 16)
    count = int(sys.argv[4]) if len(sys.argv) > 4 else 64
    for pc in range(start, start + count * 2, 2):
        o = pc - base
        print(f'{pc:08x}  {struct.unpack_from("<H", img, o)[0]:04x}  {dis(img, base, pc)}')
