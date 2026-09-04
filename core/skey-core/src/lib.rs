//! # `skey-core` - Bộ gõ tiếng Việt hiệu năng cao, zero-allocation
//!
//! `skey-core` là lõi xử lý phím (keystroke state machine) của bộ gõ tiếng Việt SKey,
//! được tối ưu hóa cho macOS và các hệ thống nhúng/WASM:
//!
//! - **Zero-allocation on hot path**: Xử lý gõ phím thông thường (`Engine::key`, `Engine::backspace`)
//!   hoàn toàn không cấp phát bộ nhớ động trên heap (hỗ trợ môi trường `no_std`).
//! - **Đầy đủ phương pháp gõ**: Telex, VNI, VIQR, Microsoft Vietnamese layout, Simple Telex, và bản đồ phím tuỳ biến (user-defined keymaps).
//! - **Hỗ trợ đa bảng mã (Charsets)**: Unicode (UTF-8, UTF-16, NFD tổ hợp, Numeric reference, C-string escape),
//!   TCVN3 (ABC), VNI Windows, VIQR, VISCII, VPS, BK HCM 1/2, Vietware X/F, Windows CP1258.
//! - **Linh hoạt cấu hình**: Đặt dấu tự do / kiểu mới (`òa`/`oà`), kiểm tra chính tả phonotactic,
//!   khôi phục từ tiếng Anh bị nuốt phím (`pass` thay vì `pas`), gõ tắt phụ âm nhanh (`f` -> `ph`, `g` -> `ng`),
//!   Quick Telex (`cc` -> `ch`, `uu` -> `ươ`), mở rộng macro, và bộ tính toán biểu thức toán học.
//!
//! # Cấu trúc Module
//!
//! - [`engine`]: Cỗ máy trạng thái chính ([`Engine`]), quản lý bộ đệm từ, bộ đếm lùi ([`Edit`]), và điều phối biến đổi.
//! - [`phonetics`]: Bảng quy tắc ngôn ngữ âm học tiếng Việt (âm đầu, nguyên âm, âm cuối, dấu thanh, và vị trí dấu).
//! - [`charset`]: Bộ mã hóa và đếm ký tự cho các bảng mã tiếng Việt khác nhau ([`Charset`]).
//! - [`input`]: Phân loại mã phím và bản đồ phương thức gõ ([`input::InputProcessor`]).
//! - [`extensions`]: Các tính năng bổ sung: gõ tắt ([`quick`]), mở rộng macro ([`macros`]),
//!   từ điển khôi phục từ tiếng Anh ([`enwords`]), nạp keymap ([`keymap`]), và bộ tính toán ([`calc`]).
//! - [`out`]: Bộ đệm đầu ra cố định ([`out::OutBuf`]) và trait sink ([`out::Sink`]).
//! - [`limits`]: Các hằng số giới hạn dung lượng bộ đệm, macro, và hàm case folding.
//!
//! # Ví dụ sử dụng cơ bản
//!
//! ```
//! use skey_core::{Engine, Options, Charset};
//! use skey_core::input::IM_TELEX;
//!
//! let mut engine = Engine::new();
//! engine.set_input_method(IM_TELEX);
//!
//! // Gõ chuỗi "vieetj" -> "việt"
//! #[cfg(feature = "alloc")]
//! {
//!     let result = engine.type_str("vieetj");
//!     assert_eq!(result, "việt");
//! }
//! ```
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
