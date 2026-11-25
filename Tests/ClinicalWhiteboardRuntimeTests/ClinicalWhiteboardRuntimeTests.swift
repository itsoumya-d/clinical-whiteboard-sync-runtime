import XCTest
@testable import ClinicalWhiteboardRuntime

final class ClinicalWhiteboardRuntimeTests: XCTestCase {
    func testVersion() {
        XCTAssertEqual(ClinicalWhiteboardRuntime.version, "1.0.0")
    }
}
