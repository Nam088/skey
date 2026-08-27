#!/usr/bin/env python3
"""User defined key map differential sweep."""
import os, random, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ORACLE = os.path.join(HERE, '..', 'oracle', 'oracle')
RUST = os.environ.get('RUST_BIN', os.path.join(HERE, '..', 'target', 'release', 'difftest'))
PATH = '/tmp/uk_keymap.txt'

LABELS = ['Tone0', 'Tone1', 'Tone2', 'Tone3', 'Tone4', 'Tone5', 'Roof-All',
          'Roof-A', 'Roof-E', 'Roof-O', 'Hook-Bowl', 'Hook-UO', 'Hook-U',
          'Hook-O', 'Bowl', 'D-Mark', 'Telex-W', 'Escape', 'DD', 'dd',
          'A^', 'a^', 'A(', 'a(', 'E^', 'e^', 'O^', 'o^', 'O+', 'o+',
          'U+', 'u+']
CANDIDATE_KEYS = list("sfrxjzawedo0123456789[]{}'`?~.^+*(\\")


def make_map(path, seed):
    r = random.Random(seed)
    lines = ['; generated key map']
    keys = r.sample(CANDIDATE_KEYS, r.randint(4, 14))
    for k in keys:
        lines.append('%s = %s' % (k, r.choice(LABELS)))
    # exercise the parser: comments, odd spacing, duplicates, bad labels,
    # multi character names, and lines with no '='
    lines += ['  z   =   Tone1   ; trailing comment',
              'z = Tone2',
              'ab = Tone3',
              'q = NoSuchLabel',
              'no equals sign here',
              '',
              '; only a comment']
    open(path, 'w').write('\n'.join(lines) + '\n')


def corpus(seed, n):
    r = random.Random(seed)
    pool = "aeiouydnghctmsrfjxzwqbv AEIOUYDNGHT" + "0123456789[]{}'`?~.^+*(\\ "
    out = []
    for _ in range(n):
        for _ in range(r.randint(2, 14)):
            out.append('K%d' % ord(r.choice(pool)))
        out.append('---')
    return out


def main():
    bad = n = 0
    for seed in range(12):
        make_map(PATH, seed)
        body = corpus(seed, 1200)
        for cs in (12, 0, 10, 20, 40):
            for fm in (1, 0):
                for sc in (1, 0):
                    n += 1
                    script = '\n'.join(['U ' + PATH] + body) + '\n'
                    opts = [0, cs, fm, 0, 0, sc, 1]
                    a = subprocess.run([ORACLE] + [str(o) for o in opts],
                                       input=script, capture_output=True, text=True)
                    b = subprocess.run([RUST] + [str(o) for o in opts],
                                       input=script, capture_output=True, text=True)
                    if a.returncode or b.returncode:
                        print('CRASH', opts, a.stderr[:200], b.stderr[:200])
                        bad += 1
                        continue
                    if a.stdout != b.stdout:
                        bad += 1
                        al, bl = a.stdout.splitlines(), b.stdout.splitlines()
                        i = next((j for j, (x, y) in enumerate(zip(al, bl)) if x != y),
                                 min(len(al), len(bl)))
                        print('DIVERGENCE seed=%d opts=%s line=%d' % (seed, opts, i))
                        print('  oracle:', al[i] if i < len(al) else '<eof>')
                        print('  rust  :', bl[i] if i < len(bl) else '<eof>')
                        print('  map file:'); print(open(PATH).read())
                        if bad > 2:
                            return 1
    print('key map sweep: %d configurations, %d divergences' % (n, bad))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
