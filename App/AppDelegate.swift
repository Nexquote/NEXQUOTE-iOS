import Capacitor
import UIKit
import WebKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate, WKScriptMessageHandler {
    var window: UIWindow?

    private let configuration = AppConfiguration()
    private let appGroupIdentifier = "group.com.nexquote.app"
    private let bridgeMessageName = "nqBridge"
    private let routeEventName = "nq:native-route"
    private let shareEventName = "nq:native-share"
    private var bridgeState = NativeBridgeState()
    private var bridgeHandlerInstalled = false

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        configureQuickActions(application)

        if let shortcut = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem,
           let path = NativeRouteParser.path(for: shortcut.type) {
            bridgeState.enqueue(path: path)
        }
        if let url = launchOptions?[.url] as? URL,
           let path = NativeRouteParser.path(for: url, hostedHost: configuration.hostedHost) {
            bridgeState.enqueue(path: path)
        }

        enqueueHarnessLaunchArgumentsIfNeeded()
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        guard let webView = bridgeWebView else { return }
        installBridgeHandler(on: webView)
        loadHostedApplicationIfNeeded(in: webView)
        consumePendingShare()
        deliverNextIfPossible(in: webView)
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        let handled = NativeRouteParser.path(for: url, hostedHost: configuration.hostedHost)
            .map { enqueueAndDeliver(path: $0) } ?? false
        let proxied = ApplicationDelegateProxy.shared.application(app, open: url, options: options)
        return handled || proxied
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        guard let path = NativeRouteParser.path(for: shortcutItem.type) else {
            completionHandler(false)
            return
        }
        completionHandler(enqueueAndDeliver(path: path))
    }

    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        let handled = userActivity.webpageURL
            .flatMap { NativeRouteParser.path(for: $0, hostedHost: configuration.hostedHost) }
            .map { enqueueAndDeliver(path: $0) } ?? false
        let proxied = ApplicationDelegateProxy.shared.application(
            application,
            continue: userActivity,
            restorationHandler: restorationHandler
        )
        return handled || proxied
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard
            message.name == bridgeMessageName,
            configuration.trusts(protocol: message.frameInfo.securityOrigin.protocol, host: message.frameInfo.securityOrigin.host),
            let body = message.body as? [String: Any],
            let type = body["type"] as? String
        else { return }

        switch type {
        case "ready":
            bridgeState.markFrontendReady()
            if let webView = message.webView { deliverNextIfPossible(in: webView) }
        case "ack":
            guard let id = body["id"] as? String, bridgeState.acknowledge(id: id) else { return }
            if let webView = message.webView { deliverNextIfPossible(in: webView) }
        case "harness-route":
            guard
                configuration.mode == .harness,
                let path = body["path"] as? String
            else { return }
            _ = enqueueAndDeliver(path: path)
        default:
            return
        }
    }

    private var bridgeWebView: WKWebView? {
        (window?.rootViewController as? CAPBridgeViewController)?.webView
    }

    private func installBridgeHandler(on webView: WKWebView) {
        guard !bridgeHandlerInstalled else { return }
        webView.configuration.userContentController.add(self, name: bridgeMessageName)
        bridgeHandlerInstalled = true
    }

    private func loadHostedApplicationIfNeeded(in webView: WKWebView) {
        guard let startURL = configuration.startURL else { return }
        if webView.url?.scheme == startURL.scheme, webView.url?.host == startURL.host { return }
        bridgeState.markFrontendUnavailable()
        webView.load(URLRequest(url: startURL, cachePolicy: .reloadIgnoringLocalCacheData))
    }

    @discardableResult
    private func enqueueAndDeliver(path: String, share: PendingSharePayload? = nil) -> Bool {
        guard bridgeState.enqueue(path: path, share: share) else { return false }
        if let webView = bridgeWebView { deliverNextIfPossible(in: webView) }
        return true
    }

    private func deliverNextIfPossible(in webView: WKWebView) {
        guard let delivery = bridgeState.nextForDelivery() else { return }

        var scripts: [String] = []
        if let share = delivery.share {
            var sharePayload: [String: String] = [:]
            if let title = share.title { sharePayload["title"] = title }
            if let text = share.text { sharePayload["text"] = text }
            if let url = share.url { sharePayload["url"] = url }
            guard let shareJSON = jsonObject(sharePayload) else {
                bridgeState.markFrontendUnavailable()
                return
            }
            scripts.append("window.dispatchEvent(new CustomEvent(\(jsonString(shareEventName)), { detail: { routeId: \(jsonString(delivery.id)), payload: \(shareJSON) } }));")
        }
        scripts.append("window.dispatchEvent(new CustomEvent(\(jsonString(routeEventName)), { detail: { id: \(jsonString(delivery.id)), path: \(jsonString(delivery.path)) } }));")

        webView.evaluateJavaScript(scripts.joined(separator: "\n")) { [weak self] _, error in
            guard let self, error != nil else { return }
            self.bridgeState.markFrontendUnavailable()
        }
    }

    private func consumePendingShare() {
        guard let store = try? PendingShareStore(appGroupIdentifier: appGroupIdentifier),
              let payload = store.consume()
        else { return }
        _ = enqueueAndDeliver(path: "/app/quotes/new?source=share-target", share: payload)
    }

    private func configureQuickActions(_ application: UIApplication) {
        application.shortcutItems = [
            quickAction(
                type: "com.nexquote.app.create-quote",
                title: AppStrings.text("quick.create_quote", fallback: "Create quote"),
                icon: .compose
            ),
            quickAction(
                type: "com.nexquote.app.import-rates",
                title: AppStrings.text("quick.import_rates", fallback: "Import rates"),
                icon: .add
            ),
            quickAction(
                type: "com.nexquote.app.decision-inbox",
                title: AppStrings.text("quick.decision_inbox", fallback: "Decision inbox"),
                icon: .task
            ),
        ]
    }

    private func quickAction(
        type: String,
        title: String,
        icon: UIApplicationShortcutIcon.IconType
    ) -> UIApplicationShortcutItem {
        UIApplicationShortcutItem(
            type: type,
            localizedTitle: title,
            localizedSubtitle: nil,
            icon: UIApplicationShortcutIcon(type: icon),
            userInfo: nil
        )
    }

    private func enqueueHarnessLaunchArgumentsIfNeeded() {
        #if DEBUG
        guard configuration.mode == .harness else { return }
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-NQHarnessRoute"), arguments.indices.contains(index + 1) {
            bridgeState.enqueue(path: arguments[index + 1])
        }
        if let text = ProcessInfo.processInfo.environment["NQ_HARNESS_SHARE_TEXT"],
           let payload = PendingShareSanitizer.payload(title: "Simulator handoff", text: text, url: nil) {
            bridgeState.enqueue(path: "/app/quotes/new?source=share-target", share: payload)
        }
        #endif
    }

    private func jsonString(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed),
              let encoded = String(data: data, encoding: .utf8)
        else { return "\"\"" }
        return encoded
    }

    private func jsonObject(_ value: [String: String]) -> String? {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value),
              let encoded = String(data: data, encoding: .utf8)
        else { return nil }
        return encoded
    }
}
