//! Fixed limits and the macro key folding rule.
//!
//! Kept out of `macros` so the engine can refer to them with no allocator
//! present.

use crate::lexi::VN_STD_CHAR_OFFSET;
use crate::tables;

pub const MAX_MACRO_KEY_LEN: usize = 16;
pub const MAX_MACRO_TEXT_LEN: usize = 1024;
/// Rows the macro table holds.
///
/// 3.6 caps it at 1024 and the number is load bearing for parity: a macro
/// file with more rows than the cap loads a different table in each engine,
/// which the macro sweep would report as a divergence. UniKey 4.3 raised it
/// to 8192, so that is available, but only behind `large-macro-table` and
/// never by default.
#[cfg(not(feature = "large-macro-table"))]
pub const MAX_MACRO_ITEMS: usize = 1024;

#[cfg(feature = "large-macro-table")]
pub const MAX_MACRO_ITEMS: usize = 8192;

/// `STD_TO_LOWER` from mactab.cpp: case folding for key comparison.
#[inline]
pub fn fold(x: u32) -> u32 {
    if x >= VN_STD_CHAR_OFFSET
        && x < VN_STD_CHAR_OFFSET + tables::TOTAL_ALPHA_VNCHARS as u32
        && x & 1 == 0
    {
        x + 1
    } else {
        x
    }
}
