//! Speaks the same stdin protocol and prints the same trace format as
//! port/oracle, so the two can be diffed line by line.
use std::io::{self, BufRead, Write};
use skey_core::{charset::Charset, engine::OutputType, Engine, Options};

fn emit(out: &mut impl Write, tag: &str, backs: i32, ty: OutputType, bytes: &[u8]) {
    let t = match ty {
        OutputType::Char => 0,
        OutputType::Key => 1,
    };
    write!(out, "{} b={} n={} t={} o=", tag, backs, bytes.len(), t).unwrap();
    for b in bytes {
        write!(out, "{:02X}", b).unwrap();
    }
    writeln!(out).unwrap();
}



fn main() {
    let a: Vec<String> = std::env::args().skip(1).collect();
    match a.first().map(|s| s.as_str()) {
        Some("gen") => {
            // Emit the golden corpus in the oracle's stdin protocol.
            print!("{}", skey_core::testkit::corpus_script(
                a.get(1).and_then(|s| s.parse().ok()).unwrap_or(20_000)));
            return;
        }
        Some("type") => {
            // One line in, the typed result out. Used to build and audit
            // the English word list empirically.
            let im: i32 = a.get(1).and_then(|s| s.parse().ok()).unwrap_or(0);
            let en: i32 = a.get(2).and_then(|s| s.parse().ok()).unwrap_or(0);
            let mut eng = Engine::new();
            eng.set_input_method(im);
            eng.set_charset(Charset(12));
            eng.options = Options {
                auto_non_vn_restore: true,
                swallowed_key_restore: en != 0,
                ..Options::default()
            };
            for line in io::stdin().lock().lines() {
                let line = line.unwrap();
                eng.reset();
                println!("{}", eng.type_str(&line));
            }
            return;
        }
        Some("bench") => {
            // Mirror of bench/bench.cpp: same corpus file, same command
            // mix, same round count, file read and parsed before the
            // clock starts.
            enum Cmd {
                K(u32),
                B,
                R,
                S,
                Z,
            }
            let path = a.get(1).cloned().unwrap_or_else(|| "/tmp/bench_corpus.txt".into());
            let im: i32 = a.get(2).and_then(|s| s.parse().ok()).unwrap_or(0);
            let cs: i32 = a.get(3).and_then(|s| s.parse().ok()).unwrap_or(12);
            let rounds: usize = a.get(4).and_then(|s| s.parse().ok()).unwrap_or(20);
            let label = a.get(5).cloned().unwrap_or_else(|| "rust".into());

            let text = std::fs::read_to_string(&path).expect("corpus");
            let mut cmds = Vec::new();
            for line in text.lines() {
                match line.as_bytes().first() {
                    Some(b'K') => cmds.push(Cmd::K(line[1..].trim().parse().unwrap())),
                    Some(b'B') => cmds.push(Cmd::B),
                    Some(b'R') => cmds.push(Cmd::R),
                    Some(b'S') => cmds.push(Cmd::S),
                    Some(b'-') => cmds.push(Cmd::Z),
                    _ => {}
                }
            }
            let keys = cmds.iter().filter(|c| matches!(c, Cmd::K(_))).count();

            let mut eng = Engine::new();
            eng.set_input_method(im);
            eng.set_charset(Charset(cs));
            eng.options = Options::default();
            eng.set_caps_state(false, false);

            let drive = |eng: &mut Engine, c: &Cmd| match c {
                Cmd::K(k) => {
                    eng.key(*k);
                }
                Cmd::B => {
                    eng.backspace();
                }
                Cmd::R => {
                    eng.restore_key_strokes();
                }
                Cmd::S => eng.set_single_mode(),
                Cmd::Z => eng.reset(),
            };

            for _ in 0..2 {
                for c in &cmds {
                    drive(&mut eng, c);
                }
            }
            let t0 = std::time::Instant::now();
            for _ in 0..rounds {
                for c in &cmds {
                    drive(&mut eng, c);
                }
            }
            let dt = t0.elapsed();
            let total = (keys * rounds) as f64;
            println!(
                "{:<22} {:>6.1} ns/key   {:>5.1} M keys/s",
                label,
                dt.as_nanos() as f64 / total,
                total / dt.as_secs_f64() / 1e6
            );
            return;
        }
        Some("hashes") => {
            // Recompute the golden hashes from the current engine.
            let cmds = skey_core::testkit::corpus(
                a.get(1).and_then(|s| s.parse().ok()).unwrap_or(20_000));
            println!("[");
            for (im, cs, o) in skey_core::testkit::golden_matrix() {
                println!("    0x{:016X}, // im={} cs={} fm={} ms={} sc={} ar={}",
                    skey_core::testkit::trace_hash(im, cs, o, &cmds),
                    im, cs, o.free_marking as u8, o.modern_style as u8,
                    o.spell_check_enabled as u8, o.auto_non_vn_restore as u8);
            }
            println!("]");
            return;
        }
        _ => {}
    }
    // Fail loudly on a malformed argument. Silently falling back to a
    // default made a shell quoting mistake look like an engine
    // divergence, which is exactly the failure mode a harness must not
    // have.
    let g = |i: usize, d: i32| match a.get(i) {
        None => d,
        Some(s) => s
            .parse()
            .unwrap_or_else(|_| panic!("bad argument {}: {:?}", i, s)),
    };

    let mut eng = Engine::new();
    eng.set_input_method(g(0, 0));
    eng.set_charset(Charset(g(1, 12)));
    eng.options = Options {
        free_marking: g(2, 1) != 0,
        modern_style: g(3, 0) != 0,
        macro_enabled: g(4, 0) != 0,
        spell_check_enabled: g(5, 1) != 0,
        auto_non_vn_restore: g(6, 0) != 0,
        // Absent arguments take the default, so every existing sweep
        // keeps passing seven and keeps getting all four off.
        quick_telex: g(7, 0) != 0,
        quick_start_consonant: g(8, 0) != 0,
        quick_end_consonant: g(9, 0) != 0,
        upper_case_first_char: g(10, 0) != 0,
        allow_consonant_zfwj: g(11, 0) != 0,
        ..Options::default()
    };
    eng.set_caps_state(false, false);

    let stdin = io::stdin();
    let stdout = io::stdout();
    let mut out = io::BufWriter::new(stdout.lock());

    for line in stdin.lock().lines() {
        let line = line.unwrap();
        let mut ch = line.chars();
        match ch.next() {
            Some('K') => {
                let code: u32 = line[1..].trim().parse().unwrap();
                let e = eng.key(code);
                let bytes: Vec<u8> = eng.output().to_vec();
                emit(&mut out, "K", e.backspaces, e.out_type, &bytes);
            }
            Some('B') => {
                let e = eng.backspace();
                let bytes: Vec<u8> = eng.output().to_vec();
                emit(&mut out, "B", e.backspaces, e.out_type, &bytes);
            }
            Some('R') => {
                let e = eng.restore_key_strokes();
                let bytes: Vec<u8> = eng.output().to_vec();
                emit(&mut out, "R", e.backspaces, e.out_type, &bytes);
            }
            Some('L') => {
                let path = line[1..].trim();
                let ok = match std::fs::read(path) {
                    Ok(data) => {
                        // The original converts a legacy file in place
                        // after loading it, so the harness must too or
                        // the two engines end up reading different data.
                        let version = eng.macro_store.load_from_bytes(&data);
                        if version != 1 {
                            let _ = std::fs::write(path, eng.macro_store.to_utf8_file());
                        }
                        1
                    }
                    Err(_) => 0,
                };
                writeln!(out, "L {}", ok).unwrap();
            }
            Some('U') => {
                let path = line[1..].trim();
                let ok = match std::fs::read(path) {
                    Ok(data) => {
                        let map = skey_core::keymap::parse_key_map(&data);
                        eng.input.set_user_map(&map);
                        eng.reset();
                        1
                    }
                    Err(_) => 0,
                };
                writeln!(out, "U {}", ok).unwrap();
            }
            Some('T') => {
                let n = eng.macro_store.count();
                writeln!(out, "T {}", n).unwrap();
                for k in 0..n {
                    let kk = eng.macro_store.key(k).unwrap();
                    let tt = eng.macro_store.text(k).unwrap();
                    write!(out, "  key:").unwrap();
                    for c in kk { write!(out, " {:X}", c).unwrap(); }
                    write!(out, "\n  txt:").unwrap();
                    for c in tt { write!(out, " {:X}", c).unwrap(); }
                    writeln!(out).unwrap();
                }
            }
            Some('Z') => {
                eng.reset();
                writeln!(out, "Z").unwrap();
            }
            Some('S') => {
                eng.set_single_mode();
                writeln!(out, "S").unwrap();
            }
            Some('C') => {
                let p: Vec<i32> = line[1..]
                    .split_whitespace()
                    .filter_map(|s| s.parse().ok())
                    .collect();
                eng.set_caps_state(*p.first().unwrap_or(&0) != 0, *p.get(1).unwrap_or(&0) != 0);
                writeln!(out, "C").unwrap();
            }
            Some('-') => {
                eng.reset();
                writeln!(out, "--").unwrap();
            }
            _ => {}
        }
    }
}
