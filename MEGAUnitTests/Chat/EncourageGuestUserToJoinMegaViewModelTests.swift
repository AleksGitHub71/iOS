@testable import MEGA
import MEGATest
import XCTest

final class EncourageGuestUserToJoinMegaViewModelTests: XCTestCase {
    
    func testDispatchCreateAccount_shouldCallCreateAccount() {
        let mockRouter = MockEncourageGuestUserToJoinMegaRouter()
        let sut = EncourageGuestUserToJoinMegaViewModel(router: mockRouter)
        
        test(viewModel: sut, action: .didCreateAccountButton, expectedCommands: [])
        
        XCTAssertEqual(mockRouter.createAccountCallCount, 1)
    }
    
    func testDispatchDismiss_shouldCallDismissView() {
        let mockRouter = MockEncourageGuestUserToJoinMegaRouter()
        let sut = EncourageGuestUserToJoinMegaViewModel(router: mockRouter)
        
        test(viewModel: sut, action: .didTapCloseButton, expectedCommands: [])
        
        XCTAssertEqual(mockRouter.dismissCallCount, 1)
    }
}
