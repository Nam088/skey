//! User-defined key mapping parser and serializer.
//!
//! Operates directly on byte buffers, keeping the core engine pure and free of I/O operations.

use alloc::vec::Vec;

use crate::input::{self, EV_COUNT, NORMAL};
use crate::lexi_consts as L;

/// Event label list, declared once and used two ways: a match for the
/// forward direction, which rustc turns into a length switch and then a
/// jump table, and a flat slice for the reverse, which only the file
/// writer needs. One list means they cannot drift.
macro_rules! ev_labels {
    ($($lit:literal => $act:expr),* $(,)?) => {
        fn label_action(label: &[u8]) -> Option<u16> {
            match label {
                $($lit => Some($act),)*
                _ => None,
            }
        }

        const LABELS: &[(&[u8], u16)] = &[$(($lit, $act)),*];
    };
}

ev_labels! {
    b"Tone0" => input::TONE0,
    b"Tone1" => input::TONE1,
    b"Tone2" => input::TONE2,
    b"Tone3" => input::TONE3,
    b"Tone4" => input::TONE4,
    b"Tone5" => input::TONE5,
    b"Roof-All" => input::ROOF_ALL,
    b"Roof-A" => input::ROOF_A,
    b"Roof-E" => input::ROOF_E,
    b"Roof-O" => input::ROOF_O,
    b"Hook-Bowl" => input::HOOK_ALL,
    b"Hook-UO" => input::HOOK_UO,
    b"Hook-U" => input::HOOK_U,
    b"Hook-O" => input::HOOK_O,
    b"Bowl" => input::BOWL,
    b"D-Mark" => input::DD,
    b"Telex-W" => input::TELEX_W,
    b"Escape" => input::ESC_CHAR,
    b"DD" => EV_COUNT + L::DD.0 as u16,
    b"dd" => EV_COUNT + L::dd.0 as u16,
    b"A^" => EV_COUNT + L::Ar.0 as u16,
    b"a^" => EV_COUNT + L::ar.0 as u16,
    b"A(" => EV_COUNT + L::Ab.0 as u16,
    b"a(" => EV_COUNT + L::ab.0 as u16,
    b"E^" => EV_COUNT + L::Er.0 as u16,
    b"e^" => EV_COUNT + L::er.0 as u16,
    b"O^" => EV_COUNT + L::Or.0 as u16,
    b"o^" => EV_COUNT + L::or.0 as u16,
    b"O+" => EV_COUNT + L::Oh.0 as u16,
    b"o+" => EV_COUNT + L::oh.0 as u16,
    b"U+" => EV_COUNT + L::Uh.0 as u16,
    b"u+" => EV_COUNT + L::uh.0 as u16,
}

const COMMENT: u8 = b';';

/// `parseNameValue`: strips a trailing comment, then splits on the first
/// `=`, trimming spaces around both halves.
fn parse_name_value(line: &[u8]) -> Option<(&[u8], &[u8])> {
    let line = match line.iter().position(|&b| b == COMMENT) {
        Some(i) => &line[..i],
        None => line,
    };
    let mut p = 0;
    while p < line.len() && line[p] == b' ' {
        p += 1;
    }
    if p >= line.len() {
        return None;
    }
    let name_start = p;
    let mut mark = p; // last non space seen
    p += 1;
    while p < line.len() && line[p] != b'=' {
        if line[p] != b' ' {
            mark = p;
        }
        p += 1;
    }
    if p >= line.len() {
        return None; // no '=' at all
    }
    let name = &line[name_start..mark + 1];

    p += 1;
    while p < line.len() && line[p] == b' ' {
        p += 1;
    }
    if p >= line.len() {
        return None;
    }
    let value_start = p;
    let mut vmark = p;
    while p < line.len() {
        if line[p] != b' ' {
            vmark = p;
        }
        p += 1;
    }
    Some((name, &line[value_start..vmark + 1]))
}

/// One accepted mapping, in file order.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct KeyMapPair {
    /// ASCII character / key code being mapped.
    pub key: u8,
    /// Action or character mapped to this key.
    pub action: u16,
}

/// Every action fits in a byte, see `input::MAX_ACTION`.
#[inline]
fn as_action_byte(a: u16) -> u8 {
    debug_assert!(a <= crate::input::MAX_ACTION);
    a as u8
}

/// Parses user-defined key mappings from raw configuration file bytes in file order.
///
/// A key that is already assigned is silently rejected, and an unknown label is skipped.
///
/// ### Arguments
///
/// - `data`: Raw bytes of the keymap configuration file (lines formatted as `key = action`).
///
/// ### Returns
///
/// Returns a [`Vec<KeyMapPair>`] preserving the order of parsed definitions.
///
/// ### Examples
///
/// ```
/// use skey_core::extensions::keymap::parse_order_map;
///
/// let config = b"s = Tone1\nf = Tone2\n";
/// let pairs = parse_order_map(config);
/// assert_eq!(pairs.len(), 2);
/// ```
pub fn parse_order_map(data: &[u8]) -> Vec<KeyMapPair> {
    let mut key_map = [NORMAL; 256];
    let mut out: Vec<KeyMapPair> = Vec::new();

    for raw in data.split(|&b| b == b'\n') {
        let mut line = raw;
        if line.last() == Some(&b'\r') {
            line = &line[..line.len() - 1];
        }
        let (name, value) = match parse_name_value(line) {
            Some(x) => x,
            None => continue,
        };
        if name.len() != 1 {
            continue;
        }
        let action = match label_action(value) {
            Some(a) => a,
            None => continue,
        };
        let c = name[0];
        if key_map[c as usize] != NORMAL {
            // already assigned, do not accept this map
            continue;
        }
        key_map[c as usize] = action;
        if action < EV_COUNT {
            let up = c.to_ascii_uppercase();
            key_map[up as usize] = action;
            out.push(KeyMapPair { key: up, action });
        } else {
            out.push(KeyMapPair { key: c, action });
        }
    }
    out
}

/// The order map collapsed into the 256 entry table the
/// input processor uses.
///
/// Action keys apply to both cases; character mappings carry their own case.
///
/// ### Arguments
///
/// - `data`: Raw bytes of the keymap configuration file.
///
/// ### Returns
///
/// A `[u8; 256]` array mapping each ASCII byte value to its corresponding action code.
///
/// ### Examples
///
/// ```
/// use skey_core::extensions::keymap::parse_key_map;
/// use skey_core::input::TONE1;
///
/// let config = b"s = Tone1\n";
/// let map = parse_key_map(config);
/// assert_eq!(map[b's' as usize], TONE1 as u8);
/// assert_eq!(map[b'S' as usize], TONE1 as u8);
/// ```
pub fn parse_key_map(data: &[u8]) -> [u8; 256] {
    let mut map = [NORMAL as u8; 256];
    for p in parse_order_map(data) {
        map[p.key as usize] = as_action_byte(p.action);
        if p.action < EV_COUNT {
            map[p.key.to_ascii_lowercase() as usize] = as_action_byte(p.action);
        }
    }
    map
}

/// Stores key order map into string formatted as a standard SKey configuration file.
///
/// ### Arguments
///
/// - `pairs`: Slice of [`KeyMapPair`] items to serialize.
///
/// ### Returns
///
/// Returns a formatted [`String`] containing comments and `key = action` entries.
///
/// ### Examples
///
/// ```
/// use skey_core::extensions::keymap::{write_order_map, KeyMapPair};
/// use skey_core::input::TONE1;
///
/// let pairs = [KeyMapPair { key: b's', action: TONE1 }];
/// let text = write_order_map(&pairs);
/// assert!(text.contains("s = Tone1"));
/// ```
pub fn write_order_map(pairs: &[KeyMapPair]) -> alloc::string::String {
    use alloc::string::String;
    let mut s = String::from(
        "; SKey user-defined key mapping file\n\n",
    );
    for p in pairs {
        if let Some(label) = action_label(p.action) {
            s.push(p.key as char);
            s.push_str(" = ");
            s.push_str(label);
            s.push('\n');
        }
    }
    s
}

fn action_label(action: u16) -> Option<&'static str> {
    LABELS
        .iter()
        .find(|(_, a)| *a == action)
        .and_then(|(l, _)| core::str::from_utf8(l).ok())
}
