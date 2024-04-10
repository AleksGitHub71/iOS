import Foundation
import MEGADomain
import MEGAPresentation

class AppearanceViewModel {
    
    enum SaveSettingValue {
        case showHiddenItems(Bool)
        case autoMediaDiscoverySetting(Bool)
        case mediaDiscoveryShouldIncludeSubfolderSetting(Bool)
        case hideRecentActivity(Bool)
    }
    
    enum SettingValue {
        case showHiddenItems
        case autoMediaDiscoverySetting
        case mediaDiscoveryShouldIncludeSubfolderSetting
        case hideRecentActivity
    }
    
    let mediaDiscoveryHelpLink = URL(string: "https://help.mega.io/files-folders/view-move/media-discovery-view-gallery")
    
    @PreferenceWrapper(key: .shouldDisplayMediaDiscoveryWhenMediaOnly, defaultValue: true)
    private var autoMediaDiscoverySetting: Bool
    @PreferenceWrapper(key: .mediaDiscoveryShouldIncludeSubfolderMedia, defaultValue: true)
    private var mediaDiscoveryShouldIncludeSubfolderSetting: Bool
    private let accountUseCase: any AccountUseCaseProtocol
    private let contentConsumptionUserAttributeUseCase: any ContentConsumptionUserAttributeUseCaseProtocol
    private let featureFlagProvider: any FeatureFlagProviderProtocol
    
    init(preferenceUseCase: some PreferenceUseCaseProtocol,
         accountUseCase: some AccountUseCaseProtocol,
         contentConsumptionUserAttributeUseCase: some ContentConsumptionUserAttributeUseCaseProtocol,
         featureFlagProvider: some FeatureFlagProviderProtocol = DIContainer.featureFlagProvider
    ) {
        self.accountUseCase = accountUseCase
        self.contentConsumptionUserAttributeUseCase = contentConsumptionUserAttributeUseCase
        self.featureFlagProvider = featureFlagProvider
        
        $autoMediaDiscoverySetting.useCase = preferenceUseCase
        $mediaDiscoveryShouldIncludeSubfolderSetting.useCase = preferenceUseCase
    }
    
    func fetchSettingValue(for setting: SettingValue) async -> Bool {
        switch setting {
        case .showHiddenItems:
            return await contentConsumptionUserAttributeUseCase.fetchSensitiveAttribute().showHiddenNodes
        case .autoMediaDiscoverySetting:
            return autoMediaDiscoverySetting
        case .mediaDiscoveryShouldIncludeSubfolderSetting:
            return mediaDiscoveryShouldIncludeSubfolderSetting
        case .hideRecentActivity:
            return !RecentsPreferenceManager.showRecents()
        }
    }
    
    func isAppearanceSectionVisible(section: AppearanceSection?) -> Bool {
        switch section {
        case .hiddenItems:
            guard featureFlagProvider.isFeatureFlagEnabled(for: .hiddenNodes) else {
                return false
            }
            return [.free, .none]
                .notContains(accountUseCase.currentAccountDetails?.proLevel)
        case .none:
            return false
        case .launch, .layout, .recents, .appIcon, .mediaDiscovery, .mediaDiscoverySubfolder:
            return true
        }
    }
    
    func saveSetting(for setting: SaveSettingValue) {
        switch setting {
        case .showHiddenItems(let value):
            Task { await saveShowHiddenNodesSetting(showHiddenNodes: value) }
        case .autoMediaDiscoverySetting(let value):
            autoMediaDiscoverySetting = value
        case .mediaDiscoveryShouldIncludeSubfolderSetting(let value):
            mediaDiscoveryShouldIncludeSubfolderSetting = value
        case .hideRecentActivity(let value):
            RecentsPreferenceManager.setShowRecents(!value)
        }
    }
    
    private func saveShowHiddenNodesSetting(showHiddenNodes: Bool) async {
        do {
            try await contentConsumptionUserAttributeUseCase.saveSensitiveSetting(showHiddenNodes: showHiddenNodes)
        } catch {
            MEGALogError("Error occurred when updating showHiddenNodes attribute. \(error.localizedDescription)")
        }
    }
}
