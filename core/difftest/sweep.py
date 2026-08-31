#!/usr/bin/env python3
"""Differential sweep: drives the original C++ engine and the Rust port
with identical input and fails on the first divergence."""
import itertools, os, random, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ORACLE = os.path.join(HERE, '..', 'oracle', 'oracle')
RUST = os.path.join(HERE, '..', 'target', 'release', 'difftest')

# Letters that carry Vietnamese meaning in Telex/VNI/VIQR, plus the
# tone and modifier keys and a word break.
ALPHA = 'aeiouydnghctmprsfjxzwqkblv'
EXTRA = " 0123456789'`?~.^+*("
BACK = '\x08'   # encoded as command B


def run(binary, opts, script):
    p = subprocess.run([binary] + [str(o) for o in opts],
                       input=script, capture_output=True, text=True)
    return p.stdout


# Control commands mixed into random sequences: backspace, restore key
# strokes, single mode, and the shift/capslock callback state.
CTRL = {'\x08': 'B', '\x01': 'R', '\x02': 'S',
        '\x03': 'C 0 0', '\x04': 'C 1 0', '\x05': 'C 0 1', '\x06': 'C 1 1'}


def script_of(seqs):
    out = []
    for s in seqs:
        for ch in s:
            cmd = CTRL.get(ch)
            out.append(cmd if cmd else 'K%d' % ord(ch))
        out.append('---')
        out.append('C 0 0')
    return '\n'.join(out) + '\n'


def compare(opts, seqs, label):
    script = script_of(seqs)
    a = run(ORACLE, opts, script)
    b = run(RUST, opts, script)
    if a == b:
        return True
    al, bl = a.splitlines(), b.splitlines()
    # Locate the offending sequence for a readable report.
    idx = next((i for i, (x, y) in enumerate(zip(al, bl)) if x != y), min(len(al), len(bl)))
    seq_no = a[:sum(len(l) + 1 for l in al[:idx])].count('--')
    print('DIVERGENCE  opts=%s  %s' % (opts, label))
    print('  sequence  : %r' % (seqs[seq_no] if seq_no < len(seqs) else '?'))
    print('  at line   : %d' % idx)
    print('  oracle    : %s' % (al[idx] if idx < len(al) else '<eof>'))
    print('  rust      : %s' % (bl[idx] if idx < len(bl) else '<eof>'))
    return False


def exhaustive(alpha, n):
    return [''.join(p) for p in itertools.product(alpha, repeat=n)]


def main():
    random.seed(20260826)
    total = 0
    fails = 0

    # Option matrix: im x charset x freeMarking x modernStyle x spellCheck x autoRestore
    matrix = []
    # Input methods compared against the C++ oracle. Id 4 needs a user
    # key map, which keymapsweep.py covers on its own. Id 5 is Simple
    # Telex: 3.6 has no implementation to compare against, so it is
    # covered by unikey-core/tests/simple_telex.rs instead.
    for im in (0, 1, 2, 3):
        for cs in (12, 0):
            for fm in (1, 0):
                for ms in (1, 0):
                    for sc in (1, 0):
                        for ar in (1, 0):
                            matrix.append([im, cs, fm, ms, 0, sc, ar])

    # 1. exhaustive short sequences on the core alphabet
    core = 'aeiouydnghctmsrfjxzwq '
    for n in (1, 2, 3):
        seqs = exhaustive(core, n)
        for opts in matrix:
            total += len(seqs)
            if not compare(opts, seqs, 'exhaustive n=%d' % n):
                fails += 1
                return 1
        print('exhaustive n=%d: %d sequences x %d option sets  OK'
              % (n, len(seqs), len(matrix)))

    # 2. exhaustive length four, default options only (too large for the
    #    full matrix, and covered by the random phase below)
    seqs = exhaustive(core, 4)
    for opts in (matrix[0], matrix[8], matrix[16]):
        total += len(seqs)
        if not compare(opts, seqs, 'exhaustive n=4'):
            return 1
    print('exhaustive n=4: %d sequences x 3 option sets  OK' % len(seqs))

    # 3. random longer sequences with backspaces, over the full matrix
    pool = ALPHA + ALPHA.upper() + EXTRA + BACK * 3 + ''.join(CTRL) * 2
    for opts in matrix:
        seqs = [''.join(random.choice(pool) for _ in range(random.randint(5, 20)))
                for _ in range(6000)]
        total += len(seqs)
        if not compare(opts, seqs, 'random'):
            return 1
    print('random: 6000 sequences x %d option sets  OK' % len(matrix))

    print('\nALL MATCH  (%d sequences compared, 0 divergences)' % total)
    return 0


if __name__ == '__main__':
    sys.exit(main())
