import XCTest
@testable import SKey

/// Locks down version comparison against the repo's actual tag shapes.
///
/// This is not hypothetical coverage. Release tags are platform prefixed (`mac-v1.0.9`), and
/// the previous parser split on "-" and kept the first piece, reducing `mac-v1.0.9` to `mac`
/// and then to an empty number list. Every remote version compared as 0, so the app told
/// every user "you are on the latest version" forever, no matter how far behind they were.
/// The failure was invisible: no crash, no error state, just an update button that never
/// found anything.
final class UpdateCheckerVersionTests: XCTestCase {

    // MARK: - Tag shapes that actually ship

    func testPlatformPrefixedTagIsParsed() {
        XCTAssertEqual(UpdateCheckerService.parseNumbers("mac-v1.0.9"), [1, 0, 9])
        XCTAssertEqual(UpdateCheckerService.parseNumbers("win-v1.0.8"), [1, 0, 8])
    }

    func testPlainAndVPrefixedTagsAreParsed() {
        XCTAssertEqual(UpdateCheckerService.parseNumbers("1.0.9"), [1, 0, 9])
        XCTAssertEqual(UpdateCheckerService.parseNumbers("v1.0.9"), [1, 0, 9])
        XCTAssertEqual(UpdateCheckerService.parseNumbers("V1.0.9"), [1, 0, 9])
    }

    func testPreReleaseSuffixIsDropped() {
        XCTAssertEqual(UpdateCheckerService.parseNumbers("mac-v1.2.0-beta.2"), [1, 2, 0])
        XCTAssertEqual(UpdateCheckerService.parseNumbers("1.2.0-rc1"), [1, 2, 0])
    }

    func testUnparseableInputYieldsNoNumbers() {
        XCTAssertEqual(UpdateCheckerService.parseNumbers(""), [])
        XCTAssertEqual(UpdateCheckerService.parseNumbers("latest"), [])
    }

    // MARK: - The regression that disabled updates

    func testNewerPrefixedRemoteIsDetectedAsUpdate() {
        // The exact case that silently failed: a published mac-v1.0.9 against a 1.0.6 install.
        XCTAssertEqual(UpdateCheckerService.compareSemVer(remote: "mac-v1.0.9", local: "1.0.6"),
                       .orderedDescending)
        // A whole major version ahead was also reported as "up to date" before.
        XCTAssertEqual(UpdateCheckerService.compareSemVer(remote: "mac-v2.0.0", local: "1.0.6"),
                       .orderedDescending)
    }

    func testOlderAndEqualRemotesAreNotOffered() {
        XCTAssertEqual(UpdateCheckerService.compareSemVer(remote: "mac-v1.0.5", local: "1.0.6"),
                       .orderedAscending)
        XCTAssertEqual(UpdateCheckerService.compareSemVer(remote: "mac-v1.0.6", local: "1.0.6"),
                       .orderedSame)
    }

    func testMissingTrailingComponentsCountAsZero() {
        XCTAssertEqual(UpdateCheckerService.compareSemVer(remote: "mac-v1.1", local: "1.0.6"),
                       .orderedDescending)
        XCTAssertEqual(UpdateCheckerService.compareSemVer(remote: "mac-v1.0", local: "1.0.0"),
                       .orderedSame)
    }

    // MARK: - Never offer an update on garbage

    func testUnparseableVersionsCompareEqualRatherThanGuessing() {
        // Reporting an update off an unreadable version would push users at a download we
        // cannot vouch for; reporting "older" hides real updates. Equal is the honest answer.
        XCTAssertEqual(UpdateCheckerService.compareSemVer(remote: "latest", local: "1.0.6"),
                       .orderedSame)
        XCTAssertEqual(UpdateCheckerService.compareSemVer(remote: "mac-v1.0.9", local: ""),
                       .orderedSame)
    }
}
