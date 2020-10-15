import Foundation

enum SMSVerificationAction: ActionType {
    case onViewReady
    case loadRegionCodes
    case logout
    case showRegionList
    case sendCodeToLocalPhoneNumber(String)
    case cancel
}

protocol SMSVerificationViewRouting: Routing {
    func dismiss()
    func goToRegionList(_ list: [SMSRegion], onRegionSelected: @escaping (SMSRegion) -> Void)
    func goToVerificationCode(forPhoneNumber number: String)
}

final class SMSVerificationViewModel: ViewModelType {
    enum Command: CommandType, Equatable {
        case startLoading
        case finishLoading
        case configView(SMSVerificationType)
        case showRegion(String, callingCode: String)
        case showLoadAchievementResult(LoadAchievementResultCommand)
        case sendCodeToPhoneNumberError(message: String)
        
        enum LoadAchievementResultCommand: Equatable {
            case showStorage(String)
            case showError(String)
        }
    }
    
    // MARK: - Private properties
    private let verificationType: SMSVerificationType
    private let smsUseCase: SMSUseCase
    private let achievementUseCase: AchievementUseCaseProtocol
    private let authUseCase: AuthUseCaseProtocol
    private var regionList = [SMSRegion]()
    private let router: SMSVerificationViewRouting
    
    // MARK: - Internal properties
    var invokeCommand: ((Command) -> Void)?
    
    // MARK: - Init
    init(router: SMSVerificationViewRouting,
         smsUseCase: SMSUseCase,
         achievementUseCase: AchievementUseCaseProtocol,
         authUseCase: AuthUseCaseProtocol,
         verificationType: SMSVerificationType = .unblockAccount) {
        self.router = router
        self.smsUseCase = smsUseCase
        self.achievementUseCase = achievementUseCase
        self.authUseCase = authUseCase
        self.verificationType = verificationType
    }
    
    // MARK: - Dispatch action
    func dispatch(_ action: SMSVerificationAction) {
        switch action {
        case .onViewReady:
            invokeCommand?(.configView(verificationType))
            if case SMSVerificationType.addPhoneNumber = verificationType {
                getAchievementStorage()
            }
        case .loadRegionCodes:
            loadCallingCodes()
        case .showRegionList:
            router.goToRegionList(regionList) { [weak self] in
                self?.showRegion($0)
            }
        case .sendCodeToLocalPhoneNumber(let number):
            sendCodeToPhoneNumber(number)
        case .logout:
            authUseCase.logout()
        case .cancel:
            router.dismiss()
        }
    }
    
    // MARK: - Load regions
    private func loadCallingCodes() {
        invokeCommand?(.startLoading)
        smsUseCase.getSMSUseCase.getRegionCallingCodes { [weak self] in
            guard let self = self else { return }
            
            self.invokeCommand?(.finishLoading)
            switch $0 {
            case .success(let codes):
                self.regionList = codes.allRegions.compactMap { $0.toSMSRegion() }
                if let region = codes.currentRegion?.toSMSRegion() {
                    self.showRegion(region)
                }
            case .failure(let error):
                MEGALogError("Could not load country calling code with error \(error)")
            }
        }
    }
    
    // MARK: - Show a region
    private func showRegion(_ region: SMSRegion) {
        invokeCommand?(.showRegion(region.displayName, callingCode: region.displayCallingCode))
    }

    // MARK: - Get achievement
    private func getAchievementStorage() {
        achievementUseCase.getAchievementStorage(by: .addPhone) { [weak self] in
            switch $0 {
            case .success(let storage):
                let message = String(format: AMLocalizedString("Get free %@ when you add your phone number. This makes it easier for your contacts to find you on MEGA."), Helper.memoryStyleString(fromByteCount: storage.valueNumber.int64Value))
                self?.invokeCommand?(.showLoadAchievementResult(.showStorage(message)))
            case .failure:
                let message = AMLocalizedString("Add your phone number to MEGA. This makes it easier for your contacts to find you on MEGA.")
                self?.invokeCommand?(.showLoadAchievementResult(.showError(message)))
            }
        }
    }
    
    // MARK: - Send code
    private func sendCodeToPhoneNumber(_ phoneNumber: String) {
        invokeCommand?(.startLoading)
        smsUseCase.checkSMSUseCase.sendVerification(toPhoneNumber: phoneNumber) { [weak self] in
            self?.invokeCommand?(.finishLoading)
            switch $0 {
            case .success(let number):
                DispatchQueue.main.async { self?.router.goToVerificationCode(forPhoneNumber: number) }
            case .failure(let error):
                let message: String
                switch error {
                case .reachedDailyLimit:
                    message = AMLocalizedString("You have reached the daily limit")
                case .alreadyVerifiedWithCurrentAccount:
                    message = AMLocalizedString("Your account is already verified")
                case .alreadyVerifiedWithAnotherAccount:
                    message = AMLocalizedString("This number is already associated with a Mega account")
                case .wrongFormat:
                    message = AMLocalizedString("Please enter a valid phone number")
                default:
                    message = AMLocalizedString("Unknown error")
                }
                
                self?.invokeCommand?(.sendCodeToPhoneNumberError(message: message))
            }
        }
    }
}
