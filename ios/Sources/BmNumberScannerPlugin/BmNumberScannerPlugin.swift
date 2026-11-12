import Capacitor
import UIKit

@objc(BmNumberScannerPlugin)
public class BmNumberScannerPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "BmNumberScannerPlugin"
    public let jsName = "BmNumberScanner"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "scan", returnType: CAPPluginReturnPromise)
    ]

    @objc func scan(_ call: CAPPluginCall) {
        let vc = ScannerViewController(
            pattern: call.getString("pattern") ?? "\\d{6,}",
            hint: call.getString("hint") ?? "Наведите камеру на номер",
            galleryTitle: call.getString("galleryTitle") ?? "Загрузить из галереи"
        )
        vc.modalPresentationStyle = .fullScreen
        vc.onResult = { value in call.resolve(["value": value]) }
        vc.onCancel = { call.reject("cancelled") }
        DispatchQueue.main.async {
            self.bridge?.viewController?.present(vc, animated: true)
        }
    }
}
