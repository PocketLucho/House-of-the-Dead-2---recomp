import sys,re,collections
for p in sys.argv[1:]:
    c=collections.Counter(); ex={}
    for l in open(p,errors='replace'):
        if not l.startswith('MISMATCH'): continue
        m=re.match(r'MISMATCH block (\S+) fpu \S+ size \d+:\s+(.*)',l.strip())
        regs=m[2].split()
        names=tuple(sorted(r.split(':')[0] for r in regs))
        kind='other'
        if names==('sr',):
            a,b=[int(x,16) for x in regs[0].split(':')[1].split('/')]
            kind='sr M/Q bits (div0/div1 fusion)' if (a^b)&~0x300==0 else f'sr {a^b:x}'
        elif 'pc' in names and any(r.startswith('pc:0c000600') or r.startswith('pc:8c000600') for r in regs): kind='interrupt inside block (ldc sr)'
        elif m[2].startswith('AOT write e0') or m[2].startswith('AOT read e0'): kind='store queue (verifier journal artifact)'
        c[kind]+=1; ex.setdefault(kind,(m[1],m[2]))
    print(p, dict(c)); [print('  ',k,v) for k,v in ex.items()]
