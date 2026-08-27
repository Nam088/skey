//! Faithful port of `UkEngine`.
//!
//! Phase one deliberately keeps the original control flow, including the
//! duplicated tone repositioning blocks. Those blocks look identical but
//! pass three different values for `terminated` to `get_tone_position`
//! (`v_end == current`, `true`, `false`), so merging them changes
//! behaviour. Do not tidy them up without the differential harness
//! green on both sides.

use crate::charset::{self, Charset, Encoder};
use crate::input::{self, InputProcessor, KeyEvent};
use crate::lexi::{CSeq, Lexi, VSeq, INVALID_STD_CHAR, VN_STD_CHAR_OFFSET};
use crate::lexi_consts as L;
use crate::out::OutBuf;
#[cfg(feature = "alloc")]
use crate::out::At;
use crate::seq;
#[cfg(feature = "alloc")]
use crate::limits::{MAX_MACRO_KEY_LEN, MAX_MACRO_TEXT_LEN};
#[cfg(feature = "alloc")]
use crate::macros::MacroTable;
use crate::tables::{self, CSEQ, VSEQ};

pub const MAX_UK_ENGINE: usize = 128;

#[cfg(feature = "alloc")]
#[derive(Clone, Copy, PartialEq)]
enum VnCase {
    NoChange,
    AllCapital,
    AllSmall,
}

// VnWordForm
const VNW_NON_VN: u8 = 0;
const VNW_EMPTY: u8 = 1;
const VNW_C: u8 = 2;
const VNW_V: u8 = 3;
const VNW_CV: u8 = 4;
const VNW_VC: u8 = 5;
const VNW_CVC: u8 = 6;

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
#[cfg_attr(feature = "serde", derive(serde::Serialize, serde::Deserialize))]
pub enum OutputType {
    Char,
    Key,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[cfg_attr(feature = "serde", derive(serde::Serialize, serde::Deserialize))]
#[cfg_attr(feature = "serde", serde(default))]
pub struct Options {
    pub free_marking: bool,
    pub modern_style: bool,
    pub macro_enabled: bool,
    /// Dead at the engine level, in the original and therefore here:
    /// `UnikeySetOptions` stores it and the engine never reads it.
    pub use_unicode_clipboard: bool,
    /// Dead at the engine level, same as above.
    pub always_macro: bool,
    /// Dead at the engine level, and the original does not even copy it
    /// in `UnikeySetOptions`.
    pub strict_spell_check: bool,
    pub spell_check_enabled: bool,
    pub auto_non_vn_restore: bool,
    /// Restore the raw key strokes when a listed English word came out
    /// with a key swallowed and no Vietnamese mark produced: `off` became
    /// `of`, `pass` became `pas`. Nobody types those on purpose, so this
    /// tier costs nothing.
    ///
    /// `autoNonVnRestore` cannot cover them: it only fires when the
    /// result is phonotactically invalid, and it also refuses to restore
    /// a word with no Vietnamese mark at all, which is exactly this case.
    pub swallowed_key_restore: bool,
    /// Telex doubled consonant shortcuts: `cc` for `ch`, `gg` for `gi`,
    /// `kk` for `kh`, `nn` for `ng`, `qq` for `qu`, `pp` for `ph`, `tt`
    /// for `th`, and `uu` for u horn plus o horn. A doubled consonant is
    /// never valid Vietnamese, so this takes nothing away.
    pub quick_telex: bool,
    /// Onset shortcuts: `f` for `ph`, `j` for `gi`, `w` for `qu`, so
    /// `fanh` gives `phanh`. Those three letters can never begin a
    /// Vietnamese word, so this takes nothing away either.
    pub quick_start_consonant: bool,
    /// Coda shortcuts: `g` for `ng`, `h` for `nh`, `k` for `ch`, so `hag`
    /// gives `hang`. Unlike the two above this cannot be decided when the
    /// key arrives, because `g` after `n` is a legitimate coda, so it is
    /// applied at the word break and only when the substitution rescues a
    /// word that was invalid as typed.
    pub quick_end_consonant: bool,
    /// Capitalise the first letter after a full stop or a new line.
    pub upper_case_first_char: bool,
    /// Treat `z`, `f`, `w` and `j` as ordinary consonants, so a word
    /// containing them can still take tones: `fas` gives f with an acute
    /// on the a rather than being abandoned. The original classifies `f`,
    /// `j` and `w` as non Vietnamese outright and leaves `z` alone.
    ///
    /// The riskiest of these options by a distance: it is the only one
    /// that changes character classification rather than rewriting an
    /// event, and `UKC_MAP` is the table the whole spell checker rests on.
    pub allow_consonant_zfwj: bool,
}

impl Default for Options {
    /// Mirrors `CreateDefaultUnikeyOptions`.
    fn default() -> Self {
        Options {
            free_marking: true,
            modern_style: false,
            macro_enabled: false,
            use_unicode_clipboard: false,
            always_macro: false,
            strict_spell_check: false,
            spell_check_enabled: true,
            auto_non_vn_restore: false,
            swallowed_key_restore: false,
            quick_telex: false,
            quick_start_consonant: false,
            quick_end_consonant: false,
            upper_case_first_char: false,
            allow_consonant_zfwj: false,
        }
    }
}

/// One buffer entry. `seq` is a single field on purpose: the original
/// overlays `VowelSeq` and `ConSeq` in a union, and reading the arm that
/// does not match `form` is observable behaviour we must not change.
/// Packed to 16 bytes from the original's 36. Offsets are positions
/// inside one word, so they never leave the range -1 to 127, and the
/// tone level is 0 to 5. Arithmetic still happens in i32 through the
/// accessors, so the engine code reads exactly as it did before.
#[derive(Clone, Copy, Debug)]
struct WordInfo {
    key_code: u32,
    vn_sym: Lexi,
    seq: i16,
    c1o: i8,
    vo: i8,
    c2o: i8,
    /// form in bits 0 to 2 (seven values), tone level in bits 3 to 5
    /// (six values), capitalisation in bit 6. Seven bits of real payload
    /// in the byte that alignment was going to waste anyway, which takes
    /// the entry from 16 bytes to 12 and the buffer from 2048 to 1536.
    bits: u8,
}

const FORM_MASK: u8 = 0b0000_0111;
const TONE_SHIFT: u32 = 3;
const TONE_MASK: u8 = 0b0011_1000;
const CAPS_BIT: u8 = 0b0100_0000;

impl Default for WordInfo {
    fn default() -> Self {
        WordInfo {
            key_code: 0,
            vn_sym: Lexi::NON_VN,
            seq: -1,
            c1o: -1,
            vo: -1,
            c2o: -1,
            bits: VNW_EMPTY,
        }
    }
}

impl WordInfo {
    #[inline]
    fn vseq(&self) -> VSeq {
        VSeq(self.seq)
    }
    #[inline]
    fn cseq(&self) -> CSeq {
        CSeq(self.seq)
    }
    #[inline]
    fn set_vseq(&mut self, v: VSeq) {
        self.seq = v.0;
    }
    #[inline]
    fn set_cseq(&mut self, c: CSeq) {
        self.seq = c.0;
    }

    #[inline]
    fn c1_offset(&self) -> i32 {
        self.c1o as i32
    }
    #[inline]
    fn v_offset(&self) -> i32 {
        self.vo as i32
    }
    #[inline]
    fn c2_offset(&self) -> i32 {
        self.c2o as i32
    }
    #[inline]
    fn tone(&self) -> i32 {
        ((self.bits & TONE_MASK) >> TONE_SHIFT) as i32
    }

    #[inline]
    fn form(&self) -> u8 {
        self.bits & FORM_MASK
    }

    #[inline]
    fn caps(&self) -> bool {
        self.bits & CAPS_BIT != 0
    }

    #[inline]
    fn set_form(&mut self, v: u8) {
        debug_assert!(v <= FORM_MASK, "form {v} out of range");
        self.bits = (self.bits & !FORM_MASK) | v;
    }

    #[inline]
    fn set_caps(&mut self, v: bool) {
        if v {
            self.bits |= CAPS_BIT;
        } else {
            self.bits &= !CAPS_BIT;
        }
    }

    #[inline]
    fn set_c1_offset(&mut self, v: i32) {
        debug_assert!((-1..=127).contains(&v), "c1 offset {v} out of range");
        self.c1o = v as i8;
    }
    #[inline]
    fn set_v_offset(&mut self, v: i32) {
        debug_assert!((-1..=127).contains(&v), "v offset {v} out of range");
        self.vo = v as i8;
    }
    #[inline]
    fn set_c2_offset(&mut self, v: i32) {
        debug_assert!((-1..=127).contains(&v), "c2 offset {v} out of range");
        self.c2o = v as i8;
    }
    #[inline]
    fn set_tone(&mut self, v: i32) {
        debug_assert!((0..=5).contains(&v), "tone level {v} out of range");
        self.bits = (self.bits & !TONE_MASK) | ((v as u8) << TONE_SHIFT);
    }
}

/// The key stroke buffer keeps two parallel arrays rather than one array
/// of structs. A struct of `u32` plus a flag pads out to 8 bytes, so
/// splitting them costs nothing in code and saves 384 bytes.
///
/// The stored character type is gone: `restore_key_strokes` rebuilds the
/// whole event with `key_code_to_symbol`, and `char_type` reads only
/// static tables, so it is a pure function of the key code and storing it
/// was pure redundancy. The three places that wanted it derive it now.

/// Result of one key press.
#[derive(Clone, Copy, Debug)]
pub struct Edit {
    /// Backspaces the front end must send before the new bytes.
    pub backspaces: i32,
    pub out_type: OutputType,
    /// False means the engine did not consume the key: the front end
    /// should let the original key through untouched. The bytes to send
    /// are `Engine::output()`.
    pub handled: bool,
}

pub struct Engine {
    // ---- state that outlives a keystroke ----
    buffer: [WordInfo; MAX_UK_ENGINE],
    keys: [u32; MAX_UK_ENGINE],
    /// Whether the stroke at the same index caused a conversion.
    converted: [bool; MAX_UK_ENGINE],
    current: i32,
    key_current: i32,
    single_mode: bool,
    to_escape: bool,
    /// Set when a full stop or a line break has been seen and the next
    /// letter should be capitalised. Armed at construction so the first
    /// letter of a session counts as the start of a sentence, but
    /// deliberately **not** re-armed by `reset()`: reset also happens on a
    /// focus change and on the arrow keys, and re-arming there would
    /// capitalise after a click into the middle of a sentence.
    capitalise_next: bool,

    // ---- configuration, was UkSharedMem ----
    pub viet_key: bool,
    pub options: Options,
    pub charset: Charset,
    pub input: InputProcessor,
    /// Present only with the `alloc` feature. Without it `macro_match`
    /// never matches, which is the engine with macros switched off.
    #[cfg(feature = "alloc")]
    pub macro_store: MacroTable,
    caps_lock_on: bool,
    shift_pressed: bool,

    /// Was a function level `static` inside `processTelexW`, therefore
    /// shared across every engine instance and not thread safe. Now per
    /// instance, which is identical for the single engine the original
    /// actually creates.
    used_as_map_char: bool,

    // ---- state valid within one keystroke ----
    out: OutBuf,
    /// Models `*m_pOutSize`: on entry it is the caller's buffer size,
    /// and every path that produces output assigns the byte count to it.
    /// It is a capacity and a result at the same time, which matters:
    /// `checkEscapeVIQR` assigns 2 to it, so an escape raised from inside
    /// the key stroke restore loop shrinks the bound that the restore's
    /// own count is later checked against.
    out_size: usize,
    backs: i32,
    change_pos: i32,
    out_written: bool,
    reverted: bool,
    key_restored: bool,
    key_restoring: bool,
    out_type: OutputType,
}

impl Default for Engine {
    fn default() -> Self {
        Engine::new()
    }
}

// ---------------------------------------------------------------- tables

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
fn pack3(a: Lexi, b: Lexi, c: Lexi) -> u32 {
    (((a.0 + 1) as u32) << 16) | (((b.0 + 1) as u32) << 8) | ((c.0 + 1) as u32)
}

#[cfg(debug_assertions)]
/// Binary search over a flat, compile time sorted key array. The
/// original sorted a copy of the table with `qsort` at start up and then
/// used `bsearch` with a comparator that looped over three elements per
/// comparison; this is the same search with no start up cost, no
/// indirect call, and one integer compare per step.
fn lookup_vseq3(v1: Lexi, v2: Lexi, v3: Lexi) -> VSeq {
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
fn lookup_vseq1(v1: Lexi) -> VSeq {
    lookup_vseq3(v1, Lexi::NON_VN, Lexi::NON_VN)
}

#[cfg(debug_assertions)]
#[inline]
fn lookup_vseq2(v1: Lexi, v2: Lexi) -> VSeq {
    lookup_vseq3(v1, v2, Lexi::NON_VN)
}

#[cfg(debug_assertions)]
fn lookup_cseq3(c1: Lexi, c2: Lexi, c3: Lexi) -> CSeq {
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
fn lookup_cseq1(c1: Lexi) -> CSeq {
    lookup_cseq3(c1, Lexi::NON_VN, Lexi::NON_VN)
}

#[cfg(debug_assertions)]
#[inline]
fn lookup_cseq2(c1: Lexi, c2: Lexi) -> CSeq {
    lookup_cseq3(c1, c2, Lexi::NON_VN)
}

/// One AND against a precomputed bitmap. The original tested gi and qu
/// with branches and then scanned a static list for k.
#[inline]
fn is_valid_cv(c: CSeq, v: VSeq) -> bool {
    let r = seq::is_valid_cv(c, v);
    #[cfg(debug_assertions)]
    debug_assert_eq!(r, is_valid_cv_reference(c, v));
    r
}

#[cfg(debug_assertions)]
fn is_valid_cv_reference(c: CSeq, v: VSeq) -> bool {
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
fn vseq1(sym: Lexi) -> VSeq {
    let r = seq::v_single(sym);
    #[cfg(debug_assertions)]
    debug_assert_eq!(r, lookup_vseq1(sym));
    r
}

#[inline]
fn cseq1(sym: Lexi) -> CSeq {
    let r = seq::c_single(sym);
    #[cfg(debug_assertions)]
    debug_assert_eq!(r, lookup_cseq1(sym));
    r
}

#[inline]
fn vseq_extend(vs: VSeq, sym: Lexi) -> VSeq {
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
fn cseq_extend(cs: CSeq, sym: Lexi) -> CSeq {
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

fn is_valid_vc(v: VSeq, c: CSeq) -> bool {
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
fn is_valid_cvc(c1: CSeq, v: VSeq, c2: CSeq) -> bool {
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
fn std_no_tone(l: Lexi) -> Lexi {
    Lexi(tables::STD_NO_TONE[l.idx()] as i16)
}

#[inline]
fn is_vowel(l: Lexi) -> bool {
    if l.is_non_vn() {
        false
    } else {
        tables::IS_VOWEL[l.idx()]
    }
}

// ---------------------------------------------------------------- engine

impl Engine {
    pub fn new() -> Self {
        Engine {
            buffer: [WordInfo::default(); MAX_UK_ENGINE],
            keys: [0; MAX_UK_ENGINE],
            converted: [false; MAX_UK_ENGINE],
            current: -1,
            key_current: -1,
            single_mode: false,
            to_escape: false,
            capitalise_next: true,
            viet_key: true,
            options: Options::default(),
            charset: Charset::default(),
            input: InputProcessor::default(),
            #[cfg(feature = "alloc")]
            macro_store: MacroTable::new(),
            caps_lock_on: false,
            shift_pressed: false,
            used_as_map_char: false,
            out: OutBuf::default(),
            out_size: crate::out::OUT_CAPACITY,
            backs: 0,
            change_pos: 0,
            out_written: false,
            reverted: false,
            key_restored: false,
            key_restoring: false,
            out_type: OutputType::Char,
        }
    }

    pub fn output(&self) -> &[u8] {
        self.out.bytes_up_to(self.out_size)
    }


    /// The size the original reports in `UnikeyBufChars`, which can
    /// exceed the bytes actually stored when the caller's buffer fills
    /// up, because the stream counter runs past the capacity.
    pub fn output_len(&self) -> usize {
        self.out_size
    }

    /// Types a whole string and returns what the front end's buffer would
    /// hold afterwards: convenient for tests, WASM demos and REPLs.
    ///
    /// Only meaningful for the UTF-8 charsets, where one backspace step is
    /// one character. Other charsets count steps in bytes or code units,
    /// so a front end has to apply the edits itself.
    #[cfg(feature = "alloc")]
    pub fn type_str(&mut self, s: &str) -> alloc::string::String {
        debug_assert!(
            self.charset.0 == crate::charset::XUTF8 || self.charset.0 == crate::charset::UNIUTF8,
            "type_str counts backspaces in characters, so it needs a UTF-8 charset"
        );
        let mut out: alloc::vec::Vec<char> = alloc::vec::Vec::new();
        for ch in s.chars() {
            let e = self.key(ch as u32);
            if !e.handled {
                out.push(ch);
                continue;
            }
            for _ in 0..e.backspaces {
                out.pop();
            }
            if let Ok(t) = core::str::from_utf8(self.output()) {
                out.extend(t.chars());
            }
        }
        out.into_iter().collect()
    }

    pub fn set_caps_state(&mut self, shift_pressed: bool, caps_lock_on: bool) {
        self.shift_pressed = shift_pressed;
        self.caps_lock_on = caps_lock_on;
    }

    pub fn set_input_method(&mut self, im: i32) {
        self.input.set_im(im);
        self.reset();
    }

    pub fn set_charset(&mut self, cs: Charset) {
        self.charset = cs;
        self.reset();
    }

    pub fn reset(&mut self) {
        self.current = -1;
        self.key_current = -1;
        self.single_mode = false;
        self.to_escape = false;
    }

    pub fn set_single_mode(&mut self) {
        self.single_mode = true;
    }

    pub fn at_word_beginning(&self) -> bool {
        self.current < 0 || self.b(self.current).form() == VNW_EMPTY
    }

    // --- buffer accessors, i32 indices mirror the original arithmetic ---

    #[inline]
    fn b(&self, i: i32) -> WordInfo {
        debug_assert!(i >= 0 && (i as usize) < MAX_UK_ENGINE, "buffer index {i}");
        self.buffer[i as usize]
    }

    #[inline]
    fn bm(&mut self, i: i32) -> &mut WordInfo {
        debug_assert!(i >= 0 && (i as usize) < MAX_UK_ENGINE, "buffer index {i}");
        &mut self.buffer[i as usize]
    }

    /// `InputProcessor::char_type` with the ZFWJ option applied. Every
    /// classification inside the engine goes through here, so there is
    /// exactly one place that knows about the override.
    ///
    /// The flag is read from `options` rather than copied into the input
    /// processor: `options` is a public field that callers assign to
    /// directly, so a duplicate would go stale the moment somebody set the
    /// option without going through a setter.
    #[inline]
    fn char_type(&self, key_code: u32) -> u8 {
        if self.options.allow_consonant_zfwj
            && key_code < 128
            && matches!(key_code as u8 | 0x20, b'z' | b'f' | b'w' | b'j')
        {
            return input::UKC_VN;
        }
        self.input.char_type(key_code)
    }

    /// `char_type` reads only static tables, so the stored copy the
    /// original kept was redundant.
    #[inline]
    fn key_is_word_break(&self, i: i32) -> bool {
        self.char_type(self.keys[i as usize]) == input::UKC_WORD_BREAK
    }

    #[inline]
    fn cur(&self) -> WordInfo {
        self.b(self.current)
    }

    /// One table load. `seq::TONE_POS` is generated from the same data at
    /// compile time; the original's branch chain is kept below as a
    /// debug time shadow so the two can never drift apart unnoticed.
    #[inline]
    fn get_tone_position(&self, vs: VSeq, terminated: bool) -> i32 {
        let r = seq::tone_pos(vs, terminated, self.options.modern_style);
        #[cfg(debug_assertions)]
        debug_assert_eq!(r, self.tone_position_reference(vs, terminated));
        r
    }

    #[cfg(debug_assertions)]
    fn tone_position_reference(&self, vs: VSeq, terminated: bool) -> i32 {
        let info = &VSEQ[vs.idx()];
        if info.len == 1 {
            return 0;
        }
        if info.roof_pos != -1 {
            return info.roof_pos as i32;
        }
        if info.hook_pos != -1 {
            if vs == L::vs_uhoh || vs == L::vs_uhohi || vs == L::vs_uhohu {
                return 1;
            }
            return info.hook_pos as i32;
        }
        if info.len == 3 {
            return 1;
        }
        if self.options.modern_style && (vs == L::vs_oa || vs == L::vs_oe || vs == L::vs_uy) {
            return 1;
        }
        if terminated {
            0
        } else {
            1
        }
    }

    /// Re-derives a vowel sequence from the buffer symbols, used only to
    /// check the generated tables in debug builds.
    #[cfg(debug_assertions)]
    fn rebuild_vseq(&self, v_start: i32, len: u8) -> VSeq {
        match len {
            3 => lookup_vseq3(
                self.b(v_start).vn_sym,
                self.b(v_start + 1).vn_sym,
                self.b(v_start + 2).vn_sym,
            ),
            2 => lookup_vseq2(self.b(v_start).vn_sym, self.b(v_start + 1).vn_sym),
            _ => lookup_vseq1(self.b(v_start).vn_sym),
        }
    }

    fn mark_change(&mut self, pos: i32) {
        if pos < self.change_pos {
            self.backs += self.get_seq_steps(pos, self.change_pos - 1);
            self.change_pos = pos;
        }
    }

    /// Backspaces needed to walk back from `last` to `first`.
    fn get_seq_steps(&self, first: i32, last: i32) -> i32 {
        if last < first {
            return 0;
        }
        if self.charset.one_step_per_char() {
            return last - first + 1;
        }
        // The original calls startOutput then encodes the range into a
        // zero length stream just to read the byte count back. Same
        // traversal and same charset state, but the counting sink stores
        // nothing.
        let mut enc = Encoder::new(self.charset);
        let mut len = 0usize;
        for i in first..=last {
            let e = self.b(i);
            let std_char = self.std_char_of(&e);
            if std_char != INVALID_STD_CHAR {
                len += enc.count(std_char);
            }
        }
        if self.charset.0 == charset::UNIDECOMPOSED {
            len /= 2;
        }
        len as i32
    }

    /// StdVnChar for one buffer entry. `writeOutput` and `getSeqSteps`
    /// differ in one detail: the former maps a raw key code through
    /// `IsoStdVnCharMap`, the latter uses it directly. Preserved.
    #[inline]
    fn std_char_of(&self, e: &WordInfo) -> u32 {
        if !e.vn_sym.is_non_vn() {
            let mut c = e.vn_sym.0 as u32 + VN_STD_CHAR_OFFSET;
            if e.caps() {
                c -= 1;
            }
            if e.tone() != 0 {
                c += (e.tone() as u32) * 2;
            }
            c
        } else {
            e.key_code
        }
    }

    #[inline]
    fn std_char_for_output(&self, e: &WordInfo) -> u32 {
        if !e.vn_sym.is_non_vn() {
            self.std_char_of(e)
        } else if e.key_code < 256 {
            tables::ISO_STD[e.key_code as usize]
        } else {
            e.key_code
        }
    }

    fn write_output(&mut self) {
        self.out.reset();
        let mut enc = Encoder::new(self.charset);
        for i in self.change_pos..=self.current {
            let e = self.b(i);
            let std_char = self.std_char_for_output(&e);
            if std_char != INVALID_STD_CHAR {
                enc.put(&mut self.out, std_char);
            }
        }
        self.out_size = self.out.len();
    }

    /// Keep at least ten entries available.
    fn prepare_buffer(&mut self) {
        if self.current >= 0 && self.current as usize + 10 >= MAX_UK_ENGINE {
            // Drop at least half the entries, never from mid word.
            // The original evaluates the buffer read before the bound
            // check; `rid <= current < 128` keeps that in range.
            let mut rid = self.current / 2;
            while self.b(rid).form() != VNW_EMPTY && rid < self.current {
                rid += 1;
            }
            if rid == self.current {
                self.current = -1;
            } else {
                rid += 1;
                let n = (self.current - rid + 1) as usize;
                self.buffer.copy_within(rid as usize..(rid as usize + n), 0);
                self.current -= rid;
            }
        }

        if self.key_current > 0 && self.key_current as usize + 1 >= MAX_UK_ENGINE {
            let rid = self.key_current / 2;
            let n = (self.key_current - rid + 1) as usize;
            self.keys.copy_within(rid as usize..(rid as usize + n), 0);
            self.converted
                .copy_within(rid as usize..(rid as usize + n), 0);
            self.key_current -= rid;
        }
    }
}

// ----------------------------------------------------- key processors

impl Engine {
    fn process_roof(&mut self, ev: &mut KeyEvent) -> i32 {
        if !self.viet_key || self.current < 0 || self.cur().v_offset() < 0 {
            return self.process_append(ev);
        }

        let target = match ev.ev_type {
            input::ROOF_A => L::ar,
            input::ROOF_E => L::er,
            input::ROOF_O => L::or,
            _ => Lexi::NON_VN,
        };

        let v_end = self.current - self.cur().v_offset();
        let vs = self.b(v_end).vseq();
        let v_start = v_end - (VSEQ[vs.idx()].len as i32 - 1);
        let cur_tone_pos = v_start + self.get_tone_position(vs, v_end == self.current);
        let tone = self.b(cur_tone_pos).tone();

        let mut double_change_uo = false;
        let mut new_vs;
        if vs == L::vs_uho || vs == L::vs_uhoh || vs == L::vs_uhoi || vs == L::vs_uhohi {
            // u+o+ -> uo^, u+o -> uo^, u+o+i -> uo^i, u+oi -> uo^i
            new_vs = seq::v_u_or(vs);
            double_change_uo = true;
        } else {
            new_vs = VSEQ[vs.idx()].with_roof;
        }

        let mut roof_removed = false;

        if new_vs.is_nil() {
            if VSEQ[vs.idx()].roof_pos == -1 {
                return self.process_append(ev); // roof is not applicable
            }

            // A roof already exists, so undo it.
            let cur_ch = self.b(v_start + VSEQ[vs.idx()].roof_pos as i32).vn_sym;
            if !target.is_non_vn() && cur_ch != target {
                return self.process_append(ev);
            }

            let new_ch = if cur_ch == L::ar {
                L::a
            } else if cur_ch == L::er {
                L::e
            } else {
                L::o
            };
            let change_pos = v_start + VSEQ[vs.idx()].roof_pos as i32;

            if !self.options.free_marking && change_pos != self.current {
                return self.process_append(ev);
            }

            self.mark_change(change_pos);
            self.bm(change_pos).vn_sym = new_ch;

            // The only symbol that changed is the one that carried the
            // roof, so the resulting sequence is a function of the old
            // one. The debug shadow re-derives it from the buffer.
            new_vs = seq::v_no_roof(vs);
            #[cfg(debug_assertions)]
            debug_assert_eq!(new_vs, self.rebuild_vseq(v_start, VSEQ[vs.idx()].len));
            roof_removed = true;
        } else {
            let p_info = VSEQ[new_vs.idx()];
            if !target.is_non_vn() && p_info.v[p_info.roof_pos as usize] != target {
                return self.process_append(ev);
            }

            let mut c1 = CSeq::NIL;
            let mut c2 = CSeq::NIL;
            if self.cur().c1_offset() != -1 {
                c1 = self.b(self.current - self.cur().c1_offset()).cseq();
            }
            if self.cur().c2_offset() != -1 {
                c2 = self.b(self.current - self.cur().c2_offset()).cseq();
            }
            if !is_valid_cvc(c1, new_vs, c2) {
                return self.process_append(ev);
            }

            let change_pos = if double_change_uo {
                v_start
            } else {
                v_start + p_info.roof_pos as i32
            };
            if !self.options.free_marking && change_pos != self.current {
                return self.process_append(ev);
            }
            self.mark_change(change_pos);
            if double_change_uo {
                self.bm(v_start).vn_sym = L::u;
                self.bm(v_start + 1).vn_sym = L::or;
            } else {
                self.bm(change_pos).vn_sym = p_info.v[p_info.roof_pos as usize];
            }
        }

        let p_info = VSEQ[new_vs.idx()];
        for i in 0..p_info.len as i32 {
            self.bm(v_start + i).set_vseq(p_info.sub[i as usize]);
        }

        let new_tone_pos = v_start + self.get_tone_position(new_vs, v_end == self.current);
        if cur_tone_pos != new_tone_pos && tone != 0 {
            self.mark_change(new_tone_pos);
            self.bm(new_tone_pos).set_tone(tone);
            self.mark_change(cur_tone_pos);
            self.bm(cur_tone_pos).set_tone(0);
        }

        if roof_removed {
            self.single_mode = false;
            let _ = self.process_append(ev);
            self.reverted = true;
        }

        1
    }

    /// Only reachable from `process_hook`.
    fn process_hook_with_uo(&mut self, ev: &mut KeyEvent) -> i32 {
        if !self.options.free_marking && self.cur().v_offset() != 0 {
            return self.process_append(ev);
        }

        let v_end = self.current - self.cur().v_offset();
        let vs = self.b(v_end).vseq();
        let v_start = v_end - (VSEQ[vs.idx()].len as i32 - 1);
        let v = VSEQ[vs.idx()].v;
        let cur_tone_pos = v_start + self.get_tone_position(vs, v_end == self.current);
        let tone = self.b(cur_tone_pos).tone();

        let mut hook_removed = false;
        let new_vs;

        match ev.ev_type {
            input::HOOK_U => {
                if v[0] == L::u {
                    new_vs = VSEQ[vs.idx()].with_hook;
                    self.mark_change(v_start);
                    self.bm(v_start).vn_sym = L::uh;
                } else {
                    // v[0] == uh, back to uo
                    new_vs = seq::v_u_o(vs);
                    self.mark_change(v_start);
                    self.bm(v_start).vn_sym = L::u;
                    self.bm(v_start + 1).vn_sym = L::o;
                    hook_removed = true;
                }
            }
            input::HOOK_O => {
                if v[1] == L::o || v[1] == L::or {
                    if v_end == self.current
                        && VSEQ[vs.idx()].len == 2
                        && self.cur().form() == VNW_CV
                        && self.b(self.current - 2).cseq() == L::cs_th
                    {
                        // o|o^ -> o+
                        new_vs = VSEQ[vs.idx()].with_hook;
                        self.mark_change(v_start + 1);
                        self.bm(v_start + 1).vn_sym = L::oh;
                    } else {
                        new_vs = seq::v_uh_oh(vs);
                        if v[0] == L::u {
                            self.mark_change(v_start);
                            self.bm(v_start).vn_sym = L::uh;
                            self.bm(v_start + 1).vn_sym = L::oh;
                        } else {
                            self.mark_change(v_start + 1);
                            self.bm(v_start + 1).vn_sym = L::oh;
                        }
                    }
                } else {
                    // v[1] == oh, back to uo
                    new_vs = seq::v_u_o(vs);
                    if v[0] == L::uh {
                        self.mark_change(v_start);
                        self.bm(v_start).vn_sym = L::u;
                        self.bm(v_start + 1).vn_sym = L::o;
                    } else {
                        self.mark_change(v_start + 1);
                        self.bm(v_start + 1).vn_sym = L::o;
                    }
                    hook_removed = true;
                }
            }
            _ => {
                // HOOK_ALL, HOOK_UO
                if v[0] == L::u {
                    if v[1] == L::o || v[1] == L::or {
                        // uo -> uo+ when prefixed by th or h
                        if (vs == L::vs_uo || vs == L::vs_uor)
                            && v_end == self.current
                            && self.cur().form() == VNW_CV
                            && (self.b(self.current - 2).cseq() == L::cs_th
                                || self.b(self.current - 2).cseq() == L::cs_h)
                        {
                            new_vs = L::vs_uoh;
                            self.mark_change(v_start + 1);
                            self.bm(v_start + 1).vn_sym = L::oh;
                        } else {
                            // uo -> u+o+
                            let mid = VSEQ[vs.idx()].with_hook;
                            self.mark_change(v_start);
                            self.bm(v_start).vn_sym = L::uh;
                            new_vs = VSEQ[mid.idx()].with_hook;
                            self.bm(v_start + 1).vn_sym = L::oh;
                        }
                    } else {
                        // uo+ -> u+o+
                        new_vs = VSEQ[vs.idx()].with_hook;
                        self.mark_change(v_start);
                        self.bm(v_start).vn_sym = L::uh;
                    }
                } else {
                    // v[0] == uh
                    if v[1] == L::o {
                        // u+o -> u+o+
                        new_vs = VSEQ[vs.idx()].with_hook;
                        self.mark_change(v_start + 1);
                        self.bm(v_start + 1).vn_sym = L::oh;
                    } else {
                        // v[1] == oh, u+o+ -> uo
                        new_vs = seq::v_u_o(vs);
                        self.mark_change(v_start);
                        self.bm(v_start).vn_sym = L::u;
                        self.bm(v_start + 1).vn_sym = L::o;
                        hook_removed = true;
                    }
                }
            }
        }

        let p = VSEQ[new_vs.idx()];
        for i in 0..p.len as i32 {
            self.bm(v_start + i).set_vseq(p.sub[i as usize]);
        }

        let new_tone_pos = v_start + self.get_tone_position(new_vs, v_end == self.current);
        if cur_tone_pos != new_tone_pos && tone != 0 {
            self.mark_change(new_tone_pos);
            self.bm(new_tone_pos).set_tone(tone);
            self.mark_change(cur_tone_pos);
            self.bm(cur_tone_pos).set_tone(0);
        }

        if hook_removed {
            self.single_mode = false;
            let _ = self.process_append(ev);
            self.reverted = true;
        }

        1
    }

    fn process_hook(&mut self, ev: &mut KeyEvent) -> i32 {
        if !self.viet_key || self.current < 0 || self.cur().v_offset() < 0 {
            return self.process_append(ev);
        }

        let v_end = self.current - self.cur().v_offset();
        let vs = self.b(v_end).vseq();
        let v = VSEQ[vs.idx()].v;

        if VSEQ[vs.idx()].len > 1
            && ev.ev_type != input::BOWL
            && (v[0] == L::u || v[0] == L::uh)
            && (v[1] == L::o || v[1] == L::oh || v[1] == L::or)
        {
            return self.process_hook_with_uo(ev);
        }

        let v_start = v_end - (VSEQ[vs.idx()].len as i32 - 1);
        let cur_tone_pos = v_start + self.get_tone_position(vs, v_end == self.current);
        let tone = self.b(cur_tone_pos).tone();

        let mut new_vs = VSEQ[vs.idx()].with_hook;
        let mut hook_removed = false;

        if new_vs.is_nil() {
            if VSEQ[vs.idx()].hook_pos == -1 {
                return self.process_append(ev); // hook is not applicable
            }

            // A hook already exists, so undo it.
            let cur_ch = self.b(v_start + VSEQ[vs.idx()].hook_pos as i32).vn_sym;
            let new_ch = if cur_ch == L::ab {
                L::a
            } else if cur_ch == L::uh {
                L::u
            } else {
                L::o
            };
            let change_pos = v_start + VSEQ[vs.idx()].hook_pos as i32;
            if !self.options.free_marking && change_pos != self.current {
                return self.process_append(ev);
            }

            match ev.ev_type {
                input::HOOK_U => {
                    if cur_ch != L::uh {
                        return self.process_append(ev);
                    }
                }
                input::HOOK_O => {
                    if cur_ch != L::oh {
                        return self.process_append(ev);
                    }
                }
                input::BOWL => {
                    if cur_ch != L::ab {
                        return self.process_append(ev);
                    }
                }
                _ => {
                    if ev.ev_type == input::HOOK_UO && cur_ch == L::ab {
                        return self.process_append(ev);
                    }
                }
            }

            self.mark_change(change_pos);
            self.bm(change_pos).vn_sym = new_ch;

            new_vs = seq::v_no_hook(vs);
            #[cfg(debug_assertions)]
            debug_assert_eq!(new_vs, self.rebuild_vseq(v_start, VSEQ[vs.idx()].len));
            hook_removed = true;
        } else {
            let p_info = VSEQ[new_vs.idx()];

            match ev.ev_type {
                input::HOOK_U => {
                    if p_info.v[p_info.hook_pos as usize] != L::uh {
                        return self.process_append(ev);
                    }
                }
                input::HOOK_O => {
                    if p_info.v[p_info.hook_pos as usize] != L::oh {
                        return self.process_append(ev);
                    }
                }
                input::BOWL => {
                    if p_info.v[p_info.hook_pos as usize] != L::ab {
                        return self.process_append(ev);
                    }
                }
                _ => {
                    if ev.ev_type == input::HOOK_UO && p_info.v[p_info.hook_pos as usize] == L::ab {
                        return self.process_append(ev);
                    }
                }
            }

            let mut c1 = CSeq::NIL;
            let mut c2 = CSeq::NIL;
            if self.cur().c1_offset() != -1 {
                c1 = self.b(self.current - self.cur().c1_offset()).cseq();
            }
            if self.cur().c2_offset() != -1 {
                c2 = self.b(self.current - self.cur().c2_offset()).cseq();
            }
            if !is_valid_cvc(c1, new_vs, c2) {
                return self.process_append(ev);
            }

            let change_pos = v_start + p_info.hook_pos as i32;
            if !self.options.free_marking && change_pos != self.current {
                return self.process_append(ev);
            }

            self.mark_change(change_pos);
            self.bm(change_pos).vn_sym = p_info.v[p_info.hook_pos as usize];
        }

        let p_info = VSEQ[new_vs.idx()];
        for i in 0..p_info.len as i32 {
            self.bm(v_start + i).set_vseq(p_info.sub[i as usize]);
        }

        let new_tone_pos = v_start + self.get_tone_position(new_vs, v_end == self.current);
        if cur_tone_pos != new_tone_pos && tone != 0 {
            self.mark_change(new_tone_pos);
            self.bm(new_tone_pos).set_tone(tone);
            self.mark_change(cur_tone_pos);
            self.bm(cur_tone_pos).set_tone(0);
        }

        if hook_removed {
            self.single_mode = false;
            let _ = self.process_append(ev);
            self.reverted = true;
        }

        1
    }

    fn process_tone(&mut self, ev: &mut KeyEvent) -> i32 {
        if self.current < 0 || !self.viet_key {
            return self.process_append(ev);
        }

        if self.cur().form() == VNW_C
            && (self.cur().cseq() == L::cs_gi || self.cur().cseq() == L::cs_gin)
        {
            let p = if self.cur().cseq() == L::cs_gi {
                self.current
            } else {
                self.current - 1
            };
            if self.b(p).tone() == 0 && ev.tone == 0 {
                return self.process_append(ev);
            }
            self.mark_change(p);
            if self.b(p).tone() == ev.tone {
                self.bm(p).set_tone(0);
                self.single_mode = false;
                let _ = self.process_append(ev);
                self.reverted = true;
                return 1;
            }
            self.bm(p).set_tone(ev.tone);
            return 1;
        }

        if self.cur().v_offset() < 0 {
            return self.process_append(ev);
        }

        let v_end = self.current - self.cur().v_offset();
        let vs = self.b(v_end).vseq();
        let info = VSEQ[vs.idx()];
        if self.options.spell_check_enabled && !self.options.free_marking && !info.complete {
            return self.process_append(ev);
        }

        if self.cur().form() == VNW_VC || self.cur().form() == VNW_CVC {
            let cs = self.cur().cseq();
            if (cs == L::cs_c || cs == L::cs_ch || cs == L::cs_p || cs == L::cs_t)
                && (ev.tone == 2 || ev.tone == 3 || ev.tone == 4)
            {
                // c, ch, p, t suffixes do not allow the ` ? ~ tones
                return self.process_append(ev);
            }
        }

        let tone_offset = self.get_tone_position(vs, v_end == self.current);
        let tone_pos = v_end - (info.len as i32 - 1) + tone_offset;
        if self.b(tone_pos).tone() == 0 && ev.tone == 0 {
            return self.process_append(ev);
        }

        if self.b(tone_pos).tone() == ev.tone {
            self.mark_change(tone_pos);
            self.bm(tone_pos).set_tone(0);
            self.single_mode = false;
            let _ = self.process_append(ev);
            self.reverted = true;
            return 1;
        }

        self.mark_change(tone_pos);
        self.bm(tone_pos).set_tone(ev.tone);
        1
    }

    fn process_dd(&mut self, ev: &mut KeyEvent) -> i32 {
        if !self.viet_key || self.current < 0 {
            return self.process_append(ev);
        }

        // dd is allowed even outside a Vietnamese sequence because it is
        // common in abbreviations, but only when the preceding character
        // is not a vowel.
        //
        // The original reads m_buffer[m_current - 1] without checking
        // m_current > 0. The guard below is added: reaching it requires a
        // nonVn 'd' at index 0, which the classifier makes unreachable
        // ('d' is always ukcVn). The differential harness confirms it.
        if self.cur().form() == VNW_NON_VN
            && self.cur().vn_sym == L::d
            && (self.current == 0
                || self.b(self.current - 1).vn_sym.is_non_vn()
                || !is_vowel(self.b(self.current - 1).vn_sym))
        {
            self.single_mode = true;
            let pos = self.current;
            self.mark_change(pos);
            let e = self.bm(pos);
            e.seq = L::cs_dd.0;
            e.vn_sym = L::dd;
            e.set_form(VNW_C);
            e.set_c1_offset(0);
            e.set_c2_offset(-1);
            e.set_v_offset(-1);
            return 1;
        }

        if self.cur().c1_offset() < 0 {
            return self.process_append(ev);
        }

        let pos = self.current - self.cur().c1_offset();
        if !self.options.free_marking && pos != self.current {
            return self.process_append(ev);
        }

        if self.b(pos).cseq() == L::cs_d {
            self.mark_change(pos);
            let e = self.bm(pos);
            e.seq = L::cs_dd.0;
            e.vn_sym = L::dd;
            // Never spell check a word starting with dd: abbreviations.
            self.single_mode = true;
            return 1;
        }

        if self.b(pos).cseq() == L::cs_dd {
            self.mark_change(pos);
            let e = self.bm(pos);
            e.seq = L::cs_d.0;
            e.vn_sym = L::d;
            self.single_mode = false;
            let _ = self.process_append(ev);
            self.reverted = true;
            return 1;
        }

        self.process_append(ev)
    }

    fn process_map_char(&mut self, ev: &mut KeyEvent) -> i32 {
        if self.caps_lock_on && !(ev.key_code < 128 && (ev.key_code as u8 as char).is_alphabetic())
        {
            ev.vn_sym = ev.vn_sym.change_case();
        }

        let mut ret = self.process_append(ev);
        if !self.viet_key {
            return ret;
        }

        if self.current >= 0 && self.cur().form() != VNW_EMPTY && self.cur().form() != VNW_NON_VN {
            return 1;
        }

        if self.current < 0 {
            return 0;
        }

        // mapChar does not apply
        self.current -= 1;
        let entry = self.cur();

        let mut undo = false;
        if entry.form() != VNW_EMPTY && entry.form() != VNW_NON_VN {
            let mut prev_sym = entry.vn_sym;
            if entry.caps() {
                prev_sym = Lexi(prev_sym.0 - 1);
            }
            if prev_sym == ev.vn_sym {
                if entry.form() != VNW_C {
                    let v_end = self.current - entry.v_offset();
                    let vs = self.b(v_end).vseq();
                    let v_start = v_end - VSEQ[vs.idx()].len as i32 + 1;
                    let cur_tone_pos = v_start + self.get_tone_position(vs, v_end == self.current);
                    let tone = self.b(cur_tone_pos).tone();
                    self.mark_change(self.current);
                    self.current -= 1;

                    if tone != 0
                        && self.current >= 0
                        && (self.cur().form() == VNW_V || self.cur().form() == VNW_CV)
                    {
                        let new_vs = self.cur().vseq();
                        let new_tone_pos = v_start + self.get_tone_position(new_vs, true);
                        if new_tone_pos != cur_tone_pos {
                            self.mark_change(new_tone_pos);
                            self.bm(new_tone_pos).set_tone(tone);
                            self.mark_change(cur_tone_pos);
                            self.bm(cur_tone_pos).set_tone(0);
                        }
                    }
                } else {
                    self.mark_change(self.current);
                    self.current -= 1;
                }
                undo = true;
            }
        }

        ev.ev_type = input::NORMAL;
        ev.ch_type = self.char_type(ev.key_code);
        ev.vn_sym = input::iso_to_lexi(ev.key_code);
        ret = self.process_append(ev);
        if undo {
            self.single_mode = false;
            self.reverted = true;
            return 1;
        }
        ret
    }

    fn process_telex_w(&mut self, ev: &mut KeyEvent) -> i32 {
        if !self.viet_key {
            return self.process_append(ev);
        }

        let upper = ev.key_code < 128 && (ev.key_code as u8 as char).is_ascii_uppercase();

        if self.used_as_map_char {
            ev.ev_type = input::MAP_CHAR;
            ev.vn_sym = if upper { L::Uh } else { L::uh };
            ev.ch_type = input::UKC_VN;
            let ret = self.process_map_char(ev);
            if ret == 0 {
                if self.current >= 0 {
                    self.current -= 1;
                }
                self.used_as_map_char = false;
                ev.ev_type = input::HOOK_ALL;
                return self.process_hook(ev);
            }
            return ret;
        }

        ev.ev_type = input::HOOK_ALL;
        self.used_as_map_char = false;
        let ret = self.process_hook(ev);
        if ret == 0 {
            if self.current >= 0 {
                self.current -= 1;
            }
            ev.ev_type = input::MAP_CHAR;
            ev.vn_sym = if upper { L::Uh } else { L::uh };
            ev.ch_type = input::UKC_VN;
            self.used_as_map_char = true;
            return self.process_map_char(ev);
        }
        ret
    }

    fn check_escape_viqr(&mut self, ev: &KeyEvent) -> i32 {
        if self.current < 0 {
            return 0;
        }
        let entry = self.cur();
        let mut escape = false;
        if entry.form() == VNW_V || entry.form() == VNW_CV {
            escape = match ev.key_code as u8 {
                b'^' => entry.vn_sym == L::a || entry.vn_sym == L::o || entry.vn_sym == L::e,
                b'(' => entry.vn_sym == L::a,
                b'+' => entry.vn_sym == L::o || entry.vn_sym == L::u,
                b'\'' | b'`' | b'?' | b'~' | b'.' => entry.tone() == 0,
                _ => false,
            };
        } else if entry.form() == VNW_NON_VN {
            let ch = (entry.key_code as u8 as char).to_ascii_uppercase();
            escape = match ev.key_code as u8 {
                b'^' => ch == 'A' || ch == 'O' || ch == 'E',
                b'(' => ch == 'A',
                b'+' => ch == 'O' || ch == 'U',
                b'\'' | b'`' | b'?' | b'~' | b'.' => {
                    ch == 'A' || ch == 'E' || ch == 'I' || ch == 'O' || ch == 'U' || ch == 'Y'
                }
                _ => false,
            };
        }

        if escape {
            let word_break = ev.ch_type == input::UKC_WORD_BREAK;
            for k in 0..2 {
                self.current += 1;
                let p = self.bm(self.current);
                p.set_form(if word_break { VNW_EMPTY } else { VNW_NON_VN });
                p.set_c1_offset(-1);
                p.set_c2_offset(-1);
                p.set_v_offset(-1);
                p.key_code = if k == 0 { b'?' as u32 } else { ev.key_code };
                p.vn_sym = Lexi::NON_VN;
            }
            // The original writes straight into the caller's buffer at
            // positions 0 and 1 and assigns the reported size, without
            // touching any cursor the restore loop may be holding. That
            // matters: the restore loop feeds key strokes back through
            // processAppend, so it can re-enter this function and clobber
            // its first two bytes while its own count keeps running.
            self.out.write_at(0, b'\\');
            self.out.write_at(1, ev.key_code as u8);
            self.out_size = 2;
            self.out_written = true;
            return 1;
        }
        0
    }

    fn process_append(&mut self, ev: &mut KeyEvent) -> i32 {
        match ev.ch_type {
            input::UKC_RESET => {
                // The original also matches macros on ENTER, but only
                // under #if defined(_WIN32). The POSIX build does not,
                // and neither does this port.
                self.reset();
                0
            }
            input::UKC_WORD_BREAK => {
                self.single_mode = false;
                self.process_word_end(ev)
            }
            input::UKC_NON_VN => {
                if self.viet_key
                    && self.charset.0 == charset::VIQR
                    && self.check_escape_viqr(ev) != 0
                {
                    return 1;
                }

                self.current += 1;
                let lower = ev.vn_sym.to_lower();
                let e = self.bm(self.current);
                e.set_form(VNW_NON_VN);
                e.set_c1_offset(-1);
                e.set_c2_offset(-1);
                e.set_v_offset(-1);
                e.key_code = ev.key_code;
                e.vn_sym = lower;
                e.set_tone(0);
                e.set_caps(lower != ev.vn_sym);
                if !self.viet_key || !self.charset.is_unicode_cstring() {
                    return 0;
                }
                self.mark_change(self.current);
                1
            }
            _ => {
                // UKC_VN
                if is_vowel(ev.vn_sym) {
                    let v = std_no_tone(ev.vn_sym.to_lower());
                    if self.current >= 0
                        && self.cur().form() == VNW_C
                        && ((self.cur().cseq() == L::cs_q && v == L::u)
                            || (self.cur().cseq() == L::cs_g && v == L::i))
                    {
                        // u after q and i after g behave as consonants
                        return self.append_consonnant(ev);
                    }
                    return self.append_vowel(ev);
                }
                self.append_consonnant(ev)
            }
        }
    }
}

// -------------------------------------------------------- append paths

impl Engine {
    fn append_vowel(&mut self, ev: &mut KeyEvent) -> i32 {
        let auto_completed = false;

        self.current += 1;
        let lower_sym = ev.vn_sym.to_lower();
        let can_sym = std_no_tone(lower_sym);

        {
            let e = self.bm(self.current);
            e.vn_sym = can_sym;
            e.set_caps(lower_sym != ev.vn_sym);
            e.set_tone(((lower_sym.0 - can_sym.0) / 2) as i32);
            e.key_code = ev.key_code;
        }

        let key_is_alpha = ev.key_code < 128 && (ev.key_code as u8 as char).is_ascii_alphabetic();

        if self.current == 0 || !self.viet_key {
            let vseq = vseq1(can_sym);
            let e = self.bm(self.current);
            e.set_form(VNW_V);
            e.set_c1_offset(-1);
            e.set_c2_offset(-1);
            e.set_v_offset(0);
            e.set_vseq(vseq);

            if !self.viet_key || (!self.charset.is_unicode_cstring() && key_is_alpha) {
                return 0;
            }
            self.mark_change(self.current);
            return 1;
        }

        let prev = self.b(self.current - 1);

        match prev.form() {
            VNW_EMPTY => {
                let new_vs = vseq1(can_sym);
                let e = self.bm(self.current);
                e.set_form(VNW_V);
                e.set_c1_offset(-1);
                e.set_c2_offset(-1);
                e.set_v_offset(0);
                e.set_vseq(new_vs);
            }
            VNW_NON_VN | VNW_CVC | VNW_VC => {
                let e = self.bm(self.current);
                e.set_form(VNW_NON_VN);
                e.set_c1_offset(-1);
                e.set_c2_offset(-1);
                e.set_v_offset(-1);
            }
            VNW_V | VNW_CV => {
                let vs = prev.vseq();
                let prev_tone_pos = (self.current - 1) - (VSEQ[vs.idx()].len as i32 - 1)
                    + self.get_tone_position(vs, true);
                let mut tone = self.b(prev_tone_pos).tone();

                let mut new_vs = if lower_sym != can_sym && tone != 0 {
                    // The new symbol carries a tone but one is already set
                    VSeq::NIL
                } else {
                    // Extending a sequence by one vowel is a table
                    // lookup, and a length three sequence extends to nil.
                    vseq_extend(vs, can_sym)
                };

                if !new_vs.is_nil() && prev.form() == VNW_CV {
                    let cs = self.b(self.current - 1 - prev.c1_offset()).cseq();
                    if !is_valid_cv(cs, new_vs) {
                        new_vs = VSeq::NIL;
                    }
                }

                if new_vs.is_nil() {
                    let e = self.bm(self.current);
                    e.set_form(VNW_NON_VN);
                    e.set_c1_offset(-1);
                    e.set_c2_offset(-1);
                    e.set_v_offset(-1);
                } else {
                    {
                        let e = self.bm(self.current);
                        e.set_form(prev.form());
                        e.set_c1_offset(if prev.form() == VNW_CV {
                            prev.c1_offset() + 1
                        } else {
                            -1
                        });
                        e.set_c2_offset(-1);
                        e.set_v_offset(0);
                        e.set_vseq(new_vs);
                        e.set_tone(0);
                    }

                    let new_tone = ((lower_sym.0 - can_sym.0) / 2) as i32;
                    if tone == 0 {
                        if new_tone != 0 {
                            tone = new_tone;
                            let tone_pos = self.get_tone_position(new_vs, true)
                                + ((self.current - 1) - VSEQ[vs.idx()].len as i32 + 1);
                            self.mark_change(tone_pos);
                            self.bm(tone_pos).set_tone(tone);
                            return 1;
                        }
                    } else {
                        let new_tone_pos = self.get_tone_position(new_vs, true)
                            + ((self.current - 1) - VSEQ[vs.idx()].len as i32 + 1);
                        if new_tone_pos != prev_tone_pos {
                            self.mark_change(prev_tone_pos);
                            self.bm(prev_tone_pos).set_tone(0);
                            self.mark_change(new_tone_pos);
                            if new_tone != 0 {
                                tone = new_tone;
                            }
                            self.bm(new_tone_pos).set_tone(tone);
                            return 1;
                        }
                        if new_tone != 0 && new_tone != tone {
                            tone = new_tone;
                            self.mark_change(prev_tone_pos);
                            self.bm(prev_tone_pos).set_tone(tone);
                            return 1;
                        }
                    }
                }
            }
            VNW_C => {
                let new_vs = vseq1(can_sym);
                let cs = prev.cseq();
                if !is_valid_cv(cs, new_vs) {
                    let e = self.bm(self.current);
                    e.set_form(VNW_NON_VN);
                    e.set_c1_offset(-1);
                    e.set_c2_offset(-1);
                    e.set_v_offset(-1);
                } else {
                    {
                        let e = self.bm(self.current);
                        e.set_form(VNW_CV);
                        e.set_c1_offset(1);
                        e.set_c2_offset(-1);
                        e.set_v_offset(0);
                        e.set_vseq(new_vs);
                    }

                    if cs == L::cs_gi && prev.tone() != 0 {
                        if self.cur().tone() == 0 {
                            let t = prev.tone();
                            self.bm(self.current).set_tone(t);
                        }
                        self.mark_change(self.current - 1);
                        let p = self.current - 1;
                        self.bm(p).set_tone(0);
                        return 1;
                    }
                }
            }
            _ => {}
        }

        if !auto_completed && !self.charset.is_unicode_cstring() && key_is_alpha {
            return 0;
        }

        self.mark_change(self.current);
        1
    }

    fn append_consonnant(&mut self, ev: &mut KeyEvent) -> i32 {
        let mut complex_event = false;
        self.current += 1;
        let lower_sym = ev.vn_sym.to_lower();

        {
            let e = self.bm(self.current);
            e.vn_sym = lower_sym;
            e.set_caps(lower_sym != ev.vn_sym);
            e.key_code = ev.key_code;
            e.set_tone(0);
        }

        if self.current == 0 || !self.viet_key {
            let cseq = cseq1(lower_sym);
            let e = self.bm(self.current);
            e.set_form(VNW_C);
            e.set_c1_offset(0);
            e.set_c2_offset(-1);
            e.set_v_offset(-1);
            e.set_cseq(cseq);
            if !self.viet_key || !self.charset.is_unicode_cstring() {
                return 0;
            }
            self.mark_change(self.current);
            return 1;
        }

        let prev = self.b(self.current - 1);

        match prev.form() {
            VNW_NON_VN => {
                let e = self.bm(self.current);
                e.set_form(VNW_NON_VN);
                e.set_c1_offset(-1);
                e.set_c2_offset(-1);
                e.set_v_offset(-1);
                if !self.charset.is_unicode_cstring() {
                    return 0;
                }
                self.mark_change(self.current);
                1
            }
            VNW_EMPTY => {
                let cseq = cseq1(lower_sym);
                let e = self.bm(self.current);
                e.set_form(VNW_C);
                e.set_c1_offset(0);
                e.set_c2_offset(-1);
                e.set_v_offset(-1);
                e.set_cseq(cseq);
                if !self.charset.is_unicode_cstring() {
                    return 0;
                }
                self.mark_change(self.current);
                1
            }
            VNW_V | VNW_CV => {
                let vs = prev.vseq();
                let mut new_vs = vs;
                if vs == L::vs_uoh || vs == L::vs_uho {
                    new_vs = L::vs_uhoh;
                }

                let mut c1 = CSeq::NIL;
                if prev.c1_offset() != -1 {
                    c1 = self.b(self.current - 1 - prev.c1_offset()).cseq();
                }

                let new_cs = cseq1(lower_sym);
                let is_valid = is_valid_cvc(c1, new_vs, new_cs);

                if is_valid {
                    // u+o -> u+o+
                    if vs == L::vs_uho {
                        self.mark_change(self.current - 1);
                        let p = self.current - 1;
                        let e = self.bm(p);
                        e.vn_sym = L::oh;
                        e.set_vseq(L::vs_uhoh);
                        complex_event = true;
                    } else if vs == L::vs_uoh {
                        self.mark_change(self.current - 2);
                        let p2 = self.current - 2;
                        let e = self.bm(p2);
                        e.vn_sym = L::uh;
                        e.set_vseq(L::vs_uh);
                        let p1 = self.current - 1;
                        self.bm(p1).set_vseq(L::vs_uhoh);
                        complex_event = true;
                    }

                    {
                        let e = self.bm(self.current);
                        if prev.form() == VNW_V {
                            e.set_form(VNW_VC);
                            e.set_c1_offset(-1);
                            e.set_c2_offset(0);
                            e.set_v_offset(1);
                        } else {
                            e.set_form(VNW_CVC);
                            e.set_c1_offset(prev.c1_offset() + 1);
                            e.set_c2_offset(0);
                            e.set_v_offset(1);
                        }
                        e.set_cseq(new_cs);
                    }

                    // reposition the tone if needed
                    let old_idx = (self.current - 1) - (VSEQ[vs.idx()].len as i32 - 1)
                        + self.get_tone_position(vs, true);
                    if self.b(old_idx).tone() != 0 {
                        let new_idx = (self.current - 1) - (VSEQ[new_vs.idx()].len as i32 - 1)
                            + self.get_tone_position(new_vs, false);
                        if new_idx != old_idx {
                            self.mark_change(new_idx);
                            let t = self.b(old_idx).tone();
                            self.bm(new_idx).set_tone(t);
                            self.mark_change(old_idx);
                            self.bm(old_idx).set_tone(0);
                            return 1;
                        }
                    }
                } else {
                    let e = self.bm(self.current);
                    e.set_form(VNW_NON_VN);
                    e.set_c1_offset(-1);
                    e.set_c2_offset(-1);
                    e.set_v_offset(-1);
                }

                if complex_event {
                    return 1;
                }
                if !self.charset.is_unicode_cstring() {
                    return 0;
                }
                self.mark_change(self.current);
                1
            }
            VNW_C | VNW_VC | VNW_CVC => {
                let cs = prev.cseq();
                // The original indexes CSeqList[cs] without checking for
                // cs_nil, so `cs == -1` is an out of bounds read one
                // element before the table. It is reachable: any of
                // a e f i j o u w y z can be stored with form vnw_c and
                // a nil sequence by processNoSpellCheck, and the next
                // consonant lands here. The garbage it reads has never
                // produced a valid extension, so the intended meaning is
                // "no sequence, nothing to extend". Encoded explicitly.
                let mut new_cs = cseq_extend(cs, lower_sym);

                if !new_cs.is_nil() && (prev.form() == VNW_VC || prev.form() == VNW_CVC) {
                    let mut c1 = CSeq::NIL;
                    if prev.c1_offset() != -1 {
                        c1 = self.b(self.current - 1 - prev.c1_offset()).cseq();
                    }
                    let v_idx = (self.current - 1) - prev.v_offset();
                    let vs = self.b(v_idx).vseq();
                    if !is_valid_cvc(c1, vs, new_cs) {
                        new_cs = CSeq::NIL;
                    }
                }

                if new_cs.is_nil() {
                    let e = self.bm(self.current);
                    e.set_form(VNW_NON_VN);
                    e.set_c1_offset(-1);
                    e.set_c2_offset(-1);
                    e.set_v_offset(-1);
                } else {
                    let e = self.bm(self.current);
                    if prev.form() == VNW_C {
                        e.set_form(VNW_C);
                        e.set_c1_offset(0);
                        e.set_c2_offset(-1);
                        e.set_v_offset(-1);
                    } else if prev.form() == VNW_VC {
                        e.set_form(VNW_VC);
                        e.set_c1_offset(-1);
                        e.set_c2_offset(0);
                        e.set_v_offset(prev.v_offset() + 1);
                    } else {
                        e.set_form(VNW_CVC);
                        e.set_c1_offset(prev.c1_offset() + 1);
                        e.set_c2_offset(0);
                        e.set_v_offset(prev.v_offset() + 1);
                    }
                    e.set_cseq(new_cs);
                }
                if !self.charset.is_unicode_cstring() {
                    return 0;
                }
                self.mark_change(self.current);
                1
            }
            _ => {
                if !self.charset.is_unicode_cstring() {
                    return 0;
                }
                self.mark_change(self.current);
                1
            }
        }
    }

    fn process_esc_char(&mut self, ev: &mut KeyEvent) -> i32 {
        if self.viet_key
            && self.current >= 0
            && self.cur().form() != VNW_EMPTY
            && self.cur().form() != VNW_NON_VN
        {
            self.to_escape = true;
        }
        self.process_append(ev)
    }

    /// Pass a key through without filtering.
    pub fn pass(&mut self, key_code: u32) {
        let mut ev = self.input.key_code_to_event(key_code);
        let _ = self.process_append(&mut ev);
    }

    /// Only valid after other processing has run: the new event is
    /// already in the buffer.
    fn process_no_spell_check(&mut self, ev: &KeyEvent) -> i32 {
        let sym = self.cur().vn_sym;
        if is_vowel(sym) {
            let vseq = vseq1(sym);
            let e = self.bm(self.current);
            e.set_form(VNW_V);
            e.set_v_offset(0);
            e.set_vseq(vseq);
            e.set_c1_offset(-1);
            e.set_c2_offset(-1);
        } else {
            let cseq = cseq1(sym);
            let e = self.bm(self.current);
            e.set_form(VNW_C);
            e.set_c1_offset(0);
            e.set_c2_offset(-1);
            e.set_v_offset(-1);
            e.set_cseq(cseq);
        }

        let k = self.cur().key_code;
        if ev.ev_type == input::NORMAL
            && ((k >= b'a' as u32 && k <= b'z' as u32) || (k >= b'A' as u32 && k <= b'Z' as u32))
        {
            return 0;
        }
        self.mark_change(self.current);
        1
    }

    #[cfg(feature = "alloc")]
    /// StdVnChar of a buffer entry as `macroMatch` builds it. Note this
    /// differs from `writeOutput`: a non Vietnamese entry contributes its
    /// raw key code, not the IsoStdVnCharMap translation.
    fn macro_std_char(&self, i: i32) -> u32 {
        let e = self.b(i);
        if !e.vn_sym.is_non_vn() {
            let mut c = e.vn_sym.0 as u32 + VN_STD_CHAR_OFFSET;
            if e.caps() {
                c -= 1;
            }
            c += (e.tone() as u32) * 2;
            c
        } else {
            e.key_code
        }
    }

    /// Without an allocator there is no macro table, so nothing matches.
    #[cfg(not(feature = "alloc"))]
    fn macro_match(&mut self, _ev: &KeyEvent) -> i32 {
        0
    }

    /// `macroMatch`: walk backwards over the current word building
    /// candidate keys, longest suffix first, and expand the first hit.
    #[cfg(feature = "alloc")]
    fn macro_match(&mut self, ev: &KeyEvent) -> i32 {
        const ENTER_CHAR: u32 = 13;
        if self.shift_pressed && (ev.key_code == b' ' as u32 || ev.key_code == ENTER_CHAR) {
            return 0;
        }

        let mut key = [0u32; MAX_MACRO_KEY_LEN + 1];
        // The matched text is copied straight into this buffer at lookup
        // time. Borrowing the table's slice instead would keep `self`
        // borrowed across the mark_change and output calls below, and
        // cloning into a Vec would put an allocation on the word end
        // path. A stack copy avoids both.
        let mut text = [0u32; MAX_MACRO_TEXT_LEN + 1];
        let mut text_len = 0usize;
        let mut found = false;
        let mut i = self.current;
        let mut key_start = 0usize;
        let mut key_len = 0usize;

        while i >= 0 && (self.current - i + 1) < MAX_MACRO_KEY_LEN as i32 {
            while i >= 0
                && self.b(i).form() != VNW_EMPTY
                && (self.current - i + 1) < MAX_MACRO_KEY_LEN as i32
            {
                i -= 1;
            }
            if i >= 0 && self.b(i).form() != VNW_EMPTY {
                return 0;
            }
            if i >= 0 {
                key[0] = self.macro_std_char(i);
            }
            let mut j = i + 1;
            while j <= self.current {
                key[(j - i) as usize] = self.macro_std_char(j);
                j += 1;
            }
            let n = (self.current - i + 1) as usize;

            if let Some(t) = self.macro_store.lookup(&key[1..n]) {
                text_len = core::cmp::min(t.len(), MAX_MACRO_TEXT_LEN);
                text[..text_len].copy_from_slice(&t[..text_len]);
                found = true;
                key_start = 1;
                key_len = n - 1;
                i += 1; // mark where the change begins
                break;
            }
            if i >= 0 {
                if let Some(t) = self.macro_store.lookup(&key[0..n]) {
                    text_len = core::cmp::min(t.len(), MAX_MACRO_TEXT_LEN);
                    text[..text_len].copy_from_slice(&t[..text_len]);
                    found = true;
                    key_start = 0;
                    key_len = n;
                    break;
                }
            }
            i -= 1;
        }

        if !found {
            return 0;
        }

        self.mark_change(i);

        // ALL CAPITALS, First Character Capital, or leave alone.
        let is_lower = |x: u32| {
            x >= VN_STD_CHAR_OFFSET
                && x < VN_STD_CHAR_OFFSET + tables::TOTAL_ALPHA_VNCHARS as u32
                && x & 1 == 1
        };
        let is_upper = |x: u32| {
            x >= VN_STD_CHAR_OFFSET
                && x < VN_STD_CHAR_OFFSET + tables::TOTAL_ALPHA_VNCHARS as u32
                && x & 1 == 0
        };
        let ks = &key[key_start..key_start + key_len];
        let case = if is_lower(ks[0]) {
            VnCase::AllSmall
        } else if is_upper(ks[0]) {
            let mut c = VnCase::AllCapital;
            for &x in &ks[1..] {
                if is_lower(x) {
                    c = VnCase::NoChange;
                }
            }
            c
        } else {
            VnCase::NoChange
        };

        let char_count = text_len;
        if case != VnCase::NoChange {
            for k in 0..char_count {
                text[k] = match case {
                    VnCase::AllCapital => charset::std_to_upper(text[k]),
                    VnCase::AllSmall => charset::std_to_lower(text[k]),
                    VnCase::NoChange => text[k],
                };
            }
        }

        // Convert to the target charset, then append the key that
        // triggered the expansion. Each conversion is its own output
        // pass, so a stateful charset restarts, exactly as VnConvert does.
        let cap = self.out_size;
        let mut written = {
            let mut enc = charset::Encoder::new(self.charset);
            let mut sink = At::new(&mut self.out, 0, cap);
            for k in 0..char_count {
                enc.put_into(&mut sink, text[k]);
            }
            sink.count()
        };

        if written < self.out_size {
            let vn_char = if !ev.vn_sym.is_non_vn() {
                ev.vn_sym.0 as u32 + VN_STD_CHAR_OFFSET
            } else {
                ev.key_code
            };
            let room = self.out_size - written;
            let mut enc = charset::Encoder::new(self.charset);
            let mut sink = At::new(&mut self.out, written, room);
            enc.put_into(&mut sink, vn_char);
            written += sink.count();
        }

        let backs = self.backs;
        self.reset();
        self.out_written = true;
        self.backs = backs;
        self.out_size = written;
        1
    }
}

// --------------------------------------------------------- entry points

impl Engine {
    /// Auto capitalisation. Rewrites the event before dispatch, so the
    /// engine sees exactly what it would have seen had shift been held.
    ///
    /// Returns true when it actually changed the letter, because the caller
    /// then has to force the character out: an alphabetic key makes the
    /// append return zero, which tells the front end to let through the key
    /// it received, and that is the lower case one the user pressed.
    fn apply_upper_case_first_char(&mut self, ev: &mut KeyEvent) -> bool {
        if !self.options.upper_case_first_char {
            return false;
        }
        if ev.ch_type == input::UKC_RESET {
            // Enter and the other control characters start a sentence.
            self.capitalise_next = true;
            return false;
        }
        let sentence_end = ev.key_code < 128 && matches!(ev.key_code as u8, b'.' | b'!' | b'?');
        if sentence_end && ev.ev_type == input::NORMAL {
            // A sentence ends here. The `ev_type` guard is load bearing, and
            // it has to be `ev_type` rather than `ch_type`: `ch_type` comes
            // from a fixed per character table, so `.` is a word break in
            // every method, while `ev_type` is where the active method has
            // its say. In VIQR `.` is nang and `?` is hoi, so they arrive as
            // tones and the word eats them. A key the engine ate is not
            // punctuation the typist wrote, and arming on it would turn
            // `ta. bo` into `Tạ Bo`.
            self.capitalise_next = true;
            return false;
        }
        if ev.ch_type == input::UKC_WORD_BREAK {
            // A space neither arms nor disarms, so `mot. hai` capitalises
            // `hai` while `mot hai` does not.
            return false;
        }
        if !self.capitalise_next {
            return false;
        }
        if ev.ch_type != input::UKC_VN || ev.vn_sym.is_non_vn() {
            // A digit or a bracket ends the wait without consuming it,
            // which is what a typist expects.
            self.capitalise_next = false;
            return false;
        }
        self.capitalise_next = false;
        // `to_lower` forces the parity bit odd, so the upper case form is
        // one below it. See `lexi.rs` for why that arithmetic is load
        // bearing and asserted at compile time.
        let lower = ev.vn_sym.to_lower();
        let was = ev.vn_sym;
        ev.vn_sym = Lexi(lower.0 - 1);
        if ev.key_code < 128 {
            ev.key_code = (ev.key_code as u8).to_ascii_uppercase() as u32;
        }
        ev.vn_sym != was
    }

    /// Quick telex: a doubled consonant becomes its pair, so `cc` gives
    /// `ch`. A doubled consonant is never valid Vietnamese, so nothing is
    /// taken away.
    ///
    /// Fires only when the previous entry is a single letter consonant at
    /// the start of a word carrying the same letter, which keeps it away
    /// from a doubled letter that spans a syllable boundary.
    ///
    /// The substitution cannot just rewrite the event and let dispatch
    /// run. `appendConsonnant` returns zero for an alphabetic key, which
    /// tells the front end to let the key it actually received through,
    /// and that key is the one the user typed rather than the replacement.
    /// So this appends the replacement itself and marks it for output:
    /// `change_pos` already sits on the new entry, so the front end gets
    /// no backspaces and the one character that should appear.
    fn apply_quick_telex(&mut self, ev: &mut KeyEvent) -> Option<i32> {
        if !self.options.quick_telex || self.current < 0 {
            return None;
        }
        if ev.ev_type != input::NORMAL || ev.ch_type != input::UKC_VN {
            return None;
        }
        // `uu` for u horn plus o horn. The one shortcut that rewrites a
        // vowel sequence rather than substituting a letter: two buffer
        // entries change, symbols and sub sequence markers both, so it
        // does its own work and reports the key as finished.
        if ev.key_code < 128 && (ev.key_code as u8).to_ascii_lowercase() == b'u' {
            let prev = self.cur();
            let vowel_form = prev.form() == VNW_V || prev.form() == VNW_CV;
            if vowel_form && prev.vseq() == L::vs_u && prev.vn_sym == L::u {
                let at = self.current;
                self.mark_change(at);
                {
                    let e = self.bm(at);
                    e.vn_sym = L::uh;
                    e.set_vseq(L::vs_uh);
                }
                // Append the partner as a plain o, then give it the horn.
                let upper = (ev.key_code as u8).is_ascii_uppercase();
                let code = if upper { b'O' as u32 } else { b'o' as u32 };
                let mut sub = self.input.key_code_to_event(code);
                sub.ev_type = input::NORMAL;
                sub.ch_type = input::UKC_VN;
                sub.vn_sym = input::iso_to_lexi(code);
                let _ = self.process_append(&mut sub);
                let last = self.current;
                {
                    let e = self.bm(last);
                    e.vn_sym = L::oh;
                    e.set_vseq(L::vs_uhoh);
                }
                self.mark_change(last);
                return Some(1);
            }
        }

        let prev = self.cur();
        if prev.form() != VNW_C || prev.c1_offset() != 0 {
            return None;
        }
        if prev.key_code > 127 || ev.key_code > 127 {
            return None;
        }
        let typed = ev.key_code as u8;
        if typed.to_ascii_lowercase() != (prev.key_code as u8).to_ascii_lowercase() {
            return None;
        }
        let second = crate::quick::doubled(typed)?;
        // The replacement keeps the case of the letter that was typed, so
        // `CC` gives `CH` and `Cc` gives `Ch`.
        let replacement = if typed.is_ascii_uppercase() {
            second.to_ascii_uppercase()
        } else {
            second
        };
        ev.key_code = replacement as u32;
        ev.vn_sym = input::iso_to_lexi(ev.key_code);
        let _ = self.process_append(ev);
        self.mark_change(self.current);
        Some(1)
    }

    fn dispatch(&mut self, ev: &mut KeyEvent) -> i32 {
        let capitalised = self.apply_upper_case_first_char(ev);
        if let Some(r) = self.apply_quick_telex(ev) {
            return r;
        }
        if capitalised {
            let r = self.dispatch_inner(ev);
            // Force the capital out. `change_pos` sits on the new entry
            // when nothing else moved, so this costs no backspaces.
            if r == 0 && self.current >= 0 {
                self.mark_change(self.current);
                return 1;
            }
            return r;
        }
        self.dispatch_inner(ev)
    }

    fn dispatch_inner(&mut self, ev: &mut KeyEvent) -> i32 {
        // A fast path testing for vneNormal before this match was tried
        // and measured consistently slower: the jump table LLVM builds
        // here is already cheaper than an extra compare on every event.
        match ev.ev_type {
            input::ROOF_ALL | input::ROOF_A | input::ROOF_E | input::ROOF_O => {
                self.process_roof(ev)
            }
            input::HOOK_ALL | input::HOOK_UO | input::HOOK_U | input::HOOK_O | input::BOWL => {
                self.process_hook(ev)
            }
            input::DD => self.process_dd(ev),
            input::TONE0 | input::TONE1 | input::TONE2 | input::TONE3 | input::TONE4
            | input::TONE5 => self.process_tone(ev),
            input::TELEX_W => self.process_telex_w(ev),
            input::MAP_CHAR => self.process_map_char(ev),
            input::ESC_CHAR => self.process_esc_char(ev),
            _ => self.process_append(ev),
        }
    }

    /// Main handler: feed one character key code.
    pub fn key(&mut self, key_code: u32) -> Edit {
        self.prepare_buffer();
        self.backs = 0;
        self.change_pos = self.current + 1;
        self.out.reset();
        self.out_size = crate::out::OUT_CAPACITY;
        self.out_written = false;
        self.reverted = false;
        self.key_restored = false;
        self.key_restoring = false;
        self.out_type = OutputType::Char;

        let mut ev = self.input.key_code_to_event(key_code);
        if self.options.allow_consonant_zfwj {
            ev.ch_type = self.char_type(key_code);
        }

        let mut ret = if !self.to_escape {
            self.dispatch(&mut ev)
        } else {
            self.to_escape = false;
            if self.current < 0 || ev.ev_type == input::NORMAL || ev.ev_type == input::ESC_CHAR {
                self.process_append(&mut ev)
            } else {
                self.current -= 1;
                let _ = self.process_append(&mut ev);
                // Marks the character for output and sets backs to 1.
                self.mark_change(self.current);
                1
            }
        };

        if self.viet_key
            && self.current >= 0
            && self.cur().form() == VNW_NON_VN
            && ev.ch_type == input::UKC_VN
            && (!self.options.spell_check_enabled || self.single_mode)
        {
            // Spell check failed, but we are not spell checking, so the
            // new character starts a new word.
            ret = self.process_no_spell_check(&ev);
        }

        // A key only enters the stroke buffer when it did not reset.
        if self.current >= 0 {
            self.key_current += 1;
            let i = self.key_current as usize;
            self.keys[i] = ev.key_code;
            self.converted[i] = ret != 0 && !self.key_restored;
        }

        if ret == 0 {
            self.out.reset();
            self.out_size = 0;
            return Edit {
                backspaces: 0,
                out_type: self.out_type,
                handled: false,
            };
        }

        if !self.out_written {
            self.write_output();
        }

        Edit {
            backspaces: self.backs,
            out_type: self.out_type,
            handled: true,
        }
    }

    /// Keeps the character buffer and the stroke buffer in step.
    fn synch_key_stroke_buffer(&mut self) {
        if self.key_current >= 0 {
            self.key_current -= 1;
        }
        if self.current >= 0 && self.cur().form() == VNW_EMPTY {
            // The character buffer reached a word break, so the stroke
            // pointer must move back to the matching break.
            while self.key_current >= 0
                && !self.key_is_word_break(self.key_current)
            {
                self.key_current -= 1;
            }
        }
    }

    /// Call when backspace is pressed.
    pub fn backspace(&mut self) -> Edit {
        self.out_type = OutputType::Char;
        self.out.reset();
        self.out_size = 0;
        if !self.viet_key || self.current < 0 {
            return Edit {
                backspaces: 0,
                out_type: OutputType::Char,
                handled: false,
            };
        }

        self.backs = 0;
        self.change_pos = self.current + 1;
        self.mark_change(self.current);

        if self.current == 0
            || self.cur().form() == VNW_EMPTY
            || self.cur().form() == VNW_NON_VN
            || self.cur().form() == VNW_C
            || self.b(self.current - 1).form() == VNW_C
            || self.b(self.current - 1).form() == VNW_CVC
            || self.b(self.current - 1).form() == VNW_VC
        {
            self.current -= 1;
            self.synch_key_stroke_buffer();
            let backs = self.backs;
            return Edit {
                backspaces: backs,
                out_type: OutputType::Char,
                handled: backs > 1,
            };
        }

        let v_end = self.current - self.cur().v_offset();
        let vs = self.b(v_end).vseq();
        let v_start = v_end - VSEQ[vs.idx()].len as i32 + 1;
        let new_vs = self.b(self.current - 1).vseq();
        let cur_tone_pos = v_start + self.get_tone_position(vs, v_end == self.current);

        // The guard above lets form(current - 1) be vnw_nonVn or
        // vnw_empty through, and for those the sequence field carries a
        // stale value from whatever previously occupied the slot. The
        // original then indexes VSeqList with it, so a stale -1 is an out
        // of bounds read whose result depends on the compiler's data
        // layout: there is no well defined behaviour here to preserve.
        // With no vowel sequence to move a tone into, the only coherent
        // answer is to leave the tone where it is and just delete, which
        // is the branch taken below.
        let new_tone_pos = if new_vs.is_nil() {
            cur_tone_pos
        } else {
            v_start + self.get_tone_position(new_vs, true)
        };
        let tone = self.b(cur_tone_pos).tone();

        if tone == 0
            || cur_tone_pos == new_tone_pos
            || (cur_tone_pos == self.current && self.cur().tone() != 0)
        {
            self.current -= 1;
            self.synch_key_stroke_buffer();
            let backs = self.backs;
            return Edit {
                backspaces: backs,
                out_type: OutputType::Char,
                handled: backs > 1,
            };
        }

        self.mark_change(new_tone_pos);
        self.bm(new_tone_pos).set_tone(tone);
        self.mark_change(cur_tone_pos);
        self.bm(cur_tone_pos).set_tone(0);
        self.current -= 1;
        self.synch_key_stroke_buffer();
        let backs = self.backs;
        self.write_output();
        Edit {
            backspaces: backs,
            out_type: OutputType::Char,
            handled: true,
        }
    }

    /// Restore the original key strokes of the last word.
    pub fn restore_key_strokes(&mut self) -> Edit {
        // UnikeyRestoreKeyStrokes sets the size to the full buffer and
        // hands it in, then reads the count back out. Note that the
        // engine's m_pOutSize still points at the previous keystroke's
        // stack slot here, so an escape raised inside the loop assigns to
        // a dead variable in the original; assigning the count last makes
        // that unobservable either way.
        self.out.reset();
        self.out_size = crate::out::OUT_CAPACITY;
        let (handled, backs, _) = self.restore_key_strokes_inner(false, 0, true);
        Edit {
            backspaces: backs,
            out_type: OutputType::Key,
            handled,
        }
    }

    /// `restoreKeyStrokes` takes both `backs` and `outSize` by reference,
    /// and its two callers bind them to different things. That is not a
    /// detail: it changes the output.
    ///
    /// From `processWordEnd`, `backs` is `m_backs` itself, so the bail
    /// outs wipe the engine's accumulated backspace count; and `outSize`
    /// is a local snapshot of `*m_pOutSize`, so the write bound stays put
    /// even when an escape assigns to `*m_pOutSize` mid loop.
    ///
    /// From `UnikeyRestoreKeyStrokes`, `backs` is a separate variable, so
    /// the count survives; and `outSize` is `UnikeyBufChars`, which is
    /// exactly what `m_pOutSize` points at, so the write bound is live
    /// and a VIQR escape raised while restoring shrinks it to 2 and
    /// truncates everything after it.
    ///
    /// `from_word_end` selects between the two.
    fn restore_key_strokes_inner(
        &mut self,
        from_word_end: bool,
        snapshot_cap: usize,
        require_vn_mark: bool,
    ) -> (bool, i32, usize) {
        self.out_type = OutputType::Key;
        if require_vn_mark && !self.last_word_has_vn_mark() {
            if from_word_end {
                self.backs = 0;
            } else {
                self.out_size = 0;
            }
            return (false, 0, 0);
        }

        self.backs = 0;
        self.change_pos = self.current + 1;

        let mut key_start = self.key_current;
        let mut converted = false;
        while key_start >= 0 && !self.key_is_word_break(key_start) {
            if self.converted[key_start as usize] {
                converted = true;
            }
            key_start -= 1;
        }
        key_start += 1;

        if !converted {
            // Nothing was converted, so restoring makes no sense.
            // m_backs was already zeroed just above, in both call paths.
            if !from_word_end {
                self.out_size = 0;
            }
            return (false, 0, 0);
        }

        while self.current >= 0 && self.cur().form() != VNW_EMPTY {
            self.current -= 1;
        }
        self.mark_change(self.current + 1);

        // A local cursor, exactly as the original's `count` is: feeding a
        // stroke back through processAppend can write to the buffer
        // itself (the VIQR escape does), and that must not move this
        // cursor.
        let mut count = 0usize;
        self.key_restoring = true;
        for i in key_start..=self.key_current {
            let code = self.keys[i as usize];
            // Snapshot bound from processWordEnd, live bound from the
            // public entry point. See the doc comment.
            let bound = if from_word_end {
                snapshot_cap
            } else {
                self.out_size
            };
            if count < bound {
                self.out.write_at(count, code as u8);
                count += 1;
            }
            let mut ev = self.input.key_code_to_symbol(code);
            self.converted[i as usize] = false;
            let _ = self.process_append(&mut ev);
        }
        self.key_restoring = false;
        if !from_word_end {
            self.out_size = count;
        }
        (true, self.backs, count)
    }

    /// Quick consonant shortcuts, both ends of the word, decided here at
    /// the break rather than when the key arrived.
    ///
    /// Deferring is not a convenience, it is required in both directions.
    /// For the coda, `g` after `n` is a legitimate ending, so rewriting on
    /// sight would turn `hang` into `hanng`. For the onset, Telex already
    /// uses `f`, `j` and `w` as the huyen key, the nang key and the horn
    /// key, and `w` alone is how you type u horn; reinterpreting them the
    /// moment they arrive would take that away. Only at the break is there
    /// enough information, and OpenKey reaches the same conclusion, which
    /// is why its `checkQuickConsonant` runs on a break code.
    ///
    /// Each candidate substitution is tried on a throwaway engine and
    /// committed only if it rescues a word that was invalid as typed, so a
    /// valid word is never touched and a word that no substitution helps
    /// is left exactly as it was.
    #[cfg(feature = "alloc")]
    fn apply_quick_consonant(&mut self) -> bool {
        if !(self.options.quick_start_consonant || self.options.quick_end_consonant) {
            return false;
        }
        if self.current < 0 || !self.last_word_is_non_vn() {
            return false;
        }

        let mut start = self.key_current;
        while start >= 0 && !self.key_is_word_break(start) {
            start -= 1;
        }
        start += 1;
        if start > self.key_current {
            return false;
        }
        let mut typed: alloc::vec::Vec<u32> = alloc::vec::Vec::new();
        for i in start..=self.key_current {
            typed.push(self.keys[i as usize]);
        }
        if typed.iter().any(|c| *c > 127) {
            return false;
        }

        // Build the candidates: onset only, coda only, then both. The
        // first that produces a valid word wins, which matches the order
        // OpenKey applies them in.
        let onset = if self.options.quick_start_consonant {
            crate::quick::onset(typed[0] as u8)
        } else {
            None
        };
        let coda = if self.options.quick_end_consonant {
            crate::quick::coda(typed[typed.len() - 1] as u8)
        } else {
            None
        };
        if onset.is_none() && coda.is_none() {
            return false;
        }

        let cased = |src: u32, c: u8| -> u32 {
            if (src as u8).is_ascii_uppercase() {
                c.to_ascii_uppercase() as u32
            } else {
                c as u32
            }
        };

        let build = |use_onset: bool, use_coda: bool| -> Option<alloc::vec::Vec<u32>> {
            if use_onset && onset.is_none() {
                return None;
            }
            if use_coda && coda.is_none() {
                return None;
            }
            if !use_onset && !use_coda {
                return None;
            }
            let mut out: alloc::vec::Vec<u32> = alloc::vec::Vec::new();
            let last = typed.len() - 1;
            for (i, c) in typed.iter().enumerate() {
                let at_first = i == 0;
                let at_last = i == last;
                if at_first && use_onset {
                    let (a, b) = onset.unwrap();
                    // Only the first letter carries the case, so `Fanh`
                    // gives `Phanh` rather than `PHanh`.
                    out.push(cased(*c, a));
                    out.push(b as u32);
                    if at_last && use_coda {
                        // A one letter word cannot be both, and the
                        // candidate list never asks for that.
                        return None;
                    }
                    continue;
                }
                if at_last && use_coda {
                    let (a, b) = coda.unwrap();
                    out.push(cased(*c, a));
                    out.push(cased(*c, b));
                    continue;
                }
                out.push(*c);
            }
            Some(out)
        };

        for (use_onset, use_coda) in [(true, false), (false, true), (true, true)] {
            let strokes = match build(use_onset, use_coda) {
                Some(v) => v,
                None => continue,
            };
            if !self.quick_candidate_is_valid(&strokes) {
                continue;
            }
            self.commit_quick_replay(&strokes);
            return true;
        }
        false
    }

    /// Runs a candidate on a throwaway engine and reports whether it
    /// produces a valid Vietnamese word. `Engine` is not `Clone` because
    /// of the macro table, so the trial is a fresh engine carrying the
    /// same configuration with both shortcuts off so it cannot recurse.
    #[cfg(feature = "alloc")]
    fn quick_candidate_is_valid(&self, strokes: &[u32]) -> bool {
        let mut trial = Engine::new();
        trial.viet_key = self.viet_key;
        trial.options = self.options;
        trial.options.quick_start_consonant = false;
        trial.options.quick_end_consonant = false;
        trial.charset = self.charset;
        trial.input = self.input;
        for code in strokes {
            let mut ev = trial.input.key_code_to_event(*code);
            let _ = trial.dispatch(&mut ev);
        }
        !trial.last_word_is_non_vn()
    }

    /// Rewinds over the word, tells the front end how far to back up, then
    /// feeds the candidate in. Same shape as `restore_key_strokes_inner`.
    /// The stroke buffer is left holding what the user actually typed,
    /// which is what a later restore has to give back.
    #[cfg(feature = "alloc")]
    fn commit_quick_replay(&mut self, strokes: &[u32]) {
        let saved_key_current = self.key_current;
        while self.current >= 0 && self.cur().form() != VNW_EMPTY {
            self.current -= 1;
        }
        self.mark_change(self.current + 1);
        self.key_restoring = true;
        for code in strokes {
            let mut ev = self.input.key_code_to_event(*code);
            let _ = self.dispatch(&mut ev);
        }
        self.key_restoring = false;
        self.key_current = saved_key_current;
    }

    /// Macro first, then the quick consonant shortcuts, then spell check
    /// and the key stroke restore.
    fn process_word_end(&mut self, ev: &mut KeyEvent) -> i32 {
        if self.options.macro_enabled && self.macro_match(ev) != 0 {
            return 1;
        }

        // A rewrite has to be reported as handled. Returning zero tells
        // the front end the engine did not consume the key, and `key()`
        // then discards the output, which would throw the rewritten word
        // away.
        #[cfg(feature = "alloc")]
        let rewrote = self.apply_quick_consonant();
        #[cfg(not(feature = "alloc"))]
        let rewrote = false;

        if !self.options.spell_check_enabled
            || self.single_mode
            || self.current < 0
            || self.key_restoring
        {
            self.current += 1;
            let lower = ev.vn_sym.to_lower();
            let e = self.bm(self.current);
            e.set_form(VNW_EMPTY);
            e.set_c1_offset(-1);
            e.set_c2_offset(-1);
            e.set_v_offset(-1);
            e.key_code = ev.key_code;
            e.vn_sym = lower;
            e.set_caps(lower != ev.vn_sym);
            return rewrote as i32;
        }

        let mut restored_count = 0usize;
        let by_english = self.options.swallowed_key_restore && self.last_word_swallowed_a_key();
        let by_phonotactics = self.options.auto_non_vn_restore && self.last_word_is_non_vn();
        if by_english || by_phonotactics {
            let snapshot = self.out_size;
            // This trigger must not require a Vietnamese mark: the whole
            // point is that `pass` became `pas`, which carries no mark at
            // all and yet is not what was typed. Having been converted is
            // the right condition, and the inner function checks it.
            let (ok, _, count) = self.restore_key_strokes_inner(true, snapshot, !by_english);
            if ok {
                self.key_restored = true;
                self.out_written = true;
                restored_count = count;
            }
        }

        self.current += 1;
        let lower = ev.vn_sym.to_lower();
        {
            let e = self.bm(self.current);
            e.set_form(VNW_EMPTY);
            e.set_c1_offset(-1);
            e.set_c2_offset(-1);
            e.set_v_offset(-1);
            e.key_code = ev.key_code;
            e.vn_sym = lower;
            e.set_caps(lower != ev.vn_sym);
        }

        // The bound is re-read here on purpose: a VIQR escape raised
        // while restoring assigns 2 to it, and the original then fails
        // this check and discards the whole output.
        if self.key_restored && restored_count < self.out_size {
            self.out.write_at(restored_count, ev.key_code as u8);
            self.out_size = restored_count + 1;
            return 1;
        }

        rewrote as i32
    }

    /// Is the last word non Vietnamese, so the strokes may be restored?
    fn last_word_is_non_vn(&self) -> bool {
        if self.current < 0 {
            return false;
        }
        match self.cur().form() {
            VNW_NON_VN => true,
            VNW_EMPTY | VNW_C => false,
            VNW_V | VNW_CV => !VSEQ[self.cur().vseq().idx()].complete,
            VNW_VC | VNW_CVC => {
                let v_index = self.current - self.cur().v_offset();
                let vs = self.b(v_index).vseq();
                if !VSEQ[vs.idx()].complete {
                    return true;
                }
                let cs = self.cur().cseq();
                let mut c1 = CSeq::NIL;
                if self.cur().c1_offset() != -1 {
                    c1 = self.b(self.current - self.cur().c1_offset()).cseq();
                }
                if !is_valid_cvc(c1, vs, cs) {
                    return true;
                }
                let tone_pos = (v_index - VSEQ[vs.idx()].len as i32 + 1)
                    + self.get_tone_position(vs, false);
                let tone = self.b(tone_pos).tone();
                (cs == L::cs_c || cs == L::cs_ch || cs == L::cs_p || cs == L::cs_t)
                    && (tone == 2 || tone == 3 || tone == 4)
            }
            _ => false,
        }
    }

    /// Are the key strokes of the word just typed one of the listed words
    /// the engine swallows a key from?
    ///
    /// Reads the raw strokes, not the surface: the surface is exactly what
    /// went wrong. The scan mirrors `restoreKeyStrokes`, walking back to
    /// the last word break.
    fn last_word_swallowed_a_key(&self) -> bool {
        let mut buf = [0u8; crate::enwords::MAX_WORD_LEN];
        let mut start = self.key_current;
        while start >= 0 && !self.key_is_word_break(start) {
            start -= 1;
        }
        start += 1;
        let n = (self.key_current - start + 1) as usize;
        if n == 0 || n > buf.len() {
            return false;
        }
        for k in 0..n {
            let c = self.keys[(start + k as i32) as usize];
            if c > 127 {
                return false;
            }
            let b = c as u8;
            if !b.is_ascii_alphabetic() {
                return false;
            }
            buf[k] = b.to_ascii_lowercase();
        }
        crate::enwords::is_swallowed_word(&buf[..n])
    }

    /// Does the last word carry a Vietnamese mark: a tone or a decorator?
    fn last_word_has_vn_mark(&self) -> bool {
        let mut i = self.current;
        while i >= 0 && self.b(i).form() != VNW_EMPTY {
            let sym = self.b(i).vn_sym;
            if !sym.is_non_vn() {
                if is_vowel(sym) && self.b(i).tone() != 0 {
                    return true;
                }
                if sym.0 != tables::STD_ROOT[sym.idx()] as i16 {
                    return true;
                }
            }
            i -= 1;
        }
        false
    }
}
