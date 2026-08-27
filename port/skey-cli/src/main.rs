use std::io::{self, IsTerminal, Read, Write};
use std::process::Command;
use skey_core::charset::{self, Charset};
use skey_core::input::{IM_TELEX, IM_VIQR, IM_VNI};
use skey_core::{Engine, Options};

/// RAII Guard to ensure terminal raw mode is properly restored on exit or panic.
struct RawTerminalGuard {
    active: bool,
}

impl RawTerminalGuard {
    fn enter() -> Self {
        let is_tty = io::stdin().is_terminal();
        if is_tty {
            // Set raw mode without echo, reading byte by byte immediately
            let _ = Command::new("stty").args(["-echo", "-icanon", "min", "1", "time", "0"]).status();
        }
        RawTerminalGuard { active: is_tty }
    }
}

impl Drop for RawTerminalGuard {
    fn drop(&mut self) {
        if self.active {
            // Restore normal terminal mode
            let _ = Command::new("stty").arg("sane").status();
        }
    }
}

fn im_name(im: i32) -> &'static str {
    match im {
        IM_TELEX => "Telex",
        IM_VNI => "VNI",
        IM_VIQR => "VIQR",
        _ => "Custom",
    }
}

fn print_banner(eng: &Engine) {
    println!("\x1b[1;36m=====================================================\x1b[0m");
    println!("\x1b[1;32m  UniKey Terminal REPL (Rust Version) \x1b[0m");
    println!("\x1b[1;36m=====================================================\x1b[0m");
    println!("  Phím tắt điều khiển:");
    println!("    \x1b[1;33mCtrl + V\x1b[0m hoặc \x1b[1;33mCtrl + E\x1b[0m : Bật / Tắt gõ Tiếng Việt");
    println!("    \x1b[1;33mCtrl + T\x1b[0m             : Đổi kiểu gõ (Telex ⇄ VNI ⇄ VIQR)");
    println!("    \x1b[1;33mCtrl + C\x1b[0m / \x1b[1;33mCtrl + D\x1b[0m  : Thoát chương trình");
    println!("-----------------------------------------------------");
    print_status(eng);
    println!("-----------------------------------------------------\x1b[0m");
    println!("Bắt đầu gõ trực tiếp bên dưới:\r\n");
}

fn print_status(eng: &Engine) {
    let mode_str = if eng.viet_key {
        "\x1b[1;32m[VIỆT NAM: BẬT]\x1b[0m"
    } else {
        "\x1b[1;31m[ENGLISH: TẮT]\x1b[0m"
    };
    let im_str = im_name(eng.input.im());
    print!("\r\n\x1b[1;34m[Trạng thái]\x1b[0m {mode_str} | Kiểu gõ: \x1b[1;33m{im_str}\x1b[0m | Bảng mã: \x1b[1;35mUTF-8\x1b[0m\r\n> ");
    let _ = io::stdout().flush();
}

fn run_interactive() -> io::Result<()> {
    let _guard = RawTerminalGuard::enter();

    // Hook panic to restore terminal cleanly
    let default_hook = std::panic::take_hook();
    std::panic::set_hook(Box::new(move |info| {
        let _ = Command::new("stty").arg("sane").status();
        default_hook(info);
    }));

    let mut eng = Engine::new();
    eng.set_input_method(IM_TELEX);
    eng.set_charset(Charset(charset::XUTF8));
    eng.options = Options::default();
    eng.viet_key = true;

    print_banner(&eng);
    let mut stdout = io::stdout();
    let mut stdin = io::stdin().lock();
    let mut buf = [0u8; 1];

    while stdin.read_exact(&mut buf).is_ok() {
        let b = buf[0];

        // Handle Control characters
        match b {
            // Ctrl+C (0x03) or Ctrl+D (0x04)
            0x03 | 0x04 => {
                println!("\r\n\x1b[1;33mTạm biệt!\x1b[0m\r");
                break;
            }
            // Ctrl+V (0x16) or Ctrl+E (0x05): Toggle Vietnamese
            0x16 | 0x05 => {
                eng.viet_key = !eng.viet_key;
                eng.reset();
                print_status(&eng);
                continue;
            }
            // Ctrl+T (0x14): Switch Input Method
            0x14 => {
                let next_im = match eng.input.im() {
                    IM_TELEX => IM_VNI,
                    IM_VNI => IM_VIQR,
                    _ => IM_TELEX,
                };
                eng.set_input_method(next_im);
                print_status(&eng);
                continue;
            }
            // Enter (\r or \n)
            b'\r' | b'\n' => {
                eng.pass(b'\n' as u32);
                eng.reset();
                print!("\r\n");
                let _ = stdout.flush();
                continue;
            }
            // Tab (\t)
            b'\t' => {
                eng.reset();
                print!("\t");
                let _ = stdout.flush();
                continue;
            }
            // Backspace (0x7F or 0x08)
            0x7F | 0x08 => {
                let edit = eng.backspace();
                if edit.handled {
                    if edit.backspaces > 0 {
                        for _ in 0..edit.backspaces {
                            print!("\x08 \x08");
                        }
                    }
                    if !eng.output().is_empty() {
                        let _ = stdout.write_all(eng.output());
                    }
                } else {
                    // Normal backspace: erase 1 cell
                    print!("\x08 \x08");
                }
                let _ = stdout.flush();
                continue;
            }
            // Escape (0x1B)
            0x1B => {
                eng.reset();
                continue;
            }
            // Regular printable byte
            _ => {
                let edit = eng.key(b as u32);
                if edit.handled {
                    if edit.backspaces > 0 {
                        for _ in 0..edit.backspaces {
                            print!("\x08 \x08");
                        }
                    }
                    let _ = stdout.write_all(eng.output());
                } else {
                    // Print raw byte
                    let _ = stdout.write_all(&[b]);
                }
                let _ = stdout.flush();
            }
        }
    }

    Ok(())
}

/// Helper function to pop N unicode characters from a String
fn pop_chars(s: &mut String, n: usize) {
    for _ in 0..n {
        s.pop();
    }
}

fn run_stream() -> io::Result<()> {
    let mut eng = Engine::new();
    eng.set_input_method(IM_TELEX);
    eng.set_charset(Charset(charset::XUTF8));
    eng.options = Options::default();
    eng.viet_key = true;

    let stdin = io::stdin();
    let mut handle = stdin.lock();
    let mut stdout = io::stdout();
    let mut buf = [0u8; 1024];
    let mut line_buf = String::new();

    while let Ok(n) = handle.read(&mut buf) {
        if n == 0 {
            break;
        }
        for &b in &buf[..n] {
            if b == b'\n' || b == b'\r' {
                eng.pass(b as u32);
                eng.reset();
                line_buf.push(b as char);
                let _ = stdout.write_all(line_buf.as_bytes());
                line_buf.clear();
            } else if b == 0x7F || b == 0x08 {
                let edit = eng.backspace();
                if edit.handled {
                    pop_chars(&mut line_buf, edit.backspaces as usize);
                    if let Ok(s) = std::str::from_utf8(eng.output()) {
                        line_buf.push_str(s);
                    }
                } else {
                    pop_chars(&mut line_buf, 1);
                }
            } else {
                let edit = eng.key(b as u32);
                if edit.handled {
                    pop_chars(&mut line_buf, edit.backspaces as usize);
                    if let Ok(s) = std::str::from_utf8(eng.output()) {
                        line_buf.push_str(s);
                    }
                } else {
                    line_buf.push(b as char);
                }
            }
        }
    }
    if !line_buf.is_empty() {
        let _ = stdout.write_all(line_buf.as_bytes());
    }
    let _ = stdout.flush();
    Ok(())
}

fn main() -> io::Result<()> {
    if io::stdin().is_terminal() {
        run_interactive()
    } else {
        run_stream()
    }
}
