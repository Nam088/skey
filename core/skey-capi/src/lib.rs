//! SKey - Bộ gõ tiếng Việt macOS (C FFI).
//!
//! Exposes functions and global buffers for integration with external
//! display servers, UI toolkits, and platform input modules.
//!
//! Globals across an FFI boundary have to be real symbols, so unsafe
//! lives here and nowhere else.
#![allow(non_snake_case)]

use core::cell::UnsafeCell;
use std::ffi::CStr;
use std::os::raw::{c_char, c_int, c_uint};

use skey_core::charset::Charset;
use skey_core::engine::OutputType;
use skey_core::{keymap, Engine, Options};

/// Buffer capacity (1024 bytes).
pub const SKEY_BUF_SIZE: usize = 1024;

/// `static mut` is deprecated in the 2024 edition and taking a reference
/// to one is already a lint, but a `#[no_mangle]` mutable C symbol has to
/// be a real global. This wrapper is the way out: the symbol keeps the
/// layout C expects, and access goes through a raw pointer so no Rust
/// reference to a mutable static is ever created.
#[repr(transparent)]
pub struct Global<T>(UnsafeCell<T>);

unsafe impl<T> Sync for Global<T> {}

impl<T> Global<T> {
    const fn new(v: T) -> Self {
        Global(UnsafeCell::new(v))
    }
    #[inline]
    fn ptr(&self) -> *mut T {
        self.0.get()
    }
}

/// Global buffer holding the latest transformed output bytes.
#[no_mangle]
pub static SKeyBuf: Global<[u8; SKEY_BUF_SIZE]> = Global::new([0; SKEY_BUF_SIZE]);

/// Global count of backspaces the front-end must send before emitting `SKeyBuf`.
#[no_mangle]
pub static SKeyBackspaces: Global<c_int> = Global::new(0);

/// Global count of characters currently written in `SKeyBuf`.
#[no_mangle]
pub static SKeyBufChars: Global<c_int> = Global::new(0);

/// Global output type flag (`0` for characters, `1` for raw keystrokes).
#[no_mangle]
pub static SKeyOutput: Global<c_int> = Global::new(0);

static ENGINE: Global<Option<Engine>> = Global::new(None);

/// Configuration options struct for C ABI interoperability.
#[repr(C)]
#[derive(Clone, Copy)]
pub struct SKeyOptions {
    /// Allows placing accent marks on vowels anywhere in the word.
    pub freeMarking: c_int,
    /// Places tone mark on the second vowel for `oa`, `oe`, `uy`.
    pub modernStyle: c_int,
    /// Enables or disables macro replacement expansion.
    pub macroEnabled: c_int,
    /// Reserved for clipboard operations.
    pub useUnicodeClipboard: c_int,
    /// Reserved option for macro execution.
    pub alwaysMacro: c_int,
    /// Strict Vietnamese spelling verification.
    pub strictSpellCheck: c_int,
    /// Reserved IME flag.
    pub useIME: c_int,
    /// General spelling check enabled.
    pub spellCheckEnabled: c_int,
    /// Automatically restores raw keystrokes if the word is non-Vietnamese.
    pub autoNonVnRestore: c_int,
}

fn eng() -> &'static mut Engine {
    unsafe {
        let p = ENGINE.ptr();
        if (*p).is_none() {
            *p = Some(Engine::new());
        }
        (*p).as_mut().unwrap()
    }
}

fn publish(edit: skey_core::Edit) {
    let e = eng();
    let bytes = e.output();
    let n = bytes.len().min(SKEY_BUF_SIZE);
    unsafe {
        core::ptr::copy_nonoverlapping(bytes.as_ptr(), SKeyBuf.ptr().cast::<u8>(), n);
        *SKeyBufChars.ptr() = e.output_len() as c_int;
        *SKeyBackspaces.ptr() = edit.backspaces as c_int;
        *SKeyOutput.ptr() = match edit.out_type {
            OutputType::Char => 0,
            OutputType::Key => 1,
        };
    }
}

/// Initializes the global SKey engine instance with default settings (Telex, UTF-8).
///
/// Always call this before calling any other global `skey_*` functions.
///
/// ### Arguments
///
/// None.
///
/// ### Returns
///
/// Returns `()`. The global engine is created or re-initialized in place.
///
/// ### Examples
///
/// ```rust,ignore
/// skey_setup();
/// ```
#[no_mangle]
pub extern "C" fn skey_setup() {
    unsafe {
        *ENGINE.ptr() = Some(Engine::new());
    }
    let e = eng();
    e.viet_key = true;
    e.set_input_method(skey_core::input::IM_TELEX);
    e.set_charset(Charset(skey_core::charset::XUTF8));
    e.options = Options::default();
}

/// Cleans up and releases the global SKey engine instance.
///
/// Releases internal heap memory associated with the global engine.
///
/// ### Arguments
///
/// None.
///
/// ### Returns
///
/// Returns `()`.
///
/// ### Examples
///
/// ```rust,ignore
/// skey_cleanup();
/// ```
#[no_mangle]
pub extern "C" fn skey_cleanup() {
    unsafe {
        *ENGINE.ptr() = None;
    }
}

/// Resets the global engine's word buffer and state machine.
///
/// Discards currently tracked syllables and buffered keys without clearing configuration.
///
/// ### Arguments
///
/// None.
///
/// ### Returns
///
/// Returns `()`.
///
/// ### Examples
///
/// ```rust,ignore
/// skey_reset_buf();
/// ```
#[no_mangle]
pub extern "C" fn skey_reset_buf() {
    eng().reset();
}

/// Main keystroke filter: processes incoming character code through the global engine.
///
/// Updates the global output variables [`SKeyBuf`], [`SKeyBufChars`], [`SKeyBackspaces`], and [`SKeyOutput`].
///
/// ### Arguments
///
/// * `ch` - Unicode scalar value or ASCII keycode to process.
///
/// ### Returns
///
/// Returns `()`. Transformed text and backspace count are published to global variables.
///
/// ### Examples
///
/// ```rust,ignore
/// skey_setup();
/// skey_filter('a' as u32);
/// skey_filter('s' as u32); // 'as' -> 'á' in Telex
/// ```
#[no_mangle]
pub extern "C" fn skey_filter(ch: c_uint) {
    let edit = eng().key(ch);
    publish(edit);
}

/// Passes a raw character code directly into the buffer without transformation.
///
/// Useful for non-printable keys, numbers, or punctuation that should break syllables.
/// Clears [`SKeyBufChars`] and [`SKeyBackspaces`] to 0.
///
/// ### Arguments
///
/// * `ch` - Character code to insert into the buffer.
///
/// ### Returns
///
/// Returns `()`.
///
/// ### Examples
///
/// ```rust,ignore
/// skey_put_char(' ' as u32);
/// ```
#[no_mangle]
pub extern "C" fn skey_put_char(ch: c_uint) {
    eng().pass(ch);
    unsafe {
        *SKeyBufChars.ptr() = 0;
        *SKeyBackspaces.ptr() = 0;
    }
}

/// Updates Shift and CapsLock modifier state in the global engine.
///
/// ### Arguments
///
/// * `shiftPressed` - Non-zero if Shift key is currently held down, `0` otherwise.
/// * `CapsLockOn` - Non-zero if Caps Lock toggle is active, `0` otherwise.
///
/// ### Returns
///
/// Returns `()`.
///
/// ### Examples
///
/// ```rust,ignore
/// skey_set_caps_state(1, 0); // Shift active
/// ```
#[no_mangle]
pub extern "C" fn skey_set_caps_state(shiftPressed: c_int, CapsLockOn: c_int) {
    eng().set_caps_state(shiftPressed != 0, CapsLockOn != 0);
}

/// Processes a backspace key press in the global engine.
///
/// Adjusts internal syllable state machine and updates global output variables.
///
/// ### Arguments
///
/// None.
///
/// ### Returns
///
/// Returns `()`.
///
/// ### Examples
///
/// ```rust,ignore
/// skey_backspace_press();
/// ```
#[no_mangle]
pub extern "C" fn skey_backspace_press() {
    let edit = eng().backspace();
    publish(edit);
}

/// Restores the raw keystrokes of the current word in the global engine.
///
/// Undoes Vietnamese diacritic transformations in the active word, restoring the original keys typed.
///
/// ### Arguments
///
/// None.
///
/// ### Returns
///
/// Returns `()`.
///
/// ### Examples
///
/// ```rust,ignore
/// skey_restore_key_strokes();
/// ```
#[no_mangle]
pub extern "C" fn skey_restore_key_strokes() {
    let edit = eng().restore_key_strokes();
    publish(edit);
}

/// Temporarily switches off spell-checking and diacritic transformation for the current word.
///
/// ### Arguments
///
/// None.
///
/// ### Returns
///
/// Returns `()`.
///
/// ### Examples
///
/// ```rust,ignore
/// skey_set_single_mode();
/// ```
#[no_mangle]
pub extern "C" fn skey_set_single_mode() {
    eng().set_single_mode();
}

/// Initializes an [`SKeyOptions`] struct with default engine options.
///
/// Populates the struct with the standard engine configuration defaults:
/// `freeMarking = 1`, `spellCheckEnabled = 1`, all other flags set to `0`.
///
/// ### Arguments
///
/// * `pOpt` - Pointer to an [`SKeyOptions`] struct to receive the default values.
///
/// ### Returns
///
/// Returns `()`. If `pOpt` is null, does nothing.
///
/// ### Safety
///
/// If non-null, `pOpt` must point to valid writable [`SKeyOptions`] memory.
///
/// ### Examples
///
/// ```rust,ignore
/// let mut opts = std::mem::MaybeUninit::<skey_capi::SKeyOptions>::uninit();
/// unsafe {
///     skey_create_default_options(opts.as_mut_ptr());
///     let opts = opts.assume_init();
///     assert_eq!(opts.freeMarking, 1);
/// }
/// ```
#[no_mangle]
pub unsafe extern "C" fn skey_create_default_options(pOpt: *mut SKeyOptions) {
    if pOpt.is_null() {
        return;
    }
    let d = Options::default();
    (*pOpt).freeMarking = d.free_marking as c_int;
    (*pOpt).modernStyle = d.modern_style as c_int;
    (*pOpt).macroEnabled = d.macro_enabled as c_int;
    (*pOpt).useUnicodeClipboard = d.use_unicode_clipboard as c_int;
    (*pOpt).alwaysMacro = d.always_macro as c_int;
    (*pOpt).spellCheckEnabled = d.spell_check_enabled as c_int;
    (*pOpt).autoNonVnRestore = d.auto_non_vn_restore as c_int;
}

/// Applies configuration options to the global engine.
///
/// ### Arguments
///
/// * `pOpt` - Pointer to a populated [`SKeyOptions`] struct containing settings to apply.
///
/// ### Returns
///
/// Returns `()`. If `pOpt` is null, does nothing.
///
/// ### Safety
///
/// If non-null, `pOpt` must point to a valid, readable [`SKeyOptions`] struct.
///
/// ### Examples
///
/// ```rust,ignore
/// let mut opts = std::mem::MaybeUninit::<skey_capi::SKeyOptions>::uninit();
/// unsafe {
///     skey_create_default_options(opts.as_mut_ptr());
///     let mut opts = opts.assume_init();
///     opts.modernStyle = 1;
///     skey_set_options(&opts);
/// }
/// ```
#[no_mangle]
pub unsafe extern "C" fn skey_set_options(pOpt: *const SKeyOptions) {
    if pOpt.is_null() {
        return;
    }
    let o = *pOpt;
    let e = eng();
    e.options.free_marking = o.freeMarking != 0;
    e.options.modern_style = o.modernStyle != 0;
    e.options.macro_enabled = o.macroEnabled != 0;
    e.options.use_unicode_clipboard = o.useUnicodeClipboard != 0;
    e.options.always_macro = o.alwaysMacro != 0;
    e.options.spell_check_enabled = o.spellCheckEnabled != 0;
    e.options.auto_non_vn_restore = o.autoNonVnRestore != 0;
}

/// Reads the current configuration options from the global engine.
///
/// ### Arguments
///
/// * `pOpt` - Pointer to an [`SKeyOptions`] struct to receive the current engine options.
///
/// ### Returns
///
/// Returns `()`. If `pOpt` is null, does nothing.
///
/// ### Safety
///
/// If non-null, `pOpt` must point to valid writable [`SKeyOptions`] memory.
///
/// ### Examples
///
/// ```rust,ignore
/// let mut opts = std::mem::MaybeUninit::<skey_capi::SKeyOptions>::uninit();
/// unsafe {
///     skey_get_options(opts.as_mut_ptr());
///     let opts = opts.assume_init();
///     println!("Free marking: {}", opts.freeMarking);
/// }
/// ```
#[no_mangle]
pub unsafe extern "C" fn skey_get_options(pOpt: *mut SKeyOptions) {
    if pOpt.is_null() {
        return;
    }
    let o = eng().options;
    (*pOpt).freeMarking = o.free_marking as c_int;
    (*pOpt).modernStyle = o.modern_style as c_int;
    (*pOpt).macroEnabled = o.macro_enabled as c_int;
    (*pOpt).useUnicodeClipboard = o.use_unicode_clipboard as c_int;
    (*pOpt).alwaysMacro = o.always_macro as c_int;
    (*pOpt).strictSpellCheck = o.strict_spell_check as c_int;
    (*pOpt).useIME = 0;
    (*pOpt).spellCheckEnabled = o.spell_check_enabled as c_int;
    (*pOpt).autoNonVnRestore = o.auto_non_vn_restore as c_int;
}

/// Sets the active input method (Telex, VNI, VIQR, etc.) for the global engine.
///
/// ### Arguments
///
/// * `im` - Input method identifier (e.g. `0` for Telex, `1` for VNI, `2` for VIQR, `4` for User custom map).
///
/// ### Returns
///
/// Returns `()`.
///
/// ### Examples
///
/// ```rust,ignore
/// skey_set_input_method(0); // Telex
/// ```
#[no_mangle]
pub extern "C" fn skey_set_input_method(im: c_int) {
    use skey_core::input::{IM_TELEX, IM_USR, IM_VIQR, IM_VNI};
    let e = eng();
    if im == IM_TELEX || im == IM_VNI || im == IM_VIQR {
        e.set_input_method(im);
    } else if im == IM_USR {
        if let Some(map) = user_map() {
            e.input.set_user_map(map);
            e.reset();
        }
    }
}

/// Sets the output character encoding for the global engine.
///
/// ### Arguments
///
/// * `charset` - Integer identifier of character set (e.g. `12` for Unicode UTF-8, `0` for TCVN3).
///
/// ### Returns
///
/// Returns `1` on successful configuration.
///
/// ### Examples
///
/// ```rust,ignore
/// assert_eq!(skey_set_output_charset(12), 1); // UTF-8
/// ```
#[no_mangle]
pub extern "C" fn skey_set_output_charset(charset: c_int) -> c_int {
    eng().set_charset(Charset(charset));
    1
}

/// Loads a macro table from the specified file path into the global engine.
///
/// ### Arguments
///
/// * `fileName` - Pointer to a null-terminated UTF-8 C string containing the filesystem path.
///
/// ### Returns
///
/// Returns `1` on success, or `0` if `fileName` is null, unreadable, or file reading failed.
///
/// ### Safety
///
/// `fileName` must be a valid, readable null-terminated C string.
///
/// ### Examples
///
/// ```rust,ignore
/// let path = std::ffi::CString::new("/path/to/macro.txt").unwrap();
/// unsafe {
///     let ok = skey_load_macro_table(path.as_ptr());
///     assert!(ok == 1 || ok == 0);
/// }
/// ```
#[no_mangle]
pub unsafe extern "C" fn skey_load_macro_table(fileName: *const c_char) -> c_int {
    let path = match cstr(fileName) {
        Some(p) => p,
        None => return 0,
    };
    let data = match std::fs::read(&path) {
        Ok(d) => d,
        Err(_) => return 0,
    };
    let e = eng();
    let version = e.macro_store.load_from_bytes(&data);
    if version != 1 {
        let _ = std::fs::write(&path, e.macro_store.to_utf8_file());
    }
    1
}

/// Loads a user key mapping file from disk into the global engine.
///
/// ### Arguments
///
/// * `fileName` - Pointer to a null-terminated UTF-8 C string containing the filesystem path to keymap.
///
/// ### Returns
///
/// Returns `1` on success, or `0` if `fileName` is null, invalid, or file read fails.
///
/// ### Safety
///
/// `fileName` must be a valid, readable null-terminated C string.
///
/// ### Examples
///
/// ```rust,ignore
/// let path = std::ffi::CString::new("/path/to/keymap.txt").unwrap();
/// unsafe {
///     let ok = skey_load_user_key_map(path.as_ptr());
///     assert!(ok == 1 || ok == 0);
/// }
/// ```
#[no_mangle]
pub unsafe extern "C" fn skey_load_user_key_map(fileName: *const c_char) -> c_int {
    let path = match cstr(fileName) {
        Some(p) => p,
        None => return 0,
    };
    let data = match std::fs::read(path) {
        Ok(d) => d,
        Err(_) => return 0,
    };
    set_user_map(keymap::parse_key_map(&data));
    1
}

fn cstr(p: *const c_char) -> Option<String> {
    if p.is_null() {
        return None;
    }
    unsafe { CStr::from_ptr(p) }.to_str().ok().map(str::to_owned)
}

static USER_MAP: Global<Option<[u8; 256]>> = Global::new(None);

fn user_map() -> Option<&'static [u8; 256]> {
    unsafe { (*USER_MAP.ptr()).as_ref() }
}

fn set_user_map(m: [u8; 256]) {
    unsafe {
        *USER_MAP.ptr() = Some(m);
    }
}

/// Sets the active input method directly by integer ID on the global engine.
///
/// Unlike [`skey_set_input_method`], does not perform method validation check and immediately resets engine state.
///
/// ### Arguments
///
/// * `im` - Raw input method ID integer.
///
/// ### Returns
///
/// Returns `()`.
///
/// ### Examples
///
/// ```rust,ignore
/// skey_set_input_method_raw(0);
/// ```
#[no_mangle]
pub extern "C" fn skey_set_input_method_raw(im: c_int) {
    let e = eng();
    e.input.set_im(im);
    e.reset();
}

/// Returns the total count of macros loaded in the global engine.
///
/// ### Arguments
///
/// None.
///
/// ### Returns
///
/// Returns the number of active macro definitions as a `c_int`.
///
/// ### Examples
///
/// ```rust,ignore
/// let count = skey_macro_count();
/// println!("Loaded macros: {}", count);
/// ```
#[no_mangle]
pub extern "C" fn skey_macro_count() -> c_int {
    eng().macro_store.count() as c_int
}

/// Retrieves the macro trigger key (`which == 0`) or replacement text (`which == 1`) at `idx`.
///
/// Copies character codes as `c_uint` into the destination buffer `buf`.
///
/// ### Arguments
///
/// * `idx` - Zero-based index of the macro item.
/// * `which` - `0` for macro trigger key, `1` for macro replacement expansion text.
/// * `buf` - Destination array of `c_uint` elements.
/// * `max` - Capacity of `buf` in elements.
///
/// ### Returns
///
/// Returns the number of characters copied into `buf`, or `0` on error or out-of-bounds index.
///
/// ### Safety
///
/// `buf` must point to a valid writable memory buffer of at least `max` `c_uint` elements.
///
/// ### Examples
///
/// ```rust,ignore
/// let mut buf = [0u32; 64];
/// unsafe {
///     let len = skey_macro_get(0, 0, buf.as_mut_ptr(), 64);
///     println!("Macro 0 key length: {}", len);
/// }
/// ```
#[no_mangle]
pub unsafe extern "C" fn skey_macro_get(
    idx: c_int,
    which: c_int,
    buf: *mut c_uint,
    max: c_int,
) -> c_int {
    if buf.is_null() || max <= 0 {
        return 0;
    }
    let e = eng();
    let s = if which == 0 {
        e.macro_store.key(idx as usize)
    } else {
        e.macro_store.text(idx as usize)
    };
    let s = match s {
        Some(s) => s,
        None => return 0,
    };
    let n = s.len().min(max as usize);
    for (i, &c) in s[..n].iter().enumerate() {
        unsafe {
            *buf.add(i) = c as c_uint;
        }
    }
    n as c_int
}

// ============================================================ context API

/// Opaque handle.
pub struct SKeyEngine {
    inner: Engine,
    user_map: Option<[u8; 256]>,
}

/// Result of a keystroke operation in SKey C ABI.
#[repr(C)]
#[derive(Clone, Copy)]
pub struct SKeyEdit {
    /// Number of backspaces front-end must send.
    pub backspaces: c_int,
    /// Length of transformed output bytes available in buffer.
    pub len: c_int,
    /// Output type: 0 for characters, 1 for raw keys.
    pub out_type: c_int,
    /// Non-zero if the keystroke was handled by the engine.
    pub handled: c_int,
}

fn edit_of(e: &Engine, edit: skey_core::Edit) -> SKeyEdit {
    SKeyEdit {
        backspaces: edit.backspaces as c_int,
        len: e.output_len() as c_int,
        out_type: match edit.out_type {
            OutputType::Char => 0,
            OutputType::Key => 1,
        },
        handled: edit.handled as c_int,
    }
}

const NO_EDIT: SKeyEdit = SKeyEdit {
    backspaces: 0,
    len: 0,
    out_type: 0,
    handled: 0,
};

/// Creates a new, isolated [`SKeyEngine`] instance.
///
/// Caller is responsible for freeing it via [`skey_engine_free`].
///
/// ### Arguments
///
/// None.
///
/// ### Returns
///
/// Returns a raw pointer `*mut SKeyEngine` to the newly allocated engine instance.
///
/// ### Examples
///
/// ```rust,ignore
/// let engine = skey_engine_create();
/// assert!(!engine.is_null());
/// unsafe { skey_engine_free(engine); }
/// ```
#[no_mangle]
pub extern "C" fn skey_engine_create() -> *mut SKeyEngine {
    let mut inner = Engine::new();
    inner.viet_key = true;
    inner.set_input_method(skey_core::input::IM_TELEX);
    inner.set_charset(Charset(skey_core::charset::XUTF8));
    inner.options = Options::default();
    Box::into_raw(Box::new(SKeyEngine {
        inner,
        user_map: None,
    }))
}

/// Frees an [`SKeyEngine`] instance previously allocated by [`skey_engine_create`].
///
/// ### Arguments
///
/// * `p` - Pointer to the [`SKeyEngine`] instance to deallocate. If null, no operation is performed.
///
/// ### Returns
///
/// Returns `()`.
///
/// ### Safety
///
/// `p` must be null or a valid pointer returned by [`skey_engine_create`].
/// After calling this, `p` must not be accessed again.
///
/// ### Examples
///
/// ```rust,ignore
/// let engine = skey_engine_create();
/// unsafe {
///     skey_engine_free(engine);
/// }
/// ```
#[no_mangle]
pub unsafe extern "C" fn skey_engine_free(p: *mut SKeyEngine) {
    if !p.is_null() {
        drop(Box::from_raw(p));
    }
}

macro_rules! handle {
    ($p:ident) => {
        match unsafe { $p.as_mut() } {
            Some(h) => h,
            None => return,
        }
    };
    ($p:ident, $ret:expr) => {
        match unsafe { $p.as_mut() } {
            Some(h) => h,
            None => return $ret,
        }
    };
}

/// Resets the engine state machine and word buffer.
///
/// ### Arguments
///
/// * `p` - Pointer to the [`SKeyEngine`] instance to reset.
///
/// ### Returns
///
/// Returns `()`.
///
/// ### Safety
///
/// `p` must be a valid, non-null pointer to an initialized [`SKeyEngine`].
///
/// ### Examples
///
/// ```rust,ignore
/// let engine = skey_engine_create();
/// unsafe {
///     skey_engine_reset(engine);
///     skey_engine_free(engine);
/// }
/// ```
#[no_mangle]
pub unsafe extern "C" fn skey_engine_reset(p: *mut SKeyEngine) {
    handle!(p).inner.reset();
}

/// Temporarily switches off spell-checking and diacritic transformation for the current word.
///
/// ### Arguments
///
/// * `p` - Pointer to the [`SKeyEngine`] instance.
///
/// ### Returns
///
/// Returns `()`.
///
/// ### Safety
///
/// `p` must be a valid, non-null pointer to an initialized [`SKeyEngine`].
///
/// ### Examples
///
/// ```rust,ignore
/// let engine = skey_engine_create();
/// unsafe {
///     skey_engine_set_single_mode(engine);
///     skey_engine_free(engine);
/// }
/// ```
#[no_mangle]
pub unsafe extern "C" fn skey_engine_set_single_mode(p: *mut SKeyEngine) {
    handle!(p).inner.set_single_mode();
}

/// Updates Shift and CapsLock modifier states for this engine instance.
///
/// ### Arguments
///
/// * `p` - Pointer to the [`SKeyEngine`] instance.
/// * `shift_pressed` - Non-zero if Shift key is currently held down; `0` otherwise.
/// * `caps_lock_on` - Non-zero if CapsLock is active; `0` otherwise.
///
/// ### Returns
///
/// Returns `()`.
///
/// ### Safety
///
/// `p` must be a valid, non-null pointer to an initialized [`SKeyEngine`].
///
/// ### Examples
///
/// ```rust,ignore
/// let engine = skey_engine_create();
/// unsafe {
///     skey_engine_set_caps_state(engine, 1, 0); // Shift down, CapsLock off
///     skey_engine_free(engine);
/// }
/// ```
#[no_mangle]
pub unsafe extern "C" fn skey_engine_set_caps_state(
    p: *mut SKeyEngine,
    shift_pressed: c_int,
    caps_lock_on: c_int,
) {
    handle!(p)
        .inner
        .set_caps_state(shift_pressed != 0, caps_lock_on != 0);
}

/// Sets the input method (Telex, VNI, VIQR, etc.) for this engine instance.
///
/// ### Arguments
///
/// * `p` - Pointer to the [`SKeyEngine`] instance.
/// * `im` - Input method identifier (`0` for Telex, `1` for VNI, `2` for VIQR, `4` for User custom map).
///
/// ### Returns
///
/// Returns `()`.
///
/// ### Safety
///
/// `p` must be a valid, non-null pointer to an initialized [`SKeyEngine`].
///
/// ### Examples
///
/// ```rust,ignore
/// let engine = skey_engine_create();
/// unsafe {
///     skey_engine_set_input_method(engine, 0); // Telex
///     skey_engine_free(engine);
/// }
/// ```
#[no_mangle]
pub unsafe extern "C" fn skey_engine_set_input_method(p: *mut SKeyEngine, im: c_int) {
    use skey_core::input::{IM_TELEX, IM_USR, IM_VIQR, IM_VNI};
    let h = handle!(p);
    if im == IM_TELEX || im == IM_VNI || im == IM_VIQR {
        h.inner.set_input_method(im);
    } else if im == IM_USR {
        if let Some(map) = h.user_map {
            h.inner.input.set_user_map(&map);
            h.inner.reset();
        }
    }
}

/// Sets the input method directly by integer ID for this engine instance.
///
/// Unlike [`skey_engine_set_input_method`], does not validate ID and resets engine immediately.
///
/// ### Arguments
///
/// * `p` - Pointer to the [`SKeyEngine`] instance.
/// * `im` - Raw input method identifier integer.
///
/// ### Returns
///
/// Returns `()`.
///
/// ### Safety
///
/// `p` must be a valid, non-null pointer to an initialized [`SKeyEngine`].
///
/// ### Examples
///
/// ```rust,ignore
/// let engine = skey_engine_create();
/// unsafe {
///     skey_engine_set_input_method_raw(engine, 0);
///     skey_engine_free(engine);
/// }
/// ```
#[no_mangle]
pub unsafe extern "C" fn skey_engine_set_input_method_raw(p: *mut SKeyEngine, im: c_int) {
    let h = handle!(p);
    h.inner.input.set_im(im);
    h.inner.reset();
}

/// Sets the output character encoding for this engine instance.
///
/// ### Arguments
///
/// * `p` - Pointer to the [`SKeyEngine`] instance.
/// * `charset` - Integer identifier of character set (e.g. `12` for Unicode UTF-8, `0` for TCVN3).
///
/// ### Returns
///
/// Returns `1` on success, or `0` if `p` is null.
///
/// ### Safety
///
/// `p` must be a valid, non-null pointer to an initialized [`SKeyEngine`].
///
/// ### Examples
///
/// ```rust,ignore
/// let engine = skey_engine_create();
/// unsafe {
///     let ok = skey_engine_set_charset(engine, 12);
///     assert_eq!(ok, 1);
///     skey_engine_free(engine);
/// }
/// ```
#[no_mangle]
pub unsafe extern "C" fn skey_engine_set_charset(p: *mut SKeyEngine, charset: c_int) -> c_int {
    let h = handle!(p, 0);
    h.inner.set_charset(Charset(charset));
    1
}

/// Sets configuration options for this engine instance.
///
/// ### Arguments
///
/// * `p` - Pointer to the [`SKeyEngine`] instance.
/// * `opt` - Pointer to an [`SKeyOptions`] struct containing settings to apply. If null, no-op.
///
/// ### Returns
///
/// Returns `()`.
///
/// ### Safety
///
/// `p` must be a valid pointer to an [`SKeyEngine`], and `opt` must point to a valid [`SKeyOptions`] struct.
///
/// ### Examples
///
/// ```rust,ignore
/// let engine = skey_engine_create();
/// let options = skey_create_default_options();
/// unsafe {
///     skey_engine_set_options(engine, &options);
///     skey_engine_free(engine);
/// }
/// ```
#[no_mangle]
pub unsafe extern "C" fn skey_engine_set_options(p: *mut SKeyEngine, opt: *const SKeyOptions) {
    let h = handle!(p);
    if opt.is_null() {
        return;
    }
    let o = *opt;
    let e = &mut h.inner.options;
    e.free_marking = o.freeMarking != 0;
    e.modern_style = o.modernStyle != 0;
    e.macro_enabled = o.macroEnabled != 0;
    e.use_unicode_clipboard = o.useUnicodeClipboard != 0;
    e.always_macro = o.alwaysMacro != 0;
    e.spell_check_enabled = o.spellCheckEnabled != 0;
    e.auto_non_vn_restore = o.autoNonVnRestore != 0;
}

/// Reads configuration options from this engine instance.
///
/// ### Arguments
///
/// * `p` - Pointer to the [`SKeyEngine`] instance.
/// * `opt` - Pointer to a writable [`SKeyOptions`] struct to populate. If null, no-op.
///
/// ### Returns
///
/// Returns `()`.
///
/// ### Safety
///
/// `p` must be a valid pointer to an [`SKeyEngine`], and `opt` must point to valid writable [`SKeyOptions`] memory.
///
/// ### Examples
///
/// ```rust,ignore
/// let engine = skey_engine_create();
/// let mut options = skey_create_default_options();
/// unsafe {
///     skey_engine_get_options(engine, &mut options);
///     skey_engine_free(engine);
/// }
/// ```
#[no_mangle]
pub unsafe extern "C" fn skey_engine_get_options(p: *mut SKeyEngine, opt: *mut SKeyOptions) {
    let h = handle!(p);
    if opt.is_null() {
        return;
    }
    let o = h.inner.options;
    (*opt).freeMarking = o.free_marking as c_int;
    (*opt).modernStyle = o.modern_style as c_int;
    (*opt).macroEnabled = o.macro_enabled as c_int;
    (*opt).useUnicodeClipboard = o.use_unicode_clipboard as c_int;
    (*opt).alwaysMacro = o.always_macro as c_int;
    (*opt).strictSpellCheck = o.strict_spell_check as c_int;
    (*opt).useIME = 0;
    (*opt).spellCheckEnabled = o.spell_check_enabled as c_int;
    (*opt).autoNonVnRestore = o.auto_non_vn_restore as c_int;
}

/// Filters a keystroke through this engine instance.
///
/// ### Arguments
///
/// * `p` - Pointer to the [`SKeyEngine`] instance.
/// * `ch` - Unicode character or key code of the keystroke.
///
/// ### Returns
///
/// Returns an [`SKeyEdit`] struct describing the required text edits (backspaces and output buffer length).
///
/// ### Safety
///
/// `p` must be a valid, non-null pointer to an initialized [`SKeyEngine`].
///
/// ### Examples
///
/// ```rust,ignore
/// let engine = skey_engine_create();
/// unsafe {
///     let edit = skey_engine_filter(engine, 'a' as u32);
///     assert_eq!(edit.handled, 1);
///     skey_engine_free(engine);
/// }
/// ```
#[no_mangle]
pub unsafe extern "C" fn skey_engine_filter(p: *mut SKeyEngine, ch: c_uint) -> SKeyEdit {
    let h = handle!(p, NO_EDIT);
    let edit = h.inner.key(ch);
    edit_of(&h.inner, edit)
}

/// Passes a character directly to this engine instance without transformation.
///
/// ### Arguments
///
/// * `p` - Pointer to the [`SKeyEngine`] instance.
/// * `ch` - Character code to append directly to the buffer.
///
/// ### Returns
///
/// Returns `()`.
///
/// ### Safety
///
/// `p` must be a valid, non-null pointer to an initialized [`SKeyEngine`].
///
/// ### Examples
///
/// ```rust,ignore
/// let engine = skey_engine_create();
/// unsafe {
///     skey_engine_put_char(engine, ' ' as u32);
///     skey_engine_free(engine);
/// }
/// ```
#[no_mangle]
pub unsafe extern "C" fn skey_engine_put_char(p: *mut SKeyEngine, ch: c_uint) {
    handle!(p).inner.pass(ch);
}

/// Processes a backspace press in this engine instance.
///
/// ### Arguments
///
/// * `p` - Pointer to the [`SKeyEngine`] instance.
///
/// ### Returns
///
/// Returns an [`SKeyEdit`] describing the backspace operation.
///
/// ### Safety
///
/// `p` must be a valid, non-null pointer to an initialized [`SKeyEngine`].
///
/// ### Examples
///
/// ```rust,ignore
/// let engine = skey_engine_create();
/// unsafe {
///     let edit = skey_engine_backspace(engine);
///     skey_engine_free(engine);
/// }
/// ```
#[no_mangle]
pub unsafe extern "C" fn skey_engine_backspace(p: *mut SKeyEngine) -> SKeyEdit {
    let h = handle!(p, NO_EDIT);
    let edit = h.inner.backspace();
    edit_of(&h.inner, edit)
}

/// Restores the raw keystrokes of the current word in this engine instance.
///
/// ### Arguments
///
/// * `p` - Pointer to the [`SKeyEngine`] instance.
///
/// ### Returns
///
/// Returns an [`SKeyEdit`] containing backspaces and the restored raw keystrokes.
///
/// ### Safety
///
/// `p` must be a valid, non-null pointer to an initialized [`SKeyEngine`].
///
/// ### Examples
///
/// ```rust,ignore
/// let engine = skey_engine_create();
/// unsafe {
///     let edit = skey_engine_restore(engine);
///     skey_engine_free(engine);
/// }
/// ```
#[no_mangle]
pub unsafe extern "C" fn skey_engine_restore(p: *mut SKeyEngine) -> SKeyEdit {
    let h = handle!(p, NO_EDIT);
    let edit = h.inner.restore_key_strokes();
    edit_of(&h.inner, edit)
}

/// Copies the latest engine output bytes into `buf` up to `max` bytes.
///
/// ### Arguments
///
/// * `p` - Pointer to the [`SKeyEngine`] instance.
/// * `buf` - Destination byte array to write output into.
/// * `max` - Maximum number of bytes to write.
///
/// ### Returns
///
/// Returns the number of bytes written to `buf`, or `0` if `p` or `buf` is null or `max <= 0`.
///
/// ### Safety
///
/// `p` must be a valid pointer to an [`SKeyEngine`], and `buf` must point to a writable buffer of at least `max` bytes.
///
/// ### Examples
///
/// ```rust,ignore
/// let engine = skey_engine_create();
/// let mut buf = [0u8; 64];
/// unsafe {
///     let written = skey_engine_output(engine, buf.as_mut_ptr(), 64);
///     skey_engine_free(engine);
/// }
/// ```
#[no_mangle]
pub unsafe extern "C" fn skey_engine_output(
    p: *mut SKeyEngine,
    buf: *mut u8,
    max: c_int,
) -> c_int {
    let h = handle!(p, 0);
    if buf.is_null() || max <= 0 {
        return 0;
    }
    let bytes = h.inner.output();
    let n = bytes.len().min(max as usize);
    core::ptr::copy_nonoverlapping(bytes.as_ptr(), buf, n);
    n as c_int
}

/// Loads a macro table from the specified file path into this engine instance.
///
/// ### Arguments
///
/// * `p` - Pointer to the [`SKeyEngine`] instance.
/// * `file_name` - Pointer to a null-terminated UTF-8 C string containing the filesystem path.
///
/// ### Returns
///
/// Returns `1` on success, or `0` if `p` or `file_name` is null, unreadable, or file reading failed.
///
/// ### Safety
///
/// `p` must be a valid pointer to an [`SKeyEngine`], and `file_name` must be a valid null-terminated C string.
///
/// ### Examples
///
/// ```rust,ignore
/// let engine = skey_engine_create();
/// let path = std::ffi::CString::new("/path/to/macro.txt").unwrap();
/// unsafe {
///     let ok = skey_engine_load_macro_table(engine, path.as_ptr());
///     skey_engine_free(engine);
/// }
/// ```
#[no_mangle]
pub unsafe extern "C" fn skey_engine_load_macro_table(
    p: *mut SKeyEngine,
    file_name: *const c_char,
) -> c_int {
    let h = handle!(p, 0);
    let path = match cstr(file_name) {
        Some(v) => v,
        None => return 0,
    };
    let data = match std::fs::read(&path) {
        Ok(d) => d,
        Err(_) => return 0,
    };
    let version = h.inner.macro_store.load_from_bytes(&data);
    if version != 1 {
        let _ = std::fs::write(&path, h.inner.macro_store.to_utf8_file());
    }
    1
}

/// Loads a user key mapping file from disk into this engine instance.
///
/// ### Arguments
///
/// * `p` - Pointer to the [`SKeyEngine`] instance.
/// * `file_name` - Pointer to a null-terminated UTF-8 C string containing the keymap file path.
///
/// ### Returns
///
/// Returns `1` on success, or `0` if `p` or `file_name` is null, invalid, or read fails.
///
/// ### Safety
///
/// `p` must be a valid pointer to an [`SKeyEngine`], and `file_name` must be a valid null-terminated C string.
///
/// ### Examples
///
/// ```rust,ignore
/// let engine = skey_engine_create();
/// let path = std::ffi::CString::new("/path/to/keymap.txt").unwrap();
/// unsafe {
///     let ok = skey_engine_load_user_key_map(engine, path.as_ptr());
///     skey_engine_free(engine);
/// }
/// ```
#[no_mangle]
pub unsafe extern "C" fn skey_engine_load_user_key_map(
    p: *mut SKeyEngine,
    file_name: *const c_char,
) -> c_int {
    let h = handle!(p, 0);
    let path = match cstr(file_name) {
        Some(v) => v,
        None => return 0,
    };
    let data = match std::fs::read(path) {
        Ok(d) => d,
        Err(_) => return 0,
    };
    h.user_map = Some(keymap::parse_key_map(&data));
    1
}

// -------------------------------------------------- swallowed key restore

/// Enables or disables swallowed key restoration on the global engine.
///
/// ### Arguments
///
/// * `on` - Non-zero to enable swallowed key restoration; `0` to disable.
///
/// ### Returns
///
/// Returns `()`.
///
/// ### Examples
///
/// ```rust,ignore
/// skey_set_swallowed_key_restore(1); // Enable
/// ```
#[no_mangle]
pub extern "C" fn skey_set_swallowed_key_restore(on: c_int) {
    eng().options.swallowed_key_restore = on != 0;
}

/// Returns whether swallowed key restoration is enabled on the global engine.
///
/// ### Arguments
///
/// None.
///
/// ### Returns
///
/// Returns `1` if swallowed key restoration is enabled; `0` otherwise.
///
/// ### Examples
///
/// ```rust,ignore
/// let enabled = skey_get_swallowed_key_restore();
/// println!("Swallowed restore enabled: {}", enabled != 0);
/// ```
#[no_mangle]
pub extern "C" fn skey_get_swallowed_key_restore() -> c_int {
    eng().options.swallowed_key_restore as c_int
}

/// Enables or disables swallowed key restoration on this engine instance.
///
/// ### Arguments
///
/// * `p` - Pointer to the [`SKeyEngine`] instance.
/// * `on` - Non-zero to enable swallowed key restoration; `0` to disable.
///
/// ### Returns
///
/// Returns `()`.
///
/// ### Safety
///
/// `p` must be a valid, non-null pointer to an initialized [`SKeyEngine`].
///
/// ### Examples
///
/// ```rust,ignore
/// let engine = skey_engine_create();
/// unsafe {
///     skey_engine_set_swallowed_key_restore(engine, 1);
///     skey_engine_free(engine);
/// }
/// ```
#[no_mangle]
pub unsafe extern "C" fn skey_engine_set_swallowed_key_restore(
    p: *mut SKeyEngine,
    on: c_int,
) {
    handle!(p).inner.options.swallowed_key_restore = on != 0;
}

/// Returns the total number of swallowed English words recognized by the engine.
///
/// ### Arguments
///
/// None.
///
/// ### Returns
///
/// Returns the word count as a `c_int`.
///
/// ### Examples
///
/// ```rust,ignore
/// let count = skey_swallowed_word_count();
/// assert!(count > 0);
/// ```
#[no_mangle]
pub extern "C" fn skey_swallowed_word_count() -> c_int {
    skey_core::enwords::words().count() as c_int
}

/// Copies the swallowed English word at index `idx` into `buf` as a null-terminated C string.
///
/// ### Arguments
///
/// * `idx` - Zero-based index of the swallowed word.
/// * `buf` - Destination buffer to receive null-terminated C string.
/// * `max` - Size of `buf` in bytes (must be at least 2).
///
/// ### Returns
///
/// Returns the length of the string copied in bytes, or `0` if index is out of bounds, `buf` is null, or `max <= 1`.
///
/// ### Safety
///
/// `buf` must point to a writable memory buffer of at least `max` bytes.
///
/// ### Examples
///
/// ```rust,ignore
/// let mut buf = [0 as std::os::raw::c_char; 32];
/// unsafe {
///     let len = skey_swallowed_word(0, buf.as_mut_ptr(), 32);
///     assert!(len > 0);
/// }
/// ```
#[no_mangle]
pub unsafe extern "C" fn skey_swallowed_word(idx: c_int, buf: *mut c_char, max: c_int) -> c_int {
    if buf.is_null() || max <= 1 || idx < 0 {
        return 0;
    }
    let w = match skey_core::enwords::words().nth(idx as usize) {
        Some(w) => w,
        None => return 0,
    };
    let n = w.len().min(max as usize - 1);
    core::ptr::copy_nonoverlapping(w.as_ptr().cast::<c_char>(), buf, n);
    *buf.add(n) = 0;
    n as c_int
}

// ------------------------------------------------ typing shortcut options

macro_rules! quick_option {
    ($set:ident, $get:ident, $ctx:ident, $field:ident) => {
        #[doc = concat!("Enables (`on != 0`) or disables (`on == 0`) `", stringify!($field), "` globally.\n\n### Arguments\n\n* `on` - Non-zero to enable; `0` to disable.\n\n### Returns\n\nReturns `()`.\n\n### Examples\n\n```rust,ignore\n", stringify!($set), "(1);\n```")]
        #[no_mangle]
        pub extern "C" fn $set(on: c_int) {
            eng().options.$field = on != 0;
        }

        #[doc = concat!("Returns whether `", stringify!($field), "` is currently enabled globally (1) or disabled (0).\n\n### Arguments\n\nNone.\n\n### Returns\n\nReturns `1` if enabled, `0` if disabled.\n\n### Examples\n\n```rust,ignore\nlet enabled = ", stringify!($get), "();\n```")]
        #[no_mangle]
        pub extern "C" fn $get() -> c_int {
            eng().options.$field as c_int
        }

        #[doc = concat!("Enables (`on != 0`) or disables (`on == 0`) `", stringify!($field), "` on the specified engine instance.\n\n### Arguments\n\n* `p` - Pointer to the [`SKeyEngine`] instance.\n* `on` - Non-zero to enable; `0` to disable.\n\n### Returns\n\nReturns `()`.\n\n### Safety\n\n`p` must be a valid, non-null pointer to an initialized [`SKeyEngine`].\n\n### Examples\n\n```rust,ignore\nlet engine = skey_engine_create();\nunsafe {\n    ", stringify!($ctx), "(engine, 1);\n    skey_engine_free(engine);\n}\n```")]
        #[no_mangle]
        pub unsafe extern "C" fn $ctx(p: *mut SKeyEngine, on: c_int) {
            handle!(p).inner.options.$field = on != 0;
        }
    };
}

quick_option!(
    skey_set_quick_telex,
    skey_get_quick_telex,
    skey_engine_set_quick_telex,
    quick_telex
);
quick_option!(
    skey_set_quick_start_consonant,
    skey_get_quick_start_consonant,
    skey_engine_set_quick_start_consonant,
    quick_start_consonant
);
quick_option!(
    skey_set_quick_end_consonant,
    skey_get_quick_end_consonant,
    skey_engine_set_quick_end_consonant,
    quick_end_consonant
);
quick_option!(
    skey_set_upper_case_first_char,
    skey_get_upper_case_first_char,
    skey_engine_set_upper_case_first_char,
    upper_case_first_char
);

quick_option!(
    skey_set_allow_consonant_zfwj,
    skey_get_allow_consonant_zfwj,
    skey_engine_set_allow_consonant_zfwj,
    allow_consonant_zfwj
);

/// Evaluates a mathematical expression using SKey Core's calc engine and writes formatted result to `out_buf`.
///
/// ### Arguments
///
/// * `expr` - Pointer to a null-terminated UTF-8 C string containing the mathematical expression (e.g. `"2+2*3"`).
/// * `out_buf` - Destination buffer to receive the formatted null-terminated result string.
/// * `max_len` - Size of `out_buf` in bytes (must be at least 2).
///
/// ### Returns
///
/// Returns `1` on successful evaluation and output copy, or `0` on syntax/math error, null pointers, or buffer overflow.
///
/// ### Safety
///
/// `expr` must be a valid null-terminated C string, and `out_buf` must point to a writable memory buffer of at least `max_len` bytes.
///
/// ### Examples
///
/// ```rust,ignore
/// let expr = std::ffi::CString::new("2+2").unwrap();
/// let mut buf = [0 as std::os::raw::c_char; 32];
/// unsafe {
///     let ok = skey_calc_evaluate(expr.as_ptr(), buf.as_mut_ptr(), 32);
///     assert_eq!(ok, 1);
/// }
/// ```
#[no_mangle]
pub unsafe extern "C" fn skey_calc_evaluate(
    expr: *const c_char,
    out_buf: *mut c_char,
    max_len: c_int,
) -> c_int {
    if expr.is_null() || out_buf.is_null() || max_len <= 1 {
        return 0;
    }
    let Ok(c_str) = CStr::from_ptr(expr).to_str() else {
        return 0;
    };
    let Some(result) = skey_core::calc::eval_formatted(c_str) else {
        return 0;
    };
    let bytes = result.as_bytes();
    if bytes.len() >= max_len as usize {
        return 0;
    }
    core::ptr::copy_nonoverlapping(bytes.as_ptr(), out_buf as *mut u8, bytes.len());
    *(out_buf.add(bytes.len())) = 0;
    1
}
