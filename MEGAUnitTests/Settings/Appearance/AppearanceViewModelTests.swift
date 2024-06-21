@testable import MEGA
import MEGADomain
import MEGADomainMock
import MEGAPresentation
import MEGAPresentationMock
import XCTest

final class AppearanceViewModelTests: XCTestCase {
    func testAutoMediaDiscoverySetting_noPreferenceSet_shouldDefaultToTrue() async {
        let sut = makeSUT()
        let result = await sut.fetchSettingValue(for: .autoMediaDiscoverySetting)
        XCTAssertTrue(result)
    }
    
    func testAutoMediaDiscoverySetting_preferenceSet_shouldSetToValue() async {
        let preferenceUseCase = MockPreferenceUseCase(dict: [.shouldDisplayMediaDiscoveryWhenMediaOnly: false])
        let sut = makeSUT(preferenceUseCase: preferenceUseCase)
        let result = await sut.fetchSettingValue(for: .autoMediaDiscoverySetting)
        XCTAssertFalse(result)
    }
    
    func testFetchSettingValue_expectSetValue() async {
        let useCase = MockContentConsumptionUserAttributeUseCase(
            sensitiveNodesUserAttributeEntity: .init(onboarded: false, showHiddenNodes: false))
        let sut = makeSUT(contentConsumptionUserAttributeUseCase: useCase)
        let result = await sut.fetchSettingValue(for: .showHiddenItems)
        XCTAssertFalse(result)
    }
    
    func testAutoMediaDiscoverySetting_onValueChange_shouldChangePreference() throws {
        let preferenceUseCase = MockPreferenceUseCase(dict: [:])
        let sut = makeSUT(preferenceUseCase: preferenceUseCase)
        
        sut.saveSetting(for: .autoMediaDiscoverySetting(false))
        
        let changedPreference = try XCTUnwrap(preferenceUseCase.dict[.shouldDisplayMediaDiscoveryWhenMediaOnly] as? Bool)
        XCTAssertFalse(changedPreference)
    }
    
    func testMediaDiscoveryShouldIncludeSubfolderSetting_noPreferenceSet_shouldDefaultToTrue() async {
        let sut = makeSUT()
        let result = await sut.fetchSettingValue(for: .mediaDiscoveryShouldIncludeSubfolderSetting)
        XCTAssertTrue(result)
    }
    
    func testMediaDiscoveryShouldIncludeSubfolderSetting_preferenceSet_shouldSetToValue() async {
        let preferenceUseCase = MockPreferenceUseCase(dict: [.mediaDiscoveryShouldIncludeSubfolderMedia: false])
        let sut = makeSUT(preferenceUseCase: preferenceUseCase)
        let result = await sut.fetchSettingValue(for: .mediaDiscoveryShouldIncludeSubfolderSetting)

        XCTAssertFalse(result)
    }
    
    func testMediaDiscoveryShouldIncludeSubfolderSetting_onValueChange_shouldChangePreference() throws {
        let preferenceUseCase = MockPreferenceUseCase(dict: [:])
        let sut = makeSUT(preferenceUseCase: preferenceUseCase)
        
        sut.saveSetting(for: .mediaDiscoveryShouldIncludeSubfolderSetting(false))
        
        let changedPreference = try XCTUnwrap(preferenceUseCase.dict[.mediaDiscoveryShouldIncludeSubfolderMedia] as? Bool)
        XCTAssertFalse(changedPreference)
    }
    
    func testMediaDiscoveryHelpLink_shouldBeCorrect() {
        let sut = makeSUT()
        
        XCTAssertEqual(sut.mediaDiscoveryHelpLink, URL(string: "https://help.mega.io/files-folders/view-move/media-discovery-view-gallery"))
    }
    
    func testIsAppearanceSectionVisible_ForFreeUserAccountAndHiddenNodesFlagEnabled_shouldReturnCorrectResults() {
        let sut = makeSUT(
            accountUseCase: MockAccountUseCase(currentAccountDetails: AccountDetailsEntity.build(proLevel: .free)),
            featureFlagProvider: MockFeatureFlagProvider(list: [.hiddenNodes: true]))
        
        let expectedResult: [(AppearanceSection, Bool)] = [
            (.launch, true),
            (.layout, true),
            (.hiddenItems, false),
            (.mediaDiscovery, true),
            (.mediaDiscoverySubfolder, true),
            (.recents, true),
            (.appIcon, true)
        ]
        
        expectedResult.forEach { section, result in
            let isAppearanceSectionVisible = sut.isAppearanceSectionVisible(section: section)
            XCTAssertEqual(isAppearanceSectionVisible, result, "AppearanceSection.\(section) should be \(result)")
        }
    }
    
    func testIsAppearanceSectionVisible_ForFreeUserAccountAndHiddenNodesFlagDisabled_shouldReturnCorrectResults() {
        let sut = makeSUT(
            accountUseCase: MockAccountUseCase(currentAccountDetails: AccountDetailsEntity.build(proLevel: .free)),
            featureFlagProvider: MockFeatureFlagProvider(list: [.hiddenNodes: false]))
        
        let expectedResult: [(AppearanceSection, Bool)] = [
            (.launch, true),
            (.layout, true),
            (.hiddenItems, false),
            (.mediaDiscovery, true),
            (.mediaDiscoverySubfolder, true),
            (.recents, true),
            (.appIcon, true)
        ]
        
        expectedResult.forEach { section, result in
            let isAppearanceSectionVisible = sut.isAppearanceSectionVisible(section: section)
            XCTAssertEqual(isAppearanceSectionVisible, result, "AppearanceSection.\(section) should be \(result)")
        }
    }
    
    func testIsAppearanceSectionVisible_ForPaidUserAccountAndHiddenNodesFlagEnabled_shouldReturnCorrectResults() {
        let sut = makeSUT(
            accountUseCase: MockAccountUseCase(currentAccountDetails: AccountDetailsEntity.build(proLevel: .lite)),
            featureFlagProvider: MockFeatureFlagProvider(list: [.hiddenNodes: true]))
        
        let expectedResult: [(AppearanceSection, Bool)] = [
            (.launch, true),
            (.layout, true),
            (.hiddenItems, true),
            (.mediaDiscovery, true),
            (.mediaDiscoverySubfolder, true),
            (.recents, true),
            (.appIcon, true)
        ]
        
        expectedResult.forEach { section, result in
            let isAppearanceSectionVisible = sut.isAppearanceSectionVisible(section: section)
            XCTAssertEqual(isAppearanceSectionVisible, result, "AppearanceSection.\(section) should be \(result)")
        }
    }
    
    func testIsAppearanceSectionVisible_ForPaidUserAccountAndHiddenNodesFlagDisabled_shouldReturnCorrectResults() {
        let sut = makeSUT(
            accountUseCase: MockAccountUseCase(currentAccountDetails: AccountDetailsEntity.build(proLevel: .lite)),
            featureFlagProvider: MockFeatureFlagProvider(list: [.hiddenNodes: false]))
        
        let expectedResult: [(AppearanceSection, Bool)] = [
            (.launch, true),
            (.layout, true),
            (.hiddenItems, false),
            (.mediaDiscovery, true),
            (.mediaDiscoverySubfolder, true),
            (.recents, true),
            (.appIcon, true)
        ]
        
        expectedResult.forEach { section, result in
            let isAppearanceSectionVisible = sut.isAppearanceSectionVisible(section: section)
            XCTAssertEqual(isAppearanceSectionVisible, result, "AppearanceSection.\(section) should be \(result)")
        }
    }
    
    func testSaveSetting_forAutoMediaDiscoverySetting_shouldSetSavedValue() {
        let preferenceUseCase = MockPreferenceUseCase(dict: [:])
        let sut = makeSUT(preferenceUseCase: preferenceUseCase)
        sut.saveSetting(for: .autoMediaDiscoverySetting(true))
        XCTAssertTrue(preferenceUseCase[.shouldDisplayMediaDiscoveryWhenMediaOnly] ?? false)
    }
    
    func testSaveSetting_forMediaDiscoveryShouldIncludeSubfolderSetting_shouldSetSavedValue() {
        let preferenceUseCase = MockPreferenceUseCase(dict: [:])
        let sut = makeSUT(preferenceUseCase: preferenceUseCase)
        sut.saveSetting(for: .mediaDiscoveryShouldIncludeSubfolderSetting(true))
        XCTAssertTrue(preferenceUseCase[.mediaDiscoveryShouldIncludeSubfolderMedia] ?? false)
    }
    
    func testSaveSetting_forShowHiddenNodes_shouldSetSavedValue() async {
        let useCase = MockContentConsumptionUserAttributeUseCase(
            sensitiveNodesUserAttributeEntity: .init(onboarded: false, showHiddenNodes: false))
        let sut = makeSUT(contentConsumptionUserAttributeUseCase: useCase)
        
        let exp = expectation(description: "Expect sensitiveAttributeChanged to be emitted")
        let subscription = useCase
            .$sensitiveAttributeChanged
            .first(where: \.showHiddenNodes)
            .sink { result in
                XCTAssertTrue(result.showHiddenNodes)
                exp.fulfill()
            }
        
        sut.saveSetting(for: .showHiddenItems(true))
        
        await fulfillment(of: [exp], timeout: 1)
        subscription.cancel()
    }
    
    private func makeSUT(
        preferenceUseCase: some PreferenceUseCaseProtocol = MockPreferenceUseCase(dict: [:]),
        accountUseCase: some AccountUseCaseProtocol = MockAccountUseCase(),
        contentConsumptionUserAttributeUseCase: some ContentConsumptionUserAttributeUseCaseProtocol = MockContentConsumptionUserAttributeUseCase(),
        featureFlagProvider: some FeatureFlagProviderProtocol = MockFeatureFlagProvider(list: [.hiddenNodes: false]),
        file: StaticString = #file,
        line: UInt = #line) -> AppearanceViewModel {
            let sut = AppearanceViewModel(
                preferenceUseCase: preferenceUseCase,
                accountUseCase: accountUseCase, 
                contentConsumptionUserAttributeUseCase: contentConsumptionUserAttributeUseCase,
                featureFlagProvider: featureFlagProvider
            )
            trackForMemoryLeaks(on: sut, file: file, line: line)
            return sut
        }
}
