//! Rough throughput measurement. Run with:
//!     cargo test --release --test bench -- --nocapture
use std::time::Instant;
use skey_core::{charset::Charset, testkit, Engine, Options};

fn bench(name: &str, im: i32, cs: i32, cmds: &[testkit::Cmd], keys: usize) {
    let mut eng = Engine::new();
    eng.set_input_method(im);
    eng.set_charset(Charset(cs));
    eng.options = Options::default();

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
