import Foundation

struct AppConfiguration: Equatable {
    enum Mode: String {
        case harness
        case hosted
    }

    let mode: Mode
    let hostedScheme: String
    let hostedHost: String

    init(bundle: Bundle = .main) {
        let configuredMode = bundle.object(forInfoDictionaryKey: "NQAppMode") as? String
        mode = Mode(rawValue: configuredMode?.lowercased() ?? "") ?? .harness
        hostedScheme = (bundle.object(forInfoDictionaryKey: "NQHostedScheme") as? String) ?? "https"
        hostedHost = (bundle.object(forInfoDictionaryKey: "NQHostedHost") as? String) ?? ""
    }

    init(mode: Mode, hostedScheme: String = "https", hostedHost: String = "") {
        self.mode = mode
        self.hostedScheme = hostedScheme
        self.hostedHost = hostedHost
    }

    var hostedOrigin: URL? {
        guard
            mode == .hosted,
            hostedScheme.lowercased() == "https",
            !hostedHost.isEmpty,
            let url = URL(string: "https://\(hostedHost)"),
            url.scheme == "https",
            url.host?.caseInsensitiveCompare(hostedHost) == .orderedSame,
            url.port == nil,
            url.user == nil,
            url.password == nil,
            url.path.isEmpty,
            url.query == nil,
            url.fragment == nil
        else { return nil }
        return url
    }

    var startURL: URL? {
        hostedOrigin?.appendingPathComponent("app/dashboard")
    }

    func trusts(protocol webProtocol: String, host: String) -> Bool {
        switch mode {
        case .harness:
            return host.lowercased() == "localhost" && ["capacitor", "https"].contains(webProtocol.lowercased())
        case .hosted:
            return hostedOrigin != nil
                && webProtocol.lowercased() == "https"
                && host.lowercased() == hostedHost.lowercased()
        }
    }
}
