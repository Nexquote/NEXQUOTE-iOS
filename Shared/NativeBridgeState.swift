import Foundation

struct NativeRouteDelivery: Equatable {
    let id: String
    let path: String
    let share: PendingSharePayload?
}

struct NativeBridgeState {
    private(set) var isFrontendReady = false
    private(set) var inFlightID: String?
    private(set) var deliveries: [NativeRouteDelivery] = []
    let capacity: Int

    init(capacity: Int = 8) {
        self.capacity = max(1, capacity)
    }

    @discardableResult
    mutating func enqueue(path: String, share: PendingSharePayload? = nil) -> Bool {
        guard
            let normalized = NativeRouteParser.normalize(path: path),
            deliveries.count < capacity,
            !deliveries.contains(where: { $0.path == normalized && $0.share == share })
        else { return false }

        deliveries.append(NativeRouteDelivery(id: UUID().uuidString, path: normalized, share: share))
        return true
    }

    mutating func markFrontendReady() {
        isFrontendReady = true
    }

    mutating func markFrontendUnavailable() {
        isFrontendReady = false
        inFlightID = nil
    }

    mutating func nextForDelivery() -> NativeRouteDelivery? {
        guard isFrontendReady, inFlightID == nil, let delivery = deliveries.first else { return nil }
        inFlightID = delivery.id
        return delivery
    }

    @discardableResult
    mutating func acknowledge(id: String) -> Bool {
        guard inFlightID == id, deliveries.first?.id == id else { return false }
        deliveries.removeFirst()
        inFlightID = nil
        return true
    }
}
