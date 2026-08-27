//! Linguistic rules, phonetic symbols, and transition tables for Vietnamese orthography.

pub mod lexi;
pub mod lexi_consts;
pub mod rules;
pub mod seq;
#[rustfmt::skip]
#[allow(dead_code)]
pub mod tables;

pub use lexi::{CSeq, Lexi, VSeq, INVALID_STD_CHAR, VN_STD_CHAR_OFFSET};
pub use rules::{
    cseq1, cseq_extend, is_valid_cv, is_valid_cvc, is_valid_vc, is_vowel, std_no_tone, vseq1,
    vseq_extend,
};
