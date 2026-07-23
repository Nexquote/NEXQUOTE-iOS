import Capacitor
import UIKit

final class BridgeViewController: CAPBridgeViewController {
    override func capacitorDidLoad() {
        super.capacitorDidLoad()
        guard let webView else { return }
        (UIApplication.shared.delegate as? AppDelegate)?.connectBridge(to: webView)
    }
}
