import XCTest

final class NativeRouteTests: XCTestCase {
    func testAllowsDocumentedRoutesAndQueries() {
        XCTAssertEqual(
            NativeRouteParser.normalize(path: "/app/quotes/new?intent=quick-create&focus=intake&source=shortcut"),
            "/app/quotes/new?intent=quick-create&focus=intake&source=shortcut"
        )
        XCTAssertEqual(
            NativeRouteParser.normalize(path: "/app/dashboard?focus=decisions&source=universal-link"),
            "/app/dashboard?focus=decisions&source=universal-link"
        )
        XCTAssertEqual(
            NativeRouteParser.normalize(path: "/app/rates/import?source=deep-link"),
            "/app/rates/import?source=deep-link"
        )
    }

    func testRejectsUnknownRouteUnknownQueryAndSecretQuery() {
        XCTAssertNil(NativeRouteParser.normalize(path: "/app/settings"))
        XCTAssertNil(NativeRouteParser.normalize(path: "/app/quotes/new?customer=acme"))
        XCTAssertNil(NativeRouteParser.normalize(path: "/app/quotes/new?token=secret"))
        XCTAssertNil(NativeRouteParser.normalize(path: "/app/quotes/new?source=shortcut&source=deep-link"))
        XCTAssertNil(NativeRouteParser.normalize(path: "/app/quotes/new#private"))
    }

    func testParsesCustomAndUniversalLinks() {
        XCTAssertEqual(
            NativeRouteParser.path(
                for: URL(string: "nexquote://app/quotes/new?source=deep-link")!,
                hostedHost: "nexquoteapp.com"
            ),
            "/app/quotes/new?source=deep-link"
        )
        XCTAssertEqual(
            NativeRouteParser.path(
                for: URL(string: "https://nexquoteapp.com/app/dashboard?focus=decisions&source=universal-link")!,
                hostedHost: "nexquoteapp.com"
            ),
            "/app/dashboard?focus=decisions&source=universal-link"
        )
    }

    func testRejectsMalformedOrUntrustedLinks() {
        XCTAssertNil(NativeRouteParser.path(
            for: URL(string: "nexquote://evil/quotes/new?source=deep-link")!,
            hostedHost: "nexquoteapp.com"
        ))
        XCTAssertNil(NativeRouteParser.path(
            for: URL(string: "https://evil.example/app/dashboard?source=universal-link")!,
            hostedHost: "nexquoteapp.com"
        ))
        XCTAssertNil(NativeRouteParser.path(
            for: URL(string: "nexquote://app/quotes/new?access_token=secret")!,
            hostedHost: "nexquoteapp.com"
        ))
        XCTAssertNil(NativeRouteParser.path(
            for: URL(string: "https://nexquoteapp.com:444/app/dashboard?source=universal-link")!,
            hostedHost: "nexquoteapp.com"
        ))
    }

    func testCanonicalizesAllowedQueryNames() {
        XCTAssertEqual(
            NativeRouteParser.normalize(path: "/app/dashboard?SOURCE=deep-link"),
            "/app/dashboard?source=deep-link"
        )
    }

    func testQuickActionMappingsStayAllowlisted() {
        for shortcut in [
            "com.nexquote.app.create-quote",
            "com.nexquote.app.import-rates",
            "com.nexquote.app.decision-inbox",
        ] {
            let path = NativeRouteParser.path(for: shortcut)
            XCTAssertNotNil(path)
            XCTAssertEqual(path, path.flatMap { NativeRouteParser.normalize(path: $0) })
        }
        XCTAssertNil(NativeRouteParser.path(for: "com.nexquote.app.unknown"))
    }
}
