import XCTest
@testable import BmNumberScannerPlugin

final class BmNumberScannerPluginTests: XCTestCase {
    func testPluginIdentifier() {
        XCTAssertEqual(BmNumberScannerPlugin().jsName, "BmNumberScanner")
    }
}
