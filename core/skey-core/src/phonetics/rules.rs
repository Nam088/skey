//! Phonotactic validation and sequence lookup rules.

use crate::phonetics::lexi::{CSeq, Lexi, VSeq};
use crate::phonetics::lexi_consts as L;
use crate::phonetics::seq;
use crate::phonetics::tables::{self, CSEQ, VSEQ};

/// Vowel sequences that may follow the consonant `k`.
#[cfg(debug_assertions)]
const K_VSEQ_MASK: u128 = (1 << 3)   // vs_e
    | (1 << 5)   // vs_i
    | (1 << 11)  // vs_y
    | (1 << 4)   // vs_er
    | (1 << 18)  // vs_eo
    | (1 << 19)  // vs_eu
    | (1 << 20)  // vs_eru
    | (1 << 21)  // vs_ia
    | (1 << 22)  // vs_ie
    | (1 << 23)  // vs_ier
    | (1 << 48)  // vs_ieu
    | (1 << 49); // vs_ieru

#[cfg(debug_assertions)]
const _: () = {
    // The mask is written by hand, so pin it to the generated enum.
    assert!(K_VSEQ_MASK & (1u128 << L::vs_e.0) != 0);
    assert!(K_VSEQ_MASK & (1u128 << L::vs_ieru.0) != 0);
    assert!(K_VSEQ_MASK.count_ones() == 12);
};

#[cfg(debug_assertions)]
/// Packs a triple into the sorted lookup key. The `+ 1` folds the
/// `nonVnChar` sentinel of -1 into 0 so the packed key orders exactly
/// like the original's three way lexicographic comparator.
#[inline]
pub fn pack3(a: Lexi, b: Lexi, c: Lexi) -> u32 {
    (((a.0 + 1) as u32) << 16) | (((b.0 + 1) as u32) << 8) | ((c.0 + 1) as u32)
}

#[cfg(debug_assertions)]
/// Binary search over a flat, compile time sorted key array. The
/// original sorted a copy of the table with `qsort` at start up and then
/// used `bsearch` with a comparator that looped over three elements per
/// comparison; this is the same search with no start up cost, no
/// indirect call, and one integer compare per step.
pub fn lookup_vseq3(v1: Lexi, v2: Lexi, v3: Lexi) -> VSeq {
    let key = pack3(v1, v2, v3);
    let mut lo = 0usize;
    let mut hi = tables::VSEQ_COUNT;
    while lo < hi {
        let mid = (lo + hi) / 2;
        let k = tables::VSEQ_KEYS[mid];
        if k == key {
            return VSeq(tables::VSEQ_IDX[mid] as i16);
        } else if k < key {
            lo = mid + 1;
        } else {
            hi = mid;
        }
    }
    VSeq::NIL
}

#[cfg(debug_assertions)]
#[inline]
pub fn lookup_vseq1(v1: Lexi) -> VSeq {
    lookup_vseq3(v1, Lexi::NON_VN, Lexi::NON_VN)
}

#[cfg(debug_assertions)]
#[inline]
pub fn lookup_vseq2(v1: Lexi, v2: Lexi) -> VSeq {
    lookup_vseq3(v1, v2, Lexi::NON_VN)
}

#[cfg(debug_assertions)]
pub fn lookup_cseq3(c1: Lexi, c2: Lexi, c3: Lexi) -> CSeq {
    let key = pack3(c1, c2, c3);
    let mut lo = 0usize;
    let mut hi = tables::CSEQ_COUNT;
    while lo < hi {
        let mid = (lo + hi) / 2;
        let k = tables::CSEQ_KEYS[mid];
        if k == key {
            return CSeq(tables::CSEQ_IDX[mid] as i16);
        } else if k < key {
            lo = mid + 1;
        } else {
            hi = mid;
        }
    }
    CSeq::NIL
}

#[cfg(debug_assertions)]
#[inline]
pub fn lookup_cseq1(c1: Lexi) -> CSeq {
    lookup_cseq3(c1, Lexi::NON_VN, Lexi::NON_VN)
}

#[cfg(debug_assertions)]
#[inline]
pub fn lookup_cseq2(c1: Lexi, c2: Lexi) -> CSeq {
    lookup_cseq3(c1, c2, Lexi::NON_VN)
}

/// One AND against a precomputed bitmap. The original tested gi and qu
/// with branches and then scanned a static list for k.
#[inline]
pub fn is_valid_cv(c: CSeq, v: VSeq) -> bool {
    let r = seq::is_valid_cv(c, v);
    #[cfg(debug_assertions)]
    debug_assert_eq!(r, is_valid_cv_reference(c, v));
    r
}

#[cfg(debug_assertions)]
pub fn is_valid_cv_reference(c: CSeq, v: VSeq) -> bool {
    if c.is_nil() || v.is_nil() {
        return true;
    }
    let v_info = &VSEQ[v.idx()];
    if (c == L::cs_gi && v_info.v[0] == L::i) || (c == L::cs_qu && v_info.v[0] == L::u) {
        return false; // gi does not go with i, qu does not go with u
    }
    if c == L::cs_k {
        return K_VSEQ_MASK & (1u128 << v.0) != 0;
    }
    true
}

/// Table backed replacements. The search functions stay in the file as
/// the debug shadow, which is what makes swapping in a generated table
/// safe rather than hopeful.
#[inline]
pub fn vseq1(sym: Lexi) -> VSeq {
    let r = seq::v_single(sym);
    #[cfg(debug_assertions)]
    debug_assert_eq!(r, lookup_vseq1(sym));
    r
}

#[inline]
pub fn cseq1(sym: Lexi) -> CSeq {
    let r = seq::c_single(sym);
    #[cfg(debug_assertions)]
    debug_assert_eq!(r, lookup_cseq1(sym));
    r
}

#[inline]
pub fn vseq_extend(vs: VSeq, sym: Lexi) -> VSeq {
    let r = seq::v_extend(vs, sym);
    #[cfg(debug_assertions)]
    {
        let want = match VSEQ[vs.idx()].len {
            3 => VSeq::NIL,
            2 => lookup_vseq3(VSEQ[vs.idx()].v[0], VSEQ[vs.idx()].v[1], sym),
            _ => lookup_vseq2(VSEQ[vs.idx()].v[0], sym),
        };
        debug_assert_eq!(r, want);
    }
    r
}

#[inline]
pub fn cseq_extend(cs: CSeq, sym: Lexi) -> CSeq {
    if cs.is_nil() {
        return CSeq::NIL;
    }
    let r = seq::c_extend(cs, sym);
    #[cfg(debug_assertions)]
    {
        let want = match CSEQ[cs.idx()].len {
            3 => CSeq::NIL,
            2 => lookup_cseq3(CSEQ[cs.idx()].c[0], CSEQ[cs.idx()].c[1], sym),
            _ => lookup_cseq2(CSEQ[cs.idx()].c[0], sym),
        };
        debug_assert_eq!(r, want);
    }
    r
}

pub fn is_valid_vc(v: VSeq, c: CSeq) -> bool {
    if v.is_nil() || c.is_nil() {
        return true;
    }
    if !VSEQ[v.idx()].con_suffix {
        return false;
    }
    if !CSEQ[c.idx()].suffix {
        return false;
    }
    // One AND, replacing the bsearch over 153 sorted pairs.
    tables::VC_VALID[v.idx()] & (1u32 << c.0) != 0
}

// Fusing this whole relation into one 31 by 71 by 31 bitmap was tried and
// measured no faster: the common path is already two well predicted nil
// tests and one masked load. It cost 8.8 KB of tables for nothing, so it
// is not here.
pub fn is_valid_cvc(c1: CSeq, v: VSeq, c2: CSeq) -> bool {
    if v.is_nil() {
        return c1.is_nil() || !c2.is_nil();
    }
    if c1.is_nil() {
        return is_valid_vc(v, c2);
    }
    if c2.is_nil() {
        return is_valid_cv(c1, v);
    }

    let ok_cv = is_valid_cv(c1, v);
    let ok_vc = is_valid_vc(v, c2);

    if ok_cv && ok_vc {
        return true;
    }

    if !ok_vc {
        // quyn, quynh
        if c1 == L::cs_qu && v == L::vs_y && (c2 == L::cs_n || c2 == L::cs_nh) {
            return true;
        }
        // gieng, gie^ng
        if c1 == L::cs_gi && (v == L::vs_e || v == L::vs_er) && (c2 == L::cs_n || c2 == L::cs_ng) {
            return true;
        }
    }
    false
}

#[inline]
pub fn std_no_tone(l: Lexi) -> Lexi {
    Lexi(tables::STD_NO_TONE[l.idx()] as i16)
}

#[inline]
pub fn is_vowel(l: Lexi) -> bool {
    if l.is_non_vn() {
        false
    } else {
        tables::IS_VOWEL[l.idx()]
    }
}
