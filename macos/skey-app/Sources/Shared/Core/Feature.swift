import AppKit
import Foundation

// MARK: - Feature Protocol

/// A pluggable capability in the SKey Super App ecosystem
/// (e.g. Keyboard Engine, Clipboard Manager, Snippets, AI Assistant, etc.)
public protocol Feature: AnyObject {
    /// Unique identifier for the feature (e.g. "com.nam088.skey.keyboard")
    var id: String { get }

    /// Human readable feature name
    var name: String { get }

    /// Whether this feature is currently active. Read-only — use enable()/disable() to change.
    var isEnabled: Bool { get }

    /// Activates the feature. Idempotent: safe to call multiple times.
    func enable()

    /// Deactivates the feature. Idempotent: safe to call multiple times.
    func disable()

    /// Called once at app startup. Internally calls enable() if isEnabled is true.
    func start()

    /// Called at app termination or feature removal.
    func stop()

    /// Generates menu items to be placed into the main Status Bar menu.
    func buildMenuItems() -> [NSMenuItem]
}

// MARK: - Default implementations

public extension Feature {
    /// Default enable: just calls start(). Override to add custom activation logic.
    func enable() { start() }

    /// Default disable: just calls stop(). Override to add custom deactivation logic.
    func disable() { stop() }
}
