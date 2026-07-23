import Foundation

enum AppStrings {
    static func text(_ key: String, fallback: String) -> String {
        NSLocalizedString(key, bundle: .main, value: fallback, comment: "")
    }
}
