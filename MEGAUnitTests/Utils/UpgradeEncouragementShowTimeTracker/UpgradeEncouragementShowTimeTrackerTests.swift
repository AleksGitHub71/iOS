@testable import MEGA
import XCTest
final class UpgradeEncouragementShowTimeTrackerTests: XCTestCase {
    func testAlreadyPresented() {
        let sut = UpgradeEncouragementShowTimeTracker()
        XCTAssertFalse(sut.alreadyPresented)
        
        sut.alreadyPresented = true
        XCTAssertTrue(sut.alreadyPresented)
    }
}
