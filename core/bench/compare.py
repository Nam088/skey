#!/usr/bin/env python3
"""Times the original C++ engine and the Rust port on the same corpus.

Both read the same file and parse it before the clock starts, run the same
warm up and the same round count, and are built with comparable
optimisation. Runs are interleaved and the minimum is taken, because
absolute numbers on a laptop drift with thermal state while the ratio
between two interleaved measurements does not."""
import os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
CPP = os.path.join(HERE, 'bench_cpp_o3')
RUST = os.path.join(HERE, '..', 'target', 'release', 'difftest')
CORPUS = os.environ.get('BENCH_CORPUS', '/tmp/bench_corpus.txt')
ROUNDS = os.environ.get('BENCH_ROUNDS', '20')
REPEATS = int(os.environ.get('BENCH_REPEATS', '5'))

CONFIGS = [
    (0, 12, 'telex xutf8'),
    (0, 0, 'telex unicode'),
    (0, 10, 'telex viqr'),
    (0, 20, 'telex tcvn3'),
    (0, 40, 'telex vniwin'),
    (1, 12, 'vni xutf8'),
]


def one(cmd):
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    m = re.search(r'([\d.]+) ns/key', out)
    if not m:
        sys.exit('no measurement from %s' % ' '.join(cmd))
    return float(m.group(1))


def main():
    rows = []
    for im, cs, name in CONFIGS:
        c = r = float('inf')
        for _ in range(REPEATS):
            c = min(c, one([CPP, CORPUS, str(im), str(cs), ROUNDS, 'cpp']))
            r = min(r, one([RUST, 'bench', CORPUS, str(im), str(cs), ROUNDS, 'rust']))
        rows.append((name, c, r))
    print('%-16s %10s %10s %12s' % ('configuration', 'C++ (ns)', 'Rust (ns)', 'Rust / C++'))
    for n, c, r in rows:
        print('%-16s %10.1f %10.1f %11.2fx' % (n, c, r, r / c))
    avg = sum(r / c for _, c, r in rows) / len(rows)
    print('\nmean ratio %.2fx, so Rust takes %.0f%% of the time, %.2fx the speed'
          % (avg, avg * 100, 1 / avg))
    return 0


if __name__ == '__main__':
    sys.exit(main())
