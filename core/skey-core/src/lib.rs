//! Vietnamese input method engine: a port of the UniKey core.
//!
//! Phase one goal is byte for byte behavioural parity with the original
//! C++ engine, verified by the differential harness in `port/oracle`.
//! Optimisation follows parity, never the other way round.
#![cfg_attr(not(feature = "std"), no_std)]
#![forbid(unsafe_code)]

// The keystroke path never allocates and works with no allocator at all.
// The macro table, the key map parser and the charset decoders do, and
// live behind the `alloc` feature.
#[cfg(feature = "alloc")]
extern crate alloc;

// 4 Primary Domain Packages:
pub mod charset;
pub mod engine;
pub mod extensions;
pub mod input;
pub mod phonetics;

// Core Infrastructure:
pub mod limits;
pub mod out;
#[cfg(feature = "testkit")]
#[doc(hidden)]
pub mod testkit;

// Backwards compatibility re-exports so no downstream caller breaks:
pub use charset::Charset;
pub use engine::{Edit, Engine, Options, OutputType};

pub use extensions::enwords;
#[cfg(feature = "alloc")]
pub use extensions::keymap;
#[cfg(feature = "alloc")]
pub use extensions::macros;
pub use extensions::quick;
#[cfg(feature = "alloc")]
pub use extensions::calc;

pub use phonetics::lexi;
pub use phonetics::seq;
pub use phonetics::tables;
#[allow(unused_imports)]
mod lexi_consts {
    pub use crate::phonetics::lexi_consts::*;
}
