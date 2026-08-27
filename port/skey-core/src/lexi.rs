//! Newtypes over the original engine's numeric spaces.
//!
//! The numeric encoding is load bearing and is NOT an implementation
//! detail we are free to change:
//!
//!   * even index  = upper case, odd index = lower case
//!   * tone level  = +2 per level from the toneless base
//!   * StdVnChar   = lexi index + 0x10000, minus 1 when capitalised,
//!                   plus 2 * tone
//!
//! `changeCase`, `vnToLower`, `appendVowel` and `writeOutput` in the
//! original all rely on this arithmetic. Reordering the enum silently
//! breaks the engine, so the invariants are asserted at compile time in
//! `assert_layout` below.

/// Index into the Vietnamese lexical alphabet. `-1` is the original
/// `vnl_nonVnChar` sentinel, kept as is for phase one fidelity.
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Debug, Default)]
pub struct Lexi(pub i16);

/// Index into the vowel sequence table. `-1` is `vs_nil`.
#[derive(Clone, Copy, PartialEq, Eq, Debug, Default)]
pub struct VSeq(pub i16);

/// Index into the consonant sequence table. `-1` is `cs_nil`.
#[derive(Clone, Copy, PartialEq, Eq, Debug, Default)]
pub struct CSeq(pub i16);

impl Lexi {
    pub const NON_VN: Lexi = Lexi(-1);

    #[inline]
    pub fn is_non_vn(self) -> bool {
        self.0 < 0
    }

    /// `changeCase` in the original: flips the parity bit.
    #[inline]
    pub fn change_case(self) -> Lexi {
        if self.is_non_vn() {
            self
        } else if self.0 & 1 == 0 {
            Lexi(self.0 + 1)
        } else {
            Lexi(self.0 - 1)
        }
    }

    /// `vnToLower` in the original: forces the parity bit to odd.
    #[inline]
    pub fn to_lower(self) -> Lexi {
        if self.is_non_vn() {
            self
        } else if self.0 & 1 == 0 {
            Lexi(self.0 + 1)
        } else {
            self
        }
    }

    #[inline]
    pub fn idx(self) -> usize {
        debug_assert!(self.0 >= 0, "non Vn lexi used as an index");
        self.0 as usize
    }
}

impl VSeq {
    pub const NIL: VSeq = VSeq(-1);
    #[inline]
    pub fn is_nil(self) -> bool {
        self.0 < 0
    }
    #[inline]
    pub fn idx(self) -> usize {
        debug_assert!(self.0 >= 0, "nil vowel sequence used as an index");
        self.0 as usize
    }
}

impl CSeq {
    pub const NIL: CSeq = CSeq(-1);
    #[inline]
    pub fn is_nil(self) -> bool {
        self.0 < 0
    }
    #[inline]
    pub fn idx(self) -> usize {
        debug_assert!(self.0 >= 0, "nil consonant sequence used as an index");
        self.0 as usize
    }
}

/// Offset of the Vietnamese block inside the StdVnChar space.
pub const VN_STD_CHAR_OFFSET: u32 = 0x10000;
pub const INVALID_STD_CHAR: u32 = 0xFFFF_FFFF;

/// Compile time guard on the numeric invariants described above.
/// If any of these fires, the generated tables and the engine are out
/// of sync and every tone decision in the engine is wrong.
const _: () = {
    use crate::lexi_consts as L;
    assert!(L::a.0 == L::A.0 + 1, "parity: lower case is upper + 1");
    assert!(L::A1.0 == L::A.0 + 2, "tone step is 2");
    assert!(L::a5.0 == L::a.0 + 10, "five tone levels above the base");
    assert!(L::ar.0 == L::A.0 + 13, "a with roof follows the six a tones");
    assert!(L::dd.0 == L::d.0 + 2, "dd sits two past d");
    assert!(L::LAST_CHAR == 186);
};
