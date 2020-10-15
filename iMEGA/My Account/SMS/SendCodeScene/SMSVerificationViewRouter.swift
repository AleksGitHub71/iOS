import Foundation

@objc enum SMSVerificationType: Int {
    case unblockAccount
    case addPhoneNumber
}

final class SMSVerificationViewRouter: NSObject, SMSVerificationViewRouting {
    private weak var baseViewController: UIViewController?
    private weak var presenter: UIViewController?
    private weak var navigationController: UINavigationController?
    
    private let verificationType: SMSVerificationType
    
    @objc init(verificationType: SMSVerificationType, presenter: UIViewController) {
        self.verificationType = verificationType
        self.presenter = presenter
        super.init()
    }
    
    func build() -> UIViewController {
        let sdk = MEGASdkManager.sharedMEGASdk()
        let repo = SMSRepository(sdk: sdk)
        let smsUseCase = SMSUseCase(getSMSUseCase: GetSMSUseCase(repo: repo), checkSMSUseCase: CheckSMSUseCase(repo: repo))
        let vm = SMSVerificationViewModel(router: self,
                                          smsUseCase: smsUseCase,
                                          achievementUseCase: AchievementUseCase(repo: AchievementRepository(sdk: sdk)),
                                          authUseCase: AuthUseCase(repo: AuthRepository(sdk: sdk)),
                                          verificationType: verificationType)
        
        let vc = UIStoryboard(name: "SMSVerification", bundle: nil).instantiateViewController(withIdentifier: "SMSVerificationViewControllerID") as! SMSVerificationViewController
        vc.viewModel = vm
        
        baseViewController = vc
        return vc
    }
    
    @objc func start() {
        let nav = SMSNavigationViewController(rootViewController: build())
        nav.modalPresentationStyle = .fullScreen
        navigationController = nav
        presenter?.present(nav, animated: true, completion: nil)
    }
    
    // MARK: - UI Actions
    func dismiss() {
        baseViewController?.dismiss(animated: true)
    }
    
    func goToRegionList(_ list: [SMSRegion], onRegionSelected: @escaping (SMSRegion) -> Void) {
        let router = RegionListViewRouter(navigationController: navigationController, regionCodes: list, onRegionSelected: onRegionSelected)
        router.start()
    }
    
    func goToVerificationCode(forPhoneNumber number: String) {
        let router = VerificationCodeViewRouter(navigationController: navigationController, verificationType: verificationType, phoneNumber: number)
        router.start()
    }
}
