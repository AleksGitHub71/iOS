import Combine
@testable import MEGA
import MEGAAnalyticsiOS
import MEGADomain
import MEGADomainMock
import MEGAPresentation
import MEGAPresentationMock
import MEGASDKRepoMock
import XCTest

final class ProfileViewModelTests: XCTestCase {
    var subscriptions = Set<AnyCancellable>()
    
    override func tearDown() {
        subscriptions.removeAll()
        super.tearDown()
    }
    
    func testAction_onViewDidLoad_defaultValue() {
        let (sut, _) = makeSUT()
        let result = receivedSectionDataSource(from: sut, after: .onViewDidLoad)
        let expectedSections = ProfileViewModel.SectionCellDataSource(
            sectionOrder: sectionsOrder(),
            sectionRows: sectionRows())
        
        XCTAssertEqual(result, expectedSections)
    }
    
    func testSectionsVisibility_withoutValidProAccount_shouldNotShowSubscriptionSection() {
        let (sut, _) = makeSUT(hasValidProAccount: false)
        sut.dispatch(.onViewDidLoad)
        
        let result = receivedSectionDataSource(from: sut, after: .onViewDidLoad)
        XCTAssertFalse(result?.sectionOrder.contains(.subscription) ?? true, "Subscription section should not appear for non-valid Pro accounts")
    }
    
    func testAction_onViewDidLoadWithoutValidProAccount_shouldShowCorrectSectionsAndRows() {
        let (sut, _) = makeSUT(hasValidProAccount: false)
        let result = receivedSectionDataSource(from: sut, after: .onViewDidLoad)
        let expectedSections = ProfileViewModel.SectionCellDataSource(
            sectionOrder: sectionsOrder(hasValidProAccount: false),
            sectionRows: sectionRows(hasValidProAccount: false))
        
        XCTAssertEqual(result, expectedSections)
    }
    
    func testAction_onViewDidLoad_whenSmsIsAllowed() {
        let (sut, _) = makeSUT(smsState: .optInAndUnblock)
        let result = receivedSectionDataSource(from: sut, after: .onViewDidLoad)
        let expectedResult = ProfileViewModel.SectionCellDataSource(
            sectionOrder: sectionsOrder(),
            sectionRows: sectionRows(isSmsAllowed: true)
        )
        
        XCTAssertEqual(result, expectedResult)
    }
    
    func testSectionCells_whenAccountIsNotProFlexiBusinessNorMasterBusinessAccount_shouldNotIncludePlanSection() {
        let testAccountType = curriedTestSectionCellsForAccountType(
            expectedOrder: sectionsOrder(),
            expectedSectionRows: sectionRows()
        )
        
        testAccountType(.free)
        testAccountType(.proI)
        testAccountType(.proII)
        testAccountType(.proIII)
        testAccountType(.lite)
    }
    
    func testSectionCells_whenAccountIsProFlexiAccount_shouldIncludePlanSection() {
        let testAccountType = curriedTestSectionCellsForAccountType(
            expectedOrder: sectionsOrder(isPlanHidden: false),
            expectedSectionRows: sectionRows(isPlanHidden: false)
        )
        
        testAccountType(.proFlexi)
    }
    
    func testSectionCells_whenAccountIsBusinessAccount_shouldIncludePlanSection() {
        let testAccountType = curriedTestSectionCellsForAccountType(
            expectedOrder: sectionsOrder(isPlanHidden: false),
            expectedSectionRows: sectionRows(
                isPlanHidden: false,
                isBusiness: true
            )
        )
        
        testAccountType(.business)
    }
    
    func testSectionCells_whenAccountIsMasterBusinessAccount_shouldIncludePlanSection() {
        let testMasterBusinessAccountType = curriedTestSectionCellsForAccountType(
            expectedOrder: sectionsOrder(isPlanHidden: false),
            expectedSectionRows: sectionRows(
                isPlanHidden: false,
                isBusiness: true,
                isMasterBusinessAccount: true
            ),
            isMasterBusinessAccount: true
        )
        
        testMasterBusinessAccountType(.business)
    }
    
    func testAction_changeEmail_emailCellShouldBeLoading() {
        let (sut, _) = makeSUT()
        sut.dispatch(.onViewDidLoad)
        
        let expectation = XCTestExpectation(description: "Expected change email cell to be loading in the profile section")
        
        var result: ProfileViewModel.SectionCellDataSource?
        sut.sectionCellsPublisher
            .dropFirst(1)
            .first()
            .sink { sectionDataSource in
                result = sectionDataSource
                expectation.fulfill()
            }
            .store(in: &subscriptions)

        sut.dispatch(.changeEmail)
        
        wait(for: [expectation], timeout: 3)
        
        XCTAssertTrue(
            result?.sectionRows[.profile]?
                .contains(where: { $0 == .changeEmail(isLoading: true)}) ?? false
        )
    }
    
    func testAction_changePassword_passwordCellShouldBeLoading() {
        let (sut, _) = makeSUT()
        sut.dispatch(.onViewDidLoad)
        
        let expectation = XCTestExpectation(description: "Expected change password cell to be loading in the profile section")
        
        var result: ProfileViewModel.SectionCellDataSource?
        sut.sectionCellsPublisher
            .dropFirst(1)
            .first()
            .sink { sectionDataSource in
                result = sectionDataSource
                expectation.fulfill()
            }
            .store(in: &subscriptions)
        
        sut.dispatch(.changePassword)
        
        wait(for: [expectation], timeout: 1)
        
        XCTAssertTrue(
            result?.sectionRows[.profile]?
                .contains(where: { $0 == .changePassword(isLoading: true)}) ?? false
        )
    }
    
    func testAction_changeEmail_shouldPresentChangeController() {
        let (sut, _) = makeSUT(
            multiFactorAuthCheckResult: true,
            multiFactorAuthCheckDelay: 0.5
        )
        sut.dispatch(.onViewDidLoad)
        
        test(
            viewModel: sut,
            actions: [ProfileAction.changeEmail],
            expectedCommands: [.changeProfile(requestedChangeType: .email, isTwoFactorAuthenticationEnabled: true)]
        )
    }
    
    func testAction_changePassword_shouldPresentChangeController() {
        let (sut, _) = makeSUT(
            multiFactorAuthCheckResult: true,
            multiFactorAuthCheckDelay: 0.5
        )
        sut.dispatch(.onViewDidLoad)
        
        test(
            viewModel: sut,
            actions: [ProfileAction.changePassword],
            expectedCommands: [.changeProfile(requestedChangeType: .password, isTwoFactorAuthenticationEnabled: true)]
        )
    }
    
    func testAction_cancelSubscription_shouldPresentCancelAccountPlan() async {
        let planType: AccountTypeEntity = .proI
        let (sut, router) = makeSUT(currentAccountDetails: AccountDetailsEntity.build(proLevel: planType))
        
        sut.dispatch(.cancelSubscription)

        XCTAssertEqual(router.showCancelAccountPlan_calledTimes, 1, "Expected showCancelAccountPlan to be called once.")
    }
    
    func testAction_cancelSubscription_shouldPresentCancellationSteps() async {
        let planType: AccountTypeEntity = .proFlexi
        let (sut, router) = makeSUT(currentAccountDetails: AccountDetailsEntity.build(proLevel: planType))
        
        sut.dispatch(.cancelSubscription)

        XCTAssertEqual(router.showCancellationSteps_calledTimes, 1, "Expected showCancellationSteps to be called once.")
    }
    
    func test_cancelSubscription_tracksAnalyticsEvent() {
        let mockTracker = MockTracker()
        let (sut, _) = makeSUT(tracker: mockTracker)
        
        sut.dispatch(.cancelSubscription)
        
        assertTrackAnalyticsEventCalled(
            trackedEventIdentifiers: mockTracker.trackedEventIdentifiers,
            with: [CancelSubscriptionButtonPressedEvent()]
        )
    }
    
    // MARK: - Helpers
    
    private func makeSUT(
        currentAccountDetails: AccountDetailsEntity? = nil,
        email: String = "test@email.com",
        smsState: SMSStateEntity = .notAllowed,
        isMasterBusinessAccount: Bool = false,
        multiFactorAuthCheckResult: Bool = false,
        multiFactorAuthCheckDelay: TimeInterval = 0,
        hasValidProAccount: Bool = true,
        tracker: some AnalyticsTracking = MockTracker(),
        featureFlagProvider: MockFeatureFlagProvider = MockFeatureFlagProvider(list: [.cancelSubscription: true])
    ) -> (sut: ProfileViewModel, router: MockProfileViewRouter) {
        
        let accountUseCase = MockAccountUseCase(
            hasValidProAccount: hasValidProAccount,
            currentAccountDetails: currentAccountDetails,
            email: email,
            isMasterBusinessAccount: isMasterBusinessAccount,
            smsState: smsState,
            multiFactorAuthCheckResult: multiFactorAuthCheckResult,
            multiFactorAuthCheckDelay: 1.0
        )
        
        let router = MockProfileViewRouter()
        
        return (
            ProfileViewModel(
                accountUseCase: accountUseCase,
                featureFlagProvider: featureFlagProvider,
                tracker: tracker,
                router: router
            ),
            router
        )
    }
    
    private func receivedSectionDataSource(
        from sut: ProfileViewModel,
        after action: ProfileAction
    ) -> ProfileViewModel.SectionCellDataSource? {
        
        let expectation = XCTestExpectation(description: "Expected default set of sections and cell states")
        var result: ProfileViewModel.SectionCellDataSource?
        sut.sectionCellsPublisher
            .first()
            .sink { sectionDataSource in
                result = sectionDataSource
                expectation.fulfill()
            }
            .store(in: &subscriptions)
        
        sut.dispatch(action)
        wait(for: [expectation], timeout: 1)
        return result
    }
    
    private func curriedTestSectionCellsForAccountType(
        expectedOrder: [ProfileSection],
        expectedSectionRows: [ProfileSection: [ProfileSectionRow]],
        isMasterBusinessAccount: Bool = false
    ) -> (AccountTypeEntity) -> Void {
        { accountType in
            let expectedSections = ProfileViewModel.SectionCellDataSource(
                sectionOrder: expectedOrder,
                sectionRows: expectedSectionRows
            )
            let (sut, _) = self.makeSUT(
                currentAccountDetails: AccountDetailsEntity.build(proLevel: accountType),
                isMasterBusinessAccount: isMasterBusinessAccount
            )
            let result = self.receivedSectionDataSource(from: sut, after: .onViewDidLoad)
            XCTAssertEqual(result, expectedSections)
        }
    }
    
    private func sectionsOrder(
        isPlanHidden: Bool = true,
        hasValidProAccount: Bool = true
    ) -> [ProfileSection] {
        var sections: [ProfileSection] = isPlanHidden ? [.profile, .security, .session]: [.profile, .security, .plan, .session]
        
        if hasValidProAccount {
            sections.append(.subscription)
        }
        
        return sections
    }
    
    private func sectionRows(
        isPlanHidden: Bool = true,
        isSmsAllowed: Bool = false,
        isBusiness: Bool = false,
        isMasterBusinessAccount: Bool = false,
        hasValidProAccount: Bool = true
    ) -> [ProfileSection: [ProfileSectionRow]] {
        let profileRows: [ProfileSectionRow] = isBusiness && !isMasterBusinessAccount ?
            [.changePhoto, .changePassword(isLoading: false)] :
            [.changeName, .changePhoto, .changeEmail(isLoading: false), .changePassword(isLoading: false)]
        
        var sections: [ProfileSection: [ProfileSectionRow]]
        
        if isPlanHidden {
            sections = [
                .profile: isSmsAllowed ? profileRows + [.phoneNumber] : profileRows,
                .security: [.recoveryKey],
                .session: [.logout]
            ]
        } else {
            sections = [
                .profile: isSmsAllowed ? profileRows + [.phoneNumber] : profileRows,
                .security: [.recoveryKey],
                .plan: isBusiness ? [.upgrade, .role] : [.upgrade],
                .session: [.logout]
            ]
        }
        
        if hasValidProAccount {
            sections[.subscription] = [.cancelSubscription]
        }
        
        return sections
    }
}
