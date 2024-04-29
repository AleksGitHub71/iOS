import DeviceCenter
import DeviceCenterMocks
@testable import MEGA
import MEGADomain
import MEGADomainMock
import MEGAPresentationMock
import MEGASDKRepoMock
import XCTest

final class MyAccountHallViewModelTests: XCTestCase {

    func testAction_onViewAppear() {
        let (sut, _) = makeSUT()
        test(viewModel: sut,
             actions: [MyAccountHallAction.reloadUI],
             expectedCommands: [.reloadUIContent])
    }
    
    func testAction_loadPlanList() async {
        let (sut, _) = makeSUT()
        
        var commands = [MyAccountHallViewModel.Command]()
        sut.invokeCommand = { viewCommand in
            commands.append(viewCommand)
        }

        sut.dispatch(.load(.planList))
        await sut.loadContentTask?.value
        
        XCTAssertEqual(commands, [.configPlanDisplay])
    }
    
    func testAction_loadContentCounts() async {
        let (sut, _) = makeSUT()
        
        var commands = [MyAccountHallViewModel.Command]()
        sut.invokeCommand = { viewCommand in
            commands.append(viewCommand)
        }

        sut.dispatch(.load(.contentCounts))
        await sut.loadContentTask?.value
        
        XCTAssertEqual(commands, [.reloadCounts])
    }
    
    func testAction_loadAccountDetails() async {
        let (sut, _) = makeSUT()
        
        var commands = [MyAccountHallViewModel.Command]()
        sut.invokeCommand = { viewCommand in
            commands.append(viewCommand)
        }

        sut.dispatch(.load(.accountDetails))
        await sut.loadContentTask?.value
        
        XCTAssertEqual(commands, [.configPlanDisplay])
    }
    
    func testAction_addSubscriptions() {
        let (sut, _) = makeSUT()
        
        test(viewModel: sut,
             actions: [MyAccountHallAction.addSubscriptions],
             expectedCommands: [])
    }
    
    func testAction_removeSubscriptions() {
        let (sut, _) = makeSUT()
        
        test(viewModel: sut,
             actions: [MyAccountHallAction.removeSubscriptions],
             expectedCommands: [])
    }
    
    func testInitAccountDetails_shouldHaveCorrectDetails() {
        let expectedAccountDetails = AccountDetailsEntity.random
        let (sut, _) = makeSUT(currentAccountDetails: expectedAccountDetails)
    
        XCTAssertEqual(sut.accountDetails, expectedAccountDetails)
    }
    
    func testArePromosAvailable_whenNotificationsEnabled_shouldReturnTrue() async throws {
        let (sut, _) = makeSUT(
            enabledNotifications: [NotificationIDEntity(1), NotificationIDEntity(2), NotificationIDEntity(3)],
            featureFlagProvider: MockFeatureFlagProvider(list: [.notificationCenter: true])
        )
        
        let result = await loadPromosAndGetAvailability(for: sut)
        XCTAssertTrue(result, "Promos should be available when notifications are enabled and the notification center feature flag is true.")
    }
    
    func testArePromosAvailable_whenNotificationsNotEnabled_shouldReturnFalse() async throws {
        let (sut, _) = makeSUT(
            featureFlagProvider: MockFeatureFlagProvider(list: [.notificationCenter: true])
        )
        
        let result = await loadPromosAndGetAvailability(for: sut)
        XCTAssertFalse(result, "Promos should not be available when notifications are not enabled, even if the notification center feature flag is true.")
    }

    func testIsMasterBusinessAccount_shouldBeTrue() {
        let (sut, _) = makeSUT(isMasterBusinessAccount: true)
        XCTAssertTrue(sut.isMasterBusinessAccount)
    }
    
    func testIsMasterBusinessAccount_shouldBeFalse() {
        let (sut, _) = makeSUT(isMasterBusinessAccount: false)
        XCTAssertFalse(sut.isMasterBusinessAccount)
    }
    
    func testAction_didTapUpgradeButton_showUpgradeView() {
        let (sut, _) = makeSUT()
        
        test(viewModel: sut, actions: [MyAccountHallAction.didTapUpgradeButton], expectedCommands: [])
    }
    
    func testIsFeatureFlagEnabled_onNotificationCenterUIEnabled_shouldBeEnabled() {
        let (sut, _) = makeSUT(featureFlagProvider: MockFeatureFlagProvider(list: [.notificationCenter: true]))
        XCTAssertTrue(sut.isNotificationCenterEnabled())
    }
    
    func testDidTapDeviceCenterButton_whenButtonIsTapped_navigatesToDeviceCenter() {
        let (sut, router) = makeSUT()
        
        test(viewModel: sut,
             actions: [MyAccountHallAction.didTapDeviceCenterButton],
             expectedCommands: [])
        
        XCTAssertEqual(router.navigateToDeviceCenter_calledTimes, 1)
    }
    
    func testDidTapCameraUploadsAction_whenCameraUploadActionTapped_callsRouterOnce() {
        let deviceCenterBridge = DeviceCenterBridge()
        let (sut, router) = makeSUT(deviceCenterBridge: deviceCenterBridge)
        
        test(viewModel: sut,
             actions: [MyAccountHallAction.didTapDeviceCenterButton],
             expectedCommands: [])
        
        deviceCenterBridge.cameraUploadActionTapped({})
        
        XCTAssertEqual(
            router.didTapCameraUploadsAction_calledTimes, 1, "Camera upload action should have called the router once"
        )
    }
    
    func testDidTapRenameAction_whenRenameActionTapped_callsRouterOnce() {
        let deviceCenterBridge = DeviceCenterBridge()
        let (sut, router) = makeSUT(deviceCenterBridge: deviceCenterBridge)
        
        test(viewModel: sut,
             actions: [MyAccountHallAction.didTapDeviceCenterButton],
             expectedCommands: [])
        
        deviceCenterBridge.renameActionTapped(
            RenameActionEntity(
                oldName: "",
                otherNamesInContext: [],
                actionType: .device(deviceId: "", maxCharacters: 32),
                alertTitles: [:],
                alertMessage: [:],
                alertPlaceholder: "",
                renamingFinished: {}
            )
        )
        
        XCTAssertEqual(
            router.didTapRenameAction_calledTimes, 1, "Rename node action should have called the router once"
        )
    }
    
    func testDidTapShowIn_whenShowInActionTapped_callsRouterOnce() async throws {
        let deviceCenterBridge = DeviceCenterBridge()
        let (sut, router) = makeSUT(deviceCenterBridge: deviceCenterBridge)
        
        test(viewModel: sut,
             actions: [MyAccountHallAction.didTapDeviceCenterButton],
             expectedCommands: [])
        
        deviceCenterBridge.showInTapped(
            NavigateToContentActionEntity(
                type: .showInBackups,
                node: MockNode(handle: 1).toNodeEntity(),
                error: nil
            )
        )
        
        XCTAssertEqual(
            router.didTapShowInAction_calledTimes, 1, "Show in action should have called the router once"
        )
    }
    
    func testDidTapInfoAction_whenInfoActionTapped_callsRouterOnce() async throws {
        let deviceCenterBridge = DeviceCenterBridge()
        let (sut, router) = makeSUT(deviceCenterBridge: deviceCenterBridge)
        
        test(viewModel: sut,
             actions: [MyAccountHallAction.didTapDeviceCenterButton],
             expectedCommands: [])
        
        deviceCenterBridge.infoActionTapped(
            ResourceInfoModel(
                icon: "",
                name: "",
                counter: ResourceCounter.emptyCounter
            )
        )
        
        XCTAssertEqual(
            router.didTapInfoAction_calledTimes, 1, "Info action should have called the router once"
        )
    }
    
    private func loadPromosAndGetAvailability(for sut: MyAccountHallViewModel) async -> Bool {
        sut.dispatch(.load(.promos))
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        return sut.arePromosAvailable
    }
    
    func testShowPlanRow_businessAccount_shouldBeFalse() {
        let (sut, _) = makeSUT(currentAccountDetails: AccountDetailsEntity(proLevel: .business))
        
        XCTAssertFalse(sut.showPlanRow)
    }
    
    func testShowPlanRow_proFlexiAccount_shouldBeFalse() {
        let (sut, _) = makeSUT(currentAccountDetails: AccountDetailsEntity(proLevel: .proFlexi))
        
        XCTAssertFalse(sut.showPlanRow)
    }
    
    func testShowPlanRow_freeOrProAccount_shouldBeTrue() {
        let accountTypes: [AccountTypeEntity] = [.free, .proI, .proII, .proIII]
        accountTypes.enumerated().forEach { (index, accountType) in
            let (sut, _) = makeSUT(currentAccountDetails: AccountDetailsEntity(proLevel: accountType))
            
            XCTAssertTrue(sut.showPlanRow, "failed at index: \(index) for accountType: \(accountType)")
        }
    }
    
    func testCalculateCellHeight_planSection_showPlanRowIsTrue_shouldNotBeZero() {
        let accountTypes: [AccountTypeEntity] = [.free, .proI, .proII, .proIII]
        let indexPath = IndexPath(row: MyAccountMegaSection.plan.rawValue,
                                  section: MyAccountSection.mega.rawValue)
        
        accountTypes.enumerated().forEach { (index, accountType) in
            let (sut, _) = makeSUT(currentAccountDetails: AccountDetailsEntity(proLevel: accountType))
            
            XCTAssertNotEqual(sut.calculateCellHeight(at: indexPath), 0, "failed at index: \(index) for accountType: \(accountType)")
        }
    }
    
    func testCalculateCellHeight_planSection_showPlanRowIsFalse_shouldBeZero() {
        let accountTypes: [AccountTypeEntity] = [.proFlexi, .business]
        let indexPath = IndexPath(row: MyAccountMegaSection.plan.rawValue,
                                  section: MyAccountSection.mega.rawValue)

        accountTypes.enumerated().forEach { (index, accountType) in
            let (sut, _) = makeSUT(currentAccountDetails: AccountDetailsEntity(proLevel: accountType))
            
            XCTAssertEqual(sut.calculateCellHeight(at: indexPath), 0, "failed at index: \(index) for accountType: \(accountType)")
        }
    }
    
    func testCalculateCellHeight_achievementSection_isAchievementEnabledTrue_shouldNotBeZero() {
        let indexPath = IndexPath(row: MyAccountMegaSection.achievements.rawValue,
                                  section: MyAccountSection.mega.rawValue)
        
        let (sut, _) = makeSUT(isAchievementsEnabled: true)
        
        XCTAssertNotEqual(sut.calculateCellHeight(at: indexPath), 0)
    }
    
    func testCalculateCellHeight_achievementSection_isAchievementEnabledFalse_shouldBeZero() {
        let indexPath = IndexPath(row: MyAccountMegaSection.achievements.rawValue,
                                  section: MyAccountSection.mega.rawValue)
        
        let (sut, _) = makeSUT(isAchievementsEnabled: false)
        
        XCTAssertEqual(sut.calculateCellHeight(at: indexPath), 0)
    }
    
    func testCalculateCellHeight_myAccountSection_featureFlagIsEnabled_shouldNotBeZero() {
        let (sut, _) = makeSUT(currentAccountDetails: AccountDetailsEntity.random,
                               featureFlagProvider: MockFeatureFlagProvider(list: [.cancelSubscription: true]))
        let indexPath = IndexPath(row: MyAccountMegaSection.myAccount.rawValue,
                                  section: MyAccountSection.mega.rawValue)
        
        XCTAssertNotEqual(sut.calculateCellHeight(at: indexPath), 0)
    }
    
    func testCalculateCellHeight_myAccountSection_featureFlagIsDisabled_shouldBeZero() {
        let (sut, _) = makeSUT(currentAccountDetails: AccountDetailsEntity.random,
                               featureFlagProvider: MockFeatureFlagProvider(list: [.cancelSubscription: false]))
        let indexPath = IndexPath(row: MyAccountMegaSection.myAccount.rawValue,
                                  section: MyAccountSection.mega.rawValue)
        
        XCTAssertEqual(sut.calculateCellHeight(at: indexPath), 0)
    }
    
    private func makeSUT(
        isMasterBusinessAccount: Bool = false,
        isAchievementsEnabled: Bool = false,
        enabledNotifications: [NotificationIDEntity] = [],
        currentAccountDetails: AccountDetailsEntity? = nil,
        featureFlagProvider: MockFeatureFlagProvider = MockFeatureFlagProvider(list: [:]),
        deviceCenterBridge: DeviceCenterBridge = DeviceCenterBridge()
    ) -> (MyAccountHallViewModel, MockMyAccountHallRouter) {
        let myAccountHallUseCase = MockMyAccountHallUseCase(
            currentAccountDetails: currentAccountDetails ?? AccountDetailsEntity.random,
            isMasterBusinessAccount: isMasterBusinessAccount,
            isAchievementsEnabled: isAchievementsEnabled
        )
        
        let purchaseUseCase = MockAccountPlanPurchaseUseCase()
        let shareUseCase = MockShareUseCase()
        let notificationUseCase = MockNotificationUseCase(enabledNotifications: enabledNotifications)
        let router = MockMyAccountHallRouter()
        
        return (
            MyAccountHallViewModel(
                myAccountHallUseCase: myAccountHallUseCase,
                purchaseUseCase: purchaseUseCase, 
                shareUseCase: shareUseCase,
                notificationsUseCase: notificationUseCase,
                featureFlagProvider: featureFlagProvider,
                deviceCenterBridge: deviceCenterBridge,
                router: router
            ), router
        )
    }
}
