//! Simple Telex, input method id 5.
//!
//! Not present in the C++ 3.6 engine: `UkInputProcessor::setIM` drops
//! `UkSimpleTelex` into its default arm, so `SimpleTelexMethodMapping` is
//! dead data there. It is real in the shipped 4.6 RC2 binary, whose input
//! method table at VA 0x1401be220 carries it at index 1 with id 5, which
//! is exactly `IM_SIMPLE_TELEX`.
//!
//! Because 3.6 has nothing to compare against, id 5 is excluded from the
//! oracle sweep and this file is its ground truth instead.
use skey_core::{charset::Charset, Engine};

fn typed(im: i32, keys: &str) -> String {
    let mut eng = Engine::new();
    eng.set_input_method(im);
    eng.set_charset(Charset(12));
    eng.type_str(keys)
}

#[test]
fn w_at_word_start_stays_a_letter() {
    assert_eq!(typed(5, "w"), "w");
    assert_eq!(typed(0, "w"), "ư");
}

#[test]
fn brackets_stay_literal() {
    assert_eq!(typed(5, "["), "[");
    assert_eq!(typed(5, "]"), "]");
    // Telex has them the other way round from the order they read in:
    // `[` is the horn o and `]` is the horn u.
    assert_eq!(typed(0, "["), "ơ");
    assert_eq!(typed(0, "]"), "ư");
}

#[test]
fn everything_else_is_ordinary_telex() {
    for keys in [
        "tieengs", "vieejt", "ddaa", "khoong", "nguoiwf", "chuwx", "quawn",
        "ddoongf", "hoocj", "buoowms",
    ] {
        assert_eq!(typed(5, keys), typed(0, keys), "{keys}");
    }
}

#[test]
fn w_still_works_as_a_modifier_after_a_vowel() {
    // Simple Telex only frees `w` at the start of a word. Inside one it is
    // still the horn and breve key, which is the whole point of keeping it.
    assert_eq!(typed(5, "tuw"), typed(0, "tuw"));
    assert_eq!(typed(5, "aw"), typed(0, "aw"));
}
