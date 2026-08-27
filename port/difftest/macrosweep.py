#!/usr/bin/env python3
"""Macro expansion differential sweep.

Each engine gets its own copy of the macro file, because loading a legacy
file rewrites it in place: sharing one file makes the second engine read
different data and looks like a divergence."""
import itertools, os, random, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ORACLE = os.path.join(HERE, '..', 'oracle', 'oracle')
RUST = os.environ.get('RUST_BIN', os.path.join(HERE, '..', 'target', 'release', 'difftest'))
TMP = '/tmp/uk_macro_sweep'

# No two keys may fold to the same value: macCompare compares case
# folded, so such a pair compares equal and the original's qsort leaves
# their relative order, and which one lookup finds, unspecified.
KEYS = ['vn', 'hn', 'tb', 'dd', 'ab', 'a', 'n', 'th', 'ng', 'q', 'z',
        'XY', 'QQ', 'TTT', 'xyz', 'ttt2']
TEXTS = ['Việt Nam', 'Hà Nội', 'trung bình', 'đại học', 'alphabet',
         'ăn cơm', 'ĐẠI HỌC', 'x', 'nhiều chữ hơn một chút', 'ừ']


def make_macro_file(path, utf8_header, seed):
    r = random.Random(seed)
    items = []
    used = set()
    for _ in range(r.randint(3, 10)):
        k = r.choice(KEYS)
        if k in used:
            continue
        used.add(k)
        items.append('%s:%s' % (k, r.choice(TEXTS)))
    body = '\n'.join(items)
    with open(path, 'wb') as f:
        if utf8_header:
            f.write(b'DO NOT DELETE THIS LINE*** version=1 ***\n')
        f.write(body.encode('utf-8'))


def corpus(seed, n_seq):
    r = random.Random(seed)
    pool = 'aeiouydnghctmvzqbxABDHNVTZ '
    out = []
    for _ in range(n_seq):
        for _ in range(r.randint(2, 12)):
            out.append('K%d' % ord(r.choice(pool)))
        out.append('K32')
        out.append('---')
    return out


def main():
    os.makedirs(TMP, exist_ok=True)
    bad = n = 0
    for seed in range(6):
        for utf8 in (True, False):
            body = corpus(seed * 7 + 1, 900)
            for cs in (12, 0, 10, 20, 40, 5):
                for im in (0, 1, 2):
                    for always in (0,):
                        n += 1
                        po = os.path.join(TMP, 'o.txt')
                        pr = os.path.join(TMP, 'r.txt')
                        make_macro_file(po, utf8, seed)
                        make_macro_file(pr, utf8, seed)
                        so = '\n'.join(['L ' + po] + body) + '\n'
                        sr = '\n'.join(['L ' + pr] + body) + '\n'
                        opts = [im, cs, 1, 0, 1, 1, 0]
                        a = subprocess.run([ORACLE] + [str(o) for o in opts],
                                           input=so, capture_output=True, text=True)
                        b = subprocess.run([RUST] + [str(o) for o in opts],
                                           input=sr, capture_output=True, text=True)
                        if a.returncode or b.returncode:
                            print('CRASH', opts, a.stderr[:200], b.stderr[:200])
                            bad += 1
                            continue
                        if a.stdout != b.stdout:
                            bad += 1
                            al, bl = a.stdout.splitlines(), b.stdout.splitlines()
                            i = next((j for j, (x, y) in enumerate(zip(al, bl)) if x != y),
                                     min(len(al), len(bl)))
                            print('DIVERGENCE seed=%d utf8=%s opts=%s line=%d'
                                  % (seed, utf8, opts, i))
                            print('  oracle:', al[i] if i < len(al) else '<eof>')
                            print('  rust  :', bl[i] if i < len(bl) else '<eof>')
                            if bad > 3:
                                return 1
                        # the rewritten file must match too
                        if open(po, 'rb').read() != open(pr, 'rb').read():
                            bad += 1
                            print('REWRITTEN FILE DIFFERS seed=%d utf8=%s' % (seed, utf8))
                            if bad > 3:
                                return 1
    print('macro sweep: %d configurations, %d divergences' % (n, bad))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
