//! Fixed limits and the macro key folding rule.
//!
//! Kept out of `macros` so the engine can refer to them with no allocator
//! present.

use crate::lexi::VN_STD_CHAR_OFFSET;
use crate::tables;

/// Maximum length (in characters) of a macro shortcut key trigger.
pub const MAX_MACRO_KEY_LEN: usize = 16;
/// Maximum length (in characters) of a macro replacement expansion string.
pub const MAX_MACRO_TEXT_LEN: usize = 1024;
/// Rows the macro table holds.
///
/// Default caps it at 1024. Larger capacity (8192) is available
/// behind the `large-macro-table` feature.
#[cfg(not(feature = "large-macro-table"))]
pub const MAX_MACRO_ITEMS: usize = 1024;

/// Rows the macro table holds when `large-macro-table` feature is enabled.
#[cfg(feature = "large-macro-table")]
pub const MAX_MACRO_ITEMS: usize = 8192;

/// Performs case folding on Vietnamese standard character codes (`StdVnChar`) for case-insensitive key comparison.
///
/// In the Vietnamese standard character table, alphabetic uppercase characters have even parity
/// and lowercase characters have odd parity (`uppercase + 1 == lowercase`).
/// If `x` falls within the alphabetic Vietnamese range (`VN_STD_CHAR_OFFSET..VN_STD_CHAR_OFFSET + TOTAL_ALPHA_VNCHARS`)
/// and is uppercase, this maps it to its lowercase counterpart (`x + 1`); otherwise returns `x` unchanged.
///
/// ### Arguments
///
/// - `x`: Standard Vietnamese character code (`StdVnChar`) or ASCII code point.
///
/// ### Returns
///
/// The lowercase counterpart if `x` is an uppercase Vietnamese standard character; otherwise returns `x` unchanged.
///
/// ### Examples
///
/// ```
/// use skey_core::limits::fold;
/// use skey_core::phonetics::lexi::VN_STD_CHAR_OFFSET;
///
/// // Plain ASCII or non-VN characters pass through unchanged:
/// assert_eq!(fold('a' as u32), 'a' as u32);
///
/// // Uppercase Vietnamese character becomes lowercase:
/// let upper_a = VN_STD_CHAR_OFFSET; // Even
/// assert_eq!(fold(upper_a), upper_a + 1);
/// ```
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
