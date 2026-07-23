import XCTest

final class NativeBridgeStateTests: XCTestCase {
    func testColdStartRouteWaitsForFrontendReadiness() {
        var state = NativeBridgeState()
        XCTAssertTrue(state.enqueue(path: "/app/dashboard?focus=decisions&source=shortcut"))
        XCTAssertNil(state.nextForDelivery())

        state.markFrontendReady()
        XCTAssertEqual(state.nextForDelivery()?.path, "/app/dashboard?focus=decisions&source=shortcut")
    }

    func testMissingReadinessDoesNotDiscardRoute() {
        var state = NativeBridgeState()
        state.enqueue(path: "/app/rates/import?source=shortcut")
        state.markFrontendUnavailable()
        XCTAssertEqual(state.deliveries.count, 1)
        XCTAssertNil(state.nextForDelivery())

        state.markFrontendReady()
        XCTAssertEqual(state.nextForDelivery()?.path, "/app/rates/import?source=shortcut")
    }

    func testDuplicateDeliveryWaitsForAcknowledgement() {
        var state = NativeBridgeState()
        state.enqueue(path: "/app/quotes/new?source=deep-link")
        state.markFrontendReady()
        let delivery = state.nextForDelivery()
        XCTAssertNotNil(delivery)
        XCTAssertNil(state.nextForDelivery())
        XCTAssertFalse(state.acknowledge(id: "wrong-id"))
        XCTAssertEqual(state.deliveries.count, 1)
        XCTAssertTrue(state.acknowledge(id: delivery!.id))
        XCTAssertTrue(state.deliveries.isEmpty)
    }

    func testWarmRouteDeliversAfterPreviousAck() {
        var state = NativeBridgeState()
        state.markFrontendReady()
        state.enqueue(path: "/app/dashboard?source=deep-link")
        state.enqueue(path: "/app/rates/import?source=deep-link")
        let first = state.nextForDelivery()!
        XCTAssertTrue(state.acknowledge(id: first.id))
        XCTAssertEqual(state.nextForDelivery()?.path, "/app/rates/import?source=deep-link")
    }

    func testQueueIsBoundedAndDeduplicated() {
        var state = NativeBridgeState(capacity: 1)
        XCTAssertTrue(state.enqueue(path: "/app/dashboard?source=deep-link"))
        XCTAssertFalse(state.enqueue(path: "/app/dashboard?source=deep-link"))
        XCTAssertFalse(state.enqueue(path: "/app/rates/import?source=deep-link"))
    }
}
