#!/usr/bin/env python3
"""The five OpenKey style options have no reference to compare against,
since the C++ original has none of them. What can be checked automatically
is the shape of their effect on a large random corpus: each one must change
something, or it is dead code, and the four that are meant to be narrow
must not change much, or their guard is reaching ordinary Vietnamese."""
import os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
RUST = os.path.join(HERE, '..', 'target', 'release', 'difftest')

# argument index in difftest's argv, and the upper bound on how often the
# option may fire. upper_case_first_char touches the first letter of every
# sequence, so it has no bound.
OPTIONS = [
    ('quick_telex', 7, 5.0),
    ('quick_start_consonant', 8, 5.0),
    ('quick_end_consonant', 9, 5.0),
    ('upper_case_first_char', 10, None),
    ('allow_consonant_zfwj', 11, 20.0),
]


def run(opts, corpus):
    r = subprocess.run([RUST] + [str(o) for o in opts],
                       input=corpus, capture_output=True, text=True)
    if r.returncode:
        sys.exit('difftest failed for %s: %s' % (opts, r.stderr[:300]))
    return r.stdout


def main():
    corpus = subprocess.run([RUST, 'gen', os.environ.get('QUICK_SEQS', '20000')],
                            capture_output=True, text=True).stdout
    base = [0, 12, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0]
    reference = run(base, corpus)
    bad = 0
    for name, idx, bound in OPTIONS:
        opts = list(base)
        opts[idx] = 1
        out = run(opts, corpus)
        a, b = reference.splitlines(), out.splitlines()
        if len(a) != len(b):
            print('%-24s TRACE LENGTH CHANGED, %d against %d' % (name, len(a), len(b)))
            bad += 1
            continue
        differing = sum(1 for x, y in zip(a, b) if x != y)
        pct = 100.0 * differing / max(len(a), 1)
        print('%-24s %6d of %d trace lines differ (%5.2f%%)' % (name, differing, len(a), pct))
        if differing == 0:
            print('  FAIL: the option did nothing at all on this corpus')
            bad += 1
        elif bound is not None and pct > bound:
            print('  FAIL: fires far more often than %.1f%%, the guard is too loose' % bound)
            bad += 1
    print()
    print('quick sweep: %d options, %d failures' % (len(OPTIONS), bad))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
