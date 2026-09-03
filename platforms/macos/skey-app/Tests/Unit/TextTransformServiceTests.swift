import XCTest
@testable import SKey

final class TextTransformServiceTests: XCTestCase {
    func testVniWindowsToUnicodeConversion() {
        let service = TextTransformService.shared
        // "baét caù" should convert to "bắt cá"
        let converted = service.vniToUnicode("baét caù")
        XCTAssertEqual(converted, "bắt cá", "aé must convert to ắ, and aù must convert to á without collision")
    }

    func testUnicodeToVniWindowsConversion() {
        let service = TextTransformService.shared
        // "bắt cá" should convert to "baét caù"
        let converted = service.unicodeToVni("bắt cá")
        XCTAssertEqual(converted, "baét caù", "ắ must convert to aé without corrupting to aù")
    }
}
