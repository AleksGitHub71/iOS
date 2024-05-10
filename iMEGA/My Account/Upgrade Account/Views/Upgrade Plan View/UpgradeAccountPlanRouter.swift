import Accounts
import MEGADesignToken
import MEGADomain
import MEGAPresentation
import MEGASDKRepo
import Settings
import SwiftUI

protocol UpgradeAccountPlanRouting: Routing {
    func showTermsAndPolicies()
}

final class UpgradeAccountPlanRouter: NSObject, UpgradeAccountPlanRouting {
    private weak var presenter: UIViewController?
    private weak var baseViewController: UIViewController?
    private var accountDetails: AccountDetailsEntity
    private let accountUseCase: any AccountUseCaseProtocol
    private let viewType: UpgradeAccountPlanViewType
    
    init(
        presenter: UIViewController,
        accountDetails: AccountDetailsEntity,
        viewType: UpgradeAccountPlanViewType = .upgrade
    ) {
        self.presenter = presenter
        self.accountDetails = accountDetails
        self.viewType = viewType
        accountUseCase = AccountUseCase(repository: AccountRepository.newRepo)
    }

    func build() -> UIViewController {
        let viewModel = UpgradeAccountPlanViewModel(
            accountDetails: accountDetails,
            accountUseCase: accountUseCase,
            purchaseUseCase: AccountPlanPurchaseUseCase(repository: AccountPlanPurchaseRepository.newRepo),
            viewType: viewType, 
            router: self
        )
        
        var accountsConfigs: AccountsConfig

        if DIContainer.featureFlagProvider.isFeatureFlagEnabled(for: .designToken) {
            accountsConfigs = AccountsConfig(onboardingViewAssets: AccountsConfig.OnboardingViewAssets(
                primaryTextColor: TokenColors.Text.primary.swiftUI,
                primaryGrayTextColor: TokenColors.Text.primary.swiftUI,
                secondaryTextColor: TokenColors.Text.secondary.swiftUI,
                subMessageBackgroundColor: TokenColors.Background.blur.swiftUI,
                headerForegroundSelectedColor: TokenColors.Text.accent.swiftUI,
                headerForegroundUnSelectedColor: TokenColors.Border.strong.swiftUI,
                headerBackgroundColor: TokenColors.Background.surface1.swiftUI,
                headerStrokeColor: TokenColors.Border.strong.swiftUI,
                backgroundColor: TokenColors.Background.page.swiftUI,
                currentPlanTagColor: TokenColors.Notifications.notificationWarning.swiftUI,
                recommendedPlanTagColor: TokenColors.Notifications.notificationInfo.swiftUI))
        } else {
            accountsConfigs = AccountsConfig(onboardingViewAssets: AccountsConfig.OnboardingViewAssets(
                primaryTextColor: MEGAAppColor.Account.upgradeAccountPrimaryText.color,
                primaryGrayTextColor: MEGAAppColor.Account.upgradeAccountPrimaryGrayText.color,
                secondaryTextColor: MEGAAppColor.Account.upgradeAccountSecondaryText.color,
                subMessageBackgroundColor: MEGAAppColor.Account.upgradeAccountSubMessageBackground.color,
                headerForegroundSelectedColor: MEGAAppColor.View.turquoise.color,
                headerForegroundUnSelectedColor: MEGAAppColor.Account.planUnselectedTint.color,
                headerBackgroundColor: MEGAAppColor.Account.planHeaderBackground.color,
                headerStrokeColor: MEGAAppColor.Account.planBorderTint.color,
                backgroundColor: MEGAAppColor.Account.planBodyBackground.color,
                currentPlanTagColor: MEGAAppColor.Account.currentPlan.color,
                recommendedPlanTagColor: MEGAAppColor.Account.planRecommended.color))
        }
        
        let upgradeAccountPlanView = UpgradeAccountPlanView(viewModel: viewModel, accountConfigs: accountsConfigs)
        let hostingController = UIHostingController(rootView: upgradeAccountPlanView)
        hostingController.isModalInPresentation = true
        return hostingController
    }
    
    func start() {
        let viewController = build()
        baseViewController = viewController
        presenter?.present(viewController, animated: true)
    }
    
    func showTermsAndPolicies() {
        TermsAndPoliciesRouter(
            accountUseCase: accountUseCase,
            presenter: baseViewController
        ).start()
    }
}
