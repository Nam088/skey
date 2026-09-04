//! Shortcuts, macro expansion, and key stroke restoration.

use super::types::*;
use super::Engine;
#[cfg(feature = "alloc")]
use crate::charset;
use crate::input::{self, KeyEvent};
use crate::phonetics::lexi::{CSeq, Lexi};
#[cfg(feature = "alloc")]
use crate::phonetics::lexi::VN_STD_CHAR_OFFSET;
use crate::phonetics::lexi_consts as L;
use crate::phonetics::rules::{is_valid_cvc, is_vowel};
use crate::phonetics::tables::{self, VSEQ};
#[cfg(feature = "alloc")]
use crate::limits::{MAX_MACRO_KEY_LEN, MAX_MACRO_TEXT_LEN};
#[cfg(feature = "alloc")]
use crate::out::At;

impl Engine {
    #[cfg(feature = "alloc")]
    /// Returns the standard character code of buffer entry `i` for macro matching.
    pub(super) fn macro_std_char(&self, i: i32) -> u32 {
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
    pub(super) fn macro_match(&mut self, _ev: &KeyEvent) -> i32 {
        0
    }

    /// `macroMatch`: walk backwards over the current word building
    /// candidate keys, longest suffix first, and expand the first hit.
    #[cfg(feature = "alloc")]
    pub(super) fn macro_match(&mut self, ev: &KeyEvent) -> i32 {
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
            for item in text[..char_count].iter_mut() {
                *item = match case {
                    VnCase::AllCapital => charset::std_to_upper(*item),
                    VnCase::AllSmall => charset::std_to_lower(*item),
                    VnCase::NoChange => *item,
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
            for &c in &text[..char_count] {
                enc.put_into(&mut sink, c);
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

    /// Automatically capitalizes the first character of a sentence after a full stop or line break.
    pub(super) fn apply_upper_case_first_char(&mut self, ev: &mut KeyEvent) -> bool {
        if !self.options.upper_case_first_char {
            return false;
        }
        if ev.ch_type == input::CHAR_RESET {
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
        if ev.ch_type == input::CHAR_WORD_BREAK {
            // A space neither arms nor disarms, so `mot. hai` capitalises
            // `hai` while `mot hai` does not.
            return false;
        }
        if !self.capitalise_next {
            return false;
        }
        if ev.ch_type != input::CHAR_VN || ev.vn_sym.is_non_vn() {
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

    /// Rewrites doubled consonants according to Quick Telex rules (e.g. `cc` -> `ch`, `uu` -> `ươ`).
    pub(super) fn apply_quick_telex(&mut self, ev: &mut KeyEvent) -> Option<i32> {
        if !self.options.quick_telex || self.current < 0 {
            return None;
        }
        if ev.ev_type != input::NORMAL || ev.ch_type != input::CHAR_VN {
            return None;
        }
        // `uu` for u horn plus o horn. The one shortcut that rewrites a
        // vowel sequence rather than substituting a letter: two buffer
        // entries change, symbols and sub sequence markers both, so it
        // does its own work and reports the key as finished.
        if ev.key_code < 128 && (ev.key_code as u8).eq_ignore_ascii_case(&b'u') {
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
                sub.ch_type = input::CHAR_VN;
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
        if !typed.eq_ignore_ascii_case(&(prev.key_code as u8)) {
            return None;
        }
        let second = crate::extensions::quick::doubled(typed)?;
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


    /// Internal implementation of raw key strokes restoration.
    pub(super) fn restore_key_strokes_inner(
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

    /// Rewrites onset or coda shortcuts if the resulting substitution produces a valid word.
    #[cfg(feature = "alloc")]
    pub(super) fn apply_quick_consonant(&mut self) -> bool {
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
        // Keep the hot path allocation-free.  The engine's key ring is
        // bounded by MAX_SKEY_ENGINE, so a stack scratch buffer is sufficient
        // for the current word and avoids a Vec allocation on every boundary.
        let mut typed = [0u32; MAX_SKEY_ENGINE];
        let typed_len = (self.key_current - start + 1) as usize;
        for (n, i) in (start..=self.key_current).enumerate() {
            typed[n] = self.keys[i as usize];
        }
        if typed[..typed_len].iter().any(|c| *c > 127) {
            return false;
        }

        // Build the candidates: onset only, coda only, then both. The
        // first that produces a valid word wins.
        let onset = if self.options.quick_start_consonant {
            crate::extensions::quick::onset(typed[0] as u8)
        } else {
            None
        };
        let coda = if self.options.quick_end_consonant {
            crate::extensions::quick::coda(typed[typed_len - 1] as u8)
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

        let mut candidate = [0u32; MAX_SKEY_ENGINE];
        let build = |use_onset: bool, use_coda: bool, candidate: &mut [u32; MAX_SKEY_ENGINE]| -> Option<usize> {
            if use_onset && onset.is_none() {
                return None;
            }
            if use_coda && coda.is_none() {
                return None;
            }
            if !use_onset && !use_coda {
                return None;
            }
            // An expansion adds one stroke per enabled side. Keep the
            // stack scratch bounded; oversized words cannot be replayed by
            // the fixed-capacity engine anyway.
            let expansion = use_onset as usize + use_coda as usize;
            if typed_len + expansion > MAX_SKEY_ENGINE {
                return None;
            }
            let mut out_len = 0usize;
            let last = typed_len - 1;
            for (i, c) in typed[..typed_len].iter().enumerate() {
                let at_first = i == 0;
                let at_last = i == last;
                if at_first && use_onset {
                    let (a, b) = onset.unwrap();
                    // Only the first letter carries the case, so `Fanh`
                    // gives `Phanh` rather than `PHanh`.
                    candidate[out_len] = cased(*c, a);
                    out_len += 1;
                    candidate[out_len] = b as u32;
                    out_len += 1;
                    if at_last && use_coda {
                        // A one letter word cannot be both, and the
                        // candidate list never asks for that.
                        return None;
                    }
                    continue;
                }
                if at_last && use_coda {
                    let (a, b) = coda.unwrap();
                    candidate[out_len] = cased(*c, a);
                    out_len += 1;
                    candidate[out_len] = cased(*c, b);
                    out_len += 1;
                    continue;
                }
                candidate[out_len] = *c;
                out_len += 1;
            }
            Some(out_len)
        };

        for (use_onset, use_coda) in [(true, false), (false, true), (true, true)] {
            let candidate_len = match build(use_onset, use_coda, &mut candidate) {
                Some(v) => v,
                None => continue,
            };
            if !self.quick_candidate_is_valid(&candidate[..candidate_len]) {
                continue;
            }
            self.commit_quick_replay(&candidate[..candidate_len]);
            return true;
        }
        false
    }

    /// Runs a candidate on a throwaway engine and reports whether it
    /// produces a valid Vietnamese word. `Engine` is not `Clone` because
    /// of the macro table, so the trial is a fresh engine carrying the
    /// same configuration with both shortcuts off so it cannot recurse.
    #[cfg(feature = "alloc")]
    pub(super) fn quick_candidate_is_valid(&self, strokes: &[u32]) -> bool {
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
    pub(super) fn commit_quick_replay(&mut self, strokes: &[u32]) {
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


    /// Handles word break keys (space, punctuation, enter), triggering macro expansion, quick consonant fixes, and spell check restorations.
    pub(super) fn process_word_end(&mut self, ev: &mut KeyEvent) -> i32 {
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
    pub(super) fn last_word_is_non_vn(&self) -> bool {
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
    pub(super) fn last_word_swallowed_a_key(&self) -> bool {
        let mut buf = [0u8; crate::extensions::enwords::MAX_WORD_LEN];
        let mut start = self.key_current;
        while start >= 0 && !self.key_is_word_break(start) {
            start -= 1;
        }
        start += 1;
        let n = (self.key_current - start + 1) as usize;
        if n == 0 || n > buf.len() {
            return false;
        }
        for (k, slot) in buf[..n].iter_mut().enumerate() {
            let c = self.keys[(start + k as i32) as usize];
            if c > 127 {
                return false;
            }
            let b = c as u8;
            if !b.is_ascii_alphabetic() {
                return false;
            }
            *slot = b.to_ascii_lowercase();
        }
        crate::extensions::enwords::is_swallowed_word(&buf[..n])
    }

    /// Does the last word carry a Vietnamese mark: a tone or a decorator?
    pub(super) fn last_word_has_vn_mark(&self) -> bool {
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
