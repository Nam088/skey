//! SKey - Bộ gõ tiếng Việt macOS: Types and options.

use crate::phonetics::lexi::{CSeq, Lexi, VSeq};

/// Maximum keystroke history buffer capacity.
pub const MAX_ENGINE_BUFFER: usize = 128;
/// Maximum key events buffered by the SKey engine.
pub const MAX_SKEY_ENGINE: usize = MAX_ENGINE_BUFFER;

#[cfg(feature = "alloc")]
#[derive(Clone, Copy, PartialEq)]
pub(crate) enum VnCase {
    NoChange,
    AllCapital,
    AllSmall,
}

// VnWordForm
pub(crate) const VNW_NON_VN: u8 = 0;
pub(crate) const VNW_EMPTY: u8 = 1;
pub(crate) const VNW_C: u8 = 2;
pub(crate) const VNW_V: u8 = 3;
pub(crate) const VNW_CV: u8 = 4;
pub(crate) const VNW_VC: u8 = 5;
pub(crate) const VNW_CVC: u8 = 6;

/// Type of output emitted by the engine.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
#[cfg_attr(feature = "serde", derive(serde::Serialize, serde::Deserialize))]
pub enum OutputType {
    /// Transformed characters ready to be committed.
    Char,
    /// Raw key stroke codes.
    Key,
}

/// Configuration settings controlling Vietnamese input behavior and shortcuts.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[cfg_attr(feature = "serde", derive(serde::Serialize, serde::Deserialize))]
#[cfg_attr(feature = "serde", serde(default))]
pub struct Options {
    /// Place tone marks anywhere in the word freely (oà vs òa).
    pub free_marking: bool,
    /// Use modern tone placement style (òa, úy instead of oà, uý).
    pub modern_style: bool,
    /// Enable macro expansions.
    pub macro_enabled: bool,
    /// Reserved for clipboard operations at the platform layer.
    pub use_unicode_clipboard: bool,
    /// Reserved option for macro execution.
    pub always_macro: bool,
    /// Reserved strict spell check option.
    pub strict_spell_check: bool,
    /// Enable Vietnamese spelling check rules.
    pub spell_check_enabled: bool,
    /// Automatically restore raw input if an invalid Vietnamese word is detected.
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
    /// event, and `CHAR_TYPE_MAP` is the table the whole spell checker rests on.
    pub allow_consonant_zfwj: bool,
}

impl Default for Options {
    /// Default option values.
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
pub(crate) struct WordInfo {
    pub(super) key_code: u32,
    pub(super) vn_sym: Lexi,
    pub(super) seq: i16,
    pub(super) c1o: i8,
    pub(super) vo: i8,
    pub(super) c2o: i8,
    /// form in bits 0 to 2 (seven values), tone level in bits 3 to 5
    /// (six values), capitalisation in bit 6. Seven bits of real payload
    /// in the byte that alignment was going to waste anyway, which takes
    /// the entry from 16 bytes to 12 and the buffer from 2048 to 1536.
    pub(super) bits: u8,
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
    pub(super) fn vseq(&self) -> VSeq {
        VSeq(self.seq)
    }
    #[inline]
    pub(super) fn cseq(&self) -> CSeq {
        CSeq(self.seq)
    }
    #[inline]
    pub(super) fn set_vseq(&mut self, v: VSeq) {
        self.seq = v.0;
    }
    #[inline]
    pub(super) fn set_cseq(&mut self, c: CSeq) {
        self.seq = c.0;
    }
    #[inline]
    pub(super) fn c1_offset(&self) -> i32 {
        self.c1o as i32
    }
    #[inline]
    pub(super) fn v_offset(&self) -> i32 {
        self.vo as i32
    }
    #[inline]
    pub(super) fn c2_offset(&self) -> i32 {
        self.c2o as i32
    }
    #[inline]
    pub(super) fn tone(&self) -> i32 {
        ((self.bits & TONE_MASK) >> TONE_SHIFT) as i32
    }
    #[inline]
    pub(super) fn form(&self) -> u8 {
        self.bits & FORM_MASK
    }
    #[inline]
    pub(super) fn caps(&self) -> bool {
        self.bits & CAPS_BIT != 0
    }
    #[inline]
    pub(super) fn set_form(&mut self, v: u8) {
        debug_assert!(v <= FORM_MASK, "form {v} out of range");
        self.bits = (self.bits & !FORM_MASK) | v;
    }
    #[inline]
    pub(super) fn set_caps(&mut self, v: bool) {
        if v {
            self.bits |= CAPS_BIT;
        } else {
            self.bits &= !CAPS_BIT;
        }
    }
    #[inline]
    pub(super) fn set_c1_offset(&mut self, v: i32) {
        debug_assert!((-1..=127).contains(&v), "c1 offset {v} out of range");
        self.c1o = v as i8;
    }
    #[inline]
    pub(super) fn set_v_offset(&mut self, v: i32) {
        debug_assert!((-1..=127).contains(&v), "v offset {v} out of range");
        self.vo = v as i8;
    }
    #[inline]
    pub(super) fn set_c2_offset(&mut self, v: i32) {
        debug_assert!((-1..=127).contains(&v), "c2 offset {v} out of range");
        self.c2o = v as i8;
    }
    #[inline]
    pub(super) fn set_tone(&mut self, v: i32) {
        debug_assert!((0..=5).contains(&v), "tone level {v} out of range");
        self.bits = (self.bits & !TONE_MASK) | ((v as u8) << TONE_SHIFT);
    }
}

/// Result of processing one key press event by [`Engine`](crate::Engine).
///
/// Indicates what editing actions the front-end (OS input method integration layer)
/// must perform to synchronize the editor buffer with the Vietnamese engine state.
///
/// ### Fields & Integration Flow
///
/// 1. Check `handled`:
///    - If `false`: The engine did not transform or consume this key. The front-end should pass
///      the original keystroke through to the application untouched.
///    - If `true`: The engine consumed this key and computed an edit operation.
/// 2. Emit `backspaces`:
///    - Send `backspaces` backspace keystrokes to erase stale text previously committed.
/// 3. Commit `Engine::output()`:
///    - Read the replacement bytes via [`Engine::output()`](crate::Engine::output) and forward them
///      to the client application.
///
/// ### Examples
///
/// ```
/// use skey_core::{Engine, Edit, OutputType};
///
/// let mut engine = Engine::new();
/// // First letter 'a' is buffered but not transformed yet, so handled is false
/// // (letting the OS front-end commit the plain ASCII 'a'):
/// let edit1: Edit = engine.key(b'a' as u32);
/// assert_eq!(edit1.backspaces, 0);
/// assert!(!edit1.handled);
///
/// // Typing 's' (acute accent in Telex) transforms 'a' into 'á':
/// let edit2: Edit = engine.key(b's' as u32);
/// assert_eq!(edit2.backspaces, 1);
/// assert!(edit2.handled);
/// ```
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Edit {
    /// Number of backspaces the front-end must send before outputting replacement bytes.
    pub backspaces: i32,
    /// Type of output emitted by the engine ([`OutputType::Char`] or [`OutputType::Key`]).
    pub out_type: OutputType,
    /// Whether the key was consumed/handled by the engine.
    ///
    /// If `false`, the front-end should let the original key through to the OS event queue.
    /// If `true`, the front-end should delete `backspaces` characters and commit [`Engine::output()`](crate::Engine::output).
    pub handled: bool,
}
