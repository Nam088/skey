import CoreGraphics
import Foundation

// MARK: - InterceptorResult

public enum InterceptorResult {
    /// The event is allowed to continue down the pipeline to the next interceptor or to the OS.
    case passThrough
    /// The event was consumed and handled by the interceptor and should be swallowed (not delivered to OS).
    case swallowed
}

// MARK: - KeyInterceptor Protocol

/// Chain of Responsibility pattern component for keyboard & mouse event processing.
/// Each interceptor has a single responsibility (e.g. self-event detection, hotkey handling, engine composing).
public protocol KeyInterceptor: AnyObject {
    /// Inspects or transforms the event. Returns .swallowed if the event should not propagate further.
    func process(event: CGEvent, type: CGEventType) -> InterceptorResult
}
