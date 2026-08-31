//! Sequence tables computed at compile time.
//!
//! Every `lookupVSeq` and `lookupCSeq` call in the original is one of
//! three shapes: extend a sequence by one symbol, rebuild a sequence
//! after a mark was removed from it, or turn a single symbol into a
//! sequence. All three are total functions of small domains, so none of
//! them needs a search at run time.
//!
//! The original sorted copies of both tables with `qsort` at start up and
//! then ran `bsearch` with a comparator that walked three elements per
//! comparison. What replaces it here is one array load.
//!
//! Everything below is derived from `tables::VSEQ` and `tables::CSEQ`,
//! which are dumped from the compiled C++, so these cannot drift from the
//! original data. The engine keeps the search functions and, in debug
//! builds, asserts that table and search agree on every use.

use super::lexi::{CSeq, Lexi, VSeq};
use super::lexi_consts as L;
use super::tables::{CSEQ, CSEQ_COUNT, VSEQ, VSEQ_COUNT};

/// Lexi values run from -1 to 185, so shift by one to index by them.
pub const LEXI_SPAN: usize = 187;

#[inline]
const fn li(l: Lexi) -> usize {
    (l.0 + 1) as usize
}

// ------------------------------------------------------ symbol codes

/// Vowel symbols that actually appear in the sequence table, numbered in
/// order of first appearance. Code 0 means "no symbol".
const fn vowel_codes() -> ([u8; LEXI_SPAN], usize) {
    let mut code = [0u8; LEXI_SPAN];
    let mut next = 1u8;
    let mut i = 0;
    while i < VSEQ_COUNT {
        let mut p = 0;
        while p < 3 {
            let v = VSEQ[i].v[p];
            if v.0 >= 0 && code[li(v)] == 0 {
                code[li(v)] = next;
                next += 1;
            }
            p += 1;
        }
        i += 1;
    }
    (code, next as usize)
}

const fn cons_codes() -> ([u8; LEXI_SPAN], usize) {
    let mut code = [0u8; LEXI_SPAN];
    let mut next = 1u8;
    let mut i = 0;
    while i < CSEQ_COUNT {
        let mut p = 0;
        while p < 3 {
            let c = CSEQ[i].c[p];
            if c.0 >= 0 && code[li(c)] == 0 {
                code[li(c)] = next;
                next += 1;
            }
            p += 1;
        }
        i += 1;
    }
    (code, next as usize)
}

pub const VOWEL_CODE: [u8; LEXI_SPAN] = vowel_codes().0;
pub const VOWEL_CODES: usize = vowel_codes().1;
pub const CONS_CODE: [u8; LEXI_SPAN] = cons_codes().0;
pub const CONS_CODES: usize = cons_codes().1;

// --------------------------------------------------- generation search
//
// Used only inside const evaluation, so its cost is compile time.

const fn find_v(a: i16, b: i16, c: i16) -> i16 {
    let mut i = 0;
    while i < VSEQ_COUNT {
        let v = &VSEQ[i].v;
        if v[0].0 == a && v[1].0 == b && v[2].0 == c {
            return i as i16;
        }
        i += 1;
    }
    -1
}

const fn find_c(a: i16, b: i16, c: i16) -> i16 {
    let mut i = 0;
    while i < CSEQ_COUNT {
        let v = &CSEQ[i].c;
        if v[0].0 == a && v[1].0 == b && v[2].0 == c {
            return i as i16;
        }
        i += 1;
    }
    -1
}

const NON: i16 = -1;

// ------------------------------------------------------ vowel tables

/// A single vowel as a sequence: `lookupVSeq(sym)`.
const fn build_v_single() -> [i8; LEXI_SPAN] {
    let mut t = [-1i8; LEXI_SPAN];
    let mut l = 0i16;
    while l < 186 {
        t[li(Lexi(l))] = find_v(l, NON, NON) as i8;
        l += 1;
    }
    t
}

/// Extend a vowel sequence by one vowel. A length three sequence cannot
/// be extended, which is the `vs_nil` the original returns for it.
const fn build_v_extend() -> [[i8; 16]; VSEQ_COUNT] {
    let mut t = [[-1i8; 16]; VSEQ_COUNT];
    let mut i = 0;
    while i < VSEQ_COUNT {
        let info = &VSEQ[i];
        let mut l = 0i16;
        while l < 186 {
            let code = VOWEL_CODE[li(Lexi(l))];
            if code != 0 {
                let r = match info.len {
                    1 => find_v(info.v[0].0, l, NON),
                    2 => find_v(info.v[0].0, info.v[1].0, l),
                    _ => NON,
                };
                t[i][code as usize] = r as i8;
            }
            l += 1;
        }
        i += 1;
    }
    t
}

const fn un_roof(x: i16) -> i16 {
    if x == L::ar.0 {
        L::a.0
    } else if x == L::er.0 {
        L::e.0
    } else {
        L::o.0
    }
}

const fn un_hook(x: i16) -> i16 {
    if x == L::ab.0 {
        L::a.0
    } else if x == L::uh.0 {
        L::u.0
    } else {
        L::o.0
    }
}

/// The sequence left after the roof is taken off the position that
/// carries it, which is what the original recomputes with a fresh
/// lookup over the mutated buffer.
const fn build_no_roof() -> [i8; VSEQ_COUNT] {
    let mut t = [-1i8; VSEQ_COUNT];
    let mut i = 0;
    while i < VSEQ_COUNT {
        let info = &VSEQ[i];
        if info.roof_pos >= 0 {
            let p = info.roof_pos as usize;
            let mut v = [info.v[0].0, info.v[1].0, info.v[2].0];
            v[p] = un_roof(v[p]);
            t[i] = find_v(v[0], v[1], v[2]) as i8;
        }
        i += 1;
    }
    t
}

const fn build_no_hook() -> [i8; VSEQ_COUNT] {
    let mut t = [-1i8; VSEQ_COUNT];
    let mut i = 0;
    while i < VSEQ_COUNT {
        let info = &VSEQ[i];
        if info.hook_pos >= 0 {
            let p = info.hook_pos as usize;
            let mut v = [info.v[0].0, info.v[1].0, info.v[2].0];
            v[p] = un_hook(v[p]);
            t[i] = find_v(v[0], v[1], v[2]) as i8;
        }
        i += 1;
    }
    t
}

/// The three fixed prefix rewrites the uo handling needs, each keeping
/// the third vowel of the current sequence.
const fn build_prefix(a: i16, b: i16) -> [i8; VSEQ_COUNT] {
    let mut t = [-1i8; VSEQ_COUNT];
    let mut i = 0;
    while i < VSEQ_COUNT {
        t[i] = find_v(a, b, VSEQ[i].v[2].0) as i8;
        i += 1;
    }
    t
}

pub const V_SINGLE: [i8; LEXI_SPAN] = build_v_single();
pub const V_EXTEND: [[i8; 16]; VSEQ_COUNT] = build_v_extend();
pub const V_NO_ROOF: [i8; VSEQ_COUNT] = build_no_roof();
pub const V_NO_HOOK: [i8; VSEQ_COUNT] = build_no_hook();
/// u with roof on the o, keeping the third vowel: `lookupVSeq(u, or, v2)`.
pub const V_U_OR: [i8; VSEQ_COUNT] = build_prefix(L::u.0, L::or.0);
/// Back to plain uo: `lookupVSeq(u, o, v2)`.
pub const V_U_O: [i8; VSEQ_COUNT] = build_prefix(L::u.0, L::o.0);
/// Both hooks: `lookupVSeq(uh, oh, v2)`.
pub const V_UH_OH: [i8; VSEQ_COUNT] = build_prefix(L::uh.0, L::oh.0);

// -------------------------------------------------- consonant tables

const fn build_c_single() -> [i8; LEXI_SPAN] {
    let mut t = [-1i8; LEXI_SPAN];
    let mut l = 0i16;
    while l < 186 {
        t[li(Lexi(l))] = find_c(l, NON, NON) as i8;
        l += 1;
    }
    t
}

const fn build_c_extend() -> [[i8; 24]; CSEQ_COUNT] {
    let mut t = [[-1i8; 24]; CSEQ_COUNT];
    let mut i = 0;
    while i < CSEQ_COUNT {
        let info = &CSEQ[i];
        let mut l = 0i16;
        while l < 186 {
            let code = CONS_CODE[li(Lexi(l))];
            if code != 0 {
                let r = match info.len {
                    1 => find_c(info.c[0].0, l, NON),
                    2 => find_c(info.c[0].0, info.c[1].0, l),
                    _ => NON,
                };
                t[i][code as usize] = r as i8;
            }
            l += 1;
        }
        i += 1;
    }
    t
}

pub const C_SINGLE: [i8; LEXI_SPAN] = build_c_single();
pub const C_EXTEND: [[i8; 24]; CSEQ_COUNT] = build_c_extend();

// --------------------------------------------------------- accessors

#[inline]
pub fn v_single(sym: Lexi) -> VSeq {
    if sym.0 < 0 {
        VSeq::NIL
    } else {
        VSeq(V_SINGLE[li(sym)] as i16)
    }
}

#[inline]
pub fn v_extend(vs: VSeq, sym: Lexi) -> VSeq {
    if vs.0 < 0 || sym.0 < 0 {
        return VSeq::NIL;
    }
    let code = VOWEL_CODE[li(sym)];
    if code == 0 {
        return VSeq::NIL;
    }
    VSeq(V_EXTEND[vs.0 as usize][code as usize] as i16)
}

#[inline]
pub fn c_single(sym: Lexi) -> CSeq {
    if sym.0 < 0 {
        CSeq::NIL
    } else {
        CSeq(C_SINGLE[li(sym)] as i16)
    }
}

#[inline]
pub fn c_extend(cs: CSeq, sym: Lexi) -> CSeq {
    if cs.0 < 0 || sym.0 < 0 {
        return CSeq::NIL;
    }
    let code = CONS_CODE[li(sym)];
    if code == 0 {
        return CSeq::NIL;
    }
    CSeq(C_EXTEND[cs.0 as usize][code as usize] as i16)
}

#[inline]
pub fn v_no_roof(vs: VSeq) -> VSeq {
    VSeq(V_NO_ROOF[vs.idx()] as i16)
}

#[inline]
pub fn v_no_hook(vs: VSeq) -> VSeq {
    VSeq(V_NO_HOOK[vs.idx()] as i16)
}

#[inline]
pub fn v_u_or(vs: VSeq) -> VSeq {
    VSeq(V_U_OR[vs.idx()] as i16)
}

#[inline]
pub fn v_u_o(vs: VSeq) -> VSeq {
    VSeq(V_U_O[vs.idx()] as i16)
}

#[inline]
pub fn v_uh_oh(vs: VSeq) -> VSeq {
    VSeq(V_UH_OH[vs.idx()] as i16)
}

// -------------------------------------------------- tone position table
//
// `getTonePosition` is a pure function of the sequence, whether the
// sequence is terminated, and the modernStyle option, and it is the most
// called helper in the engine. Precomputed, it is one load instead of
// half a dozen branches.

const fn build_tone_pos() -> [i8; VSEQ_COUNT * 4] {
    let mut t = [0i8; VSEQ_COUNT * 4];
    let mut i = 0;
    while i < VSEQ_COUNT {
        let info = &VSEQ[i];
        let mut term = 0;
        while term < 2 {
            let mut modern = 0;
            while modern < 2 {
                let r = if info.len == 1 {
                    0
                } else if info.roof_pos != -1 {
                    info.roof_pos
                } else if info.hook_pos != -1 {
                    if i == L::vs_uhoh.0 as usize
                        || i == L::vs_uhohi.0 as usize
                        || i == L::vs_uhohu.0 as usize
                    {
                        1
                    } else {
                        info.hook_pos
                    }
                } else if info.len == 3
                    || (modern == 1
                        && (i == L::vs_oa.0 as usize
                            || i == L::vs_oe.0 as usize
                            || i == L::vs_uy.0 as usize))
                {
                    1
                } else if term == 1 {
                    0
                } else {
                    1
                };
                t[i * 4 + term * 2 + modern] = r;
                modern += 1;
            }
            term += 1;
        }
        i += 1;
    }
    t
}

pub const TONE_POS: [i8; VSEQ_COUNT * 4] = build_tone_pos();

#[inline]
pub fn tone_pos(vs: VSeq, terminated: bool, modern: bool) -> i32 {
    TONE_POS[vs.idx() * 4 + (terminated as usize) * 2 + modern as usize] as i32
}

// ------------------------------------------- consonant vowel validity
//
// `isValidCV` tested two special cases with branches and then scanned a
// static list for the consonant k. As a bitmap it is one AND.

const fn build_cv_valid() -> [u128; CSEQ_COUNT] {
    // Vowel sequences the consonant k may precede.
    const K_OK: [i16; 12] = [
        L::vs_e.0,
        L::vs_i.0,
        L::vs_y.0,
        L::vs_er.0,
        L::vs_eo.0,
        L::vs_eu.0,
        L::vs_eru.0,
        L::vs_ia.0,
        L::vs_ie.0,
        L::vs_ier.0,
        L::vs_ieu.0,
        L::vs_ieru.0,
    ];
    let mut t = [0u128; CSEQ_COUNT];
    let mut c = 0;
    while c < CSEQ_COUNT {
        let mut v = 0;
        while v < VSEQ_COUNT {
            let first = VSEQ[v].v[0].0;
            let ok = if (c == L::cs_gi.0 as usize && first == L::i.0)
                || (c == L::cs_qu.0 as usize && first == L::u.0)
            {
                false
            } else if c == L::cs_k.0 as usize {
                let mut found = false;
                let mut j = 0;
                while j < 12 {
                    if K_OK[j] as usize == v {
                        found = true;
                    }
                    j += 1;
                }
                found
            } else {
                true
            };
            if ok {
                t[c] |= 1u128 << v;
            }
            v += 1;
        }
        c += 1;
    }
    t
}

pub const CV_VALID: [u128; CSEQ_COUNT] = build_cv_valid();

#[inline]
pub fn is_valid_cv(c: CSeq, v: VSeq) -> bool {
    if c.0 < 0 || v.0 < 0 {
        return true;
    }
    CV_VALID[c.idx()] & (1u128 << v.0) != 0
}
