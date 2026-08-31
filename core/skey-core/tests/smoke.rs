//! Behaviour checks that need neither the testkit nor an allocator, so
//! they also run under:
//!     cargo test -p unikey-core --no-default-features --test smoke
use skey_core::{charset::Charset, Engine, Options};

fn type_bytes(im: i32, cs: i32, keys: &str) -> Vec<Vec<u8>> {
    let mut eng = Engine::new();
    eng.set_input_method(im);
    eng.set_charset(Charset(cs));
    eng.options = Options::default();
    let mut out = Vec::new();
    for ch in keys.chars() {
        let e = eng.key(ch as u32);
        out.push(if e.handled {
            eng.output().to_vec()
        } else {
            Vec::new()
        });
    }
    out
}

fn last_nonempty(v: &[Vec<u8>]) -> Vec<u8> {
    v.iter()
        .rev()
        .find(|b| !b.is_empty())
        .cloned()
        .unwrap_or_default()
}

#[test]
fn telex_produces_tieng() {
    assert_eq!(last_nonempty(&type_bytes(0, 12, "tieengs")), "ếng".as_bytes());
}

#[test]
fn telex_produces_viet() {
    assert_eq!(last_nonempty(&type_bytes(0, 12, "Vieejt")), "ệ".as_bytes());
}

#[test]
fn dd_becomes_d_with_stroke() {
    assert_eq!(last_nonempty(&type_bytes(0, 12, "dd")), "đ".as_bytes());
}

#[test]
fn every_charset_encodes_without_panicking() {
    for cs in [
        0, 1, 2, 3, 4, 5, 6, 7, 10, 11, 12, 20, 21, 22, 23, 24, 25, 40, 41, 42, 43,
    ] {
        let out = type_bytes(0, cs, "tieengs Vieejt Nam ddaay");
        assert!(
            out.iter().any(|b| !b.is_empty()),
            "charset {cs} emitted nothing"
        );
    }
}

#[test]
fn all_input_methods_run() {
    for im in [0, 1, 2, 3, 4, 5] {
        let _ = type_bytes(im, 12, "tieengs aa oo ee dd 123456");
    }
}

#[cfg(feature = "alloc")]
#[test]
fn type_str_types_whole_words() {
    let mut eng = Engine::new();
    eng.set_input_method(0);
    eng.set_charset(Charset(12));
    eng.options = Options::default();
    assert_eq!(eng.type_str("tieengs Vieejt Nam "), "tiếng Việt Nam ");
    eng.reset();
    assert_eq!(eng.type_str("ddaay laf ddaau "), "đây là đâu ");
    eng.reset();
    assert_eq!(eng.type_str("thuowng "), "thương ");
    eng.reset();
    assert_eq!(eng.type_str("nguyeenx "), "nguyễn ");
}

#[cfg(feature = "alloc")]
#[test]
fn type_str_in_vni() {
    let mut eng = Engine::new();
    eng.set_input_method(1);
    eng.set_charset(Charset(12));
    eng.options = Options::default();
    assert_eq!(eng.type_str("tieng61 Viet65 Nam "), "tiếng Việt Nam ");
}

#[cfg(feature = "serde")]
#[test]
fn options_round_trip_through_json() {
    let o = Options {
        modern_style: true,
        macro_enabled: true,
        ..Options::default()
    };
    let s = serde_json::to_string(&o).unwrap();
    let back: Options = serde_json::from_str(&s).unwrap();
    assert_eq!(o, back);
    let cs: Charset = serde_json::from_str("12").unwrap();
    assert_eq!(cs, Charset(12));
}

/// The swallowed key option, and the guarantee that it takes nothing away.
#[cfg(feature = "alloc")]
mod swallowed {
    use super::*;

    fn typed(word: &str, on: bool) -> String {
        let mut eng = Engine::new();
        eng.set_input_method(0);
        eng.set_charset(Charset(12));
        eng.options = Options {
            auto_non_vn_restore: true,
            swallowed_key_restore: on,
            ..Options::default()
        };
        eng.type_str(&format!("{word} ")).trim_end().to_string()
    }

    #[test]
    fn every_listed_word_survives_when_on() {
        for w in skey_core::enwords::words() {
            let w = core::str::from_utf8(w).unwrap();
            assert_eq!(typed(w, true), w, "{w} should come through intact");
            // and the engine really does mangle it with the option off,
            // so no entry in the table is dead weight
            assert_ne!(typed(w, false), w, "{w} is not mangled, drop it");
        }
    }

    /// The binary search in `is_swallowed_word` is silently wrong if the
    /// blob is not sorted or an offset is mistyped, and neither shows up
    /// as a failure anywhere else.
    #[test]
    fn enwords_blob_is_sorted_and_well_formed() {
        let all: Vec<&[u8]> = skey_core::enwords::words().collect();
        assert_eq!(all.len(), 14);
        for w in &all {
            assert!(!w.is_empty());
            assert!(w.len() <= skey_core::enwords::MAX_WORD_LEN);
            assert!(skey_core::enwords::is_swallowed_word(w));
        }
        for pair in all.windows(2) {
            assert!(
                pair[0] < pair[1],
                "unsorted: {:?} then {:?}",
                core::str::from_utf8(pair[0]),
                core::str::from_utf8(pair[1])
            );
        }
        // Measured, not assumed: `st` and `cr` are not valid consonant
        // sequences, so these two go non Vn before any tone key lands and
        // the engine never mangles them. They must stay out of the table.
        assert!(!skey_core::enwords::is_swallowed_word(b"staff"));
        assert!(!skey_core::enwords::is_swallowed_word(b"cross"));
    }

    /// The reason the table stops where it does. These key strokes are how
    /// you type these Vietnamese words, and the option must not touch them.
    #[test]
    fn vietnamese_words_are_untouched() {
        let pairs = [
            ("theme", "thêm"),
            ("did", "đi"),
            ("its", "ít"),
            ("too", "tô"),
            ("max", "mã"),
            ("last", "lát"),
            ("list", "lít"),
            ("rust", "rút"),
            ("test", "tét"),
            ("trust", "trút"),
            ("toast", "toát"),
            ("host", "hót"),
            ("room", "rôm"),
        ];
        for (keys, want) in pairs {
            assert_eq!(typed(keys, false), want, "baseline for {keys}");
            assert_eq!(typed(keys, true), want, "{keys} must stay {want}");
        }
    }

    #[test]
    fn ordinary_vietnamese_is_identical_either_way() {
        let words = [
            "tieengs", "Vieejt", "nguyeenx", "thuowng", "ddaay", "khoong", "quyeenr",
            "hoaf", "uongs", "duwongf", "ddoongf", "traamf", "nghieengx", "chuyeenr",
        ];
        for w in words {
            assert_eq!(typed(w, false), typed(w, true), "{w}");
        }
    }
}

/// The macro table cap is a parity relevant number, not a tuning knob.
/// See the `large-macro-table` feature.
#[test]
fn macro_table_capacity_matches_the_active_feature() {
    let want = if cfg!(feature = "large-macro-table") {
        8192
    } else {
        1024
    };
    assert_eq!(skey_core::limits::MAX_MACRO_ITEMS, want);
}
