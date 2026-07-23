import Social
import UniformTypeIdentifiers

final class ShareViewController: SLComposeServiceViewController {
    private let appGroupIdentifier = "group.com.nexquote.app"
    private var postStarted = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationItem.title = "NexQuote"
        navigationController?.navigationBar.topItem?.rightBarButtonItem?.title = AppStrings.text(
            "share.save",
            fallback: "Save"
        )
    }

    override func isContentValid() -> Bool {
        if PendingShareSanitizer.cleanText(contentText, maximumLength: 16_384) != nil { return true }
        return inputItems.contains { item in
            PendingShareSanitizer.cleanText(item.attributedTitle?.string, maximumLength: 512) != nil
                || PendingShareSanitizer.cleanText(item.attributedContentText?.string, maximumLength: 16_384) != nil
                || (item.attachments ?? []).contains(where: supports)
        }
    }

    override func didSelectPost() {
        guard !postStarted else { return }
        postStarted = true
        collectSharedContent { [weak self] payload in
            guard let self else { return }
            do {
                guard let payload else { throw PendingShareStoreError.invalidPayload }
                let store = try PendingShareStore(appGroupIdentifier: self.appGroupIdentifier)
                try store.save(payload)
                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            } catch {
                let failure = NSError(
                    domain: "com.nexquote.app.share",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: AppStrings.text(
                        "share.save_failed",
                        fallback: "NexQuote could not save the shared content."
                    )]
                )
                self.extensionContext?.cancelRequest(withError: failure)
            }
        }
    }

    override func configurationItems() -> [Any]! {
        let item = SLComposeSheetConfigurationItem()
        item?.title = AppStrings.text("share.after_saving", fallback: "After saving")
        item?.value = AppStrings.text("share.open_to_continue", fallback: "Open NexQuote to continue")
        return item.map { [$0] } ?? []
    }

    private var inputItems: [NSExtensionItem] {
        (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
    }

    private func supports(_ provider: NSItemProvider) -> Bool {
        provider.hasItemConformingToTypeIdentifier(UTType.url.identifier)
            || provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
    }

    private func collectSharedContent(completion: @escaping (PendingSharePayload?) -> Void) {
        let accumulator = SharedContentAccumulator()
        inputItems.forEach { item in
            accumulator.appendTitle(item.attributedTitle?.string)
            accumulator.appendText(item.attributedContentText?.string)
        }
        accumulator.appendText(contentText)

        let group = DispatchGroup()
        for provider in inputItems.flatMap({ $0.attachments ?? [] }) {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    let value = (item as? URL)?.absoluteString
                        ?? (item as? NSURL)?.absoluteString
                        ?? (item as? String)
                    accumulator.appendURL(value)
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    accumulator.appendText((item as? String) ?? (item as? NSAttributedString)?.string)
                }
            }
        }

        group.notify(queue: .main) {
            completion(accumulator.payload())
        }
    }
}

private final class SharedContentAccumulator {
    private let lock = NSLock()
    private var titles: [String] = []
    private var texts: [String] = []
    private var url: String?

    func appendTitle(_ value: String?) {
        guard let value = PendingShareSanitizer.cleanText(value, maximumLength: 512) else { return }
        lock.withLock { if !titles.contains(value) { titles.append(value) } }
    }

    func appendText(_ value: String?) {
        guard let value = PendingShareSanitizer.cleanText(value, maximumLength: 16_384) else { return }
        lock.withLock { if !texts.contains(value) { texts.append(value) } }
    }

    func appendURL(_ value: String?) {
        guard let value = PendingShareSanitizer.cleanURL(value) else { return }
        lock.withLock { if url == nil { url = value } }
    }

    func payload() -> PendingSharePayload? {
        lock.withLock {
            PendingShareSanitizer.payload(
                title: titles.first,
                text: texts.joined(separator: "\n\n"),
                url: url
            )
        }
    }
}

private extension NSLock {
    func withLock<T>(_ operation: () -> T) -> T {
        lock()
        defer { unlock() }
        return operation()
    }
}
