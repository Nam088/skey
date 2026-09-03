import XCTest
import SwiftUI
import AppKit
@testable import SKey

final class ThemeSettingsTests: XCTestCase {
    var defaults: UserDefaults!
    var storage: SettingsStorage!
    var settings: GeneralSettings!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "com.skey.test.theme.\(UUID().uuidString)")!
        storage = SettingsStorage(defaults: defaults)
        settings = GeneralSettings(storage: storage)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: defaults.description)
        super.tearDown()
    }

    func testDefaultThemeIsSystem() {
        XCTAssertEqual(settings.appTheme, .system)
        XCTAssertNil(settings.appTheme.nsAppearance)
        XCTAssertNil(settings.appTheme.colorScheme)
    }

    func testSettingLightAndDarkTheme() {
        settings.appTheme = .light
        XCTAssertEqual(settings.appTheme, .light)
        XCTAssertEqual(settings.appTheme.colorScheme, .light)
        XCTAssertEqual(settings.appTheme.nsAppearance?.name, .aqua)

        settings.appTheme = .dark
        XCTAssertEqual(settings.appTheme, .dark)
        XCTAssertEqual(settings.appTheme.colorScheme, .dark)
        XCTAssertEqual(settings.appTheme.nsAppearance?.name, .darkAqua)
    }

    func testResetRestoresSystemTheme() {
        settings.appTheme = .dark
        settings.resetToDefaults()
        XCTAssertEqual(settings.appTheme, .system)
    }
}
