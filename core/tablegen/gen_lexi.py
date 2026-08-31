#!/usr/bin/env python3
"""Emits the Lexi/VSeq/CSeq constants from src/ukengine/vnlexi.h.

The enum ORDER is load bearing: parity encodes letter case and each tone
level is plus two. lexi.rs asserts that at compile time, so a bad parse
here fails the build rather than corrupting the engine silently."""
import os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
HEADER = os.path.join(HERE, '..', '..', 'archive', 'unikey-legacy', 'ukengine', 'vnlexi.h')


def parse(src, enum_name):
    m = re.search(r'enum\s+%s\s*\{(.*?)\}\s*;' % enum_name, src, re.S)
    body = re.sub(r'//.*', '', m.group(1))
    return [t.strip() for t in body.split(',')
            if t.strip() and '=' not in t]


def main():
    src = open(HEADER).read()
    out = [
        '// @generated from archive/unikey-legacy/ukengine/vnlexi.h by core/tablegen/gen_lexi.py.',
        '// The enum order is load bearing: parity encodes case, each tone',
        '// level is plus two. See the compile time assertions in lexi.rs.',
        '',
        '#![allow(dead_code, non_upper_case_globals)]',
        '',
        'use super::lexi::{Lexi, VSeq, CSeq};',
        '',
        'pub const nonVnChar: Lexi = Lexi(-1);',
    ]
    for i, n in enumerate(parse(src, 'VnLexiName')):
        if n == 'vnl_lastChar':
            out.append('pub const LAST_CHAR: i16 = %d;' % i)
        else:
            out.append('pub const %s: Lexi = Lexi(%d);' % (n[4:], i))
    out.append('')
    out.append('pub const vs_nil: VSeq = VSeq(-1);')
    for i, n in enumerate(parse(src, 'VowelSeq')):
        out.append('pub const %s: VSeq = VSeq(%d);' % (n, i))
    out.append('')
    out.append('pub const cs_nil: CSeq = CSeq(-1);')
    for i, n in enumerate(parse(src, 'ConSeq')):
        out.append('pub const %s: CSeq = CSeq(%d);' % (n, i))
    print('\n'.join(out))


if __name__ == '__main__':
    sys.exit(main())
