import AppKit
import ApplicationServices
import Foundation
import os.lock

// MARK: - AppCategory

public enum AppCategory: Int8, Sendable {
    case developerTool, webBrowser, electronOrChat, spotlight, nativeApp
}

// MARK: - AppFocusObserver

/// Thread-safe frontmost PID and dynamic AppCategory tracker with 0-allocation RAM cache.
public final class AppFocusObserver {
    public static let shared = AppFocusObserver()

    private var observer: NSObjectProtocol?
    private var lock = os_unfair_lock()
    private var _currentPID: pid_t = 0
    private var _currentBundleID: String?
    private var _currentCategory: AppCategory = .nativeApp

    private static var cache: [String: AppCategory] = [:]
    private static var cacheLock = os_unfair_lock()

    // MARK: - Dynamic Classification Engine

    public static func category(for bundleID: String?, bundleURL: URL? = nil) -> AppCategory {
        guard let bundleID, !bundleID.isEmpty else { return .nativeApp }
        if bundleID == "com.apple.Spotlight" { return .spotlight }

        // Fast RAM Cache lookup
        os_unfair_lock_lock(&cacheLock)
        if let cached = cache[bundleID] {
            os_unfair_lock_unlock(&cacheLock)
            return cached
        }
        os_unfair_lock_unlock(&cacheLock)

        let url = bundleURL ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        let detected = inspect(bundleURL: url, bundleID: bundleID)

        os_unfair_lock_lock(&cacheLock)
        cache[bundleID] = detected
        os_unfair_lock_unlock(&cacheLock)
        return detected
    }

    private static func inspect(bundleURL: URL?, bundleID: String) -> AppCategory {
        if let url = bundleURL {
            let fm = FileManager.default
            let fw = url.appendingPathComponent("Contents/Frameworks")

            // 1. Electron / CEF / QtWebEngine
            let isElectron = fm.fileExists(atPath: fw.appendingPathComponent("Electron Framework.framework").path) ||
                             fm.fileExists(atPath: fw.appendingPathComponent("Chromium Embedded Framework.framework").path) ||
                             fm.fileExists(atPath: fw.appendingPathComponent("QtWebEngineCore.framework").path) ||
                             fm.fileExists(atPath: url.appendingPathComponent("Contents/Resources/app.asar").path)
            if isElectron { return .electronOrChat }

            // 2. Info.plist inspection (Browser & Code Editor)
            let plistPath = url.appendingPathComponent("Contents/Info.plist")
            if let data = try? Data(contentsOf: plistPath),
               let dict = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any] {
                
                if let urls = dict["CFBundleURLTypes"] as? [[String: Any]],
                   urls.contains(where: { ($0["CFBundleURLSchemes"] as? [String])?.contains(where: { ["http", "https"].contains($0.lowercased()) }) == true }) {
                    return .webBrowser
                }

                if let docs = dict["CFBundleDocumentTypes"] as? [[String: Any]] {
                    let codeExts: Set<String> = ["swift", "c", "cpp", "h", "py", "rs", "go", "js", "ts", "java", "kt", "sh", "json", "yaml"]
                    let allExts = docs.flatMap { ($0["CFBundleTypeExtensions"] as? [String])?.map { $0.lowercased() } ?? [] }
                    if allExts.contains(where: { ["html", "htm", "xhtml"].contains($0) }) && codeExts.isDisjoint(with: allExts) {
                        return .webBrowser
                    }
                    if !codeExts.isDisjoint(with: allExts) {
                        return .developerTool
                    }
                }
            }
        }

        // 3. Fallback heuristic for virtual / uninstalled bundle IDs
        let id = bundleID.lowercased()
        if ["browser", "chrome", "safari", "firefox", "edge", "yandex"].contains(where: id.contains) { return .webBrowser }
        if ["zalo", "slack", "discord", "teams", "telegram", "notion"].contains(where: id.contains) { return .electronOrChat }
        if ["xcode", "vscode", "terminal", "iterm", "ghostty", "intellij", "warp"].contains(where: id.contains) { return .developerTool }
        return .nativeApp
    }

    // MARK: - State Accessors

    public var currentPID: pid_t {
        os_unfair_lock_lock(&lock); defer { os_unfair_lock_unlock(&lock) }
        return _currentPID
    }

    public var currentBundleID: String? {
        os_unfair_lock_lock(&lock); defer { os_unfair_lock_unlock(&lock) }
        return _currentBundleID
    }

    public var currentCategory: AppCategory {
        os_unfair_lock_lock(&lock); defer { os_unfair_lock_unlock(&lock) }
        return _currentCategory
    }

    private init() {
        if let app = NSWorkspace.shared.frontmostApplication { updateFrontmostApp(app) }
    }

    public func startObserving(onAppChange: @escaping (_ bundleID: String?) -> Void) {
        stopObserving()
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notif in
            guard let self else { return }
            let app = notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self.updateFrontmostApp(app)
            onAppChange(app?.bundleIdentifier)
        }
    }

    public func stopObserving() {
        if let obs = observer {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            observer = nil
        }
    }

    private func updateFrontmostApp(_ app: NSRunningApplication?) {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }

        guard let app else {
            _currentPID = 0; _currentBundleID = nil; _currentCategory = .nativeApp
            return
        }

        _currentPID = app.processIdentifier
        _currentBundleID = app.bundleIdentifier
        _currentCategory = Self.category(for: app.bundleIdentifier, bundleURL: app.bundleURL)

        if _currentCategory == .webBrowser || _currentCategory == .spotlight {
            let appElem = AXUIElementCreateApplication(app.processIdentifier)
            _ = AXUIElementSetAttributeValue(appElem, "AXManualAccessibility" as CFString, kCFBooleanTrue)
            _ = AXUIElementSetAttributeValue(appElem, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
        }
    }
}
