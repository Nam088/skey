//! Word assembly, vowel/consonant appending, spell checking, and buffer maintenance.

use super::types::*;
use super::Engine;
use crate::charset::{self, Encoder};
use crate::input::{self, KeyEvent};
use crate::phonetics::lexi::{CSeq, VSeq, INVALID_STD_CHAR, VN_STD_CHAR_OFFSET};
use crate::phonetics::lexi_consts as L;
use crate::phonetics::rules::{
    cseq1, cseq_extend, is_valid_cv, is_valid_cvc, is_vowel, std_no_tone, vseq1,
    vseq_extend,
};
use crate::phonetics::tables::{self, VSEQ};

impl Engine {
    /// Classifies a key code under engine options (taking z, f, w, j rules into account).
    pub(super) fn char_type(&self, key_code: u32) -> u8 {
        if self.options.allow_consonant_zfwj
            && key_code < 128
            && matches!(key_code as u8 | 0x20, b'z' | b'f' | b'w' | b'j')
        {
            return input::CHAR_VN;
        }
        self.input.char_type(key_code)
    }

    /// `char_type` reads only static tables, so the stored copy the
    /// original kept was redundant.
    #[inline]
    pub(super) fn key_is_word_break(&self, i: i32) -> bool {
        self.char_type(self.keys[i as usize]) == input::CHAR_WORD_BREAK
    }

    /// Marks that buffer contents starting at index `pos` have changed and accumulates backspaces.
    pub(super) fn mark_change(&mut self, pos: i32) {
        if pos < self.change_pos {
            self.backs += self.get_seq_steps(pos, self.change_pos - 1);
            self.change_pos = pos;
        }
    }

    /// Backspaces needed to walk back from `last` to `first`.
    pub(super) fn get_seq_steps(&self, first: i32, last: i32) -> i32 {
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
    pub(super) fn std_char_of(&self, e: &WordInfo) -> u32 {
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

    /// Returns the standard character code formatted for output sink encoding.
    #[inline]
    pub(super) fn std_char_for_output(&self, e: &WordInfo) -> u32 {
        if !e.vn_sym.is_non_vn() {
            self.std_char_of(e)
        } else if e.key_code < 256 {
            tables::ISO_STD[e.key_code as usize]
        } else {
            e.key_code
        }
    }

    /// Encodes and writes changed characters from `change_pos` up to `current` into the output buffer.
    pub(super) fn write_output(&mut self) {
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
    pub(super) fn prepare_buffer(&mut self) {
        if self.current >= 0 && self.current as usize + 10 >= MAX_SKEY_ENGINE {
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

        if self.key_current > 0 && self.key_current as usize + 1 >= MAX_SKEY_ENGINE {
            let rid = self.key_current / 2;
            let n = (self.key_current - rid + 1) as usize;
            self.keys.copy_within(rid as usize..(rid as usize + n), 0);
            self.converted
                .copy_within(rid as usize..(rid as usize + n), 0);
            self.key_current -= rid;
        }
    }

    /// Appends a key event to the word buffer, routing vowels, consonants, word breaks, and non-VN characters.
    pub(super) fn process_append(&mut self, ev: &mut KeyEvent) -> i32 {
        match ev.ch_type {
            input::CHAR_RESET => {
                // The original also matches macros on ENTER, but only
                // under #if defined(_WIN32). The POSIX build does not,
                // and neither does this port.
                self.reset();
                0
            }
            input::CHAR_WORD_BREAK => {
                self.single_mode = false;
                self.process_word_end(ev)
            }
            input::CHAR_NON_VN => {
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
                // CHAR_VN
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
    /// Appends a vowel to the current word buffer, checking phonotactics and shifting tone positions if needed.
    pub(super) fn append_vowel(&mut self, ev: &mut KeyEvent) -> i32 {
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

    /// Appends a consonant to the current word buffer, handling onsets (`C1`) and codas (`C2`).
    pub(super) fn append_consonnant(&mut self, ev: &mut KeyEvent) -> i32 {
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

    /// Processes an escape character trigger to bypass typing rules.
    pub(super) fn process_esc_char(&mut self, ev: &mut KeyEvent) -> i32 {
        if self.viet_key
            && self.current >= 0
            && self.cur().form() != VNW_EMPTY
            && self.cur().form() != VNW_NON_VN
        {
            self.to_escape = true;
        }
        self.process_append(ev)
    }

    /// Appends a character starting a new word when spell check is disabled or in single mode.
    pub(super) fn process_no_spell_check(&mut self, ev: &KeyEvent) -> i32 {
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

    /// Synchronizes the key stroke ring buffer by decrementing the cursor after a backspace.
    pub(super) fn synch_key_stroke_buffer(&mut self) {
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

}
