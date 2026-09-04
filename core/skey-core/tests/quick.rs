//! Typing shortcuts tests. Every one of them is off by
//! default.
use skey_core::{charset::Charset, Engine, Options};

/// Types `keys` and returns what the front end's buffer would hold.
fn typed(keys: &str, opts: Options) -> String {
    let mut eng = Engine::new();
    eng.set_input_method(0);
    eng.set_charset(Charset(12));
    eng.options = opts;
    eng.type_str(keys)
}

#[test]
fn all_new_options_default_to_off() {
    let d = Options::default();
    assert!(!d.quick_telex);
    assert!(!d.quick_start_consonant);
    assert!(!d.quick_end_consonant);
    assert!(!d.upper_case_first_char);
}

mod quick_telex {
    use super::*;

    fn on() -> Options {
        Options {
            quick_telex: true,
            ..Options::default()
        }
    }

    #[test]
    fn doubled_consonants_expand() {
        for (keys, want) in [
            ("cco", "cho"),
            ("ggo", "gio"),
            ("kkong", "khong"),
            ("nnon", "ngon"),
            // `qq` gives `qu`, so the vowel follows it directly: `qqa`
            // is `qua`, and `qqua` would be `quua`.
            ("qqa", "qua"),
            ("ppo", "pho"),
            ("ttoi", "thoi"),
        ] {
            assert_eq!(typed(keys, on()), want, "{keys}");
        }
    }

    /// The replacement carries the case of the letter that was typed.
    /// Two capitals give two capitals.
    #[test]
    fn the_replacement_carries_the_case_that_was_typed() {
        assert_eq!(typed("Cco", on()), "Cho");
        assert_eq!(typed("CCo", on()), "CHo");
        assert_eq!(typed("Ppo", on()), "Pho");
        assert_eq!(typed("PPo", on()), "PHo");
    }

    #[test]
    fn off_by_default_leaves_them_alone() {
        for keys in ["cco", "ggo", "kkong", "nnon", "qqa", "ppo", "ttoi"] {
            assert_ne!(typed(keys, Options::default()), typed(keys, on()), "{keys}");
        }
    }

    /// A single consonant is untouched, and a doubled one that is not in
    /// the table is untouched.
    #[test]
    fn only_the_listed_pairs_change() {
        for keys in ["cho", "bbo", "mmo"] {
            assert_eq!(typed(keys, on()), typed(keys, Options::default()), "{keys}");
        }
    }

    /// The values come from typing the horns explicitly, `uwow` and
    /// `tuwowng` and `Uwow`, so the shortcut has to land in the same
    /// place. Only the first letter carries the case.
    #[test]
    fn uu_becomes_u_horn_o_horn() {
        assert_eq!(typed("uu", on()), "ươ");
        // `tuun` is four keys, so it lands on `tươn`; the coda needs its
        // own key, which is what `tuung` gives.
        assert_eq!(typed("tuun", on()), "tươn");
        assert_eq!(typed("tuung", on()), "tương");
        assert_eq!(typed("Uu", on()), "Ươ");
    }

    #[test]
    fn uu_is_left_alone_when_off() {
        assert_eq!(typed("uu", Options::default()), "uu");
        assert_eq!(typed("tuung", Options::default()), "tuung");
    }

    #[test]
    fn vietnamese_is_untouched() {
        for keys in ["tieengs ", "Vieejt ", "ddaay ", "nguyeenx ", "thuowng "] {
            assert_eq!(typed(keys, on()), typed(keys, Options::default()), "{keys}");
        }
    }
}

mod quick_consonant {
    use super::*;

    fn onset() -> Options {
        Options {
            quick_start_consonant: true,
            ..Options::default()
        }
    }

    fn coda() -> Options {
        Options {
            quick_end_consonant: true,
            ..Options::default()
        }
    }

    fn both() -> Options {
        Options {
            quick_start_consonant: true,
            quick_end_consonant: true,
            ..Options::default()
        }
    }

    #[test]
    fn onset_shortcuts_expand_at_the_word_break() {
        assert_eq!(typed("fanh ", onset()), "phanh ");
        assert_eq!(typed("jang ", onset()), "giang ");
        assert_eq!(typed("wen ", onset()), "quen ");
    }

    #[test]
    fn coda_shortcuts_expand_at_the_word_break() {
        assert_eq!(typed("hag ", coda()), "hang ");
        assert_eq!(typed("vih ", coda()), "vinh ");
        assert_eq!(typed("bak ", coda()), "bach ");
    }

    /// The whole reason both are deferred: a word that is already valid
    /// must not be touched, or `hang` would become `hanng`.
    #[test]
    fn already_valid_words_are_untouched() {
        for keys in ["hang ", "vinh ", "bach ", "hongf ", "manhj "] {
            assert_eq!(typed(keys, both()), typed(keys, Options::default()), "{keys}");
        }
    }

    /// The other reason: `w` alone is how Telex types u horn, and that
    /// must survive.
    #[test]
    fn w_still_types_u_horn() {
        assert_eq!(typed("w ", both()), typed("w ", Options::default()));
        assert_eq!(typed("thuowng ", both()), "thương ");
    }

    #[test]
    fn a_word_no_substitution_rescues_is_left_alone() {
        for keys in ["zzg ", "qqg ", "fzz "] {
            assert_eq!(typed(keys, both()), typed(keys, Options::default()), "{keys}");
        }
    }

    #[test]
    fn off_by_default_leaves_them_alone() {
        for keys in ["fanh ", "jang ", "wen ", "hag ", "vih ", "bak "] {
            assert_ne!(typed(keys, both()), typed(keys, Options::default()), "{keys}");
        }
    }

    #[test]
    fn vietnamese_is_untouched() {
        for keys in ["tieengs ", "Vieejt ", "ddaay ", "nguyeenx ", "thuowng ", "khoong "] {
            assert_eq!(typed(keys, both()), typed(keys, Options::default()), "{keys}");
        }
    }
}

mod upper_first {
    use super::*;

    fn on() -> Options {
        Options {
            upper_case_first_char: true,
            ..Options::default()
        }
    }

    #[test]
    fn first_letter_of_the_buffer_is_capitalised() {
        assert_eq!(typed("tieengs", on()), "Tiếng");
    }

    #[test]
    fn a_full_stop_arms_the_next_letter() {
        assert_eq!(typed("mot. hai", on()), "Mot. Hai");
    }

    #[test]
    fn a_plain_space_does_not_arm_it() {
        assert_eq!(typed("mot hai", on()), "Mot hai");
    }

    #[test]
    fn a_letter_already_capital_is_left_alone() {
        assert_eq!(typed("Tieengs", on()), "Tiếng");
    }

    #[test]
    fn off_by_default_leaves_them_alone() {
        assert_eq!(typed("tieengs", Options::default()), "tiếng");
        assert_eq!(typed("mot. hai", Options::default()), "mot. hai");
    }
}

mod consonant_zfwj {
    use super::*;

    fn on() -> Options {
        Options {
            allow_consonant_zfwj: true,
            ..Options::default()
        }
    }

    /// With the option on the letter may carry a Vietnamese word, so the
    /// tone lands on the vowel. `bas` gives the placement `fas` must now
    /// get, with `b` in place of `f`.
    #[test]
    fn a_tone_lands_on_a_word_starting_with_f() {
        assert_eq!(typed("bas", Options::default()), "bá");
        assert_eq!(typed("fas", on()), "fá");
    }

    #[test]
    fn off_by_default_leaves_them_alone() {
        assert_eq!(typed("fas", Options::default()), "fas");
        assert_ne!(typed("fas", on()), typed("fas", Options::default()));
    }

    #[test]
    fn vietnamese_is_untouched() {
        for keys in ["tieengs ", "Vieejt ", "ddaay ", "nguyeenx ", "khoong "] {
            assert_eq!(typed(keys, on()), typed(keys, Options::default()), "{keys}");
        }
    }
}

mod sentence_end {
    use super::*;

    fn on() -> Options {
        Options {
            upper_case_first_char: true,
            ..Options::default()
        }
    }

    /// Same as `typed`, but the input method is a parameter, because the
    /// whole point of this suite is that the punctuation keys are not
    /// punctuation in every method.
    fn typed_in(im: i32, keys: &str) -> String {
        let mut eng = Engine::new();
        eng.set_input_method(im);
        eng.set_charset(Charset(12));
        eng.options = on();
        eng.type_str(keys)
    }

    #[test]
    fn full_stop_bang_and_question_all_end_a_sentence_in_telex() {
        // None of the three is a Telex key, so all three are punctuation.
        assert_eq!(typed("mot. hai", on()), "Mot. Hai");
        assert_eq!(typed("mot! hai", on()), "Mot! Hai");
        assert_eq!(typed("mot? hai", on()), "Mot? Hai");
    }

    #[test]
    fn viqr_tone_keys_do_not_end_a_sentence() {
        // In VIQR `.` is nang and `?` is hoi. The word eats them, so no
        // sentence ended and the next word stays lower case.
        assert_eq!(typed_in(2, "ta. bo"), "Tạ bo");
        assert_eq!(typed_in(2, "ta? bo"), "Tả bo");
    }

    #[test]
    fn viqr_bang_still_ends_a_sentence() {
        // `!` is not a VIQR key, so it keeps working there.
        assert_eq!(typed_in(2, "ta! bo"), "Ta! Bo");
    }

    #[test]
    fn off_is_indistinguishable() {
        let d = Options::default();
        for keys in ["mot. hai", "mot! hai", "mot? hai"] {
            assert_eq!(typed(keys, d), typed(keys, d), "{keys}");
        }
        assert_eq!(typed("mot! hai", d), "mot! hai");
    }
}
