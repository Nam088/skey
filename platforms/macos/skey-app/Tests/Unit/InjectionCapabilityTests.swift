import XCTest
@testable import SKey

/// Guards the toolkit sniff that decides how injected text reaches an app.
///
/// Getting this wrong is silent: classify a Qt app as packed-capable and every macro longer
/// than the threshold vanishes, backspaces applied and nothing typed back, exactly the bug
/// that made "đánh kẻ chạy" come out as "đh kẻ ch" in TeXstudio. So the fixture apps below
/// are built on disk rather than mocked, and the unsafe direction (returning false when it
/// should be true) is asserted explicitly.
final class InjectionCapabilityTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("skey-injection-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    // MARK: - Helpers

    /// Builds a throwaway `.app` whose Frameworks directory holds `frameworks`.
    /// Pass an empty array for an app that ships no Frameworks directory at all.
    private func makeBundle(named name: String, frameworks: [String]?) throws -> URL {
        let bundle = root.appendingPathComponent("\(name).app")
        let macos = bundle.appendingPathComponent("Contents/MacOS")
        try FileManager.default.createDirectory(at: macos, withIntermediateDirectories: true)

        if let frameworks {
            let dir = bundle.appendingPathComponent("Contents/Frameworks")
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            for entry in frameworks {
                try FileManager.default.createDirectory(
                    at: dir.appendingPathComponent(entry), withIntermediateDirectories: true)
            }
        }
        return bundle
    }

    /// Each call uses a fresh bundle id: the answer is cached per id for the process lifetime.
    private func needsPerChar(_ url: URL?, id: String = UUID().uuidString) -> Bool {
        AppFocusObserver.needsPerCharacterInjection(for: id, bundleURL: url)
    }

    // MARK: - Qt must take the per-character path

    func testQtFrameworkLayoutNeedsPerCharacter() throws {
        // The layout TeXstudio 4.9.7 actually ships.
        let bundle = try makeBundle(named: "QtApp", frameworks: [
            "QtCore.framework", "QtGui.framework", "QtWidgets.framework",
        ])
        XCTAssertTrue(needsPerChar(bundle),
                      "A Qt bundle must never be sent packed multi-character events")
    }

    func testQtDylibLayoutNeedsPerCharacter() throws {
        // Qt is just as often shipped as plain dylibs instead of frameworks.
        let bundle = try makeBundle(named: "QtDylibApp", frameworks: [
            "libQt6Core.dylib", "libQt6Gui.dylib",
        ])
        XCTAssertTrue(needsPerChar(bundle),
                      "Qt shipped as dylibs must be detected as well as the framework layout")
    }

    func testQtAlongsideOtherFrameworksStillNeedsPerCharacter() throws {
        let bundle = try makeBundle(named: "MixedApp", frameworks: [
            "Sparkle.framework", "libssl.dylib", "QtCore.framework",
        ])
        XCTAssertTrue(needsPerChar(bundle),
                      "Qt must be found even when it is not the first entry listed")
    }

    // MARK: - Verified toolkits may take the packed path

    func testAppKitBundleWithoutFrameworksAllowsPacked() throws {
        // TextEdit shape: no bundled third-party runtime. Verified to accept packed events.
        let bundle = try makeBundle(named: "PlainApp", frameworks: nil)
        XCTAssertFalse(needsPerChar(bundle),
                       "A plain native app ships no Qt and was verified to accept packed events")
    }

    func testChromiumBundleAllowsPacked() throws {
        // VS Code shape. Verified to accept packed events.
        let bundle = try makeBundle(named: "ElectronApp", frameworks: [
            "Electron Framework.framework", "Squirrel.framework",
        ])
        XCTAssertFalse(needsPerChar(bundle),
                       "Chromium hosts were verified to accept packed events")
    }

    // MARK: - Unknown means slow, never fast

    func testMissingBundleURLFallsBackToPerCharacter() {
        XCTAssertTrue(needsPerChar(nil),
                      "An app whose bundle cannot be located must take the path that always works")
    }

    func testEmptyBundleIDFallsBackToPerCharacter() throws {
        let bundle = try makeBundle(named: "NoID", frameworks: nil)
        XCTAssertTrue(AppFocusObserver.needsPerCharacterInjection(for: "", bundleURL: bundle),
                      "A missing bundle id must not be treated as a verified app")
        XCTAssertTrue(AppFocusObserver.needsPerCharacterInjection(for: nil, bundleURL: bundle),
                      "A nil bundle id must not be treated as a verified app")
    }

    func testNonExistentBundlePathFallsBackToNoQt() {
        // A path that resolves to nothing has no Frameworks directory to read, so the sniff
        // reports "no Qt found". Recorded here so the behaviour is a decision, not a surprise:
        // the frontmost app always resolves to a real bundle, and an unresolvable one is
        // already caught by the nil-URL case above.
        let ghost = root.appendingPathComponent("Missing.app")
        XCTAssertFalse(needsPerChar(ghost))
    }

    // MARK: - Caching

    func testAnswerIsCachedPerBundleID() throws {
        let qt = try makeBundle(named: "CachedQt", frameworks: ["QtCore.framework"])
        let plain = try makeBundle(named: "CachedPlain", frameworks: nil)
        let id = "com.example.cached"

        XCTAssertTrue(AppFocusObserver.needsPerCharacterInjection(for: id, bundleURL: qt))
        // Same id, different bundle: the cached answer must win, since this is read on the
        // event tap hot path and must never hit the filesystem again.
        XCTAssertTrue(AppFocusObserver.needsPerCharacterInjection(for: id, bundleURL: plain),
                      "Result must be cached per bundle id after the first lookup")
    }
}
