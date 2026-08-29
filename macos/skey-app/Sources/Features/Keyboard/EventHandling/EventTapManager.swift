import AppKit
import ApplicationServices
import Carbon
import Foundation
import os.lock

// MARK: - Delegate

public protocol EventTapManagerDelegate: AnyObject {
    func statusDidChange(isVietnamese: Bool)
}

// MARK: - EventTapManager

/// Manages the low-level CoreGraphics EventTap lifecycle and thread hosting.
/// Event logic processing is delegated to TypingPipeline via Chain of Responsibility.
public final class EventTapManager {
    // MARK: - Shared

    public static let shared = EventTapManager()

    // MARK: - Public state

    public weak var delegate: EventTapManagerDelegate?
    public let engine = SKeyEngine()

    private lazy var pipeline = TypingPipeline(
        engine: engine,
        languageProvider: { [weak self] in self?.isVietnamese ?? true },
        onToggleLanguage: { [weak self] in self?.toggleLanguage() }
    )

    /// Thread-safe read/write of language state using ultra-fast os_unfair_lock.
    /// Written from main thread (menu click) and tap thread (Option+Z hotkey).
    public var isVietnamese: Bool {
        get {
            os_unfair_lock_lock(&languageLock)
            defer { os_unfair_lock_unlock(&languageLock) }
            return _isVietnamese
        }
        set {
            os_unfair_lock_lock(&languageLock)
            _isVietnamese = newValue
            os_unfair_lock_unlock(&languageLock)
            engine.reset()
            // Move UserDefaults write + UI callback to main thread:
            // isVietnamese setter can be called from the tap thread (Option+Z hotkey),
            // so UserDefaults.set() must not run there (it may trigger KVO / disk flush).
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                AppSettings.shared.keyboard.isVietnamese = newValue
                self.delegate?.statusDidChange(isVietnamese: newValue)
            }
        }
    }

    // MARK: - Private state

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tapRunLoop: CFRunLoop?
    private var tapThread: Thread?
    private var tapThreadLock = os_unfair_lock()

    /// Dedicated unfair lock for isVietnamese — sub-microsecond latency, zero heap allocation.
    private var languageLock = os_unfair_lock()
    private var _isVietnamese: Bool = true

    private init() {
        _isVietnamese = AppSettings.shared.keyboard.isVietnamese
    }

    // MARK: - Language

    public var isListening: Bool { eventTap != nil }
    public func toggleLanguage() { isVietnamese.toggle() }
    public func setLanguage(vietnamese: Bool) { isVietnamese = vietnamese }

    // MARK: - Lifecycle

    public func start() -> Bool {
        guard eventTap == nil else { return true }

        let ax = AXIsProcessTrusted()
        let im = CGPreflightListenEventAccess()
        skeyLog("Starting EventTap. AX=\(ax) IM=\(im)", category: .keyboard)

        let callback: CGEventTapCallBack = { _, type, event, _ in
            EventTapManager.shared.handleEvent(type: type, event: event)
        }

        guard let tap = createTap(callback: callback) else {
            skeyLog("[Error] CGEventTap creation failed", category: .keyboard)
            return false
        }

        eventTap      = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        startDedicatedThread(tap: tap)
        
        // No watchdog timer needed - callback detects tap-disabled events instantly
        skeyLog("EventTap started successfully (instant detection mode)", category: .keyboard)
        return true
    }

    public func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            eventTap = nil
        }
        if let src = runLoopSource, let rl = tapRunLoop {
            CFRunLoopRemoveSource(rl, src, .commonModes)
            runLoopSource = nil
        }
        // Stop the tap thread's run loop so the thread exits cleanly.
        if let rl = tapRunLoop {
            CFRunLoopStop(rl)
            tapRunLoop = nil
            tapThread = nil
        }
        skeyLog("EventTap stopped", category: .keyboard)
    }

    // MARK: - Private helpers

    /// Tries `.cghidEventTap` first, falls back to `.cgSessionEventTap`.
    private func createTap(callback: @escaping CGEventTapCallBack) -> CFMachPort? {
        let mask: CGEventMask = eventMask(.keyDown, .keyUp, .flagsChanged, .leftMouseDown, .rightMouseDown, .otherMouseDown)

        if let tap = CGEvent.tapCreate(tap: .cghidEventTap, place: .headInsertEventTap,
                                       options: .defaultTap, eventsOfInterest: mask,
                                       callback: callback, userInfo: nil) { return tap }

        skeyLog("cghidEventTap failed, trying cgSessionEventTap", category: .keyboard)
        return CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                 options: .defaultTap, eventsOfInterest: mask,
                                 callback: callback, userInfo: nil)
    }

    /// Starts a permanent, high-priority thread hosting the tap run loop.
    private func startDedicatedThread(tap: CFMachPort) {
        let ready = DispatchSemaphore(value: 0)

        let thread = Thread { [weak self] in
            guard let self else { return }
            let rl = CFRunLoopGetCurrent()!

            os_unfair_lock_lock(&self.tapThreadLock)
            self.tapRunLoop = rl
            os_unfair_lock_unlock(&self.tapThreadLock)

            if let src = self.runLoopSource { CFRunLoopAddSource(rl, src, .commonModes) }
            CGEvent.tapEnable(tap: tap, enable: true)
            ready.signal()

            // CFRunLoopRun blocks until CFRunLoopStop() is called from stop().
            CFRunLoopRun()
        }
        thread.name = "com.nam088.skey.eventtap"
        thread.qualityOfService = .userInteractive
        thread.start()

        os_unfair_lock_lock(&tapThreadLock)
        tapThread = thread
        os_unfair_lock_unlock(&tapThreadLock)

        ready.wait()
    }

    // MARK: - Event handling

    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Handle tap-disabled events IMMEDIATELY - pass through to prevent freeze
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            skeyLog("Event tap disabled (type: \(type)) - quitting app", category: .keyboard)
            
            // CRITICAL: Pass through ALL events FIRST before anything else
            // This ensures keyboard works immediately without delay
            let retainedEvent = Unmanaged.passRetained(event)
            
            // Quit app INSTANTLY using exit() - no graceful shutdown delay
            // User must restart after re-granting permissions
            DispatchQueue.global(qos: .background).async {
                exit(0)
            }
            
            return retainedEvent
        }

        // Delegate event evaluation to pipeline
        let result = pipeline.process(event: event, type: type)
        switch result {
        case .passThrough:
            return .passRetained(event)
        case .swallowed:
            return nil
        }
    }
}

// MARK: - Utilities

private func eventMask(_ types: CGEventType...) -> CGEventMask {
    types.reduce(0) { $0 | (1 << CGEventMask($1.rawValue)) }
}
