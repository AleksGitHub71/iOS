import XCTest
@testable import MEGA

final class MockFavouritesRouter: FavouritesRouting {
    var openNode_calledTimes = 0
    var openNodeActions_calledTimes = 0
    
    func openNode(_ nodeHandle: MEGAHandle) {
        openNode_calledTimes += 1
    }
    
    func openNodeActions(nodeHandle: MEGAHandle, sender: Any) {
        openNodeActions_calledTimes += 1
    }
}
