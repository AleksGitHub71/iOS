import XCTest
@testable import MEGA

final class TurnOnNotificationsViewModelTests: XCTestCase {
    
    let mockRouter = MockTurnOnNotificationsViewRouter()
    let mockPreference = MockPreferenceUseCase()
    
    func testAction_onViewLoaded_configView() {
        let sut = TurnOnNotificationsViewModel(router: mockRouter,
                                               authUseCase: MockAuthUseCase(isUserLoggedIn: true))
        sut.dispatch(.onViewLoaded)
        
        let title = NSLocalizedString("dialog.turnOnNotifications.label.title", comment: "The title of Turn on Notifications view")
        let description = NSLocalizedString("dialog.turnOnNotifications.label.description", comment: "The description of Turn on Notifications view")
        let stepOne = NSLocalizedString("dialog.turnOnNotifications.label.stepOne", comment: "First step to turn on notifications")
        let stepTwo = NSLocalizedString("dialog.turnOnNotifications.label.stepTwo", comment: "Second step to turn on notifications")
        let stepThree = NSLocalizedString("dialog.turnOnNotifications.label.stepThree", comment: "Third step to turn on notifications")
        
        
        let expectedNotificationsModel = TurnOnNotificationsModel(headerImageName: "groupChat",
                                                          title: title,
                                                          description: description,
                                                          stepOneImageName: "openSettings",
                                                          stepOne: stepOne,
                                                          stepTwoImageName: "tapNotifications",
                                                          stepTwo: stepTwo,
                                                          stepThreeImageName: "allowNotifications",
                                                          stepThree: stepThree,
                                                          openSettingsTitle: NSLocalizedString("dialog.turnOnNotifications.button.primary", comment: "Title of the button to open Settings"),
                                                          dismissTitle: NSLocalizedString("Dismiss", comment: ""))
        test(viewModel: sut, action: .onViewLoaded, expectedCommands: [.configView(expectedNotificationsModel)])
    }
    
    func testAction_openSettings() {
        let sut = TurnOnNotificationsViewModel(router: mockRouter,
                                               authUseCase: MockAuthUseCase(isUserLoggedIn: true))
        test(viewModel: sut, action: .openSettings, expectedCommands: [])
        XCTAssertEqual(mockRouter.openSettings_calledTimes, 1)
    }
    
    func testAction_dismiss() {
        let sut = TurnOnNotificationsViewModel(router: mockRouter,
                                               authUseCase: MockAuthUseCase(isUserLoggedIn: true))
        test(viewModel: sut, action: .dismiss, expectedCommands: [])
        XCTAssertEqual(mockRouter.dismiss_calledTimes, 1)
    }
    
    func testShoudlShowTurnOnNotifications_moreThanSevenDaysHasPassed() {
        mockPreference.dict[.lastDateTurnOnNotificationsShowed] = Date.init(timeIntervalSince1970: 0)
        let sut = TurnOnNotificationsViewModel(router: mockRouter, preferenceUseCase: mockPreference,
                                               authUseCase: MockAuthUseCase(isUserLoggedIn: false))
        XCTAssertFalse(sut.shouldShowTurnOnNotifications())
    }
    
    func testShoudlShowTurnOnNotifications_moreThanSevenDaysHasPassed_userLoggedIn() {
        mockPreference.dict[.lastDateTurnOnNotificationsShowed] = Date.init(timeIntervalSince1970: 0)
        let sut = TurnOnNotificationsViewModel(router: mockRouter, preferenceUseCase: mockPreference,
                                               authUseCase: MockAuthUseCase(isUserLoggedIn: true))
        XCTAssertTrue(sut.shouldShowTurnOnNotifications())
    }
    
    func testShoudlShowTurnOnNotifications_lessThanSevenDaysHasPassed() {
        mockPreference.dict[.lastDateTurnOnNotificationsShowed] = Date()
        let sut = TurnOnNotificationsViewModel(router: mockRouter, preferenceUseCase: mockPreference,
                                               authUseCase: MockAuthUseCase(isUserLoggedIn: true))
        XCTAssertFalse(sut.shouldShowTurnOnNotifications())
    }
    
    func testShoudlShowTurnOnNotifications_equalOrMoreThanThreeTimesShown() {
        mockPreference.dict[.timesTurnOnNotificationsShowed] = 3
        let sut = TurnOnNotificationsViewModel(router: mockRouter, preferenceUseCase: mockPreference,
                                               authUseCase: MockAuthUseCase(isUserLoggedIn: true))
        XCTAssertFalse(sut.shouldShowTurnOnNotifications())
    }
    
    func testShoudlShowTurnOnNotifications_lessThanThreeTimesShown() {
        mockPreference.dict[.timesTurnOnNotificationsShowed] = 2
        let sut = TurnOnNotificationsViewModel(router: mockRouter, preferenceUseCase: mockPreference,
                                               authUseCase: MockAuthUseCase(isUserLoggedIn: false))
        XCTAssertFalse(sut.shouldShowTurnOnNotifications())
    }
    
    func testShoudlShowTurnOnNotifications_lessThanThreeTimesShown_userLoggedI() {
        mockPreference.dict[.timesTurnOnNotificationsShowed] = 2
        let sut = TurnOnNotificationsViewModel(router: mockRouter, preferenceUseCase: mockPreference,
                                               authUseCase: MockAuthUseCase(isUserLoggedIn: true))
        XCTAssertTrue(sut.shouldShowTurnOnNotifications())
    }
}

final class MockTurnOnNotificationsViewRouter: TurnOnNotificationsViewRouting {
    var openSettings_calledTimes = 0
    var dismiss_calledTimes = 0
    
    func dismiss() {
        dismiss_calledTimes += 1
    }
    
    func openSettings() {
        openSettings_calledTimes += 1
    }
}
