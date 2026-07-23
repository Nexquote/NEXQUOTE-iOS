import XCTest

final class LocalizationTests: XCTestCase {
    func testCriticalEnglishAndVietnameseKeysExist() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        for language in ["en", "vi"] {
            let file = root.appendingPathComponent("Shared/\(language).lproj/Localizable.strings")
            let content = try String(contentsOf: file, encoding: .utf8)
            for key in [
                "quick.create_quote",
                "quick.import_rates",
                "quick.decision_inbox",
                "share.save",
                "share.save_failed",
            ] {
                XCTAssertTrue(content.contains("\"\(key)\""), "Missing \(key) in \(language)")
            }
        }
    }
}
