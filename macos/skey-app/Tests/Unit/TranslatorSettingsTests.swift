import XCTest
@testable import SKey

final class TranslatorSettingsTests: XCTestCase {
    private func makeSettings() -> TranslatorSettings {
        let suite = "TranslatorSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return TranslatorSettings(storage: SettingsStorage(defaults: defaults))
    }

    func testPreferredEngineDefaultsAndPersists() {
        let settings = makeSettings()
        XCTAssertEqual(settings.preferredEngine, .google)

        settings.preferredEngine = .deepl
        XCTAssertEqual(settings.preferredEngine, .deepl)
    }

    func testApiKeyUpdatesSelectedEngine() {
        let settings = makeSettings()
        settings.preferredEngine = .gemini
        settings.updateApiKey(for: .gemini, key: "TEST_KEY")

        XCTAssertEqual(settings.engines.first(where: { $0.type == .gemini })?.apiKey, "TEST_KEY")
        XCTAssertEqual(settings.engines.first(where: { $0.type == .google })?.apiKey, "")
    }

    func testResetRestoresPreferredEngineAndEngines() {
        let settings = makeSettings()
        settings.preferredEngine = .groq
        settings.updateApiKey(for: .groq, key: "TEST_KEY")

        settings.resetToDefaults()

        XCTAssertEqual(settings.preferredEngine, .google)
        XCTAssertEqual(settings.engines, TranslationEngineConfig.defaultList)
    }
}
