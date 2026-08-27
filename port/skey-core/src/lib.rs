//! Vietnamese input method engine: a port of the UniKey core.
//!
//! Phase one goal is byte for byte behavioural parity with the original
//! C++ engine, verified by the differential harness in `port/oracle`.
//! Optimisation follows parity, never the other way round.
#![cfg_attr(not(test), no_std)]
#![forbid(unsafe_code)]

// The keystroke path never allocates and works with no allocator at all.
// The macro table, the key map parser and the charset decoders do, and
// live behind the `alloc` feature.
#[cfg(feature = "alloc")]
extern crate alloc;

pub mod charset;
pub mod engine;
pub mod enwords;
pub mod input;
#[cfg(feature = "alloc")]
pub mod keymap;
pub mod lexi;
pub mod limits;
#[cfg(feature = "alloc")]
pub mod macros;
mod lexi_consts;
pub mod out;
pub mod quick;
pub mod seq;
#[cfg(feature = "testkit")]
#[doc(hidden)]
pub mod testkit;
// Tables for charsets that are not ported yet are carried here so the
// generator stays a single pass; they light up as those charsets land.
#[rustfmt::skip]
#[allow(dead_code)]
mod tables;

pub use charset::Charset;
pub use engine::{Edit, Engine, Options, OutputType};
