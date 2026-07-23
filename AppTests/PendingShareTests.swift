import XCTest

final class PendingShareTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testSanitizesTextURLAndDirectionalControls() {
        let payload = PendingShareSanitizer.payload(
            title: "  Quote\u{202E} title  ",
            text: "\0Cargo details\n",
            url: "https://example.com/request"
        )
        XCTAssertEqual(payload?.title, "Quote title")
        XCTAssertEqual(payload?.text, "Cargo details")
        XCTAssertEqual(payload?.url, "https://example.com/request")
        XCTAssertNil(PendingShareSanitizer.cleanURL("javascript:alert(1)"))
        XCTAssertNil(PendingShareSanitizer.cleanURL("https://user:password@example.com"))
    }

    func testSerializationRoundTripConsumesAndDeletesFile() throws {
        let fileURL = temporaryDirectory.appendingPathComponent("pending-share.json")
        let store = PendingShareStore(fileURL: fileURL)
        let createdAt = Date()
        let payload = PendingShareSanitizer.payload(
            createdAt: createdAt,
            title: "Rate request",
            text: "SGN to SIN",
            url: nil
        )!
        try store.save(payload)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        let consumed = store.consume(now: createdAt.addingTimeInterval(100))
        XCTAssertEqual(consumed?.title, payload.title)
        XCTAssertEqual(consumed?.text, payload.text)
        XCTAssertEqual(consumed?.url, payload.url)
        XCTAssertEqual(consumed?.createdAt.timeIntervalSince1970, payload.createdAt.timeIntervalSince1970, accuracy: 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertNil(store.consume(now: createdAt.addingTimeInterval(100)))
    }

    func testExpiredAndOversizedPayloadsFailClosedAndDeleteFile() throws {
        let fileURL = temporaryDirectory.appendingPathComponent("pending-share.json")
        let store = PendingShareStore(fileURL: fileURL)
        let expired = PendingSharePayload(
            createdAt: Date(timeIntervalSince1970: 0),
            title: "Expired",
            text: nil,
            url: nil
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(expired).write(to: fileURL)
        XCTAssertNil(store.consume(now: Date(timeIntervalSince1970: 1_000)))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))

        try Data(repeating: 65, count: PendingShareSanitizer.maximumEncodedBytes + 1).write(to: fileURL)
        XCTAssertNil(store.consume())
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }
}
