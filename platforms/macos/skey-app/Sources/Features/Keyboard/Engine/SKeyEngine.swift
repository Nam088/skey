import Foundation
import os.lock

// MARK: - SKeyEngine

/// High-performance wrapper around the core Rust Vietnamese typing engine.
/// Optimized for zero heap allocations on the hot path and sub-microsecond latency.
public final class SKeyEngine {
    // MARK: - ProcessResult

    public struct ProcessResult {
        public let handled: Bool
        public let backspaces: Int
        public let text: String

        public static let unhandled = ProcessResult(handled: false, backspaces: 0, text: "")
    }

    // MARK: - State

    private var engine: OpaquePointer?
    /// Low-overhead 4-byte unfair lock (10-15x faster than NSLock, zero heap allocation)
    private var lock = os_unfair_lock()

    // MARK: - Lifecycle

    public init() {
        engine = skey_engine_create()
        setupDefaultOptions()
    }

    deinit {
        engine.map(skey_engine_free)
    }

    // MARK: - Configuration

    public func setupDefaultOptions() {
        withEngine { eng in
            var opt = SKeyOptions(
                freeMarking: 1,
                modernStyle: 0,
                macroEnabled: 0,
                useUnicodeClipboard: 0,
                alwaysMacro: 0,
                strictSpellCheck: 0,
                useIME: 1,
                spellCheckEnabled: 1,
                autoNonVnRestore: 1
            )
            skey_engine_set_options(eng, &opt)
            skey_engine_set_charset(eng, 12)  // XUTF8
            skey_engine_set_input_method_raw(eng, InputMethodType.telex.rawValue)
            skey_engine_set_swallowed_key_restore(eng, 1)
            skey_engine_set_quick_telex(eng, 0)
            skey_engine_set_quick_start_consonant(eng, 0)
            skey_engine_set_quick_end_consonant(eng, 0)
            skey_engine_set_upper_case_first_char(eng, 0)
            skey_engine_set_allow_consonant_zfwj(eng, 0)
        }
    }

    public func setInputMethod(_ method: InputMethodType) {
        withEngine { eng in
            skey_engine_set_input_method_raw(eng, method.rawValue)
            skey_engine_reset(eng)
        }
    }

    public func setCharset(_ charset: Int32) {
        withEngine { eng in
            skey_engine_set_charset(eng, charset)
            skey_engine_reset(eng)
        }
    }

    public func setSpellCheck(_ enabled: Bool) {
        setOption { opt in
            opt.spellCheckEnabled = enabled ? 1 : 0
            opt.autoNonVnRestore  = enabled ? 1 : 0
        }
    }

    public func setModernStyle(_ enabled: Bool) {
        setOption { opt in opt.modernStyle = enabled ? 1 : 0 }
    }

    public func setFreeMarking(_ enabled: Bool) {
        setOption { opt in opt.freeMarking = enabled ? 1 : 0 }
    }

    public func setSwallowedKeyRestore(_ enabled: Bool) {
        withEngine { eng in
            skey_engine_set_swallowed_key_restore(eng, enabled ? 1 : 0)
        }
    }

    public func setQuickTelex(_ enabled: Bool) {
        withEngine { eng in
            skey_engine_set_quick_telex(eng, enabled ? 1 : 0)
        }
    }

    public func setQuickStartConsonant(_ enabled: Bool) {
        withEngine { eng in
            skey_engine_set_quick_start_consonant(eng, enabled ? 1 : 0)
        }
    }

    public func setQuickEndConsonant(_ enabled: Bool) {
        withEngine { eng in
            skey_engine_set_quick_end_consonant(eng, enabled ? 1 : 0)
        }
    }

    public func setUpperCaseFirstChar(_ enabled: Bool) {
        withEngine { eng in
            skey_engine_set_upper_case_first_char(eng, enabled ? 1 : 0)
        }
    }

    public func setAllowConsonantZFWJ(_ enabled: Bool) {
        withEngine { eng in
            skey_engine_set_allow_consonant_zfwj(eng, enabled ? 1 : 0)
        }
    }

    public func reset() {
        withEngine(skey_engine_reset)
    }

    public func setCapsState(shiftPressed: Bool, capsLockOn: Bool) {
        withEngine { eng in
            skey_engine_set_caps_state(eng, shiftPressed ? 1 : 0, capsLockOn ? 1 : 0)
        }
    }

    // MARK: - Processing

    public func filter(character: UInt32) -> ProcessResult {
        withEngine { eng in
            let edit = skey_engine_filter(eng, character)
            return edit.handled != 0 ? readResult(edit, from: eng) : .unhandled
        } ?? .unhandled
    }

    public func backspace() -> ProcessResult {
        withEngine { eng in
            let edit = skey_engine_backspace(eng)
            return edit.handled != 0 ? readResult(edit, from: eng) : .unhandled
        } ?? .unhandled
    }

    // MARK: - Helpers

    @discardableResult
    private func withEngine<T>(_ body: (OpaquePointer) -> T) -> T? {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        guard let eng = engine else { return nil }
        return body(eng)
    }

    private func setOption(_ mutate: (inout SKeyOptions) -> Void) {
        withEngine { eng in
            var opt = SKeyOptions()
            skey_engine_get_options(eng, &opt)
            mutate(&opt)
            skey_engine_set_options(eng, &opt)
        }
    }

    /// Zero-heap-allocation UTF-8 extraction using a stack-allocated buffer
    private func readResult(_ edit: SKeyEdit, from eng: OpaquePointer) -> ProcessResult {
        guard edit.len > 0 else {
            return ProcessResult(handled: true, backspaces: Int(edit.backspaces), text: "")
        }

        // Vietnamese words are strictly <= 64 bytes.
        // withUnsafeTemporaryAllocation provides stack storage via alloca without any heap malloc.
        let capacity = max(64, Int(edit.len) + 4)
        return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: capacity) { buffer in
            guard let basePtr = buffer.baseAddress else {
                return ProcessResult(handled: true, backspaces: Int(edit.backspaces), text: "")
            }
            let written = skey_engine_output(eng, basePtr, Int32(buffer.count))
            guard written > 0 else {
                return ProcessResult(handled: true, backspaces: Int(edit.backspaces), text: "")
            }

            let text = String(decoding: UnsafeBufferPointer(start: basePtr, count: Int(written)), as: UTF8.self)
            return ProcessResult(handled: true, backspaces: Int(edit.backspaces), text: text)
        }
    }
}
