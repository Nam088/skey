//! Key code classification and the per method key maps.

use crate::lexi::Lexi;
use crate::tables;

/// Event type: apply roof accent to any eligible vowel (a -> â, e -> ê, o -> ô).
pub const ROOF_ALL: u16 = 0;
/// Event type: apply roof accent specifically to 'a'.
pub const ROOF_A: u16 = 1;
/// Event type: apply roof accent specifically to 'e'.
pub const ROOF_E: u16 = 2;
/// Event type: apply roof accent specifically to 'o'.
pub const ROOF_O: u16 = 3;
/// Event type: apply hook / horn accent to any eligible vowel (u, o).
pub const HOOK_ALL: u16 = 4;
/// Event type: apply hook / horn accent to 'u' and 'o' together (ươ).
pub const HOOK_UO: u16 = 5;
/// Event type: apply hook / horn accent to 'u'.
pub const HOOK_U: u16 = 6;
/// Event type: apply hook / horn accent to 'o'.
pub const HOOK_O: u16 = 7;
/// Event type: apply bowl / breve accent (ă).
pub const BOWL: u16 = 8;
/// Event type: transform 'd' to 'đ'.
pub const DD: u16 = 9;
/// Event type: remove tone accent (ngang / unmarked).
pub const TONE0: u16 = 10;
/// Event type: apply acute tone (sắc).
pub const TONE1: u16 = 11;
/// Event type: apply grave tone (huyền).
pub const TONE2: u16 = 12;
/// Event type: apply hook above tone (hỏi).
pub const TONE3: u16 = 13;
/// Event type: apply tilde tone (ngã).
pub const TONE4: u16 = 14;
/// Event type: apply dot below tone (nặng).
pub const TONE5: u16 = 15;
/// Event type: Telex 'w' key behavior (ă, ươ, or raw w).
pub const TELEX_W: u16 = 16;
/// Event type: mapped character insertion.
pub const MAP_CHAR: u16 = 17;
/// Event type: escape key sequence.
pub const ESC_CHAR: u16 = 18;
/// Event type: normal character input.
pub const NORMAL: u16 = 19;
/// Number of predefined event types.
pub const EV_COUNT: u16 = 20;

/// Every key map action fits in a byte: the event kinds run to 19, and a
/// character mapping is `EV_COUNT + lexi`, whose largest value is
/// 20 + 186 = 206. The table is therefore 256 bytes rather than 512.
pub const MAX_ACTION: u16 = EV_COUNT + 186;
const _: () = assert!(MAX_ACTION <= u8::MAX as u16);

/// Character classification: valid Vietnamese character.
pub const CHAR_VN: u8 = 0;
/// Character classification: word-breaking delimiter (spaces, punctuation).
pub const CHAR_WORD_BREAK: u8 = 1;
/// Character classification: non-Vietnamese character.
pub const CHAR_NON_VN: u8 = 2;
/// Character classification: reset character forcing word reset.
pub const CHAR_RESET: u8 = 3;

/// Alias for `CHAR_VN`.
pub const SKC_VN: u8 = CHAR_VN;
/// Alias for `CHAR_WORD_BREAK`.
pub const SKC_WORD_BREAK: u8 = CHAR_WORD_BREAK;
/// Alias for `CHAR_NON_VN`.
pub const SKC_NON_VN: u8 = CHAR_NON_VN;
/// Alias for `CHAR_RESET`.
pub const SKC_RESET: u8 = CHAR_RESET;

/// Input method: Telex.
pub const IM_TELEX: i32 = 0;
/// Input method: VNI.
pub const IM_VNI: i32 = 1;
/// Input method: VIQR.
pub const IM_VIQR: i32 = 2;
/// Input method: Microsoft Vietnamese layout.
pub const IM_MSVI: i32 = 3;
/// Input method: User-defined key map.
pub const IM_USR: i32 = 4;
/// Input method: Simple Telex.
pub const IM_SIMPLE_TELEX: i32 = 5;

/// Represents a classified key event with character and tone details.
#[derive(Clone, Copy, Debug, Default)]
pub struct KeyEvent {
    /// Event type code (e.g. `ROOF_ALL`, `TONE1`, `NORMAL`).
    pub ev_type: u16,
    /// Character category (`CHAR_VN`, `CHAR_WORD_BREAK`, `CHAR_NON_VN`, etc.).
    pub ch_type: u8,
    /// Vietnamese lexical symbol; meaningful only when `ch_type == CHAR_VN`.
    pub vn_sym: Lexi,
    /// Raw key code input.
    pub key_code: u32,
    /// Tone index (0 to 5); meaningful only for tone events.
    pub tone: i32,
}

/// Converts an ISO-8859/ASCII key code into an internal lexical character index ([`Lexi`]).
///
/// ### Arguments
///
/// - `key_code`: Character code point or ASCII byte value.
///
/// ### Returns
///
/// Returns [`Lexi::NON_VN`] if `key_code >= 256`, or the mapped [`Lexi`] symbol index for valid characters.
///
/// ### Examples
///
/// ```
/// use skey_core::input::iso_to_lexi;
///
/// let sym = iso_to_lexi(b'a' as u32);
/// assert!(!sym.is_non_vn());
/// assert!(iso_to_lexi(1000).is_non_vn());
/// ```
#[inline]
pub fn iso_to_lexi(key_code: u32) -> Lexi {
    if key_code >= 256 {
        Lexi::NON_VN
    } else {
        Lexi(tables::ISO_LEXI[key_code as usize])
    }
}

/// Input processor that classifies keystrokes and maps them based on the active input method.
#[derive(Clone, Copy)]
pub struct InputProcessor {
    im: i32,
    key_map: [u8; 256],
}

impl Default for InputProcessor {
    fn default() -> Self {
        let mut p = InputProcessor {
            im: IM_TELEX,
            key_map: [NORMAL as u8; 256],
        };
        p.set_im(IM_TELEX);
        p
    }
}

impl InputProcessor {
    /// Returns the active input method ID (`IM_TELEX`, `IM_VNI`, etc.).
    ///
    /// ### Returns
    ///
    /// The integer code corresponding to the active input method:
    /// - [`IM_TELEX`] (0)
    /// - [`IM_VNI`] (1)
    /// - [`IM_VIQR`] (2)
    /// - [`IM_MSVI`] (3)
    /// - [`IM_USR`] (4)
    /// - [`IM_SIMPLE_TELEX`] (5)
    ///
    /// ### Examples
    ///
    /// ```
    /// use skey_core::input::{InputProcessor, IM_TELEX};
    ///
    /// let proc = InputProcessor::default();
    /// assert_eq!(proc.im(), IM_TELEX);
    /// ```
    pub fn im(&self) -> i32 {
        self.im
    }

    /// Sets the active input method and updates the internal key dispatch map.
    ///
    /// ### Arguments
    ///
    /// - `im`: Input method identifier ([`IM_TELEX`], [`IM_VNI`], [`IM_VIQR`], [`IM_MSVI`], or [`IM_SIMPLE_TELEX`]).
    ///   If an unknown ID is provided, it safely defaults back to [`IM_TELEX`].
    ///
    /// ### Examples
    ///
    /// ```
    /// use skey_core::input::{InputProcessor, IM_VNI};
    ///
    /// let mut proc = InputProcessor::default();
    /// proc.set_im(IM_VNI);
    /// assert_eq!(proc.im(), IM_VNI);
    /// ```
    pub fn set_im(&mut self, im: i32) {
        self.im = im;
        let map = match im {
            IM_TELEX => tables::TELEX_MAP,
            IM_VNI => tables::VNI_MAP,
            IM_VIQR => tables::VIQR_MAP,
            IM_MSVI => tables::MSVI_MAP,
            IM_SIMPLE_TELEX => tables::SIMPLE_TELEX_MAP,
            _ => {
                self.im = IM_TELEX;
                tables::TELEX_MAP
            }
        };
        self.use_built_in(map);
    }

    /// Configures a custom user-defined key map.
    ///
    /// ### Arguments
    ///
    /// - `map`: Reference to a 256-entry array mapping each byte to an action or mapped character.
    ///
    /// ### Examples
    ///
    /// ```
    /// use skey_core::input::{InputProcessor, IM_USR, NORMAL};
    ///
    /// let mut proc = InputProcessor::default();
    /// let custom_map = [NORMAL as u8; 256];
    /// proc.set_user_map(&custom_map);
    /// assert_eq!(proc.im(), IM_USR);
    /// ```
    pub fn set_user_map(&mut self, map: &[u8; 256]) {
        self.im = IM_USR;
        self.key_map = *map;
    }

    /// Returns a reference to the active 256-entry key map table.
    ///
    /// ### Returns
    ///
    /// A reference to the fixed-size array of 256 action bytes currently applied to incoming key codes.
    ///
    /// ### Examples
    ///
    /// ```
    /// use skey_core::input::{InputProcessor, TONE1};
    ///
    /// let proc = InputProcessor::default(); // Telex
    /// assert_eq!(proc.key_map()[b's' as usize], TONE1 as u8);
    /// ```
    pub fn key_map(&self) -> &[u8; 256] {
        &self.key_map
    }

    fn use_built_in(&mut self, map: &[(u8, u16)]) {
        self.key_map = [NORMAL as u8; 256];
        for &(key, action) in map {
            debug_assert!(action <= MAX_ACTION);
            self.key_map[key as usize] = action as u8;
            if action < EV_COUNT {
                let k = key as char;
                if k.is_ascii_lowercase() {
                    self.key_map[k.to_ascii_uppercase() as usize] = action as u8;
                } else if k.is_ascii_uppercase() {
                    self.key_map[k.to_ascii_lowercase() as usize] = action as u8;
                }
            }
        }
    }

    /// Classifies a key code into a character category (`CHAR_VN`, `CHAR_NON_VN`, etc.).
    ///
    /// Values above 255 are classified based on whether [`iso_to_lexi`] maps them to a valid Vietnamese symbol.
    ///
    /// ### Arguments
    ///
    /// - `key_code`: Character code point or ASCII byte value.
    ///
    /// ### Returns
    ///
    /// Returns one of:
    /// - [`CHAR_VN`]: Standard Vietnamese alphabetic character.
    /// - [`CHAR_WORD_BREAK`]: Delimiter character that terminates a word (space, punctuation).
    /// - [`CHAR_NON_VN`]: Foreign character or symbol outside Vietnamese phonotactics.
    /// - [`CHAR_RESET`]: Control character forcing word buffer reset.
    ///
    /// ### Examples
    ///
    /// ```
    /// use skey_core::input::{InputProcessor, CHAR_VN, CHAR_WORD_BREAK};
    ///
    /// let proc = InputProcessor::default();
    /// assert_eq!(proc.char_type(b'a' as u32), CHAR_VN);
    /// assert_eq!(proc.char_type(b' ' as u32), CHAR_WORD_BREAK);
    /// ```
    pub fn char_type(&self, key_code: u32) -> u8 {
        if key_code > 255 {
            if iso_to_lexi(key_code).is_non_vn() {
                CHAR_NON_VN
            } else {
                CHAR_VN
            }
        } else {
            tables::CHAR_TYPE_MAP[key_code as usize]
        }
    }

    /// Converts a key code stroke into a classified [`KeyEvent`] under the active input method.
    ///
    /// Dispatches the stroke through the active key map table (e.g. mapping 's' to `TONE1` in Telex).
    ///
    /// ### Arguments
    ///
    /// - `key_code`: Raw key code (ASCII code or Unicode codepoint).
    ///
    /// ### Returns
    ///
    /// A populated [`KeyEvent`] containing the event type (`ev_type`), character type (`ch_type`),
    /// Vietnamese lexical symbol (`vn_sym`), and tone index (`tone`).
    ///
    /// ### Examples
    ///
    /// ```
    /// use skey_core::input::{InputProcessor, IM_TELEX, TONE1};
    ///
    /// let proc = InputProcessor::default(); // Defaults to Telex
    /// let ev = proc.key_code_to_event(b's' as u32);
    /// assert_eq!(ev.ev_type, TONE1);
    /// assert_eq!(ev.tone, 1);
    /// ```
    pub fn key_code_to_event(&self, key_code: u32) -> KeyEvent {
        let mut ev = KeyEvent {
            key_code,
            ..Default::default()
        };
        if key_code > 255 {
            ev.ev_type = NORMAL;
            ev.vn_sym = iso_to_lexi(key_code);
            ev.ch_type = if ev.vn_sym.is_non_vn() {
                CHAR_NON_VN
            } else {
                CHAR_VN
            };
        } else {
            ev.ch_type = tables::CHAR_TYPE_MAP[key_code as usize];
            ev.ev_type = self.key_map[key_code as usize] as u16;

            if ev.ev_type >= TONE0 && ev.ev_type <= TONE5 {
                ev.tone = (ev.ev_type - TONE0) as i32;
            }

            if ev.ev_type >= EV_COUNT {
                ev.ch_type = CHAR_VN;
                ev.vn_sym = Lexi((ev.ev_type - EV_COUNT) as i16);
                ev.ev_type = MAP_CHAR;
            } else {
                ev.vn_sym = iso_to_lexi(key_code);
            }
        }
        ev
    }

    /// Treats the stroke strictly as a plain character input without method transformations.
    ///
    /// Sets `ev_type` to [`NORMAL`] regardless of whether the key is mapped to a tone or diacritic
    /// in the active input method. Used during key stroke restoration or raw typing passes.
    ///
    /// ### Arguments
    ///
    /// - `key_code`: Raw key code (ASCII code or Unicode codepoint).
    ///
    /// ### Returns
    ///
    /// A [`KeyEvent`] configured with `ev_type = NORMAL` and tone `0`, representing the literal keystroke.
    ///
    /// ### Examples
    ///
    /// ```
    /// use skey_core::input::{InputProcessor, NORMAL};
    ///
    /// let proc = InputProcessor::default();
    /// let ev = proc.key_code_to_symbol(b's' as u32);
    /// assert_eq!(ev.ev_type, NORMAL);
    /// assert_eq!(ev.tone, 0);
    /// ```
    pub fn key_code_to_symbol(&self, key_code: u32) -> KeyEvent {
        let vn_sym = iso_to_lexi(key_code);
        KeyEvent {
            key_code,
            ev_type: NORMAL,
            vn_sym,
            ch_type: if key_code > 255 {
                if vn_sym.is_non_vn() {
                    CHAR_NON_VN
                } else {
                    CHAR_VN
                }
            } else {
                tables::CHAR_TYPE_MAP[key_code as usize]
            },
            tone: 0,
        }
    }
}

