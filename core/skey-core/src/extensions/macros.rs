//! Fast contiguous macro table implementation with binary search lookup.
//!
//! Stores key-value replacement pairs in a contiguous memory arena with case-folded ordering.

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
    /// Creates an empty macro table with dynamic heap storage.
    ///
    /// ### Returns
    ///
    /// Returns an empty [`MacroTable`] ready to register shortcut expansions.
    ///
    /// ### Examples
    ///
    /// ```
    /// use skey_core::extensions::macros::MacroTable;
    ///
    /// let table = MacroTable::new();
    /// assert_eq!(table.count(), 0);
    /// ```
    pub fn new() -> Self {
        MacroTable {
            data: Vec::new(),
            entries: Vec::new(),
        }
    }

    /// Clears all macro entries and resets internal buffers.
    ///
    /// ### Examples
    ///
    /// ```
    /// use skey_core::extensions::macros::MacroTable;
    ///
    /// let mut table = MacroTable::new();
    /// table.reset_content();
    /// assert_eq!(table.count(), 0);
    /// ```
    pub fn reset_content(&mut self) {
        self.data.clear();
        self.entries.clear();
    }

    /// Returns the total number of macros stored.
    ///
    /// ### Returns
    ///
    /// The number of macro definitions currently held in the table.
    ///
    /// ### Examples
    ///
    /// ```
    /// use skey_core::extensions::macros::MacroTable;
    ///
    /// let table = MacroTable::new();
    /// assert_eq!(table.count(), 0);
    /// ```
    pub fn count(&self) -> usize {
        self.entries.len()
    }

    #[inline]
    fn slice_of(data: &[u32], at: u32, len: u16) -> &[u32] {
        &data[at as usize..at as usize + len as usize]
    }

    /// Returns the trigger key sequence of the macro at index `i`.
    ///
    /// ### Arguments
    ///
    /// - `i`: Zero-based index of the macro item.
    ///
    /// ### Returns
    ///
    /// `Some(&[u32])` containing the Vietnamese standard character sequence if `i < count()`; otherwise `None`.
    ///
    /// ### Examples
    ///
    /// ```
    /// use skey_core::extensions::macros::MacroTable;
    ///
    /// let table = MacroTable::new();
    /// assert_eq!(table.key(0), None);
    /// ```
    pub fn key(&self, i: usize) -> Option<&[u32]> {
        self.entries
            .get(i)
            .map(|e| Self::slice_of(&self.data, e.key_at, e.key_len))
    }

    /// Returns the replacement text sequence of the macro at index `i`.
    ///
    /// ### Arguments
    ///
    /// - `i`: Zero-based index of the macro item.
    ///
    /// ### Returns
    ///
    /// `Some(&[u32])` containing the replacement text standard character sequence if `i < count()`; otherwise `None`.
    ///
    /// ### Examples
    ///
    /// ```
    /// use skey_core::extensions::macros::MacroTable;
    ///
    /// let table = MacroTable::new();
    /// assert_eq!(table.text(0), None);
    /// ```
    pub fn text(&self, i: usize) -> Option<&[u32]> {
        self.entries
            .get(i)
            .map(|e| Self::slice_of(&self.data, e.text_at, e.text_len))
    }

    /// Binary searches for a matching macro definition matching `key`.
    ///
    /// Comparisons are case-folded using Vietnamese standard character rules.
    ///
    /// ### Arguments
    ///
    /// - `key`: Standard Vietnamese character code slice representing the trigger word.
    ///
    /// ### Returns
    ///
    /// `Some(&[u32])` of standard Vietnamese character codes for the replacement text on match; `None` if not found.
    ///
    /// ### Examples
    ///
    /// ```
    /// use skey_core::extensions::macros::MacroTable;
    ///
    /// let table = MacroTable::new();
    /// assert_eq!(table.lookup(&[b'v' as u32, b'n' as u32]), None);
    /// ```
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

    /// Adds a key-text macro pair decoded using the specified charset.
    ///
    /// ### Arguments
    ///
    /// - `key`: NUL-terminated or bounded byte slice for the trigger shortcut.
    /// - `text`: NUL-terminated or bounded byte slice for the replacement expansion.
    /// - `cs`: Character set used to decode `key` and `text` (e.g. Unicode UTF-8 or VIQR).
    ///
    /// ### Returns
    ///
    /// Returns `true` if added successfully; `false` if the table is full ([`MAX_MACRO_ITEMS`]) or decoding failed.
    ///
    /// ### Examples
    ///
    /// ```
    /// use skey_core::Charset;
    /// use skey_core::charset::UNIUTF8;
    /// use skey_core::extensions::macros::MacroTable;
    ///
    /// let mut table = MacroTable::new();
    /// assert!(table.add_item(b"vn\0", b"Vi\xE1\xBB\x87t Nam\0", Charset(UNIUTF8)));
    /// assert_eq!(table.count(), 1);
    /// ```
    pub fn add_item(&mut self, key: &[u8], text: &[u8], cs: Charset) -> bool {
        if self.entries.len() >= MAX_MACRO_ITEMS {
            return false;
        }
        let k = match charset::decode_nul_terminated(cs, key, MAX_MACRO_KEY_LEN) {
            Some(v) => v,
            None => return false,
        };
        let t = match charset::decode_nul_terminated(cs, text, MAX_MACRO_TEXT_LEN) {
            Some(v) => v,
            None => return false,
        };
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

    /// Parses and adds a single `key:text` line into the table.
    ///
    /// ### Arguments
    ///
    /// - `line`: Byte slice in format `key:text`.
    /// - `cs`: Character set used to decode `key` and `text`.
    ///
    /// ### Returns
    ///
    /// Returns `true` if the line was valid and added successfully; `false` if colon is missing or capacity exceeded.
    ///
    /// ### Examples
    ///
    /// ```
    /// use skey_core::Charset;
    /// use skey_core::charset::UNIUTF8;
    /// use skey_core::extensions::macros::MacroTable;
    ///
    /// let mut table = MacroTable::new();
    /// assert!(table.add_line(b"vn:Vi\xE1\xBB\x87t Nam", Charset(UNIUTF8)));
    /// assert_eq!(table.count(), 1);
    /// ```
    pub fn add_line(&mut self, line: &[u8], cs: Charset) -> bool {
        let pos = match line.iter().position(|&b| b == b':') {
            Some(p) => p,
            None => return false,
        };
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
        let data = core::mem::take(&mut self.data);
        self.entries.sort_by(|a, b| {
            cmp_folded(
                Self::slice_of(&data, a.key_at, a.key_len),
                Self::slice_of(&data, b.key_at, b.key_len),
            )
        });
        self.data = data;
    }

    /// Loads macro definitions from raw file bytes and sorts entries.
    ///
    /// ### Arguments
    ///
    /// - `data`: Raw file contents representing the macro definition file.
    ///
    /// ### Returns
    ///
    /// Returns the detected macro file format version (e.g. `1` for UTF-8 format, `0` for legacy VIQR).
    ///
    /// ### Examples
    ///
    /// ```
    /// use skey_core::extensions::macros::MacroTable;
    ///
    /// let mut table = MacroTable::new();
    /// let content = b"DO NOT DELETE THIS LINE*** version=1 ***\nvn:Vi\xE1\xBB\x87t Nam\n";
    /// let ver = table.load_from_bytes(content);
    /// assert_eq!(ver, 1);
    /// assert_eq!(table.count(), 1);
    /// ```
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

    /// Serializes all macros to a UTF-8 formatted string suitable for saving to disk.
    ///
    /// ### Returns
    ///
    /// Returns a [`String`] formatted with the version 1 header and `key:text` lines.
    ///
    /// ### Examples
    ///
    /// ```
    /// use skey_core::Charset;
    /// use skey_core::charset::UNIUTF8;
    /// use skey_core::extensions::macros::MacroTable;
    ///
    /// let mut table = MacroTable::new();
    /// table.add_line(b"vn:Viet Nam", Charset(UNIUTF8));
    /// let file_content = table.to_utf8_file();
    /// assert!(file_content.contains("vn:Viet Nam"));
    /// ```
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
