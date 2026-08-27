//! Keystroke transformations: diacritics (roof, hook), d-stroke, and tones.

use super::types::*;
use super::Engine;
use crate::input::{self, KeyEvent};
use crate::phonetics::lexi::{CSeq, Lexi, VSeq};
use crate::phonetics::lexi_consts as L;
use crate::phonetics::rules::{is_valid_cvc, is_vowel};
#[cfg(debug_assertions)]
use crate::phonetics::rules::{lookup_vseq1, lookup_vseq2, lookup_vseq3};
use crate::phonetics::seq;
use crate::phonetics::tables::VSEQ;

impl Engine {
    /// One table load. `seq::TONE_POS` is generated from the same data at
    /// compile time; the original's branch chain is kept below as a
    /// debug time shadow so the two can never drift apart unnoticed.
    #[inline]
    pub(super) fn get_tone_position(&self, vs: VSeq, terminated: bool) -> i32 {
        let r = seq::tone_pos(vs, terminated, self.options.modern_style);
        #[cfg(debug_assertions)]
        debug_assert_eq!(r, self.tone_position_reference(vs, terminated));
        r
    }

    #[cfg(debug_assertions)]
    pub(super) fn tone_position_reference(&self, vs: VSeq, terminated: bool) -> i32 {
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
    pub(super) fn rebuild_vseq(&self, v_start: i32, len: u8) -> VSeq {
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


    pub(super) fn process_roof(&mut self, ev: &mut KeyEvent) -> i32 {
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
    pub(super) fn process_hook_with_uo(&mut self, ev: &mut KeyEvent) -> i32 {
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

    pub(super) fn process_hook(&mut self, ev: &mut KeyEvent) -> i32 {
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

    pub(super) fn process_tone(&mut self, ev: &mut KeyEvent) -> i32 {
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

    pub(super) fn process_dd(&mut self, ev: &mut KeyEvent) -> i32 {
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

    pub(super) fn process_map_char(&mut self, ev: &mut KeyEvent) -> i32 {
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

    pub(super) fn process_telex_w(&mut self, ev: &mut KeyEvent) -> i32 {
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

    pub(super) fn check_escape_viqr(&mut self, ev: &KeyEvent) -> i32 {
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


}
