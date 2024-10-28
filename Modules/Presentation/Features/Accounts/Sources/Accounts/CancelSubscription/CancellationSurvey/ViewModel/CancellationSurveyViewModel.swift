import MEGAAnalyticsiOS
import MEGADomain
import MEGAPresentation
import MEGASDKRepo
import SwiftUI

final class CancellationSurveyViewModel: ObservableObject {
    @Published var shouldDismiss: Bool = false
    @Published var selectedReason: CancellationSurveyReason?
    @Published var cancellationSurveyReasonList: [CancellationSurveyReason] = []
    @Published var otherReasonText: String = ""
    @Published var isOtherFieldFocused: Bool = false
    @Published var allowToBeContacted: Bool = false
    @Published var showNoReasonSelectedError: Bool = false
    @Published var showMinLimitOrEmptyOtherFieldError: Bool = false
    @Published var dismissKeyboard: Bool = false
    
    let otherReasonID = CancellationSurveyReason.otherReason.id
    let minimumTextRequired = 10
    let maximumTextRequired = 120
    private(set) var subscription: AccountSubscriptionEntity
    private let subscriptionsUseCase: any SubscriptionsUseCaseProtocol
    private let cancelAccountPlanRouter: any CancelAccountPlanRouting
    private let tracker: any AnalyticsTracking
    private let logger: ((String) -> Void)?
    var submitSurveyTask: Task<Void, Never>?
    
    init(
        subscription: AccountSubscriptionEntity,
        subscriptionsUseCase: some SubscriptionsUseCaseProtocol,
        cancelAccountPlanRouter: some CancelAccountPlanRouting,
        tracker: some AnalyticsTracking = DIContainer.tracker,
        logger: ((String) -> Void)? = nil
    ) {
        self.subscription = subscription
        self.subscriptionsUseCase = subscriptionsUseCase
        self.cancelAccountPlanRouter = cancelAccountPlanRouter
        self.tracker = tracker
        self.logger = logger
    }
    
    deinit {
        submitSurveyTask?.cancel()
        submitSurveyTask = nil
    }
    
    // MARK: - Setup
    @MainActor
    func setupRandomizedReasonList() {
        let otherReasonItem = CancellationSurveyReason.eight
        let cancellationReasons = CancellationSurveyReason.allCases.filter({ $0 != otherReasonItem })
        
        var randomizedList = cancellationReasons.shuffled()
        randomizedList.append(otherReasonItem)
        
        cancellationSurveyReasonList = randomizedList
    }
    
    func trackViewOnAppear() {
        tracker.trackAnalyticsEvent(with: SubscriptionCancellationSurveyScreenEvent())
    }
    
    // MARK: - Reason selection
    @MainActor
    func selectReason(_ reason: CancellationSurveyReason) {
        selectedReason = reason
        isOtherFieldFocused = false
        showNoReasonSelectedError = false
    }
    
    var formattedReasonString: String? {
        guard let selectedReason else { return nil }
        return selectedReason.isOtherReason ? otherReasonText : "\(selectedReason.id) - \(selectedReason.title)"
    }
    
    func isReasonSelected(_ reason: CancellationSurveyReason) -> Bool {
        selectedReason?.id == reason.id
    }
    
    // MARK: - Button action
    @MainActor
    func didTapCancelButton() {
        shouldDismiss = true
        tracker.trackAnalyticsEvent(with: SubscriptionCancellationSurveyCancelViewButtonEvent())
    }
    
    @MainActor
    func didTapDontCancelButton() {
        shouldDismiss = true
        cancelAccountPlanRouter.dismissCancellationFlow()
        tracker.trackAnalyticsEvent(with: SubscriptionCancellationSurveyDontCancelButtonEvent())
    }
    
    @MainActor
    func didTapCancelSubscriptionButton() {
        guard validateSelectedReason() else { return }
        
        if selectedReason?.isOtherReason == true {
            guard validateOtherReasonText() else { return }
            dismissKeyboard = true
        }
        
        trackCancelSubscriptionEvent()
        
        submitSurveyTask = Task { [weak self] in
            guard let self else { return }
            await handleSubscriptionCancellation()
        }
    }

    private func validateSelectedReason() -> Bool {
        guard selectedReason != nil else {
            showNoReasonSelectedError = true
            return false
        }
        return true
    }

    private func validateOtherReasonText() -> Bool {
        guard !otherReasonText.isEmpty && otherReasonText.count >= minimumTextRequired else {
            showMinLimitOrEmptyOtherFieldError = true
            return false
        }
        
        guard otherReasonText.count <= maximumTextRequired else {
            return false
        }
        
        return true
    }

    private func trackCancelSubscriptionEvent() {
        tracker.trackAnalyticsEvent(with: SubscriptionCancellationSurveyCancelSubscriptionButtonEvent())
    }

    @MainActor
    private func handleSubscriptionCancellation() async {
        do {
            try await subscriptionsUseCase.cancelSubscriptions(
                reason: formattedReasonString,
                subscriptionId: subscription.id,
                canContact: allowToBeContacted
            )
            
            switch subscription.paymentMethodId {
            case .itunes:
                cancelAccountPlanRouter.showAppleManageSubscriptions()
            default:
                cancelAccountPlanRouter.showAlert(.success(Date(timeIntervalSince1970: TimeInterval(subscription.renewTime))))
            }
        } catch {
            logger?("[Cancellation Survey] Error - \(error.localizedDescription)")
            cancelAccountPlanRouter.showAlert(.failure(error))
        }
    }
}
