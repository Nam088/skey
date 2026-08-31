//! Key code classification and the per method key maps.
//! Direct port of `UkInputProcessor`.

use crate::lexi::Lexi;
use crate::tables;

// UkKeyEvName
pub const ROOF_ALL: u16 = 0;
pub const ROOF_A: u16 = 1;
pub const ROOF_E: u16 = 2;
pub const ROOF_O: u16 = 3;
pub const HOOK_ALL: u16 = 4;
pub const HOOK_UO: u16 = 5;
pub const HOOK_U: u16 = 6;
pub const HOOK_O: u16 = 7;
pub const BOWL: u16 = 8;
pub const DD: u16 = 9;
pub const TONE0: u16 = 10;
pub const TONE1: u16 = 11;
pub const TONE2: u16 = 12;
pub const TONE3: u16 = 13;
pub const TONE4: u16 = 14;
pub const TONE5: u16 = 15;
pub const TELEX_W: u16 = 16;
pub const MAP_CHAR: u16 = 17;
pub const ESC_CHAR: u16 = 18;
pub const NORMAL: u16 = 19;
pub const EV_COUNT: u16 = 20;

/// Every key map action fits in a byte: the event kinds run to 19, and a
/// character mapping is `EV_COUNT + lexi`, whose largest value is
/// 20 + 186 = 206. The table is therefore 256 bytes rather than 512.
pub const MAX_ACTION: u16 = EV_COUNT + 186;
const _: () = assert!(MAX_ACTION <= u8::MAX as u16);

// UkCharType
pub const UKC_VN: u8 = 0;
pub const UKC_WORD_BREAK: u8 = 1;
pub const UKC_NON_VN: u8 = 2;
pub const UKC_RESET: u8 = 3;

// UkInputMethod
pub const IM_TELEX: i32 = 0;
pub const IM_VNI: i32 = 1;
pub const IM_VIQR: i32 = 2;
pub const IM_MSVI: i32 = 3;
pub const IM_USR: i32 = 4;
pub const IM_SIMPLE_TELEX: i32 = 5;

#[derive(Clone, Copy, Debug, Default)]
pub struct KeyEvent {
    pub ev_type: u16,
    pub ch_type: u8,
    /// Meaningful only when `ch_type == UKC_VN`.
    pub vn_sym: Lexi,
    pub key_code: u32,
    /// Meaningful only for tone events. The original leaves this
    /// uninitialised; zero is used here and every read is behind a
    /// tone event dispatch, so the value is never observed.
    pub tone: i32,
}

#[inline]
pub fn iso_to_lexi(key_code: u32) -> Lexi {
    if key_code >= 256 {
        Lexi::NON_VN
    } else {
        Lexi(tables::ISO_LEXI[key_code as usize])
    }
}

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
    pub fn im(&self) -> i32 {
        self.im
    }

    pub fn set_im(&mut self, im: i32) {
        self.im = im;
        // Ids 0 to 4 are exactly 3.6, and the differential harness holds
        // them there. Id 5 is not: `UkInputProcessor::setIM` drops
        // `UkSimpleTelex` into its default arm, leaving
        // `SimpleTelexMethodMapping` as dead data in the C++ engine. The
        // shipped 4.6 RC2 binary does implement it, so this port does too,
        // and pays for it by taking id 5 out of the oracle comparison.
        let map = match im {
            IM_TELEX => tables::TELEX_MAP,
            IM_VNI => tables::VNI_MAP,
            IM_VIQR => tables::VIQR_MAP,
            IM_MSVI => tables::MSVI_MAP,
            // The one place this port deliberately parts company with 3.6.
            // See the note above: 3.6 silently degrades id 5 to Telex, but
            // the shipped 4.6 RC2 binary carries Simple Telex at index 1 of
            // the input method table at VA 0x1401be220, with id 5. Id 5 is
            // therefore out of the oracle sweep, and tests/simple_telex.rs
            // is its ground truth.
            IM_SIMPLE_TELEX => tables::SIMPLE_TELEX_MAP,
            _ => {
                self.im = IM_TELEX;
                tables::TELEX_MAP
            }
        };
        self.use_built_in(map);
    }

    pub fn set_user_map(&mut self, map: &[u8; 256]) {
        self.im = IM_USR;
        self.key_map = *map;
    }

    pub fn key_map(&self) -> &[u8; 256] {
        &self.key_map
    }

    fn use_built_in(&mut self, map: &[(u8, u16)]) {
        self.key_map = [NORMAL as u8; 256];
        for &(key, action) in map {
            debug_assert!(action <= MAX_ACTION);
            self.key_map[key as usize] = action as u8;
            // Built in maps list only one case; action keys apply to
            // both. Character mapping entries (>= EV_COUNT) do not,
            // because they carry their own case.
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

    pub fn char_type(&self, key_code: u32) -> u8 {
        if key_code > 255 {
            if iso_to_lexi(key_code).is_non_vn() {
                UKC_NON_VN
            } else {
                UKC_VN
            }
        } else {
            tables::UKC_MAP[key_code as usize]
        }
    }

    pub fn key_code_to_event(&self, key_code: u32) -> KeyEvent {
        let mut ev = KeyEvent {
            key_code,
            ..Default::default()
        };
        if key_code > 255 {
            ev.ev_type = NORMAL;
            ev.vn_sym = iso_to_lexi(key_code);
            ev.ch_type = if ev.vn_sym.is_non_vn() {
                UKC_NON_VN
            } else {
                UKC_VN
            };
        } else {
            ev.ch_type = tables::UKC_MAP[key_code as usize];
            ev.ev_type = self.key_map[key_code as usize] as u16;

            if ev.ev_type >= TONE0 && ev.ev_type <= TONE5 {
                ev.tone = (ev.ev_type - TONE0) as i32;
            }

            if ev.ev_type >= EV_COUNT {
                ev.ch_type = UKC_VN;
                ev.vn_sym = Lexi((ev.ev_type - EV_COUNT) as i16);
                ev.ev_type = MAP_CHAR;
            } else {
                ev.vn_sym = iso_to_lexi(key_code);
            }
        }
        ev
    }

    /// `keyCodeToSymbol`: treat the stroke as plain character input.
    pub fn key_code_to_symbol(&self, key_code: u32) -> KeyEvent {
        let vn_sym = iso_to_lexi(key_code);
        KeyEvent {
            key_code,
            ev_type: NORMAL,
            vn_sym,
            ch_type: if key_code > 255 {
                if vn_sym.is_non_vn() {
                    UKC_NON_VN
                } else {
                    UKC_VN
                }
            } else {
                tables::UKC_MAP[key_code as usize]
            },
            tone: 0,
        }
    }
}

