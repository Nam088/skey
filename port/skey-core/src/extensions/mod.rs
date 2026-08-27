//! Add-on features: swallowed word restoration, quick typing shortcuts, macros, and user keymaps.

pub mod enwords;
pub mod quick;
#[cfg(feature = "alloc")]
pub mod macros;
#[cfg(feature = "alloc")]
pub mod keymap;
