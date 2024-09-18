import Foundation
import MEGAAnalyticsiOS
import MEGADomain
import MEGAPresentation
import MEGASDKRepo

public final class CancelAccountPlanViewModel: ObservableObject {
    let currentPlanName: String
    let currentPlanStorageUsed: String
    let featureListHelper: FeatureListHelperProtocol
    let router: CancelAccountPlanRouting
    private let achievementUseCase: any AchievementUseCaseProtocol
    private let featureFlagProvider: any FeatureFlagProviderProtocol
    private let currentSubscription: AccountSubscriptionEntity
    @Published var showCancellationSurvey: Bool = false
    @Published var showCancellationSteps: Bool = false
    
    private let tracker: any AnalyticsTracking
    
    @Published private(set) var features: [FeatureDetails] = []
    
    init(
        currentSubscription: AccountSubscriptionEntity,
        currentPlanName: String,
        currentPlanStorageUsed: String,
        featureListHelper: FeatureListHelperProtocol,
        achievementUseCase: some AchievementUseCaseProtocol,
        featureFlagProvider: some FeatureFlagProviderProtocol = DIContainer.featureFlagProvider,
        tracker: some AnalyticsTracking,
        router: CancelAccountPlanRouting
    ) {
        self.currentSubscription = currentSubscription
        self.currentPlanName = currentPlanName
        self.currentPlanStorageUsed = currentPlanStorageUsed
        self.achievementUseCase = achievementUseCase
        self.featureListHelper = featureListHelper
        self.featureFlagProvider = featureFlagProvider
        self.tracker = tracker
        self.router = router
    }
    
    private var isCancellationSurveyEnabled: Bool {
        featureFlagProvider.isFeatureFlagEnabled(for: .subscriptionCancellationSurvey)
    }
    
    var cancellationStepsSubscriptionType: SubscriptionType {
        currentSubscription.paymentMethodId == .googleWallet ? .google : .webClient
    }
    
    @MainActor
    func setupFeatureList() async {
        do {
            let bytesBaseStorage = try await achievementUseCase.baseStorage()
            features = featureListHelper.createCurrentFeatures(
                baseStorage: bytesBaseStorage.bytesToGigabytes()
            )
        } catch {
            dismiss()
        }
    }
    
    func dismiss() {
        tracker.trackAnalyticsEvent(with: CancelSubscriptionKeepPlanButtonPressedEvent())
        router.dismissCancellationFlow()
    }
    
    @MainActor
    func didTapContinueCancellation() {
        tracker.trackAnalyticsEvent(with: CancelSubscriptionContinueCancellationButtonPressedEvent())
        
        if currentSubscription.paymentMethodId == .itunes {
            guard isCancellationSurveyEnabled else {
                router.showAppleManageSubscriptions()
                return
            }
            showCancellationSurvey = true
        } else {
            // Show cancellation step for either google or webclient subscriptions
            showCancellationSteps = true
        }
    }
    
    func makeCancellationSurveyViewModel() -> CancellationSurveyViewModel {
        CancellationSurveyViewModel(
            subscription: currentSubscription,
            subscriptionsUseCase: SubscriptionsUseCase(repo: SubscriptionsRepository.newRepo),
            cancelAccountPlanRouter: router)
    }
}
