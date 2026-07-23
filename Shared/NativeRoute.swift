import Foundation

enum NativeRouteParser {
    private static let virtualOrigin = URL(string: "https://localhost")!
    private static let sensitiveQueryNames = [
        "access_token", "api_key", "authorization", "code", "credential", "jwt",
        "password", "refresh_token", "secret", "session", "token",
    ]

    private static let allowedQueries: [String: [String: Set<String>]] = [
        "/app/dashboard": [
            "focus": ["decisions"],
            "source": ["shortcut", "deep-link", "universal-link"],
        ],
        "/app/quotes/new": [
            "intent": ["quick-create"],
            "focus": ["intake"],
            "source": ["shortcut", "deep-link", "universal-link", "share-target"],
        ],
        "/app/rates/import": [
            "source": ["shortcut", "deep-link", "universal-link"],
        ],
    ]

    static func normalize(path value: String) -> String? {
        guard
            !value.isEmpty,
            value.count <= 1_024,
            !value.contains("#"),
            let url = URL(string: value, relativeTo: virtualOrigin)?.absoluteURL,
            url.scheme == virtualOrigin.scheme,
            url.host == virtualOrigin.host,
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let queryRules = allowedQueries[components.path]
        else { return nil }

        let items = components.queryItems ?? []
        guard items.count <= queryRules.count else { return nil }

        var seen = Set<String>()
        var normalizedItems: [URLQueryItem] = []
        for item in items {
            let name = item.name.lowercased()
            guard
                !sensitiveQueryNames.contains(where: { name.contains($0) }),
                seen.insert(name).inserted,
                let value = item.value,
                queryRules[name]?.contains(value) == true
            else { return nil }
            normalizedItems.append(URLQueryItem(name: name, value: value))
        }

        var output = URLComponents()
        output.path = components.path
        output.queryItems = normalizedItems.isEmpty ? nil : normalizedItems
        var normalized = output.percentEncodedPath
        if let query = output.percentEncodedQuery, !query.isEmpty {
            normalized += "?\(query)"
        }
        return normalized
    }

    static func path(for shortcutType: String) -> String? {
        switch shortcutType {
        case "com.nexquote.app.create-quote":
            return "/app/quotes/new?intent=quick-create&focus=intake&source=shortcut"
        case "com.nexquote.app.import-rates":
            return "/app/rates/import?source=shortcut"
        case "com.nexquote.app.decision-inbox":
            return "/app/dashboard?focus=decisions&source=shortcut"
        default:
            return nil
        }
    }

    static func path(for url: URL, hostedHost: String) -> String? {
        guard url.user == nil, url.password == nil else { return nil }

        if url.scheme?.lowercased() == "nexquote", url.host?.lowercased() == "app" {
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedQuery
            return normalize(path: "/app\(url.path)\(query.map { "?\($0)" } ?? "")")
        }

        guard
            url.scheme?.lowercased() == "https",
            !hostedHost.isEmpty,
            url.host?.lowercased() == hostedHost.lowercased(),
            url.port == nil || url.port == 443
        else { return nil }

        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedQuery
        return normalize(path: "\(url.path)\(query.map { "?\($0)" } ?? "")")
    }
}
