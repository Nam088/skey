//! Shared corpus generator and trace hasher.
//!
//! Both the frozen golden test and the difftest binary use this module,
//! so the command stream the original engine is measured against and the
//! command stream replayed later cannot drift apart.
#![allow(clippy::new_without_default)]

use alloc::format;
use alloc::string::String;
use alloc::vec::Vec;

use crate::charset::Charset;
use crate::engine::OutputType;
use crate::{Engine, Options};

pub struct Lcg(u64);

impl Lcg {
    pub fn new(seed: u64) -> Self {
        Lcg(seed)
    }
    pub fn next_u32(&mut self) -> u32 {
        self.0 = self
            .0
            .wrapping_mul(6364136223846793005)
            .wrapping_add(1442695040888963407);
        (self.0 >> 33) as u32
    }
    pub fn below(&mut self, n: u32) -> u32 {
        self.next_u32() % n
    }
}

pub const SEED: u64 = 0x5EED_1234_ABCD_0001;

pub const POOL: &[u8] = b"aeiouydnghctmprsfjxzwqkblvAEIOUYDNGHCTMPRSFJXZWQKBLV \
0123456789'`?~.^+*(\x08\x08\x01\x02";

#[derive(Clone, Copy, PartialEq, Debug)]
pub enum Cmd {
    Key(u32),
    Backspace,
    Restore,
    Single,
    Reset,
}

pub fn corpus(seq_count: u32) -> Vec<Cmd> {
    let mut r = Lcg::new(SEED);
    let mut out = Vec::new();
    for _ in 0..seq_count {
        let n = 3 + r.below(23);
        for _ in 0..n {
            let c = POOL[r.below(POOL.len() as u32) as usize];
            out.push(match c {
                0x08 => Cmd::Backspace,
                0x01 => Cmd::Restore,
                0x02 => Cmd::Single,
                _ => Cmd::Key(c as u32),
            });
        }
        out.push(Cmd::Reset);
    }
    out
}

/// The corpus in the stdin protocol that port/oracle understands.
pub fn corpus_script(seq_count: u32) -> String {
    let mut o = String::new();
    for c in corpus(seq_count) {
        match c {
            Cmd::Key(k) => o.push_str(&format!("K{k}\n")),
            Cmd::Backspace => o.push_str("B\n"),
            Cmd::Restore => o.push_str("R\n"),
            Cmd::Single => o.push_str("S\n"),
            Cmd::Reset => o.push_str("---\n"),
        }
    }
    o
}

fn fnv(acc: &mut u64, bytes: &[u8]) {
    for &b in bytes {
        *acc ^= b as u64;
        *acc = acc.wrapping_mul(0x100_0000_01b3);
    }
}

/// One u64 that pins the entire trace for a given configuration.
pub fn trace_hash(im: i32, cs: i32, opts: Options, cmds: &[Cmd]) -> u64 {
    let mut eng = Engine::new();
    eng.set_input_method(im);
    eng.set_charset(Charset(cs));
    eng.options = opts;
    eng.set_caps_state(false, false);

    let mut h: u64 = 0xcbf2_9ce4_8422_2325;
    for c in cmds {
        let (tag, e) = match c {
            Cmd::Key(k) => ("K", Some(eng.key(*k))),
            Cmd::Backspace => ("B", Some(eng.backspace())),
            Cmd::Restore => ("R", Some(eng.restore_key_strokes())),
            Cmd::Single => {
                eng.set_single_mode();
                ("S", None)
            }
            Cmd::Reset => {
                eng.reset();
                ("-", None)
            }
        };
        let mut line = String::from(tag);
        if let Some(e) = e {
            let t = match e.out_type {
                OutputType::Char => 0,
                OutputType::Key => 1,
            };
            line.push_str(&format!(" b={} t={} o=", e.backspaces, t));
            for b in eng.output() {
                line.push_str(&format!("{b:02X}"));
            }
        }
        fnv(&mut h, line.as_bytes());
    }
    h
}

/// The configurations the golden file pins: every charset against the
/// default input method, and every input method against the two most
/// used charsets, each crossed with the option flags that change
/// spelling decisions.
pub fn golden_matrix() -> Vec<(i32, i32, Options)> {
    const CHARSETS: [i32; 21] = [
        0, 1, 2, 3, 4, 5, 6, 7, 10, 11, 12, 20, 21, 22, 23, 24, 25, 40, 41, 42, 43,
    ];
    // 4 (user map) is left out: with no map loaded the original's setter
    // is a no op and does not even reset, so it only ever duplicates
    // whatever was set before it.
    //
    // 5 (Simple Telex) is left out too, and for a different reason: these
    // hashes were recorded from the C++ 3.6 engine, which has no Simple
    // Telex and silently serves Telex on id 5. Freezing that would freeze
    // a wrong answer. Id 5 is covered by tests/simple_telex.rs instead.
    const METHODS: [i32; 4] = [0, 1, 2, 3];

    let opts = |fm: bool, ms: bool, sc: bool, ar: bool| Options {
        free_marking: fm,
        modern_style: ms,
        macro_enabled: false,
        spell_check_enabled: sc,
        auto_non_vn_restore: ar,
        ..Options::default()
    };

    let mut v = Vec::new();
    for cs in CHARSETS {
        for fm in [true, false] {
            for sc in [true, false] {
                for ar in [true, false] {
                    v.push((0, cs, opts(fm, false, sc, ar)));
                }
            }
        }
    }
    for im in METHODS {
        for cs in [12, 0] {
            for fm in [true, false] {
                for ms in [true, false] {
                    for sc in [true, false] {
                        for ar in [true, false] {
                            v.push((im, cs, opts(fm, ms, sc, ar)));
                        }
                    }
                }
            }
        }
    }
    v
}
