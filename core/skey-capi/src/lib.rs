//! The original C interface, unchanged.
//!
//! `src/ukinterface/unikey.cpp` exposes a handful of functions and four
//! globals, and every front end in the tree (xim, the GTK input module,
//! the Windows and macOS shells) is written against exactly that. Keeping
//! it byte for byte means the port arrives as a library swap rather than
//! an ecosystem migration.
//!
//! Globals across an FFI boundary have to be real symbols, so unsafe
//! lives here and nowhere else: `unikey-core` forbids it.
#![allow(non_snake_case)]

use core::cell::UnsafeCell;
use std::ffi::CStr;
use std::os::raw::{c_char, c_int, c_uint};

use skey_core::charset::Charset;
use skey_core::engine::OutputType;
use skey_core::{keymap, Engine, Options};

/// Same size as the original's `unsigned char UnikeyBuf[1024]`.
pub const UNIKEY_BUF_SIZE: usize = 1024;

/// `static mut` is deprecated in the 2024 edition and taking a reference
/// to one is already a lint, but a `#[no_mangle]` mutable C symbol has to
/// be a real global. This wrapper is the way out: the symbol keeps the
/// layout C expects, and access goes through a raw pointer so no Rust
/// reference to a mutable static is ever created.
#[repr(transparent)]
pub struct Global<T>(UnsafeCell<T>);

// Safety: this states the original's threading model, it does not claim
// safety. The legacy interface is a set of process wide globals meant to
// be driven from one thread, exactly as the C++ engine was. Code needing
// concurrency uses the context API further down, which has no globals.
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

#[no_mangle]
pub static UnikeyBuf: Global<[u8; UNIKEY_BUF_SIZE]> = Global::new([0; UNIKEY_BUF_SIZE]);
#[no_mangle]
pub static UnikeyBackspaces: Global<c_int> = Global::new(0);
#[no_mangle]
pub static UnikeyBufChars: Global<c_int> = Global::new(0);
/// `UkOutputType`: 0 is UkCharOutput, 1 is UkKeyOutput.
#[no_mangle]
pub static UnikeyOutput: Global<c_int> = Global::new(0);

static ENGINE: Global<Option<Engine>> = Global::new(None);

/// Mirrors `struct _UnikeyOptions`, field order and all.
#[repr(C)]
#[derive(Clone, Copy)]
pub struct UnikeyOptions {
    pub freeMarking: c_int,
    pub modernStyle: c_int,
    pub macroEnabled: c_int,
    pub useUnicodeClipboard: c_int,
    pub alwaysMacro: c_int,
    pub strictSpellCheck: c_int,
    pub useIME: c_int,
    pub spellCheckEnabled: c_int,
    pub autoNonVnRestore: c_int,
}

fn eng() -> &'static mut Engine {
    // Safety: single threaded legacy interface, see Global above.
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
    let n = bytes.len().min(UNIKEY_BUF_SIZE);
    unsafe {
        core::ptr::copy_nonoverlapping(bytes.as_ptr(), UnikeyBuf.ptr().cast::<u8>(), n);
        // The original reports the stream counter, which can run past the
        // buffer size; front ends are expected to clamp.
        *UnikeyBufChars.ptr() = e.output_len() as c_int;
        *UnikeyBackspaces.ptr() = edit.backspaces as c_int;
        *UnikeyOutput.ptr() = match edit.out_type {
            OutputType::Char => 0,
            OutputType::Key => 1,
        };
    }
}

/// Always call this first.
#[no_mangle]
pub extern "C" fn UnikeySetup() {
    unsafe {
        *ENGINE.ptr() = Some(Engine::new());
    }
    let e = eng();
    e.viet_key = true;
    e.set_input_method(skey_core::input::IM_TELEX);
    e.set_charset(Charset(skey_core::charset::XUTF8));
    e.options = Options::default();
}

#[no_mangle]
pub extern "C" fn UnikeyCleanup() {
    unsafe {
        *ENGINE.ptr() = None;
    }
}

#[no_mangle]
pub extern "C" fn UnikeyResetBuf() {
    eng().reset();
}

/// Main handler: call for every character input received.
#[no_mangle]
pub extern "C" fn UnikeyFilter(ch: c_uint) {
    let edit = eng().key(ch as u32);
    publish(edit);
}

/// Put a character through without filtering.
#[no_mangle]
pub extern "C" fn UnikeyPutChar(ch: c_uint) {
    eng().pass(ch as u32);
    unsafe {
        *UnikeyBufChars.ptr() = 0;
        *UnikeyBackspaces.ptr() = 0;
    }
}

/// Call before `UnikeyFilter` so the Telex shortcuts see the real state.
#[no_mangle]
pub extern "C" fn UnikeySetCapsState(shiftPressed: c_int, CapsLockOn: c_int) {
    eng().set_caps_state(shiftPressed != 0, CapsLockOn != 0);
}

#[no_mangle]
pub extern "C" fn UnikeyBackspacePress() {
    let edit = eng().backspace();
    publish(edit);
}

#[no_mangle]
pub extern "C" fn UnikeyRestoreKeyStrokes() {
    let edit = eng().restore_key_strokes();
    publish(edit);
}

#[no_mangle]
pub extern "C" fn UnikeySetSingleMode() {
    eng().set_single_mode();
}

#[no_mangle]
pub extern "C" fn CreateDefaultUnikeyOptions(pOpt: *mut UnikeyOptions) {
    if pOpt.is_null() {
        return;
    }
    let d = Options::default();
    unsafe {
        (*pOpt).freeMarking = d.free_marking as c_int;
        (*pOpt).modernStyle = d.modern_style as c_int;
        (*pOpt).macroEnabled = d.macro_enabled as c_int;
        (*pOpt).useUnicodeClipboard = d.use_unicode_clipboard as c_int;
        (*pOpt).alwaysMacro = d.always_macro as c_int;
        (*pOpt).spellCheckEnabled = d.spell_check_enabled as c_int;
        (*pOpt).autoNonVnRestore = d.auto_non_vn_restore as c_int;
    }
}

/// Note which fields are copied: the original leaves `strictSpellCheck`
/// and `useIME` alone here, and that is preserved.
#[no_mangle]
pub extern "C" fn UnikeySetOptions(pOpt: *const UnikeyOptions) {
    if pOpt.is_null() {
        return;
    }
    let o = unsafe { *pOpt };
    let e = eng();
    e.options.free_marking = o.freeMarking != 0;
    e.options.modern_style = o.modernStyle != 0;
    e.options.macro_enabled = o.macroEnabled != 0;
    e.options.use_unicode_clipboard = o.useUnicodeClipboard != 0;
    e.options.always_macro = o.alwaysMacro != 0;
    e.options.spell_check_enabled = o.spellCheckEnabled != 0;
    e.options.auto_non_vn_restore = o.autoNonVnRestore != 0;
}

#[no_mangle]
pub extern "C" fn UnikeyGetOptions(pOpt: *mut UnikeyOptions) {
    if pOpt.is_null() {
        return;
    }
    let o = eng().options;
    unsafe {
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
}

/// Accepts Telex, VNI, VIQR and the user map, exactly as the original
/// does: MsVi and simple Telex are not reachable here, and simple Telex
/// is dead in the engine anyway.
#[no_mangle]
pub extern "C" fn UnikeySetInputMethod(im: c_int) {
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

#[no_mangle]
pub extern "C" fn UnikeySetOutputCharset(charset: c_int) -> c_int {
    eng().set_charset(Charset(charset));
    1
}

#[no_mangle]
pub extern "C" fn UnikeyLoadMacroTable(fileName: *const c_char) -> c_int {
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
        // The original rewrites a legacy file in the current format.
        let _ = std::fs::write(&path, e.macro_store.to_utf8_file());
    }
    1
}

#[no_mangle]
pub extern "C" fn UnikeyLoadUserKeyMap(fileName: *const c_char) -> c_int {
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

/// The loaded user map, kept aside so `UnikeySetInputMethod(UkUsrIM)`
/// can install it later, mirroring `pShMem->usrKeyMap` together with the
/// `usrKeyMapLoaded` flag.
static USER_MAP: Global<Option<[u8; 256]>> = Global::new(None);

fn user_map() -> Option<&'static [u8; 256]> {
    unsafe { (*USER_MAP.ptr()).as_ref() }
}

fn set_user_map(m: [u8; 256]) {
    unsafe {
        *USER_MAP.ptr() = Some(m);
    }
}

// ------------------------------------------------- harness extensions
//
// Not part of the original interface. `UnikeySetInputMethod` cannot
// select MsVi or simple Telex, and the differential harness needs to
// reach them and to read the macro table back.

#[no_mangle]
pub extern "C" fn UnikeySetInputMethodRaw(im: c_int) {
    let e = eng();
    e.input.set_im(im);
    e.reset();
}

#[no_mangle]
pub extern "C" fn UnikeyMacroCount() -> c_int {
    eng().macro_store.count() as c_int
}

/// `which` 0 for the key, 1 for the text. Returns the number of
/// StdVnChars written.
#[no_mangle]
pub extern "C" fn UnikeyMacroGet(
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
//
// The legacy interface above is process wide globals, which is what the
// original was and what every existing front end expects. Anything that
// needs more than one input session, or any thread safety at all, uses
// the functions below instead: the engine is an opaque handle, there is
// no shared state, and nothing is reentrancy sensitive.

/// Opaque handle. Create with `unikey_engine_create`, release with
/// `unikey_engine_free`.
pub struct UnikeyEngine {
    inner: Engine,
    /// Where a loaded user key map waits for
    /// `unikey_engine_set_input_method(UkUsrIM)`.
    user_map: Option<[u8; 256]>,
}

/// What one key produced. `len` is the number of output bytes available
/// from `unikey_engine_output`.
#[repr(C)]
#[derive(Clone, Copy)]
pub struct UnikeyEdit {
    pub backspaces: c_int,
    pub len: c_int,
    /// 0 is UkCharOutput, 1 is UkKeyOutput.
    pub out_type: c_int,
    /// 0 means the engine did not consume the key: pass the original
    /// through untouched.
    pub handled: c_int,
}

fn edit_of(e: &Engine, edit: skey_core::Edit) -> UnikeyEdit {
    UnikeyEdit {
        // Both are reported unconditionally, as the legacy globals are.
        // `processBackspace` in particular assigns its backspace count
        // even when it reports that it did not handle the key, and the
        // reported length is the stream counter, which can exceed the
        // bytes actually stored.
        backspaces: edit.backspaces as c_int,
        len: e.output_len() as c_int,
        out_type: match edit.out_type {
            OutputType::Char => 0,
            OutputType::Key => 1,
        },
        handled: edit.handled as c_int,
    }
}

const NO_EDIT: UnikeyEdit = UnikeyEdit {
    backspaces: 0,
    len: 0,
    out_type: 0,
    handled: 0,
};

#[no_mangle]
pub extern "C" fn unikey_engine_create() -> *mut UnikeyEngine {
    let mut inner = Engine::new();
    inner.viet_key = true;
    inner.set_input_method(skey_core::input::IM_TELEX);
    inner.set_charset(Charset(skey_core::charset::XUTF8));
    inner.options = Options::default();
    Box::into_raw(Box::new(UnikeyEngine {
        inner,
        user_map: None,
    }))
}

/// Safety: `p` must come from `unikey_engine_create` and must not be used
/// afterwards.
#[no_mangle]
pub unsafe extern "C" fn unikey_engine_free(p: *mut UnikeyEngine) {
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

#[no_mangle]
pub unsafe extern "C" fn unikey_engine_reset(p: *mut UnikeyEngine) {
    handle!(p).inner.reset();
}

#[no_mangle]
pub unsafe extern "C" fn unikey_engine_set_single_mode(p: *mut UnikeyEngine) {
    handle!(p).inner.set_single_mode();
}

#[no_mangle]
pub unsafe extern "C" fn unikey_engine_set_caps_state(
    p: *mut UnikeyEngine,
    shift_pressed: c_int,
    caps_lock_on: c_int,
) {
    handle!(p)
        .inner
        .set_caps_state(shift_pressed != 0, caps_lock_on != 0);
}

/// Accepts Telex, VNI and VIQR, and the user map once one is loaded,
/// exactly like the legacy setter.
#[no_mangle]
pub unsafe extern "C" fn unikey_engine_set_input_method(p: *mut UnikeyEngine, im: c_int) {
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

/// Reaches the processor directly, so MsVi and simple Telex are
/// selectable here even though the legacy setter rejects them.
#[no_mangle]
pub unsafe extern "C" fn unikey_engine_set_input_method_raw(p: *mut UnikeyEngine, im: c_int) {
    let h = handle!(p);
    h.inner.input.set_im(im);
    h.inner.reset();
}

#[no_mangle]
pub unsafe extern "C" fn unikey_engine_set_charset(p: *mut UnikeyEngine, charset: c_int) -> c_int {
    let h = handle!(p, 0);
    h.inner.set_charset(Charset(charset));
    1
}

#[no_mangle]
pub unsafe extern "C" fn unikey_engine_set_options(p: *mut UnikeyEngine, opt: *const UnikeyOptions) {
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

#[no_mangle]
pub unsafe extern "C" fn unikey_engine_get_options(p: *mut UnikeyEngine, opt: *mut UnikeyOptions) {
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

#[no_mangle]
pub unsafe extern "C" fn unikey_engine_filter(p: *mut UnikeyEngine, ch: c_uint) -> UnikeyEdit {
    let h = handle!(p, NO_EDIT);
    let edit = h.inner.key(ch as u32);
    edit_of(&h.inner, edit)
}

#[no_mangle]
pub unsafe extern "C" fn unikey_engine_put_char(p: *mut UnikeyEngine, ch: c_uint) {
    handle!(p).inner.pass(ch as u32);
}

#[no_mangle]
pub unsafe extern "C" fn unikey_engine_backspace(p: *mut UnikeyEngine) -> UnikeyEdit {
    let h = handle!(p, NO_EDIT);
    let edit = h.inner.backspace();
    edit_of(&h.inner, edit)
}

#[no_mangle]
pub unsafe extern "C" fn unikey_engine_restore(p: *mut UnikeyEngine) -> UnikeyEdit {
    let h = handle!(p, NO_EDIT);
    let edit = h.inner.restore_key_strokes();
    edit_of(&h.inner, edit)
}

/// Copies up to `max` output bytes into `buf` and returns how many were
/// written. Call right after a filter, backspace or restore.
#[no_mangle]
pub unsafe extern "C" fn unikey_engine_output(
    p: *mut UnikeyEngine,
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

#[no_mangle]
pub unsafe extern "C" fn unikey_engine_load_macro_table(
    p: *mut UnikeyEngine,
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

#[no_mangle]
pub unsafe extern "C" fn unikey_engine_load_user_key_map(
    p: *mut UnikeyEngine,
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
//
// A dedicated setter rather than a field in `UnikeyOptions`: that struct is
// part of the original ABI and adding to it would change its size and
// break every front end already compiled against it.

/// Off by default, and off is byte for byte identical to the original.
/// See `skey_core::enwords` for what it covers and why it stops there.
#[no_mangle]
pub extern "C" fn UnikeySetSwallowedKeyRestore(on: c_int) {
    eng().options.swallowed_key_restore = on != 0;
}

#[no_mangle]
pub extern "C" fn UnikeyGetSwallowedKeyRestore() -> c_int {
    eng().options.swallowed_key_restore as c_int
}

#[no_mangle]
pub unsafe extern "C" fn unikey_engine_set_swallowed_key_restore(
    p: *mut UnikeyEngine,
    on: c_int,
) {
    handle!(p).inner.options.swallowed_key_restore = on != 0;
}

/// Number of words in the table.
#[no_mangle]
pub extern "C" fn unikey_swallowed_word_count() -> c_int {
    skey_core::enwords::words().count() as c_int
}

/// Copies word `idx` into `buf` as NUL terminated ASCII and returns its
/// length, so a front end can show the user exactly what the option
/// covers. Returns 0 when `idx` is out of range.
#[no_mangle]
pub unsafe extern "C" fn unikey_swallowed_word(idx: c_int, buf: *mut c_char, max: c_int) -> c_int {
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

// ------------------------------------------------ OpenKey style options
//
// Dedicated setters rather than fields in `UnikeyOptions`: that struct is
// part of the original ABI and growing it would change its size and break
// every front end already compiled against it.
//
// All of them default to off, and off is byte for byte identical to the
// original.

macro_rules! quick_option {
    ($set:ident, $get:ident, $ctx:ident, $field:ident) => {
        #[no_mangle]
        pub extern "C" fn $set(on: c_int) {
            eng().options.$field = on != 0;
        }

        #[no_mangle]
        pub extern "C" fn $get() -> c_int {
            eng().options.$field as c_int
        }

        #[no_mangle]
        pub unsafe extern "C" fn $ctx(p: *mut UnikeyEngine, on: c_int) {
            handle!(p).inner.options.$field = on != 0;
        }
    };
}

quick_option!(
    UnikeySetQuickTelex,
    UnikeyGetQuickTelex,
    unikey_engine_set_quick_telex,
    quick_telex
);
quick_option!(
    UnikeySetQuickStartConsonant,
    UnikeyGetQuickStartConsonant,
    unikey_engine_set_quick_start_consonant,
    quick_start_consonant
);
quick_option!(
    UnikeySetQuickEndConsonant,
    UnikeyGetQuickEndConsonant,
    unikey_engine_set_quick_end_consonant,
    quick_end_consonant
);
quick_option!(
    UnikeySetUpperCaseFirstChar,
    UnikeyGetUpperCaseFirstChar,
    unikey_engine_set_upper_case_first_char,
    upper_case_first_char
);

quick_option!(
    UnikeySetAllowConsonantZFWJ,
    UnikeyGetAllowConsonantZFWJ,
    unikey_engine_set_allow_consonant_zfwj,
    allow_consonant_zfwj
);

// MARK: - SKey Export Aliases

#[no_mangle]
pub extern "C" fn skey_engine_create() -> *mut UnikeyEngine {
    unikey_engine_create()
}

#[no_mangle]
pub unsafe extern "C" fn skey_engine_free(p: *mut UnikeyEngine) {
    unikey_engine_free(p)
}

#[no_mangle]
pub unsafe extern "C" fn skey_engine_reset(p: *mut UnikeyEngine) {
    unikey_engine_reset(p)
}

#[no_mangle]
pub unsafe extern "C" fn skey_engine_set_single_mode(p: *mut UnikeyEngine) {
    unikey_engine_set_single_mode(p)
}

#[no_mangle]
pub unsafe extern "C" fn skey_engine_set_caps_state(p: *mut UnikeyEngine, shiftPressed: c_int, capsLockOn: c_int) {
    unikey_engine_set_caps_state(p, shiftPressed, capsLockOn)
}

#[no_mangle]
pub unsafe extern "C" fn skey_engine_set_input_method(p: *mut UnikeyEngine, im: c_int) {
    unikey_engine_set_input_method(p, im)
}

#[no_mangle]
pub unsafe extern "C" fn skey_engine_set_input_method_raw(p: *mut UnikeyEngine, im: c_int) {
    unikey_engine_set_input_method_raw(p, im)
}

#[no_mangle]
pub unsafe extern "C" fn skey_engine_set_charset(p: *mut UnikeyEngine, charset: c_int) -> c_int {
    unikey_engine_set_charset(p, charset)
}

#[no_mangle]
pub unsafe extern "C" fn skey_engine_set_options(p: *mut UnikeyEngine, opt: *const UnikeyOptions) {
    unikey_engine_set_options(p, opt)
}

#[no_mangle]
pub unsafe extern "C" fn skey_engine_get_options(p: *mut UnikeyEngine, opt: *mut UnikeyOptions) {
    unikey_engine_get_options(p, opt)
}

#[no_mangle]
pub unsafe extern "C" fn skey_engine_filter(p: *mut UnikeyEngine, ch: c_uint) -> UnikeyEdit {
    unikey_engine_filter(p, ch)
}

#[no_mangle]
pub unsafe extern "C" fn skey_engine_put_char(p: *mut UnikeyEngine, ch: c_uint) {
    unikey_engine_put_char(p, ch)
}

#[no_mangle]
pub unsafe extern "C" fn skey_engine_backspace(p: *mut UnikeyEngine) -> UnikeyEdit {
    unikey_engine_backspace(p)
}

#[no_mangle]
pub unsafe extern "C" fn skey_engine_restore(p: *mut UnikeyEngine) -> UnikeyEdit {
    unikey_engine_restore(p)
}

#[no_mangle]
pub unsafe extern "C" fn skey_engine_output(p: *mut UnikeyEngine, buf: *mut u8, max: c_int) -> c_int {
    unikey_engine_output(p, buf, max)
}

#[no_mangle]
pub unsafe extern "C" fn skey_engine_load_macro_table(p: *mut UnikeyEngine, fileName: *const c_char) -> c_int {
    unikey_engine_load_macro_table(p, fileName)
}

#[no_mangle]
pub unsafe extern "C" fn skey_engine_load_user_key_map(p: *mut UnikeyEngine, fileName: *const c_char) -> c_int {
    unikey_engine_load_user_key_map(p, fileName)
}

#[no_mangle]
pub unsafe extern "C" fn skey_engine_set_swallowed_key_restore(p: *mut UnikeyEngine, on: c_int) {
    unikey_engine_set_swallowed_key_restore(p, on)
}

#[no_mangle]
pub unsafe extern "C" fn skey_engine_set_quick_telex(p: *mut UnikeyEngine, on: c_int) {
    unikey_engine_set_quick_telex(p, on)
}

#[no_mangle]
pub unsafe extern "C" fn skey_engine_set_quick_start_consonant(p: *mut UnikeyEngine, on: c_int) {
    unikey_engine_set_quick_start_consonant(p, on)
}

#[no_mangle]
pub unsafe extern "C" fn skey_engine_set_quick_end_consonant(p: *mut UnikeyEngine, on: c_int) {
    unikey_engine_set_quick_end_consonant(p, on)
}

#[no_mangle]
pub unsafe extern "C" fn skey_engine_set_upper_case_first_char(p: *mut UnikeyEngine, on: c_int) {
    unikey_engine_set_upper_case_first_char(p, on)
}

#[no_mangle]
pub unsafe extern "C" fn skey_engine_set_allow_consonant_zfwj(p: *mut UnikeyEngine, on: c_int) {
    unikey_engine_set_allow_consonant_zfwj(p, on)
}

/// Evaluates a mathematical expression using SKey Core's calc engine.
///
/// Writes the null-terminated formatted result into `out_buf`.
/// Returns 1 on success, 0 on failure/invalid expression.
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

