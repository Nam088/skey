//! Macro table.
//!
//! The original keeps this inside `UkSharedMem`, which may not contain
//! pointers, so it is a fixed `MacroDef[1024]` index over a fixed
//! `char[131072]` arena: 136 KB reserved whether or not any macro is
//! defined, and `lookup` binary searches the index through a comparator
//! that walks both strings. Here the storage grows with the content and
//! the ordering and comparison semantics are preserved exactly, because
//! `lookup` is what the engine's word end path depends on.

use alloc::string::String;
use alloc::vec::Vec;

use crate::charset::{self, Charset};
use crate::limits::{fold, MAX_MACRO_ITEMS, MAX_MACRO_KEY_LEN, MAX_MACRO_TEXT_LEN};

const VERSION_UTF8: i32 = 1;

/// `macKeyCompare`: case folded lexicographic order over NUL terminated
/// StdVnChar strings. Both inputs here exclude the terminator, which is
/// the same ordering.
fn cmp_folded(a: &[u32], b: &[u32]) -> core::cmp::Ordering {
    use core::cmp::Ordering;
    let n = core::cmp::min(a.len(), b.len());
    for i in 0..n {
        let (x, y) = (fold(a[i]), fold(b[i]));
        if x > y {
            return Ordering::Greater;
        }
        if x < y {
            return Ordering::Less;
        }
    }
    if a.len() == n {
        if b.len() == n {
            Ordering::Equal
        } else {
            Ordering::Less
        }
    } else {
        Ordering::Greater
    }
}

/// Where one macro lives inside the arena.
#[derive(Clone, Copy)]
struct Slice {
    key_at: u32,
    key_len: u16,
    text_at: u32,
    text_len: u16,
}

/// One contiguous arena for every key and text, plus a slim index over
/// it. A table of N macros costs two allocations rather than 2N, and the
/// binary search walks memory that is actually adjacent.
#[derive(Default)]
pub struct MacroTable {
    data: Vec<u32>,
    entries: Vec<Slice>,
}

impl MacroTable {
    pub fn new() -> Self {
        MacroTable {
            data: Vec::new(),
            entries: Vec::new(),
        }
    }

    pub fn reset_content(&mut self) {
        self.data.clear();
        self.entries.clear();
    }

    pub fn count(&self) -> usize {
        self.entries.len()
    }

    #[inline]
    fn slice_of(data: &[u32], at: u32, len: u16) -> &[u32] {
        &data[at as usize..at as usize + len as usize]
    }

    pub fn key(&self, i: usize) -> Option<&[u32]> {
        self.entries
            .get(i)
            .map(|e| Self::slice_of(&self.data, e.key_at, e.key_len))
    }

    pub fn text(&self, i: usize) -> Option<&[u32]> {
        self.entries
            .get(i)
            .map(|e| Self::slice_of(&self.data, e.text_at, e.text_len))
    }

    /// `CMacroTable::lookup`.
    pub fn lookup(&self, key: &[u32]) -> Option<&[u32]> {
        let data = &self.data;
        self.entries
            .binary_search_by(|e| cmp_folded(Self::slice_of(data, e.key_at, e.key_len), key))
            .ok()
            .map(|i| {
                let e = self.entries[i];
                Self::slice_of(data, e.text_at, e.text_len)
            })
    }

    /// `CMacroTable::addItem(key, text, charset)`. Returns false when the
    /// item is rejected, which the original does by way of `VnConvert`
    /// reporting out of memory for an over long key or text.
    pub fn add_item(&mut self, key: &[u8], text: &[u8], cs: Charset) -> bool {
        if self.entries.len() >= MAX_MACRO_ITEMS {
            return false;
        }
        // The key budget is MAX_MACRO_KEY_LEN StdVnChars including the
        // NUL the converter emits, likewise for the text.
        let k = match charset::decode_nul_terminated(cs, key, MAX_MACRO_KEY_LEN) {
            Some(v) => v,
            None => return false,
        };
        let t = match charset::decode_nul_terminated(cs, text, MAX_MACRO_TEXT_LEN) {
            Some(v) => v,
            None => return false,
        };
        // Stored without the terminator; every reader here is length
        // aware, and the ordering is unchanged.
        let strip = |v: &[u32]| -> usize {
            if v.last() == Some(&0) {
                v.len() - 1
            } else {
                v.len()
            }
        };
        let kn = strip(&k);
        let tn = strip(&t);
        let key_at = self.data.len() as u32;
        self.data.extend_from_slice(&k[..kn]);
        let text_at = self.data.len() as u32;
        self.data.extend_from_slice(&t[..tn]);
        self.entries.push(Slice {
            key_at,
            key_len: kn as u16,
            text_at,
            text_len: tn as u16,
        });
        true
    }

    /// `CMacroTable::addItem(item, charset)`: one `key:text` line.
    pub fn add_line(&mut self, line: &[u8], cs: Charset) -> bool {
        let pos = match line.iter().position(|&b| b == b':') {
            Some(p) => p,
            None => return false,
        };
        // The original copies at most MAX_MACRO_KEY_LEN-1 bytes of key.
        let mut key_len = pos;
        if key_len > MAX_MACRO_KEY_LEN - 1 {
            key_len = MAX_MACRO_KEY_LEN - 1;
        }
        let mut key: Vec<u8> = line[..key_len].to_vec();
        key.push(0);
        let mut text: Vec<u8> = line[pos + 1..].to_vec();
        text.push(0);
        self.add_item(&key, &text, cs)
    }

    fn sort(&mut self) {
        // `qsort` with `macCompare`, which compares keys case folded.
        //
        // Two keys that differ only in case therefore compare equal, and
        // qsort is not stable, so the original's relative order for such
        // a pair is whatever the platform's qsort happens to produce and
        // which of the two `lookup` finds is likewise unspecified. There
        // is no behaviour to preserve there. This sort is stable, so the
        // tie break is insertion order, which is at least reproducible.
        //
        // The arena is moved aside so the comparator can read it while the
        // index is being reordered.
        let data = core::mem::take(&mut self.data);
        self.entries.sort_by(|a, b| {
            cmp_folded(
                Self::slice_of(&data, a.key_at, a.key_len),
                Self::slice_of(&data, b.key_at, b.key_len),
            )
        });
        self.data = data;
    }

    /// `CMacroTable::loadFromFile`, minus the file handling: the caller
    /// supplies the bytes. Returns the file version that was detected, so
    /// the caller can rewrite a legacy file as the original does.
    pub fn load_from_bytes(&mut self, data: &[u8]) -> i32 {
        self.reset_content();
        let mut lines = data.split(|&b| b == b'\n');
        let first = lines.next().unwrap_or(&[]);
        let version = detect_version(first);
        let cs = if version == VERSION_UTF8 {
            Charset(charset::UNIUTF8)
        } else {
            Charset(charset::VIQR)
        };

        // A missing header means the first line is data, exactly as the
        // original's rewind does.
        let body: Vec<&[u8]> = if version == 0 && !is_header(first) {
            core::iter::once(first).chain(lines).collect()
        } else {
            lines.collect()
        };

        for raw in body {
            let mut line = raw;
            if line.last() == Some(&b'\r') {
                line = &line[..line.len() - 1];
            }
            if line.is_empty() {
                continue;
            }
            self.add_line(line, cs);
        }
        self.sort();
        version
    }

    /// `CMacroTable::writeToFile`, minus the file handling.
    pub fn to_utf8_file(&self) -> String {
        let mut s = String::from("DO NOT DELETE THIS LINE*** version=1 ***\n");
        for i in 0..self.entries.len() {
            s.push_str(&encode_utf8(self.key(i).unwrap()));
            s.push(':');
            s.push_str(&encode_utf8(self.text(i).unwrap()));
            if i + 1 < self.entries.len() {
                s.push('\n');
            }
        }
        s
    }
}

fn is_header(line: &[u8]) -> bool {
    line.windows(3).any(|w| w == b"***")
}

/// `CMacroTable::readHeader`: an optional BOM, then `***version=n`.
fn detect_version(line: &[u8]) -> i32 {
    let mut p = line;
    if p.len() >= 3 && p[0] == 0xEF && p[1] == 0xBB && p[2] == 0xBF {
        p = &p[3..];
    }
    let idx = match p.windows(3).position(|w| w == b"***") {
        Some(i) => i + 3,
        None => return 0,
    };
    let mut q = &p[idx..];
    while q.first() == Some(&b' ') {
        q = &q[1..];
    }
    if !q.starts_with(b"version=") {
        return 0;
    }
    q = &q[b"version=".len()..];
    let mut n: i32 = 0;
    let mut any = false;
    for &b in q {
        if b.is_ascii_digit() {
            n = n * 10 + (b - b'0') as i32;
            any = true;
        } else {
            break;
        }
    }
    if any {
        n
    } else {
        0
    }
}

fn encode_utf8(chars: &[u32]) -> String {
    use crate::out::{Counter, Sink};
    struct Bytes(Vec<u8>);
    impl Sink for Bytes {
        fn put(&mut self, b: u8) -> bool {
            self.0.push(b);
            true
        }
    }
    let _ = core::mem::size_of::<Counter>();
    let mut enc = charset::Encoder::new(Charset(charset::UNIUTF8));
    let mut out = Bytes(Vec::new());
    for &c in chars {
        enc.put_into(&mut out, c);
    }
    String::from_utf8_lossy(&out.0).into_owned()
}
