import XCTest

final class AppConfigurationTests: XCTestCase {
    func testHarnessTrustsOnlyLocalCapacitorOrigin() {
        let configuration = AppConfiguration(mode: .harness)
        XCTAssertTrue(configuration.trusts(protocol: "capacitor", host: "localhost"))
        XCTAssertTrue(configuration.trusts(protocol: "https", host: "localhost"))
        XCTAssertFalse(configuration.trusts(protocol: "https", host: "localhost", port: 444))
        XCTAssertFalse(configuration.trusts(protocol: "https", host: "evil.example"))
        XCTAssertTrue(configuration.trusts(url: URL(string: "capacitor://localhost")))
        XCTAssertFalse(configuration.trusts(url: URL(string: "https://localhost:444")))
    }

    func testHostedModeRequiresHttpsAndExactHost() {
        let configuration = AppConfiguration(mode: .hosted, hostedHost: "nexquoteapp.com")
        XCTAssertEqual(configuration.startURL?.absoluteString, "https://nexquoteapp.com/app/dashboard")
        XCTAssertTrue(configuration.trusts(protocol: "https", host: "nexquoteapp.com"))
        XCTAssertTrue(configuration.trusts(protocol: "https", host: "nexquoteapp.com", port: 443))
        XCTAssertFalse(configuration.trusts(protocol: "https", host: "nexquoteapp.com", port: 444))
        XCTAssertFalse(configuration.trusts(protocol: "http", host: "nexquoteapp.com"))
        XCTAssertFalse(configuration.trusts(protocol: "https", host: "sub.nexquoteapp.com"))

        let insecure = AppConfiguration(mode: .hosted, hostedScheme: "http", hostedHost: "nexquoteapp.com")
        XCTAssertNil(insecure.startURL)
        XCTAssertFalse(insecure.trusts(protocol: "http", host: "nexquoteapp.com"))

        let malformed = AppConfiguration(mode: .hosted, hostedHost: "nexquoteapp.com/path")
        XCTAssertNil(malformed.startURL)
        XCTAssertTrue(configuration.trusts(url: URL(string: "https://nexquoteapp.com/app/dashboard")))
        XCTAssertFalse(configuration.trusts(url: URL(string: "https://nexquoteapp.com:444/app/dashboard")))
    }
}
