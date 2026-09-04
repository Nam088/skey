//! Vietnamese phonetic character representation and lexical spaces.
//!
//! Numeric properties:
//! - Even index: uppercase, Odd index: lowercase.
//! - Tone level: +2 per tone level from base.
//! - StdVnChar: lexical index + 0x10000, minus 1 when capitalized, plus 2 * tone.

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
    /// Sentinel representing a non-Vietnamese character.
    pub const NON_VN: Lexi = Lexi(-1);

    /// Checks if this symbol is a non-Vietnamese character.
    #[inline]
    pub fn is_non_vn(self) -> bool {
        self.0 < 0
    }

    /// Toggles the casing of the Vietnamese lexical symbol.
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

    /// Converts this Vietnamese lexical symbol to lowercase.
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

    /// Returns the non-negative index value.
    #[inline]
    pub fn idx(self) -> usize {
        debug_assert!(self.0 >= 0, "non Vn lexi used as an index");
        self.0 as usize
    }
}

impl VSeq {
    /// Sentinel representing an empty or nil vowel sequence.
    pub const NIL: VSeq = VSeq(-1);

    /// Checks whether this vowel sequence is nil.
    #[inline]
    pub fn is_nil(self) -> bool {
        self.0 < 0
    }

    /// Returns the vowel sequence table index.
    #[inline]
    pub fn idx(self) -> usize {
        debug_assert!(self.0 >= 0, "nil vowel sequence used as an index");
        self.0 as usize
    }
}

impl CSeq {
    /// Sentinel representing an empty or nil consonant sequence.
    pub const NIL: CSeq = CSeq(-1);

    /// Checks whether this consonant sequence is nil.
    #[inline]
    pub fn is_nil(self) -> bool {
        self.0 < 0
    }

    /// Returns the consonant sequence table index.
    #[inline]
    pub fn idx(self) -> usize {
        debug_assert!(self.0 >= 0, "nil consonant sequence used as an index");
        self.0 as usize
    }
}

/// Offset of the Vietnamese block inside the StdVnChar space.
pub const VN_STD_CHAR_OFFSET: u32 = 0x10000;
/// Sentinel value representing an invalid standard character code.
pub const INVALID_STD_CHAR: u32 = 0xFFFF_FFFF;

/// Compile time guard on the numeric invariants described above.
/// If any of these fires, the generated tables and the engine are out
/// of sync and every tone decision in the engine is wrong.
const _: () = {
    use super::lexi_consts as L;
    assert!(L::a.0 == L::A.0 + 1, "parity: lower case is upper + 1");
    assert!(L::A1.0 == L::A.0 + 2, "tone step is 2");
    assert!(L::a5.0 == L::a.0 + 10, "five tone levels above the base");
    assert!(L::ar.0 == L::A.0 + 13, "a with roof follows the six a tones");
    assert!(L::dd.0 == L::d.0 + 2, "dd sits two past d");
    assert!(L::LAST_CHAR == 186);
};
