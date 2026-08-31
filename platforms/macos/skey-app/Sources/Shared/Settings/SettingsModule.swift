import Combine
import Foundation

// MARK: - SettingsModule Protocol

/// Protocol for modular settings modules in the SKey Super App ecosystem.
public protocol SettingsModule: ObservableObject {
    /// Distinct key prefix for namespacing
    static var prefix: String { get }
    
    /// Registers default values for this module into storage
    func registerDefaults(in storage: SettingsStorage)
    
    /// Resets all values in this module to factory defaults
    func resetToDefaults()
}
