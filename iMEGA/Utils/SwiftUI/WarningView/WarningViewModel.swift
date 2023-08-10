enum WarningType: CustomStringConvertible {
    case noInternetConnection
    case limitedPhotoAccess
    case requiredIncomingSharedItemVerification
    case contactsNotVerified

    var description: String {
        switch self {
        case .noInternetConnection:
            return Strings.Localizable.General.noIntenerConnection
        case .limitedPhotoAccess:
            return Strings.Localizable.CameraUploads.Warning.limitedAccessToPhotoMessage
        case .requiredIncomingSharedItemVerification:
            return Strings.Localizable.SharedItems.ContactVerification.Section.VerifyContact.bannerMessage
        case .contactsNotVerified:
            return Strings.Localizable.ShareFolder.contactsNotVerified
        }
    }
}

@objc final class WarningViewModel: NSObject, ObservableObject {
    let warningType: WarningType
    let router: (any WarningViewRouting)?
    let isShowCloseButton: Bool
    var hideWarningViewAction: (() -> Void)?
    @Published var isHideWarningView: Bool = false
    
    init(warningType: WarningType,
         router: (any WarningViewRouting)? = nil,
         isShowCloseButton: Bool = false,
         hideWarningViewAction: (() -> Void)? = nil) {
        self.warningType = warningType
        self.router = router
        self.isShowCloseButton = isShowCloseButton
        self.hideWarningViewAction = hideWarningViewAction
    }
    
    func tapAction() {
        switch warningType {
        case .limitedPhotoAccess:
            router?.goToSettings()
        case .noInternetConnection,
             .requiredIncomingSharedItemVerification,
             .contactsNotVerified:
            break
        }
    }
    
    func closeAction() {
        isHideWarningView = true
        hideWarningViewAction?()
    }
}
