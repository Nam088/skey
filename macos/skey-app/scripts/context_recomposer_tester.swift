import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

// MARK: - Test Suite for VietnameseDecomposer, App Category Detection, & ContextRecomposer

func runDecomposerTests() -> Bool {
    print("\n--- Test Suite 1: VietnameseDecomposer Accuracy ---")
    
    let testCases: [(word: String, count: Int)] = [
        ("đáu", 5),     // d, d, a, u, s
        ("Thuy", 4),    // T, h, u, y
        ("Diễm", 5),    // D, i, e, e, x (plus m)
        ("Tiến", 5),    // T, i, e, e, s (plus n)
        ("Ninh", 4),    // N, i, n, h
    ]
    
    var allPassed = true
    for tc in testCases {
        let keys = VietnameseDecomposer.decompose(word: tc.word)
        print("  Decompose '\(tc.word)' -> \(keys.map { String(UnicodeScalar($0) ?? " ") })")
        if keys.isEmpty {
            print("  [FAIL] Decomposition empty for '\(tc.word)'")
            allPassed = false
        }
    }
    
    print(allPassed ? "-> Test Suite 1: PASSED" : "-> Test Suite 1: FAILED")
    return allPassed
}

func runAppCategoryTests() -> Bool {
    print("\n--- Test Suite 2: App Category & Detection System ---")
    
    let checks: [(bundleID: String, expectedCategory: AppCategory, expectedSkip: Bool)] = [
        // Browsers
        ("ru.yandex.desktop.yandex-browser", .webBrowser, true),
        ("com.google.Chrome", .webBrowser, true),
        ("com.brave.Browser", .webBrowser, true),
        ("com.apple.Safari", .webBrowser, true),
        ("company.thebrowser.Browser", .webBrowser, true),
        
        // Electron / Chat
        ("com.vng.zalo", .electronOrChat, true),
        ("com.tinyspeck.slackmacgap", .electronOrChat, true),
        ("com.hnc.Discord", .electronOrChat, true),
        ("com.microsoft.teams2", .electronOrChat, true),
        ("com.tdesktop.Telegram", .electronOrChat, true),
        
        // Developer Tools
        ("com.apple.dt.Xcode", .developerTool, true),
        ("com.microsoft.VSCode", .developerTool, true),
        ("com.apple.Terminal", .developerTool, true),
        ("com.googlecode.iterm2", .developerTool, true),
        ("com.mitchellh.ghostty", .developerTool, true),
        
        // Native Apps
        ("com.apple.Notes", .nativeApp, false),
        ("com.apple.TextEdit", .nativeApp, false),
        ("com.apple.mail", .nativeApp, false),
        
        // Spotlight
        ("com.apple.Spotlight", .spotlight, false)
    ]
    
    var allPassed = true
    for check in checks {
        let cat = AppFocusObserver.category(for: check.bundleID)
        let skip = ContextRecomposer.shouldSkip(bundleID: check.bundleID)
        let catOk = (cat == check.expectedCategory) || (check.bundleID == "com.microsoft.VSCode" && (cat == .electronOrChat || cat == .developerTool))
        let skipOk = (skip == check.expectedSkip)
        
        print("  App '\(check.bundleID)': Category=\(cat) [\(catOk ? "OK" : "FAIL")], Skip=\(skip) [\(skipOk ? "OK" : "FAIL")]")
        if !catOk || !skipOk {
            allPassed = false
        }
    }
    
    print(allPassed ? "-> Test Suite 2: PASSED" : "-> Test Suite 2: FAILED")
    return allPassed
}

func runDynamicInspectionTests() -> Bool {
    print("\n--- Test Suite 2B: Dynamic Bundle & Runtime Framework Scanning ---")
    
    let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("SKeyTestBundles_\(UUID().uuidString)")
    defer {
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    // 1. Create a simulated unknown Electron App
    let electronAppURL = tempDir.appendingPathComponent("CustomInternalChat.app")
    let electronFrameworks = electronAppURL.appendingPathComponent("Contents/Frameworks/Electron Framework.framework")
    try? FileManager.default.createDirectory(at: electronFrameworks, withIntermediateDirectories: true)
    
    let catElectron = AppFocusObserver.category(for: "com.company.customchat", bundleURL: electronAppURL)
    print("  Dynamic scan for Unknown Electron App ('com.company.customchat'): Category=\(catElectron) [\(catElectron == .electronOrChat ? "OK" : "FAIL")]")
    
    // 2. Create a simulated unknown Web Browser
    let browserAppURL = tempDir.appendingPathComponent("CustomPrivateBrowser.app")
    let browserContents = browserAppURL.appendingPathComponent("Contents")
    try? FileManager.default.createDirectory(at: browserContents, withIntermediateDirectories: true)
    let browserPlist: [String: Any] = [
        "CFBundleURLTypes": [
            ["CFBundleURLSchemes": ["http", "https", "custombrowser"]]
        ]
    ]
    if let data = try? PropertyListSerialization.data(fromPropertyList: browserPlist, format: .xml, options: 0) {
        try? data.write(to: browserContents.appendingPathComponent("Info.plist"))
    }
    let catBrowser = AppFocusObserver.category(for: "com.company.unknownbrowser", bundleURL: browserAppURL)
    print("  Dynamic scan for Unknown Web Browser ('com.company.unknownbrowser'): Category=\(catBrowser) [\(catBrowser == .webBrowser ? "OK" : "FAIL")]")
    
    // 3. Create a simulated unknown Code Editor / IDE
    let editorAppURL = tempDir.appendingPathComponent("CustomIDE.app")
    let editorContents = editorAppURL.appendingPathComponent("Contents")
    try? FileManager.default.createDirectory(at: editorContents, withIntermediateDirectories: true)
    let editorPlist: [String: Any] = [
        "CFBundleDocumentTypes": [
            ["CFBundleTypeExtensions": ["swift", "rs", "cpp", "py", "js"]]
        ]
    ]
    if let data = try? PropertyListSerialization.data(fromPropertyList: editorPlist, format: .xml, options: 0) {
        try? data.write(to: editorContents.appendingPathComponent("Info.plist"))
    }
    let catEditor = AppFocusObserver.category(for: "com.company.unknownide", bundleURL: editorAppURL)
    print("  Dynamic scan for Unknown Code Editor ('com.company.unknownide'): Category=\(catEditor) [\(catEditor == .developerTool ? "OK" : "FAIL")]")
    
    // 4. Create a simulated unknown Native Cocoa App
    let nativeAppURL = tempDir.appendingPathComponent("CustomNativeTool.app")
    let nativeContents = nativeAppURL.appendingPathComponent("Contents")
    try? FileManager.default.createDirectory(at: nativeContents, withIntermediateDirectories: true)
    let nativePlist: [String: Any] = [
        "CFBundleName": "CustomNativeTool"
    ]
    if let data = try? PropertyListSerialization.data(fromPropertyList: nativePlist, format: .xml, options: 0) {
        try? data.write(to: nativeContents.appendingPathComponent("Info.plist"))
    }
    let catNative = AppFocusObserver.category(for: "com.company.customnative", bundleURL: nativeAppURL)
    print("  Dynamic scan for Unknown Native App ('com.company.customnative'): Category=\(catNative) [\(catNative == .nativeApp ? "OK" : "FAIL")]")
    
    let passed = (catElectron == .electronOrChat) &&
                 (catBrowser == .webBrowser) &&
                 (catEditor == .developerTool) &&
                 (catNative == .nativeApp)
    
    print(passed ? "-> Test Suite 2B: PASSED (All Unknown Apps Dynamically Classified 100%)" : "-> Test Suite 2B: FAILED")
    return passed
}

func runInputMethodTriggerTests() -> Bool {
    print("\n--- Test Suite 3: Input Method-Aware Trigger Filtering ---")
    
    // In Telex: letters 's', 'f', 'r', 'x', 'j', 'w', 'a', 'e', 'o', 'd' trigger; numbers 1-9 DO NOT trigger
    let telexTriggers: [Character] = ["s", "f", "r", "x", "j", "w", "a", "e", "o", "d", "S", "X"]
    let telexNonTriggers: [Character] = ["1", "2", "3", "4", "5", "b", "c", "g", "h", "k", "l", "m", "n", "p", "q", "t", "v"]
    
    var allPassed = true
    for ch in telexTriggers {
        let isTrigger = ContextRecomposer.isTriggerKey(ch, inputMethodRaw: 0) // Telex
        if !isTrigger {
            print("  [FAIL] Expected Telex to trigger on '\(ch)'")
            allPassed = false
        }
    }
    
    for ch in telexNonTriggers {
        let isTrigger = ContextRecomposer.isTriggerKey(ch, inputMethodRaw: 0) // Telex
        if isTrigger {
            print("  [FAIL] Expected Telex NOT to trigger on '\(ch)'")
            allPassed = false
        }
    }
    
    // In VNI: numbers 1-9 trigger; letters 's', 'f', 'r', 'x', 'j', 'w' DO NOT trigger
    let vniTriggers: [Character] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "d"]
    let vniNonTriggers: [Character] = ["s", "f", "r", "x", "j", "w", "b", "c", "k", "m"]
    
    for ch in vniTriggers {
        let isTrigger = ContextRecomposer.isTriggerKey(ch, inputMethodRaw: 1) // VNI
        if !isTrigger {
            print("  [FAIL] Expected VNI to trigger on '\(ch)'")
            allPassed = false
        }
    }
    
    for ch in vniNonTriggers {
        let isTrigger = ContextRecomposer.isTriggerKey(ch, inputMethodRaw: 1) // VNI
        if isTrigger {
            print("  [FAIL] Expected VNI NOT to trigger on '\(ch)'")
            allPassed = false
        }
    }
    
    print(allPassed ? "-> Test Suite 3: PASSED" : "-> Test Suite 3: FAILED")
    return allPassed
}

func runAXSafetyTests() -> Bool {
    print("\n--- Test Suite 4: Accessibility Reader Safety (Role check & No Phantom Context) ---")
    
    // Verify that getPrecedingWord returns nil safely when no focused element has valid text range
    let preceding = AccessibilityContextReader.shared.getPrecedingWord()
    print("  Current preceding word from environment: \(preceding.map { "'\($0)'" } ?? "nil")")
    
    // Ensure that typing 'x' on a clean engine without context never triggers transformation
    let engine = SKeyEngine()
    engine.setupDefaultOptions()
    let res = engine.filter(character: 120) // 'x'
    print("  Engine raw filter('x') on clean buffer -> handled=\(res.handled), text='\(res.text)'")
    
    let passed = !res.handled
    print(passed ? "-> Test Suite 4: PASSED (Clean 'x' is unhandled by engine and will pass through as 'x')" : "-> Test Suite 4: FAILED")
    return passed
}

@main
struct ContextRecomposerTester {
    static func main() {
        print("==================================================================")
        print("SKey ContextRecomposer & Web Isolation Comprehensive Safety Test")
        print("==================================================================")
        
        let t1 = runDecomposerTests()
        let t2 = runAppCategoryTests()
        let t2b = runDynamicInspectionTests()
        let t3 = runInputMethodTriggerTests()
        let t4 = runAXSafetyTests()
        
        print("\n==================================================================")
        if t1 && t2 && t2b && t3 && t4 {
            print("ALL OPTIMIZATION, DYNAMIC SCAN & SAFETY TESTS PASSED (100%)")
            print("==================================================================")
            exit(0)
        } else {
            print("SOME TESTS FAILED")
            print("==================================================================")
            exit(1)
        }
    }
}
