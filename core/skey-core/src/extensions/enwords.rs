//! Words that the engine mangles by swallowing a key.
//!
//! @generated, and every entry was verified against the engine itself:
//! a word the engine already leaves alone is not in here.
//!
//! The entry criterion is measured, not guessed. Each of these comes
//! out with **no Vietnamese mark at all**, because a key was simply
//! swallowed: `off` becomes `of`, `pass` becomes `pas`, `error`
//! becomes `eror`. Nobody types those on purpose, so restoring the
//! key strokes takes nothing away from anyone.
//!
//! Words whose mangled form is valid Vietnamese are deliberately NOT
//! here. `theme` is also how you type `thêm`, `did` is `đi`, `its` is
//! `ít`, `too` is `tô`, `test` is `tét`. A list containing those would
//! fix English by breaking Vietnamese, which is a trade, not a fix.
//! `autoNonVnRestore` cannot reach them either, since their result is
//! phonotactically valid. They are left alone on purpose.
//!
//! One blob plus offsets: 105 bytes, against 299 for a `&[&str]` of the
//! same words, most of which would be fat pointers.

/// Longest word in the table, so callers can size a stack buffer.
pub const MAX_WORD_LEN: usize = 16;

/// Concatenated, in sorted order.
const BLOB: &[u8] = b"bassbossbuffbufferchessdifferrorerrorsguessissuelesslossmassmessmessagemissoffoffsetpasspassedpasswordsessionsuffix";

/// Start of each word, with a final sentinel. 23 words.
const OFFSETS: [u16; 24] = [
    0, 4, 8, 12, 18, 23, 27, 32, 38, 43, 48, 52, 56, 60, 64, 71, 75, 78, 84, 88, 94, 102, 109, 115,
];

/// True when `w`, already lowercased, is one of them.
pub fn is_swallowed_word(w: &[u8]) -> bool {
    let mut lo = 0usize;
    let mut hi = OFFSETS.len() - 1;
    while lo < hi {
        let mid = (lo + hi) / 2;
        let s = OFFSETS[mid] as usize;
        let e = OFFSETS[mid + 1] as usize;
        match BLOB[s..e].cmp(w) {
            core::cmp::Ordering::Equal => return true,
            core::cmp::Ordering::Less => lo = mid + 1,
            core::cmp::Ordering::Greater => hi = mid,
        }
    }
    false
}

/// The words, for tests and for a front end that wants to show them.
pub fn words() -> impl Iterator<Item = &'static [u8]> {
    (0..OFFSETS.len() - 1).map(|i| &BLOB[OFFSETS[i] as usize..OFFSETS[i + 1] as usize])
}
