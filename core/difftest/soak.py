#!/usr/bin/env python3
"""Large random corpus driven through both engines across the full
option matrix. Complements sweep.py, which covers short sequences
exhaustively; this one covers long sequences with control commands."""
import os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ORACLE = os.path.join(HERE, '..', 'oracle', 'oracle')
RUST = os.path.join(HERE, '..', 'target', 'release', 'difftest')
SEQS = int(os.environ.get('SOAK_SEQS', '120000'))


def run(binary, opts, script):
    r = subprocess.run([binary] + [str(o) for o in opts],
                       input=script, capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit('%s failed for %s: %s' % (binary, opts, r.stderr[:400]))
    return r.stdout


def main():
    corpus = run(RUST, ['gen', SEQS], '')
    bad = n = 0
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
                            opts = [im, cs, fm, ms, 0, sc, ar]
                            n += 1
                            a = run(ORACLE, opts, corpus)
                            b = run(RUST, opts, corpus)
                            if a != b:
                                bad += 1
                                al, bl = a.splitlines(), b.splitlines()
                                i = next((j for j, (x, y) in enumerate(zip(al, bl))
                                          if x != y), 0)
                                print('DIVERGENCE opts=%s line=%d' % (opts, i))
                                print('  oracle:', al[i] if i < len(al) else '<eof>')
                                print('  rust  :', bl[i] if i < len(bl) else '<eof>')
    print('%d sequences x %d option sets, %d divergences' % (SEQS, n, bad))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
