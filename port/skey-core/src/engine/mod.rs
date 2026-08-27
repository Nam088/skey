//! Core SKey typing engine state machine and dispatch orchestration.

pub mod types;
mod transform;
mod append;
mod shortcuts;

pub use types::{Edit, Options, OutputType, MAX_UK_ENGINE};

use types::*;
use crate::charset::Charset;
use crate::input::{self, InputProcessor, KeyEvent};
use crate::phonetics::tables::VSEQ;
use crate::out::OutBuf;
#[cfg(feature = "alloc")]
use crate::extensions::macros::MacroTable;

pub struct Engine {
    // ---- state that outlives a keystroke ----
    pub(super) buffer: [WordInfo; MAX_UK_ENGINE],
    pub(super) keys: [u32; MAX_UK_ENGINE],
    /// Whether the stroke at the same index caused a conversion.
    pub(super) converted: [bool; MAX_UK_ENGINE],
    pub(super) current: i32,
    pub(super) key_current: i32,
    pub(super) single_mode: bool,
    pub(super) to_escape: bool,
    /// Set when a full stop or a line break has been seen and the next
    /// letter should be capitalised. Armed at construction so the first
    /// letter of a session counts as the start of a sentence, but
    /// deliberately **not** re-armed by `reset()`: reset also happens on a
    /// focus change and on the arrow keys, and re-arming there would
    /// capitalise after a click into the middle of a sentence.
    pub(super) capitalise_next: bool,

    // ---- configuration, was UkSharedMem ----
    pub viet_key: bool,
    pub options: Options,
    pub charset: Charset,
    pub input: InputProcessor,
    /// Present only with the `alloc` feature. Without it `macro_match`
    /// never matches, which is the engine with macros switched off.
    #[cfg(feature = "alloc")]
    pub macro_store: MacroTable,
    pub(super) caps_lock_on: bool,
    pub(super) shift_pressed: bool,

    /// Was a function level `static` inside `processTelexW`, therefore
    /// shared across every engine instance and not thread safe. Now per
    /// instance, which is identical for the single engine the original
    /// actually creates.
    pub(super) used_as_map_char: bool,

    // ---- state valid within one keystroke ----
    pub(super) out: OutBuf,
    /// Models `*m_pOutSize`: on entry it is the caller's buffer size,
    /// and every path that produces output assigns the byte count to it.
    /// It is a capacity and a result at the same time, which matters:
    /// `checkEscapeVIQR` assigns 2 to it, so an escape raised from inside
    /// the key stroke restore loop shrinks the bound that the restore's
    /// own count is later checked against.
    pub(super) out_size: usize,
    pub(super) backs: i32,
    pub(super) change_pos: i32,
    pub(super) out_written: bool,
    pub(super) reverted: bool,
    pub(super) key_restored: bool,
    pub(super) key_restoring: bool,
    pub(super) out_type: OutputType,
}



impl Default for Engine {
    fn default() -> Self {
        Engine::new()
    }
}

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

    #[inline]
    pub(super) fn b(&self, i: i32) -> WordInfo {
        debug_assert!(i >= 0 && (i as usize) < MAX_UK_ENGINE, "buffer index {i}");
        self.buffer[i as usize]
    }

    #[inline]
    pub(super) fn bm(&mut self, i: i32) -> &mut WordInfo {
        debug_assert!(i >= 0 && (i as usize) < MAX_UK_ENGINE, "buffer index {i}");
        &mut self.buffer[i as usize]
    }


    #[inline]
    pub(super) fn cur(&self) -> WordInfo {
        self.b(self.current)
    }

    /// Pass a key through without filtering.
    pub fn pass(&mut self, key_code: u32) {
        let mut ev = self.input.key_code_to_event(key_code);
        let _ = self.process_append(&mut ev);
    }


    pub(super) fn dispatch(&mut self, ev: &mut KeyEvent) -> i32 {
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

    pub(super) fn dispatch_inner(&mut self, ev: &mut KeyEvent) -> i32 {
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

}
