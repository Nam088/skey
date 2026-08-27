//! Output charsets.
//!
//! The original dispatches through the virtual `VnCharset::putChar`, and
//! `getSeqSteps` abuses it by encoding a range into a zero length stream
//! purely to count bytes. Here the same code path serves both, but the
//! counting sink stores nothing, so backspace arithmetic allocates and
//! copies nothing.
//!
//! VIQR is stateful. The engine calls `startOutput` before every write,
//! so that state lives exactly one output pass: `Encoder::new` is
//! `startOutput`.

use crate::lexi::VN_STD_CHAR_OFFSET;
use crate::out::{Counter, OutBuf, Sink};
use crate::tables;

pub const UNICODE: i32 = 0;
pub const UNIUTF8: i32 = 1;
pub const UNIREF: i32 = 2;
pub const UNIREF_HEX: i32 = 3;
pub const UNIDECOMPOSED: i32 = 4;
pub const WINCP1258: i32 = 5;
pub const UNI_CSTRING: i32 = 6;
pub const VNSTANDARD: i32 = 7;
pub const VIQR: i32 = 10;
pub const UTF8VIQR: i32 = 11;
pub const XUTF8: i32 = 12;
pub const TCVN3: i32 = 20;
pub const VPS: i32 = 21;
pub const VISCII: i32 = 22;
pub const BKHCM1: i32 = 23;
pub const VIETWAREF: i32 = 24;
pub const ISC: i32 = 25;
pub const VNIWIN: i32 = 40;
pub const BKHCM2: i32 = 41;
pub const VIETWAREX: i32 = 42;
pub const VNIMAC: i32 = 43;

const TOTAL_SINGLE: i32 = 6;
const TOTAL_DOUBLE: i32 = 4;

// Padding used when a character is absent from the target charset.
const PAD_CHAR: u8 = b'#';
const PAD_START_QUOTE: u8 = b'"';
const PAD_END_QUOTE: u8 = b'"';
const PAD_ELLIPSIS: u8 = b'.';

const STD_START_QUOTE: u32 = VN_STD_CHAR_OFFSET + 201;
const STD_END_QUOTE: u32 = VN_STD_CHAR_OFFSET + 202;
const STD_ELLIPSIS: u32 = VN_STD_CHAR_OFFSET + 190;

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
#[cfg_attr(feature = "serde", derive(serde::Serialize, serde::Deserialize))]
#[cfg_attr(feature = "serde", serde(transparent))]
pub struct Charset(pub i32);

impl Default for Charset {
    fn default() -> Self {
        Charset(XUTF8)
    }
}

impl Charset {
    pub fn is_unicode_cstring(self) -> bool {
        self.0 == UNI_CSTRING
    }

    /// True when one buffer entry always costs exactly one step, the fast
    /// path the original takes in `getSeqSteps` for XUTF8 and UNICODE.
    ///
    /// The six single byte charsets are added here. That is not a
    /// behaviour change: every branch of `SingleByteCharset::putChar`
    /// writes exactly one byte, and no buffer entry can encode to
    /// INVALID_STD_CHAR so the caller never skips one, which makes the
    /// byte count the original computes already equal to the entry
    /// count. Double byte charsets and VN standard are excluded because
    /// theirs is not, and VIQR because its length depends on preceding
    /// output.
    pub fn one_step_per_char(self) -> bool {
        self.0 == XUTF8
            || self.0 == UNICODE
            || (self.0 >= TCVN3 && self.0 < TCVN3 + TOTAL_SINGLE)
    }

    pub fn is_supported(self) -> bool {
        matches!(
            self.0,
            UNICODE
                | UNIUTF8
                | UNIREF
                | UNIREF_HEX
                | UNIDECOMPOSED
                | WINCP1258
                | UNI_CSTRING
                | VNSTANDARD
                | VIQR
                | UTF8VIQR
                | XUTF8
        ) || (self.0 >= TCVN3 && self.0 < TCVN3 + TOTAL_SINGLE)
            || (self.0 >= VNIWIN && self.0 < VNIWIN + TOTAL_DOUBLE)
    }
}

// ------------------------------------------------------- derived maps

/// `SingleByteCharset`'s constructor, evaluated at compile time.
const fn single_std_map(vn: &[u8; tables::TOTAL_VNCHARS]) -> [u16; 256] {
    let mut m = [0u16; 256];
    let mut i = 0;
    while i < tables::TOTAL_VNCHARS {
        if vn[i] != 0 && (i == tables::TOTAL_VNCHARS - 1 || vn[i] != vn[i + 1]) {
            m[vn[i] as usize] = (i + 1) as u16;
        }
        i += 1;
    }
    m
}

/// `DoubleByteCharset`'s constructor, evaluated at compile time.
const fn double_std_map(vn: &[u16; tables::TOTAL_VNCHARS]) -> [u16; 256] {
    let mut m = [0u16; 256];
    let mut i = 0;
    while i < tables::TOTAL_VNCHARS {
        if vn[i] >> 8 != 0 {
            m[(vn[i] >> 8) as usize] = 0xFFFF;
        } else if m[vn[i] as usize] == 0 {
            m[vn[i] as usize] = (i + 1) as u16;
        }
        i += 1;
    }
    m
}

/// `WinCP1258Charset`'s constructor: the composite table first, then the
/// precomposed one folded in wherever it differs.
const fn cp1258_std_map() -> [u16; 256] {
    let comp = &tables::WIN_CP1258;
    let pre = &tables::WIN_CP1258_PRE;
    let mut m = double_std_map(comp);
    let mut k = 0;
    while k < tables::TOTAL_VNCHARS {
        if pre[k] != comp[k] {
            if pre[k] >> 8 != 0 {
                m[(pre[k] >> 8) as usize] = 0xFFFF;
            } else if m[pre[k] as usize] == 0 {
                m[pre[k] as usize] = (k + 1) as u16;
            }
        }
        k += 1;
    }
    m
}

/// `VIQRCharset`'s constructor. The tone and decorator entries below are
/// offsets from a base character, not indices, which is why they overlap
/// the single byte range written first.
const fn viqr_std_map() -> [u16; 256] {
    let mut m = [0u16; 256];
    let mut i = 0;
    while i < tables::TOTAL_VNCHARS {
        let dw = tables::VIQR_TABLE[i];
        if dw & 0xFFFF_FF00 == 0 {
            m[dw as usize] = (i + 256) as u16;
        }
        i += 1;
    }
    m[b'\'' as usize] = 2;
    m[b'`' as usize] = 4;
    m[b'?' as usize] = 6;
    m[b'~' as usize] = 8;
    m[b'.' as usize] = 10;
    m[b'^' as usize] = 12;
    m[b'(' as usize] = 24;
    m[b'+' as usize] = 26;
    m[b'*' as usize] = 26;
    m
}

static SINGLE_STD_MAPS: [[u16; 256]; 6] = [
    single_std_map(&tables::SINGLE_BYTE_TABLES[0]),
    single_std_map(&tables::SINGLE_BYTE_TABLES[1]),
    single_std_map(&tables::SINGLE_BYTE_TABLES[2]),
    single_std_map(&tables::SINGLE_BYTE_TABLES[3]),
    single_std_map(&tables::SINGLE_BYTE_TABLES[4]),
    single_std_map(&tables::SINGLE_BYTE_TABLES[5]),
];

static DOUBLE_STD_MAPS: [[u16; 256]; 4] = [
    double_std_map(&tables::DOUBLE_BYTE_TABLES[0]),
    double_std_map(&tables::DOUBLE_BYTE_TABLES[1]),
    double_std_map(&tables::DOUBLE_BYTE_TABLES[2]),
    double_std_map(&tables::DOUBLE_BYTE_TABLES[3]),
];

static CP1258_STD_MAP: [u16; 256] = cp1258_std_map();
static VIQR_STD_MAP: [u16; 256] = viqr_std_map();

#[inline]
fn to_unicode(std_char: u32) -> u16 {
    if std_char < VN_STD_CHAR_OFFSET {
        // The original casts to UnicodeChar, truncating anything above
        // 0xFFFF. Reproduced deliberately.
        std_char as u16
    } else {
        let i = (std_char - VN_STD_CHAR_OFFSET) as usize;
        if i < tables::TOTAL_VNCHARS {
            tables::UNICODE_TABLE[i]
        } else {
            0
        }
    }
}

#[inline]
fn hex_digit(x: u16) -> u8 {
    if x < 10 {
        b'0' + x as u8
    } else {
        b'A' + x as u8 - 10
    }
}

#[inline]
fn is_ascii_vowel(ch: u8) -> bool {
    matches!(
        ch,
        b'a' | b'e' | b'i' | b'o' | b'u' | b'y' | b'A' | b'E' | b'I' | b'O' | b'U' | b'Y'
    )
}

// --------------------------------------------------- VIQR escape state

/// The VIQR encoder suppresses escaping inside things that look like
/// URLs or mail addresses. The original runs a KMP matcher per pattern
/// over the output bytes and only ever asks "did some pattern end at
/// this byte", so a rolling window of the last few bytes answers the
/// same question with far less machinery. `reset` clears the window,
/// which is what resetting the matchers does.
/// The longest pattern is seven bytes, so the whole window fits in a
/// `u64`: shift left by eight, OR in the new byte, and each pattern
/// becomes one mask and one compare. No memory traffic, no slicing, no
/// per pattern state, and resetting is assigning zero. A full Aho
/// Corasick DFA would also be O(1) but needs about thirty states over a
/// byte class alphabet for the same answer.
///
/// Zero filled high bytes cannot cause a false positive because no
/// pattern contains a NUL, so a window with fewer bytes fed than a
/// pattern is long can never match it.
const ESC_PATTERNS: [&[u8]; 8] = [
    b"://", b"/", b"@", b"mailto:", b"email:", b"news:", b"www", b"ftp",
];

const fn pack(p: &[u8]) -> u64 {
    let mut v = 0u64;
    let mut i = 0;
    while i < p.len() {
        v = (v << 8) | p[i] as u64;
        i += 1;
    }
    v
}

const fn width_mask(len: usize) -> u64 {
    if len >= 8 {
        u64::MAX
    } else {
        (1u64 << (len * 8)) - 1
    }
}

const fn build_esc() -> ([u64; 8], [u64; 8]) {
    let mut masks = [0u64; 8];
    let mut vals = [0u64; 8];
    let mut i = 0;
    while i < 8 {
        masks[i] = width_mask(ESC_PATTERNS[i].len());
        vals[i] = pack(ESC_PATTERNS[i]);
        i += 1;
    }
    (masks, vals)
}

const ESC_MASK: [u64; 8] = build_esc().0;
const ESC_VAL: [u64; 8] = build_esc().1;

#[derive(Clone, Copy, Default)]
struct EscWindow {
    w: u64,
}

impl EscWindow {
    #[inline]
    fn reset(&mut self) {
        self.w = 0;
    }

    /// Feeds one byte and reports whether any pattern ends here.
    #[inline]
    fn feed(&mut self, b: u8) -> bool {
        self.w = (self.w << 8) | b as u64;
        let mut hit = false;
        let mut i = 0;
        while i < 8 {
            hit |= (self.w & ESC_MASK[i]) == ESC_VAL[i];
            i += 1;
        }
        hit
    }
}

#[derive(Clone, Copy, Default)]
struct Viqr {
    escape_bowl: bool,
    escape_roof: bool,
    escape_hook: bool,
    escape_tone: bool,
    no_out_esc: bool,
    esc: EscWindow,
}

// --------------------------------------------------------- the encoder

/// The charset resolved to a dense tag once, so the per character path is
/// a jump table rather than a chain of range comparisons. The original
/// dispatched through a virtual call for the same reason and paid for it
/// on every character.
#[derive(Clone, Copy)]
enum Kind {
    Utf8,
    Utf16,
    VnStd,
    Decomposed,
    Ref,
    RefHex,
    CString,
    Viqr,
    Single(usize),
    Double(usize),
    Cp1258,
}

fn kind_of(cs: Charset) -> Kind {
    let id = cs.0;
    match id {
        UNIUTF8 | XUTF8 => Kind::Utf8,
        UNICODE => Kind::Utf16,
        VNSTANDARD => Kind::VnStd,
        UNIDECOMPOSED => Kind::Decomposed,
        UNIREF => Kind::Ref,
        UNIREF_HEX => Kind::RefHex,
        UNI_CSTRING => Kind::CString,
        VIQR | UTF8VIQR => Kind::Viqr,
        WINCP1258 => Kind::Cp1258,
        _ if id >= TCVN3 && id < TCVN3 + TOTAL_SINGLE => Kind::Single((id - TCVN3) as usize),
        _ if id >= VNIWIN && id < VNIWIN + TOTAL_DOUBLE => Kind::Double((id - VNIWIN) as usize),
        _ => panic!("charset has no encoder"),
    }
}

/// One output pass. Constructing it is `VnCharset::startOutput`.
pub struct Encoder {
    kind: Kind,
    viqr: Viqr,
}

impl Encoder {
    pub fn new(cs: Charset) -> Self {
        Encoder {
            kind: kind_of(cs),
            viqr: Viqr::default(),
        }
    }

    pub fn put(&mut self, os: &mut OutBuf, std_char: u32) -> bool {
        self.emit(os, std_char)
    }

    /// Same as `put`, for any sink.
    pub fn put_into<S: Sink>(&mut self, os: &mut S, std_char: u32) -> bool {
        self.emit(os, std_char)
    }

    /// Bytes this character would emit, given the state so far. The
    /// state advances exactly as it would when writing, because the
    /// original counts by encoding into a zero length stream.
    pub fn count(&mut self, std_char: u32) -> usize {
        let mut c = Counter::default();
        self.emit(&mut c, std_char);
        c.n
    }

    fn emit<S: Sink>(&mut self, os: &mut S, std_char: u32) -> bool {
        match self.kind {
            Kind::Utf8 => {
                // Straight through for plain ASCII, which every pass
                // through character is. `to_unicode` of a value below the
                // Vietnamese block is the value itself, so this is the
                // same answer with one branch less.
                if std_char < 0x80 {
                    return os.put(std_char as u8);
                }
                let u = to_unicode(std_char);
                if u < 0x0080 {
                    os.put(u as u8)
                } else if u < 0x0800 {
                    os.put2(0xC0 | (u >> 6) as u8, 0x80 | (u & 0x3F) as u8)
                } else {
                    os.put3(
                        0xE0 | (u >> 12) as u8,
                        0x80 | ((u >> 6) & 0x3F) as u8,
                        0x80 | (u & 0x3F) as u8,
                    )
                }
            }
            Kind::Utf16 => put_w(os, to_unicode(std_char)),
            Kind::VnStd => {
                let a = put_w(os, (std_char & 0xFFFF) as u16);
                let b = put_w(os, (std_char >> 16) as u16);
                a && b
            }
            Kind::Decomposed => {
                if std_char >= VN_STD_CHAR_OFFSET {
                    let i = (std_char - VN_STD_CHAR_OFFSET) as usize;
                    let dw = if i < tables::TOTAL_VNCHARS {
                        tables::UNICODE_COMPOSITE[i]
                    } else {
                        0
                    };
                    let mut ret = put_w(os, (dw & 0xFFFF) as u16);
                    let hi = (dw >> 16) as u16;
                    if hi > 0 {
                        ret = put_w(os, hi);
                    }
                    ret
                } else {
                    put_w(os, std_char as u16)
                }
            }
            Kind::Ref => {
                let mut u = to_unicode(std_char);
                if u < 128 {
                    return os.put(u as u8);
                }
                os.put(b'&');
                os.put(b'#');
                let mut prev = false;
                let mut base: u16 = 10000;
                for _ in 0..5 {
                    let digit = u / base;
                    if digit != 0 || prev {
                        prev = true;
                        os.put(b'0' + digit as u8);
                    }
                    u %= base;
                    base /= 10;
                }
                os.put(b';')
            }
            Kind::RefHex => {
                let u = to_unicode(std_char);
                if u < 256 {
                    return os.put(u as u8);
                }
                os.put(b'&');
                os.put(b'#');
                os.put(b'x');
                put_hex_nibbles(os, u);
                os.put(b';')
            }
            Kind::CString => {
                let u = to_unicode(std_char);
                let plain = u < 128
                    && !(u as u8 as char).is_ascii_hexdigit()
                    && u != b'x' as u16
                    && u != b'X' as u16;
                if plain {
                    return os.put(u as u8);
                }
                os.put(b'\\');
                os.put(b'x');
                put_hex_nibbles(os, u);
                // The original returns the stream state here rather than
                // the result of the last byte written.
                true
            }
            Kind::Cp1258 => self.emit_double(os, std_char, &tables::WIN_CP1258, &CP1258_STD_MAP),
            Kind::Viqr => self.emit_viqr(os, std_char),
            Kind::Single(k) => self.emit_single(
                os,
                std_char,
                &tables::SINGLE_BYTE_TABLES[k],
                &SINGLE_STD_MAPS[k],
            ),
            Kind::Double(k) => self.emit_double(
                os,
                std_char,
                &tables::DOUBLE_BYTE_TABLES[k],
                &DOUBLE_STD_MAPS[k],
            ),
        }
    }

    fn emit_single<S: Sink>(
        &mut self,
        os: &mut S,
        std_char: u32,
        vn: &[u8; tables::TOTAL_VNCHARS],
        std_map: &[u16; 256],
    ) -> bool {
        if std_char >= VN_STD_CHAR_OFFSET {
            let i = (std_char - VN_STD_CHAR_OFFSET) as usize;
            let mut ch = if i < tables::TOTAL_VNCHARS { vn[i] } else { 0 };
            if ch == 0 {
                ch = if std_char == STD_START_QUOTE {
                    PAD_START_QUOTE
                } else if std_char == STD_END_QUOTE {
                    PAD_END_QUOTE
                } else if std_char == STD_ELLIPSIS {
                    PAD_ELLIPSIS
                } else {
                    PAD_CHAR
                };
            }
            os.put(ch)
        } else if std_char > 255 || std_map[std_char as usize] != 0 {
            // absent from this charset
            os.put(PAD_CHAR)
        } else {
            os.put(std_char as u8)
        }
    }

    fn emit_double<S: Sink>(
        &mut self,
        os: &mut S,
        std_char: u32,
        vn: &[u16; tables::TOTAL_VNCHARS],
        std_map: &[u16; 256],
    ) -> bool {
        if std_char >= VN_STD_CHAR_OFFSET {
            let i = (std_char - VN_STD_CHAR_OFFSET) as usize;
            let w = if i < tables::TOTAL_VNCHARS { vn[i] } else { 0 };
            if w & 0xFF00 != 0 {
                os.put((w & 0x00FF) as u8);
                os.put((w >> 8) as u8)
            } else {
                let mut b = w as u8;
                if std_map[b as usize] == 0xFFFF {
                    b = PAD_CHAR;
                }
                os.put(b)
            }
        } else if std_char > 255 || std_map[std_char as usize] != 0 {
            os.put(PAD_CHAR)
        } else {
            os.put(std_char as u8)
        }
    }

    fn emit_viqr<S: Sink>(&mut self, os: &mut S, std_char: u32) -> bool {
        let map = &VIQR_STD_MAP;
        if std_char >= VN_STD_CHAR_OFFSET {
            let i = (std_char - VN_STD_CHAR_OFFSET) as usize;
            let dw = if i < tables::TOTAL_VNCHARS {
                tables::VIQR_TABLE[i]
            } else {
                0
            };
            let first = dw as u8;
            let first_upper = first.to_ascii_uppercase();

            let mut ret = os.put(first);
            if self.viqr.esc.feed(first) {
                self.viqr.no_out_esc = true;
            }
            if self.viqr.no_out_esc && matches!(first, b' ' | b'\t' | b'\r' | b'\n') {
                self.viqr.no_out_esc = false;
            }

            if dw & 0x0000_FF00 != 0 {
                let second = (dw >> 8) as u8;
                ret = os.put(second);

                if dw & 0x00FF_0000 != 0 {
                    ret = os.put((dw >> 16) as u8);
                    self.viqr.escape_tone = false;
                } else {
                    let index = map[second as usize];
                    self.viqr.escape_tone = index == 12 || index == 24 || index == 26;
                }

                self.viqr.esc.reset();
                self.viqr.escape_bowl = false;
                self.viqr.escape_hook = false;
                self.viqr.escape_roof = false;
            } else {
                self.viqr.escape_tone = is_ascii_vowel(first);
                self.viqr.escape_bowl = first_upper == b'A';
                self.viqr.escape_hook = first_upper == b'U' || first_upper == b'O';
                self.viqr.escape_roof =
                    first_upper == b'A' || first_upper == b'E' || first_upper == b'O';
            }
            return ret;
        }

        let ret;
        if std_char > 255 {
            ret = os.put(PAD_CHAR);
            if self.viqr.esc.feed(PAD_CHAR) {
                self.viqr.no_out_esc = true;
            }
        } else {
            let index = map[std_char as usize];
            // viqrMixed is 0 by default and the engine never changes it.
            let needs_escape = !self.viqr.no_out_esc
                && (std_char == b'\\' as u32
                    || (index > 0 && index <= 10 && self.viqr.escape_tone)
                    || (index == 12 && self.viqr.escape_roof)
                    || (index == 24 && self.viqr.escape_bowl)
                    || (index == 26 && self.viqr.escape_hook));
            if needs_escape {
                os.put(b'\\');
                if self.viqr.esc.feed(b'\\') {
                    self.viqr.no_out_esc = true;
                }
            }
            let b = std_char as u8;
            ret = os.put(b);
            if self.viqr.esc.feed(b) {
                self.viqr.no_out_esc = true;
            }
            if self.viqr.no_out_esc && matches!(b, b' ' | b'\t' | b'\r' | b'\n') {
                self.viqr.no_out_esc = false;
            }
        }

        self.viqr.escape_bowl = false;
        self.viqr.escape_roof = false;
        self.viqr.escape_hook = false;
        self.viqr.escape_tone = false;
        ret
    }
}

#[inline]
fn put_w<S: Sink>(os: &mut S, w: u16) -> bool {
    os.put2((w & 0xFF) as u8, (w >> 8) as u8)
}

#[inline]
fn put_hex_nibbles<S: Sink>(os: &mut S, u: u16) {
    let mut prev = false;
    let mut shifts = 12i32;
    for _ in 0..4 {
        let digit = (u >> shifts) & 0x000F;
        if digit > 0 || prev {
            prev = true;
            os.put(hex_digit(digit));
        }
        shifts -= 4;
    }
}

// ------------------------------------------------------------- decoding

#[cfg(feature = "alloc")]
/// Reverse of `UNICODE_TABLE`. The original sorts a copy and binary
/// searches it; the table has no duplicate Unicode values, so the result
/// is unambiguous and a scan over 213 entries is equivalent. Only the
/// macro file loader uses this, never the keystroke path.
fn unicode_to_std(u: u16) -> u32 {
    let mut i = 0;
    while i < tables::TOTAL_VNCHARS {
        if tables::UNICODE_TABLE[i] == u {
            return VN_STD_CHAR_OFFSET + i as u32;
        }
        i += 1;
    }
    u as u32
}

/// `StdVnToUpper`. Note the parity test runs on the whole StdVnChar; the
/// 0x10000 offset is even, so it is the same parity as the index.
pub fn std_to_upper(ch: u32) -> u32 {
    if ch >= VN_STD_CHAR_OFFSET
        && ch < VN_STD_CHAR_OFFSET + tables::TOTAL_ALPHA_VNCHARS as u32
        && ch & 1 == 1
    {
        ch - 1
    } else {
        ch
    }
}

/// `StdVnToLower`.
pub fn std_to_lower(ch: u32) -> u32 {
    if ch >= VN_STD_CHAR_OFFSET
        && ch < VN_STD_CHAR_OFFSET + tables::TOTAL_ALPHA_VNCHARS as u32
        && ch & 1 == 0
    {
        ch + 1
    } else {
        ch
    }
}

/// Decodes a NUL terminated byte string into StdVnChars, terminator
/// included, which is what `VnConvert` with `inLen = -1` produces: the
/// stream hands the NUL out as a character before flagging end of
/// stream, so the converted key and text are NUL terminated in memory.
///
/// Returns `None` when more than `max_chars` would be produced, matching
/// `VnConvert` returning out of memory and `addItem` rejecting the item.
#[cfg(feature = "alloc")]
pub fn decode_nul_terminated(cs: Charset, input: &[u8], max_chars: usize) -> Option<alloc::vec::Vec<u32>> {
    use alloc::vec::Vec;
    let mut out: Vec<u32> = Vec::new();
    let mut st = ViqrIn::default();
    let mut i = 0usize;

    // The stream is at end of stream immediately when the first byte is
    // NUL, so an empty string converts to nothing at all.
    if input.first().copied().unwrap_or(0) == 0 {
        return Some(out);
    }

    loop {
        let (ch, used) = match cs.0 {
            UNIUTF8 | XUTF8 => decode_utf8(input, i),
            VIQR | UTF8VIQR => decode_viqr(input, i, &mut st),
            _ => return None,
        };
        if used == 0 {
            break;
        }
        let last = input[i] == 0;
        i += used;
        if let Some(c) = ch {
            out.push(c);
            if out.len() > max_chars {
                return None;
            }
        }
        if last || i >= input.len() {
            break;
        }
    }
    Some(out)
}

#[cfg(feature = "alloc")]
/// `UnicodeUTF8Charset::nextInput`. Returns the character and how many
/// bytes it consumed; `None` for an invalid sequence, which the original
/// reports as INVALID_STD_CHAR and `genConvert` then drops.
fn decode_utf8(input: &[u8], at: usize) -> (Option<u32>, usize) {
    let first = match input.get(at) {
        Some(&b) => b,
        None => return (None, 0),
    };
    let uni: u16;
    let used: usize;
    if first < 0x80 {
        uni = first as u16;
        used = 1;
    } else if first & 0xE0 == 0xC0 {
        match input.get(at + 1) {
            None => return (None, 0),
            Some(&second) if second & 0xC0 != 0x80 => return (None, 1),
            Some(&second) => {
                uni = (((first & 0x1F) as u16) << 6) | (second & 0x3F) as u16;
                used = 2;
            }
        }
    } else if first & 0xF0 == 0xE0 {
        match (input.get(at + 1), input.get(at + 2)) {
            (None, _) => return (None, 0),
            (Some(&second), _) if second & 0xC0 != 0x80 => return (None, 1),
            (Some(_), None) => return (None, 0),
            (Some(&second), Some(&third)) => {
                if third & 0xC0 != 0x80 {
                    return (None, 2);
                }
                uni = (((first & 0x0F) as u16) << 12)
                    | (((second & 0x3F) as u16) << 6)
                    | (third & 0x3F) as u16;
                used = 3;
            }
        }
    } else {
        return (None, 1);
    }
    (Some(unicode_to_std(uni)), used)
}

#[cfg(feature = "alloc")]
/// Per string state of `VIQRCharset` input decoding. `startInput` sets
/// `m_atWordBeginning` to 1, so the default must not be `false`: it gates
/// the Dd rule and getting it wrong silently turns "DD" into two plain
/// letters instead of the single character d with stroke.
pub struct ViqrIn {
    suspicious: bool,
    at_word_beginning: bool,
    got_tone: bool,
    esc_all: bool,
    esc: EscWindow,
}

#[cfg(feature = "alloc")]
impl Default for ViqrIn {
    fn default() -> Self {
        ViqrIn {
            suspicious: false,
            at_word_beginning: true,
            got_tone: false,
            esc_all: false,
            esc: EscWindow::default(),
        }
    }
}

#[cfg(feature = "alloc")]
/// `VIQRCharset::nextInput`. viqrEsc and smartViqr are 1 by default and
/// the engine never changes them.
fn decode_viqr(input: &[u8], at: usize, st: &mut ViqrIn) -> (Option<u32>, usize) {
    let map = &VIQR_STD_MAP;
    let mut i = at;
    let mut ch1 = match input.get(i) {
        Some(&b) => b,
        None => return (None, 0),
    };
    i += 1;
    let mut std_char = map[ch1 as usize] as u32;

    if st.esc.feed(ch1) {
        st.esc_all = true;
    }
    if st.esc_all && matches!(ch1, b' ' | b'\t' | b'\r' | b'\n') {
        st.esc_all = false;
    }

    if ch1 == b'\\' {
        // The original only recomputes stdChar when getNext FAILS, so on
        // success ch1 advances while stdChar stays as the map entry for
        // the backslash. That is zero, so the branch below substitutes
        // the escaped byte, which is the intended effect.
        if let Some(&b) = input.get(i) {
            ch1 = b;
            i += 1;
        }
    }

    let eos = i >= input.len() || input[i - 1] == 0;

    if std_char < 256 {
        std_char = ch1 as u32;
    } else if !st.esc_all && !eos {
        let ch2 = input.get(i).copied().unwrap_or(0);
        let upper = ch1.to_ascii_uppercase();
        // smartViqr is 1 by default and the engine never changes it, so
        // the guard reduces to at_word_beginning.
        if st.at_word_beginning && upper == b'D' && (ch2 == b'd' || ch2 == b'D') {
            i += 1;
            std_char += 2; // dd sits two past d
        } else {
            let index = map[ch2 as usize] as u32;
            let cond = if st.suspicious {
                is_ascii_vowel(ch1)
                    && (index == 2
                        || index == 4
                        || index == 8
                        || (index == 12 && matches!(upper, b'A' | b'E' | b'O'))
                        || (index == 24 && upper == b'A')
                        || (index == 26 && matches!(upper, b'O' | b'U')))
            } else {
                is_ascii_vowel(ch1)
                    && ((index <= 10 && index > 0 && (!st.got_tone || (index != 6 && index != 10)))
                        || (index == 12 && matches!(upper, b'A' | b'E' | b'O'))
                        || (index == 24 && upper == b'A')
                        || (index == 26 && matches!(upper, b'O' | b'U')))
            };
            if cond {
                if st.suspicious {
                    st.suspicious = false;
                }
                if index > 0 {
                    st.got_tone = true;
                }
                i += 1;
                let mut offset = index;
                if offset == 26 {
                    offset = 24;
                }
                if offset == 24 && (ch1 == b'u' || ch1 == b'U') {
                    offset = 12;
                }
                std_char += offset;
                if let Some(&ch3) = input.get(i) {
                    let i3 = map[ch3 as usize] as u32;
                    if index > 10 && i3 > 0 && i3 <= 10 {
                        i += 1;
                        std_char += i3;
                    }
                }
            }
        }
    }

    st.at_word_beginning = std_char < 256;
    if std_char < 256 {
        st.got_tone = false;
    } else {
        std_char += VN_STD_CHAR_OFFSET - 256;
    }
    (Some(std_char), i - at)
}
