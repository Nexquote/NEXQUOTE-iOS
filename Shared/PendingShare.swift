import Foundation

struct PendingSharePayload: Codable, Equatable {
    let createdAt: Date
    let title: String?
    let text: String?
    let url: String?
}

enum PendingShareSanitizer {
    static let maximumEncodedBytes = 65_536
    static let maximumAge: TimeInterval = 10 * 60
    private static let sensitiveQueryNames = [
        "access_token", "api_key", "authorization", "code", "credential", "jwt",
        "password", "refresh_token", "secret", "session", "token",
    ]

    static func payload(
        createdAt: Date = Date(),
        title: String?,
        text: String?,
        url: String?
    ) -> PendingSharePayload? {
        let cleaned = PendingSharePayload(
            createdAt: createdAt,
            title: cleanText(title, maximumLength: 512),
            text: cleanText(text, maximumLength: 16_384),
            url: cleanURL(url)
        )
        guard cleaned.title != nil || cleaned.text != nil || cleaned.url != nil else { return nil }
        return cleaned
    }

    static func validated(_ payload: PendingSharePayload, now: Date = Date()) -> PendingSharePayload? {
        let age = now.timeIntervalSince(payload.createdAt)
        guard age >= -60, age <= maximumAge else { return nil }
        return self.payload(
            createdAt: payload.createdAt,
            title: payload.title,
            text: payload.text,
            url: payload.url
        )
    }

    static func cleanText(_ value: String?, maximumLength: Int) -> String? {
        guard let value else { return nil }
        let forbiddenScalars: Set<UInt32> = [0x202A, 0x202B, 0x202D, 0x202E, 0x2066, 0x2067, 0x2068, 0x2069]
        let cleaned = value.unicodeScalars
            .filter { scalar in
                let code = scalar.value
                if forbiddenScalars.contains(code) { return false }
                return code == 9 || code == 10 || code == 13 || (code >= 32 && code != 127)
            }
            .map(String.init)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        return String(cleaned.prefix(maximumLength))
    }

    static func cleanURL(_ value: String?) -> String? {
        guard
            let cleaned = cleanText(value, maximumLength: 2_048),
            let components = URLComponents(string: cleaned),
            let scheme = components.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            components.host?.isEmpty == false,
            components.user == nil,
            components.password == nil,
            components.fragment == nil,
            !(components.queryItems ?? []).contains(where: { item in
                let name = item.name.lowercased()
                return sensitiveQueryNames.contains(where: { name.contains($0) })
            })
        else { return nil }
        return components.string
    }
}

enum PendingShareStoreError: Error {
    case unavailableContainer
    case invalidPayload
    case oversizedPayload
}

struct PendingShareStore {
    static let fileName = "pending-share.json"
    let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    init(appGroupIdentifier: String) throws {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else { throw PendingShareStoreError.unavailableContainer }
        fileURL = container.appendingPathComponent(Self.fileName, isDirectory: false)
    }

    func save(_ payload: PendingSharePayload) throws {
        guard let validated = PendingShareSanitizer.validated(payload) else {
            throw PendingShareStoreError.invalidPayload
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(validated)
        guard data.count <= PendingShareSanitizer.maximumEncodedBytes else {
            throw PendingShareStoreError.oversizedPayload
        }
        // ponytail: one pending share stays intentional; add a bounded queue only after real multi-share demand.
        try data.write(
            to: fileURL,
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
    }

    func consume(now: Date = Date()) -> PendingSharePayload? {
        guard let data = try? Data(contentsOf: fileURL, options: .mappedIfSafe) else {
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }
        defer { try? FileManager.default.removeItem(at: fileURL) }
        guard data.count <= PendingShareSanitizer.maximumEncodedBytes else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let payload = try? decoder.decode(PendingSharePayload.self, from: data) else { return nil }
        return PendingShareSanitizer.validated(payload, now: now)
    }
}
