#!/usr/bin/env python3
"""Holds the context based C ABI to the same standard as the engine.

The C harness also keeps a second engine instance busy on every key, so
any shared state between instances shows up as a divergence."""
import os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ORACLE = os.path.join(HERE, '..', 'oracle', 'oracle')
CTX = os.path.join(HERE, '..', 'oracle', 'ctx_harness')
GEN = os.path.join(HERE, '..', 'target', 'release', 'difftest')
CHARSETS = [0, 1, 2, 3, 4, 5, 6, 7, 10, 11, 12, 20, 21, 22, 23, 24, 25, 40, 41, 42, 43]


def run(binary, opts, corpus):
    r = subprocess.run([binary] + [str(o) for o in opts],
                       input=corpus, capture_output=True, text=True)
    if r.returncode:
        return 'CRASH: ' + r.stderr[:200]
    return r.stdout


def main():
    seqs = os.environ.get('CTX_SEQS', '2000')
    corpus = subprocess.run([GEN, 'gen', seqs], capture_output=True, text=True).stdout
    bad = n = 0
    for cs in CHARSETS:
        # Input methods compared against the C++ oracle. Id 4 needs a user
        # key map, which keymapsweep.py covers on its own. Id 5 is Simple
        # Telex: 3.6 has no implementation to compare against, so it is
        # covered by unikey-core/tests/simple_telex.rs instead.
        for im in (0, 1, 2, 3):
            for fm in (1, 0):
                for sc in (1, 0):
                    for ar in (1, 0):
                        for ms in (1, 0):
                            opts = [im, cs, fm, ms, 0, sc, ar]
                            n += 1
                            a = run(ORACLE, opts, corpus)
                            b = run(CTX, opts, corpus)
                            if a != b:
                                bad += 1
                                al, bl = a.splitlines(), b.splitlines()
                                i = next((j for j, (x, y) in enumerate(zip(al, bl))
                                          if x != y), 0)
                                print('DIVERGENCE opts=%s line=%d' % (opts, i))
                                print('  oracle:', al[i] if i < len(al) else '<eof>')
                                print('  ctx   :', bl[i] if i < len(bl) else '<eof>')
                                if bad > 2:
                                    return 1
    print('context C ABI: %d configurations, %d divergences' % (n, bad))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
