//! OpenKey style typing shortcuts: pure tables and pure predicates.
//!
//! Kept out of `engine.rs` deliberately. These tables are what a reviewer
//! checks against OpenKey's `Vietnamese.cpp`, and `engine.rs` earns its
//! length by corresponding line for line with `ukengine.cpp`.
//!
//! Every table here is ASCII, because every shortcut is expressed in
//! terms of the letters that were typed.

/// Telex doubled consonants. Typing the letter twice gives the pair.
///
/// `uu` for u horn plus o horn is not here: it rewrites a vowel sequence
/// rather than substituting a letter, so the engine handles it separately.
pub const DOUBLED: [(u8, u8); 7] = [
    (b'c', b'h'),
    (b'g', b'i'),
    (b'k', b'h'),
    (b'n', b'g'),
    (b'q', b'u'),
    (b'p', b'h'),
    (b't', b'h'),
];

/// The second letter for a doubled `first`, if the pair is listed.
#[inline]
pub fn doubled(first: u8) -> Option<u8> {
    let lower = first.to_ascii_lowercase();
    let mut i = 0;
    while i < DOUBLED.len() {
        if DOUBLED[i].0 == lower {
            return Some(DOUBLED[i].1);
        }
        i += 1;
    }
    None
}

/// Onset shortcuts. None of `f`, `j` or `w` can begin a Vietnamese word,
/// so substituting them takes nothing away.
pub const ONSET: [(u8, u8, u8); 3] = [
    (b'f', b'p', b'h'),
    (b'j', b'g', b'i'),
    (b'w', b'q', b'u'),
];

/// The pair a word initial `typed` expands to, if it is listed.
#[inline]
pub fn onset(typed: u8) -> Option<(u8, u8)> {
    let lower = typed.to_ascii_lowercase();
    let mut i = 0;
    while i < ONSET.len() {
        if ONSET[i].0 == lower {
            return Some((ONSET[i].1, ONSET[i].2));
        }
        i += 1;
    }
    None
}

/// Coda shortcuts. Unlike the onsets these letters are all legitimate on
/// their own, so the engine may only apply them when the word is
/// otherwise invalid.
pub const CODA: [(u8, u8, u8); 3] = [
    (b'g', b'n', b'g'),
    (b'h', b'n', b'h'),
    (b'k', b'c', b'h'),
];

/// The pair a word final `typed` expands to, if it is listed.
#[inline]
pub fn coda(typed: u8) -> Option<(u8, u8)> {
    let lower = typed.to_ascii_lowercase();
    let mut i = 0;
    while i < CODA.len() {
        if CODA[i].0 == lower {
            return Some((CODA[i].1, CODA[i].2));
        }
        i += 1;
    }
    None
}
