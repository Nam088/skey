//! Rough throughput measurement. Run with:
//!     cargo test --release --test bench -- --nocapture
use std::time::Instant;
use skey_core::{charset::Charset, testkit, Engine, Options};

fn bench(name: &str, im: i32, cs: i32, cmds: &[testkit::Cmd], keys: usize) {
    bench_with_options(name, im, cs, cmds, keys, Options::default());
}

fn bench_with_options(
    name: &str,
    im: i32,
    cs: i32,
    cmds: &[testkit::Cmd],
    keys: usize,
    options: Options,
) {
    let mut eng = Engine::new();
    eng.set_input_method(im);
    eng.set_charset(Charset(cs));
    eng.options = options;

    // Keep macro setup out of the timed region while still exercising lookup
    // and expansion on every measured round.
    #[cfg(feature = "alloc")]
    if options.macro_enabled {
        eng.macro_store.add_item(b"brb\0", b"be right back\0", Charset(12));
        eng.macro_store.add_item(b"omw\0", b"on my way\0", Charset(12));
    }

    for _ in 0..2 {
        for c in cmds {
            drive(&mut eng, c);
        }
    }
    let rounds = 20;
    let t0 = Instant::now();
    for _ in 0..rounds {
        for c in cmds {
            drive(&mut eng, c);
        }
    }
    let dt = t0.elapsed();
    let total = keys * rounds;
    println!(
        "{name:<22} {:>6.1} ns/key   {:>5.1} M keys/s",
        dt.as_nanos() as f64 / total as f64,
        total as f64 / dt.as_secs_f64() / 1e6
    );
}

#[test]
fn keystroke_throughput() {
    let cmds = testkit::corpus(20_000);
    let keys = cmds
        .iter()
        .filter(|c| matches!(c, testkit::Cmd::Key(_)))
        .count();
    println!("{keys} key events per round\n");
    bench("telex + xutf8", 0, 12, &cmds, keys);
    bench("telex + unicode", 0, 0, &cmds, keys);
    bench("telex + tcvn3", 0, 20, &cmds, keys);
    bench("telex + vniwin", 0, 40, &cmds, keys);
    bench("telex + viqr", 0, 10, &cmds, keys);
    bench("telex + cp1258", 0, 5, &cmds, keys);
    bench("vni + xutf8", 1, 12, &cmds, keys);
    bench("viqr im + xutf8", 2, 12, &cmds, keys);
}

/// Targeted workloads complement the pseudo-random corpus above. They are
/// intentionally short so `cargo test` remains quick, while repeated rounds
/// make allocator and branch costs visible in release builds.
#[test]
fn targeted_workloads() {
    // Long words stress replacement scans and output encoding.
    let mut long_word = Vec::new();
    for _ in 0..1_000 {
        for ch in "nguyeenxthuwowng".bytes() {
            long_word.push(testkit::Cmd::Key(ch as u32));
        }
        long_word.push(testkit::Cmd::Key(b' ' as u32));
    }

    // Backspace-heavy editing exercises restore/revert paths.
    let mut backspace = Vec::new();
    for _ in 0..2_000 {
        for ch in b"tieengs" {
            backspace.push(testkit::Cmd::Key(*ch as u32));
        }
        backspace.extend([testkit::Cmd::Backspace; 4]);
        backspace.push(testkit::Cmd::Reset);
    }

    // Quick shortcuts take candidate/replay branches that the default corpus
    // does not enable.
    let mut quick = Vec::new();
    for _ in 0..2_000 {
        for ch in b"fanh ddau cc" {
            quick.push(testkit::Cmd::Key(*ch as u32));
        }
        quick.push(testkit::Cmd::Key(b' ' as u32));
    }
    let quick_opts = Options {
        quick_telex: true,
        quick_start_consonant: true,
        quick_end_consonant: true,
        ..Options::default()
    };

    // Macro expansion is triggered at word boundaries (space).
    let mut macros = Vec::new();
    for _ in 0..2_000 {
        for ch in b"brb" {
            macros.push(testkit::Cmd::Key(*ch as u32));
        }
        macros.push(testkit::Cmd::Key(b' ' as u32));
        for ch in b"omw" {
            macros.push(testkit::Cmd::Key(*ch as u32));
        }
        macros.push(testkit::Cmd::Key(b' ' as u32));
    }
    let macro_opts = Options {
        macro_enabled: true,
        ..Options::default()
    };

    bench_with_options(
        "target long-word",
        0,
        12,
        &long_word,
        event_count(&long_word),
        Options::default(),
    );
    bench_with_options(
        "target backspace",
        0,
        12,
        &backspace,
        event_count(&backspace),
        Options::default(),
    );
    bench_with_options(
        "target quick options",
        0,
        12,
        &quick,
        event_count(&quick),
        quick_opts,
    );
    bench_with_options(
        "target macro lookup",
        0,
        12,
        &macros,
        event_count(&macros),
        macro_opts,
    );
}

fn event_count(cmds: &[testkit::Cmd]) -> usize {
    cmds.iter().filter(|c| !matches!(c, testkit::Cmd::Reset)).count()
}

fn drive(eng: &mut Engine, c: &testkit::Cmd) {
    match c {
        testkit::Cmd::Key(k) => {
            eng.key(*k);
        }
        testkit::Cmd::Backspace => {
            eng.backspace();
        }
        testkit::Cmd::Restore => {
            eng.restore_key_strokes();
        }
        testkit::Cmd::Single => eng.set_single_mode(),
        testkit::Cmd::Reset => eng.reset(),
    }
}
